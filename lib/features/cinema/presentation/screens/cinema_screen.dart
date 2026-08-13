import 'dart:async';
import 'package:flutter/material.dart' hide FilterChip;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/media_item.dart';
import '../../data/services/tmdb_service.dart';
import '../widgets/episode_drawer.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_breakpoints.dart';
import 'package:go_router/go_router.dart';
import '../widgets/netflix/netflix_colors.dart';
import '../widgets/netflix/netflix_nav_bar.dart';

import '../widgets/tabs/cinema_home_tab.dart'
    show CinemaHomeTab, featuredGenres;
import '../widgets/tabs/cinema_search_tab.dart'
    show CinemaSearchTab;
import '../widgets/tabs/cinema_browse_tab.dart'
    show CinemaBrowseTab;
import '../widgets/tabs/cinema_library_tab.dart'
    show CinemaLibraryTab;
import '../../../watch_party/presentation/widgets/cinema_watch_together_tab.dart';

// ─────────────────────────────────────────────────────────────────────
// Cinema Color Tokens
// ─────────────────────────────────────────────────────────────────────

class CinemaScreen extends StatefulWidget {
  final int initialTab;

  const CinemaScreen({super.key, this.initialTab = 0});

  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen>
    with TickerProviderStateMixin {
  final TMDBService _tmdbService = TMDBService();
  int _currentIndex = 0;
  bool _navScrolled = false;

  /// Bumped every time a nav link targets the Browse tab so it rebuilds
  /// with the requested filter even when it is already mounted.
  int _browseSeed = 0;
  String? _pendingBrowseOption;

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
    _currentIndex = widget.initialTab.clamp(0, 4);
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
        // Same healing the dashboard's currently-watching shelf does:
        // items created by the player (played before being added to the
        // watchlist) can land in Firestore with an empty posterPath, so
        // backfill them before splitting into the continue-watching row.
        var refreshed = await _tmdbService.backfillMissingPosters(items);
        refreshed = await _tmdbService.refreshAnimePosters(refreshed);
        setState(() {
          _watchlist = refreshed;
          _splitWatchlists();
        });
      }
    });
  }

  void _splitWatchlists() {
    _watchedList = _watchlist.where((item) => item.isWatched).toList();
    _watchingList = _watchlist
        .where((item) => item.isCurrentlyWatching)
        .toList();
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
      _discoveryRows['korean_dramas'] = languageRows[0]
          .where((m) => !m.isAnime)
          .toList();
      _discoveryRows['bollywood'] = languageRows[1]
          .where((m) => !m.isAnime)
          .toList();
      _discoveryRows['spanish_cinema'] = languageRows[2]
          .where((m) => !m.isAnime)
          .toList();
      _discoveryRows['french_cinema'] = languageRows[3]
          .where((m) => !m.isAnime)
          .toList();
      _discoveryRows['decade_2010s'] = decadeRows[0]
          .where((m) => !m.isAnime)
          .toList();
      _discoveryRows['decade_2000s'] = decadeRows[1]
          .where((m) => !m.isAnime)
          .toList();
      _discoveryRows['classic_films'] = decadeRows[2]
          .where((m) => !m.isAnime)
          .toList();
    });
  }

  void _showMediaDetails(MediaItem item) {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close details',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, _, _) =>
          EpisodeDrawer(item: item, cinemaVariant: true),
      transitionBuilder: (context, animation, _, child) {
        final offset =
            Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  void _switchTab(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  /// Opens the Browse tab seeded with [optionId] (used by nav links).
  void _openBrowse(String optionId) {
    HapticFeedback.selectionClick();
    setState(() {
      _pendingBrowseOption = optionId;
      _browseSeed++;
      _currentIndex = 2;
    });
  }

  /// Netflix-style Play from the billboard: movies jump straight into the
  /// player; series open the drawer so the right episode can be picked.
  void _playNow(MediaItem item) {
    if (item.mediaType == 'movie') {
      context.push(
        '/cinema/video/${item.tmdbId}?type=movie'
        '&title=${Uri.encodeComponent(item.title)}&anime=false',
      );
      return;
    }
    _showMediaDetails(item);
  }

  void _onNavSelect(int tab, String? browseOptionId) {
    if (browseOptionId != null) {
      _openBrowse(browseOptionId);
      return;
    }
    _switchTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoint.isMobile(context);
    final isCoupleUser = context.read<AuthService>().isCoupleUser;

    return Scaffold(
      extendBody: true,
      backgroundColor: NetflixColors.background,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          final scrolled = notification.metrics.pixels > 48;
          if (scrolled != _navScrolled) {
            setState(() => _navScrolled = scrolled);
          }
          return false;
        },
        child: Stack(
          children: [
            const ColoredBox(color: NetflixColors.background),
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
                  onPlay: _playNow,
                  onSwitchTab: _switchTab,
                ),
                CinemaSearchTab(
                  trendingGlobal: _trendingGlobal,
                  onMediaTap: _showMediaDetails,
                  onSwitchTab: _switchTab,
                ),
                CinemaBrowseTab(
                  key: ValueKey('browse-$_browseSeed'),
                  initialOptionId: _pendingBrowseOption,
                  onMediaTap: _showMediaDetails,
                ),
                CinemaLibraryTab(
                  watchlist: _watchlist,
                  onMediaTap: _showMediaDetails,
                  onSwitchTab: _switchTab,
                ),
                CinemaWatchTogetherTab(
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
                child: NetflixNavBar(
                  scrolled: _navScrolled,
                  currentIndex: _currentIndex,
                  links: const [
                    NetflixNavLink('Home', 0),
                    NetflixNavLink('Movies', 2, 'collection-movies'),
                    NetflixNavLink('TV Shows', 2, 'collection-tv'),
                    NetflixNavLink('New & Popular', 2, 'collection-new'),
                    NetflixNavLink('My List', 3),
                    NetflixNavLink('Watch Together', 4),
                  ],
                  onSelect: _onNavSelect,
                  onSearchTap: () => _switchTab(1),
                  onBackToDashboard: isCoupleUser
                      ? () => context.go('/dashboard')
                      : null,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: isMobile
          ? NetflixNavBar(
              scrolled: _navScrolled,
              currentIndex: _currentIndex,
              links: const [
                NetflixNavLink('Home', 0),
                NetflixNavLink('New & Popular', 2, 'collection-new'),
                NetflixNavLink('My List', 3),
                NetflixNavLink('Search', 1),
              ],
              mobileItems: const [
                NetflixMobileItem(
                  label: 'Home',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  tab: 0,
                ),
                NetflixMobileItem(
                  label: 'New & Popular',
                  icon: Icons.local_fire_department_outlined,
                  activeIcon: Icons.local_fire_department_rounded,
                  tab: 2,
                  browseOptionId: 'collection-new',
                ),
                NetflixMobileItem(
                  label: 'My List',
                  icon: Icons.bookmark_border_rounded,
                  activeIcon: Icons.bookmark_rounded,
                  tab: 3,
                ),
                NetflixMobileItem(
                  label: 'Search',
                  icon: Icons.search_rounded,
                  activeIcon: Icons.search_rounded,
                  tab: 1,
                ),
                NetflixMobileItem(
                  label: 'Together',
                  icon: Icons.favorite_outline_rounded,
                  activeIcon: Icons.favorite_rounded,
                  tab: 4,
                ),
              ],
              onSelect: _onNavSelect,
            )
          : null,
    );
  }
}
