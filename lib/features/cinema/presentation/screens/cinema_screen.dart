import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/services/auth_service.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Cinema Color Tokens
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _cBlack = Color(0xFF080810);
const _cVelvet = Color(0xFF12091A);
const _cCard = Color(0xFF1C1228);
const _cRose = Color(0xFFF4C2C2);
const _cDeepRose = Color(0xFFC2185B);
const _cGold = Color(0xFFE8C97A);
const _cAmber = Color(0xFFF0A500);
const _cWhite = Color(0xFFFFF5F5);
const _cMuted = Color(0xFF8A7A92);


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
  List<MediaItem> _wantToWatchList = [];
  List<MediaItem> _watchedList = [];

  List<MediaItem> _trendingCarousel = [];
  List<MediaItem> _trendingGlobal = [];
  List<MediaItem> _trendingPH = [];
  List<MediaItem> _topRatedMovies = [];
  List<MediaItem> _popularTVShows = [];
  List<MediaItem> _nowShowing = [];
  List<MediaItem> _newlyReleased = [];

  final Map<String, List<MediaItem>> _genreLists = {};
  final Map<int, String> _movieGenres = {};
  final Map<int, String> _tvGenres = {};

  bool _isLoadingHome = true;
  final PageController _carouselController =
      PageController(viewportFraction: 0.88);
  int _carouselPage = 0;
  Timer? _carouselTimer;

  static final List<Map<String, dynamic>> _featuredGenres = [
    {
      'id': 28,
      'name': 'Action',
      'type': 'movie',
      'icon': Icons.local_fire_department_rounded,
      'color': const Color(0xFFE53935),
    },
    {
      'id': 35,
      'name': 'Comedy',
      'type': 'movie',
      'icon': Icons.sentiment_very_satisfied_rounded,
      'color': const Color(0xFFFDD835),
    },
    {
      'id': 27,
      'name': 'Horror',
      'type': 'movie',
      'icon': Icons.brightness_3_rounded,
      'color': const Color(0xFF7B1FA2),
    },
    {
      'id': 10749,
      'name': 'Romance',
      'type': 'movie',
      'icon': Icons.favorite_rounded,
      'color': const Color(0xFFE91E63),
    },
    {
      'id': 18,
      'name': 'Drama',
      'type': 'movie',
      'icon': Icons.theater_comedy_rounded,
      'color': const Color(0xFF1565C0),
    },
    {
      'id': 16,
      'name': 'Animation',
      'type': 'movie',
      'icon': Icons.auto_awesome_rounded,
      'color': const Color(0xFF00ACC1),
    },
    {
      'id': 9648,
      'name': 'Mystery',
      'type': 'movie',
      'icon': Icons.youtube_searched_for_rounded,
      'color': const Color(0xFF455A64),
    },
    {
      'id': 878,
      'name': 'Sci-Fi',
      'type': 'movie',
      'icon': Icons.rocket_launch_rounded,
      'color': const Color(0xFF00BCD4),
    },
    {
      'id': 10765,
      'name': 'Sci-Fi & Fantasy',
      'type': 'tv',
      'icon': Icons.public_rounded,
      'color': const Color(0xFF3949AB),
    },
    {
      'id': 10759,
      'name': 'Action & Adventure',
      'type': 'tv',
      'icon': Icons.shield_rounded,
      'color': const Color(0xFFEF6C00),
    },
  ];

  final TextEditingController _searchController = TextEditingController();
  List<MediaItem> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

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
      final userName = context.read<AuthService>().currentUser ?? '';
      if (userName.isEmpty) return;
      _loadCachedWatchList(userName);
      _subscribeToWatchList(userName);
    });
  }

  @override
  void dispose() {
    _navController.dispose();
    _watchlistSubscription?.cancel();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _carouselController.dispose();
    _carouselTimer?.cancel();
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
    _watchlistSubscription = _tmdbService.getWatchListStream(userName).listen((items) {
      if (mounted) {
        setState(() {
          _watchlist = items;
          _splitWatchlists();
        });
      }
    });
  }

  void _splitWatchlists() {
    _wantToWatchList = _watchlist.where((item) => item.isToWatch).toList();
    _watchedList = _watchlist.where((item) => item.isWatched).toList();
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
    ]);

    if (!mounted) return;

    final trendingGlobal = results[0] as List<MediaItem>;
    final trendingPH = results[1] as List<MediaItem>;
    final topRated = results[2] as List<MediaItem>;
    final popularTV = results[3] as List<MediaItem>;
    final nowShowing = results[4] as List<MediaItem>;
    final newlyReleased = results[5] as List<MediaItem>;
    final movieGenres = results[6] as Map<int, String>;
    final tvGenres = results[7] as Map<int, String>;

    setState(() {
      _trendingGlobal = trendingGlobal;
      _trendingPH = trendingPH;
      _trendingCarousel = trendingGlobal.take(5).toList();
      _topRatedMovies = topRated;
      _popularTVShows = popularTV;
      _nowShowing = nowShowing;
      _newlyReleased = newlyReleased;
      _movieGenres
        ..clear()
        ..addAll(movieGenres);
      _tvGenres
        ..clear()
        ..addAll(tvGenres);
      _isLoadingHome = false;
    });

    _startCarouselAutoPlay();
    _fetchGenreLists();
  }

  Future<void> _fetchGenreLists() async {
    for (final genre in _featuredGenres) {
      final items = await _tmdbService.discoverByGenre(
        genreId: genre['id'] as int,
        mediaType: genre['type'] as String,
      );
      if (mounted && items.isNotEmpty) {
        setState(() {
          _genreLists['${genre['name']}'] = items;
        });
      }
    }
  }

  void _startCarouselAutoPlay() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_trendingCarousel.isEmpty || !_carouselController.hasClients) return;
      final nextPage = (_carouselPage + 1) % _trendingCarousel.length;
      _carouselController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _performSearch(query.trim());
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final results = await _tmdbService.searchMedia(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
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
    return Scaffold(
      extendBody: true,
      backgroundColor: _cBlack,
      body: SafeArea(
        top: false,
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(),
            _buildSearchTab(),
            _buildWatchlistTab(isWatchedTab: false),
            _buildWatchlistTab(isWatchedTab: true),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // 1. HOME TAB
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildHomeTab() {
    if (_isLoadingHome) {
      return _buildShimmerHome();
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildTopHeader()),
        SliverToBoxAdapter(child: _buildHeroBanner()),
        SliverToBoxAdapter(child: _buildTrendingRankings()),
        SliverToBoxAdapter(
          child: _buildSection(
            'Now Showing',
            'In Cinemas',
            _nowShowing,
            accentColor: _cDeepRose,
            icon: Icons.movie_creation_outlined,
          ),
        ),
        SliverToBoxAdapter(
          child: _buildSection(
            'Newly Released',
            'Fresh Picks',
            _newlyReleased,
            accentColor: _cGold,
            icon: Icons.new_releases_rounded,
          ),
        ),
        ..._buildGenreRows(),
        SliverToBoxAdapter(
          child: _buildSection(
            'Top Rated',
            'All Time Greats',
            _topRatedMovies,
            accentColor: _cAmber,
            icon: Icons.workspace_premium_rounded,
          ),
        ),
        SliverToBoxAdapter(
          child: _buildSection(
            'Popular Series',
            'TV Shows',
            _popularTVShows,
            accentColor: _cRose,
            icon: Icons.tv_rounded,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildTopHeader() {
    final top = MediaQuery.of(context).padding.top;
    final canPop = Navigator.canPop(context);
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 10),
      child: Row(
        children: [
          // Back — only when there's a route to pop to (e.g. Khent/Clair
          // arriving from the dashboard). Breyan lands on the cinema
          // directly, so popping would leave an empty stack and a white screen.
          if (canPop)
            _CinemaIconBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            )
          else
            const SizedBox(width: 40, height: 40),
          const Spacer(),
          // Title
          Column(
            children: [
              Text(
                'OUR CINEMA',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _cWhite,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _cDeepRose,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _cDeepRose.withValues(alpha: 0.7),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'BY EVERGLOW',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: _cMuted,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _cDeepRose,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _cDeepRose.withValues(alpha: 0.7),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Search
          _CinemaIconBtn(
            icon: Icons.search_rounded,
            onTap: () => _switchTab(1),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ HERO CAROUSEL â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildHeroBanner() {
    if (_trendingCarousel.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _carouselController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => _carouselPage = i),
            itemCount: _trendingCarousel.length,
            itemBuilder: (context, index) {
              final item = _trendingCarousel[index];
              return AnimatedBuilder(
                animation: _carouselController,
                builder: (context, child) {
                  double scale = 1.0;
                  if (_carouselController.position.haveDimensions) {
                    final diff = (_carouselController.page! - index).abs();
                    scale = (1 - (diff * 0.06)).clamp(0.92, 1.0);
                  } else {
                    scale = index == _carouselPage ? 1.0 : 0.94;
                  }
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: _buildHeroCard(item, index),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_trendingCarousel.length, (i) {
            final isActive = i == _carouselPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 22 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: isActive ? _cDeepRose : _cMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: _cDeepRose.withValues(alpha: 0.6),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHeroCard(MediaItem item, int index) {
    return GestureDetector(
      onTap: () => _showMediaDetails(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _cDeepRose.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Backdrop
                if (item.backdropPath.isNotEmpty)
                  Image.network(item.backdropPath, fit: BoxFit.cover)
                else if (item.posterPath.isNotEmpty)
                  Image.network(item.posterPath, fit: BoxFit.cover)
                else
                  Container(color: _cVelvet),

                // Cinematic gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        _cBlack.withValues(alpha: 0.7),
                        _cBlack.withValues(alpha: 0.97),
                      ],
                      stops: const [0.0, 0.35, 0.70, 1.0],
                    ),
                  ),
                ),

                // Left vignette
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        _cBlack.withValues(alpha: 0.35),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Content
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trending badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _cDeepRose,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_fire_department_rounded,
                                  color: Colors.white,
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '#${index + 1} TRENDING',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              item.mediaType.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Title
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: _cWhite,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (item.year.isNotEmpty) ...[
                            Text(
                              item.year,
                              style: GoogleFonts.outfit(
                                color: _cGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: _cMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          Text(
                            'Tap to explore',
                            style: GoogleFonts.outfit(
                              color: _cMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ TRENDING RANKINGS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildTrendingRankings() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChapterHeader('Trending', 'Rankings', Icons.emoji_events_rounded,
              accentColor: _cAmber),
          const SizedBox(height: 16),
          DefaultTabController(
            length: 2,
            child: Column(
              children: [
                // Tab Bar
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _cCard,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: _cRose.withValues(alpha: 0.1), width: 1),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_cDeepRose, Color(0xFF8E1444)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _cDeepRose.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(3),
                    labelColor: _cWhite,
                    unselectedLabelColor: _cMuted,
                    labelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.w500, fontSize: 13),
                    tabs: const [
                      Tab(text: '\u{1F30D}  Global'),
                      Tab(text: '\u{1F1F5}\u{1F1ED}  Philippines'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 370,
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildRankingList(_trendingGlobal),
                      _buildRankingList(_trendingPH),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingList(List<MediaItem> items) {
    if (items.isEmpty) {
      return _buildEmptyState('No rankings available');
    }

    final top10 = items.take(10).toList();
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: top10.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final item = top10[index];
        final rank = index + 1;
        return _RankingTile(
          item: item,
          rank: rank,
          onTap: () => _showMediaDetails(item),
        );
      },
    );
  }

  // â”€â”€â”€ SECTION ROW â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSection(
    String title,
    String subtitle,
    List<MediaItem> items, {
    Color accentColor = _cRose,
    IconData? icon,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 14),
          child: _buildChapterHeader(title, subtitle, icon,
              accentColor: accentColor),
        ),
        SizedBox(
          height: 205,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _PosterTile(
                item: items[index],
                onTap: () => _showMediaDetails(items[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildGenreRows() {
    final rows = <Widget>[];
    _genreLists.forEach((genreName, items) {
      final genreMeta = _featuredGenres.firstWhere(
        (g) => g['name'] == genreName,
        orElse: () => {
          'name': genreName,
          'icon': Icons.movie_filter_rounded,
          'color': _cRose,
        },
      );
      final icon = genreMeta['icon'] as IconData?;
      final color = genreMeta['color'] as Color? ?? _cRose;

      rows.add(
        SliverToBoxAdapter(
          child: _buildSection(
            genreName,
            genreMeta['type'] == 'tv' ? 'TV Series' : 'Movies',
            items,
            accentColor: color,
            icon: icon,
          ),
        ),
      );
    });
    return rows;
  }

  // â”€â”€â”€ CHAPTER HEADER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildChapterHeader(
    String title,
    String subtitle,
    IconData? icon, {
    Color accentColor = _cRose,
  }) {
    return Row(
      children: [
        // Vertical accent bar
        Container(
          width: 3,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accentColor, accentColor.withValues(alpha: 0.3)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _cWhite,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              subtitle.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: accentColor.withValues(alpha: 0.7),
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // 2. SEARCH TAB
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 14, 20, 0),
          child: Row(
            children: [
              _CinemaIconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => _switchTab(0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _cWhite,
                      ),
                    ),
                    Text(
                      'FIND YOUR NEXT OBSESSION',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _cMuted,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: _cCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _cRose.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: _cDeepRose.withValues(alpha: 0.08),
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
                hintText: 'Movies, TV shows...',
                hintStyle: GoogleFonts.outfit(
                    color: _cMuted, fontSize: 15),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(Icons.search_rounded,
                      color: _cDeepRose, size: 22),
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Results
        Expanded(
          child: _isSearching
              ? Center(
                  child: CircularProgressIndicator(
                    color: _cDeepRose,
                    strokeWidth: 2.5,
                  ),
                )
              : _searchResults.isEmpty
                  ? _buildSearchEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2 / 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return _SearchResultTile(
                          item: item,
                          onTap: () => _showMediaDetails(item),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchEmptyState() {
    return _buildEmptyState(
      _searchController.text.isEmpty
          ? 'Type to discover magic...'
          : 'No results found',
      icon: Icons.video_library_outlined,
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // 3. WATCHLIST TABS
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Color _watchedBadgeColor(String status) {
    switch (status) {
      case 'watched-clair':
        return const Color(0xFFE91E8C);
      case 'watched-khent':
        return const Color(0xFF1976D2);
      case 'watched-both':
      case 'watched':
      default:
        return const Color(0xFF2E7D32);
    }
  }

  Widget _buildWatchlistTab({required bool isWatchedTab}) {
    final list = isWatchedTab ? _watchedList : _wantToWatchList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 14, 20, 0),
          child: Row(
            children: [
              _CinemaIconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => _switchTab(0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isWatchedTab ? 'Watched' : 'Want to Watch',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _cWhite,
                      ),
                    ),
                    Text(
                      isWatchedTab ? 'OUR CATALOG' : 'THE WATCHLIST',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _cMuted,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
              // Count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _cDeepRose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: _cDeepRose.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${list.length}',
                  style: GoogleFonts.outfit(
                    color: _cDeepRose,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: list.isEmpty
              ? _buildEmptyState(
                  isWatchedTab
                      ? 'Your watched catalog is empty'
                      : 'Nothing queued yet',
                  icon: isWatchedTab
                      ? Icons.remove_red_eye_outlined
                      : Icons.bookmark_border_rounded,
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return _WatchlistTile(
                      item: item,
                      isWatched: isWatchedTab,
                      badgeColor: isWatchedTab
                          ? _watchedBadgeColor(item.status)
                          : _cAmber,
                      badgeLabel: isWatchedTab
                          ? item.watchedDisplay.toUpperCase()
                          : 'TO WATCH',
                      onTap: () => _showMediaDetails(item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // â”€â”€â”€ SHIMMER LOADING â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildShimmerHome() {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 14, 20, 20),
            child: _shimmerBox(height: 40, width: 160, radius: 8),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _shimmerBox(height: 320, radius: 24),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
            child: _shimmerBox(height: 280, radius: 16),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 14),
            child: _shimmerBox(height: 36, width: 200, radius: 8),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 205,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 6,
              itemBuilder: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _shimmerBox(width: 120, height: 205, radius: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _shimmerBox(
      {double? width, required double height, double radius = 12}) {
    return _ShimmerWidget(
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: _cCard,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  // â”€â”€â”€ EMPTY STATE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildEmptyState(String message,
      {IconData icon = Icons.video_library_outlined}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _cCard,
              shape: BoxShape.circle,
              border: Border.all(color: _cRose.withValues(alpha: 0.1)),
            ),
            child: Icon(icon, size: 36, color: _cMuted),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: _cMuted,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // BOTTOM NAVIGATION
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildBottomNavBar() {
    final items = [
      _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.search_rounded, activeIcon: Icons.search_rounded, label: 'Search'),
      _NavItem(icon: Icons.bookmark_border_rounded, activeIcon: Icons.bookmark_rounded, label: 'Queue'),
      _NavItem(icon: Icons.remove_red_eye_outlined, activeIcon: Icons.remove_red_eye_rounded, label: 'Watched'),
    ];

    return Container(
      margin: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _cRose.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: _cDeepRose.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final isActive = _currentIndex == i;
            final navItem = items[i];
            return _buildNavItem(navItem, i, isActive);
          }),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem navItem, int index, bool isActive) {
    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _cDeepRose.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? navItem.activeIcon : navItem.icon,
                key: ValueKey('$index-$isActive'),
                size: 22,
                color: isActive ? _cDeepRose : _cMuted,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                navItem.label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _cDeepRose,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// EXTRACTED WIDGETS
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

/// Circular icon button for Cinema header
class _CinemaIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CinemaIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _cCard,
          shape: BoxShape.circle,
          border: Border.all(color: _cRose.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: _cRose, size: 18),
      ),
    );
  }
}

/// Poster card in horizontal row
class _PosterTile extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _PosterTile({required this.item, required this.onTap});

  @override
  State<_PosterTile> createState() => _PosterTileState();
}

class _PosterTileState extends State<_PosterTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          width: 120,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.item.posterPath.isNotEmpty
                            ? Image.network(widget.item.posterPath,
                                fit: BoxFit.cover)
                            : Container(
                                color: _cCard,
                                child: const Center(
                                  child: Icon(
                                    Icons.movie_creation_outlined,
                                    color: _cMuted,
                                    size: 28,
                                  ),
                                ),
                              ),
                        // Bottom shimmer overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.7),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: _cWhite,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                widget.item.year.isNotEmpty
                    ? widget.item.year
                    : (widget.item.mediaType == 'movie' ? 'Movie' : 'Series'),
                style: GoogleFonts.outfit(
                  color: _cMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ranking list tile
class _RankingTile extends StatefulWidget {
  final MediaItem item;
  final int rank;
  final VoidCallback onTap;

  const _RankingTile(
      {required this.item, required this.rank, required this.onTap});

  @override
  State<_RankingTile> createState() => _RankingTileState();
}

class _RankingTileState extends State<_RankingTile> {
  bool _pressed = false;

  Color get _rankColor {
    switch (widget.rank) {
      case 1:
        return const Color(0xFFF0A500);
      case 2:
        return const Color(0xFFB0BEC5);
      case 3:
        return const Color(0xFFBF8040);
      default:
        return _cMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTop3 = widget.rank <= 3;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _pressed
              ? _cCard.withValues(alpha: 0.8)
              : _cCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isTop3
                ? _rankColor.withValues(alpha: 0.3)
                : _cRose.withValues(alpha: 0.07),
            width: isTop3 ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 38,
              child: isTop3
                  ? Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _rankColor.withValues(alpha: 0.15),
                        border: Border.all(
                            color: _rankColor.withValues(alpha: 0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _rankColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${widget.rank}',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _rankColor,
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        '${widget.rank}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _cMuted,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            // Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 62,
                child: widget.item.posterPath.isNotEmpty
                    ? Image.network(widget.item.posterPath, fit: BoxFit.cover)
                    : Container(color: _cCard),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: _cWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        widget.item.year.isNotEmpty
                            ? widget.item.year
                            : 'â€”',
                        style: GoogleFonts.outfit(
                          color: _cGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _cDeepRose.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.item.mediaType.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: _cDeepRose,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _cMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Search result grid tile
class _SearchResultTile extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _SearchResultTile({required this.item, required this.onTap});

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 130),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.item.posterPath.isNotEmpty
                    ? Image.network(widget.item.posterPath, fit: BoxFit.cover)
                    : Container(
                        color: _cCard,
                        child: const Center(
                          child: Icon(
                            Icons.movie_creation_outlined,
                            color: _cMuted,
                            size: 28,
                          ),
                        ),
                      ),
                // Gradient + title
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      widget.item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: _cWhite,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
                // Media type badge
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: _cDeepRose.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.item.mediaType == 'movie' ? 'M' : 'TV',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
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
  }
}

/// Watchlist grid tile
class _WatchlistTile extends StatefulWidget {
  final MediaItem item;
  final bool isWatched;
  final Color badgeColor;
  final String badgeLabel;
  final VoidCallback onTap;

  const _WatchlistTile({
    required this.item,
    required this.isWatched,
    required this.badgeColor,
    required this.badgeLabel,
    required this.onTap,
  });

  @override
  State<_WatchlistTile> createState() => _WatchlistTileState();
}

class _WatchlistTileState extends State<_WatchlistTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 130),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Poster
                widget.item.posterPath.isNotEmpty
                    ? Image.network(widget.item.posterPath, fit: BoxFit.cover)
                    : Container(
                        color: _cCard,
                        child: const Center(
                          child: Icon(
                            Icons.movie_rounded,
                            color: _cMuted,
                            size: 36,
                          ),
                        ),
                      ),

                // Bottom gradient + title
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.9),
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        if (widget.item.year.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.item.year,
                            style: GoogleFonts.outfit(
                              color: _cGold.withValues(alpha: 0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Status badge
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.badgeColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: widget.badgeColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.badgeLabel,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
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
  }
}

/// Shimmer animation widget
class _ShimmerWidget extends StatefulWidget {
  final Widget child;
  const _ShimmerWidget({required this.child});

  @override
  State<_ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<_ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: false);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.linear);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.5, 0),
              end: const Alignment(1.5, 0),
              colors: const [
                _cCard,
                Color(0xFF2A1F3A),
                _cCard,
              ],
              stops: [
                _anim.value - 0.3,
                _anim.value,
                _anim.value + 0.3,
              ].map((v) => v.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

