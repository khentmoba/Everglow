import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/recipe.dart';

class CookbookService {
  static final CookbookService _instance = CookbookService._internal();
  factory CookbookService() => _instance;
  CookbookService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _recipesCol = 'recipes';
  final String _mealPlansCol = 'meal_plans';

  Stream<List<Recipe>> watchAll() => withFirestoreTimeout(
    _db
        .collection(_recipesCol)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => Recipe.fromFirestore(d)).toList()),
    label: 'cookbook-all',
  );

  Stream<List<Recipe>> watchFavorites() => withFirestoreTimeout(
    _db
        .collection(_recipesCol)
        .where('isFavorite', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => Recipe.fromFirestore(d)).toList()),
    label: 'cookbook-fav',
  );

  Stream<List<Recipe>> watchByCategory(RecipeCategory cat) =>
      withFirestoreTimeout(
        _db
            .collection(_recipesCol)
            .where('category', isEqualTo: cat.name)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots()
            .map((s) => s.docs.map((d) => Recipe.fromFirestore(d)).toList()),
        label: 'cookbook-${cat.name}',
      );

  Future<void> add(Recipe recipe) async {
    try {
      await _db.collection(_recipesCol).add(recipe.toFirestore());
      Logger.i('Recipe added: ${recipe.title}');
    } catch (e) {
      Logger.e('Error adding recipe', error: e);
    }
  }

  Future<void> update(Recipe recipe) async {
    try {
      await _db
          .collection(_recipesCol)
          .doc(recipe.id)
          .update(recipe.toFirestore());
    } catch (e) {
      Logger.e('Error updating recipe', error: e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _db.collection(_recipesCol).doc(id).delete();
    } catch (e) {
      Logger.e('Error deleting recipe', error: e);
    }
  }

  Future<void> toggleFavorite(String id, bool fav) async {
    try {
      await _db.collection(_recipesCol).doc(id).update({'isFavorite': fav});
    } catch (e) {
      Logger.e('Error toggling favorite', error: e);
    }
  }

  Future<void> incrementCooked(String id, int current) async {
    try {
      await _db.collection(_recipesCol).doc(id).update({
        'timesCooked': current + 1,
      });
    } catch (e) {
      Logger.e('Error incrementing cooked', error: e);
    }
  }

  /// Mealie-style import: fetch title from URL (simple heuristic), create stub.
  /// Full scraping would need Cloud Function; this is lightweight client import.
  Future<Recipe?> importFromUrl(String url, String createdBy) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    String title = 'Imported Recipe';
    String description = 'Imported from $trimmed';
    try {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.hasScheme) {
        final res = await http.get(uri).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final body = res.body;
          final titleMatch = RegExp(
            r'<title[^>]*>([^<]+)</title>',
            caseSensitive: false,
          ).firstMatch(body);
          if (titleMatch != null) {
            title = _decodeHtml(titleMatch.group(1)?.trim() ?? title);
            if (title.length > 80) title = title.substring(0, 80);
          }
          final descMatch = RegExp(
            r'<meta[^>]+name="description"[^>]+content="([^"]+)"',
            caseSensitive: false,
          ).firstMatch(body);
          if (descMatch != null) {
            description = _decodeHtml(descMatch.group(1) ?? description);
            if (description.length > 200) {
              description = description.substring(0, 200);
            }
          }
        }
      }
    } catch (e) {
      Logger.e('Import fetch failed, using fallback', error: e);
    }
    return Recipe(
      id: '',
      title: title,
      description: description,
      sourceUrl: trimmed,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      ingredients: const [
        RecipeIngredient(name: 'Edit ingredients', amount: 'to taste'),
      ],
      steps: const ['Edit steps — imported stub. Tap to edit.'],
      tags: const ['imported'],
    );
  }

  String _decodeHtml(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  // Meal planner
  Stream<List<MealPlanEntry>> watchMealPlans({int days = 7}) {
    final start = DateTime.now().subtract(const Duration(days: 1));
    return _db
        .collection(_mealPlansCol)
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime(start.year, start.month, start.day),
          ),
        )
        .orderBy('date')
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map((d) => MealPlanEntry.fromFirestore(d)).toList());
  }

  Future<void> addMealPlan(MealPlanEntry entry) async {
    try {
      await _db.collection(_mealPlansCol).add(entry.toFirestore());
    } catch (e) {
      Logger.e('Error adding meal plan', error: e);
    }
  }

  Future<void> removeMealPlan(String id) async {
    try {
      await _db.collection(_mealPlansCol).doc(id).delete();
    } catch (e) {
      Logger.e('Error removing meal plan', error: e);
    }
  }

  /// Generate shopping list: aggregate ingredients for upcoming meal plans.
  Future<Map<String, String>> generateShoppingList(
    List<MealPlanEntry> plans,
    Map<String, Recipe> recipeMap,
  ) async {
    final agg = <String, String>{};
    for (final plan in plans) {
      final recipe = recipeMap[plan.recipeId];
      if (recipe == null) continue;
      for (final ing in recipe.ingredients) {
        final key = ing.name.toLowerCase();
        if (agg.containsKey(key)) {
          agg[key] = '${agg[key]}, ${ing.amount}';
        } else {
          agg[key] = ing.amount;
        }
      }
    }
    return agg;
  }
}
