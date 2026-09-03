import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../models/user_mood.dart';

class MoodService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Submits a new mood entry.
  Future<void> submitMood({
    required String username,
    required int score,
    required String emoji,
  }) async {
    await _db.collection('moods').add({
      'username': username,
      'moodScore': score,
      'moodEmoji': emoji,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Checks if the user has already submitted a mood today.
  Future<bool> hasSubmittedToday(String username) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final snapshot = await _db
        .collection('moods')
        .where('username', isEqualTo: username)
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// One-shot fetch of the latest mood (cheaper than opening a stream
  /// listener for fire-and-forget reads like the Guardian's mentions).
  Future<UserMood?> getLatestMood(String username) async {
    try {
      final snapshot = await _db
          .collection('moods')
          .where('username', isEqualTo: username)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));
      if (snapshot.docs.isEmpty) return null;
      return UserMood.fromFirestore(snapshot.docs.first.data());
    } catch (e) {
      return null;
    }
  }

  /// Streams the latest mood for a specific user.
  Stream<UserMood?> watchLatestMood(String username) {
    return withFirestoreTimeout(
      _db
          .collection('moods')
          .where('username', isEqualTo: username)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isEmpty) return null;
            return UserMood.fromFirestore(snapshot.docs.first.data());
          }),
      label: 'mood-$username',
    );
  }
}
