import 'package:flutter/material.dart';
import '../../../../../core/theme/app_breakpoints.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../cinema/data/models/media_item.dart';
import '../../../../../shared/widgets/shelf/shelf_poster_card.dart';
import '../../../../../shared/widgets/shelf/shelf_section_header.dart';
import '../../../../../shared/widgets/shelf/anime_cta_button.dart';
import '../../../../../core/theme/app_typography.dart';

// ── Anime palette (subset used by the Library tab) ──────────────
const _cWhite = AppColors.animeWhite;
const _cMuted = AppColors.animeMuted;
const _cCyan = AppColors.animeCyan;
const _cMagenta = AppColors.animeMagenta;
const _cElectricPurple = AppColors.animeElectricPurple;
const _cVibrantPink = AppColors.animeVibrantPink;

/// Library tab for the Anime screen.
///
/// Displays the user's combined anime catalog split into "Currently
/// Watching", "Want to Watch", and "Watched" sections with partner
/// attribution. An empty state invites users to search for their first
/// anime.
class AnimeLibraryTab extends StatelessWidget {
  final List<MediaItem> library;
  final void Function(MediaItem) onTapItem;
  final VoidCallback onOpenSearch;

  const AnimeLibraryTab({
    super.key,
    required this.library,
    required this.onTapItem,
    required this.onOpenSearch,
  });

  @override
  Widget build(BuildContext context) {
    final currentlyWatching = library.currentlyWatching;
    final wantToWatch = library.toWatch;
    final watched = library.watched;

    if (currentlyWatching.isEmpty && wantToWatch.isEmpty && watched.isEmpty) {
      return _buildEmptyState(context);
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
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
                      'OUR ANIME',
                      style: AppTypography.cormorantBlack.copyWith(
                        fontSize: 24,
                        letterSpacing: 3,
                        color: _cWhite,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    'JAPANESE ANIMATION',
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 9,
                      color: _cMuted,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _LibraryStat(
                      label: 'Watching',
                      count: currentlyWatching.length,
                      color: AppColors.cinemaOrange,
                    ),
                    const SizedBox(width: 8),
                    _LibraryStat(
                      label: 'Queue',
                      count: wantToWatch.length,
                      color: _cCyan,
                    ),
                    const SizedBox(width: 8),
                    _LibraryStat(
                      label: 'Watched',
                      count: watched.length,
                      color: const Color(0xFF8BC34A),
                    ),
                    const SizedBox(width: 8),
                    _LibraryStat(
                      label: 'Total',
                      count:
                          currentlyWatching.length +
                          wantToWatch.length +
                          watched.length,
                      color: _cVibrantPink,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ..._buildLibrarySectionSlivers(
          context,
          'Currently Watching',
          currentlyWatching,
          Icons.play_circle_filled_rounded,
          AppColors.cinemaOrange,
        ),
        ..._buildLibrarySectionSlivers(
          context,
          'Want to Watch',
          wantToWatch,
          Icons.bookmark_rounded,
          _cCyan,
        ),
        ..._buildLibrarySectionSlivers(
          context,
          'Watched',
          watched,
          Icons.remove_red_eye_rounded,
          const Color(0xFF8BC34A),
        ),
      ],
    );
  }

  // ── PRIVATE BUILD HELPERS ────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_cMagenta, _cElectricPurple],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _cMagenta.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: -8,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.collections_bookmark_rounded,
                color: _cWhite,
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your anime library is empty',
              style: AppTypography.cormorantBold.copyWith(
                fontSize: 24,
                color: _cWhite,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for any series and add it to your watchlist.\nItems you mark as watched will live here too.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                color: _cMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            AnimeCtaButton(
              label: 'Search Anime',
              icon: Icons.search_rounded,
              onTap: onOpenSearch,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLibrarySectionSlivers(
    BuildContext context,
    String title,
    List<MediaItem> items,
    IconData icon,
    Color accent,
  ) {
    if (items.isEmpty) return const [];
    final isDesktop = AppBreakpoint.isDesktop(context);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: ShelfSectionHeader(
            eyebrow: 'COLLECTION',
            title: title,
            icon: icon,
            accent: accent,
            count: items.length,
            countLabel: 'titles',
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid.builder(
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop
                ? 6
                : (AppBreakpoint.isTablet(context) ? 4 : 2),
            childAspectRatio: 0.65,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final badge = title == 'Currently Watching'
                ? (!item.isMovie && item.currentEpisode != null
                      ? 'S${item.currentSeason ?? 1}E${item.currentEpisode}'
                      : 'WATCHING')
                : title == 'Watched'
                ? 'WATCHED'
                : 'QUEUE';
            return ShelfPosterCard(
              imageUrl: item.posterPath,
              title: item.title,
              subtitle: item.year.isNotEmpty ? item.year : null,
              badge: badge,
              badgeColor: accent,
              synopsis: item.synopsis,
              episodeCount: item.episodeCount?.toString(),
              format: item.format,
              airingStatus: item.airingStatus,
              currentEpisode: item.currentEpisode,
              onTap: () => onTapItem(item),
            );
          },
        ),
      ),
    ];
  }
}

// ── STAT CHIP ───────────────────────────────────────────────────

/// Small tinted stat chip used in the library header.
/// Uses Expanded to prevent overflow on smaller screens.
class _LibraryStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _LibraryStat({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: AppTypography.cormorantBlack.copyWith(
                fontSize: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.outfitHeading.copyWith(
                fontSize: 10,
                color: color.withValues(alpha: 0.8),
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
