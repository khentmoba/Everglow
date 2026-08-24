/// A single structured fact Mochi remembers about Khent, Clair, or
/// their relationship.
///
/// Older facts in Firestore only contain [fact] and [category]. The
/// structured [subject]/[relation]/[object] fields are optional and
/// are filled in by `remember_fact` when available. Keeping the raw
/// [fact] string as the source of truth means nothing breaks for facts
/// written before this model existed.
class MemoryFact {
  final String id;
  final String fact;
  final String category;
  final String? subject;
  final String? relation;
  final String? object;
  final DateTime? occurredAt;
  final DateTime? createdAt;
  final double confidence;
  final bool pinned;
  final int accessCount;
  final String source;

  const MemoryFact({
    this.id = '',
    required this.fact,
    this.category = 'fact',
    this.subject,
    this.relation,
    this.object,
    this.occurredAt,
    this.createdAt,
    this.confidence = 1.0,
    this.pinned = false,
    this.accessCount = 0,
    this.source = '',
  });

  /// Whether this memory happened on the same month/day as [now].
  /// Used for the "On This Day" surfaces.
  bool isOnThisDay(DateTime now) {
    final date = occurredAt;
    if (date == null) return false;
    return date.month == now.month && date.day == now.day;
  }

  /// Human-readable subject label, falling back to the raw fact when
  /// the structured parser could not infer one.
  String get subjectLabel => subject ?? _inferSubject;

  String get _inferSubject {
    final lower = fact.toLowerCase();
    if (lower.startsWith('khent and clair')) return 'Khent and Clair';
    if (lower.startsWith('clair and khent')) return 'Clair and Khent';
    if (lower.startsWith('khent')) return 'Khent';
    if (lower.startsWith('clair')) return 'Clair';
    return 'Mochi';
  }

  MemoryFact copyWith({
    String? id,
    String? fact,
    String? category,
    String? subject,
    String? relation,
    String? object,
    DateTime? occurredAt,
    DateTime? createdAt,
    double? confidence,
    bool? pinned,
    int? accessCount,
    String? source,
  }) {
    return MemoryFact(
      id: id ?? this.id,
      fact: fact ?? this.fact,
      category: category ?? this.category,
      subject: subject ?? this.subject,
      relation: relation ?? this.relation,
      object: object ?? this.object,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      confidence: confidence ?? this.confidence,
      pinned: pinned ?? this.pinned,
      accessCount: accessCount ?? this.accessCount,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fact': fact,
    'category': category,
    if (subject != null) 'subject': subject,
    if (relation != null) 'relation': relation,
    if (object != null) 'object': object,
    if (occurredAt != null) 'occurredAt': occurredAt!.toIso8601String(),
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    'confidence': confidence,
    'pinned': pinned,
    'accessCount': accessCount,
    if (source.isNotEmpty) 'source': source,
  };

  factory MemoryFact.fromJson(Map<String, dynamic> json, {String id = ''}) {
    return MemoryFact(
      id: (json['id'] as String?) ?? id,
      fact: (json['fact'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'fact',
      subject: json['subject'] as String?,
      relation: json['relation'] as String?,
      object: json['object'] as String?,
      occurredAt: _parseDate(json['occurredAt']),
      createdAt: _parseDate(json['createdAt']),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      pinned: json['pinned'] == true,
      accessCount: (json['accessCount'] as num?)?.toInt() ?? 0,
      source: (json['source'] as String?) ?? '',
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

/// Lightweight subject/relation/object inference for facts written as
/// plain sentences. This keeps trivia generation and search useful even
/// when older facts never got structured fields.
class FactStructureParser {
  const FactStructureParser();

  static final RegExp _knownVerbs = RegExp(
    r'^(Khent and Clair|Clair and Khent|Khent|Clair)\s+'
    r'(prefers?|loves?|likes?|dislikes?|hates?|wants?|enjoys?|'
    r'studies?|rides?|plays?|watched?|watches?|read|reads?|'
    r'went to|visited?|dreams? of|is|was|has|had|works at|'
    r'started|finished|learned|learnt)\s+(.+)$',
    caseSensitive: false,
  );

  /// Returns `(subject, relation, object)` or all nulls when the fact
  /// does not follow an inferable pattern.
  (String?, String?, String?) parse(String fact) {
    final trimmed = fact.trim();
    if (trimmed.isEmpty) return (null, null, null);
    final match = _knownVerbs.firstMatch(trimmed);
    if (match == null) return (null, null, null);
    return (match.group(1), match.group(2), match.group(3));
  }
}
