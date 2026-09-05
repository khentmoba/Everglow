import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/wellness/data/models/habit.dart';
import 'package:everglow/features/wellness/data/models/workout.dart';

Habit _habit() => Habit(
      id: 'h1',
      title: 'Morning walk',
      category: HabitCategory.fitness,
      frequency: HabitFrequency.daily,
      createdBy: 'clair',
      createdAt: DateTime.utc(2026, 9, 1),
      completedDates: [DateTime.utc(2026, 9, 4, 22, 15)],
      streak: 3,
      longestStreak: 5,
    );

void main() {
  group('Habit', () {
    test('isCompletedOn matches the calendar day, not the hour', () {
      final habit = _habit();

      expect(habit.isCompletedOn(DateTime.utc(2026, 9, 4)), isTrue);
      expect(habit.isCompletedOn(DateTime.utc(2026, 9, 4, 8)), isTrue);
      expect(habit.isCompletedOn(DateTime.utc(2026, 9, 3)), isFalse);
      expect(habit.isCompletedOn(DateTime.utc(2026, 9, 5)), isFalse);
    });

    test('toFirestore keeps names and truncates completions to days', () {
      final map = _habit().toFirestore();

      expect(map['category'], 'fitness');
      expect(map['frequency'], 'daily');
      expect(map['streak'], 3);
      expect(map['longestStreak'], 5);
      expect(map['isActive'], isTrue);
      final stamped =
          (map['completedDates'] as List).single as dynamic;
      final day = stamped.toDate() as DateTime;
      expect(day.hour, 0);
      expect(day.minute, 0);
      expect(day.day, 4);
    });

    test('copyWith keeps identity while updating progress', () {
      final updated = _habit().copyWith(
        streak: 4,
        completedDates: [DateTime.utc(2026, 9, 5)],
        isActive: false,
      );

      expect(updated.id, 'h1');
      expect(updated.createdBy, 'clair');
      expect(updated.streak, 4);
      expect(updated.isActive, isFalse);
      expect(updated.isCompletedOn(DateTime.utc(2026, 9, 5)), isTrue);
    });
  });

  group('Workout', () {
    test('toFirestore keeps category name and numbers', () {
      final map = Workout(
        id: 'w1',
        title: 'Evening run',
        notes: 'Easy pace',
        category: WorkoutCategory.cardio,
        durationMinutes: 40,
        calories: 320,
        createdBy: 'khent',
        date: DateTime.utc(2026, 9, 4, 18),
        tags: const ['run'],
      ).toFirestore();

      expect(map['category'], 'cardio');
      expect(map['durationMinutes'], 40);
      expect(map['calories'], 320);
      expect(map['tags'], ['run']);
    });

    test('defaults are a 30-minute uncategorized session', () {
      final workout = Workout(
        id: 'w2',
        title: 'Stretch',
        createdBy: 'clair',
        date: DateTime.utc(2026, 9, 4),
      );

      expect(workout.category, WorkoutCategory.other);
      expect(workout.durationMinutes, 30);
      expect(workout.calories, 0);
      expect(workout.notes, isEmpty);
    });
  });
}
