import 'package:cloud_firestore/cloud_firestore.dart';

/// Stable slot in a Fun Race 3D 1v1 room. Always exactly two.
enum FunRace3DSide { host, guest }

/// Top-level status of the room. Drives the lobby UI and the
/// finished/abandoned transitions on the game screen.
enum FunRace3DRoomStatus {
  waitingForGuest,
  racing,
  finished,
  abandoned,
}

FunRace3DRoomStatus funRace3DRoomStatusFromString(String? s) {
  switch (s) {
    case 'racing':
      return FunRace3DRoomStatus.racing;
    case 'finished':
      return FunRace3DRoomStatus.finished;
    case 'abandoned':
      return FunRace3DRoomStatus.abandoned;
    case 'waitingForGuest':
    default:
      return FunRace3DRoomStatus.waitingForGuest;
  }
}

/// Single Firestore document holding the full state of a Fun Race 3D
/// 1v1 match. Flat (no subcollections) so a single `get()` /
/// `set(merge: true)` round-trips everything.
class FunRace3DRoom {
  /// 4-letter room code, e.g. "K7QP". Uppercased, unambiguous alphabet.
  final String code;

  final String hostUid;
  final String hostName;
  final String? guestUid;
  final String? guestName;

  final FunRace3DRoomStatus status;

  /// Server-side timestamps captured when each player taps "I finished!".
  /// The host that finishes first is the winner; if both finish within
  /// the same server millisecond the host is the tiebreaker.
  final Timestamp? hostFinishedAt;
  final Timestamp? guestFinishedAt;

  /// UID of the winning side, set when status transitions to `finished`.
  final String? winnerUid;

  /// Monotonic counter incremented on every authoritative state write.
  /// Used to drop stale writes.
  final int lastTick;

  /// Server-side timestamp of the last write. Set by Firestore; not
  /// trusted for ordering.
  final Timestamp updatedAt;

  const FunRace3DRoom({
    required this.code,
    required this.hostUid,
    required this.hostName,
    this.guestUid,
    this.guestName,
    this.status = FunRace3DRoomStatus.waitingForGuest,
    this.hostFinishedAt,
    this.guestFinishedAt,
    this.winnerUid,
    this.lastTick = 0,
    required this.updatedAt,
  });

  FunRace3DRoom copyWith({
    String? guestUid,
    String? guestName,
    FunRace3DRoomStatus? status,
    Timestamp? hostFinishedAt,
    Timestamp? guestFinishedAt,
    String? winnerUid,
    int? lastTick,
    Timestamp? updatedAt,
    bool clearGuest = false,
    bool clearHostFinished = false,
    bool clearGuestFinished = false,
    bool clearWinner = false,
  }) {
    return FunRace3DRoom(
      code: code,
      hostUid: hostUid,
      hostName: hostName,
      guestUid: clearGuest ? null : (guestUid ?? this.guestUid),
      guestName: clearGuest ? null : (guestName ?? this.guestName),
      status: status ?? this.status,
      hostFinishedAt: clearHostFinished
          ? null
          : (hostFinishedAt ?? this.hostFinishedAt),
      guestFinishedAt: clearGuestFinished
          ? null
          : (guestFinishedAt ?? this.guestFinishedAt),
      winnerUid: clearWinner ? null : (winnerUid ?? this.winnerUid),
      lastTick: lastTick ?? this.lastTick,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// True if this side has already tapped "I finished!".
  bool didFinish(FunRace3DSide side) {
    switch (side) {
      case FunRace3DSide.host:
        return hostFinishedAt != null;
      case FunRace3DSide.guest:
        return guestFinishedAt != null;
    }
  }

  /// Earliest finish timestamp of the two, or null if neither finished.
  Timestamp? earliestFinish() {
    final h = hostFinishedAt;
    final g = guestFinishedAt;
    if (h == null) return g;
    if (g == null) return h;
    return h.compareTo(g) <= 0 ? h : g;
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'hostUid': hostUid,
        'hostName': hostName,
        'guestUid': guestUid,
        'guestName': guestName,
        'status': _statusToString(status),
        'hostFinishedAt': hostFinishedAt,
        'guestFinishedAt': guestFinishedAt,
        'winnerUid': winnerUid,
        'lastTick': lastTick,
        'updatedAt': updatedAt,
      };

  factory FunRace3DRoom.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const {};
    return FunRace3DRoom(
      code: (d['code'] as String?) ?? doc.id,
      hostUid: (d['hostUid'] as String?) ?? '',
      hostName: (d['hostName'] as String?) ?? 'Host',
      guestUid: d['guestUid'] as String?,
      guestName: d['guestName'] as String?,
      status: funRace3DRoomStatusFromString(d['status'] as String?),
      hostFinishedAt: d['hostFinishedAt'] as Timestamp?,
      guestFinishedAt: d['guestFinishedAt'] as Timestamp?,
      winnerUid: d['winnerUid'] as String?,
      lastTick: (d['lastTick'] as int?) ?? 0,
      updatedAt: (d['updatedAt'] as Timestamp?) ?? Timestamp.now(),
    );
  }

  static String _statusToString(FunRace3DRoomStatus s) {
    switch (s) {
      case FunRace3DRoomStatus.waitingForGuest:
        return 'waitingForGuest';
      case FunRace3DRoomStatus.racing:
        return 'racing';
      case FunRace3DRoomStatus.finished:
        return 'finished';
      case FunRace3DRoomStatus.abandoned:
        return 'abandoned';
    }
  }
}
