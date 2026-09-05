import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/memory_photo.dart';
import '../../../../core/utils/logger.dart';

class GalleryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'gallery';

  static String _monthDay(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$m-$d';
  }

  /// Returns the URL used for displaying gallery images.
  /// Routes Firebase Storage URLs through a Cloud Function proxy
  /// on web to avoid CORS / auth issues.
  static String displayUrl(String imageUrl) {
    if (kIsWeb && imageUrl.contains('firebasestorage.googleapis.com')) {
      return 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyGalleryImage?url=${Uri.encodeComponent(imageUrl)}';
    }
    return imageUrl;
  }

  /// Upload a photo and store its metadata in Firestore.
  Future<MemoryPhoto> uploadPhoto({
    required Uint8List imageBytes,
    required String fileName,
    required String caption,
    required String uploadedBy,
    required String userId,
    List<String> tags = const [],
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? takenAt,
  }) async {
    // Upload to Firebase Storage
    final String path =
        "gallery/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName";
    final Reference ref = _storage.ref().child(path);
    final UploadTask uploadTask = ref.putData(
      imageBytes,
      SettableMetadata(
        contentType: _guessContentType(fileName),
        cacheControl: 'public, max-age=31536000',
      ),
    );
    final TaskSnapshot snapshot = await uploadTask;
    final String downloadUrl = await snapshot.ref.getDownloadURL();

    // Save metadata to Firestore
    final docRef = await _db.collection(_collection).add({
      'imageUrl': downloadUrl,
      'caption': caption,
      'uploadedBy': uploadedBy,
      'uploadedAt': FieldValue.serverTimestamp(),
      'tags': tags,
      'monthDay': _monthDay(DateTime.now()),
      'latitude': ?latitude,
      'longitude': ?longitude,
      if (locationName != null && locationName.isNotEmpty)
        'locationName': locationName,
      if (takenAt != null) 'takenAt': Timestamp.fromDate(takenAt),
    });

    Logger.i("Photo uploaded successfully: ${docRef.id}");

    return MemoryPhoto(
      id: docRef.id,
      imageUrl: downloadUrl,
      caption: caption,
      uploadedBy: uploadedBy,
      uploadedAt: DateTime.now(),
      tags: tags,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      takenAt: takenAt,
    );
  }

  /// Guess content type from file extension, defaulting to image/jpeg.
  static String _guessContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  /// Stream of all photos, newest first.
  Stream<List<MemoryPhoto>> getPhotosStream() {
    return _db
        .collection(_collection)
        .orderBy('uploadedAt', descending: true)
        .limit(40)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MemoryPhoto.fromFirestore(doc))
              .toList(),
        );
  }

  /// Stream of recent photos (for dashboard preview).
  Stream<List<MemoryPhoto>> getRecentPhotos({int limit = 6}) {
    return _db
        .collection(_collection)
        .orderBy('uploadedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MemoryPhoto.fromFirestore(doc))
              .toList(),
        );
  }

  /// Delete a photo from Firestore and Storage.
  Future<void> deletePhoto(MemoryPhoto photo) async {
    try {
      // Delete from Firestore
      await _db.collection(_collection).doc(photo.id).delete();

      // Delete from Storage (best-effort). The direct delete only works
      // for the uploader's own files; for the partner's photo it falls back
      // to the couple-only cloud function so no orphaned file is left behind.
      try {
        final ref = _storage.refFromURL(photo.imageUrl);
        await ref.delete();
      } catch (_) {
        await _deleteStorageViaFunction(photo.imageUrl);
      }

      Logger.i("Photo deleted: ${photo.id}");
    } catch (e) {
      debugPrint("Error deleting photo: $e");
    }
  }

  /// Server-side Storage delete for the partner's photos. Best-effort:
  /// never throws, so a failed cleanup can't fail the whole delete.
  Future<void> _deleteStorageViaFunction(String imageUrl) async {
    try {
      final idToken =
          await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
      if (idToken.isEmpty) return;
      final urls = <Uri>[
        if (kIsWeb) Uri.parse('/api/deleteGalleryPhoto'),
        Uri.parse(
          'https://us-central1-everglow-1c6db.cloudfunctions.net/deleteGalleryPhoto',
        ),
      ];
      for (final url in urls) {
        try {
          final resp = await http
              .post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
                body: jsonEncode({'imageUrl': imageUrl}),
              )
              .timeout(const Duration(seconds: 10));
          if (resp.statusCode == 200) return;
          Logger.e('deleteGalleryPhoto $url -> ${resp.statusCode}');
        } catch (_) {
          // Try the next URL.
        }
      }
    } catch (_) {
      // Best-effort only.
    }
  }

  /// Search photos by caption or tags (client-side).
  Stream<List<MemoryPhoto>> searchPhotos(String query) {
    final lowerQuery = query.toLowerCase();
    return _db
        .collection(_collection)
        .orderBy('uploadedAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MemoryPhoto.fromFirestore(doc))
              .where(
                (photo) =>
                    photo.caption.toLowerCase().contains(lowerQuery) ||
                    photo.tags.any((t) => t.toLowerCase().contains(lowerQuery)),
              )
              .toList(),
        );
  }

  /// "On This Day" — photos uploaded on the same month+day in previous years.
  Future<List<MemoryPhoto>> getPhotosFromThisDay() async {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    try {
      final monthDay = _monthDay(now);
      var snapshot = await _db
          .collection(_collection)
          .where('monthDay', isEqualTo: monthDay)
          .limit(100)
          .get();

      // Legacy photos predate the monthDay field; bound the fallback so it
      // never grows with the full album.
      if (snapshot.docs.isEmpty) {
        snapshot = await _db
            .collection(_collection)
            .orderBy('uploadedAt', descending: true)
            .limit(200)
            .get();
      }

      final results = <MemoryPhoto>[];
      for (final doc in snapshot.docs) {
        final photo = MemoryPhoto.fromFirestore(doc);
        if (photo.uploadedAt.month == month &&
            photo.uploadedAt.day == day &&
            photo.uploadedAt.year != now.year) {
          results.add(photo);
        }
      }
      return results;
    } catch (e) {
      Logger.e("Error getting on-this-day photos", error: e);
      return [];
    }
  }

  /// This Week In Past — 7-day window around today (Immich-inspired: This week in past slides)
  Future<List<MemoryPhoto>> getPhotosFromThisWeek() async {
    final now = DateTime.now();
    try {
      final all = await _db
          .collection(_collection)
          .orderBy('uploadedAt', descending: true)
          .limit(300)
          .get();
      final photos = all.docs.map((d) => MemoryPhoto.fromFirestore(d)).toList();
      return photos.where((p) {
        if (p.uploadedAt.year == now.year) return false;
        final thisYearAnniv = DateTime(
          now.year,
          p.uploadedAt.month,
          p.uploadedAt.day,
        );
        final diff =
            (thisYearAnniv
                    .difference(DateTime(now.year, now.month, now.day))
                    .inDays)
                .abs();
        return diff <= 3; // within 3 days => 7-day window
      }).toList()..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    } catch (e) {
      Logger.e("Error getting this-week photos", error: e);
      return [];
    }
  }

  /// All photos that have a pinned location — for map view (Immich map)
  Stream<List<MemoryPhoto>> getPhotosWithLocationStream() {
    return _db
        .collection(_collection)
        .orderBy('uploadedAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MemoryPhoto.fromFirestore(d))
              .where((p) => p.hasLocation)
              .toList(),
        );
  }

  Future<List<MemoryPhoto>> getPhotosWithLocation() async {
    try {
      final snap = await _db
          .collection(_collection)
          .orderBy('uploadedAt', descending: true)
          .limit(200)
          .get();
      return snap.docs
          .map((d) => MemoryPhoto.fromFirestore(d))
          .where((p) => p.hasLocation)
          .toList();
    } catch (e) {
      Logger.e("Error getting located photos", error: e);
      return [];
    }
  }

  Future<void> updatePhotoLocation(
    String id, {
    double? lat,
    double? lng,
    String? locationName,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (lat != null && lng != null) {
        data['latitude'] = lat;
        data['longitude'] = lng;
      } else {
        data['latitude'] = FieldValue.delete();
        data['longitude'] = FieldValue.delete();
      }
      if (locationName != null && locationName.isNotEmpty) {
        data['locationName'] = locationName;
      } else {
        data['locationName'] = FieldValue.delete();
      }
      await _db.collection(_collection).doc(id).update(data);
      Logger.i("Updated location for $id");
    } catch (e) {
      Logger.e("Error updating location", error: e);
    }
  }
}
