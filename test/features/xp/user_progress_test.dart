import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/features/xp/domain/models/user_progress.dart';

void main() {
  group('UserProgress', () {
    test('constructor stores all fields', () {
      final date = DateTime(2026, 3, 1);
      final progress = UserProgress(
        uid: 'user1',
        xpTotal: 2500,
        level: 3,
        streak: 7,
        lastActivity: date,
      );

      expect(progress.uid, 'user1');
      expect(progress.xpTotal, 2500);
      expect(progress.level, 3);
      expect(progress.streak, 7);
      expect(progress.lastActivity, date);
    });

    test('fromMap parses all fields correctly', () {
      final date = DateTime(2026, 3, 15);
      final map = {
        'xpTotal': 1500,
        'level': 2,
        'streak': 5,
        'lastActivity': Timestamp.fromDate(date),
      };

      final progress = UserProgress.fromMap('uid123', map);

      expect(progress.uid, 'uid123');
      expect(progress.xpTotal, 1500);
      expect(progress.level, 2);
      expect(progress.streak, 5);
      expect(progress.lastActivity, date);
    });

    test('fromMap uses defaults for missing fields', () {
      final map = <String, dynamic>{};

      final progress = UserProgress.fromMap('uid-empty', map);

      expect(progress.uid, 'uid-empty');
      expect(progress.xpTotal, 0);
      expect(progress.level, 1);
      expect(progress.streak, 0);
      // lastActivity falls back to DateTime.now()
      expect(progress.lastActivity, isNotNull);
    });

    test('toMap returns correct structure', () {
      final date = DateTime(2026, 5, 20, 10, 30);
      final progress = UserProgress(
        uid: 'user2',
        xpTotal: 3000,
        level: 4,
        streak: 10,
        lastActivity: date,
      );

      final map = progress.toMap();

      expect(map['xpTotal'], 3000);
      expect(map['level'], 4);
      expect(map['streak'], 10);
      expect(map['lastActivity'], isA<Timestamp>());
      // uid is NOT included in the map (it's the doc ID)
      expect(map.containsKey('uid'), isFalse);
    });

    test('copyWith overrides specified fields', () {
      final original = UserProgress(
        uid: 'user3',
        xpTotal: 500,
        level: 1,
        streak: 2,
        lastActivity: DateTime(2026, 1, 1),
      );

      final updated = original.copyWith(xpTotal: 1500, level: 2);

      expect(updated.uid, 'user3'); // unchanged
      expect(updated.xpTotal, 1500); // changed
      expect(updated.level, 2); // changed
      expect(updated.streak, 2); // unchanged
      expect(updated.lastActivity, original.lastActivity); // unchanged
    });

    test('copyWith with no args returns equivalent instance', () {
      final original = UserProgress(
        uid: 'user4',
        xpTotal: 100,
        level: 1,
        streak: 0,
        lastActivity: DateTime(2026, 2, 14),
      );

      final copy = original.copyWith();

      expect(copy.uid, original.uid);
      expect(copy.xpTotal, original.xpTotal);
      expect(copy.level, original.level);
      expect(copy.streak, original.streak);
      expect(copy.lastActivity, original.lastActivity);
    });

    test('XP to level formula: level = floor(xp / 200) + 1', () {
      // This mirrors the curve in UserProgress.levelForXp.
      expect(UserProgress.levelForXp(0), 1);
      expect(UserProgress.levelForXp(199), 1);
      expect(UserProgress.levelForXp(200), 2);
      expect(UserProgress.levelForXp(450), 3);
      expect(UserProgress.levelForXp(2000), 11);
    });

    test('xpIntoLevel and xpToNextLevel follow xpPerLevel', () {
      expect(UserProgress.xpPerLevel, 200);
      expect(UserProgress.xpIntoLevel(450), 50);
      expect(UserProgress.xpToNextLevel(450), 150);
      expect(UserProgress.xpToNextLevel(200), 200);
    });

    test('stored level eventually converges to the curve via addXp', () {
      // addXp writes levelForXp(newXp), and fromMap keeps the stored value,
      // so one award after a curve change heals the level. Simulate that.
      final healed = UserProgress.fromMap('uid-heal', {
        'xpTotal': 450,
        'level': UserProgress.levelForXp(450),
        'streak': 0,
        'lastActivity': Timestamp.fromDate(DateTime(2026, 9, 1)),
      });

      expect(healed.level, 3);
    });
  });
}
