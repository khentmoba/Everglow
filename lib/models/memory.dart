import 'package:cloud_firestore/cloud_firestore.dart';

class Memory {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String category;
  final DateTime date;
  final String ownerId;

  Memory({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.category,
    required this.date,
    required this.ownerId,
  });

  factory Memory.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Memory(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      category: data['category'] ?? 'General',
      date: (data['date'] as Timestamp).toDate(),
      ownerId: data['ownerId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'category': category,
      'date': Timestamp.fromDate(date),
      'ownerId': ownerId,
      'year': date.year, // Useful for filtering/grouping
    };
  }

  Memory copyWith({
    String? title,
    String? description,
    String? imageUrl,
    String? category,
    DateTime? date,
  }) {
    return Memory(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      date: date ?? this.date,
      ownerId: ownerId,
    );
  }
}
