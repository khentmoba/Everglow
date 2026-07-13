import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories for star notes.
const List<String> starCategories = [
  'gratitude',
  'memory',
  'love',
  'dream',
  'milestone',
  'surprise',
];

/// Emoji + label map for display.
const Map<String, (String emoji, String label)> starCategoryInfo = {
  'gratitude': ('🙏', 'Gratitude'),
  'memory': ('📸', 'Memory'),
  'love': ('💕', 'Love'),
  'dream': ('🌙', 'Dream'),
  'milestone': ('🎉', 'Milestone'),
  'surprise': ('✨', 'Surprise'),
};

class StarNote {
  final String id;
  final String content;
  final String author;
  final DateTime timestamp;
  final String category;
  final List<String> tags;

  StarNote({
    required this.id,
    required this.content,
    required this.author,
    required this.timestamp,
    this.category = 'gratitude',
    this.tags = const [],
  });

  factory StarNote.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return StarNote(
      id: doc.id,
      content: data['content'] ?? '',
      author: data['author'] ?? '',
      timestamp: _parseTimestamp(data['timestamp']),
      category: data['category'] ?? 'gratitude',
      tags: (data['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'author': author,
      'timestamp': FieldValue.serverTimestamp(),
      'category': category,
      'tags': tags,
    };
  }
}
