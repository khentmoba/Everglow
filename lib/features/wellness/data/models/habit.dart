import 'package:cloud_firestore/cloud_firestore.dart';

enum HabitFrequency { daily, weekly, custom }

enum HabitCategory { health, fitness, mindfulness, learning, social, other }

class Habit {
  final String id;
  final String title;
  final String description;
  final HabitCategory category;
  final HabitFrequency frequency;
  final String createdBy;
  final DateTime createdAt;
  final List<DateTime> completedDates; // store as Timestamp list
  final int streak;
  final int longestStreak;
  final bool isActive;

  const Habit({
    required this.id,
    required this.title,
    this.description = '',
    this.category = HabitCategory.health,
    this.frequency = HabitFrequency.daily,
    required this.createdBy,
    required this.createdAt,
    this.completedDates = const [],
    this.streak = 0,
    this.longestStreak = 0,
    this.isActive = true,
  });

  static HabitCategory _parseCat(dynamic v) {
    if (v is String) for (final c in HabitCategory.values) if (c.name == v) return c;
    return HabitCategory.health;
  }

  static HabitFrequency _parseFreq(dynamic v) {
    if (v is String) for (final f in HabitFrequency.values) if (f.name == v) return f;
    return HabitFrequency.daily;
  }

  factory Habit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Habit(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: _parseCat(data['category']),
      frequency: _parseFreq(data['frequency']),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedDates: (data['completedDates'] as List<dynamic>? ?? []).map((e) => e is Timestamp ? e.toDate() : DateTime.tryParse(e.toString()) ?? DateTime.now()).toList(),
      streak: data['streak'] ?? 0,
      longestStreak: data['longestStreak'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'category': category.name,
        'frequency': frequency.name,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'completedDates': completedDates.map((d) => Timestamp.fromDate(DateTime(d.year, d.month, d.day))).toList(),
        'streak': streak,
        'longestStreak': longestStreak,
        'isActive': isActive,
      };

  bool isCompletedOn(DateTime day) => completedDates.any((d) => d.year == day.year && d.month == day.month && d.day == day.day);

  bool get isCompletedToday => isCompletedOn(DateTime.now());

  Habit copyWith({String? title, String? description, HabitCategory? category, HabitFrequency? frequency, List<DateTime>? completedDates, int? streak, int? longestStreak, bool? isActive}) => Habit(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        frequency: frequency ?? this.frequency,
        createdBy: createdBy,
        createdAt: createdAt,
        completedDates: completedDates ?? this.completedDates,
        streak: streak ?? this.streak,
        longestStreak: longestStreak ?? this.longestStreak,
        isActive: isActive ?? this.isActive,
      );
}
