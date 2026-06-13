import 'package:cloud_firestore/cloud_firestore.dart';

import 'hexgl_race_result.dart';

enum HexGLChallengeStatus {
  open,
  closed;

  static HexGLChallengeStatus fromName(String? name) {
    if (name == 'open') return HexGLChallengeStatus.open;
    return HexGLChallengeStatus.closed;
  }
}

class HexGLChallenge {
  final String challengeId;
  final String trackId;
  final String challengerId;
  final String? defenderId;
  final DateTime createdAt;
  final DateTime? closedAt;
  final HexGLChallengeStatus status;
  final HexGLRaceResult? challengerResult;
  final HexGLRaceResult? defenderResult;
  final String? winnerId;

  const HexGLChallenge({
    required this.challengeId,
    required this.trackId,
    required this.challengerId,
    this.defenderId,
    required this.createdAt,
    this.closedAt,
    this.status = HexGLChallengeStatus.open,
    this.challengerResult,
    this.defenderResult,
    this.winnerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'trackId': trackId,
      'challengerId': challengerId,
      'defenderId': defenderId,
      'createdAt': Timestamp.fromDate(createdAt),
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
      'status': status.name,
      'challengerResult': challengerResult?.toMap(),
      'defenderResult': defenderResult?.toMap(),
      'winnerId': winnerId,
    };
  }

  factory HexGLChallenge.fromMap(Map<String, dynamic> map, String docId) {
    HexGLRaceResult? parse(String key) {
      final raw = map[key];
      if (raw is Map) {
        return HexGLRaceResult.fromMap(Map<String, dynamic>.from(raw));
      }
      return null;
    }

    return HexGLChallenge(
      challengeId: docId,
      trackId: map['trackId'] ?? HexGLTrack.cityscape.id,
      challengerId: map['challengerId'] ?? '',
      defenderId: map['defenderId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      closedAt: (map['closedAt'] as Timestamp?)?.toDate(),
      status: HexGLChallengeStatus.fromName(map['status']),
      challengerResult: parse('challengerResult'),
      defenderResult: parse('defenderResult'),
      winnerId: map['winnerId'],
    );
  }

  factory HexGLChallenge.fromFirestore(DocumentSnapshot doc) {
    return HexGLChallenge.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  bool get isComplete =>
      status == HexGLChallengeStatus.closed &&
      challengerResult != null &&
      defenderResult != null;

  HexGLChallenge copyWith({
    String? defenderId,
    DateTime? closedAt,
    HexGLChallengeStatus? status,
    HexGLRaceResult? challengerResult,
    HexGLRaceResult? defenderResult,
    String? winnerId,
  }) {
    return HexGLChallenge(
      challengeId: challengeId,
      trackId: trackId,
      challengerId: challengerId,
      defenderId: defenderId ?? this.defenderId,
      createdAt: createdAt,
      closedAt: closedAt ?? this.closedAt,
      status: status ?? this.status,
      challengerResult: challengerResult ?? this.challengerResult,
      defenderResult: defenderResult ?? this.defenderResult,
      winnerId: winnerId ?? this.winnerId,
    );
  }
}
