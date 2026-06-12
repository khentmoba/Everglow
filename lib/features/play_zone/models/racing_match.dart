import 'package:cloud_firestore/cloud_firestore.dart';

class RacingMatch {
  final String matchId;
  final String hostId;
  final String? participantId;
  final String status;
  final DateTime createdAt;
  final num? hostTime;
  final num? participantTime;
  final String? winnerId;

  RacingMatch({
    required this.matchId,
    required this.hostId,
    this.participantId,
    required this.status,
    required this.createdAt,
    this.hostTime,
    this.participantTime,
    this.winnerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'participantId': participantId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'hostTime': hostTime,
      'participantTime': participantTime,
      'winnerId': winnerId,
    };
  }

  factory RacingMatch.fromMap(Map<String, dynamic> map, String docId) {
    return RacingMatch(
      matchId: docId,
      hostId: map['hostId'] ?? '',
      participantId: map['participantId'],
      status: map['status'] ?? 'waiting',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hostTime: map['hostTime'],
      participantTime: map['participantTime'],
      winnerId: map['winnerId'],
    );
  }

  factory RacingMatch.fromFirestore(DocumentSnapshot doc) {
    return RacingMatch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  RacingMatch copyWith({
    String? participantId,
    String? status,
    num? hostTime,
    num? participantTime,
    String? winnerId,
  }) {
    return RacingMatch(
      matchId: matchId,
      hostId: hostId,
      participantId: participantId ?? this.participantId,
      status: status ?? this.status,
      createdAt: createdAt,
      hostTime: hostTime ?? this.hostTime,
      participantTime: participantTime ?? this.participantTime,
      winnerId: winnerId ?? this.winnerId,
    );
  }
}
