import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/milestone.dart';
import '../../domain/models/hidden_note.dart';
import '../../../guardian/data/models/guardian_message.dart';
import 'milestone_service.dart';

class CreatorService {
  FirebaseFirestore? _firestoreInstance;
  FirebaseStorage? _storageInstance;
  http.Client? _httpClient;

  CreatorService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    http.Client? httpClient,
  })  : _firestoreInstance = firestore,
        _storageInstance = storage,
        _httpClient = httpClient;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ??= FirebaseFirestore.instance;

  FirebaseStorage get _storage => _storageInstance ??= FirebaseStorage.instance;
  http.Client get _http => _httpClient ??= http.Client();

  // ---------------------------------------------------------------------------
  // Images & Media
  // ---------------------------------------------------------------------------

  /// Uploads an image to Firebase Storage and returns the download URL.
  Future<String?> uploadImage(
    Uint8List fileBytes,
    String fileName,
    String userId,
  ) async {
    try {
      final ref = _storage.ref().child('milestones/$userId/$fileName');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = ref.putData(fileBytes, metadata);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// Uploads multiple images in sequence and returns successful URLs.
  Future<List<String>> uploadMultipleImages(
    List<({Uint8List bytes, String name})> files,
    String userId,
  ) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadImage(file.bytes, file.name, userId);
      if (url != null && url.isNotEmpty) {
        urls.add(url);
      }
    }
    return urls;
  }

  // ---------------------------------------------------------------------------
  // Milestones & Memories
  // ---------------------------------------------------------------------------

  /// Saves a new Milestone to Firestore.
  Future<void> saveMilestone({
    required String title,
    required String description,
    required DateTime date,
    required List<String> imageUrls,
    String? author,
  }) async {
    final milestone = Milestone(
      id: '',
      title: title,
      description: description,
      date: date,
      imageUrls: imageUrls,
      author: author,
    );
    await _firestore.collection('milestones').add(milestone.toFirestore());
  }

  /// Updates an existing Milestone in Firestore.
  Future<void> updateMilestone({
    required String id,
    required String title,
    required String description,
    required DateTime date,
    required List<String> imageUrls,
    String? author,
  }) async {
    await _firestore.collection('milestones').doc(id).update({
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'imageUrls': imageUrls,
      'author': ?author,
    });
  }

  /// Deletes a Milestone by its ID.
  Future<void> deleteMilestone(String id) async {
    await _firestore.collection('milestones').doc(id).delete();
  }

  /// Realtime stream of recent milestones ordered by date.
  Stream<List<Milestone>> watchMilestones({int limit = 30}) {
    return _firestore
        .collection('milestones')
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Milestone.fromFirestore(doc)).toList());
  }

  // ---------------------------------------------------------------------------
  // Hidden Notes & Letterbox
  // ---------------------------------------------------------------------------

  /// Saves a new HiddenNote to Firestore.
  Future<void> saveHiddenNote({
    required String title,
    required String content,
    required DateTime unlockDate,
  }) async {
    final note = HiddenNote(
      id: '',
      title: title,
      content: content,
      unlockDate: unlockDate,
      isRead: false,
    );
    await _firestore.collection('notes').add(note.toFirestore());
  }

  /// Updates an existing HiddenNote's content and unlock schedule.
  Future<void> updateHiddenNote({
    required String id,
    required String title,
    required String content,
    required DateTime unlockDate,
  }) async {
    await _firestore.collection('notes').doc(id).update({
      'title': title,
      'content': content,
      'unlockDate': Timestamp.fromDate(unlockDate),
    });
  }

  /// Deletes a HiddenNote by its ID.
  Future<void> deleteHiddenNote(String id) async {
    await _firestore.collection('notes').doc(id).delete();
  }

  /// Realtime stream of notes ordered by unlock date ascending.
  Stream<List<HiddenNote>> watchHiddenNotes({int limit = 50}) {
    return _firestore
        .collection('notes')
        .orderBy('unlockDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => HiddenNote.fromFirestore(doc)).toList());
  }

  // ---------------------------------------------------------------------------
  // Guardian Mascot Whispers (Surprises for Clair)
  // ---------------------------------------------------------------------------

  /// Sends a secret whisper message to the Guardian mascot to greet Clair.
  Future<void> sendGuardianWhisper(String content) async {
    if (content.trim().isEmpty) return;
    await _firestore.collection('guardian_messages').add({
      'content': content.trim(),
      'category': 'whisper',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Realtime stream of recent whispers.
  Stream<List<GuardianMessage>> watchGuardianWhispers({int limit = 10}) {
    return _firestore
        .collection('guardian_messages')
        .where('category', isEqualTo: 'whisper')
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GuardianMessage.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Deletes a whisper message.
  Future<void> deleteGuardianWhisper(String id) async {
    await _firestore.collection('guardian_messages').doc(id).delete();
  }

  // ---------------------------------------------------------------------------
  // Love Burst / Surprise Star
  // ---------------------------------------------------------------------------

  /// Drops an instant glowing surprise note into the Starlight Jar.
  Future<void> sendLoveBurst({
    required String message,
    required String author,
  }) async {
    if (message.trim().isEmpty) return;
    await _firestore.collection('starlight_jar').add({
      'content': message.trim(),
      'author': author,
      'timestamp': FieldValue.serverTimestamp(),
      'category': 'surprise',
      'tags': ['surprise', 'love_burst', 'creator'],
      'likes': 0,
      'opened': false,
      'openedAt': null,
    });
  }

  // ---------------------------------------------------------------------------
  // Teaser / Secret Countdown
  // ---------------------------------------------------------------------------

  /// Adds a teaser countdown event on the shared calendar / upcoming countdowns.
  Future<void> createTeaserCountdown({
    required String title,
    required DateTime date,
    String? description,
    required String createdBy,
  }) async {
    await _firestore.collection('calendar_events').add({
      'title': title.trim(),
      'description': (description ?? 'Surprise countdown for Clair ✨').trim(),
      'date': Timestamp.fromDate(date),
      'type': 'date_night',
      'createdBy': createdBy,
      'recurring': 'none',
      'attendees': ['khentsgdz', 'clairjassen'],
      'isAllDay': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // Date Night Feature (Tonight's Spotlight)
  // ---------------------------------------------------------------------------

  /// Sets or updates the active "Tonight's Feature" in our_cinema.
  Future<void> setTonightFeature({
    required String title,
    required String mediaType,
    String? posterPath,
    String? note,
    required String setBy,
  }) async {
    await _firestore.collection('our_cinema').doc('tonight_feature').set({
      'title': title.trim(),
      'mediaType': mediaType,
      'posterPath': ?posterPath,
      'note': (note ?? '').trim(),
      'setBy': setBy,
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Clears the active tonight feature spotlight.
  Future<void> clearTonightFeature() async {
    await _firestore.collection('our_cinema').doc('tonight_feature').set({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Realtime stream of the current tonight feature.
  Stream<Map<String, dynamic>?> watchTonightFeature() {
    return _firestore
        .collection('our_cinema')
        .doc('tonight_feature')
        .snapshots()
        .map((doc) => doc.data());
  }

  // ---------------------------------------------------------------------------
  // System Health & Maintenance
  // ---------------------------------------------------------------------------

  /// Pings the backend health endpoint and returns uptime, version, and firestore status.
  Future<Map<String, dynamic>> fetchHealthStatus() async {
    try {
      final uri = Uri.parse(
        'https://us-central1-everglow-1c6db.cloudfunctions.net/health',
      );
      final response = await _http.get(uri).timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode == 200 || response.statusCode == 503) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      return {
        'status': 'error',
        'httpStatus': response.statusCode,
        'message': 'HTTP ${response.statusCode}',
      };
    } catch (e) {
      return {
        'status': 'offline',
        'error': e.toString(),
      };
    }
  }

  /// Repaired legacy milestone assets (.png to .jpg).
  Future<int> repairMilestoneAssets() async {
    return MilestoneService().repairLegacyAssetPaths();
  }

  /// Clears persistent local disk caches for letters and local storage.
  Future<void> clearLocalCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('letterbox_notes_cache_v1');
    } catch (e) {
      debugPrint('Error clearing caches: $e');
    }
  }
}
