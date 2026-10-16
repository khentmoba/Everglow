@TestOn('browser')
library;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/play_zone/table_tennis/data/services/tt_bridge_service.dart';
import 'package:everglow/features/play_zone/table_tennis/data/services/tt_multiplayer_service.dart';
import 'package:everglow/features/play_zone/table_tennis/data/models/tt_room.dart';

class _Service implements TTMultiplayerService {
  final gate = Completer<void>();
  final writes = <(int, double, double)>[];
  @override
  Stream<TTRoom> watchRoom(String roomId) => Stream.value(
    TTRoom(
      id: roomId,
      hostUid: 'demo',
      status: TTRoomStatus.playing,
      lastTick: 7,
      updatedAt: Timestamp(0, 0),
    ),
  );
  @override
  Future<void> writeHostState({
    required String roomId,
    required int localTick,
    required double hostPaddleY,
    required BallState ball,
    required int hostScore,
    required int guestScore,
    required TTRoomStatus status,
  }) async {
    writes.add((localTick, hostPaddleY, ball.x));
    if (writes.length == 1) await gate.future;
  }

  @override
  Future<void> endMatch({required String roomId}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'one host tick combines paddle and ball and coalesces a slow save',
    (tester) async {
      final service = _Service();
      final bridge = TTBridgeService(mpService: service);
      bridge.connect(roomId: 'synthetic-room', isHost: true);
      await tester.pump();
      for (var i = 1; i <= 4; i++) {
        TTMultiplayerState.localPaddleY = i / 10;
        TTMultiplayerState.latestBallState = {
          'x': i / 10,
          'y': 0,
          'vx': 1,
          'vy': 0,
        };
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(service.writes, [(8, 0.1, 0.1)]);
      service.gate.complete();
      await tester.pump();
      expect(service.writes, [(8, 0.1, 0.1), (9, 0.4, 0.4)]);
      await tester.pump(const Duration(milliseconds: 200));
      expect(service.writes, hasLength(2));
      bridge.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(service.writes, hasLength(2));
    },
  );
}
