import 'package:cloud_firestore/cloud_firestore.dart';

enum WorkoutCategory { strength, cardio, flexibility, sports, other }

class Workout {
  final String id;
  final String title;
  final String notes;
  final WorkoutCategory category;
  final int durationMinutes;
  final int calories;
  final String createdBy;
  final DateTime date;
  final List<String> tags;

  const Workout({
    required this.id,
    required this.title,
    this.notes = '',
    this.category = WorkoutCategory.other,
    this.durationMinutes = 30,
    this.calories = 0,
    required this.createdBy,
    required this.date,
    this.tags = const [],
  });

  static WorkoutCategory _parseCat(dynamic v) {
    if (v is String) for (final c in WorkoutCategory.values) if (c.name == v) return c;
    return WorkoutCategory.other;
  }

  factory Workout.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Workout(
      id: doc.id,
      title: data['title'] ?? '',
      notes: data['notes'] ?? '',
      category: _parseCat(data['category']),
      durationMinutes: (data['durationMinutes'] ?? 30) is int ? data['durationMinutes'] : int.tryParse(data['durationMinutes'].toString()) ?? 30,
      calories: (data['calories'] ?? 0) is int ? data['calories'] : int.tryParse(data['calories'].toString()) ?? 0,
      createdBy: data['createdBy'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tags: (data['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'notes': notes,
        'category': category.name,
        'durationMinutes': durationMinutes,
        'calories': calories,
        'createdBy': createdBy,
        'date': Timestamp.fromDate(date),
        'tags': tags,
      };
}
