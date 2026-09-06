import 'dart:async';
import 'package:flutter/material.dart' hide FilterChip;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/media_item.dart';
import '../../data/services/tmdb_service.dart';
import '../widgets/cinema_sidebar.dart';
import '../widgets/episode_drawer.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_breakpoints.dart';
import 'package:go_router/go_router.dart';
import '../widgets/netflix/netflix_colors.dart';
import '../widgets/netflix/netflix_nav_bar.dart';

import '../widgets/tabs/cinema_home_tab.dart'
    show CinemaHomeTab, featuredGenres;
import '../widgets/tabs/cinema_search_tab.dart' show CinemaSearchTab;
import '../widgets/tabs/cinema_browse_tab.dart' show CinemaBrowseTab;
import '../widgets/tabs/cinema_library_tab.dart' show CinemaLibraryTab;
import '../../../watch_party/presentation/widgets/cinema_watch_together_tab.dart';

// ─────────────────────────────────────────────────────────────────────
// Cinema Color Tokens
// ─────────────────────────────────────────────────────────────────────

class CinemaScreen extends StatefulWidget {
  final int initialTab;
  final String? initialBrowseOption;

  const CinemaScreen({
    super.key,
    this.initialTab = 0,
    this.initialBrowseOption,
  });

  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen> {
  final TMDBService _tmdbService = TMDBService();
  int _currentIndex = 0;

  /// Bumped every time a nav link targets the Browse tab so it rebuilds
  /// with the requested filter even when it is already mounted.
  int _browseSeed = 0;
  String? _pendingBrowseOption;

  // ── Sidebar state ──────────────────────────────────────────────
  bool _mobileSidebarOpen = false;
  bool _desktopScrolled = false;

  StreamSubscription<List<MediaItem>>? _watchlistSubscription;

  List<MediaItem> _watchlist = [];
  List<MediaItem> _watchedList = [];
  List<MediaItem> _watchingList = [];

  List<MediaItem> _trendingCarousel = [];
  List<MediaItem> _trendingGlobal = [];
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

  bool _isLoadingHome = true;

  /// Watch Together mounts lazily (see build) — flipped on first visit.
  bool _hasVisitedTogether = false;

  /// Below-the-fold rails (genre + discovery rows) wait for the first scroll
  /// so opening Cinema only pays for the rows Claire can actually see.
  bool _deepRowsStarted = false;
  Timer? _deepRowsFallbackTimer;

  @override
  void initState() {
    super.initState();
    _pendingBrowseOption = widget.initialBrowseOption;
    if (_pendingBrowseOption != null) {
      _currentIndex = 2;
      _browseSeed = 1;
    } else {
      _currentIndex = widget.initialTab.clamp(0, 4);
    }
    if (_currentIndex == 4) _hasVisitedTogether = true;
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
    _watchlistSubscription?.cancel();
    _deepRowsFallbackTimer?.cancel();
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
      if (!mounted) return;
      setState(() {
        _watchlist = items;
        _splitWatchlists();
      });
      // Poster healing runs after paint so the list shows instantly; each
      // pass only touches items still missing art.
      var refreshed = await _tmdbService.backfillMissingPosters(items);
      refreshed = await _tmdbService.refreshAnimePosters(refreshed);
      if (!mounted) return;
      setState(() {
        _watchlist = refreshed;
        _splitWatchlists();
      });
    });
  }

  void _splitWatchlists() {
    // Cinema's rails own every movie (live-action or anime) plus non-anime
    // TV — see MediaItem.isCinemaItem. Anime series live in the anime rail.
    _watchedList = _watchlist.watchedCinema;
    _watchingList = _watchlist.watchingCinema;
  }

  Future<void> _fetchHomeData() async {
    setState(() => _isLoadingHome = true);
    _deepRowsStarted = false;
    _deepRowsFallbackTimer?.cancel();

    // Open pays for 5 visible rows only: billboard + trending, top rated,
    // popular series, now showing, new releases. Genre + discovery rails
    // wait for the first scroll (see _startDeepRows) so Claire's phone
    // isn't opening 13+ authenticated proxy calls at once.
    final currentYear = DateTime.now().year;
    await Future.wait([
      _loadRow(
        _tmdbService.fetchTrending(region: 'all', timeWindow: 'week'),
        (items) {
          _trendingGlobal = items;
          _trendingCarousel = items.take(5).toList();
        },
        dismissShimmer: true,
      ),
      _loadRow(
        _tmdbService.fetchTopRatedMovies(),
        (items) => _topRatedMovies = items,
      ),
      _loadRow(
        _tmdbService.fetchPopularTVShows(),
        (items) => _popularTVShows = items,
      ),
      _loadRow(
        _tmdbService.fetchNowPlaying(region: 'PH'),
        (items) => _nowShowing = items,
      ),
      _loadRow(
        _tmdbService.fetchUpcoming(region: 'PH'),
        (items) => _newlyReleased = items.where((m) {
          // Exclude obviously old movies (TMDB upcoming sometimes leaks
          // outdated entries like a 2004 film).
          final y = int.tryParse(m.year);
          return y == null || y >= currentYear - 1;
        }).toList(),
      ),
    ]);

    if (!mounted) return;
    // Safety net: if the critical row failed, don't trap the user on shimmer.
    if (_isLoadingHome) setState(() => _isLoadingHome = false);
    // Below-the-fold rails load on first scroll (see _onScrollNotification);
    // the timer covers screens where nothing scrolls.
    _deepRowsFallbackTimer = Timer(
      const Duration(seconds: 12),
      _startDeepRows,
    );
  }

  /// Awaits one home request and paints its rail on arrival. Anime is filtered
  /// here — the dedicated Anime tab already covers Japanese animation.
  Future<void> _loadRow(
    Future<List<MediaItem>> request,
    void Function(List<MediaItem> items) apply, {
    bool dismissShimmer = false,
  }) async {
    late final List<MediaItem> items;
    try {
      items = await request;
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      apply(items.where((m) => !m.isAnime).toList());
      if (dismissShimmer) _isLoadingHome = false;
    });
  }

  /// Starts the below-the-fold rails once, either from the first scroll or
  /// the fallback timer. The 4 mid-page rails paint as their own calls land;
  /// genre + decade rails wait until those finish so the proxy + TMDB
  /// never serve 17 concurrent calls from one phone.
  void _startDeepRows() {
    if (_deepRowsStarted || !mounted) return;
    _deepRowsStarted = true;
    _deepRowsFallbackTimer?.cancel();
    unawaited(_fetchMidRows().then((_) {
      if (!mounted) return;
      unawaited(_fetchGenreLists());
      unawaited(_fetchDiscoveryRows());
    }));
  }

  Future<void> _fetchMidRows() async {
    await Future.wait([
      _loadRow(
        _tmdbService.fetchPopularMovies(),
        (items) => _popularMovies = items,
      ),
      _loadRow(
        _tmdbService.fetchTopRatedTV(),
        (items) => _topRatedTV = items,
      ),
      _loadRow(
        _tmdbService.fetchAiringToday(),
        (items) => _airingToday = items,
      ),
      _loadRow(
        _tmdbService.fetchOnTheAir(),
        (items) => _onTheAir = items,
      ),
    ]);
  }

  Future<void> _fetchGenreLists() async {
    // Chunked so 10 genres don't take 10xRTT serially; each chunk paints
    // its rails as it lands.
    const concurrency = 4;
    for (var i = 0; i < featuredGenres.length; i += concurrency) {
      final chunk = featuredGenres.skip(i).take(concurrency);
      final settled = await Future.wait(
        chunk.map((genre) async {
          try {
            final items = await _tmdbService.discoverByGenre(
              genreId: genre['id'] as int,
              mediaType: genre['type'] as String,
            );
            return MapEntry(
              '${genre['name']}',
              items.where((m) => !m.isAnime).toList(),
            );
          } catch (_) {
            return MapEntry('${genre['name']}', <MediaItem>[]);
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        for (final entry in settled) {
          if (entry.value.isNotEmpty) _genreLists[entry.key] = entry.value;
        }
      });
    }
  }

  /// Fetches extended discovery rows — language and decade-based
  /// curated collections that load after the main home data (see
  /// [_startDeepRows]). All 7 fire at once instead of 4-then-3.
  Future<void> _fetchDiscoveryRows() async {
    late final List<List<MediaItem>> rows;
    try {
      rows = await Future.wait([
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
    } catch (_) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _discoveryRows['korean_dramas'] =
          rows[0].where((m) => !m.isAnime).toList();
      _discoveryRows['bollywood'] =
          rows[1].where((m) => !m.isAnime).toList();
      _discoveryRows['spanish_cinema'] =
          rows[2].where((m) => !m.isAnime).toList();
      _discoveryRows['french_cinema'] =
          rows[3].where((m) => !m.isAnime).toList();
      _discoveryRows['decade_2010s'] =
          rows[4].where((m) => !m.isAnime).toList();
      _discoveryRows['decade_2000s'] =
          rows[5].where((m) => !m.isAnime).toList();
      _discoveryRows['classic_films'] =
          rows[6].where((m) => !m.isAnime).toList();
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
    setState(() {
      _currentIndex = index;
      if (index == 4) _hasVisitedTogether = true;
    });
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

  void _playMedia(MediaItem item) {
    if (item.mediaType == 'movie') {
      context.push(
        '/cinema/video/${item.tmdbId}?type=movie'
        '&title=${Uri.encodeComponent(item.title)}&anime=false'
        '${(item.currentTimestamp ?? 0) > 0 ? '&start=${item.currentTimestamp}' : ''}',
      );
      return;
    }
    final season = item.currentSeason ?? 1;
    final episode = item.currentEpisode ?? 1;
    final start = item.currentTimestamp ?? 0;
    context.push(
      '/cinema/video/${item.tmdbId}?type=tv'
      '&title=${Uri.encodeComponent(item.title)}&anime=false'
      '&season=$season&episode=$episode'
      '${start > 0 ? '&start=$start' : ''}',
    );
  }

  Future<void> _toggleListItem(MediaItem item, bool add) async {
    final userName = context.read<AuthService>().currentUser ?? '';
    if (userName.isEmpty) return;
    try {
      await _tmdbService.setListMembership(item, userName, add: add);
    } catch (e) {
      debugPrint('[Cinema] Failed to update list membership: $e');
    }
  }

  Future<void> _rateItem(MediaItem item, double? rating) async {
    final userName = context.read<AuthService>().currentUser ?? '';
    if (userName.isEmpty) return;
    try {
      await _tmdbService.setUserRating(item, userName, rating: rating);
    } catch (e) {
      debugPrint('[Cinema] Failed to save title rating: $e');
    }
  }

  void _onNavSelect(int tab, String? browseOptionId) {
    if (browseOptionId != null) {
      _openBrowse(browseOptionId);
      return;
    }
    _switchTab(tab);
  }

  void _toggleSidebar() {
    HapticFeedback.selectionClick();
    setState(() => _mobileSidebarOpen = !_mobileSidebarOpen);
  }

  void _handleSidebarSelect(int tab, String? browseOptionId) {
    if (_mobileSidebarOpen) {
      setState(() => _mobileSidebarOpen = false);
    }
    _onNavSelect(tab, browseOptionId);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final scrolled = notification.metrics.pixels > 12;
    if (scrolled != _desktopScrolled) {
      setState(() => _desktopScrolled = scrolled);
    }
    // First real scroll past the billboard: start the below-the-fold rails.
    final metrics = notification.metrics;
    if (metrics.maxScrollExtent > 0 &&
        metrics.pixels > metrics.maxScrollExtent * 0.25) {
      _startDeepRows();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoint.isDesktop(context);
    final auth = context.watch<AuthService>();
    final isCoupleUser = auth.isCoupleUser;
    final isCinemaOnlyUser = auth.isCinemaOnlyUser;
    final userName = auth.currentUser ?? '';

    // Sidebar widget (reused for both layouts, just different toggle behavior)
    Widget buildSidebar({
      required bool collapsed,
      required VoidCallback onToggle,
    }) {
      final router = GoRouter.of(context);
      return CinemaSidebar(
        currentIndex: _currentIndex,
        activeBrowseOption: _pendingBrowseOption,
        isCollapsed: false,
        onToggle: onToggle,
        onSelect: _handleSidebarSelect,
        onAnimeTap: () {
          if (_mobileSidebarOpen) {
            setState(() => _mobileSidebarOpen = false);
          }
          router.go('/anime');
        },
        onDashboardTap: isCoupleUser ? () => router.go('/dashboard') : null,
        onLogout: () async {
          if (_mobileSidebarOpen) {
            setState(() => _mobileSidebarOpen = false);
          }
          await auth.logout();
          if (!mounted) return;
          router.go('/');
        },
        userName: userName,
        isCinemaOnlyUser: isCinemaOnlyUser,
      );
    }

    // Main cinema content. The desktop top bar overlays it so the hero
    // can remain full bleed, just like the streaming-service pattern.
    Widget buildCinemaContent() {
      return NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: Stack(
          children: [
            const ColoredBox(color: NetflixColors.background),
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
                  onRefresh: _fetchHomeData,
                  onMediaTap: _showMediaDetails,
                  onPlay: _playNow,
                  onPlayItem: _playMedia,
                  onToggleListItem: _toggleListItem,
                  onRateItem: _rateItem,
                  isInList: (item) =>
                      _watchlist.any((saved) => saved.tmdbId == item.tmdbId),
                  onSwitchTab: _switchTab,
                ),
                CinemaSearchTab(
                  trendingGlobal: _trendingGlobal,
                  onMediaTap: _showMediaDetails,
                  onPlayItem: _playMedia,
                  onToggleListItem: _toggleListItem,
                  onRateItem: _rateItem,
                  isInList: (item) =>
                      _watchlist.any((saved) => saved.tmdbId == item.tmdbId),
                  onSwitchTab: _switchTab,
                ),
                CinemaBrowseTab(
                  key: ValueKey('browse-$_browseSeed'),
                  initialOptionId: _pendingBrowseOption,
                  onMediaTap: _showMediaDetails,
                  onPlayItem: _playMedia,
                  onToggleListItem: _toggleListItem,
                  onRateItem: _rateItem,
                  isInList: (item) =>
                      _watchlist.any((saved) => saved.tmdbId == item.tmdbId),
                ),
                CinemaLibraryTab(
                  watchlist: _watchlist,
                  onMediaTap: _showMediaDetails,
                  onPlayItem: _playMedia,
                  onToggleListItem: _toggleListItem,
                  onRateItem: _rateItem,
                  onSwitchTab: _switchTab,
                ),
                // Watch Together holds a Jellyfin fetch + room stream, so it
                // only mounts once visited — otherwise every Cinema open pays
                // for a tab Claire may never tap.
                if (_hasVisitedTogether)
                  CinemaWatchTogetherTab(
                    watchlist: _watchlist,
                    onMediaTap: _showMediaDetails,
                    onSwitchTab: _switchTab,
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
            if (!isDesktop && !_mobileSidebarOpen)
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12, top: 10),
                    child: Material(
                      color: const Color(0xFF14101A),
                      shape: const CircleBorder(
                        side: BorderSide(color: Color(0x1AFFFFFF)),
                      ),
                      elevation: 8,
                      child: InkWell(
                        onTap: _toggleSidebar,
                        customBorder: const CircleBorder(),
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // ── Desktop: transparent-to-solid catalog top bar ─────────────
    if (isDesktop) {
      return Scaffold(
        backgroundColor: NetflixColors.background,
        extendBody: true,
        body: Stack(
          children: [
            buildCinemaContent(),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: NetflixCinemaTopBar(
                currentIndex: _currentIndex,
                scrolled: _desktopScrolled,
                onSelect: _onNavSelect,
                onAnimeTap: () => GoRouter.of(context).go('/anime'),
                onDashboardTap: isCoupleUser
                    ? () => GoRouter.of(context).go('/dashboard')
                    : null,
                onLogout: () async {
                  final router = GoRouter.of(context);
                  await auth.logout();
                  if (!mounted) return;
                  router.go('/');
                },
                userName: userName,
                showAnime: isCinemaOnlyUser,
                links: const [
                  NetflixNavLink('Home', 0),
                  NetflixNavLink('New & Popular', 2, 'collection-new'),
                  NetflixNavLink('My List', 3),
                  NetflixNavLink('Search', 1),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile / Tablet: overlay drawer ───────────────────────────
    return Scaffold(
      extendBody: true,
      backgroundColor: NetflixColors.background,
      body: Stack(
        children: [
          buildCinemaContent(),
          if (_mobileSidebarOpen) ...[
            // Scrim
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _mobileSidebarOpen = false),
                child: Container(color: Colors.black.withValues(alpha: 0.55)),
              ),
            ),
            // Drawer panel — slides in from the left
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Material(
                color: const Color(0xFF0F0A14),
                elevation: 24,
                child: SizedBox(
                  width: 280,
                  child: buildSidebar(
                    collapsed: false,
                    onToggle: () => setState(() => _mobileSidebarOpen = false),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: NetflixNavBar(
        scrolled: false,
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
      ),
    );
  }
}
