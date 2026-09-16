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
      hostId: _toStr(map['hostId']),
      participantId: _toNullableStr(map['participantId']),
      khentScore: _toInt(map['khentScore']),
      clairScore: _toInt(map['clairScore']),
      status: _toStr(map['status'], fallback: 'waiting'),
      currentQuestionId: _toStr(map['currentQuestionId']),
      questionIndex: _toInt(map['questionIndex']),
      category: _toStr(map['category'], fallback: 'engineering'),
      createdAt: _toDate(map['createdAt']),
      winnerId: _toNullableStr(map['winnerId']),
      isReplenishing: map['isReplenishing'] is bool
          ? map['isReplenishing'] as bool
          : false,
    );
  }

  static String _toStr(dynamic value, {String fallback = ''}) =>
      value is String ? value : fallback;

  static String? _toNullableStr(dynamic value) =>
      value is String ? value : null;

  static int _toInt(dynamic value) => value is num ? value.toInt() : 0;

  static DateTime _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  factory GameMatch.fromFirestore(DocumentSnapshot doc) {
    return GameMatch.fromMap(doc.data() as Map<String, dynamic>? ?? const {}, doc.id);
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
