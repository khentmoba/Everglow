import 'package:cloud_firestore/cloud_firestore.dart';

enum HeartNeed {
  hug('Could use a hug'),
  talk('Want to talk'),
  company('Keep me company'),
  quiet('Need some quiet');

  final String label;
  const HeartNeed(this.label);
}

class UserMood {
  final String? id;
  final HeartNeed? need;
  final String? acknowledgedBy;
  final String username;
  final int moodScore;
  final String moodEmoji;
  final DateTime timestamp;

  UserMood({
    this.id,
    this.need,
    this.acknowledgedBy,
    required this.username,
    required this.moodScore,
    required this.moodEmoji,
    required this.timestamp,
  });

  factory UserMood.fromFirestore(Map<String, dynamic> data, {String? id}) {
    return UserMood(
      id: id,
      need: HeartNeed.values.where((n) => n.name == data['need']).firstOrNull,
      acknowledgedBy: data['acknowledgedBy'] as String?,
      username: data['username'] ?? '',
      moodScore: data['moodScore'] ?? 3,
      moodEmoji: data['moodEmoji'] ?? '💖',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  bool isCurrentAt(DateTime now) =>
      timestamp.year == now.year &&
      timestamp.month == now.month &&
      timestamp.day == now.day;

  Map<String, dynamic> toFirestore() {
    return {
      if (need != null) 'need': need!.name,
      'username': username,
      'moodScore': moodScore,
      'moodEmoji': moodEmoji,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
