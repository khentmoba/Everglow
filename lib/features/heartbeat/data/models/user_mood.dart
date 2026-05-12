import 'package:cloud_firestore/cloud_firestore.dart';

class UserMood {
  final String username;
  final int moodScore;
  final String moodEmoji;
  final DateTime timestamp;

  UserMood({
    required this.username,
    required this.moodScore,
    required this.moodEmoji,
    required this.timestamp,
  });

  factory UserMood.fromFirestore(Map<String, dynamic> data) {
    return UserMood(
      username: data['username'] ?? '',
      moodScore: data['moodScore'] ?? 3,
      moodEmoji: data['moodEmoji'] ?? '💖',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'moodScore': moodScore,
      'moodEmoji': moodEmoji,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
