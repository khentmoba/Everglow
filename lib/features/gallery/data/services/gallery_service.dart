import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'upload_image_preparation_native.dart' as native_images;
import 'upload_image_preparation_native.dart'
    if (dart.library.js_interop) 'upload_image_preparation_web.dart'
    as upload_images;
import '../../../../core/agent/agent_mode.dart';
import '../../../../core/agent/agent_fixtures.dart';
import '../../domain/models/memory_photo.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/firestore_pagination.dart';

class GalleryService {
  GalleryService({
    FirebaseFirestore? db,
    Future<String> Function(String path, Uint8List bytes)? uploadObject,
    Future<void> Function(String imageUrl)? deleteStorageFile,
    Future<void> Function(String imageUrl)? deleteStorageViaFunction,
  }) : _customDb = db,
       _uploadObject = uploadObject,
       _deleteStorageFile = deleteStorageFile,
       _deleteStorageViaFunctionForTesting = deleteStorageViaFunction;

  final FirebaseFirestore? _customDb;
  final Future<String> Function(String path, Uint8List bytes)? _uploadObject;
  final Future<void> Function(String imageUrl)? _deleteStorageFile;
  final Future<void> Function(String imageUrl)?
  _deleteStorageViaFunctionForTesting;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;
  final String _collection = 'gallery';

  @visibleForTesting
  static String monthDay(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$m-$d';
  }

  @visibleForTesting
  static String sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  @visibleForTesting
  static String storageBasePath({
    required String userId,
    required String fileName,
    required int timestamp,
  }) {
    final safeName = sanitizeFileName(fileName);
    return 'gallery/$userId/${timestamp}_$safeName';
  }

  @visibleForTesting
  static Map<String, dynamic> buildMetadataPayload({
    required String imageUrl,
    String? thumbUrl,
    required String caption,
    required String uploadedBy,
    List<String> tags = const [],
    DateTime? now,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? takenAt,
    dynamic uploadedAtFieldValue,
  }) {
    final effectiveNow = now ?? DateTime.now();
    return {
      'imageUrl': imageUrl,
      'thumbUrl': ?thumbUrl,
      'caption': caption,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAtFieldValue ?? FieldValue.serverTimestamp(),
      'tags': tags,
      'monthDay': monthDay(effectiveNow),
      'latitude': ?latitude,
      'longitude': ?longitude,
      if (locationName != null && locationName.isNotEmpty)
        'locationName': locationName,
      if (takenAt != null) 'takenAt': Timestamp.fromDate(takenAt),
    };
  }

  /// Returns the URL used for displaying gallery images.
  /// Routes Firebase Storage URLs through a Cloud Function proxy
  /// on web to avoid CORS / auth issues.
  ///
  /// Pass [thumb] for rails, grids, and marquees: it appends `&w=440`
  /// so the proxy caches the thumbnail URL long-term, independently of
  /// the short-lived full-res viewer URL. (The proxy does not resize;
  /// small bytes come from the stored `thumbUrl` files.)
  static String displayUrl(String imageUrl, {bool thumb = false, bool? isWeb}) {
    final web = isWeb ?? kIsWeb;
    if (web && imageUrl.contains('firebasestorage.googleapis.com')) {
      final proxied =
          'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyGalleryImage?url=${Uri.encodeComponent(imageUrl)}';
      return thumb ? '$proxied&w=440' : proxied;
    }
    return imageUrl;
  }

  /// Upload a photo and store its metadata in Firestore.
  ///
  /// Uploads a web-friendly full image (max 1600px, JPEG q85) plus a
  /// 400px grid thumbnail. Grids load `thumbUrl`; the viewer loads the
  /// full `imageUrl`. Falls back to the original bytes when decoding fails.\
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
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return AgentFixtures.demoPhotos.first;
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final base = storageBasePath(
      userId: userId,
      fileName: fileName,
      timestamp: stamp,
    );
    final images = await upload_images.prepareImages(imageBytes);
    final fullBytes = images.full;
    final thumbBytes = images.thumb;

    final uploadedUrls = <String>[];
    Future<String> put(String path, Uint8List bytes) async {
      final url = _uploadObject == null
          ? await _putStorageFile(path, bytes)
          : await _uploadObject(path, bytes);
      uploadedUrls.add(url);
      return url;
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

    // Save metadata to Firestore. If it fails, remove only objects whose
    // upload completed; a committed metadata write must keep its files.
    late final DocumentReference<Map<String, dynamic>> docRef;
    try {
      docRef = await _db
          .collection(_collection)
          .add(
            buildMetadataPayload(
              imageUrl: downloadUrl,
              thumbUrl: thumbUrl,
              caption: caption,
              uploadedBy: uploadedBy,
              tags: tags,
              latitude: latitude,
              longitude: longitude,
              locationName: locationName,
              takenAt: takenAt,
            ),
          );
    } catch (e, st) {
      await _cleanupUploadedFiles(uploadedUrls);
      Error.throwWithStackTrace(e, st);
    }

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

  /// Decode the original once for both upload sizes.
  @visibleForTesting
  static ({Uint8List full, Uint8List? thumb}) prepareUploadImages(
    Uint8List bytes,
  ) {
    return native_images.prepareImagesSync(bytes);
  }

  static Uint8List _encodeResized(img.Image decoded, int maxSize) {
    return native_images.encodeResized(decoded, maxSize);
  }

  /// Decode + downscale to [maxSize] longest edge, re-encode JPEG q85.
  /// Returns null when the bytes aren't a decodable image.
  @visibleForTesting
  static Uint8List? resizedJpeg(Uint8List bytes, int maxSize) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      return _encodeResized(decoded, maxSize);
    } catch (e) {
      Logger.e('Image resize failed, using original bytes', error: e);
      return null;
    }
  }

  /// Stream of all photos, newest first.
  Stream<List<MemoryPhoto>> getPhotosStream({int limit = 40}) {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(AgentFixtures.demoPhotos.take(limit).toList());
    }

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

  /// Stream of recent photos (for dashboard preview).
  Stream<List<MemoryPhoto>> getRecentPhotos({int limit = 6}) {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(AgentFixtures.demoPhotos.take(limit).toList());
    }

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

  /// Delete a photo from Storage before its Firestore metadata.
  Future<void> deletePhoto(MemoryPhoto photo) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return;
    }

    try {
      for (final url in {
        photo.imageUrl,
        if (photo.thumbUrl?.isNotEmpty == true) photo.thumbUrl!,
      }) {
        await _deleteStorageObject(url);
      }
      await _db.collection(_collection).doc(photo.id).delete();
      Logger.i("Photo deleted: ${photo.id}");
    } catch (e) {
      Logger.e("Error deleting photo: ${photo.id}", error: e);
      rethrow;
    }
  }

  Future<String> _putStorageFile(String path, Uint8List bytes) async {
    final ref = _storage.ref().child(path);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      ),
    );
    try {
      return await ref.getDownloadURL();
    } catch (e, st) {
      try {
        await ref.delete();
      } catch (cleanupError, cleanupSt) {
        Logger.e(
          'Gallery: failed to clean uploaded file $path',
          error: cleanupError,
          stackTrace: cleanupSt,
        );
      }
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> _cleanupUploadedFiles(List<String> urls) async {
    for (final url in urls) {
      try {
        await _deleteStorageObject(url);
      } catch (e, st) {
        Logger.e(
          'Gallery: failed to clean uploaded file $url',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<void> _deleteStorageObject(String imageUrl) async {
    try {
      if (_deleteStorageFile case final delete?) {
        await delete(imageUrl);
      } else {
        await _storage.refFromURL(imageUrl).delete();
      }
    } catch (e) {
      if (_isObjectNotFound(e)) return;
      await _deleteStorageViaFunction(imageUrl);
    }
  }

  static bool _isObjectNotFound(Object error) =>
      error is FirebaseException &&
      (error.code == 'object-not-found' ||
          error.code == 'storage/object-not-found');

  /// Server-side Storage delete for the partner's photos.
  Future<void> _deleteStorageViaFunction(String imageUrl) async {
    if (_deleteStorageViaFunctionForTesting case final delete?) {
      try {
        await delete(imageUrl);
      } catch (e) {
        if (_isObjectNotFound(e)) return;
        rethrow;
      }
      return;
    }

    try {
      final idToken =
          await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
      if (idToken.isEmpty) {
        throw StateError('No authenticated user for gallery file cleanup');
      }
      final urls = <Uri>[
        if (kIsWeb) Uri.parse('/api/deleteGalleryPhoto'),
        Uri.parse(
          'https://us-central1-everglow-1c6db.cloudfunctions.net/deleteGalleryPhoto',
        ),
      ];
      Object? lastError;
      StackTrace? lastStack;
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
          final error = StateError(
            'deleteGalleryPhoto $url returned ${resp.statusCode}',
          );
          Logger.e('Gallery storage fallback failed', error: error);
          lastError = error;
          lastStack = StackTrace.current;
        } catch (e, st) {
          if (_isObjectNotFound(e)) return;
          Logger.e(
            'deleteGalleryPhoto attempt failed for $url',
            error: e,
            stackTrace: st,
          );
          lastError = e;
          lastStack = st;
        }
      }
      if (lastError != null) Error.throwWithStackTrace(lastError, lastStack!);
      throw StateError('Gallery storage fallback did not run');
    } catch (e, st) {
      Logger.e(
        'Gallery: storage cleanup via function failed for $imageUrl',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Search photos by caption or tags (client-side, one-shot so typing
  /// doesn't re-query on every remote write).
  Future<List<MemoryPhoto>> searchPhotos(String query) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      final lowerQuery = query.toLowerCase();
      return AgentFixtures.demoPhotos
          .where(
            (photo) =>
                photo.caption.toLowerCase().contains(lowerQuery) ||
                photo.tags.any((t) => t.toLowerCase().contains(lowerQuery)),
          )
          .toList();
    }

    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return [];
    final matches = <MemoryPhoto>[];
    DocumentSnapshot? cursor;
    do {
      final page = await fetchFirestorePage<MemoryPhoto>(
        collection: _db.collection(_collection),
        orderBy: 'uploadedAt',
        cursor: cursor,
        limit: 40,
        fromDoc: MemoryPhoto.fromFirestore,
      );
      matches.addAll(
        page.items.where(
          (photo) =>
              photo.caption.toLowerCase().contains(lowerQuery) ||
              photo.tags.any((t) => t.toLowerCase().contains(lowerQuery)),
        ),
      );
      cursor = page.nextCursor;
    } while (cursor != null);
    return matches;
  }

  /// "On This Day" — photos uploaded on the same month+day in previous years.
  Future<List<MemoryPhoto>> getPhotosFromThisDay() async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return [];
    }

    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    try {
      final md = monthDay(now);
      var snapshot = await withGetTimeout(
        _db
            .collection(_collection)
            .where('monthDay', isEqualTo: md)
            .limit(100)
            .get(),
        label: 'gallery on-this-day',
      );

      // Legacy photos predate the monthDay field; bound the fallback so it
      // never grows with the full album.
      if (snapshot.docs.isEmpty) {
        snapshot = await withGetTimeout(
          _db
              .collection(_collection)
              .orderBy('uploadedAt', descending: true)
              .limit(200)
              .get(),
          label: 'gallery on-this-day fallback',
        );
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
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return AgentFixtures.demoPhotos;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_thisWeekDay == today && _thisWeekCache != null) return _thisWeekCache!;
    try {
      final all = await withGetTimeout(
        _db
            .collection(_collection)
            .orderBy('uploadedAt', descending: true)
            .limit(100)
            .get(),
        label: 'gallery this-week',
      );
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
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return AgentFixtures.demoPhotos.where((p) => p.hasLocation).toList();
    }

    try {
      final snap = await withGetTimeout(
        _db
            .collection(_collection)
            .orderBy('uploadedAt', descending: true)
            .limit(limit)
            .get(),
        label: 'gallery located photos',
      );
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
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return;
    }

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
