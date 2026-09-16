import 'package:cloud_firestore/cloud_firestore.dart';

enum PollStatus { open, closed }

class DatePollOption {
  final String id;
  final DateTime date; // option date
  final String label; // e.g., "Sat, Feb 14 — 7pm"

  const DatePollOption({
    required this.id,
    required this.date,
    required this.label,
  });

  factory DatePollOption.fromMap(Map<String, dynamic> m) => DatePollOption(
    id: _toStr(m['id']),
    date: (m['date'] is Timestamp)
        ? (m['date'] as Timestamp).toDate()
        : DateTime.tryParse(m['date'].toString()) ?? DateTime.now(),
    label: _toStr(m['label']),
  );

  static String _toStr(dynamic value) => value is String ? value : '';

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': Timestamp.fromDate(date),
    'label': label,
  };
}

class DatePoll {
  final String id;
  final String title;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final List<DatePollOption> options;
  final Map<String, String>
  votes; // username -> optionId (single vote, Rallly style). Could extend to multi.
  final PollStatus status;
  final String? decidedOptionId;

  const DatePoll({
    required this.id,
    required this.title,
    this.description = '',
    required this.createdBy,
    required this.createdAt,
    required this.options,
    this.votes = const {},
    this.status = PollStatus.open,
    this.decidedOptionId,
  });

  factory DatePoll.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return DatePoll.fromMap(data, doc.id);
  }

  factory DatePoll.fromMap(Map<String, dynamic> data, String id) {
    final votes = <String, String>{};
    final votesRaw = data['votes'];
    if (votesRaw is Map) {
      votesRaw.forEach((k, v) {
        if (k is String && v is String) votes[k] = v;
      });
    }
    final optionsRaw = data['options'];
    return DatePoll(
      id: id,
      title: _toStr(data['title']),
      description: _toStr(data['description']),
      createdBy: _toStr(data['createdBy']),
      createdAt: _toDate(data['createdAt']),
      options: optionsRaw is List
          ? optionsRaw
                .whereType<Map>()
                .map(
                  (e) => DatePollOption.fromMap(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [],
      votes: votes,
      status: data['status'] == 'closed' ? PollStatus.closed : PollStatus.open,
      decidedOptionId: _toNullableStr(data['decidedOptionId']),
    );
  }

  static String _toStr(dynamic value) => value is String ? value : '';

  static String? _toNullableStr(dynamic value) =>
      value is String ? value : null;

  static DateTime _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'description': description,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'options': options.map((o) => o.toMap()).toList(),
    'votes': votes,
    'status': status.name,
    if (decidedOptionId != null) 'decidedOptionId': decidedOptionId,
  };

  DatePoll copyWith({
    String? title,
    String? description,
    List<DatePollOption>? options,
    Map<String, String>? votes,
    PollStatus? status,
    String? decidedOptionId,
    bool clearDecided = false,
  }) => DatePoll(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    createdBy: createdBy,
    createdAt: createdAt,
    options: options ?? this.options,
    votes: votes ?? this.votes,
    status: status ?? this.status,
    decidedOptionId: clearDecided
        ? null
        : (decidedOptionId ?? this.decidedOptionId),
  );

  Map<String, int> get tally {
    final m = <String, int>{};
    for (final v in votes.values) {
      m[v] = (m[v] ?? 0) + 1;
    }
    return m;
  }

  String? get winningOptionId {
    if (tally.isEmpty) return null;
    return tally.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  bool get isTie {
    if (tally.length < 2) return false;
    final maxVotes = tally.values.reduce((a, b) => a > b ? a : b);
    return tally.values.where((v) => v == maxVotes).length > 1;
  }
}
