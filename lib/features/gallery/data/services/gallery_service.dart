import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/memory_photo.dart';
import '../../../../core/utils/logger.dart';

class GalleryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'gallery';

  /// Upload a photo and store its metadata in Firestore.
  Future<MemoryPhoto> uploadPhoto({
    required Uint8List imageBytes,
    required String fileName,
    required String caption,
    required String uploadedBy,
    List<String> tags = const [],
  }) async {
    // Upload to Firebase Storage
    final String path =
        "gallery/$uploadedBy/${DateTime.now().millisecondsSinceEpoch}_$fileName";
    final Reference ref = _storage.ref().child(path);
    final UploadTask uploadTask = ref.putData(
      imageBytes,
      SettableMetadata(contentType: _guessContentType(fileName)),
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
    });

    Logger.i("Photo uploaded successfully: ${docRef.id}");

    return MemoryPhoto(
      id: docRef.id,
      imageUrl: downloadUrl,
      caption: caption,
      uploadedBy: uploadedBy,
      uploadedAt: DateTime.now(),
      tags: tags,
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
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MemoryPhoto.fromFirestore(doc)).toList());
  }

  /// Stream of recent photos (for dashboard preview).
  Stream<List<MemoryPhoto>> getRecentPhotos({int limit = 6}) {
    return _db
        .collection(_collection)
        .orderBy('uploadedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MemoryPhoto.fromFirestore(doc)).toList());
  }

  /// Delete a photo from Firestore and Storage.
  Future<void> deletePhoto(MemoryPhoto photo) async {
    try {
      // Delete from Firestore
      await _db.collection(_collection).doc(photo.id).delete();

      // Delete from Storage (best-effort)
      try {
        final ref = _storage.refFromURL(photo.imageUrl);
        await ref.delete();
      } catch (_) {
        // Storage deletion is best-effort
      }

      Logger.i("Photo deleted: ${photo.id}");
    } catch (e) {
      debugPrint("Error deleting photo: $e");
    }
  }

  /// Search photos by caption or tags (client-side).
  Stream<List<MemoryPhoto>> searchPhotos(String query) {
    final lowerQuery = query.toLowerCase();
    return _db
        .collection(_collection)
        .orderBy('uploadedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MemoryPhoto.fromFirestore(doc))
            .where((photo) =>
                photo.caption.toLowerCase().contains(lowerQuery) ||
                photo.tags.any((t) => t.toLowerCase().contains(lowerQuery)))
            .toList());
  }
}
