import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories for milestones.
enum MilestoneCategory {
  firstDate('First Date', '💕'),
  trip('Trip', '✈️'),
  achievement('Achievement', '🏆'),
  anniversary('Anniversary', '🎂'),
  memory('Memory', '⭐');

  final String displayName;
  final String emoji;
  const MilestoneCategory(this.displayName, this.emoji);
}

class Milestone {
  /// Milestone photos that were renamed from `.png` to `.jpg` after the
  /// first memories were saved. Stored docs may still point at the deleted
  /// `.png` files, which render as blank photos, so both the read path
  /// ([fromFirestore]) and the one-time repair migration
  /// (`MilestoneService.repairLegacyAssetPaths`) rewrite them.
  /// Keep this map to exactly these renames — never add a live `.png`.
  static const Map<String, String> legacyAssetPathFixes = {
    'assets/images/milestones/valentines_khent_2.png':
        'assets/images/milestones/valentines_khent_2.jpg',
    'assets/images/milestones/kiss_khent_4.png':
        'assets/images/milestones/kiss_khent_4.jpg',
    'assets/images/milestones/birthday_pre_khent_5.png':
        'assets/images/milestones/birthday_pre_khent_5.jpg',
    'assets/images/milestones/puting_bato_khent_2.png':
        'assets/images/milestones/puting_bato_khent_2.jpg',
    'assets/images/milestones/puting_bato_khent_3.png':
        'assets/images/milestones/puting_bato_khent_3.jpg',
  };

  /// Rewrites a stale seeded asset path to its current equivalent.
  /// Returns [url] unchanged when it needs no repair.
  static String repairLegacyImageUrl(String url) =>
      legacyAssetPathFixes[url] ?? url;

  final String id;
  final String title;
  final String description;
  final DateTime date;
  final List<String> imageUrls;
  final String? author;
  final MilestoneCategory category;

  const Milestone({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.imageUrls = const [],
    this.author,
    this.category = MilestoneCategory.memory,
  });

  factory Milestone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Milestone(
      id: doc.id,
      title: data['title'] as String,
      description: data['description'] as String,
      date: _parseDateTime(data['date']),
      imageUrls:
          (data['imageUrls'] as List<dynamic>?)
              ?.map((e) => repairLegacyImageUrl(e as String))
              .toList() ??
          [],
      author: data['author'] as String?,
      category: MilestoneCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => MilestoneCategory.memory,
      ),
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
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'imageUrls': imageUrls,
      'category': category.name,
      if (author != null) 'author': author,
    };
  }
}
