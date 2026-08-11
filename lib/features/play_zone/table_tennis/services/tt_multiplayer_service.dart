import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/tt_room.dart';

class TTMultiplayerService {
  final FirebaseFirestore _fs;
  TTMultiplayerService({FirebaseFirestore? firestore})
    : _fs = firestore ?? FirebaseFirestore.instance;

  static const String _collection = 'tt_rooms';

  DocumentReference<Map<String, dynamic>> _doc(String id) =>
      _fs.collection(_collection).doc(id);

  String _generateId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final list = List.generate(8, (_) => chars[rng.nextInt(chars.length)]);
    return list.join();
  }

  Future<TTRoom> createRoom({required String hostUid}) async {
    final id = _generateId();
    final side = DateTime.now().millisecondsSinceEpoch.isEven ? 'near' : 'far';
    final room = TTRoom(
      id: id,
      hostUid: hostUid,
      hostSide: side,
      status: TTRoomStatus.waiting,
      updatedAt: Timestamp.now(),
    );
    await _doc(id).set(room.toMap());
    return room;
  }

  Future<TTRoom?> findOpenRoom({required String myUid}) async {
    final snap = await _fs
        .collection(_collection)
        .where('status', isEqualTo: 'waiting')
        .where('hostUid', isNotEqualTo: myUid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return TTRoom.fromDoc(doc.id, doc.data());
  }

  Future<TTRoom> joinRoom({
    required String roomId,
    required String guestUid,
  }) async {
    final ref = _doc(roomId);
    final result = await ref.get();
    if (!result.exists) throw StateError('Room not found');
    final current = TTRoom.fromDoc(result.id, result.data());
    if (current.guestUid != null) throw StateError('Room already has a guest');
    if (current.status != TTRoomStatus.waiting) {
      throw StateError('Match already in progress');
    }
    if (current.hostUid == guestUid) {
      throw StateError('You cannot join your own room');
    }
    final updated = current.copyWith(
      guestUid: guestUid,
      status: TTRoomStatus.playing,
      lastTick: current.lastTick + 1,
      updatedAt: Timestamp.now(),
    );
    await ref.set(updated.toMap(), SetOptions(merge: true));
    return updated;
  }

  Stream<TTRoom> watchRoom(String roomId) {
    return _doc(roomId).snapshots().map((snap) {
      return TTRoom.fromDoc(snap.id, snap.data());
    });
  }

  Future<void> writeHostState({
    required String roomId,
    required int localTick,
    required double hostPaddleY,
    required BallState ball,
    required int hostScore,
    required int guestScore,
    required TTRoomStatus status,
  }) async {
    final ref = _doc(roomId);
    await _fs
        .runTransaction((txn) async {
          final snap = await txn.get(ref);
          if (!snap.exists) return;
          final serverTick = (snap.data()?['lastTick'] as int?) ?? 0;
          if (localTick < serverTick + 1) return;
          txn.update(ref, {
            'hostPaddleY': hostPaddleY,
            'ball': ball.toMap(),
            'hostScore': hostScore,
            'guestScore': guestScore,
            'status': status.name,
            'lastTick': localTick,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        })
        .catchError((e, st) {
          if (kDebugMode) debugPrint('writeHostState failed: $e');
        });
  }

  Future<void> writeGuestPaddle({
    required String roomId,
    required int localTick,
    required double guestPaddleY,
  }) async {
    final ref = _doc(roomId);
    await _fs
        .runTransaction((txn) async {
          final snap = await txn.get(ref);
          if (!snap.exists) return;
          final serverTick = (snap.data()?['lastTick'] as int?) ?? 0;
          if (localTick < serverTick + 1) return;
          txn.update(ref, {
            'guestPaddleY': guestPaddleY,
            'lastTick': localTick,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        })
        .catchError((e, st) {
          if (kDebugMode) debugPrint('writeGuestPaddle failed: $e');
        });
  }

  Future<void> endMatch({required String roomId}) async {
    final ref = _doc(roomId);
    await ref.update({
      'status': TTRoomStatus.finished.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRoom({required String roomId}) async {
    await _doc(roomId).delete();
  }

  Future<void> resetForRematch({required String roomId}) async {
    final ref = _doc(roomId);
    await _fs.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return;
      final current = TTRoom.fromDoc(snap.id, snap.data());
      final fresh = current.copyWith(
        hostScore: 0,
        guestScore: 0,
        ball: const BallState(),
        guestUid: null,
        status: TTRoomStatus.waiting,
        lastTick: current.lastTick + 1,
        updatedAt: Timestamp.now(),
      );
      txn.set(ref, fresh.toMap());
    });
  }
}
