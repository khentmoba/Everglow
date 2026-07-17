import 'package:flutter/material.dart' hide FilterChip;
import 'package:google_fonts/google_fonts.dart';

import 'package:everglow/core/theme/app_breakpoints.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/features/cinema/data/anime_categories.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/shared/widgets/shelf/filter_chip.dart';
import 'package:everglow/shared/widgets/shelf/shelf_poster_card.dart';
import 'package:everglow/shared/widgets/shelf/shelf_empty_state.dart';
import 'package:everglow/shared/widgets/shelf/shimmer_box.dart';

import 'anime_models.dart';

// ── Anime palette (subset used by the Browse tab) ───────────────
const _cRose           = AppColors.animeRose;
const _cMuted          = AppColors.animeMuted;
const _cCyan           = AppColors.animeCyan;
const _cMagenta        = AppColors.animeMagenta;
const _cElectricPurple = AppColors.animeElectricPurple;
const _cVibrantPink    = AppColors.animeVibrantPink;

/// Browse / Discover tab for the Anime screen.
///
/// Renders filter chip groups (By Format, By Genre, By Status, Discovery,
/// By Season) and an inline results grid for the currently selected
/// category. All data is supplied via constructor parameters; the parent
/// `AnimeScreen` owns the fetching logic.
class AnimeBrowseTab extends StatelessWidget {
  final String? selectedCategoryId;
  final Map<String, AnimeRowData> browseResults;
  final void Function(AnimeCategoryOption) onSelectCategory;
  final void Function(MediaItem) onTapItem;
  final VoidCallback onClearFilter;

  const AnimeBrowseTab({
    super.key,
    required this.selectedCategoryId,
    required this.browseResults,
    required this.onSelectCategory,
    required this.onTapItem,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_cMagenta, _cCyan],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Browse',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _cRose,
                ),
              ),
              const Spacer(),
              if (selectedCategoryId != null)
                GestureDetector(
                  onTap: onClearFilter,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _cMagenta.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _cMagenta.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded,
                              color: _cMagenta, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Clear Filter',
                            style: GoogleFonts.outfit(
                              color: _cMagenta,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Text(
            'Filter by format, genre, status, or curated list.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: _cRose.withValues(alpha: 0.6),
            ),
          ),
        ),
        ...AnimeCategoryGroup.values.map(
          (group) => _buildBrowseGroup(context, group),
        ),
        const SizedBox(height: 16),
        if (selectedCategoryId != null) _buildBrowseResults(context),
      ],
    );
  }

  // ── PRIVATE BUILD HELPERS ────────────────────────────────────────

  Widget _buildBrowseGroup(BuildContext context, AnimeCategoryGroup group) {
    final options =
        animeCategoryOptions.where((o) => o.group == group).toList();
    final groupMeta = _groupMeta(group);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        groupMeta.tint,
                        groupMeta.tint.withValues(alpha: 0.25),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(groupMeta.icon, color: groupMeta.tint, size: 18),
                const SizedBox(width: 8),
                Text(
                  groupMeta.title,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: groupMeta.tint,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  groupMeta.subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: _cMuted,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final option = options[i];
                final selected = selectedCategoryId == option.id;
                return FilterChip(
                  icon: option.icon,
                  label: option.label,
                  color: option.color,
                  selected: selected,
                  onTap: () => onSelectCategory(option),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseResults(BuildContext context) {
    final isDesktop = AppBreakpoint.isDesktop(context);
    final row = browseResults[selectedCategoryId];
    final option = animeCategoryOptions.firstWhere(
      (o) => o.id == selectedCategoryId,
      orElse: () => animeCategoryOptions.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: option.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(option.icon, color: option.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: option.color,
                      ),
                    ),
                    if (row != null && !row.isLoading && row.items.isNotEmpty)
                      Text(
                        '${row.items.length} titles found',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: _cMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (row == null || row.isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 12,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    isDesktop ? 6 : (AppBreakpoint.isTablet(context) ? 4 : 2),
                childAspectRatio: 0.65,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (_, _) => const ShimmerBox(height: 220, radius: 14),
            ),
          )
        else if (row.items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: row.hasError
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _cCard.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: option.color.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            color: _cMuted, size: 28),
                        const SizedBox(height: 12),
                        Text(
                          'Couldn\'t load results',
                          style: GoogleFonts.outfit(
                            color: _cMuted,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => onSelectCategory(option),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: option.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: option.color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'Retry',
                              style: GoogleFonts.outfit(
                                color: option.color,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ShelfEmptyState(
                    icon: Icons.travel_explore_rounded,
                    title: 'No matches in this category yet',
                    subtitle:
                        'Try another filter, or pull to refresh to fetch the latest.',
                    accent: option.color,
                  ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: row.items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:
                  isDesktop ? 6 : (AppBreakpoint.isTablet(context) ? 4 : 2),
              childAspectRatio: 0.65,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (context, i) {
              final item = row.items[i];
              return ShelfPosterCard(
                imageUrl: item.posterPath,
                title: item.title,
                subtitle: item.year.isNotEmpty ? item.year : null,
                badge: 'ANIME',
                badgeIcon: Icons.animation_rounded,
                badgeColor: option.color,
                onTap: () => onTapItem(item),
              );
            },
          ),
      ],
    );
  }

  AnimeBrowseGroupMeta _groupMeta(AnimeCategoryGroup g) {
    switch (g) {
      case AnimeCategoryGroup.format:
        return const AnimeBrowseGroupMeta(
          title: 'By Format',
          subtitle: 'MOVIES · SERIES · OVAs',
          icon: Icons.movie_filter_rounded,
          tint: _cCyan,
        );
      case AnimeCategoryGroup.genre:
        return const AnimeBrowseGroupMeta(
          title: 'By Genre',
          subtitle: 'TAP TO FILTER',
          icon: Icons.theater_comedy_rounded,
          tint: _cVibrantPink,
        );
      case AnimeCategoryGroup.status:
        return const AnimeBrowseGroupMeta(
          title: 'By Status',
          subtitle: 'AIRING · COMPLETED · NEW',
          icon: Icons.live_tv_rounded,
          tint: _cMagenta,
        );
      case AnimeCategoryGroup.discovery:
        return const AnimeBrowseGroupMeta(
          title: 'Discovery',
          subtitle: 'CURATED PICKS',
          icon: Icons.workspace_premium_rounded,
          tint: _cElectricPurple,
        );
      case AnimeCategoryGroup.season:
        return const AnimeBrowseGroupMeta(
          title: 'By Season',
          subtitle: 'SPRING · SUMMER · FALL · WINTER',
          icon: Icons.calendar_view_month_rounded,
          tint: Color(0xFFFFB74D),
        );
    }
  }
}

// Re-export the card colour constant used in error boxes.
const _cCard = AppColors.animeCard;
