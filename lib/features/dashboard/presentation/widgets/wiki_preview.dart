import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/wiki/data/models/wiki_page.dart';
import '../../../../features/wiki/data/services/wiki_service.dart';
import 'feature_section.dart';

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
            final pinned = pages.where((p) => p.isPinned).length;

            final subtitle = shelves.isEmpty
                ? 'No lore yet — create your first shelf'
                : '${shelves.length} ${shelves.length == 1 ? 'shelf' : 'shelves'}'
                      ' • ${pages.length} ${pages.length == 1 ? 'page' : 'pages'}'
                      '${pinned > 0 ? ' • $pinned pinned' : ''}';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: FeatureSection(
                icon: Icons.auto_stories_rounded,
                hue: AppColors.auroraLilac,
                title: 'Our Universe',
                subtitle: subtitle,
                trailing: const SectionChevron(hue: AppColors.auroraLilac),
                onTap: () => context.push('/wiki'),
                child: shelves.isEmpty && pages.isEmpty
                    ? const _EmptyUniverse(hue: AppColors.auroraLilac)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (shelves.isNotEmpty) ...[
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: shelves.take(4).map((s) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.auroraLilac.withValues(
                                          alpha: 0.18,
                                        ),
                                        AppColors.auroraLilac.withValues(
                                          alpha: 0.06,
                                        ),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.auroraLilac.withValues(
                                        alpha: 0.22,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.bookmark_rounded,
                                        size: 11,
                                        color: AppColors.auroraLilac,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        s.title.isEmpty
                                            ? 'Untitled shelf'
                                            : s.title,
                                        style: AppTypography.outfitBold
                                            .copyWith(
                                              fontSize: 11,
                                              color: AppColors.auroraLilac,
                                            ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        s.icon,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (pages.isNotEmpty)
                            ...pages
                                .take(2)
                                .map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: AppColors.auroraLilac
                                                .withValues(alpha: 0.13),
                                            borderRadius: AppRadius.radiusSm,
                                            border: Border.all(
                                              color: AppColors.auroraLilac
                                                  .withValues(alpha: 0.20),
                                            ),
                                          ),
                                          child: Icon(
                                            p.isPinned
                                                ? Icons.push_pin_rounded
                                                : Icons.article_rounded,
                                            size: 14,
                                            color: AppColors.auroraLilac,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            p.title.isEmpty
                                                ? 'Untitled page'
                                                : p.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.outfitWhite
                                                .copyWith(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.petalWhite
                                                      .withValues(alpha: 0.88),
                                                ),
                                          ),
                                        ),
                                        if (p.isPinned)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.auroraGold
                                                  .withValues(alpha: 0.16),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'PINNED',
                                              style: AppTypography.outfitWhite
                                                  .copyWith(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.6,
                                                    color: AppColors.auroraGold,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
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

class _EmptyUniverse extends StatelessWidget {
  final Color hue;
  const _EmptyUniverse({required this.hue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.07),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: hue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_stories_rounded, size: 16, color: hue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Build your lore',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 12,
                    color: AppColors.petalWhite.withValues(alpha: 0.88),
                  ),
                ),
                Text(
                  'Inside jokes, timelines, headcanons — your canon.',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 11,
                    color: AppColors.petalWhite.withValues(alpha: 0.50),
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
