import 'package:cloud_firestore/cloud_firestore.dart';

enum AssaultMatchStatus { waiting, active, finished }

class AssaultMatch {
  final String matchId;
  final String hostId;
  final String? participantId;
  final AssaultMatchStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int hostHp;
  final int participantHp;
  final int hostKills;
  final int participantKills;
  final String? winnerId;
  final String? loserId;

  const AssaultMatch({
    required this.matchId,
    required this.hostId,
    this.participantId,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.hostHp = 100,
    this.participantHp = 100,
    this.hostKills = 0,
    this.participantKills = 0,
    this.winnerId,
    this.loserId,
  });

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'participantId': participantId,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'finishedAt': finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
      'hostHp': hostHp,
      'participantHp': participantHp,
      'hostKills': hostKills,
      'participantKills': participantKills,
      'winnerId': winnerId,
      'loserId': loserId,
    };
  }

  factory AssaultMatch.fromMap(Map<String, dynamic> map, String docId) {
    return AssaultMatch(
      matchId: docId,
      hostId: map['hostId'] ?? '',
      participantId: map['participantId'],
      status: _parseStatus(map['status']),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
      finishedAt: (map['finishedAt'] as Timestamp?)?.toDate(),
      hostHp: (map['hostHp'] as num?)?.toInt() ?? 100,
      participantHp: (map['participantHp'] as num?)?.toInt() ?? 100,
      hostKills: (map['hostKills'] as num?)?.toInt() ?? 0,
      participantKills: (map['participantKills'] as num?)?.toInt() ?? 0,
      winnerId: map['winnerId'],
      loserId: map['loserId'],
    );
  }

  factory AssaultMatch.fromFirestore(DocumentSnapshot doc) {
    return AssaultMatch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  static AssaultMatchStatus _parseStatus(dynamic raw) {
    if (raw is String) {
      return AssaultMatchStatus.values.firstWhere(
        (s) => s.name == raw,
        orElse: () => AssaultMatchStatus.waiting,
      );
    }
    return AssaultMatchStatus.waiting;
  }

  AssaultMatch copyWith({
    String? participantId,
    AssaultMatchStatus? status,
    DateTime? startedAt,
    DateTime? finishedAt,
    int? hostHp,
    int? participantHp,
    int? hostKills,
    int? participantKills,
    String? winnerId,
    String? loserId,
  }) {
    return AssaultMatch(
      matchId: matchId,
      hostId: hostId,
      participantId: participantId ?? this.participantId,
      status: status ?? this.status,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      hostHp: hostHp ?? this.hostHp,
      participantHp: participantHp ?? this.participantHp,
      hostKills: hostKills ?? this.hostKills,
      participantKills: participantKills ?? this.participantKills,
      winnerId: winnerId ?? this.winnerId,
      loserId: loserId ?? this.loserId,
    );
  }
}
