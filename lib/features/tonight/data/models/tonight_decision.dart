import 'package:cloud_firestore/cloud_firestore.dart';
import 'tonight_option.dart';

enum TonightStatus {
  voting,
  decided,
  planned;

  static TonightStatus fromString(dynamic value) {
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'voting':
          return TonightStatus.voting;
        case 'decided':
          return TonightStatus.decided;
        case 'planned':
          return TonightStatus.planned;
      }
    }
    return TonightStatus.voting;
  }
}

class TonightDecision {
  final String id;
  final TonightStatus status;
  final List<TonightOption> options;
  final Map<String, String> votes;
  final String? winnerOptionId;
  final String? calendarEventId;
  final DateTime? planTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TonightDecision({
    required this.id,
    this.status = TonightStatus.voting,
    this.options = const [],
    this.votes = const {},
    this.winnerOptionId,
    this.calendarEventId,
    this.planTime,
    required this.createdAt,
    required this.updatedAt,
  });

  TonightOption? get winningOption {
    if (winnerOptionId == null) return null;
    return options.cast<TonightOption?>().firstWhere(
      (opt) => opt?.id == winnerOptionId,
      orElse: () => null,
    );
  }

  String? get khentVote => votes['khentsgdz'];
  String? get clairVote => votes['clairjassen'];

  bool get isMatch =>
      khentVote != null && clairVote != null && khentVote == clairVote;

  bool get hasBothVoted => khentVote != null && clairVote != null;

  bool get isTied => hasBothVoted && khentVote != clairVote;

  factory TonightDecision.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return TonightDecision.fromMap(data, doc.id);
  }

  factory TonightDecision.fromMap(Map<String, dynamic>? data, [String? id]) {
    if (data == null) {
      final now = DateTime.now();
      return TonightDecision(
        id: id ?? 'active',
        createdAt: now,
        updatedAt: now,
      );
    }

    final rawOptions = data['options'];
    final options = <TonightOption>[];
    if (rawOptions is List) {
      for (final raw in rawOptions) {
        if (raw is Map) {
          final optionData = <String, dynamic>{};
          raw.forEach((key, value) {
            if (key is String) optionData[key] = value;
          });
          options.add(
            TonightOption.fromMap(optionData, _toNullableStr(optionData['id'])),
          );
        }
      }
    }

    final rawVotes = data['votes'];
    final votes = <String, String>{};
    if (rawVotes is Map) {
      rawVotes.forEach((k, v) {
        if (k is String && v is String) votes[k] = v;
      });
    }

    return TonightDecision(
      id: id ?? 'active',
      status: TonightStatus.fromString(data['status']),
      options: options,
      votes: votes,
      winnerOptionId: _toNullableStr(data['winnerOptionId']),
      calendarEventId: _toNullableStr(data['calendarEventId']),
      planTime: _parseDateTime(data['planTime']),
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
    );
  }

  static String? _toNullableStr(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  Map<String, dynamic> toMap() => {
    'status': status.name,
    'options': options.map((o) => o.toMap()).toList(),
    'votes': votes,
    if (winnerOptionId != null) 'winnerOptionId': winnerOptionId,
    if (calendarEventId != null) 'calendarEventId': calendarEventId,
    if (planTime != null) 'planTime': Timestamp.fromDate(planTime!),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
