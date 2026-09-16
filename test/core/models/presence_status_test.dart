import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/core/models/presence_status.dart';

void main() {
  group('PresenceStatus', () {
    test('fromFirestore reads every field', () {
      final seen = DateTime.utc(2026, 9, 16, 10, 0);
      final status = PresenceStatus.fromFirestore('uid1', {
        'username': 'clair',
        'isOnline': true,
        'lastSeen': Timestamp.fromDate(seen),
        'isDoodling': true,
        'lastDoodleAt': Timestamp.fromDate(seen),
      });

      expect(status.uid, 'uid1');
      expect(status.username, 'clair');
      expect(status.isOnlineRaw, isTrue);
      expect(status.lastSeen?.millisecondsSinceEpoch,
          seen.millisecondsSinceEpoch);
      expect(status.isDoodlingRaw, isTrue);
      expect(status.lastDoodleAt?.millisecondsSinceEpoch,
          seen.millisecondsSinceEpoch);
      expect(status.hasEverBeenSeen, isTrue);
    });

    test('online and doodling checks respect freshness windows', () {
      final now = DateTime.utc(2026, 9, 16, 10, 5);
      final fresh = PresenceStatus.fromFirestore('uid1', {
        'isOnline': true,
        'lastSeen': Timestamp.fromDate(now),
        'isDoodling': true,
        'lastDoodleAt': Timestamp.fromDate(now),
      });

      expect(fresh.isOnlineAt(now), isTrue);
      expect(fresh.isActivelyDoodlingAt(now), isTrue);

      final stale = PresenceStatus.fromFirestore('uid1', {
        'isOnline': true,
        'lastSeen':
            Timestamp.fromDate(now.subtract(const Duration(minutes: 30))),
        'isDoodling': true,
        'lastDoodleAt':
            Timestamp.fromDate(now.subtract(const Duration(minutes: 30))),
      });

      expect(stale.isOnlineAt(now), isFalse);
      expect(stale.isActivelyDoodlingAt(now), isFalse);
    });

    test('fromFirestore never crashes on odd field types', () {
      final status = PresenceStatus.fromFirestore('uid1', {
        'username': 123,
        'isOnline': 'yes',
        'lastSeen': 'not-a-date',
        'isDoodling': 1,
        'lastDoodleAt': ['now'],
      });

      expect(status.username, isEmpty);
      expect(status.isOnlineRaw, isFalse);
      expect(status.lastSeen, isNull);
      expect(status.isDoodlingRaw, isFalse);
      expect(status.lastDoodleAt, isNull);
      expect(status.hasEverBeenSeen, isFalse);
      expect(status.isOnlineAt(DateTime.now()), isFalse);
      expect(status.isActivelyDoodlingAt(DateTime.now()), isFalse);
    });
  });
}
