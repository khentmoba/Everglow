import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/cookbook/data/models/recipe.dart';
import '../../../../features/cookbook/data/services/cookbook_service.dart';

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
        return GestureDetector(
          onTap: () => context.push('/cookbook'),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.moonlight.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.restaurant_menu_rounded, size: 18, color: AppColors.warmAmber), const SizedBox(width: 8), Text('Our Cookbook', style: AppTypography.outfitBold.copyWith(fontSize: 14, color: AppColors.petalWhite)), const Spacer(), Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.warmAmber)]),
                const SizedBox(height: 6),
                Text(recipes.isEmpty ? 'No recipes yet — add your first dish' : '${recipes.length} recipes • $fav favorites', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppColors.petalWhite.withValues(alpha: 0.6))),
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...recent.map((r) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Text(r.category.emoji, style: const TextStyle(fontSize: 12)), const SizedBox(width: 6), Expanded(child: Text(r.title, style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppColors.petalWhite.withValues(alpha: 0.85)), maxLines: 1, overflow: TextOverflow.ellipsis)), Text('${r.cookMinutes}m', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppColors.petalWhite.withValues(alpha: 0.5)))]))),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
