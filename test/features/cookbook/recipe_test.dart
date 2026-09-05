import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cookbook/data/models/recipe.dart';

Recipe _recipe() => Recipe(
      id: 'r1',
      title: 'Miso Salmon',
      description: 'Weeknight favorite',
      category: RecipeCategory.dinner,
      difficulty: RecipeDifficulty.medium,
      cookMinutes: 25,
      servings: 2,
      ingredients: const [
        RecipeIngredient(name: 'Salmon', amount: '400g'),
        RecipeIngredient(name: 'Miso', amount: '2 tbsp', note: 'white'),
      ],
      steps: const ['Marinate', 'Bake 12 min'],
      tags: const ['fish', 'japanese'],
      createdBy: 'khent',
      createdAt: DateTime.utc(2026, 9, 1, 12),
    );

void main() {
  group('Recipe', () {
    test('toFirestore keeps names and builds a searchable key', () {
      final map = _recipe().toFirestore();

      expect(map['category'], 'dinner');
      expect(map['difficulty'], 'medium');
      expect(map['searchKey'], contains('miso salmon'));
      expect(map['searchKey'], contains('weeknight favorite'));
      expect(map['searchKey'], contains('fish japanese'));
    });

    test('toFirestore omits null image, source and rating', () {
      final map = _recipe().toFirestore();

      expect(map.containsKey('imageUrl'), isFalse);
      expect(map.containsKey('sourceUrl'), isFalse);
      expect(map.containsKey('rating'), isFalse);
    });

    test('copyWith clears image and rating only when asked', () {
      final base = Recipe(
        id: 'r1',
        title: 'T',
        imageUrl: 'http://img',
        rating: 4.5,
        createdBy: 'clair',
        createdAt: DateTime.utc(2026, 9, 1),
      );

      expect(base.copyWith().imageUrl, 'http://img');
      expect(base.copyWith().rating, 4.5);
      expect(base.copyWith(clearImage: true).imageUrl, isNull);
      expect(base.copyWith(clearRating: true).rating, isNull);
      expect(base.copyWith(isFavorite: true, timesCooked: 3).timesCooked, 3);
    });

    test('every category has a label and emoji', () {
      for (final c in RecipeCategory.values) {
        expect(c.displayName, isNotEmpty);
        expect(c.emoji, isNotEmpty);
      }
    });
  });

  group('RecipeIngredient', () {
    test('fromMap/toMap round-trips name, amount and note', () {
      const ingredient =
          RecipeIngredient(name: 'Rice', amount: '1 cup', note: 'jasmine');

      final restored = RecipeIngredient.fromMap(ingredient.toMap());

      expect(restored.name, 'Rice');
      expect(restored.amount, '1 cup');
      expect(restored.note, 'jasmine');
    });

    test('missing fields default to empty, not null', () {
      final restored = RecipeIngredient.fromMap({});

      expect(restored.name, isEmpty);
      expect(restored.amount, isEmpty);
      expect(restored.note, isNull);
    });
  });

  group('MealPlanEntry', () {
    test('toFirestore truncates the date to the day', () {
      final map = MealPlanEntry(
        id: 'm1',
        recipeId: 'r1',
        recipeTitle: 'Miso Salmon',
        date: DateTime.utc(2026, 9, 5, 18, 30, 45),
        plannedBy: 'clair',
      ).toFirestore();

      final stamped = (map['date'] as dynamic).toDate() as DateTime;
      expect(stamped.hour, 0);
      expect(stamped.minute, 0);
      expect(stamped.day, 5);
      expect(map['meal'], 'dinner');
      expect(map['recipeTitle'], 'Miso Salmon');
    });

    test('meal defaults to dinner', () {
      final entry = MealPlanEntry(
        id: 'm1',
        recipeId: 'r1',
        recipeTitle: 'T',
        date: DateTime.utc(2026, 9, 5),
        plannedBy: 'khent',
      );

      expect(entry.meal, 'dinner');
    });
  });
}
