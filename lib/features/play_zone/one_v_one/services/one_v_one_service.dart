import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/one_v_one_room.dart';

/// Thin wrapper around Firestore for the `one_v_one_rooms` collection.
/// Single-document-per-room model: one document holds the full state,
/// so the game screen subscribes to one document and the lobby subscribes
/// to one document. No subcollections, no batches.
class OneVOneService {
  final FirebaseFirestore _fs;
  OneVOneService({FirebaseFirestore? firestore})
      : _fs = firestore ?? FirebaseFirestore.instance;

  /// Collection name. Single collection keeps queries simple; we never
  /// list all rooms client-side.
  static const String _collection = 'one_v_one_rooms';

  DocumentReference<Map<String, dynamic>> _doc(String code) =>
      _fs.collection(_collection).doc(code);

  /// Creates a new room with the current user as host. Throws on
  /// `code already exists` (extremely unlikely with 1.3M combinations,
  /// but we handle it by retrying with a fresh code).
  Future<OneVOneRoom> createRoom({
    required String hostUid,
    required String hostName,
  }) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = generateRoomCode();
      final ref = _doc(code);
      final room = OneVOneRoom(
        code: code,
        hostUid: hostUid,
        hostName: hostName,
        status: RoomStatus.waitingForGuest,
        ball: BallState.serve(server: OneVOneSide.host),
        updatedAt: Timestamp.now(),
      );
      try {
        await ref.set(room.toMap());
        return room;
      } on FirebaseException catch (e) {
        if (e.code == 'already-exists') {
          continue; // extremely rare, try again
        }
        rethrow;
      } on Exception catch (e) {
        // Some platforms report the conflict as a generic exception.
        if (e.toString().toLowerCase().contains('already')) {
          continue;
        }
        rethrow;
      }
    }
    throw StateError('Could not allocate a room code after 5 attempts.');
  }

  /// Stream of a single room. Lobby and game both use this.
  Stream<OneVOneRoom?> watchRoom(String code) {
    return _doc(code).snapshots().map((snap) {
      if (!snap.exists) return null;
      return OneVOneRoom.fromDoc(snap);
    });
  }

  /// One-shot read used on lobby entry to validate a code before
  /// subscribing (cheaper than a no-op stream subscription).
  Future<OneVOneRoom?> fetchRoom(String code) async {
    final snap = await _doc(code).get();
    if (!snap.exists) return null;
    return OneVOneRoom.fromDoc(snap);
  }

  /// Joins a room as guest. Fails if the room doesn't exist, already has
  /// a guest, or is no longer accepting players.
  Future<OneVOneRoom> joinRoom({
    required String code,
    required String guestUid,
    required String guestName,
  }) async {
    final ref = _doc(code);
    final result = await ref.get();
    if (!result.exists) {
      throw StateError('Room not found');
    }
    final current = OneVOneRoom.fromDoc(result);
    if (current.guestUid != null && current.guestUid != guestUid) {
      throw StateError('Room is full');
    }
    if (current.status != RoomStatus.waitingForGuest) {
      throw StateError('Match already in progress');
    }
    if (current.hostUid == guestUid) {
      throw StateError('You cannot join your own room');
    }

    // The host's run loop is the authoritative state owner: the host runs
    // the simulation, the guest sends paddle input only. We mark the room
    // inProgress here so the host's run loop picks it up and starts the
    // ball. `lastTick` is bumped to force the host to read fresh state.
    final updated = current.copyWith(
      guestUid: guestUid,
      guestName: guestName,
      status: RoomStatus.inProgress,
      server: current.server, // server-side choice preserved
      lastTick: current.lastTick + 1,
      updatedAt: Timestamp.now(),
    );
    await ref.set(updated.toMap(), SetOptions(merge: true));
    return updated;
  }

  /// Host calls this from its game tick to write ball + host paddle
  /// + score. We use `lastTick` as a fencing token: if the local tick
  /// is no longer >= the server's lastTick+1 we drop the write to
  /// avoid stomping on a more recent update.
  Future<void> writeHostState({
    required String code,
    required int localTick,
    required BallState ball,
    required PaddleState hostPaddle,
    required int hostScore,
    required int guestScore,
    required OneVOneSide server,
    required RoomStatus status,
    String? winnerUid,
  }) async {
    final ref = _doc(code);
    await _fs.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return;
      final serverTick = (snap.data()?['lastTick'] as int?) ?? 0;
      // Bail if our local view is stale; the next tick will retry.
      if (localTick < serverTick + 1) return;
      txn.update(ref, {
        'ball': ball.toMap(),
        'hostPaddle': hostPaddle.toMap(),
        'hostScore': hostScore,
        'guestScore': guestScore,
        'server': server == OneVOneSide.host ? 'host' : 'guest',
        'status': _statusToString(status),
        'winnerUid': winnerUid,
        'lastTick': localTick,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }).catchError((e, st) {
      if (kDebugMode) debugPrint('writeHostState failed: $e');
    });
  }

  /// Guest calls this to send paddle position. Guest is *not* allowed
  /// to touch ball, score, or status. The transaction guards that.
  Future<void> writeGuestPaddle({
    required String code,
    required int localTick,
    required PaddleState guestPaddle,
  }) async {
    final ref = _doc(code);
    await _fs.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return;
      final serverTick = (snap.data()?['lastTick'] as int?) ?? 0;
      if (localTick < serverTick + 1) return;
      txn.update(ref, {
        'guestPaddle': guestPaddle.toMap(),
        'lastTick': localTick,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }).catchError((e, st) {
      if (kDebugMode) debugPrint('writeGuestPaddle failed: $e');
    });
  }

  /// Either side can call this to mark the match as finished/abandoned
  /// (e.g. when one player navigates away mid-match).
  Future<void> setStatus({
    required String code,
    required RoomStatus status,
    String? winnerUid,
  }) async {
    final ref = _doc(code);
    await _fs.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return;
      final current = (snap.data()?['lastTick'] as int?) ?? 0;
      txn.update(ref, {
        'status': _statusToString(status),
        'winnerUid': winnerUid,
        'lastTick': current + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Reset the room back to waiting so the same pair can play again
  /// with a new match. Only callable by the host.
  Future<void> resetForRematch({required String code}) async {
    final ref = _doc(code);
    await _fs.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return;
      final current = OneVOneRoom.fromDoc(snap);
      final fresh = current.copyWith(
        status: RoomStatus.inProgress,
        hostScore: 0,
        guestScore: 0,
        server: oppositeOf(current.server),
        hostPaddle: PaddleState.initial(),
        guestPaddle: PaddleState.initial(),
        ball: BallState.serve(server: oppositeOf(current.server)),
        winnerUid: null,
        lastTick: current.lastTick + 1,
        updatedAt: Timestamp.now(),
      );
      txn.set(ref, fresh.toMap());
    });
  }

  static String _statusToString(RoomStatus s) {
    switch (s) {
      case RoomStatus.waitingForGuest:
        return 'waitingForGuest';
      case RoomStatus.inProgress:
        return 'inProgress';
      case RoomStatus.finished:
        return 'finished';
      case RoomStatus.abandoned:
        return 'abandoned';
    }
  }
}
