import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Picture, PictureRecorder;
import 'package:flutter/material.dart' hide FilterChip;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_breakpoints.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/anime_categories.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/anilist_service.dart';
import 'package:everglow/features/cinema/data/services/jikan_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/shared/widgets/shelf/filter_chip.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/shared/widgets/shelf/atmospheric_backdrop.dart';
import 'package:everglow/shared/widgets/shelf/scroll_edge_fade.dart';
import 'package:everglow/shared/widgets/shelf/shelf_hero_carousel.dart';
import 'package:everglow/shared/widgets/shelf/anime_hero_banner.dart';
import 'package:everglow/shared/widgets/shelf/shelf_icon_button.dart';
import 'package:everglow/shared/widgets/shelf/shelf_poster_card.dart';
import 'package:everglow/shared/widgets/shelf/shelf_section_header.dart';
import 'package:everglow/shared/widgets/shelf/shelf_empty_state.dart';
import 'package:everglow/shared/widgets/shelf/shimmer_box.dart';
import 'package:everglow/shared/widgets/shelf/shelf_pill_bottom_nav.dart';
import 'package:everglow/shared/widgets/shelf/staggered_entrance.dart';
import 'package:everglow/shared/widgets/shelf/cinema_sections.dart';
import 'package:everglow/shared/widgets/shelf/anime_cta_button.dart';
import 'package:everglow/features/ai/presentation/widgets/ai_recommendations.dart';

// Anime palette — now sourced from AppColors for design-system consistency.
const _cBlack          = AppColors.animeBackground;
const _cCard           = AppColors.animeCard;
const _cRose           = AppColors.animeRose;
const _cDeepRose       = AppColors.animeDeepRose;
const _cGold           = AppColors.animeGold;
const _cWhite          = AppColors.animeWhite;
const _cMuted          = AppColors.animeMuted;
const _cCyan           = AppColors.animeCyan;
const _cMagenta        = AppColors.animeMagenta;
const _cElectricPurple = AppColors.animeElectricPurple;
const _cVibrantPink    = AppColors.animeVibrantPink;

// Single source of truth for home-tab genre rail metadata.
// Used by both [_loadGenreRows] and [_buildGenreRow].
const _genreMeta = <String, ({
  List<int> genreIds,
  Color color,
  IconData icon,
  String subtitle,
})>{
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
///   * Search   — Full inline search backed by AniList + Jikan (with
///                TMDB fallback). Results show anime poster cards with
///                an "Add to Everglow?" dialog on tap.
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

  // Genre rows for home tab
  final Map<String, List<MediaItem>> _genreRows = {};

  // Top 10 for home tab
  List<MediaItem> _topTenItems = [];

  // Search tab
  final TextEditingController _searchController = TextEditingController();
  List<MediaItem> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;
  String? _searchErrorMessage;

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
        _HomeSection(
          id: 'you-might-like',
          title: 'You Might Like',
          icon: Icons.recommend_rounded,
          tint: const Color(0xFF00E5FF),
          builder: () async {
            // Fetch top airing and pick a random subset for variety
            try {
              final items = await _jikanService.fetchTopAiring();
              if (items.length > 5) {
                items.shuffle();
                return items.take(15).toList();
              }
              if (items.isNotEmpty) return items;
            } catch (_) {}
            return _tmdbService.discoverAnime(
              sortBy: 'popularity.desc',
              voteAverageGte: 7.0,
              voteCountGte: 50,
            );
          },
        ),
      ];

  Future<void> _bootstrap() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _subscribeToLibrary();
    });
    await Future.wait([
      _loadHome(),
      _loadGenreRows(),
      _loadTopTen(),
    ]);
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
    await Future.wait([
      _loadHome(),
      _loadGenreRows(),
      _loadTopTen(),
    ]);
  }

  /// Loads genre-specific rows for the home tab. Each genre fetches its
  /// top titles via Jikan's genre filter so the home screen has dedicated
  /// discovery rails for Action, Romance, Isekai, etc.
  Future<void> _loadGenreRows() async {
    final futures = _genreMeta.entries.map((entry) async {
      try {
        final items = await _jikanService.fetchByGenres(entry.value.genreIds, limit: 15);
        if (items.isNotEmpty && mounted) {
          setState(() => _genreRows[entry.key] = items);
        }
      } catch (_) {}
    });

    await Future.wait(futures);
  }

  /// Loads the top 10 trending anime for the dedicated ranking section.
  Future<void> _loadTopTen() async {
    try {
      final items = await _jikanService.fetchTopAiring(limit: 10);
      if (mounted) setState(() => _topTenItems = items);
    } catch (_) {}
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
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 600), () {
      if (query.trim().isNotEmpty) {
        _performSearch(query.trim());
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _searchErrorMessage = null;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _searchErrorMessage = null;
    });

    final aniListFuture = AniListService().searchAnime(query);
    final jikanFuture = _jikanService.searchAnimeDirect(query);
    final results = await Future.wait([aniListFuture, jikanFuture]);

    var combined = results[0].isNotEmpty
        ? results[0]
        : results[1].isNotEmpty
            ? results[1]
            : <MediaItem>[];

    if (combined.isEmpty) {
      combined = await _tmdbService.searchMedia(query);
    }

    if (mounted) {
      setState(() {
        _searchResults = combined;
        _isSearching = false;
        if (combined.isEmpty) {
          final backends = <String>[];
          if (results[0].isEmpty) backends.add('AniList');
          if (results[1].isEmpty) backends.add('Jikan');
          if (combined.isEmpty) backends.add('TMDB');
          _searchErrorMessage =
              'No results from ${backends.join(", ")} — check your connection or try a different title';
        }
      });
    }
  }

  void _openSearch() {
    setState(() => _currentIndex = 3);
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
        setState(() => _currentIndex = i);
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

          // ── AI RECOMMENDATIONS ─────────────────────────────────
          StaggeredEntrance(
            index: _homeSections.length + 1,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AIRecommendations(
                title: "Mochi's Picks",
                autoLoad: true,
                onTapItem: (item) => _openDetails(item),
              ),
            ),
          ),

          // ── TOP 10 RANKING ─────────────────────────────────────
          if (_topTenItems.isNotEmpty)
            StaggeredEntrance(
              index: _homeSections.length + 2,
              child: TopTenRankingSection(
                items: buildRankingItems(
                  items: _topTenItems,
                  getTitle: (m) => m.title,
                  getImageUrl: (m) =>
                      m.posterPath.isNotEmpty ? m.posterPath : '',
                  getSubtitle: (m) => m.year.isNotEmpty ? m.year : null,
                  getBadge: (m) => 'ANIME',
                  onTap: (m) => _openDetails(m),
                ),
                eyebrow: 'Trending Today',
                title: 'TOP 10 Anime',
                accent: _cMagenta,
              ),
            ),

          // ── GENRE ROWS ─────────────────────────────────────────
          for (var gi = 0; gi < _genreRows.length; gi++) ...[
            StaggeredEntrance(
              index: _homeSections.length + 3 + gi,
              child: _buildGenreRow(
                _genreRows.keys.elementAt(gi),
                _genreRows.values.elementAt(gi),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── LIBRARY SECTIONS ───────────────────────────────────
          if (_library.where((i) => i.isCurrentlyWatching).isNotEmpty) ...[
            StaggeredEntrance(
              index: _homeSections.length + 3 + _genreRows.length,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: ShelfSectionHeader(
                  eyebrow: 'Resume Playing',
                  title: 'Currently Watching',
                  subtitle: 'Pick up where you left off',
                  icon: Icons.play_circle_filled_rounded,
                  accent: const Color(0xFFFF6D00),
                  count: _library.where((i) => i.isCurrentlyWatching).length,
                  countLabel: 'titles',
                ),
              ),
            ),
            _buildContinueWatchingRow(
              _library.where((i) => i.isCurrentlyWatching).toList(),
            ),
            const SizedBox(height: 24),
          ],
          if (_library.where((i) => i.isToWatch).isNotEmpty) ...[
            StaggeredEntrance(
              index: _homeSections.length + 4 + _genreRows.length,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: ShelfSectionHeader(
                  eyebrow: 'Up Next',
                  title: 'In Your Queue',
                  subtitle: 'Anime you plan to watch',
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
              index: _homeSections.length + 5 + _genreRows.length,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: ShelfSectionHeader(
                  eyebrow: 'Already Finished',
                  title: 'Watched',
                  subtitle: 'Anime you\'ve completed',
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
      return _buildShimmerRow(height: section.isHero ? 540 : 290);
    }
    if (row.isLoading) {
      return _buildShimmerRow(height: section.isHero ? 540 : 290);
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
            subtitle: _subtitleForSection(section.id),
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

  /// Builds a genre-specific horizontal rail for the home tab. Each genre
  /// has its own color and icon, matching the browse tab's genre chips.
  Widget _buildGenreRow(String genreName, List<MediaItem> items) {
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
        _buildPosterRow(items, accent: color),
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
        posterUrl: m.posterPath,
        synopsis: m.synopsis,
        episodeCount: m.episodeCount,
        format: m.format,
        airingStatus: m.airingStatus,
        year: m.year,
        accent: _cMagenta,
        onTap: () => _openDetails(m),
      );
    }).toList();

    return AnimeHeroBanner(
      items: heroItems,
      holdDuration: const Duration(seconds: 18),
      height: AppBreakpoint.isDesktop(context) ? 520 : 420,
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
          // WatchPeak-style search bar trigger
          GestureDetector(
            onTap: _openSearch,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  Icon(Icons.search_rounded,
                      color: _cMuted, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Search anime...',
                    style: GoogleFonts.outfit(
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

  Widget _buildShimmerRow({required double height}) {
    final isDesktop = AppBreakpoint.isDesktop(context);
    final isTablet = AppBreakpoint.isTablet(context);
    final shimmerWidth = isDesktop ? 170.0 : (isTablet ? 150.0 : 130.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: ShimmerPosterRow(
        height: height - 14,
        width: shimmerWidth,
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

    final isDesktop = AppBreakpoint.isDesktop(context);
    final isTablet = AppBreakpoint.isTablet(context);
    final cardWidth = isDesktop ? 170.0 : (isTablet ? 150.0 : 130.0);
    final cardHeight = isDesktop ? 290.0 : (isTablet ? 260.0 : 230.0);

    return ScrollEdgeFade(
      fadeColor: _cBlack,
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
                onTap: () => _openDetails(item),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Enhanced "Currently Watching" row with episode progress labels,
  /// backdrop images, progress bar, and resume play button.
  Widget _buildContinueWatchingRow(List<MediaItem> items) {
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
          if (season != null && episode != null) {
            progressLabel = 'S$season E$episode';
          } else if (episode != null) {
            progressLabel = 'Ep $episode';
          }

          return GestureDetector(
            onTap: () => _openDetails(item),
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
                  border: Border.all(
                    color: _cCyan.withValues(alpha: 0.2),
                  ),
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
                      if (item.backdropPath.isNotEmpty)
                        Image.network(
                          item.backdropPath,
                          fit: BoxFit.cover,
                          cacheWidth: 900,
                          errorBuilder: (_, _, _) => Image.network(
                            item.posterPath,
                            fit: BoxFit.cover,
                            cacheWidth: 400,
                            errorBuilder: (_, _, _) =>
                                Container(color: _cCard),
                          ),
                        )
                      else if (item.posterPath.isNotEmpty)
                        Image.network(
                          item.posterPath,
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          errorBuilder: (_, _, _) =>
                              Container(color: _cCard),
                        )
                      else
                        Container(color: _cCard),
                      // Dark gradient overlay
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
                      // Content
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
                                    horizontal: 8, vertical: 3),
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
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.petalWhite,
                                height: 1.15,
                              ),
                            ),
                            if (item.year.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.year,
                                style: GoogleFonts.outfit(
                                  color: AppTheme.warmAmber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: (episode != null && item.episodeCount != null && item.episodeCount! > 0)
                                    ? (episode / item.episodeCount!).clamp(0.0, 1.0)
                                    : 0.0,
                                backgroundColor: Colors.white.withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(_cCyan),
                                minHeight: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Resume play button
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
              const Spacer(),
              if (_selectedCategoryId != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedCategoryId = null;
                  }),
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
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final option = options[i];
                final selected = _selectedCategoryId == option.id;
                return FilterChip(
                  icon: option.icon,
                  label: option.label,
                  color: option.color,
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
    final isDesktop = AppBreakpoint.isDesktop(context);
    final row = _browseResults[_selectedCategoryId];
    final option = animeCategoryOptions.firstWhere(
      (o) => o.id == _selectedCategoryId,
      orElse: () => animeCategoryOptions.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Active filter header with icon and count
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
      case AnimeCategoryGroup.season:
        return const _BrowseGroupMeta(
          title: 'By Season',
          subtitle: 'SPRING · SUMMER · FALL · WINTER',
          icon: Icons.calendar_view_month_rounded,
          tint: Color(0xFFFFB74D),
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
              AnimeCtaButton(
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
    final isDesktop = AppBreakpoint.isDesktop(context);
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
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                isDesktop ? 6 : (AppBreakpoint.isTablet(context) ? 4 : 2),
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
              synopsis: item.synopsis,
              episodeCount: item.episodeCount?.toString(),
              format: item.format,
              airingStatus: item.airingStatus,
              currentEpisode: item.currentEpisode,
              onTap: () => _openDetails(item),
            );
          },
        ),
      ],
    );
  }

  // ── SEARCH TAB ─────────────────────────────────────────────────────

  Widget _buildSearchTab() {
    final isDesktop = AppBreakpoint.isDesktop(context);
    final horizontalPad = isDesktop ? 48.0 : 20.0;

    return Column(
      children: [
        // Header with title + subtitle + search bar
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            isDesktop ? 32 : (MediaQuery.of(context).padding.top + 14),
            horizontalPad,
            8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isDesktop)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ShelfIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    semanticLabel: 'Back to Home',
                    tooltip: 'Back to Home',
                    onTap: () => setState(() => _currentIndex = 0),
                  ),
                ),
              Text(
                'Find Your Next Anime',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: isDesktop ? 32 : 26,
                  fontWeight: FontWeight.w800,
                  color: _cWhite,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Search MyAnimeList or AniList by title. We auto-detect anime and add it to your library.',
                style: GoogleFonts.outfit(
                  fontSize: isDesktop ? 14 : 12,
                  color: _cMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: _cCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: _cCyan.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: _cMagenta.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: GoogleFonts.outfit(color: _cWhite, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search anime titles, studios, anything\u2026',
                    hintStyle:
                        GoogleFonts.outfit(color: _cMuted, fontSize: 15),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Icon(
                        Icons.search_rounded,
                        color: _cCyan,
                        size: 22,
                      ),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: _cMuted,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                                _isSearching = false;
                                _searchErrorMessage = null;
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Results
        Expanded(
          child: _isSearching
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isDesktop
                          ? 6
                          : (AppBreakpoint.isTablet(context) ? 4 : 2),
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: 12,
                    itemBuilder: (_, _) => const ShimmerBox(height: 220, radius: 14),
                  ),
                )
              : _searchResults.isEmpty
                  ? (_searchController.text.isEmpty
                      ? _buildSearchLandingState()
                      : _buildSearchEmptyState())
                  : GridView.builder(
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPad),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop
                            ? 6
                            : (AppBreakpoint.isTablet(context) ? 4 : 2),
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return ShelfPosterCard(
                          imageUrl: item.posterPath,
                          title: item.title,
                          subtitle: item.year.isNotEmpty ? item.year : null,
                          badge: 'ANIME',
                          badgeIcon: Icons.auto_awesome_rounded,
                          onTap: () => _showAddDialog(item),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showAddDialog(MediaItem item) {
    String status = 'to-watch';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: AppTheme.velvet,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: AppTheme.roseQuartz.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.roseQuartz.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Poster + metadata
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: item.posterUrl.isNotEmpty
                        ? Image.network(item.posterUrl,
                            width: 90, height: 130, fit: BoxFit.cover)
                        : Container(
                            width: 90, height: 130,
                            color: AppTheme.twilight,
                            child: const Icon(Icons.movie_rounded,
                                color: AppTheme.roseQuartz, size: 32),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add to Everglow?',
                          style: GoogleFonts.outfit(
                            color: AppTheme.roseQuartz,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          style: GoogleFonts.cormorantGaramond(
                            color: AppTheme.petalWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        if (item.studio.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.deepRose.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item.studio,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.deepRose,
                              ),
                            ),
                          ),
                        ],
                        if (item.synopsis.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.synopsis,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: AppTheme.roseQuartz.withValues(alpha: 0.7),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Status chips
              Row(
                children: [
                  Expanded(
                    child: _buildStatusChip(
                      label: 'To Watch',
                      icon: Icons.bookmark_rounded,
                      selected: status == 'to-watch',
                      color: _cCyan,
                      onTap: () => setDialogState(() => status = 'to-watch'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatusChip(
                      label: 'Watched',
                      icon: Icons.check_circle_rounded,
                      selected: status == 'watched',
                      color: const Color(0xFF8BC34A),
                      onTap: () => setDialogState(() => status = 'watched'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.roseQuartz.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.roseQuartz.withValues(alpha: 0.15),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.outfit(
                            color: AppTheme.roseQuartz,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        final u = context.read<AuthService>().currentUser ?? '';
                        if (u.isEmpty) return;
                        await _tmdbService.saveToWatchList(item, status, u);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${item.title} added to Everglow!',
                                style: GoogleFonts.outfit(
                                    color: AppTheme.petalWhite),
                              ),
                              backgroundColor: AppTheme.deepRose,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _cMagenta.withValues(alpha: 0.8),
                              _cElectricPurple.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _cMagenta.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded,
                                color: _cWhite, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Add',
                              style: GoogleFonts.outfit(
                                color: _cWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : AppTheme.roseQuartz.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : AppTheme.roseQuartz.withValues(alpha: 0.1),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected ? color : AppTheme.roseQuartz.withValues(alpha: 0.4),
                size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: selected ? color : AppTheme.roseQuartz.withValues(alpha: 0.5),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 60,
              color: _cCyan.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'No anime found',
            style: GoogleFonts.outfit(
                color: _cMuted, fontSize: 16),
          ),
          if (_searchErrorMessage != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _searchErrorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: _cMagenta.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchLandingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 60,
              color: _cElectricPurple.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'Start typing to find magic\u2026',
            style: GoogleFonts.outfit(
                color: _cMuted, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Search thousands of anime from MyAnimeList and AniList',
            style: GoogleFonts.outfit(
              color: _cMuted.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 28),
          _buildQuickSearchChips(),
        ],
      ),
    );
  }

  /// Quick-access chips shown on the search landing state so users can
  /// start exploring without typing.
  Widget _buildQuickSearchChips() {
    final suggestions = [
      ('Top Airing', Icons.local_fire_department_rounded, _cMagenta),
      ('This Season', Icons.calendar_today_rounded, _cCyan),
      ('Popular Movies', Icons.movie_rounded, _cElectricPurple),
      ('All Time Best', Icons.star_rounded, _cGold),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: suggestions.map((s) {
        return GestureDetector(
          onTap: () {
            _searchController.text = s.$1;
            _performSearch(s.$1);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: s.$3.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: s.$3.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.$2, color: s.$3, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    s.$1,
                    style: GoogleFonts.outfit(
                      color: s.$3,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
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

/// Compact poster tile used in the home + library carousels is now
/// `ShelfPosterCard` (see `lib/shared/widgets/shelf/`).

/// Hero card for the Trending carousel is now `ShelfHeroCarousel`
/// (see `lib/shared/widgets/shelf/`).

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
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
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
