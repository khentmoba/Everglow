import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/play_zone/table_tennis/models/tt_room.dart';

void main() {
  group('ttRoomStatusFromString', () {
    test('parses known statuses and falls back to waiting', () {
      expect(ttRoomStatusFromString('playing'), TTRoomStatus.playing);
      expect(ttRoomStatusFromString('finished'), TTRoomStatus.finished);
      expect(ttRoomStatusFromString('abandoned'), TTRoomStatus.abandoned);
      expect(ttRoomStatusFromString('waiting'), TTRoomStatus.waiting);
      expect(ttRoomStatusFromString(null), TTRoomStatus.waiting);
      expect(ttRoomStatusFromString('bogus'), TTRoomStatus.waiting);
    });
  });

  group('BallState', () {
    test('null map gives a centered still ball', () {
      const ball = BallState();
      expect(ball.x, 0);
      expect(ball.vx, 0);
      expect(BallState.fromMap(null), const BallState());
    });

    test('fromMap/toMap round-trips motion', () {
      const ball = BallState(x: 0.5, y: 0.25, vx: 1.5, vy: -2.0);
      final restored = BallState.fromMap(ball.toMap());

      expect(restored.x, 0.5);
      expect(restored.y, 0.25);
      expect(restored.vx, 1.5);
      expect(restored.vy, -2.0);
    });

    test('fromMap tolerates ints and missing keys', () {
      final restored = BallState.fromMap({'x': 1, 'vy': 2});

      expect(restored.x, 1.0);
      expect(restored.y, 0);
      expect(restored.vx, 0);
      expect(restored.vy, 2.0);
    });
  });

  group('TTRoom', () {
    test('fromDoc null data gives an empty waiting room', () {
      final room = TTRoom.fromDoc('r1', null);

      expect(room.id, 'r1');
      expect(room.hostUid, isEmpty);
      expect(room.status, TTRoomStatus.waiting);
      expect(room.hostScore, 0);
      expect(room.guestScore, 0);
      expect(room.hostPaddleY, 0.5);
    });

    test('fromDoc reads a live rally', () {
      final room = TTRoom.fromDoc('r2', {
        'hostUid': 'khent',
        'guestUid': 'clair',
        'status': 'playing',
        'hostPaddleY': 0.6,
        'guestPaddleY': 0.4,
        'ball': {'x': 0.5, 'y': 0.5, 'vx': 2.0, 'vy': 1.0},
        'hostScore': 3,
        'guestScore': 5,
        'lastTick': 42,
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 5)),
      });

      expect(room.hostUid, 'khent');
      expect(room.guestUid, 'clair');
      expect(room.status, TTRoomStatus.playing);
      expect(room.ball.vx, 2.0);
      expect(room.hostScore, 3);
      expect(room.guestScore, 5);
      expect(room.lastTick, 42);
    });

    test('copyWith scores without losing the room', () {
      final room = TTRoom.fromDoc('r3', {'hostUid': 'khent'}).copyWith(
        status: TTRoomStatus.playing,
        guestUid: 'clair',
        hostScore: 1,
        ball: const BallState(x: 0.1, vx: 3.0),
      );

      expect(room.id, 'r3');
      expect(room.hostUid, 'khent');
      expect(room.status, TTRoomStatus.playing);
      expect(room.guestUid, 'clair');
      expect(room.hostScore, 1);
      expect(room.ball.vx, 3.0);
    });

    test('toMap keeps status name and nested ball', () {
      final map = TTRoom.fromDoc('r4', {
        'hostUid': 'khent',
        'status': 'finished',
      }).toMap();

      expect(map['status'], 'finished');
      expect(map['hostSide'], 'near');
      expect((map['ball'] as Map)['x'], 0);
    });
  });
}
