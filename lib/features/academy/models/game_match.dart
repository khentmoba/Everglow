import 'package:cloud_firestore/cloud_firestore.dart';

class GameMatch {
  final String matchId;
  final String hostId;
  final String? participantId;
  final int khentScore;
  final int clairScore;
  final String status; // 'waiting', 'active', 'finished'
  final String currentQuestionId;
  final int questionIndex;
  final String category;
  final DateTime createdAt;
  final String? winnerId;
  final bool isReplenishing;

  GameMatch({
    required this.matchId,
    required this.hostId,
    this.participantId,
    required this.khentScore,
    required this.clairScore,
    required this.status,
    required this.currentQuestionId,
    required this.questionIndex,
    required this.category,
    required this.createdAt,
    this.winnerId,
    this.isReplenishing = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'participantId': participantId,
      'khentScore': khentScore,
      'clairScore': clairScore,
      'status': status,
      'currentQuestionId': currentQuestionId,
      'questionIndex': questionIndex,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'winnerId': winnerId,
      'isReplenishing': isReplenishing,
    };
  }

  factory GameMatch.fromMap(Map<String, dynamic> map, String docId) {
    return GameMatch(
      matchId: docId,
      hostId: map['hostId'] ?? '',
      participantId: map['participantId'],
      khentScore: map['khentScore'] ?? 0,
      clairScore: map['clairScore'] ?? 0,
      status: map['status'] ?? 'waiting',
      currentQuestionId: map['currentQuestionId'] ?? '',
      questionIndex: map['questionIndex'] ?? 0,
      category: map['category'] ?? 'engineering',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      winnerId: map['winnerId'],
      isReplenishing: map['isReplenishing'] ?? false,
    );
  }

  factory GameMatch.fromFirestore(DocumentSnapshot doc) {
    return GameMatch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  GameMatch copyWith({
    String? status,
    String? participantId,
    int? khentScore,
    int? clairScore,
    String? currentQuestionId,
    int? questionIndex,
    String? winnerId,
  }) {
    return GameMatch(
      matchId: matchId,
      hostId: hostId,
      participantId: participantId ?? this.participantId,
      khentScore: khentScore ?? this.khentScore,
      clairScore: clairScore ?? this.clairScore,
      status: status ?? this.status,
      currentQuestionId: currentQuestionId ?? this.currentQuestionId,
      questionIndex: questionIndex ?? this.questionIndex,
      category: category,
      createdAt: createdAt,
      winnerId: winnerId ?? this.winnerId,
    );
  }
}
