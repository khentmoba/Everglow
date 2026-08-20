import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/wiki/data/models/wiki_page.dart';
import '../../../../features/wiki/data/services/wiki_service.dart';

class WikiPreview extends StatelessWidget {
  const WikiPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final service = WikiService();
    return StreamBuilder<List<WikiPage>>(
      stream: service.watchAllPages(),
      builder: (context, snap) {
        final pages = snap.data ?? <WikiPage>[];
        return StreamBuilder<List<WikiShelf>>(
          stream: service.watchShelves(),
          builder: (context, shelfSnap) {
            final shelves = shelfSnap.data ?? <WikiShelf>[];
            return GestureDetector(
              onTap: () => context.push('/wiki'),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.softLavender.withValues(alpha: 0.18))),
                child: Row(
                  children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.softLavender.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(Icons.menu_book_rounded, color: AppColors.softLavender, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Our Universe', style: AppTypography.outfitBold.copyWith(fontSize: 14, color: AppColors.petalWhite)),
                          const SizedBox(height: 4),
                          Text(shelves.isEmpty ? 'No lore yet — create your first shelf' : '${shelves.length} shelves • ${pages.length} pages • ${pages.where((p) => p.isPinned).length} pinned', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppColors.petalWhite.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.softLavender, size: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
