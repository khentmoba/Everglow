import 'package:cloud_firestore/cloud_firestore.dart';

/// Category for journal entries — DailyTxT / Memos inspired.
enum JournalCategory {
  daily('Daily', '📔'),
  gratitude('Gratitude', '🙏'),
  memory('Memory', '📸'),
  letter('Letter', '💌'),
  dream('Dream', '🌙'),
  idea('Idea', '💡');

  final String displayName;
  final String emoji;
  const JournalCategory(this.displayName, this.emoji);
}

/// Mood snapshot linked to heartbeat — optional.
enum JournalMood {
  happy('happy', '😊'),
  calm('calm', '😌'),
  loved('loved', '🥰'),
  excited('excited', '🤩'),
  tired('tired', '😴'),
  sad('sad', '😢'),
  stressed('stressed', '😣'),
  neutral('neutral', '😐');

  final String key;
  final String emoji;
  const JournalMood(this.key, this.emoji);
}

class JournalEntry {
  final String id;
  final String title;
  final String content; // markdown
  final String author; // username lowercased
  final DateTime createdAt;
  final DateTime updatedAt;
  final JournalCategory category;
  final JournalMood? mood;
  final List<String> tags;
  final bool isPinned;
  final bool isLocked; // soft lock — UI gate, DailyTxT inspired
  final String? coverColor; // hex or null
  final int wordCount;

  const JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    this.category = JournalCategory.daily,
    this.mood,
    this.tags = const [],
    this.isPinned = false,
    this.isLocked = false,
    this.coverColor,
    this.wordCount = 0,
  });

  static JournalMood? _parseMood(dynamic v) {
    if (v == null) return null;
    for (final m in JournalMood.values) {
      if (m.key == v || m.name == v) return m;
    }
    return null;
  }

  static JournalCategory _parseCategory(dynamic v) {
    if (v is String) {
      for (final c in JournalCategory.values) {
        if (c.name == v) return c;
      }
    }
    return JournalCategory.daily;
  }

  static DateTime _parseTs(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  factory JournalEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final content = data['content'] ?? '';
    return JournalEntry(
      id: doc.id,
      title: data['title'] ?? '',
      content: content,
      author: data['author'] ?? '',
      createdAt: _parseTs(data['createdAt']),
      updatedAt: _parseTs(data['updatedAt'] ?? data['createdAt']),
      category: _parseCategory(data['category']),
      mood: _parseMood(data['mood']),
      tags: (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      isPinned: data['isPinned'] ?? false,
      isLocked: data['isLocked'] ?? false,
      coverColor: data['coverColor'],
      wordCount: data['wordCount'] ?? content.toString().trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'author': author.toLowerCase(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'category': category.name,
      if (mood != null) 'mood': mood!.key,
      'tags': tags,
      'isPinned': isPinned,
      'isLocked': isLocked,
      if (coverColor != null) 'coverColor': coverColor,
      'wordCount': wordCount,
      'monthDay': _monthDay(createdAt),
      'searchKey': '${title.toLowerCase()} ${content.toLowerCase().substring(0, content.length > 500 ? 500 : content.length)}'.toLowerCase(),
    };
  }

  static String _monthDay(DateTime d) => '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  JournalEntry copyWith({
    String? title,
    String? content,
    String? author,
    DateTime? createdAt,
    DateTime? updatedAt,
    JournalCategory? category,
    JournalMood? mood,
    bool clearMood = false,
    List<String>? tags,
    bool? isPinned,
    bool? isLocked,
    String? coverColor,
    bool clearCoverColor = false,
    int? wordCount,
  }) {
    return JournalEntry(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      mood: clearMood ? null : (mood ?? this.mood),
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      coverColor: clearCoverColor ? null : (coverColor ?? this.coverColor),
      wordCount: wordCount ?? this.wordCount,
    );
  }

  bool get isLong => wordCount > 200;
  String get preview => content.length > 120 ? '${content.substring(0, 120)}…' : content;
}
