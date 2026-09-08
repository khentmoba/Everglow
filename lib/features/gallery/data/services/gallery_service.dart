import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
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
  ///
  /// Uploads a web-friendly full image (max 1600px, JPEG q85) plus a
  /// 400px grid thumbnail. Grids load `thumbUrl`; the viewer loads the
  /// full `imageUrl`. Falls back to the original bytes when decoding fails.
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
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final base = 'gallery/$userId/${stamp}_$safeName';
    final fullBytes = _resizedJpeg(imageBytes, 1600) ?? imageBytes;
    final thumbBytes = _resizedJpeg(imageBytes, 400);

    Future<String> put(String path, Uint8List bytes) async {
      final ref = _storage.ref().child(path);
      final snap = await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        ),
      );
      return snap.ref.getDownloadURL();
    }

    final downloadUrl = await put('${base}_full.jpg', fullBytes);
    final thumbBytesLocal = thumbBytes;
    String? thumbUrl;
    if (thumbBytesLocal != null) {
      try {
        thumbUrl = await put('${base}_thumb.jpg', thumbBytesLocal);
      } catch (e) {
        Logger.e('Thumbnail upload failed, grid falls back to full', error: e);
      }
    }

    // Save metadata to Firestore
    final docRef = await _db.collection(_collection).add({
      'imageUrl': downloadUrl,
      'thumbUrl': ?thumbUrl,
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
      thumbUrl: thumbUrl,
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

  /// Decode + downscale to [maxSize] longest edge, re-encode JPEG q85.
  /// Returns null when the bytes aren't a decodable image.
  static Uint8List? _resizedJpeg(Uint8List bytes, int maxSize) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final longest = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;
      final resized = longest <= maxSize
          ? decoded
          : img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? maxSize : null,
              height: decoded.height > decoded.width ? maxSize : null,
            );
      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (e) {
      Logger.e('Image resize failed, using original bytes', error: e);
      return null;
    }
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

  /// Delete a photo from Firestore and Storage (full + thumbnail).
  Future<void> deletePhoto(MemoryPhoto photo) async {
    try {
      // Delete from Firestore
      await _db.collection(_collection).doc(photo.id).delete();

      // Delete from Storage (best-effort). The direct delete only works
      // for the uploader's own files; for the partner's photo it falls back
      // to the couple-only cloud function so no orphaned file is left behind.
      for (final url in {
        photo.imageUrl,
        if (photo.thumbUrl?.isNotEmpty == true) photo.thumbUrl!,
      }) {
        try {
          final ref = _storage.refFromURL(url);
          await ref.delete();
        } catch (_) {
          await _deleteStorageViaFunction(url);
        }
      }

      Logger.i("Photo deleted: ${photo.id}");
    } catch (e) {
      Logger.e("Error deleting photo: ${photo.id}", error: e);
      rethrow;
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

  /// Search photos by caption or tags (client-side, one-shot so typing
  /// doesn't re-query on every remote write).
  Future<List<MemoryPhoto>> searchPhotos(String query) async {
    final lowerQuery = query.toLowerCase();
    final snapshot = await _db
        .collection(_collection)
        .orderBy('uploadedAt', descending: true)
        .limit(50)
        .get();
    return snapshot.docs
        .map((doc) => MemoryPhoto.fromFirestore(doc))
        .where(
          (photo) =>
              photo.caption.toLowerCase().contains(lowerQuery) ||
              photo.tags.any((t) => t.toLowerCase().contains(lowerQuery)),
        )
        .toList();
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

  /// This Week In Past — 7-day window around today (Immich-inspired: This week in past slides).
  /// Memoized per calendar day so every dashboard open doesn't re-read 300 docs.
  DateTime? _thisWeekDay;
  List<MemoryPhoto>? _thisWeekCache;
  Future<List<MemoryPhoto>> getPhotosFromThisWeek() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_thisWeekDay == today && _thisWeekCache != null) return _thisWeekCache!;
    try {
      final all = await _db
          .collection(_collection)
          .orderBy('uploadedAt', descending: true)
          .limit(100)
          .get();
      final photos = all.docs.map((d) => MemoryPhoto.fromFirestore(d)).toList();
      final results = photos.where((p) {
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
      _thisWeekDay = today;
      _thisWeekCache = results;
      return results;
    } catch (e) {
      Logger.e("Error getting this-week photos", error: e);
      return [];
    }
  }

  /// All photos that have a pinned location — for map view (Immich map).
  /// One-shot fetch: the map only needs a snapshot on open, not a realtime
  /// stream that re-queries on every remote write.
  Future<List<MemoryPhoto>> getPhotosWithLocationStream() =>
      getPhotosWithLocation(limit: 100);

  Future<List<MemoryPhoto>> getPhotosWithLocation({int limit = 200}) async {
    try {
      final snap = await _db
          .collection(_collection)
          .orderBy('uploadedAt', descending: true)
          .limit(limit)
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
