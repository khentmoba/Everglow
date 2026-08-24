import 'package:cloud_firestore/cloud_firestore.dart';

class UserProgress {
  final String uid;
  final int xpTotal;
  final int level;
  final int streak;
  final DateTime lastActivity;

  UserProgress({
    required this.uid,
    required this.xpTotal,
    required this.level,
    required this.streak,
    required this.lastActivity,
  });

  factory UserProgress.fromMap(String uid, Map<String, dynamic> map) {
    return UserProgress(
      uid: uid,
      xpTotal: map['xpTotal'] ?? 0,
      level: map['level'] ?? 1,
      streak: map['streak'] ?? 0,
      lastActivity:
          (map['lastActivity'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'xpTotal': xpTotal,
      'level': level,
      'streak': streak,
      'lastActivity': Timestamp.fromDate(lastActivity),
    };
  }

  UserProgress copyWith({
    int? xpTotal,
    int? level,
    int? streak,
    DateTime? lastActivity,
  }) {
    return UserProgress(
      uid: uid,
      xpTotal: xpTotal ?? this.xpTotal,
      level: level ?? this.level,
      streak: streak ?? this.streak,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}
