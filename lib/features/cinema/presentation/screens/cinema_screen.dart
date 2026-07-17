import 'dart:async';
import 'package:flutter/material.dart' hide FilterChip;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/shared/widgets/shelf/atmospheric_backdrop.dart';
import 'package:everglow/shared/widgets/shelf/cinema_nav_bar.dart';
import 'package:everglow/core/theme/app_breakpoints.dart';
import 'package:go_router/go_router.dart';

import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_home_tab.dart'
    show CinemaHomeTab, featuredGenres;
import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_search_tab.dart'
    show CinemaSearchTab;
import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_browse_tab.dart'
    show CinemaBrowseTab;
import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_library_tab.dart'
    show CinemaLibraryTab;

// ─────────────────────────────────────────────────────────────────────
// Cinema Color Tokens
// ─────────────────────────────────────────────────────────────────────

class CinemaScreen extends StatefulWidget {
  const CinemaScreen({super.key});

  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen>
    with TickerProviderStateMixin {
  final TMDBService _tmdbService = TMDBService();
  int _currentIndex = 0;

  // Nav animation
  late AnimationController _navController;

  StreamSubscription<List<MediaItem>>? _watchlistSubscription;

  List<MediaItem> _watchlist = [];
  List<MediaItem> _watchedList = [];
  List<MediaItem> _watchingList = [];

  List<MediaItem> _trendingCarousel = [];
  List<MediaItem> _trendingGlobal = [];
  List<MediaItem> _trendingPH = [];
  List<MediaItem> _topRatedMovies = [];
  List<MediaItem> _popularTVShows = [];
  List<MediaItem> _nowShowing = [];
  List<MediaItem> _newlyReleased = [];

  // Discovery rows (Phase 3a)
  List<MediaItem> _popularMovies = [];
  List<MediaItem> _topRatedTV = [];
  List<MediaItem> _airingToday = [];
  List<MediaItem> _onTheAir = [];
  final Map<String, List<MediaItem>> _discoveryRows = {};

  final Map<String, List<MediaItem>> _genreLists = {};
  final Map<int, String> _movieGenres = {};
  final Map<int, String> _tvGenres = {};

  bool _isLoadingHome = true;

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fetchHomeData();
    // Read auth-dependent state after the first frame so Provider is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthService>();
      final userName = auth.currentUser ?? '';
      if (userName.isEmpty) return;
      _loadCachedWatchList(userName);
      _subscribeToWatchList(userName);
    });
  }

  @override
  void dispose() {
    _navController.dispose();
    _watchlistSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedWatchList(String userName) async {
    final cached = await _tmdbService.getCachedWatchList(userName);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _watchlist = cached;
        _splitWatchlists();
      });
    }
  }

  void _subscribeToWatchList(String userName) {
    _watchlistSubscription = _tmdbService.getWatchListStream(userName).listen((
      items,
    ) async {
      if (mounted) {
        final refreshed = await _tmdbService.refreshAnimePosters(items);
        setState(() {
          _watchlist = refreshed;
          _splitWatchlists();
        });
      }
    });
  }

  void _splitWatchlists() {
    _watchedList = _watchlist.where((item) => item.isWatched).toList();
    _watchingList =
        _watchlist.where((item) => item.isCurrentlyWatching).toList();
  }

  Future<void> _fetchHomeData() async {
    setState(() => _isLoadingHome = true);

    final results = await Future.wait([
      _tmdbService.fetchTrending(region: 'all', timeWindow: 'week'),
      _tmdbService.fetchTrending(region: 'PH', timeWindow: 'week'),
      _tmdbService.fetchTopRatedMovies(),
      _tmdbService.fetchPopularTVShows(),
      _tmdbService.fetchNowPlaying(region: 'PH'),
      _tmdbService.fetchUpcoming(region: 'PH'),
      _tmdbService.fetchGenreList('movie'),
      _tmdbService.fetchGenreList('tv'),
      // Discovery rows (Phase 3a)
      _tmdbService.fetchPopularMovies(),
      _tmdbService.fetchTopRatedTV(),
      _tmdbService.fetchAiringToday(),
      _tmdbService.fetchOnTheAir(),
    ]);

    if (!mounted) return;

    // Filter out anime from all cinema lists — the dedicated Anime tab
    // already covers Japanese animation content.
    final trendingGlobal = (results[0] as List<MediaItem>)
        .where((m) => !m.isAnime)
        .toList();
    final trendingPH = (results[1] as List<MediaItem>)
        .where((m) => !m.isAnime)
        .toList();
    final topRated = (results[2] as List<MediaItem>)
        .where((m) => !m.isAnime)
        .toList();
    final popularTV = (results[3] as List<MediaItem>)
        .where((m) => !m.isAnime)
        .toList();
    final nowShowing = (results[4] as List<MediaItem>)
        .where((m) => !m.isAnime)
        .toList();
    final currentYear = DateTime.now().year;
    final newlyReleased = (results[5] as List<MediaItem>)
        .where((m) => !m.isAnime)
        .where((m) {
          // Exclude obviously old movies (TMDB upcoming sometimes leaks
          // outdated entries like a 2004 film).
          final y = int.tryParse(m.year);
          return y == null || y >= currentYear - 1;
        })
        .toList();
    final movieGenres = results[6] as Map<int, String>;
    final tvGenres = results[7] as Map<int, String>;
    final popularMovies = (results[8] as List<MediaItem>)
        .where((m) => !m.isAnime)
        .toList();
    final topRatedTV = (results[9] as List<MediaItem>)
        .where((m) => !m.isAnime)
        .toList();
    final airingToday = (results[10] as List<MediaItem>)
        .where((m) => !m.isAnime)
        .toList();
    final onTheAir = (results[11] as List<MediaItem>)
        .where((m) => !m.isAnime)
        .toList();

    setState(() {
      _trendingGlobal = trendingGlobal;
      _trendingPH = trendingPH;
      _trendingCarousel = trendingGlobal.take(5).toList();
      _topRatedMovies = topRated;
      _popularTVShows = popularTV;
      _nowShowing = nowShowing;
      _newlyReleased = newlyReleased;
      _popularMovies = popularMovies;
      _topRatedTV = topRatedTV;
      _airingToday = airingToday;
      _onTheAir = onTheAir;
      _movieGenres
        ..clear()
        ..addAll(movieGenres);
      _tvGenres
        ..clear()
        ..addAll(tvGenres);
      _isLoadingHome = false;
    });

    _fetchGenreLists();
    _fetchDiscoveryRows();
  }

  Future<void> _fetchGenreLists() async {
    for (final genre in featuredGenres) {
      final items = await _tmdbService.discoverByGenre(
        genreId: genre['id'] as int,
        mediaType: genre['type'] as String,
      );
      final filtered = items.where((m) => !m.isAnime).toList();
      if (mounted && filtered.isNotEmpty) {
        setState(() {
          _genreLists['${genre['name']}'] = filtered;
        });
      }
    }
  }

  /// Fetches extended discovery rows — language and decade-based
  /// curated collections that are loaded after the main home data.
  Future<void> _fetchDiscoveryRows() async {
    final languageRows = await Future.wait([
      _tmdbService.discoverMedia(
        mediaType: 'tv',
        withOriginalLanguage: 'ko',
        sortBy: 'vote_average.desc',
        voteAverageGte: 7.0,
      ),
      _tmdbService.discoverMedia(
        mediaType: 'movie',
        withOriginalLanguage: 'hi',
        sortBy: 'vote_average.desc',
        voteAverageGte: 7.0,
      ),
      _tmdbService.discoverMedia(
        mediaType: 'movie',
        withOriginalLanguage: 'es',
        sortBy: 'vote_average.desc',
        voteAverageGte: 7.0,
      ),
      _tmdbService.discoverMedia(
        mediaType: 'movie',
        withOriginalLanguage: 'fr',
        sortBy: 'vote_average.desc',
        voteAverageGte: 7.0,
      ),
    ]);

    final decadeRows = await Future.wait([
      _tmdbService.discoverMedia(
        mediaType: 'movie',
        yearGte: 2010,
        yearLte: 2019,
        voteAverageGte: 7.0,
      ),
      _tmdbService.discoverMedia(
        mediaType: 'movie',
        yearGte: 2000,
        yearLte: 2009,
        voteAverageGte: 7.0,
      ),
      _tmdbService.discoverMedia(
        mediaType: 'movie',
        yearLte: 1999,
        voteAverageGte: 7.0,
        voteCountGte: 500,
      ),
    ]);

    if (!mounted) return;
    setState(() {
      _discoveryRows['korean_dramas'] =
          (languageRows[0] as List<MediaItem>)
              .where((m) => !m.isAnime)
              .toList();
      _discoveryRows['bollywood'] =
          (languageRows[1] as List<MediaItem>)
              .where((m) => !m.isAnime)
              .toList();
      _discoveryRows['spanish_cinema'] =
          (languageRows[2] as List<MediaItem>)
              .where((m) => !m.isAnime)
              .toList();
      _discoveryRows['french_cinema'] =
          (languageRows[3] as List<MediaItem>)
              .where((m) => !m.isAnime)
              .toList();
      _discoveryRows['decade_2010s'] =
          (decadeRows[0] as List<MediaItem>)
              .where((m) => !m.isAnime)
              .toList();
      _discoveryRows['decade_2000s'] =
          (decadeRows[1] as List<MediaItem>)
              .where((m) => !m.isAnime)
              .toList();
      _discoveryRows['classic_films'] =
          (decadeRows[2] as List<MediaItem>)
              .where((m) => !m.isAnime)
              .toList();
    });
  }

  void _showMediaDetails(MediaItem item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpisodeDrawer(item: item),
    );
  }

  void _switchTab(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoint.isMobile(context);
    final isCoupleUser = context.read<AuthService>().isCoupleUser;

    final navBarItems = const [
      CinemaNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
      ),
      CinemaNavItem(
        icon: Icons.search_rounded,
        activeIcon: Icons.search_rounded,
        label: 'Search',
      ),
      CinemaNavItem(
        icon: Icons.category_outlined,
        activeIcon: Icons.category_rounded,
        label: 'Browse',
      ),
      CinemaNavItem(
        icon: Icons.collections_bookmark_outlined,
        activeIcon: Icons.collections_bookmark_rounded,
        label: 'Library',
      ),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF080810),
      body: Stack(
        children: [
          const ShelfAtmosphericBackdrop(),
          // Content
          IndexedStack(
            index: _currentIndex,
            children: [
              CinemaHomeTab(
                isLoadingHome: _isLoadingHome,
                trendingCarousel: _trendingCarousel,
                topRatedMovies: _topRatedMovies,
                popularTVShows: _popularTVShows,
                nowShowing: _nowShowing,
                newlyReleased: _newlyReleased,
                popularMovies: _popularMovies,
                topRatedTV: _topRatedTV,
                airingToday: _airingToday,
                onTheAir: _onTheAir,
                discoveryRows: _discoveryRows,
                genreLists: _genreLists,
                watchingList: _watchingList,
                watchedList: _watchedList,
                trendingGlobal: _trendingGlobal,
                trendingPH: _trendingPH,
                onRefresh: _fetchHomeData,
                onMediaTap: _showMediaDetails,
                onSwitchTab: _switchTab,
              ),
              CinemaSearchTab(
                trendingGlobal: _trendingGlobal,
                onMediaTap: _showMediaDetails,
                onSwitchTab: _switchTab,
              ),
              CinemaBrowseTab(
                onMediaTap: _showMediaDetails,
              ),
              CinemaLibraryTab(
                watchlist: _watchlist,
                onMediaTap: _showMediaDetails,
                onSwitchTab: _switchTab,
              ),
            ],
          ),
          // Floating top navbar (desktop/tablet only — overlays hero)
          if (!isMobile)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: CinemaNavBar(
                currentIndex: _currentIndex,
                items: navBarItems,
                onTap: _switchTab,
                onSearchTap: () => _switchTab(1),
                logoText: 'Everglow Cinema',
                onBackToDashboard: isCoupleUser
                    ? () => context.go('/dashboard')
                    : null,
              ),
            ),
        ],
      ),
      // Bottom nav (mobile only)
      bottomNavigationBar: isMobile
          ? CinemaNavBar(
              currentIndex: _currentIndex,
              items: navBarItems,
              onTap: _switchTab,
              onSearchTap: () => _switchTab(1),
              logoText: 'Everglow Cinema',
              onBackToDashboard: isCoupleUser
                  ? () => context.go('/dashboard')
                  : null,
            )
          : null,
    );
  }
}
