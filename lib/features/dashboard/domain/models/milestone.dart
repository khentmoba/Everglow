import 'package:cloud_firestore/cloud_firestore.dart';

class Milestone {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final List<String> imageUrls;
  final String? author;

  const Milestone({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.imageUrls = const [],
    this.author,
  });

  factory Milestone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Milestone(
      id:          doc.id,
      title:       data['title']       as String,
      description: data['description'] as String,
      date:        _parseDateTime(data['date']),
      imageUrls:    (data['imageUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      author:      data['author']      as String?,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
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

  Map<String, dynamic> toFirestore() {
    return {
      'title':       title,
      'description': description,
      'date':        Timestamp.fromDate(date),
      'imageUrls':   imageUrls,
      if (author != null) 'author': author,
    };
  }
}
