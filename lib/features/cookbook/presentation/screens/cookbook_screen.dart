import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_error_state.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_icon_button.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../../../shared/widgets/everglow/everglow_segmented_control.dart';
import '../../../../shared/widgets/everglow/everglow_search_field.dart';
import '../../data/models/recipe.dart';
import '../../data/services/cookbook_service.dart';
import '../widgets/add_recipe_dialog.dart';
import '../widgets/recipe_card.dart';

class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  RecipeCategory? _categoryFilter;
  bool _favoritesOnly = false;
  int _tabIndex = 0; // 0 recipes, 1 planner, 2 shopping

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = CookbookService();
    final auth = context.read<AuthService>();

    return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      body: Column(
              children: [
                EverglowFeatureHeader(
                  title: 'Our Cookbook',
                  subtitle: 'tastes we share',
                  icon: Icons.restaurant_menu_rounded,
                  hue: AppColors.warmAmber,
                  actions: [
                    EverglowIconButton(
                      icon: Icons.add_rounded,
                      onPressed: () => _showAddDialog(),
                      semanticLabel: '''New recipe''',
                      tooltip: '''New recipe''',
                      iconColor: AppColors.blushGold,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EverglowSegmentedControl(
                    selectedIndex: _tabIndex,
                    onChanged: (i) => setState(() => _tabIndex = i),
                    activeColor: AppColors.warmAmber,
                    items: const [
                      SegmentItem('Recipes', Icons.menu_book_rounded),
                      SegmentItem('Planner', Icons.calendar_view_week_rounded),
                      SegmentItem('Shopping', Icons.shopping_cart_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_tabIndex == 0) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: EverglowSearchField(
                      controller: _searchController,
                      hint: 'Search recipes, tags, ingredients...',
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildCategoryChip(null, 'All'),
                        ...RecipeCategory.values.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _buildCategoryChip(
                              c,
                              '${c.emoji} ${c.displayName}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _favoritesOnly = !_favoritesOnly),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _favoritesOnly
                                  ? Colors.redAccent.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _favoritesOnly
                                    ? Colors.redAccent
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _favoritesOnly
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 14,
                                  color: _favoritesOnly
                                      ? Colors.redAccent
                                      : AppTheme.petalWhite.withValues(
                                          alpha: 0.6,
                                        ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Favorites',
                                  style: AppTypography.outfitWhite.copyWith(
                                    fontSize: 12,
                                    color: _favoritesOnly
                                        ? Colors.redAccent
                                        : AppTheme.petalWhite.withValues(
                                            alpha: 0.7,
                                          ),
                                    fontWeight: _favoritesOnly
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildRecipesGrid(service)),
                ] else if (_tabIndex == 1)
                  Expanded(
                    child: _MealPlannerView(service: service, auth: auth),
                  )
                else
                  Expanded(child: _ShoppingListView(service: service)),
              ],
            ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              backgroundColor: AppColors.deepRose,
              foregroundColor: AppColors.petalWhite,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _buildCategoryChip(RecipeCategory? cat, String label) {
    final isSel = _categoryFilter == cat;
    return GestureDetector(
      onTap: () => setState(() => _categoryFilter = cat),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSel
              ? AppColors.deepRose.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSel ? AppColors.blushGold : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 12,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
            color: isSel
                ? AppColors.blushGold
                : AppTheme.petalWhite.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipesGrid(CookbookService service) {
    return StreamBuilder<List<Recipe>>(
      stream: _searchQuery.isNotEmpty
          ? service.watchAll().map(
              (list) => list
                  .where(
                    (r) =>
                        r.title.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ||
                        r.description.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ||
                        r.tags.any(
                          (t) => t.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                        ),
                  )
                  .toList(),
            )
          : service.watchAll(),
      builder: (context, snap) {
        if (snap.hasError) {
          return EverglowErrorState(
            message: 'Could not load recipes',
            onRetry: () => setState(() {}),
            icon: Icons.restaurant_rounded,
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: EverglowSkeleton(
              width: double.infinity,
              height: 140,
              radius: 16,
            ),
          );
        }
        var recipes = snap.data!;
        if (_categoryFilter != null) {
          recipes = recipes
              .where((r) => r.category == _categoryFilter)
              .toList();
        }
        if (_favoritesOnly) {
          recipes = recipes.where((r) => r.isFavorite).toList();
        }
        if (recipes.isEmpty) {
          final isFiltered =
              _categoryFilter != null ||
              _favoritesOnly ||
              _searchQuery.isNotEmpty;
          return EverglowEmptyState(
            icon: Icons.soup_kitchen_rounded,
            title: isFiltered
                ? 'No matching recipes'
                : 'Your cookbook is empty',
            subtitle: isFiltered
                ? 'Try adjusting filters'
                : 'Add your first recipe together 👩‍🍳',
            ctaLabel: isFiltered ? null : 'Add Recipe',
            onCta: isFiltered ? null : _showAddDialog,
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: recipes.length,
          itemBuilder: (context, idx) => RecipeCard(recipe: recipes[idx]),
        );
      },
    );
  }

  void _showAddDialog() {
    showDialog(context: context, builder: (_) => const AddRecipeDialog());
  }
}

class _MealPlannerView extends StatelessWidget {
  final CookbookService service;
  final AuthService auth;
  const _MealPlannerView({required this.service, required this.auth});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekDays = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day).add(Duration(days: i)),
    );

    return StreamBuilder<List<MealPlanEntry>>(
      stream: service.watchMealPlans(days: 7),
      builder: (context, snap) {
        final plans = snap.data ?? [];
        return StreamBuilder<List<Recipe>>(
          stream: service.watchAll(),
          builder: (context, recSnap) {
            final recipes = recSnap.data ?? [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.moonlight.withValues(
                      alpha: AppTheme.glassOpacity,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.blushGold.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_view_week_rounded,
                        size: 16,
                        color: AppColors.warmAmber,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Weekly Planner',
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 13,
                          color: AppTheme.petalWhite,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${plans.length} meals planned',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          color: AppTheme.petalWhite.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...weekDays.map((day) {
                  final dayPlans = plans
                      .where(
                        (p) =>
                            p.date.year == day.year &&
                            p.date.month == day.month &&
                            p.date.day == day.day,
                      )
                      .toList();
                  final isToday =
                      day.year == now.year &&
                      day.month == now.month &&
                      day.day == now.day;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.warmAmber.withValues(alpha: 0.08)
                          : AppTheme.moonlight.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isToday
                            ? AppColors.warmAmber.withValues(alpha: 0.3)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _weekdayName(day.weekday),
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 12,
                                color: isToday
                                    ? AppColors.warmAmber
                                    : AppTheme.petalWhite,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${day.month}/${day.day}',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 11,
                                color: AppTheme.petalWhite.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (isToday)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warmAmber,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'TODAY',
                                  style: AppTypography.outfitWhite.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            TextButton.icon(
                              onPressed: () =>
                                  _showAddMealDialog(context, day, recipes),
                              icon: const Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: AppColors.blushGold,
                              ),
                              label: Text(
                                'Add',
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 11,
                                  color: AppColors.blushGold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (dayPlans.isEmpty)
                          Text(
                            'No meals planned — tap Add',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 11,
                              color: AppTheme.petalWhite.withValues(
                                alpha: 0.45,
                              ),
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else
                          ...dayPlans.map(
                            (plan) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.twilight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.restaurant_rounded,
                                    size: 14,
                                    color: AppColors.blushGold,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      plan.recipeTitle,
                                      style: AppTypography.outfitWhite.copyWith(
                                        fontSize: 13,
                                        color: AppTheme.petalWhite,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.moonlight.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      plan.meal,
                                      style: AppTypography.outfitWhite.copyWith(
                                        fontSize: 10,
                                        color: AppTheme.petalWhite.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        service.removeMealPlan(plan.id),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: AppTheme.petalWhite.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  String _weekdayName(int w) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];

  void _showAddMealDialog(
    BuildContext context,
    DateTime day,
    List<Recipe> recipes,
  ) {
    Recipe? selected;
    String meal = 'dinner';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.velvet,
            title: Text(
              'Plan meal for ${day.month}/${day.day}',
              style: AppTypography.cormorantBold.copyWith(
                fontSize: 18,
                color: AppTheme.petalWhite,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<Recipe>(
                  value: selected,
                  hint: Text(
                    'Choose recipe',
                    style: AppTypography.outfitWhite.copyWith(
                      color: AppTheme.petalWhite.withValues(alpha: 0.5),
                    ),
                  ),
                  isExpanded: true,
                  dropdownColor: AppColors.twilight,
                  items: recipes
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(
                            r.title,
                            style: AppTypography.outfitWhite.copyWith(
                              color: AppTheme.petalWhite,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selected = v),
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  value: meal,
                  isExpanded: true,
                  dropdownColor: AppColors.twilight,
                  items: ['breakfast', 'lunch', 'dinner', 'snack']
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            m,
                            style: AppTypography.outfitWhite.copyWith(
                              color: AppTheme.petalWhite,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => meal = v!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selected == null
                    ? null
                    : () async {
                        await service.addMealPlan(
                          MealPlanEntry(
                            id: '',
                            recipeId: selected!.id,
                            recipeTitle: selected!.title,
                            date: day,
                            meal: meal,
                            plannedBy: auth.currentUser ?? 'unknown',
                          ),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepRose,
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShoppingListView extends StatelessWidget {
  final CookbookService service;
  const _ShoppingListView({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MealPlanEntry>>(
      stream: service.watchMealPlans(days: 7),
      builder: (context, planSnap) {
        final plans = planSnap.data ?? [];
        if (plans.isEmpty) {
          return const EverglowEmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'No shopping list yet',
            subtitle:
                'Plan meals for the week to auto-generate your list (grocy-inspired)',
            ctaLabel: null,
          );
        }
        return StreamBuilder<List<Recipe>>(
          stream: service.watchAll(),
          builder: (context, recSnap) {
            final recipes = recSnap.data ?? [];
            final map = {for (final r in recipes) r.id: r};
            return FutureBuilder<Map<String, String>>(
              future: service.generateShoppingList(plans, map),
              builder: (context, snap) {
                final list = snap.data ?? {};
                if (list.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warmAmber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.warmAmber.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shopping_basket_rounded,
                            size: 18,
                            color: AppColors.warmAmber,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${list.length} ingredients for ${plans.length} meals',
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 13,
                                color: AppTheme.petalWhite,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              'Share',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 11,
                                color: AppColors.warmAmber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...list.entries.map(
                      (e) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.moonlight.withValues(
                            alpha: AppTheme.glassOpacity,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.blushGold.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.transparent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                e.key,
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 13,
                                  color: AppTheme.petalWhite,
                                ),
                              ),
                            ),
                            Text(
                              e.value,
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 12,
                                color: AppColors.blushGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
