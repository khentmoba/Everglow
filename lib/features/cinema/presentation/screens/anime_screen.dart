import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Picture, PictureRecorder;
import 'package:flutter/material.dart' hide FilterChip;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/anime_categories.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/jikan_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/shared/widgets/shelf/atmospheric_backdrop.dart';
import 'package:everglow/shared/widgets/shelf/shelf_pill_bottom_nav.dart';

import 'package:everglow/features/cinema/presentation/widgets/anime_tabs/anime_models.dart';
import 'package:everglow/features/cinema/presentation/widgets/anime_tabs/anime_home_tab.dart';
import 'package:everglow/features/cinema/presentation/widgets/anime_tabs/anime_browse_tab.dart';
import 'package:everglow/features/cinema/presentation/widgets/anime_tabs/anime_library_tab.dart';
import 'package:everglow/features/cinema/presentation/widgets/anime_tabs/anime_search_tab.dart';

// Anime palette — now sourced from AppColors for design-system consistency.
const _cBlack     = AppColors.animeBackground;
const _cMagenta   = AppColors.animeMagenta;
const _cCyan      = AppColors.animeCyan;
const _cElectricPurple = AppColors.animeElectricPurple;

/// Dedicated entry for the anime rail. Four tabs:
///   * Home     — Leads with Trending Now + Currently Airing, followed
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
  const AnimeScreen({super.key});

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen>
    with TickerProviderStateMixin {
  final JikanService _jikanService = JikanService();
  final TMDBService _tmdbService = TMDBService();
  int _currentIndex = 0;

  // Library / watchlist
  StreamSubscription<List<MediaItem>>? _watchlistSub;
  List<MediaItem> _library = [];

  // Home tab
  final Map<String, AnimeRowData> _homeRows = {};
  late final List<AnimeHomeSection> _homeSections;

  // Browse tab
  String? _selectedCategoryId;
  final Map<String, AnimeRowData> _browseResults = {};

  // Genre rows for home tab
  final Map<String, List<MediaItem>> _genreRows = {};

  // Top 10 for home tab
  List<MediaItem> _topTenItems = [];

  @override
  void initState() {
    super.initState();
    _homeSections = _buildHomeSections();
    _bootstrap();
  }

  List<AnimeHomeSection> _buildHomeSections() => [
        AnimeHomeSection(
          id: 'trending',
          title: 'Trending Now',
          icon: Icons.local_fire_department_rounded,
          tint: const Color(0xFFFF7043),
          builder: () async {
            try {
              final items = await _jikanService.fetchTopAiring();
              if (items.length >= 5) return items;
            } catch (e) {
              debugPrint('[AnimeScreen] Jikan top airing fetch failed, falling back to TMDB: $e');
            }
            return _tmdbService.fetchTrendingAnime();
          },
          isHero: true,
        ),
        AnimeHomeSection(
          id: 'airing',
          title: 'Currently Airing',
          icon: Icons.live_tv_rounded,
          tint: const Color(0xFFE53935),
          builder: () async {
            try {
              final items = await _jikanService.fetchSeasonNow();
              if (items.length >= 5) return items;
            } catch (e) {
              debugPrint('[AnimeScreen] Jikan season now fetch failed, falling back to TMDB: $e');
            }
            final now = DateTime.now();
            final threeMonthsAgo = now.subtract(const Duration(days: 90));
            return _tmdbService.discoverAnime(
              sortBy: 'popularity.desc',
              airDateGte: threeMonthsAgo.toIso8601String().substring(0, 10),
              voteCountGte: 5,
            );
          },
        ),
        AnimeHomeSection(
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
              if (items.length >= 5) return items;
            } catch (e) {
              debugPrint('[AnimeScreen] Jikan top rated fetch failed, falling back to TMDB: $e');
            }
            return _tmdbService.discoverAnime(
              sortBy: 'vote_average.desc',
              voteCountGte: 300,
            );
          },
        ),
        AnimeHomeSection(
          id: 'new-releases',
          title: 'New Releases',
          icon: Icons.fiber_new_rounded,
          tint: const Color(0xFF42A5F5),
          builder: () async {
            try {
              final items = await _jikanService.fetchNewReleases();
              if (items.length >= 5) return items;
            } catch (e) {
              debugPrint('[AnimeScreen] Jikan new releases fetch failed, falling back to TMDB: $e');
            }
            final now = DateTime.now();
            final sixMonthsAgo = now.subtract(const Duration(days: 180));
            return _tmdbService.discoverAnime(
              sortBy: 'first_air_date.desc',
              firstAirDateGte: sixMonthsAgo.toIso8601String().substring(0, 10),
              voteCountGte: 10,
            );
          },
        ),
        AnimeHomeSection(
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
              if (items.length >= 5) return items;
            } catch (e) {
              debugPrint('[AnimeScreen] Jikan popular all time fetch failed, falling back to TMDB: $e');
            }
            return _tmdbService.discoverAnime(
              sortBy: 'popularity.desc',
              voteCountGte: 100,
            );
          },
        ),
        AnimeHomeSection(
          id: 'hidden-gems',
          title: 'Hidden Gems',
          icon: Icons.diamond_rounded,
          tint: const Color(0xFF26C6DA),
          builder: () async {
            try {
              final items = await _jikanService.fetchHiddenGems();
              if (items.length >= 5) return items;
            } catch (e) {
              debugPrint('[AnimeScreen] Jikan hidden gems fetch failed, falling back to TMDB: $e');
            }
            return _tmdbService.discoverAnime(
              sortBy: 'vote_average.desc',
              voteCountGte: 50,
              voteCountLte: 5000,
              voteAverageGte: 7.5,
            );
          },
        ),
        AnimeHomeSection(
          id: 'editors-picks',
          title: "Editor's Picks",
          icon: Icons.workspace_premium_rounded,
          tint: const Color(0xFFEC407A),
          builder: () async {
            try {
              final items = await animeCategoryOptions
                  .firstWhere((o) => o.id == 'curated-editors-picks')
                  .fetch(_jikanService);
              if (items.length >= 5) return items;
            } catch (e) {
              debugPrint('[AnimeScreen] Jikan editor\'s picks fetch failed, falling back to TMDB: $e');
            }
            return _tmdbService.discoverAnime(
              sortBy: 'vote_average.desc',
              voteCountGte: 1000,
            );
          },
        ),
        AnimeHomeSection(
          id: 'you-might-like',
          title: 'You Might Like',
          icon: Icons.recommend_rounded,
          tint: const Color(0xFF00E5FF),
          builder: () async {
            try {
              final items = await _jikanService.fetchTopAiring();
              if (items.length >= 5) {
                items.shuffle();
                return items.take(15).toList();
              }
            } catch (e) {
              debugPrint('[AnimeScreen] Jikan you might like fetch failed, falling back to TMDB: $e');
            }
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
      _homeRows[section.id] ??= AnimeRowData(isLoading: true);
      _runRow(section.id, _homeRows, section.builder);
    }
    if (mounted) setState(() {});
  }

  Future<void> _runRow(
    String id,
    Map<String, AnimeRowData> rows,
    Future<List<MediaItem>> Function() builder,
  ) async {
    try {
      final items = await builder();
      if (!mounted) return;
      rows[id] = AnimeRowData(items: items, isLoading: false);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      rows[id] = AnimeRowData(items: const [], isLoading: false, hasError: true);
      setState(() {});
    }
  }

  Future<void> _refreshHome() async {
    for (final section in _homeSections) {
      _homeRows[section.id] = AnimeRowData(isLoading: true);
    }
    if (mounted) setState(() {});
    await Future.wait([
      _loadHome(),
      _loadGenreRows(),
      _loadTopTen(),
    ]);
  }

  Future<void> _loadGenreRows() async {
    final futures = _genreMeta.entries.map((entry) async {
      try {
        final items = await _jikanService.fetchByGenres(entry.value.genreIds, limit: 15);
        if (items.isNotEmpty && mounted) {
          setState(() => _genreRows[entry.key] = items);
        }
      } catch (e) {
        debugPrint('[AnimeScreen] Jikan genre fetch failed for ${entry.key}: $e');
      }
    });

    await Future.wait(futures);
  }

  Future<void> _loadTopTen() async {
    try {
      final items = await _jikanService.fetchTopAiring(limit: 10);
      if (mounted) setState(() => _topTenItems = items);
    } catch (e) {
      debugPrint('[AnimeScreen] Jikan top ten fetch failed: $e');
    }
  }

  Future<void> _selectCategory(AnimeCategoryOption option) async {
    setState(() {
      _selectedCategoryId = option.id;
      _browseResults[option.id] ??= AnimeRowData(isLoading: true);
    });
    await _runRow(option.id, _browseResults, () async {
      try {
        final items = await option.fetch(_jikanService);
        if (items.isNotEmpty) return items;
      } catch (e) {
        debugPrint('[AnimeScreen] Jikan category fetch failed for ${option.id}: $e');
      }
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
                AnimeHomeTab(
                  homeSections: _homeSections,
                  homeRows: _homeRows,
                  genreRows: _genreRows,
                  topTenItems: _topTenItems,
                  library: _library,
                  onRefresh: _refreshHome,
                  onTapItem: _openDetails,
                  onOpenSearch: () => setState(() => _currentIndex = 3),
                  onRetryRow: (section) {
                    setState(() {
                      _homeRows[section.id] = AnimeRowData(isLoading: true);
                    });
                    _runRow(section.id, _homeRows, section.builder);
                  },
                ),
                AnimeBrowseTab(
                  selectedCategoryId: _selectedCategoryId,
                  browseResults: _browseResults,
                  onSelectCategory: _selectCategory,
                  onTapItem: _openDetails,
                  onClearFilter: () => setState(() => _selectedCategoryId = null),
                ),
                AnimeLibraryTab(
                  library: _library,
                  onTapItem: _openDetails,
                  onOpenSearch: () => setState(() => _currentIndex = 3),
                ),
                AnimeSearchTab(
                  onBack: () => setState(() => _currentIndex = 0),
                ),
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
}

// ── Genre meta for home tab genre rows ──────────────────────────
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

// ── ANIME SPARKLE ANIMATION ─────────────────────────────────────

/// Floating diamond/star sparkle particles that drift across the anime
/// screen background.
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

    _starPicture = _createStarPicture();
  }

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
        builder: (_, _) => CustomPaint(
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
  final double hue;
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

  static const _colors = [
    Color(0x80FF2D55),
    Color(0x8000BCD4),
    Color(0x807C3AED),
    Color(0x80FF4081),
  ];

  @override
  void paint(Canvas canvas, Size size) {
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
      canvas.scale(s.size);
      canvas.drawPicture(starPicture);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.progress != progress;
}
