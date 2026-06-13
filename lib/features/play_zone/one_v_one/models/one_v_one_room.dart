import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Stable slot in a 1v1 room. Always exactly two.
enum OneVOneSide { host, guest }

OneVOneSide oppositeOf(OneVOneSide s) =>
    s == OneVOneSide.host ? OneVOneSide.guest : OneVOneSide.host;

/// Top-level status of the room. The lobby UI is driven almost entirely
/// off this; the game screen also watches it for `inProgress`/`finished`.
enum RoomStatus {
  waitingForGuest,
  inProgress,
  finished,
  abandoned,
}

RoomStatus roomStatusFromString(String? s) {
  switch (s) {
    case 'inProgress':
      return RoomStatus.inProgress;
    case 'finished':
      return RoomStatus.finished;
    case 'abandoned':
      return RoomStatus.abandoned;
    case 'waitingForGuest':
    default:
      return RoomStatus.waitingForGuest;
  }
}

/// A single player's paddle y-position, normalised 0..1 (0 = top of canvas,
/// 1 = bottom). We only sync the y, not the full state, so updates are
/// small and the host client can render the opponent instantly.
class PaddleState {
  final double y;
  final double v; // current paddle velocity in y/sec, used to impart spin

  const PaddleState({required this.y, required this.v});

  factory PaddleState.initial() => const PaddleState(y: 0.5, v: 0);

  Map<String, dynamic> toMap() => {'y': y, 'v': v};

  factory PaddleState.fromMap(Map<String, dynamic>? m) {
    if (m == null) return PaddleState.initial();
    return PaddleState(
      y: (m['y'] as num?)?.toDouble() ?? 0.5,
      v: (m['v'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Ball state. Positions and velocity are normalised to the canvas
/// (0..1 in both axes), so the renderer scales them to the actual widget.
class BallState {
  final double x;
  final double y;
  final double vx;
  final double vy;

  const BallState({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });

  factory BallState.serve({required OneVOneSide server}) {
    // Ball starts at centre, drifts gently toward the server.
    final dir = server == OneVOneSide.host ? 1.0 : -1.0;
    return BallState(x: 0.5, y: 0.5, vx: 0.25 * dir, vy: 0);
  }

  Map<String, dynamic> toMap() => {'x': x, 'y': y, 'vx': vx, 'vy': vy};

  factory BallState.fromMap(Map<String, dynamic>? m) {
    if (m == null) return BallState.serve(server: OneVOneSide.host);
    return BallState(
      x: (m['x'] as num?)?.toDouble() ?? 0.5,
      y: (m['y'] as num?)?.toDouble() ?? 0.5,
      vx: (m['vx'] as num?)?.toDouble() ?? 0,
      vy: (m['vy'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// The shape of `rooms/{code}` in Firestore. We keep it intentionally flat
/// (no subcollections) so a single `get()` / `set(merge:true)` round-trips
/// the whole game state. Two players ping-pong the `lastTick` counter and
/// trust the most recent write from either side.
class OneVOneRoom {
  /// 4-letter room code, e.g. "K7QP". Uppercased, unambiguous alphabet.
  final String code;
  final String hostUid;
  final String hostName;
  final String? guestUid;
  final String? guestName;
  final RoomStatus status;
  final int hostScore;
  final int guestScore;

  /// Whose turn to serve next. Flips on every point.
  final OneVOneSide server;

  /// Paddle positions are owned by each player; we store them under the
  /// player's side. The other client reads but never writes.
  final PaddleState hostPaddle;
  final PaddleState guestPaddle;
  final BallState ball;

  /// Monotonic counter incremented on every authoritative state write.
  /// Clients use this to drop stale writes (network reordering, two
  /// writes racing, etc.).
  final int lastTick;

  /// Server-side timestamp of the last write. Set by Firestore; not trusted
  /// for ordering (clocks differ between devices).
  final Timestamp updatedAt;

  /// Optional winner for finished rooms.
  final String? winnerUid;

  const OneVOneRoom({
    required this.code,
    required this.hostUid,
    required this.hostName,
    this.guestUid,
    this.guestName,
    this.status = RoomStatus.waitingForGuest,
    this.hostScore = 0,
    this.guestScore = 0,
    this.server = OneVOneSide.host,
    this.hostPaddle = const PaddleState(y: 0.5, v: 0),
    this.guestPaddle = const PaddleState(y: 0.5, v: 0),
    required this.ball,
    this.lastTick = 0,
    required this.updatedAt,
    this.winnerUid,
  });

  OneVOneRoom copyWith({
    String? guestUid,
    String? guestName,
    RoomStatus? status,
    int? hostScore,
    int? guestScore,
    OneVOneSide? server,
    PaddleState? hostPaddle,
    PaddleState? guestPaddle,
    BallState? ball,
    int? lastTick,
    Timestamp? updatedAt,
    String? winnerUid,
    bool clearGuest = false,
  }) {
    return OneVOneRoom(
      code: code,
      hostUid: hostUid,
      hostName: hostName,
      guestUid: clearGuest ? null : (guestUid ?? this.guestUid),
      guestName: clearGuest ? null : (guestName ?? this.guestName),
      status: status ?? this.status,
      hostScore: hostScore ?? this.hostScore,
      guestScore: guestScore ?? this.guestScore,
      server: server ?? this.server,
      hostPaddle: hostPaddle ?? this.hostPaddle,
      guestPaddle: guestPaddle ?? this.guestPaddle,
      ball: ball ?? this.ball,
      lastTick: lastTick ?? this.lastTick,
      updatedAt: updatedAt ?? this.updatedAt,
      winnerUid: winnerUid ?? this.winnerUid,
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'hostUid': hostUid,
        'hostName': hostName,
        'guestUid': guestUid,
        'guestName': guestName,
        'status': _statusToString(status),
        'hostScore': hostScore,
        'guestScore': guestScore,
        'server': server == OneVOneSide.host ? 'host' : 'guest',
        'hostPaddle': hostPaddle.toMap(),
        'guestPaddle': guestPaddle.toMap(),
        'ball': ball.toMap(),
        'lastTick': lastTick,
        'updatedAt': updatedAt,
        'winnerUid': winnerUid,
      };

  factory OneVOneRoom.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const {};
    return OneVOneRoom(
      code: (d['code'] as String?) ?? doc.id,
      hostUid: (d['hostUid'] as String?) ?? '',
      hostName: (d['hostName'] as String?) ?? 'Host',
      guestUid: d['guestUid'] as String?,
      guestName: d['guestName'] as String?,
      status: roomStatusFromString(d['status'] as String?),
      hostScore: (d['hostScore'] as int?) ?? 0,
      guestScore: (d['guestScore'] as int?) ?? 0,
      server: (d['server'] as String?) == 'guest'
          ? OneVOneSide.guest
          : OneVOneSide.host,
      hostPaddle: PaddleState.fromMap(
        d['hostPaddle'] is Map<String, dynamic>
            ? d['hostPaddle'] as Map<String, dynamic>
            : null,
      ),
      guestPaddle: PaddleState.fromMap(
        d['guestPaddle'] is Map<String, dynamic>
            ? d['guestPaddle'] as Map<String, dynamic>
            : null,
      ),
      ball: BallState.fromMap(
        d['ball'] is Map<String, dynamic>
            ? d['ball'] as Map<String, dynamic>
            : null,
      ),
      lastTick: (d['lastTick'] as int?) ?? 0,
      updatedAt: (d['updatedAt'] as Timestamp?) ?? Timestamp.now(),
      winnerUid: d['winnerUid'] as String?,
    );
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

/// Generates a 4-character room code from an unambiguous alphabet
/// (no 0/O/1/I to avoid "did you type a zero or an O?").
String generateRoomCode({Random? rng}) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = rng ?? Random.secure();
  return List.generate(4, (_) => alphabet[r.nextInt(alphabet.length)]).join();
}

bool isValidRoomCode(String s) {
  if (s.length != 4) return false;
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  for (final ch in s.codeUnits) {
    if (!alphabet.codeUnits.contains(ch)) return false;
  }
  return true;
}
