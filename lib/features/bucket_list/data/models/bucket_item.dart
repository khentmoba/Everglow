import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories for bucket list items.
enum BucketCategory {
  travel('Travel', '✈️'),
  experience('Experience', '🎭'),
  food('Food & Drink', '🍽️'),
  adventure('Adventure', '🏔️'),
  milestone('Milestone', '🏆'),
  other('Other', '💫');

  final String displayName;
  final String emoji;
  const BucketCategory(this.displayName, this.emoji);
}

/// Status of a bucket list item.
enum BucketStatus {
  wish('Wished', '🌟'),
  planned('Planned', '📋'),
  completed('Completed', '✅');

  final String displayName;
  final String emoji;
  const BucketStatus(this.displayName, this.emoji);
}

/// A single bucket list item shared between the couple.
class BucketItem {
  final String id;
  final String title;
  final String description;
  final BucketCategory category;
  final BucketStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? completedBy;
  final String? imageUrl;
  final String notes;

  const BucketItem({
    required this.id,
    required this.title,
    this.description = '',
    this.category = BucketCategory.other,
    this.status = BucketStatus.wish,
    required this.createdBy,
    required this.createdAt,
    this.completedAt,
    this.completedBy,
    this.imageUrl,
    this.notes = '',
  });

  factory BucketItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BucketItem(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: BucketCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => BucketCategory.other,
      ),
      status: BucketStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => BucketStatus.wish,
      ),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      completedBy: data['completedBy'],
      imageUrl: data['imageUrl'],
      notes: data['notes'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category.name,
      'status': status.name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (completedBy != null) 'completedBy': completedBy,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'notes': notes,
    };
  }

  BucketItem copyWith({
    String? title,
    String? description,
    BucketCategory? category,
    BucketStatus? status,
    DateTime? completedAt,
    String? completedBy,
    String? imageUrl,
    String? notes,
  }) {
    return BucketItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      createdBy: createdBy,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
    );
  }
}
