import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/recipe.dart';
import '../../data/services/cookbook_service.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const RecipeCard({super.key, required this.recipe, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _showDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panelGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: recipe.isFavorite
                ? AppColors.blushGold.withValues(alpha: 0.22)
                : AppColors.moonlight.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder with category emoji
            Container(
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _catColor(recipe.category).withValues(alpha: 0.25),
                    AppColors.inkDeep.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      recipe.category.emoji,
                      style: const TextStyle(fontSize: 42),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => CookbookService().toggleFavorite(
                        recipe.id,
                        !recipe.isFavorite,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          recipe.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 14,
                          color: recipe.isFavorite
                              ? AppColors.error
                              : AppColors.petalWhite,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${recipe.cookMinutes}m • ${recipe.servings} servings',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 10,
                          color: AppColors.petalWhite,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.title,
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 13,
                            color: AppColors.petalWhite,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (recipe.difficulty == RecipeDifficulty.hard)
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: AppColors.error,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.description.isEmpty
                        ? 'No description'
                        : recipe.description,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 11,
                      color: AppColors.petalWhite.withValues(alpha: 0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _catColor(
                            recipe.category,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          recipe.category.displayName,
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 10,
                            color: _catColor(recipe.category),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (recipe.timesCooked > 0)
                        Text(
                          '🍳 ${recipe.timesCooked}x',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 10,
                            color: AppColors.petalWhite.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                  if (recipe.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: recipe.tags
                          .take(3)
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.softLavender.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '#$t',
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 9,
                                  color: AppColors.softLavender,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _catColor(RecipeCategory c) {
    switch (c) {
      case RecipeCategory.breakfast:
        return AppColors.warmAmber;
      case RecipeCategory.lunch:
        return AppColors.auroraTeal;
      case RecipeCategory.dinner:
        return AppColors.deepRose;
      case RecipeCategory.dessert:
        return AppColors.blushGold;
      case RecipeCategory.drink:
        return AppColors.auroraLilac;
      case RecipeCategory.snack:
        return AppColors.softLavender;
      case RecipeCategory.other:
        return AppColors.moonlight;
    }
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RecipeDetailSheet(recipe: recipe),
    );
  }
}

class _RecipeDetailSheet extends StatelessWidget {
  final Recipe recipe;
  const _RecipeDetailSheet({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.velvet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.2)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.petalWhite.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  recipe.category.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    recipe.title,
                    style: AppTypography.cormorantBold.copyWith(fontSize: 22),
                  ),
                ),
                IconButton(
                  onPressed: () => CookbookService().toggleFavorite(
                    recipe.id,
                    !recipe.isFavorite,
                  ),
                  icon: Icon(
                    recipe.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: recipe.isFavorite
                        ? AppColors.error
                        : AppColors.petalWhite,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(
                    '${recipe.cookMinutes} min',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: AppColors.moonlight.withValues(alpha: 0.08),
                ),
                Chip(
                  label: Text(
                    '${recipe.servings} servings',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: AppColors.moonlight.withValues(alpha: 0.08),
                ),
                Chip(
                  label: Text(
                    recipe.difficulty.name,
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: AppColors.deepRose.withValues(alpha: 0.12),
                ),
              ],
            ),
            if (recipe.sourceUrl != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'Source: ${recipe.sourceUrl}',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 11,
                    color: AppColors.blushGold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              recipe.description,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 13,
                color: AppColors.petalWhite.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ingredients',
              style: AppTypography.outfitBold.copyWith(
                fontSize: 14,
                color: AppColors.petalWhite,
              ),
            ),
            const SizedBox(height: 8),
            ...recipe.ingredients.map(
              (ing) => Container(
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
                      Icons.circle,
                      size: 6,
                      color: AppColors.blushGold,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ing.name,
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 13,
                          color: AppColors.petalWhite,
                        ),
                      ),
                    ),
                    Text(
                      ing.amount,
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 12,
                        color: AppColors.blushGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Steps',
              style: AppTypography.outfitBold.copyWith(
                fontSize: 14,
                color: AppColors.petalWhite,
              ),
            ),
            const SizedBox(height: 8),
            ...recipe.steps.asMap().entries.map(
              (e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.moonlight.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppColors.deepRose,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: const TextStyle(
                            color: AppColors.petalWhite,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.value,
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.petalWhite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await CookbookService().incrementCooked(
                        recipe.id,
                        recipe.timesCooked,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.soup_kitchen_rounded,
                      size: 16,
                      color: AppColors.warmAmber,
                    ),
                    label: Text(
                      'Cooked! (+1)',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 12,
                        color: AppColors.warmAmber,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.warmAmber.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          backgroundColor: AppColors.velvet,
                          title: Text(
                            'Delete recipe?',
                            style: AppTypography.outfitBold.copyWith(
                              color: AppColors.petalWhite,
                            ),
                          ),
                          content: Text(
                            'This cannot be undone.',
                            style: AppTypography.outfitWhite.copyWith(
                              color: AppColors.petalWhite.withValues(alpha: 0.7),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await CookbookService().delete(recipe.id);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
