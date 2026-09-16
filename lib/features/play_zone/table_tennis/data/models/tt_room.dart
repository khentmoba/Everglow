import 'package:cloud_firestore/cloud_firestore.dart';

enum TTRoomStatus { waiting, playing, finished, abandoned }

TTRoomStatus ttRoomStatusFromString(String? s) {
  switch (s) {
    case 'playing':
      return TTRoomStatus.playing;
    case 'finished':
      return TTRoomStatus.finished;
    case 'abandoned':
      return TTRoomStatus.abandoned;
    default:
      return TTRoomStatus.waiting;
  }
}

class BallState {
  final double x;
  final double y;
  final double vx;
  final double vy;

  const BallState({this.x = 0, this.y = 0, this.vx = 0, this.vy = 0});

  Map<String, dynamic> toMap() => {'x': x, 'y': y, 'vx': vx, 'vy': vy};

  factory BallState.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const BallState();
    return BallState(
      x: (m['x'] as num?)?.toDouble() ?? 0,
      y: (m['y'] as num?)?.toDouble() ?? 0,
      vx: (m['vx'] as num?)?.toDouble() ?? 0,
      vy: (m['vy'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TTRoom {
  final String id;
  final String hostUid;
  final String? guestUid;
  final String hostSide;
  final TTRoomStatus status;
  final double hostPaddleY;
  final double guestPaddleY;
  final BallState ball;
  final int hostScore;
  final int guestScore;
  final int lastTick;
  final Timestamp updatedAt;

  const TTRoom({
    required this.id,
    required this.hostUid,
    this.guestUid,
    this.hostSide = 'near',
    this.status = TTRoomStatus.waiting,
    this.hostPaddleY = 0.5,
    this.guestPaddleY = 0.5,
    this.ball = const BallState(),
    this.hostScore = 0,
    this.guestScore = 0,
    this.lastTick = 0,
    required this.updatedAt,
  });

  TTRoom copyWith({
    String? guestUid,
    String? hostSide,
    TTRoomStatus? status,
    double? hostPaddleY,
    double? guestPaddleY,
    BallState? ball,
    int? hostScore,
    int? guestScore,
    int? lastTick,
    Timestamp? updatedAt,
  }) {
    return TTRoom(
      id: id,
      hostUid: hostUid,
      guestUid: guestUid ?? this.guestUid,
      hostSide: hostSide ?? this.hostSide,
      status: status ?? this.status,
      hostPaddleY: hostPaddleY ?? this.hostPaddleY,
      guestPaddleY: guestPaddleY ?? this.guestPaddleY,
      ball: ball ?? this.ball,
      hostScore: hostScore ?? this.hostScore,
      guestScore: guestScore ?? this.guestScore,
      lastTick: lastTick ?? this.lastTick,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'hostUid': hostUid,
    'guestUid': guestUid,
    'hostSide': hostSide,
    'status': status.name,
    'hostPaddleY': hostPaddleY,
    'guestPaddleY': guestPaddleY,
    'ball': ball.toMap(),
    'hostScore': hostScore,
    'guestScore': guestScore,
    'lastTick': lastTick,
    'updatedAt': updatedAt,
  };

  factory TTRoom.fromDoc(String docId, Map<String, dynamic>? data) {
    if (data == null) {
      return TTRoom(id: docId, hostUid: '', updatedAt: Timestamp.now());
    }
    return TTRoom(
      id: docId,
      hostUid: (data['hostUid'] as String?) ?? '',
      guestUid: data['guestUid'] as String?,
      hostSide: (data['hostSide'] as String?) ?? 'near',
      status: ttRoomStatusFromString(data['status'] as String?),
      hostPaddleY: ((data['hostPaddleY'] as num?)?.toDouble() ?? 0.5),
      guestPaddleY: ((data['guestPaddleY'] as num?)?.toDouble() ?? 0.5),
      ball: BallState.fromMap(
        data['ball'] is Map<String, dynamic>
            ? data['ball'] as Map<String, dynamic>
            : null,
      ),
      hostScore: (data['hostScore'] as int?) ?? 0,
      guestScore: (data['guestScore'] as int?) ?? 0,
      lastTick: (data['lastTick'] as int?) ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?) ?? Timestamp.now(),
    );
  }
}
