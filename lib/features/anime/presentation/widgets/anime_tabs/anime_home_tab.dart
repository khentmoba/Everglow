import 'package:flutter/material.dart' hide FilterChip;
import '../../../../../core/theme/app_breakpoints.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../cinema/data/models/media_item.dart';
import '../../../../../shared/widgets/shelf/scroll_edge_fade.dart';
import '../../../../../shared/widgets/shelf/shelf_hero_carousel.dart';
import '../../../../../shared/widgets/shelf/anime_hero_banner.dart';
import '../../../../../shared/widgets/shelf/shelf_icon_button.dart';
import '../../../../../shared/widgets/shelf/shelf_poster_card.dart';
import '../../../../../shared/widgets/shelf/shelf_section_header.dart';
import '../../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../../shared/widgets/shelf/staggered_entrance.dart';
import '../../../../../shared/widgets/shelf/cinema_sections.dart';
import '../../../../ai/presentation/widgets/ai_recommendations.dart';

import 'anime_models.dart';
import '../../../../../core/theme/app_typography.dart';

// ── Anime palette (subset used by the Home tab) ─────────────────
const _cCard = AppColors.animeCard;
const _cRose = AppColors.animeRose;
const _cDeepRose = AppColors.animeDeepRose;
const _cGold = AppColors.animeGold;
const _cWhite = AppColors.animeWhite;
const _cMuted = AppColors.animeMuted;
const _cCyan = AppColors.animeCyan;
const _cMagenta = AppColors.animeMagenta;
const _cElectricPurple = AppColors.animeElectricPurple;
const _cVibrantPink = AppColors.animeVibrantPink;

// Single source of truth for home-tab genre rail metadata.
const _genreMeta =
    <
      String,
      ({List<int> genreIds, Color color, IconData icon, String subtitle})
    >{
      'Action & Adventure': (
        genreIds: [1, 2],
        color: Color(0xFFE57373),
        icon: Icons.bolt_rounded,
        subtitle: 'High-octane thrills and epic battles',
      ),
      'Romance': (
        genreIds: [22],
        color: Color(0xFFF06292),
        icon: Icons.favorite_rounded,
        subtitle: 'Love stories that warm the heart',
      ),
      'Fantasy & Isekai': (
        genreIds: [10],
        color: Color(0xFFBA68C8),
        icon: Icons.auto_awesome_rounded,
        subtitle: 'Otherworldly adventures and magic',
      ),
      'Comedy': (
        genreIds: [4],
        color: Color(0xFFFFD54F),
        icon: Icons.theater_comedy_rounded,
        subtitle: 'Laughs and good vibes',
      ),
      'Slice of Life': (
        genreIds: [36],
        color: Color(0xFFAED581),
        icon: Icons.local_cafe_rounded,
        subtitle: 'Quiet moments and everyday beauty',
      ),
    };

/// Home tab for the Anime screen.
///
/// Displays the hero carousel, curated content rows (Trending, Airing, Top
/// Rated …), AI recommendations, Top 10 ranking, genre rails, and the
/// user's library sections — all in a single scrollable [ListView].
///
/// All data is supplied via constructor parameters; the parent
/// `AnimeScreen` owns the fetching logic and service instances.
class AnimeHomeTab extends StatelessWidget {
  final List<AnimeHomeSection> homeSections;
  final Map<String, AnimeRowData> homeRows;
  final Map<String, List<MediaItem>> genreRows;
  final List<MediaItem> topTenItems;
  final List<MediaItem> library;
  final Future<void> Function() onRefresh;
  final void Function(MediaItem) onTapItem;
  final VoidCallback onOpenSearch;
  final void Function(AnimeHomeSection) onRetryRow;

  const AnimeHomeTab({
    super.key,
    required this.homeSections,
    required this.homeRows,
    required this.genreRows,
    required this.topTenItems,
    required this.library,
    required this.onRefresh,
    required this.onTapItem,
    required this.onOpenSearch,
    required this.onRetryRow,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _cDeepRose,
      backgroundColor: _cCard,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          StaggeredEntrance(index: 0, child: _buildHeader(context)),
          const SizedBox(height: 8),
          for (var i = 0; i < homeSections.length; i++) ...[
            StaggeredEntrance(
              index: i + 1,
              child: _buildHomeSection(context, homeSections[i]),
            ),
            const SizedBox(height: 24),
          ],

          // ── AI RECOMMENDATIONS ─────────────────────────────────
          StaggeredEntrance(
            index: homeSections.length + 1,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AIRecommendations(
                title: "Mochi's Picks",
                autoLoad: true,
                onTapItem: (item) => onTapItem(item),
              ),
            ),
          ),

          // ── TOP 10 RANKING ─────────────────────────────────────
          if (topTenItems.isNotEmpty)
            StaggeredEntrance(
              index: homeSections.length + 2,
              child: TopTenRankingSection(
                items: buildRankingItems(
                  items: topTenItems,
                  getTitle: (m) => m.title,
                  getImageUrl: (m) =>
                      m.posterPath.isNotEmpty ? m.posterPath : '',
                  getSubtitle: (m) => m.year.isNotEmpty ? m.year : null,
                  getBadge: (m) => 'ANIME',
                  onTap: (m) => onTapItem(m),
                ),
                eyebrow: 'Trending Today',
                title: 'TOP 10 Anime',
                accent: _cMagenta,
              ),
            ),

          // ── GENRE ROWS ─────────────────────────────────────────
          for (var gi = 0; gi < genreRows.length; gi++) ...[
            StaggeredEntrance(
              index: homeSections.length + 3 + gi,
              child: _buildGenreRow(
                context,
                genreRows.keys.elementAt(gi),
                genreRows.values.elementAt(gi),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── LIBRARY SECTIONS ───────────────────────────────────
          if (library.where((i) => i.isCurrentlyWatching).isNotEmpty) ...[
            StaggeredEntrance(
              index: homeSections.length + 3 + genreRows.length,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: ShelfSectionHeader(
                  eyebrow: 'Resume Playing',
                  title: 'Currently Watching',
                  subtitle: 'Pick up where you left off',
                  icon: Icons.play_circle_filled_rounded,
                  accent: AppColors.cinemaOrange,
                  count: library.where((i) => i.isCurrentlyWatching).length,
                  countLabel: 'titles',
                ),
              ),
            ),
            _buildContinueWatchingRow(
              context,
              library.where((i) => i.isCurrentlyWatching).toList(),
            ),
            const SizedBox(height: 24),
          ],
          if (library.where((i) => i.isToWatch).isNotEmpty) ...[
            StaggeredEntrance(
              index: homeSections.length + 4 + genreRows.length,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: ShelfSectionHeader(
                  eyebrow: 'Up Next',
                  title: 'In Your Queue',
                  subtitle: 'Anime you plan to watch',
                  icon: Icons.bookmark_rounded,
                  accent: _cGold,
                  count: library.where((i) => i.isToWatch).length,
                  countLabel: 'titles',
                ),
              ),
            ),
            _buildPosterRow(
              context,
              library.where((i) => i.isToWatch).toList(),
            ),
            const SizedBox(height: 24),
          ],
          if (library.where((i) => i.isWatched).isNotEmpty) ...[
            StaggeredEntrance(
              index: homeSections.length + 5 + genreRows.length,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: ShelfSectionHeader(
                  eyebrow: 'Already Finished',
                  title: 'Watched',
                  subtitle: 'Anime you\'ve completed',
                  icon: Icons.remove_red_eye_rounded,
                  accent: _cGold,
                  count: library.where((i) => i.isWatched).length,
                  countLabel: 'titles',
                ),
              ),
            ),
            _buildPosterRow(
              context,
              library.where((i) => i.isWatched).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  // ── PRIVATE BUILD HELPERS ────────────────────────────────────────

  Widget _buildHomeSection(BuildContext context, AnimeHomeSection section) {
    final row = homeRows[section.id];
    if (row == null) {
      return _buildShimmerRow(context, height: section.isHero ? 540 : 290);
    }
    if (row.isLoading) {
      return _buildShimmerRow(context, height: section.isHero ? 540 : 290);
    }
    if (row.items.isEmpty) {
      if (row.hasError) {
        return _buildErrorRow(context, section);
      }
      return const SizedBox.shrink();
    }
    if (section.isHero) {
      return _buildHeroCarousel(context, row.items, section);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: ShelfSectionHeader(
            eyebrow: _eyebrowForSection(section.id),
            title: section.title,
            subtitle: _subtitleForSection(section.id),
            icon: section.icon,
            accent: section.tint,
            count: row.items.length,
            countLabel: 'titles',
          ),
        ),
        _buildPosterRow(context, row.items, accent: section.tint),
      ],
    );
  }

  Widget _buildGenreRow(
    BuildContext context,
    String genreName,
    List<MediaItem> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    final meta = _genreMeta[genreName];
    final color = meta?.color ?? _cCyan;
    final icon = meta?.icon ?? Icons.category_rounded;
    final subtitle = meta?.subtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: ShelfSectionHeader(
            eyebrow: 'GENRE',
            title: genreName,
            subtitle: subtitle,
            icon: icon,
            accent: color,
            count: items.length,
            countLabel: 'titles',
          ),
        ),
        _buildPosterRow(context, items, accent: color),
      ],
    );
  }

  String _eyebrowForSection(String id) {
    switch (id) {
      case 'airing':
        return 'Now Airing';
      case 'top-rated':
        return 'All Time Best';
      case 'new-releases':
        return 'Just Added';
      case 'popular-all':
        return 'Fan Favourites';
      case 'hidden-gems':
        return 'Worth Discovering';
      case 'editors-picks':
        return "Mochi's Picks";
      case 'you-might-like':
        return 'Curated For You';
      case 'trending':
      default:
        return 'Hot Right Now';
    }
  }

  String? _subtitleForSection(String id) {
    switch (id) {
      case 'airing':
        return 'New episodes dropping this season';
      case 'top-rated':
        return 'Highest scores from the community';
      case 'new-releases':
        return 'Freshly added this season';
      case 'popular-all':
        return 'Enduring fan favourites';
      case 'hidden-gems':
        return 'Underrated picks worth discovering';
      case 'editors-picks':
        return 'Mochi\'s personal recommendations';
      case 'you-might-like':
        return 'Curated based on your taste';
      case 'trending':
      default:
        return 'What everyone\'s watching right now';
    }
  }

  Widget _buildHeroCarousel(
    BuildContext context,
    List<MediaItem> items,
    AnimeHomeSection section,
  ) {
    final heroItems = items.take(5).map((m) {
      final rank = items.indexOf(m) + 1;
      return ShelfHeroItem(
        id: '${m.tmdbId}',
        title: m.title,
        subtitle: m.year.isNotEmpty ? m.year : 'Tap to explore',
        eyebrow: rank <= 3 ? '★ Top $rank' : 'Trending #$rank',
        imageUrl: m.backdropUrl.isNotEmpty ? m.backdropUrl : m.posterPath,
        posterUrl: m.posterPath,
        synopsis: m.synopsis,
        episodeCount: m.episodeCount,
        format: m.format,
        airingStatus: m.airingStatus,
        year: m.year,
        accent: _cMagenta,
        onTap: () => onTapItem(m),
      );
    }).toList();

    return AnimeHeroBanner(
      items: heroItems,
      holdDuration: const Duration(seconds: 18),
      height: AppBreakpoint.isDesktop(context) ? 520 : 420,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
      child: Row(
        children: [
          if (canPop)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ShelfIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                semanticLabel: 'Back',
                tooltip: 'Back',
                onTap: () => Navigator.pop(context),
              ),
            )
          else
            const SizedBox(width: 48),
          const _AnimeLogo(size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Everglow Anime',
                  style: AppTypography.cormorantBold.copyWith(
                    fontSize: 26,
                    height: 1.1,
                    color: _cRose,
                  ),
                ),
                Text(
                  'Discover · Watch · Collect',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 11,
                    color: _cCyan.withValues(alpha: 0.8),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onOpenSearch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _cCard.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _cRose.withValues(alpha: 0.15),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_rounded, color: _cMuted, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Search anime...',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 12,
                      color: _cMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerRow(BuildContext context, {required double height}) {
    final isDesktop = AppBreakpoint.isDesktop(context);
    final isTablet = AppBreakpoint.isTablet(context);
    final shimmerWidth = isDesktop ? 170.0 : (isTablet ? 150.0 : 130.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: SizedBox(
        height: height - 14,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => EverglowSkeleton(
            width: shimmerWidth,
            height: height - 14,
            radius: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorRow(BuildContext context, AnimeHomeSection section) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: ShelfSectionHeader(
              eyebrow: _eyebrowForSection(section.id),
              title: section.title,
              icon: section.icon,
              accent: section.tint,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _cCard.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: section.tint.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: _cMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Couldn\'t load ${section.title.toLowerCase()}',
                    style: AppTypography.outfitWhite.copyWith(
                      color: _cMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => onRetryRow(section),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: section.tint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: section.tint.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Retry',
                      style: AppTypography.outfitBold.copyWith(
                        color: section.tint,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterRow(
    BuildContext context,
    List<MediaItem> items, {
    Color accent = _cRose,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Text(
          'Nothing here yet. Search above to add your first anime!',
          style: AppTypography.outfitWhite.copyWith(
            color: _cMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final isDesktop = AppBreakpoint.isDesktop(context);
    final isTablet = AppBreakpoint.isTablet(context);
    final cardWidth = isDesktop ? 170.0 : (isTablet ? 150.0 : 130.0);
    final cardHeight = isDesktop ? 290.0 : (isTablet ? 260.0 : 230.0);

    return ScrollEdgeFade(
      fadeColor: AppColors.animeBackground,
      child: SizedBox(
        height: cardHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: ShelfPosterCard(
                imageUrl: item.posterPath,
                title: item.title,
                subtitle: item.year.isNotEmpty ? item.year : null,
                badge: 'ANIME',
                badgeIcon: Icons.auto_awesome_rounded,
                badgeColor: _cVibrantPink,
                synopsis: item.synopsis,
                episodeCount: item.episodeCount?.toString(),
                format: item.format,
                airingStatus: item.airingStatus,
                genres: item.genres,
                currentEpisode: item.currentEpisode,
                onTap: () => onTapItem(item),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContinueWatchingRow(
    BuildContext context,
    List<MediaItem> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    final isDesktop = AppBreakpoint.isDesktop(context);

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item = items[i];
          final season = item.currentSeason;
          final episode = item.currentEpisode;
          String? progressLabel;
          if (item.isMovie) {
            progressLabel = 'Movie';
          } else if (season != null && episode != null) {
            progressLabel = 'S$season E$episode';
          } else if (episode != null) {
            progressLabel = 'Ep $episode';
          }

          return GestureDetector(
            onTap: () => onTapItem(item),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: isDesktop ? 320 : 260,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.black.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(color: _cCyan.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: _cCyan.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item.backdropUrl.isNotEmpty)
                        Image.network(
                          item.backdropUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 900,
                          errorBuilder: (_, _, _) => Image.network(
                            item.posterPath,
                            fit: BoxFit.cover,
                            cacheWidth: 400,
                            errorBuilder: (_, _, _) => Container(color: _cCard),
                          ),
                        )
                      else if (item.posterPath.isNotEmpty)
                        Image.network(
                          item.posterPath,
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          errorBuilder: (_, _, _) => Container(color: _cCard),
                        )
                      else
                        Container(color: _cCard),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.88),
                              Colors.black.withValues(alpha: 0.25),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        top: 14,
                        bottom: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (progressLabel != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _cCyan,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _cCyan.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  progressLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.cormorantBoldWhite.copyWith(
                                fontSize: 16,
                                height: 1.15,
                              ),
                            ),
                            if (item.year.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.year,
                                style: AppTypography.outfitBold.copyWith(
                                  color: AppTheme.warmAmber,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value:
                                    (episode != null &&
                                        item.episodeCount != null &&
                                        item.episodeCount! > 0)
                                    ? (episode / item.episodeCount!).clamp(
                                        0.0,
                                        1.0,
                                      )
                                    : 0.0,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.15,
                                ),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  _cCyan,
                                ),
                                minHeight: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _cCyan.withValues(alpha: 0.9),
                              boxShadow: [
                                BoxShadow(
                                  color: _cCyan.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── ANIME LOGO WIDGET ────────────────────────────────────────────

/// Animated gradient logo icon with pulsing glow for the header.
class _AnimeLogo extends StatefulWidget {
  final double size;
  const _AnimeLogo({this.size = 44});

  @override
  State<_AnimeLogo> createState() => _AnimeLogoState();
}

class _AnimeLogoState extends State<_AnimeLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_cMagenta, _cElectricPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _cMagenta.withValues(alpha: 0.3 + _pulse.value * 0.25),
                blurRadius: 12 + _pulse.value * 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: _cWhite,
            size: 22,
          ),
        );
      },
    );
  }
}
