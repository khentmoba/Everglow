import 'package:cloud_firestore/cloud_firestore.dart';

enum RecipeCategory {
  breakfast('Breakfast', '🥞'),
  lunch('Lunch', '🥗'),
  dinner('Dinner', '🍝'),
  dessert('Dessert', '🍰'),
  drink('Drink', '🍹'), // Bar Assistant
  snack('Snack', '🍿'),
  other('Other', '🍽️');

  final String displayName;
  final String emoji;
  const RecipeCategory(this.displayName, this.emoji);
}

enum RecipeDifficulty { easy, medium, hard }

class RecipeIngredient {
  final String name;
  final String amount; // e.g., "200g", "1 cup"
  final String? note;

  const RecipeIngredient({required this.name, required this.amount, this.note});

  factory RecipeIngredient.fromMap(Map<String, dynamic> m) => RecipeIngredient(
    name: m['name'] ?? '',
    amount: m['amount'] ?? '',
    note: m['note'],
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'amount': amount,
    if (note != null) 'note': note,
  };
}

class Recipe {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String? sourceUrl; // Mealie import URL
  final RecipeCategory category;
  final RecipeDifficulty difficulty;
  final int cookMinutes;
  final int servings;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final List<String> tags;
  final String createdBy;
  final DateTime createdAt;
  final bool isFavorite;
  final double? rating; // 0-5
  final int timesCooked;

  const Recipe({
    required this.id,
    required this.title,
    this.description = '',
    this.imageUrl,
    this.sourceUrl,
    this.category = RecipeCategory.other,
    this.difficulty = RecipeDifficulty.easy,
    this.cookMinutes = 30,
    this.servings = 2,
    this.ingredients = const [],
    this.steps = const [],
    this.tags = const [],
    required this.createdBy,
    required this.createdAt,
    this.isFavorite = false,
    this.rating,
    this.timesCooked = 0,
  });

  static RecipeCategory _parseCategory(dynamic v) {
    if (v is String) {
      for (final c in RecipeCategory.values) {
        if (c.name == v) return c;
      }
    }
    return RecipeCategory.other;
  }

  static RecipeDifficulty _parseDifficulty(dynamic v) {
    if (v is String) {
      for (final d in RecipeDifficulty.values) {
        if (d.name == v) return d;
      }
    }
    return RecipeDifficulty.easy;
  }

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Recipe(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      sourceUrl: data['sourceUrl'],
      category: _parseCategory(data['category']),
      difficulty: _parseDifficulty(data['difficulty']),
      cookMinutes: (data['cookMinutes'] ?? 30) is int
          ? data['cookMinutes']
          : int.tryParse(data['cookMinutes'].toString()) ?? 30,
      servings: (data['servings'] ?? 2) is int
          ? data['servings']
          : int.tryParse(data['servings'].toString()) ?? 2,
      ingredients: (data['ingredients'] as List<dynamic>? ?? [])
          .map(
            (e) =>
                RecipeIngredient.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      steps: (data['steps'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      tags: (data['tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isFavorite: data['isFavorite'] ?? false,
      rating: (data['rating'] as num?)?.toDouble(),
      timesCooked: data['timesCooked'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'description': description,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
    'category': category.name,
    'difficulty': difficulty.name,
    'cookMinutes': cookMinutes,
    'servings': servings,
    'ingredients': ingredients.map((i) => i.toMap()).toList(),
    'steps': steps,
    'tags': tags,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'isFavorite': isFavorite,
    if (rating != null) 'rating': rating,
    'timesCooked': timesCooked,
    'searchKey':
        '${title.toLowerCase()} ${description.toLowerCase()} ${tags.join(' ').toLowerCase()}',
  };

  Recipe copyWith({
    String? title,
    String? description,
    String? imageUrl,
    bool clearImage = false,
    String? sourceUrl,
    RecipeCategory? category,
    RecipeDifficulty? difficulty,
    int? cookMinutes,
    int? servings,
    List<RecipeIngredient>? ingredients,
    List<String>? steps,
    List<String>? tags,
    bool? isFavorite,
    double? rating,
    bool clearRating = false,
    int? timesCooked,
  }) => Recipe(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
    sourceUrl: sourceUrl ?? this.sourceUrl,
    category: category ?? this.category,
    difficulty: difficulty ?? this.difficulty,
    cookMinutes: cookMinutes ?? this.cookMinutes,
    servings: servings ?? this.servings,
    ingredients: ingredients ?? this.ingredients,
    steps: steps ?? this.steps,
    tags: tags ?? this.tags,
    createdBy: createdBy,
    createdAt: createdAt,
    isFavorite: isFavorite ?? this.isFavorite,
    rating: clearRating ? null : (rating ?? this.rating),
    timesCooked: timesCooked ?? this.timesCooked,
  );
}

class MealPlanEntry {
  final String id;
  final String recipeId;
  final String recipeTitle;
  final DateTime date; // day
  final String meal; // breakfast/lunch/dinner
  final String plannedBy;

  const MealPlanEntry({
    required this.id,
    required this.recipeId,
    required this.recipeTitle,
    required this.date,
    this.meal = 'dinner',
    required this.plannedBy,
  });

  factory MealPlanEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealPlanEntry(
      id: doc.id,
      recipeId: data['recipeId'] ?? '',
      recipeTitle: data['recipeTitle'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      meal: data['meal'] ?? 'dinner',
      plannedBy: data['plannedBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'recipeId': recipeId,
    'recipeTitle': recipeTitle,
    'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
    'meal': meal,
    'plannedBy': plannedBy,
  };
}
