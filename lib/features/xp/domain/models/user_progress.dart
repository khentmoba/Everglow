import 'package:cloud_firestore/cloud_firestore.dart';

class UserProgress {
  final String uid;
  final int xpTotal;
  final int level;
  final int streak;
  final DateTime lastActivity;

  static const int xpPerLevel = 200;

  static int levelForXp(int xpTotal) {
    if (xpTotal <= 0) return 1;
    return xpTotal ~/ xpPerLevel + 1;
  }

  static int xpIntoLevel(int xpTotal) {
    if (xpTotal <= 0) return 0;
    return xpTotal % xpPerLevel;
  }

  static int xpToNextLevel(int xpTotal) => xpPerLevel - xpIntoLevel(xpTotal);

  UserProgress({
    required this.uid,
    required this.xpTotal,
    required this.level,
    required this.streak,
    required this.lastActivity,
  });

  factory UserProgress.fromMap(String uid, Map<String, dynamic> map) {
    final xp = (map['xpTotal'] as num?)?.toInt() ?? 0;
    return UserProgress(
      uid: uid,
      xpTotal: xp,
      level: (map['level'] as num?)?.toInt() ?? 1,
      streak: (map['streak'] as num?)?.toInt() ?? 0,
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
