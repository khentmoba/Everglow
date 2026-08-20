import 'package:cloud_firestore/cloud_firestore.dart';

enum PollStatus { open, closed }

class DatePollOption {
  final String id;
  final DateTime date; // option date
  final String label; // e.g., "Sat, Feb 14 — 7pm"

  const DatePollOption({required this.id, required this.date, required this.label});

  factory DatePollOption.fromMap(Map<String, dynamic> m) => DatePollOption(
        id: m['id'] ?? '',
        date: (m['date'] is Timestamp) ? (m['date'] as Timestamp).toDate() : DateTime.tryParse(m['date'].toString()) ?? DateTime.now(),
        label: m['label'] ?? '',
      );

  Map<String, dynamic> toMap() => {'id': id, 'date': Timestamp.fromDate(date), 'label': label};
}

class DatePoll {
  final String id;
  final String title;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final List<DatePollOption> options;
  final Map<String, String> votes; // username -> optionId (single vote, Rallly style). Could extend to multi.
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
    final data = doc.data() as Map<String, dynamic>;
    return DatePoll(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      options: (data['options'] as List<dynamic>? ?? []).map((e) => DatePollOption.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      votes: Map<String, String>.from(data['votes'] ?? {}),
      status: data['status'] == 'closed' ? PollStatus.closed : PollStatus.open,
      decidedOptionId: data['decidedOptionId'],
    );
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

  DatePoll copyWith({String? title, String? description, List<DatePollOption>? options, Map<String, String>? votes, PollStatus? status, String? decidedOptionId, bool clearDecided = false}) => DatePoll(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        createdBy: createdBy,
        createdAt: createdAt,
        options: options ?? this.options,
        votes: votes ?? this.votes,
        status: status ?? this.status,
        decidedOptionId: clearDecided ? null : (decidedOptionId ?? this.decidedOptionId),
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
