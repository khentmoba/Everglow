import 'package:cloud_firestore/cloud_firestore.dart';

class GameMatch {
  final String matchId;
  // Firebase Auth UIDs (rules compare against request.auth.uid).
  final String hostId;
  final String? participantId;
  // Usernames (khentsgdz / clairjassen / ...) for display + scoring.
  final String? hostUsername;
  final String? participantUsername;
  // Scores by side: host on the left, guest on the right.
  final int hostScore;
  final int guestScore;
  final String status; // 'waiting', 'active', 'finished'
  final String currentQuestionId;
  final int questionIndex;
  // Shared question order, snapshotted at creation so both phones
  // see the same questions. Empty on legacy docs (pre-refresh).
  final List<String> questionIds;
  final String category;
  final DateTime createdAt;
  // Winner username or 'draw'.
  final String? winnerId;
  final bool isReplenishing;

  GameMatch({
    required this.matchId,
    required this.hostId,
    this.participantId,
    this.hostUsername,
    this.participantUsername,
    required this.hostScore,
    required this.guestScore,
    required this.status,
    required this.currentQuestionId,
    required this.questionIndex,
    this.questionIds = const [],
    required this.category,
    required this.createdAt,
    this.winnerId,
    this.isReplenishing = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'participantId': participantId,
      if (hostUsername != null) 'hostUsername': hostUsername,
      if (participantUsername != null)
        'participantUsername': participantUsername,
      'hostScore': hostScore,
      'guestScore': guestScore,
      'status': status,
      'currentQuestionId': currentQuestionId,
      'questionIndex': questionIndex,
      'questionIds': questionIds,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'winnerId': winnerId,
      'isReplenishing': isReplenishing,
    };
  }

  factory GameMatch.fromMap(Map<String, dynamic> map, String docId) {
    final idsRaw = map['questionIds'];
    return GameMatch(
      matchId: docId,
      hostId: _toStr(map['hostId']),
      participantId: _toNullableStr(map['participantId']),
      hostUsername: _toNullableStr(map['hostUsername']),
      participantUsername: _toNullableStr(map['participantUsername']),
      // Legacy docs stored khentScore / clairScore; read them as sides.
      hostScore: _toInt(map['hostScore'] ?? map['khentScore']),
      guestScore: _toInt(map['guestScore'] ?? map['clairScore']),
      status: _toStr(map['status'], fallback: 'waiting'),
      currentQuestionId: _toStr(map['currentQuestionId']),
      questionIndex: _toInt(map['questionIndex']),
      questionIds: idsRaw is List
          ? idsRaw.map((e) => e.toString()).toList()
          : const [],
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
    return GameMatch.fromMap(
      doc.data() as Map<String, dynamic>? ?? const {},
      doc.id,
    );
  }

  GameMatch copyWith({
    String? status,
    String? participantId,
    String? participantUsername,
    int? hostScore,
    int? guestScore,
    String? currentQuestionId,
    int? questionIndex,
    List<String>? questionIds,
    String? winnerId,
    bool? isReplenishing,
  }) {
    return GameMatch(
      matchId: matchId,
      hostId: hostId,
      participantId: participantId ?? this.participantId,
      hostUsername: hostUsername,
      participantUsername: participantUsername ?? this.participantUsername,
      hostScore: hostScore ?? this.hostScore,
      guestScore: guestScore ?? this.guestScore,
      status: status ?? this.status,
      currentQuestionId: currentQuestionId ?? this.currentQuestionId,
      questionIndex: questionIndex ?? this.questionIndex,
      questionIds: questionIds ?? this.questionIds,
      category: category,
      createdAt: createdAt,
      winnerId: winnerId ?? this.winnerId,
      isReplenishing: isReplenishing ?? this.isReplenishing,
    );
  }
}
