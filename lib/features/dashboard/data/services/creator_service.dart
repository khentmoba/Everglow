import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/milestone.dart';
import '../../domain/models/hidden_note.dart';

class CreatorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads an image to Firebase Storage and returns the download URL.
  Future<String?> uploadImage(Uint8List fileBytes, String fileName) async {
    try {
      final ref = _storage.ref().child('milestones/$fileName');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = ref.putData(fileBytes, metadata);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// Saves a new Milestone to Firestore.
  Future<void> saveMilestone({
    required String title,
    required String description,
    required DateTime date,
    required List<String> imageUrls,
    String? author,
  }) async {
    final milestone = Milestone(
      id: '', // Firestore will generate an ID on add
      title: title,
      description: description,
      date: date,
      imageUrls: imageUrls,
      author: author,
    );
    await _firestore.collection('milestones').add(milestone.toFirestore());
  }

  /// Saves a new HiddenNote to Firestore.
  Future<void> saveHiddenNote({
    required String title,
    required String content,
    required DateTime unlockDate,
  }) async {
    final note = HiddenNote(
      id: '', // Firestore will generate an ID on add
      title: title,
      content: content,
      unlockDate: unlockDate,
      isRead: false,
    );
    await _firestore.collection('notes').add(note.toFirestore());
  }
}
