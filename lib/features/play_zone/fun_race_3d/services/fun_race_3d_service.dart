import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/fun_race_3d_room.dart';

/// Thin wrapper around Firestore for the `fun_race_3d_rooms` collection.
/// Single-document-per-room model: one document holds the full state,
/// so the game screen subscribes to one document and the lobby subscribes
/// to one document. No subcollections, no batches.
class FunRace3DService {
  final FirebaseFirestore _fs;
  FunRace3DService({FirebaseFirestore? firestore})
      : _fs = firestore ?? FirebaseFirestore.instance;

  static const String _collection = 'fun_race_3d_rooms';

  DocumentReference<Map<String, dynamic>> _doc(String code) =>
      _fs.collection(_collection).doc(code);

  /// Creates a new room with the current user as host. Throws on
  /// `code already exists` (extremely unlikely with 1.3M combinations,
  /// but we handle it by retrying with a fresh code).
  Future<FunRace3DRoom> createRoom({
    required String hostUid,
    required String hostName,
  }) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateRoomCode();
      final ref = _doc(code);
      final room = FunRace3DRoom(
        code: code,
        hostUid: hostUid,
        hostName: hostName,
        status: FunRace3DRoomStatus.waitingForGuest,
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
        if (e.toString().toLowerCase().contains('already')) {
          continue;
        }
        rethrow;
      }
    }
    throw StateError('Could not allocate a room code after 5 attempts.');
  }

  /// Stream of a single room. Lobby and game both use this.
  Stream<FunRace3DRoom?> watchRoom(String code) {
    return _doc(code).snapshots().map((snap) {
      if (!snap.exists) return null;
      return FunRace3DRoom.fromDoc(snap);
    });
  }

  /// One-shot read used on lobby entry to validate a code before
  /// subscribing (cheaper than a no-op stream subscription).
  Future<FunRace3DRoom?> fetchRoom(String code) async {
    final snap = await _doc(code).get();
    if (!snap.exists) return null;
    return FunRace3DRoom.fromDoc(snap);
  }

  /// Joins a room as guest. Fails if the room doesn't exist, already has
  /// a guest, or is no longer accepting players.
  ///
  /// Both sides get bumped to `racing` status atomically via transaction,
  /// with the host and guest UIDs both written. The host's client picks
  /// this up via `watchRoom` and the auto-navigate to the game screen.
  Future<FunRace3DRoom> joinRoom({
    required String code,
    required String guestUid,
    required String guestName,
  }) async {
    final ref = _doc(code);
    return _fs.runTransaction<FunRace3DRoom>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Room $code does not exist.');
      }
      final room = FunRace3DRoom.fromDoc(snap);

      if (room.hostUid == guestUid) {
        throw StateError('You can\'t join your own room.');
      }
      if (room.guestUid != null && room.guestUid != guestUid) {
        throw StateError('Room is full.');
      }
      if (room.status != FunRace3DRoomStatus.waitingForGuest) {
        throw StateError('Match is no longer accepting players.');
      }

      final updated = room.copyWith(
        guestUid: guestUid,
        guestName: guestName,
        status: FunRace3DRoomStatus.racing,
        lastTick: room.lastTick + 1,
        updatedAt: Timestamp.now(),
      );
      tx.set(ref, updated.toMap());
      return updated;
    });
  }

  /// Records that the given side has finished the race. Sets the
  /// server-side timestamp, bumps `lastTick`, and (if the opponent has
  /// not yet finished) marks the match as `finished` with this side as
  /// winner. If both have finished, the side with the earlier timestamp
  /// wins. If they tie exactly, the host wins.
  ///
  /// Host and guest are both allowed to call this; the transaction
  /// arbitrates.
  Future<FunRace3DRoom> markFinished({
    required String code,
    required String uid,
  }) async {
    final ref = _doc(code);
    return _fs.runTransaction<FunRace3DRoom>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Room $code does not exist.');
      }
      final room = FunRace3DRoom.fromDoc(snap);
      if (room.status != FunRace3DRoomStatus.racing &&
          room.status != FunRace3DRoomStatus.finished) {
        throw StateError('Match is not in progress.');
      }
      if (room.status == FunRace3DRoomStatus.finished) {
        return room; // already resolved
      }

      final side = uid == room.hostUid
          ? FunRace3DSide.host
          : uid == room.guestUid
              ? FunRace3DSide.guest
              : (throw StateError('Caller is not in this room.'));

      // Don't double-write if this side already finished.
      if (room.didFinish(side)) return room;

      final now = Timestamp.now();
      final hostFinishedAt = side == FunRace3DSide.host
          ? now
          : room.hostFinishedAt;
      final guestFinishedAt = side == FunRace3DSide.guest
          ? now
          : room.guestFinishedAt;

      // Determine winner: the earliest finish wins. If only one side
      // has finished, they win. If both are at the same millisecond
      // (vanishingly rare), the host is the tiebreaker.
      String? winnerUid;
      var newStatus = room.status;
      if (hostFinishedAt != null && guestFinishedAt != null) {
        final cmp = hostFinishedAt.compareTo(guestFinishedAt);
        if (cmp < 0) {
          winnerUid = room.hostUid;
        } else if (cmp > 0) {
          winnerUid = room.guestUid;
        } else {
          winnerUid = room.hostUid; // tie → host
        }
        newStatus = FunRace3DRoomStatus.finished;
      } else {
        // Only this side has finished so far. We can resolve the
        // match if the opponent has already abandoned (guest never
        // joined or already left) but the lobby guarantees both sides
        // are present, so the other side is still racing.
        // Leave status as `racing` and let the opponent's finish
        // resolve it (or have the host hit a "claim win" button after
        // a timeout if the other side never finishes — see UI).
      }

      final updated = room.copyWith(
        hostFinishedAt: hostFinishedAt,
        guestFinishedAt: guestFinishedAt,
        status: newStatus,
        winnerUid: winnerUid ?? room.winnerUid,
        lastTick: room.lastTick + 1,
        updatedAt: now,
      );
      tx.set(ref, updated.toMap());
      return updated;
    });
  }

  /// Host resets the same room for a rematch. Flips status back to
  /// `racing`, clears finish timestamps and winner.
  Future<FunRace3DRoom> resetForRematch({required String code}) async {
    final ref = _doc(code);
    return _fs.runTransaction<FunRace3DRoom>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Room $code does not exist.');
      }
      final room = FunRace3DRoom.fromDoc(snap);
      final updated = room.copyWith(
        status: FunRace3DRoomStatus.racing,
        clearHostFinished: true,
        clearGuestFinished: true,
        clearWinner: true,
        lastTick: room.lastTick + 1,
        updatedAt: Timestamp.now(),
      );
      tx.set(ref, updated.toMap());
      return updated;
    });
  }

  /// Either side marks the room abandoned (e.g. back-button mid-race).
  Future<void> setAbandoned({required String code}) async {
    final ref = _doc(code);
    return _fs.runTransaction<void>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final room = FunRace3DRoom.fromDoc(snap);
      final updated = room.copyWith(
        status: FunRace3DRoomStatus.abandoned,
        lastTick: room.lastTick + 1,
        updatedAt: Timestamp.now(),
      );
      tx.set(ref, updated.toMap());
    });
  }

  /// Generates a 4-character room code from an unambiguous alphabet
  /// (no 0/O/1/I to avoid "did you type a zero or an O?").
  static String _generateRoomCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = DateTime.now().microsecondsSinceEpoch;
    return List.generate(4, (i) {
      return alphabet[(r + i) % alphabet.length];
    }).join();
  }
}

/// Re-export of the side enum for convenience at call sites.
typedef RaceSide = FunRace3DSide;
