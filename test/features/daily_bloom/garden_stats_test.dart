import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/daily_bloom/data/models/garden_stats.dart';
import 'package:everglow/features/daily_bloom/data/models/plant_type.dart';

void main() {
  group('PlantType', () {
    test('fromId falls back to lily for unknown ids', () {
      expect(PlantType.fromId('rose').displayName, 'Rose');
      expect(PlantType.fromId('nope').id, 'lily');
    });

    test('every plant has six stages, a name and an emoji', () {
      for (final p in PlantType.all) {
        expect(p.displayName, isNotEmpty);
        expect(p.emoji, isNotEmpty);
        expect(p.stageDescriptions.length, 6);
      }
    });

    test('effectiveStage never exceeds the final stage', () {
      expect(PlantType.fromId('lily').effectiveStage(3), 3);
      expect(PlantType.fromId('rose').effectiveStage(5), 5);
      expect(PlantType.fromId('rose').effectiveStage(0), greaterThanOrEqualTo(0));
    });
  });

  group('GardenStats', () {
    test('initial starts an empty lily pot', () {
      final stats = GardenStats.initial();

      expect(stats.currentStage, 0);
      expect(stats.streakCount, 0);
      expect(stats.totalInteractions, 0);
      expect(stats.plantType, 'lily');
    });

    test('toFirestore keeps every field', () {
      final stats = GardenStats(
        currentStage: 4,
        lastVisit: DateTime.utc(2026, 9, 5),
        streakCount: 7,
        totalInteractions: 42,
        plantType: 'rose',
      );
      final map = stats.toFirestore();

      expect(map['currentStage'], 4);
      expect(map['streakCount'], 7);
      expect(map['totalInteractions'], 42);
      expect(map['plantType'], 'rose');
    });

    test('copyWith advances the garden without losing history', () {
      final stats = GardenStats(
        currentStage: 2,
        lastVisit: DateTime.utc(2026, 9, 4),
        streakCount: 2,
        totalInteractions: 10,
      ).copyWith(currentStage: 3, streakCount: 3);

      expect(stats.currentStage, 3);
      expect(stats.streakCount, 3);
      expect(stats.totalInteractions, 10);
      expect(stats.plantType, 'lily');
    });
  });

  group('GardenStats.fromMap', () {
    test('reads every field', () {
      final stats = GardenStats.fromMap({
        'currentStage': 4,
        'lastVisit': Timestamp.fromDate(DateTime.utc(2026, 9, 5)),
        'streakCount': 7,
        'totalInteractions': 42,
        'plantType': 'rose',
      });

      expect(stats.currentStage, 4);
      expect(
        stats.lastVisit.millisecondsSinceEpoch,
        DateTime.utc(2026, 9, 5).millisecondsSinceEpoch,
      );
      expect(stats.streakCount, 7);
      expect(stats.totalInteractions, 42);
      expect(stats.plantType, 'rose');
    });

    test('missing lastVisit never crashes the garden', () {
      final stats = GardenStats.fromMap({
        'currentStage': 2,
        'streakCount': 2,
        'totalInteractions': 10,
      });

      expect(stats.currentStage, 2);
      expect(stats.lastVisit, isA<DateTime>());
      expect(stats.plantType, 'lily');
    });

    test('wrong types fall back instead of throwing', () {
      final stats = GardenStats.fromMap({
        'currentStage': 3.0,
        'lastVisit': 'not-a-date',
        'streakCount': null,
        'totalInteractions': null,
        'plantType': null,
      });

      expect(stats.currentStage, 3);
      expect(stats.lastVisit, isA<DateTime>());
      expect(stats.streakCount, 0);
      expect(stats.totalInteractions, 0);
      expect(stats.plantType, 'lily');
    });
  });
}
