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

/// Priority — Vikunja/Donetick inspired.
enum BucketPriority {
  low('Low', '⬇️', 0),
  medium('Medium', '➡️', 1),
  high('High', '⬆️', 2),
  urgent('Urgent', '🔥', 3);

  final String displayName;
  final String emoji;
  final int rank;
  const BucketPriority(this.displayName, this.emoji, this.rank);
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

  // Phase 1 — Kanban/chores additions (Donetick/Vikunja).
  final BucketPriority priority;
  final String?
  assignedTo; // username: khentsgdz / clairjassen / null = unassigned
  final DateTime? dueDate;

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
    this.priority = BucketPriority.medium,
    this.assignedTo,
    this.dueDate,
  });

  factory BucketItem.fromFirestore(DocumentSnapshot doc) => BucketItem.fromMap(
    doc.data() as Map<String, dynamic>? ?? const {},
    doc.id,
  );

  factory BucketItem.fromMap(Map<String, dynamic> data, String id) {
    // Tolerate missing/odd-typed fields: one malformed doc must never
    // crash the watchAll stream and take the whole shelf down.
    DateTime? asDate(dynamic v) => v is Timestamp ? v.toDate() : null;
    return BucketItem(
      id: id,
      title: data['title'] is String ? data['title'] as String : '',
      description:
          data['description'] is String ? data['description'] as String : '',
      category: BucketCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => BucketCategory.other,
      ),
      status: BucketStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => BucketStatus.wish,
      ),
      createdBy: data['createdBy'] is String ? data['createdBy'] : '',
      createdAt: asDate(data['createdAt']) ?? DateTime.now(),
      completedAt: asDate(data['completedAt']),
      completedBy:
          data['completedBy'] is String ? data['completedBy'] as String : null,
      imageUrl:
          data['imageUrl'] is String ? data['imageUrl'] as String : null,
      notes: data['notes'] is String ? data['notes'] as String : '',
      priority: BucketPriority.values.firstWhere(
        (p) => p.name == data['priority'],
        orElse: () => BucketPriority.medium,
      ),
      assignedTo: data['assignedTo'] is String ? data['assignedTo'] as String : null,
      dueDate: asDate(data['dueDate']),
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
      'priority': priority.name,
      if (assignedTo != null) 'assignedTo': assignedTo,
      if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
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
    BucketPriority? priority,
    String? assignedTo,
    DateTime? dueDate,
    bool clearAssignedTo = false,
    bool clearDueDate = false,
    bool clearCompletedAt = false,
    bool clearCompletedBy = false,
  }) {
    return BucketItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      createdBy: createdBy,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      completedBy: clearCompletedBy ? null : (completedBy ?? this.completedBy),
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      assignedTo: clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
    );
  }

  /// Helpers for Kanban/chores UI.
  bool get isOverdue =>
      dueDate != null &&
      status != BucketStatus.completed &&
      DateTime.now().isAfter(
        DateTime(dueDate!.year, dueDate!.month, dueDate!.day, 23, 59, 59),
      );

  bool get isDueSoon {
    if (dueDate == null || status == BucketStatus.completed) return false;
    final now = DateTime.now();
    final diff = dueDate!
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return diff >= 0 && diff <= 2;
  }

  bool get isChore =>
      assignedTo != null ||
      priority != BucketPriority.medium ||
      dueDate != null;
}
