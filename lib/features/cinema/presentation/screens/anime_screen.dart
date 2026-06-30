import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Picture, PictureRecorder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/anime_categories.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/jikan_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/features/cinema/presentation/widgets/jikan_search_modal.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/shared/widgets/shelf/atmospheric_backdrop.dart';
import 'package:everglow/shared/widgets/shelf/scroll_edge_fade.dart';
import 'package:everglow/shared/widgets/shelf/shelf_hero_carousel.dart';
import 'package:everglow/shared/widgets/shelf/shelf_icon_button.dart';
import 'package:everglow/shared/widgets/shelf/shelf_poster_card.dart';
import 'package:everglow/shared/widgets/shelf/shelf_section_header.dart';
import 'package:everglow/shared/widgets/shelf/shelf_empty_state.dart';
import 'package:everglow/shared/widgets/shelf/shimmer_box.dart';
import 'package:everglow/shared/widgets/shelf/shelf_pill_bottom_nav.dart';
import 'package:everglow/shared/widgets/shelf/staggered_entrance.dart';
import 'package:everglow/shared/widgets/shelf/motion.dart';

// Anime-specific palette — more vibrant and energetic than the cinema
// palette, drawing from iconic anime colour schemes (magenta, cyan,
// electric violet) while staying in the dusk-romantic universe.
const _cBlack = Color(0xFF080810);
const _cCard = Color(0xFF1C1228);
const _cRose = Color(0xFFF4C2C2);
const _cDeepRose = Color(0xFFC2185B);
const _cGold = Color(0xFFE8C97A);
const _cWhite = Color(0xFFFFF5F5);
const _cMuted = Color(0xFF8A7A92);
const _cCyan = Color(0xFF00BCD4);
const _cMagenta = Color(0xFFFF2D55);
const _cElectricPurple = Color(0xFF7C3AED);
const _cVibrantPink = Color(0xFFFF4081);

/// Dedicated entry for the anime rail. Four tabs:
///   * Home     — Leads with Trending Now + Currently Airing (the two
///                hooks for both casuals and hardcore fans), followed
///                by Top Rated, Popular All Time, New Releases, Hidden
///                Gems, Editor's Picks, and the user's own queue.
///   * Browse   — Filterable chips for By Format, By Genre, By Status,
///                and Discovery. Tapping a chip loads its results
///                inline below the chip row.
///   * Library  — Couple's combined anime catalog split into
///                "Want to Watch" + "Watched" with partner attribution.
///   * Search   — Opens [TMDBSearchModal]; the auto-detect in the
///                episode drawer picks up anime from the results.
class AnimeScreen extends StatefulWidget {
  const AnimeScreen({Key? key}) : super(key: key);

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen>
    with TickerProviderStateMixin {
  final JikanService _jikanService = JikanService();
  // Kept around for the shared watchlist / Firestore plumbing; the
  // anime screen itself only reads from Jikan + AniList.
  final TMDBService _tmdbService = TMDBService();
  int _currentIndex = 0;

  // Library / watchlist
  StreamSubscription<List<MediaItem>>? _watchlistSub;
  List<MediaItem> _library = [];

  // Home tab — one slot per curated row. Each slot owns its own
  // loading flag and result list so the home screen can render them
  // independently and replace one without rerunning the others.
  final Map<String, _AnimeRow> _homeRows = {};
  late final List<_HomeSection> _homeSections;

  // Browse tab
  String? _selectedCategoryId;
  final Map<String, _AnimeRow> _browseResults = {};

  @override
  void initState() {
    super.initState();
    _homeSections = _buildHomeSections();
    _bootstrap();
  }

  List<_HomeSection> _buildHomeSections() => [
        _HomeSection(
          id: 'trending',
          title: 'Trending Now',
          icon: Icons.local_fire_department_rounded,
          tint: const Color(0xFFFF7043),
          builder: () async {
            try {
              final items = await _jikanService.fetchTopAiring();
              if (items.isNotEmpty) return items;
            } catch (_) {}
            return _tmdbService.fetchTrendingAnime();
          },
          isHero: true,
        ),
        _HomeSection(
          id: 'airing',
          title: 'Currently Airing',
          icon: Icons.live_tv_rounded,
          tint: const Color(0xFFE53935),
          builder: () async {
            try {
              final items = await _jikanService.fetchSeasonNow();
              if (items.isNotEmpty) return items;
            } catch (_) {}
            final now = DateTime.now();
            final threeMonthsAgo = now.subtract(const Duration(days: 90));
            return _tmdbService.discoverAnime(
              sortBy: 'popularity.desc',
              airDateGte: threeMonthsAgo.toIso8601String().substring(0, 10),
              voteCountGte: 5,
            );
          },
        ),
        _HomeSection(
          id: 'top-rated',
          title: 'Top Rated',
          icon: Icons.star_rounded,
          tint: const Color(0xFFFFCA28),
          builder: () async {
            try {
              final items = await _jikanService.fetchTopAnime(
                type: 'tv',
                filter: 'favorite',
              );
              if (items.isNotEmpty) return items;
            } catch (_) {}
            return _tmdbService.discoverAnime(
              sortBy: 'vote_average.desc',
              voteCountGte: 300,
            );
          },
        ),
        _HomeSection(
          id: 'new-releases',
          title: 'New Releases',
          icon: Icons.fiber_new_rounded,
          tint: const Color(0xFF42A5F5),
          builder: () async {
            try {
              final items = await _jikanService.fetchNewReleases();
              if (items.isNotEmpty) return items;
            } catch (_) {}
            final now = DateTime.now();
            final sixMonthsAgo = now.subtract(const Duration(days: 180));
            return _tmdbService.discoverAnime(
              sortBy: 'first_air_date.desc',
              firstAirDateGte: sixMonthsAgo.toIso8601String().substring(0, 10),
              voteCountGte: 10,
            );
          },
        ),
        _HomeSection(
          id: 'popular-all',
          title: 'Popular All Time',
          icon: Icons.public_rounded,
          tint: const Color(0xFFAB47BC),
          builder: () async {
            try {
              final items = await _jikanService.fetchTopAnime(
                type: 'tv',
                filter: 'bypopularity',
              );
              if (items.isNotEmpty) return items;
            } catch (_) {}
            return _tmdbService.discoverAnime(
              sortBy: 'popularity.desc',
              voteCountGte: 100,
            );
          },
        ),
        _HomeSection(
          id: 'hidden-gems',
          title: 'Hidden Gems',
          icon: Icons.diamond_rounded,
          tint: const Color(0xFF26C6DA),
          builder: () async {
            try {
              final items = await _jikanService.fetchHiddenGems();
              if (items.isNotEmpty) return items;
            } catch (_) {}
            return _tmdbService.discoverAnime(
              sortBy: 'vote_average.desc',
              voteCountGte: 50,
              voteCountLte: 5000,
              voteAverageGte: 7.5,
            );
          },
        ),
        _HomeSection(
          id: 'editors-picks',
          title: "Editor's Picks",
          icon: Icons.workspace_premium_rounded,
          tint: const Color(0xFFEC407A),
          builder: () async {
            try {
              final items = await animeCategoryOptions
                  .firstWhere((o) => o.id == 'curated-editors-picks')
                  .fetch(_jikanService);
              if (items.isNotEmpty) return items;
            } catch (_) {}
            return _tmdbService.discoverAnime(
              sortBy: 'vote_average.desc',
              voteCountGte: 1000,
            );
          },
        ),
      ];

  Future<void> _bootstrap() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _subscribeToLibrary();
    });
    await _loadHome();
  }

  void _subscribeToLibrary() {
    final auth = context.read<AuthService>();
    final userName = auth.currentUser ?? '';
    if (userName.isEmpty) return;

    _watchlistSub?.cancel();
    _watchlistSub = _tmdbService.getAnimeWatchListStream(userName).listen((items) async {
      if (!mounted) return;
      final refreshed = await _tmdbService.refreshAnimePosters(items);
      if (!mounted) return;
      setState(() => _library = refreshed);
    });
  }

  Future<void> _loadHome() async {
    for (final section in _homeSections) {
      _homeRows[section.id] ??= _AnimeRow(isLoading: true);
      _runRow(section.id, _homeRows, section.builder);
    }
    if (mounted) setState(() {});
  }

  Future<void> _runRow(
    String id,
    Map<String, _AnimeRow> rows,
    Future<List<MediaItem>> Function() builder,
  ) async {
    try {
      final items = await builder();
      if (!mounted) return;
      rows[id] = _AnimeRow(items: items, isLoading: false);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      rows[id] = _AnimeRow(items: const [], isLoading: false, hasError: true);
      setState(() {});
    }
  }

  Future<void> _refreshHome() async {
    for (final section in _homeSections) {
      _homeRows[section.id] = _AnimeRow(isLoading: true);
    }
    if (mounted) setState(() {});
    await _loadHome();
  }

  Future<void> _selectCategory(AnimeCategoryOption option) async {
    setState(() {
      _selectedCategoryId = option.id;
      _browseResults[option.id] ??= _AnimeRow(isLoading: true);
    });
    await _runRow(option.id, _browseResults, () async {
      // Try Jikan first, fall back to TMDB discover
      try {
        final items = await option.fetch(_jikanService);
        if (items.isNotEmpty) return items;
      } catch (_) {}
      return _discoverAnimeForCategory(option.id);
    });
  }

  Future<List<MediaItem>> _discoverAnimeForCategory(String categoryId) {
    switch (categoryId) {
      case 'series':
        return _tmdbService.discoverAnime(sortBy: 'popularity.desc');
      case 'movies':
        return _tmdbService.discoverAnimeMovies(sortBy: 'popularity.desc');
      case 'ovas':
        return _tmdbService.discoverAnime(sortBy: 'popularity.desc');
      case 'genre-action':
        return _tmdbService.discoverAnime(
            sortBy: 'popularity.desc', withGenres: [10759]);
      case 'genre-romance':
        return _tmdbService.discoverAnime(
            sortBy: 'popularity.desc', withGenres: [10749]);
      case 'genre-comedy':
        return _tmdbService.discoverAnime(
            sortBy: 'popularity.desc', withGenres: [35]);
      case 'genre-slice-of-life':
        return _tmdbService.discoverAnime(
            sortBy: 'vote_average.desc', voteCountGte: 50);
      case 'genre-fantasy-isekai':
        return _tmdbService.discoverAnime(
            sortBy: 'popularity.desc', withGenres: [10765]);
      case 'genre-scifi-mecha':
        return _tmdbService.discoverAnime(
            sortBy: 'popularity.desc', withGenres: [878]);
      case 'genre-horror-thriller':
        return _tmdbService.discoverAnime(
            sortBy: 'popularity.desc', withGenres: [9648]);
      case 'genre-sports':
        return _tmdbService.discoverAnime(
            sortBy: 'popularity.desc', voteCountGte: 20);
      case 'genre-mystery':
        return _tmdbService.discoverAnime(
            sortBy: 'popularity.desc', withGenres: [9648]);
      case 'status-airing':
        return _tmdbService.discoverAnime(
            sortBy: 'popularity.desc',
            airDateGte: DateTime.now()
                .subtract(const Duration(days: 90))
                .toIso8601String()
                .substring(0, 10),
            voteCountGte: 5);
      case 'status-completed':
        return _tmdbService.discoverAnime(
            sortBy: 'vote_average.desc',
            voteCountGte: 100,
            voteCountLte: 50000);
      case 'status-new':
        final now = DateTime.now();
        return _tmdbService.discoverAnime(
          sortBy: 'first_air_date.desc',
          firstAirDateGte:
              now.subtract(const Duration(days: 180)).toIso8601String().substring(0, 10),
          voteCountGte: 10,
        );
      case 'status-trending':
        return _tmdbService.discoverAnime(sortBy: 'popularity.desc');
      case 'curated-popular-all':
        return _tmdbService.discoverAnime(sortBy: 'popularity.desc');
      case 'curated-top-rated':
        return _tmdbService.discoverAnime(
            sortBy: 'vote_average.desc', voteCountGte: 500);
      case 'curated-hidden-gems':
        return _tmdbService.discoverAnime(
            sortBy: 'vote_average.desc',
            voteCountGte: 50,
            voteCountLte: 5000,
            voteAverageGte: 7.5);
      case 'curated-editors-picks':
        return _tmdbService.discoverAnime(
            sortBy: 'vote_average.desc', voteCountGte: 1000);
      default:
        return _tmdbService.discoverAnime(sortBy: 'popularity.desc');
    }
  }

  @override
  void dispose() {
    _watchlistSub?.cancel();
    super.dispose();
  }

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const JikanSearchModal(),
    );
  }

  void _openDetails(MediaItem item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EpisodeDrawer(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBlack,
      body: Stack(
        children: [
          // Anime-specific atmosphere — vibrant magenta + cyan + electric
          // purple glows instead of the default cinema palette.
          const ShelfAtmosphericBackdrop(
            baseColor: _cBlack,
            glows: [
              RadialGlow(
                color: _cMagenta,
                alignment: Alignment(-0.8, -0.8),
                size: 1.0,
                opacity: 0.20,
              ),
              RadialGlow(
                color: _cCyan,
                alignment: Alignment(0.85, 0.7),
                size: 0.7,
                opacity: 0.12,
              ),
              RadialGlow(
                color: _cElectricPurple,
                alignment: Alignment(0.0, 1.2),
                size: 0.9,
                opacity: 0.15,
              ),
            ],
          ),
          // Floating sparkle particles for anime energy
          const Positioned.fill(
            child: IgnorePointer(
              child: _AnimeSparkles(),
            ),
          ),
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeTab(),
                _buildBrowseTab(),
                _buildLibraryTab(),
                _buildSearchTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return ShelfPillBottomNav(
      currentIndex: _currentIndex,
      accentColor: _cMagenta,
      glowColor: _cCyan,
      onTap: (i) {
        HapticFeedback.selectionClick();
        if (i == 3) {
          setState(() => _currentIndex = i);
          _openSearch();
        } else {
          setState(() => _currentIndex = i);
        }
      },
      items: const [
        ShelfNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        ShelfNavItem(
          icon: Icons.explore_outlined,
          activeIcon: Icons.explore_rounded,
          label: 'Browse',
        ),
        ShelfNavItem(
          icon: Icons.collections_bookmark_outlined,
          activeIcon: Icons.collections_bookmark_rounded,
          label: 'Library',
        ),
        ShelfNavItem(
          icon: Icons.search_rounded,
          activeIcon: Icons.search_rounded,
          label: 'Search',
        ),
      ],
    );
  }

  // ── HOME TAB ───────────────────────────────────────────────────────

  Widget _buildHomeTab() {
    return RefreshIndicator(
      color: _cDeepRose,
      backgroundColor: _cCard,
      onRefresh: _refreshHome,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          StaggeredEntrance(index: 0, child: _buildHeader()),
          const SizedBox(height: 8),
          for (var i = 0; i < _homeSections.length; i++) ...[
            StaggeredEntrance(
              index: i + 1,
              child: _buildHomeSection(_homeSections[i]),
            ),
            const SizedBox(height: 24),
          ],
          if (_library.where((i) => i.isCurrentlyWatching).isNotEmpty) ...[
            StaggeredEntrance(
              index: _homeSections.length + 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: ShelfSectionHeader(
                  eyebrow: 'Resume Playing',
                  title: 'Currently Watching',
                  icon: Icons.play_circle_filled_rounded,
                  accent: const Color(0xFFFF6D00),
                  count: _library.where((i) => i.isCurrentlyWatching).length,
                  countLabel: 'titles',
                ),
              ),
            ),
            _buildPosterRow(
              _library.where((i) => i.isCurrentlyWatching).toList(),
            ),
            const SizedBox(height: 24),
          ],
          if (_library.where((i) => i.isToWatch).isNotEmpty) ...[
            StaggeredEntrance(
              index: _homeSections.length + 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: ShelfSectionHeader(
                  eyebrow: 'Up Next',
                  title: 'In Your Queue',
                  icon: Icons.bookmark_rounded,
                  accent: _cGold,
                  count: _library.where((i) => i.isToWatch).length,
                  countLabel: 'titles',
                ),
              ),
            ),
            _buildPosterRow(
              _library.where((i) => i.isToWatch).toList(),
            ),
            const SizedBox(height: 24),
          ],
          if (_library.where((i) => i.isWatched).isNotEmpty) ...[
            StaggeredEntrance(
              index: _homeSections.length + 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: ShelfSectionHeader(
                  eyebrow: 'Already Finished',
                  title: 'Watched',
                  icon: Icons.remove_red_eye_rounded,
                  accent: _cGold,
                  count: _library.where((i) => i.isWatched).length,
                  countLabel: 'titles',
                ),
              ),
            ),
            _buildPosterRow(
              _library.where((i) => i.isWatched).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildHomeSection(_HomeSection section) {
    final row = _homeRows[section.id];
    if (row == null) {
      return _buildShimmerRow(height: section.isHero ? 280 : 220);
    }
    if (row.isLoading) {
      return _buildShimmerRow(height: section.isHero ? 280 : 220);
    }
    if (row.items.isEmpty) {
      if (row.hasError) {
        return _buildErrorRow(section);
      }
      return const SizedBox.shrink();
    }
    if (section.isHero) {
      return _buildHeroCarousel(row.items, section);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: ShelfSectionHeader(
            eyebrow: _eyebrowForSection(section.id),
            title: section.title,
            icon: section.icon,
            accent: section.tint,
            count: row.items.length,
            countLabel: 'titles',
          ),
        ),
        _buildPosterRow(row.items, accent: section.tint),
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
        return "Mochi's Picks 🐱";
      case 'trending':
      default:
        return 'Hot Right Now';
    }
  }

  Widget _buildHeroCarousel(List<MediaItem> items, _HomeSection section) {
    final heroItems = items.take(5).map((m) {
      final rank = items.indexOf(m) + 1;
      return ShelfHeroItem(
        id: '${m.tmdbId}',
        title: m.title,
        subtitle: m.year.isNotEmpty ? m.year : 'Tap to explore',
        eyebrow: rank <= 3 ? '★ Top $rank' : 'Trending #$rank',
        imageUrl: m.backdropPath.isNotEmpty
            ? m.backdropPath
            : m.posterPath,
        accent: _cMagenta,
        onTap: () => _openDetails(m),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: ShelfSectionHeader(
            eyebrow: _eyebrowForSection(section.id),
            title: section.title,
            icon: section.icon,
            accent: _cMagenta,
            count: items.length,
            countLabel: 'titles',
          ),
        ),
        ShelfHeroCarousel(
          items: heroItems,
          holdDuration: const Duration(seconds: 8),
          height: 340,
          viewportFraction: 0.85,
        ),
      ],
    );
  }

  Widget _buildHeader() {
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
          // Animated gradient icon with pulsing glow
          _AnimeLogo(size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Everglow Anime',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: _cRose,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Discover · Watch · Collect',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: _cCyan.withValues(alpha: 0.8),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          ShelfIconButton(
            icon: Icons.search_rounded,
            semanticLabel: 'Search Anime',
            tooltip: 'Search anime',
            onTap: _openSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title,
      {required IconData icon, Color tint = _cRose, int? count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: ShelfSectionHeader(
        eyebrow: 'Collection',
        title: title,
        icon: icon,
        accent: tint,
        count: count,
        countLabel: count != null ? 'titles' : null,
      ),
    );
  }

  Widget _buildShimmerRow({required double height}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: ShimmerPosterRow(
        height: height - 14,
        width: 130,
        count: 5,
        padding: EdgeInsets.zero,
        base: const Color(0xFF1C1228),
        highlight: const Color(0xFF2A1F3A),
      ),
    );
  }

  Widget _buildErrorRow(_HomeSection section) {
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
              border: Border.all(
                color: section.tint.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded,
                    color: _cMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Couldn\'t load ${section.title.toLowerCase()}',
                    style: GoogleFonts.outfit(
                      color: _cMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _homeRows[section.id] = _AnimeRow(isLoading: true);
                    });
                    _runRow(section.id, _homeRows, section.builder);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: section.tint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: section.tint.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Retry',
                      style: GoogleFonts.outfit(
                        color: section.tint,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
    List<MediaItem> items, {
    Color accent = _cRose,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Text(
          'Nothing here yet. Search above to add your first anime!',
          style: GoogleFonts.outfit(
            color: _cMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return ScrollEdgeFade(
      fadeColor: _cBlack,
      child: SizedBox(
        height: 230,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return SizedBox(
              width: 130,
              child: ShelfPosterCard(
                imageUrl: item.posterPath,
                title: item.title,
                subtitle: item.year.isNotEmpty ? item.year : null,
                badge: 'ANIME',
                badgeIcon: Icons.auto_awesome_rounded,
                badgeColor: _cVibrantPink,
                onTap: () => _openDetails(item),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── BROWSE TAB ─────────────────────────────────────────────────────

  Widget _buildBrowseTab() {
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
        ...AnimeCategoryGroup.values.map(_buildBrowseGroup),
        const SizedBox(height: 16),
        if (_selectedCategoryId != null) _buildBrowseResults(),
      ],
    );
  }

  Widget _buildBrowseGroup(AnimeCategoryGroup group) {
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
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final option = options[i];
                final selected = _selectedCategoryId == option.id;
                return _AnimeFilterChip(
                  option: option,
                  selected: selected,
                  onTap: () => _selectCategory(option),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseResults() {
    final row = _browseResults[_selectedCategoryId];
    final option = animeCategoryOptions.firstWhere(
      (o) => o.id == _selectedCategoryId,
      orElse: () => animeCategoryOptions.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildSectionTitle(
          option.label,
          icon: option.icon,
          tint: option.color,
          count: row?.items.length,
        ),
        if (row == null || row.isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cCard.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
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
                          onTap: () => _selectCategory(option),
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
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
                onTap: () => _openDetails(item),
              );
            },
          ),
      ],
    );
  }

  _BrowseGroupMeta _groupMeta(AnimeCategoryGroup g) {
    switch (g) {
      case AnimeCategoryGroup.format:
        return const _BrowseGroupMeta(
          title: 'By Format',
          subtitle: 'MOVIES · SERIES · OVAs',
          icon: Icons.movie_filter_rounded,
          tint: _cCyan,
        );
      case AnimeCategoryGroup.genre:
        return const _BrowseGroupMeta(
          title: 'By Genre',
          subtitle: 'TAP TO FILTER',
          icon: Icons.theater_comedy_rounded,
          tint: _cVibrantPink,
        );
      case AnimeCategoryGroup.status:
        return const _BrowseGroupMeta(
          title: 'By Status',
          subtitle: 'AIRING · COMPLETED · NEW',
          icon: Icons.live_tv_rounded,
          tint: _cMagenta,
        );
      case AnimeCategoryGroup.discovery:
        return const _BrowseGroupMeta(
          title: 'Discovery',
          subtitle: 'CURATED PICKS',
          icon: Icons.workspace_premium_rounded,
          tint: _cElectricPurple,
        );
    }
  }

  // ── LIBRARY TAB ────────────────────────────────────────────────────

  Widget _buildLibraryTab() {
    final currentlyWatching = _library.where((i) => i.isCurrentlyWatching).toList();
    final wantToWatch = _library.where((i) => i.isToWatch).toList();
    final watched = _library.where((i) => i.isWatched).toList();

    if (currentlyWatching.isEmpty && wantToWatch.isEmpty && watched.isEmpty) {
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
                    colors: [
                      _cMagenta,
                      _cElectricPurple,
                    ],
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
                child: const Icon(Icons.collections_bookmark_rounded,
                    color: _cWhite, size: 44),
              ),
              const SizedBox(height: 24),
              Text(
                'Your anime library is empty',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _cWhite,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search for any series and add it to your watchlist.\nItems you mark as watched will live here too.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: _cMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              _AnimeCtaButton(
                label: 'Search Anime',
                icon: Icons.search_rounded,
                onTap: _openSearch,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _cWhite,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  'JAPANESE ANIMATION',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    color: _cMuted,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _LibraryStat(
                    label: 'Watching',
                    count: currentlyWatching.length,
                    color: const Color(0xFFFF6D00),
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
                    count: currentlyWatching.length + wantToWatch.length + watched.length,
                    color: _cVibrantPink,
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildLibrarySection('Currently Watching', currentlyWatching,
            Icons.play_circle_filled_rounded, const Color(0xFFFF6D00)),
        _buildLibrarySection(
            'Want to Watch', wantToWatch, Icons.bookmark_rounded, _cCyan),
        _buildLibrarySection('Watched', watched,
            Icons.remove_red_eye_rounded, const Color(0xFF8BC34A)),
      ],
    );
  }

  Widget _buildLibrarySection(
    String title,
    List<MediaItem> items,
    IconData icon,
    Color accent,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final badge = title == 'Currently Watching'
                ? (item.currentEpisode != null
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
              onTap: () => _openDetails(item),
            );
          },
        ),
      ],
    );
  }

  // ── SEARCH TAB ─────────────────────────────────────────────────────

  Widget _buildSearchTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
                  colors: [_cCyan, _cElectricPurple],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _cCyan.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: -8,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.search_rounded,
                  color: _cWhite, size: 44),
            ),
            const SizedBox(height: 24),
            Text(
              'Find Your Next Anime',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _cWhite,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search MyAnimeList or AniList by title. We auto-detect anime and add it to your library.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: _cMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            _AnimeCtaButton(
              label: 'Open Search',
              icon: Icons.search_rounded,
              onTap: _openSearch,
            ),
          ],
        ),
      ),
    );
  }
}

// ── INTERNAL MODELS ──────────────────────────────────────────────

class _AnimeRow {
  final List<MediaItem> items;
  final bool isLoading;
  final bool hasError;
  const _AnimeRow({this.items = const [], this.isLoading = false, this.hasError = false});
}

class _HomeSection {
  final String id;
  final String title;
  final IconData icon;
  final Color tint;
  final Future<List<MediaItem>> Function() builder;
  final bool isHero;

  const _HomeSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.tint,
    required this.builder,
    this.isHero = false,
  });
}

class _BrowseGroupMeta {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  const _BrowseGroupMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });
}

// ── EXTRACTED WIDGETS ─────────────────────────────────────────────

class _AnimeFilterChip extends StatefulWidget {
  final AnimeCategoryOption option;
  final bool selected;
  final VoidCallback onTap;
  const _AnimeFilterChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_AnimeFilterChip> createState() => _AnimeFilterChipState();
}

class _AnimeFilterChipState extends State<_AnimeFilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tint = widget.option.color;
    final selected = widget.selected;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (show) => setState(() => _hovered = show),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? tint.withValues(alpha: 0.2)
                  : _hovered
                      ? _cCard.withValues(alpha: 0.8)
                      : _cCard,
              border: Border.all(
                color: selected
                    ? tint.withValues(alpha: 0.6)
                    : _hovered
                        ? tint.withValues(alpha: 0.25)
                        : _cRose.withValues(alpha: 0.12),
                width: selected ? 1.2 : 1,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: tint.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.option.icon,
                    color: selected ? tint : _cMuted, size: 14),
                const SizedBox(width: 6),
                Text(
                  widget.option.label,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: selected
                        ? tint
                        : _cRose.withValues(alpha: 0.85),
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact poster tile used in the home + library carousels is now
/// `ShelfPosterCard` (see `lib/shared/widgets/shelf/`).

/// Hero card for the Trending carousel is now `ShelfHeroCarousel`
/// (see `lib/shared/widgets/shelf/`).

/// Small tinted stat chip used in the library header.
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.85),
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── ANIME-SPECIFIC WIDGETS ─────────────────────────────────────────

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
          child: const Icon(Icons.auto_awesome_rounded,
              color: _cWhite, size: 22),
        );
      },
    );
  }
}

/// Floating diamond/star sparkle particles that drift across the anime
/// screen background. Gives the page a magical, energetic feel without
/// distracting from the content.
class _AnimeSparkles extends StatefulWidget {
  const _AnimeSparkles();

  @override
  State<_AnimeSparkles> createState() => _AnimeSparklesState();
}

class _AnimeSparklesState extends State<_AnimeSparkles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const _count = 18;
  late final List<_SparkleData> _sparkles;
  late final Picture _starPicture;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _sparkles = List.generate(_count, (_) => _SparkleData(rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Pre-render the star/diamond shape into a Picture so every frame
    // just replays it with translate+rotate+scale instead of allocating
    // a new 8-vertex Path per sparkle.
    _starPicture = _createStarPicture();
  }

  /// Pre-renders the canonical star shape at size=1.0 so the painter
  /// can scale it to each sparkle's size via canvas.scale().
  static Picture _createStarPicture() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const r = 1.0;
    final path = Path()
      ..moveTo(0, -r)
      ..lineTo(r * 0.4, -r * 0.3)
      ..lineTo(r, 0)
      ..lineTo(r * 0.4, r * 0.3)
      ..lineTo(0, r)
      ..lineTo(-r * 0.4, r * 0.3)
      ..lineTo(-r, 0)
      ..lineTo(-r * 0.4, -r * 0.3)
      ..close();
    // Use a neutral paint — the caller overrides color/blend per sparkle.
    canvas.drawPath(path, Paint()..style = PaintingStyle.fill);
    return recorder.endRecording();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _starPicture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppTheme.shouldReduceMotion) return const SizedBox.shrink();
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _SparklePainter(
            sparkles: _sparkles,
            progress: _ctrl.value,
            starPicture: _starPicture,
          ),
        ),
      ),
    );
  }
}

class _SparkleData {
  final double x, y, size, speed, delay;
  final double hue; // 0..1 — maps to pink/cyan/purple
  _SparkleData(math.Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        size = 1.5 + rng.nextDouble() * 2.5,
        speed = 0.4 + rng.nextDouble() * 0.6,
        delay = rng.nextDouble(),
        hue = rng.nextDouble();
}

class _SparklePainter extends CustomPainter {
  final List<_SparkleData> sparkles;
  final double progress;
  final Picture starPicture;

  _SparklePainter({
    required this.sparkles,
    required this.progress,
    required this.starPicture,
  });

  // Palette shared across all sparkles — created once and tinted
  // per sparkle by adjusting alpha via Paint.colorFilter or a
  // shared Paint with varying color.
  static const _colors = [
    Color(0x80FF2D55), // magenta
    Color(0x8000BCD4), // cyan
    Color(0x807C3AED), // purple
    Color(0x80FF4081), // vibrant pink
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Reusable Paint — color is overwritten per sparkle
    final paint = Paint()..style = PaintingStyle.fill;

    for (final s in sparkles) {
      final t = (progress + s.delay) % 1.0;
      final alpha = (math.sin(t * math.pi) * 0.6 + 0.1).clamp(0.0, 1.0);
      final drift = (t - 0.5) * 40;
      final px = (s.x * size.width + drift) % size.width;
      final py = (s.y * size.height - t * size.height * s.speed * 0.15) %
          size.height;

      paint.color = _colors[s.hue.floor() % _colors.length]
          .withValues(alpha: alpha * 0.9);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(t * 6.28);
      canvas.scale(s.size); // canonical star is size=1
      canvas.drawPicture(starPicture);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.progress != progress;
}

/// Anime-themed CTA button with gradient border and hover glow.
class _AnimeCtaButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _AnimeCtaButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_AnimeCtaButton> createState() => _AnimeCtaButtonState();
}

class _AnimeCtaButtonState extends State<_AnimeCtaButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: ShelfMotion.orZero(ShelfMotion.medium),
          curve: ShelfMotion.easeOutStrong,
          transform: Matrix4.identity()
            ..setTranslationRaw(0.0, _hovered ? -2.0 : 0.0, 0.0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _cMagenta.withValues(alpha: _hovered ? 0.35 : 0.25),
                _cElectricPurple.withValues(alpha: _hovered ? 0.35 : 0.25),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _hovered
                  ? _cCyan.withValues(alpha: 0.7)
                  : _cMagenta.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: _cMagenta.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: _cWhite, size: 18),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  color: _cWhite,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
