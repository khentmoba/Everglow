import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/cookbook/data/models/recipe.dart';
import '../../../../features/cookbook/data/services/cookbook_service.dart';
import 'feature_section.dart';

class CookbookPreview extends StatelessWidget {
  const CookbookPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final service = CookbookService();
    return StreamBuilder<List<Recipe>>(
      stream: service.watchAll(),
      builder: (context, snap) {
        final recipes = snap.data ?? [];
        final fav = recipes.where((r) => r.isFavorite).length;
        final recent = recipes.take(3).toList();

        final subtitle = recipes.isEmpty
            ? 'No recipes yet — add your first dish'
            : '${recipes.length} recipes${fav > 0 ? ' • $fav favorites' : ''}';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: FeatureSection(
            icon: Icons.restaurant_menu_rounded,
            hue: AppColors.warmAmber,
            title: 'Our Cookbook',
            subtitle: subtitle,
            trailing: const SectionChevron(hue: AppColors.warmAmber),
            onTap: () => context.push('/cookbook'),
            child: recent.isEmpty
                ? const _EmptyRow(
                    hue: AppColors.warmAmber,
                    text:
                        'Adobo, pasta, late-night snacks — save your flavors.',
                  )
                : Column(
                    children: recent.map((r) => _RecipeRow(recipe: r)).toList(),
                  ),
          ),
        );
      },
    );
  }
}

class _RecipeRow extends StatelessWidget {
  final Recipe recipe;
  const _RecipeRow({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.warmAmber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.warmAmber.withValues(alpha: 0.22),
              ),
              image: (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(recipe.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (recipe.imageUrl == null || recipe.imageUrl!.isEmpty)
                ? Center(
                    child: Text(
                      recipe.category.emoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        recipe.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.petalWhite.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                    if (recipe.isFavorite) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: AppColors.auroraGold,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  recipe.category.displayName.toUpperCase(),
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warmAmber.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.warmAmber.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 10,
                  color: AppColors.warmAmber,
                ),
                const SizedBox(width: 3),
                Text(
                  '${recipe.cookMinutes}m',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warmAmber,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final Color hue;
  final String text;
  const _EmptyRow({required this.hue, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.08),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(Icons.soup_kitchen_rounded, size: 16, color: hue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 11,
                color: AppColors.petalWhite.withValues(alpha: 0.60),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
