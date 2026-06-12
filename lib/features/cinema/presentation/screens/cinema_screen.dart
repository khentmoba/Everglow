import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';

class CinemaScreen extends StatefulWidget {
  const CinemaScreen({Key? key}) : super(key: key);

  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen> {
  final TMDBService _tmdbService = TMDBService();
  int _currentIndex = 0;

  // Stream subscription for watchlists
  StreamSubscription<List<MediaItem>>? _watchlistSubscription;

  // Watchlist lists
  List<MediaItem> _watchlist = [];
  List<MediaItem> _wantToWatchList = [];
  List<MediaItem> _watchedList = [];

  // Home Lists
  List<MediaItem> _trendingCarousel = [];
  List<MediaItem> _trendingGlobal = [];
  List<MediaItem> _trendingPH = [];
  List<MediaItem> _topRatedMovies = [];
  List<MediaItem> _popularTVShows = [];
  List<MediaItem> _nowShowing = [];
  List<MediaItem> _newlyReleased = [];

  // Genre Lists (Map: genreName -> items)
  final Map<String, List<MediaItem>> _genreLists = {};
  final Map<int, String> _movieGenres = {};
  final Map<int, String> _tvGenres = {};

  bool _isLoadingHome = true;
  final PageController _carouselController = PageController(viewportFraction: 0.92);
  int _carouselPage = 0;
  Timer? _carouselTimer;

  // Selected featured genre to display
  static const List<Map<String, dynamic>> _featuredGenres = [
    {'id': 28, 'name': 'Action', 'type': 'movie', 'icon': '🔥'},
    {'id': 35, 'name': 'Comedy', 'type': 'movie', 'icon': '😂'},
    {'id': 27, 'name': 'Horror', 'type': 'movie', 'icon': '👻'},
    {'id': 10749, 'name': 'Romance', 'type': 'movie', 'icon': '💕'},
    {'id': 18, 'name': 'Drama', 'type': 'movie', 'icon': '🎭'},
    {'id': 16, 'name': 'Animation', 'type': 'movie', 'icon': '✨'},
    {'id': 9648, 'name': 'Mystery', 'type': 'movie', 'icon': '🔍'},
    {'id': 878, 'name': 'Sci-Fi', 'type': 'movie', 'icon': '🚀'},
    {'id': 10765, 'name': 'Sci-Fi & Fantasy', 'type': 'tv', 'icon': '🌌'},
    {'id': 10759, 'name': 'Action & Adventure', 'type': 'tv', 'icon': '⚔️'},
  ];

  // Search variables
  final TextEditingController _searchController = TextEditingController();
  List<MediaItem> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadCachedWatchList();
    _subscribeToWatchList();
    _fetchHomeData();
  }

  @override
  void dispose() {
    _watchlistSubscription?.cancel();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _carouselController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  // Load from local storage / shared_preferences
  Future<void> _loadCachedWatchList() async {
    final cached = await _tmdbService.getCachedWatchList();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _watchlist = cached;
        _splitWatchlists();
      });
    }
  }

  // Subscribe to real-time updates from Firestore
  void _subscribeToWatchList() {
    _watchlistSubscription = _tmdbService.getWatchListStream().listen((items) {
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

  // Fetch TMDB sections
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
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  // Handle Search Input
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

  // Show detailed info bottom sheet
  void _showMediaDetails(MediaItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpisodeDrawer(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.twilight,
      body: SafeArea(
        top: false,
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

  // 1. HOME TAB
  Widget _buildHomeTab() {
    if (_isLoadingHome) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.deepRose));
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Top App Bar (just title)
        SliverToBoxAdapter(child: _buildTopHeader()),

        // Trending Carousel (at the very top)
        SliverToBoxAdapter(child: _buildTrendingCarousel()),

        // Two trending rankings: Global and Philippines
        SliverToBoxAdapter(child: _buildTrendingRankings()),

        // Now Showing in Cinema
        SliverToBoxAdapter(child: _buildHorizontalRow('🎬 Now Showing in Cinema', _nowShowing, showYear: true)),

        // Newly Released
        SliverToBoxAdapter(child: _buildHorizontalRow('🆕 Newly Released', _newlyReleased, showYear: true)),

        // Genre Lists
        ..._buildGenreRows(),

        // Top Rated Movies
        SliverToBoxAdapter(child: _buildHorizontalRow('Top Rated Movies', _topRatedMovies, showYear: true)),

        // Popular TV Shows
        SliverToBoxAdapter(child: _buildHorizontalRow('Popular TV Shows', _popularTVShows, showYear: true)),

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.roseQuartz),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'OUR CINEMA',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.roseQuartz,
              letterSpacing: 2,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.roseQuartz),
            onPressed: () => setState(() => _currentIndex = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingCarousel() {
    if (_trendingCarousel.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: AppTheme.warmAmber, size: 22),
              const SizedBox(width: 6),
              Text(
                'Trending This Week',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.roseQuartz,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _carouselController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => _carouselPage = i),
            itemCount: _trendingCarousel.length,
            itemBuilder: (context, index) {
              final item = _trendingCarousel[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () => _showMediaDetails(item),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (item.backdropPath.isNotEmpty)
                          Image.network(item.backdropPath, fit: BoxFit.cover)
                        else if (item.posterPath.isNotEmpty)
                          Image.network(item.posterPath, fit: BoxFit.cover)
                        else
                          Container(color: AppTheme.velvet),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppTheme.twilight.withOpacity(0.95),
                                AppTheme.twilight.withOpacity(0.3),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.deepRose,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#${index + 1} TRENDING',
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.petalWhite,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.petalWhite,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    item.year.isNotEmpty ? item.year : '—',
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.blushGold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppTheme.petalWhite.withOpacity(0.4)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.mediaType.toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.petalWhite,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
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
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Carousel indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_trendingCarousel.length, (i) {
            final isActive = i == _carouselPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? AppTheme.deepRose : AppTheme.roseQuartz.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTrendingRankings() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppTheme.warmAmber, size: 22),
                const SizedBox(width: 6),
                Text(
                  'Trending Rankings',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.roseQuartz,
                  ),
                ),
              ],
            ),
          ),
          // Tab switcher Global / Philippines
          DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.velvet,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.roseQuartz.withOpacity(0.2)),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: AppTheme.deepRose,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: AppTheme.petalWhite,
                    unselectedLabelColor: AppTheme.roseQuartz,
                    labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                    tabs: const [
                      Tab(text: '🌍 GLOBAL'),
                      Tab(text: '🇵🇭 PHILIPPINES'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 320,
                  child: TabBarView(
                    children: [
                      _buildRankingList(_trendingGlobal, 'Global'),
                      _buildRankingList(_trendingPH, 'Philippines'),
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

  Widget _buildRankingList(List<MediaItem> items, String region) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No rankings available',
          style: GoogleFonts.outfit(color: AppTheme.petalWhite.withOpacity(0.5)),
        ),
      );
    }

    final top10 = items.take(10).toList();

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: top10.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = top10[index];
        final rank = index + 1;
        return GestureDetector(
          onTap: () => _showMediaDetails(item),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.velvet.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: rank <= 3
                    ? AppTheme.warmAmber.withOpacity(0.4)
                    : AppTheme.roseQuartz.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rank == 1
                        ? AppTheme.warmAmber
                        : rank == 2
                            ? AppTheme.roseQuartz
                            : rank == 3
                                ? AppTheme.deepRose.withOpacity(0.7)
                                : AppTheme.moonlight.withOpacity(0.2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$rank',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: rank <= 3 ? AppTheme.twilight : AppTheme.petalWhite,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 45,
                    height: 65,
                    child: item.posterPath.isNotEmpty
                        ? Image.network(item.posterPath, fit: BoxFit.cover)
                        : Container(color: AppTheme.velvet),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: AppTheme.petalWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            item.year.isNotEmpty ? item.year : '—',
                            style: GoogleFonts.outfit(
                              color: AppTheme.blushGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.petalWhite.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              item.mediaType.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: AppTheme.petalWhite.withOpacity(0.7),
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
                const Icon(Icons.chevron_right_rounded, color: AppTheme.roseQuartz, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildGenreRows() {
    final rows = <Widget>[];
    _genreLists.forEach((genreName, items) {
      final genreMeta = _featuredGenres.firstWhere(
        (g) => g['name'] == genreName,
        orElse: () => {'name': genreName, 'icon': '🎬'},
      );
      final icon = genreMeta['icon'] ?? '🎬';
      rows.add(
        SliverToBoxAdapter(
          child: _buildHorizontalRow(
            '$icon $genreName',
            items,
            showYear: true,
          ),
        ),
      );
    });
    return rows;
  }

  Widget _buildHorizontalRow(String title, List<MediaItem> items, {bool showYear = false}) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            title,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.roseQuartz,
            ),
          ),
        ),
        SizedBox(
          height: showYear ? 210 : 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () => _showMediaDetails(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(
                    width: showYear ? 120 : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 2 / 3,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.roseQuartz.withOpacity(0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item.posterPath.isNotEmpty
                                  ? Image.network(item.posterPath, fit: BoxFit.cover)
                                  : Container(
                                      color: AppTheme.velvet,
                                      child: const Center(
                                        child: Icon(Icons.movie_creation_outlined, color: AppTheme.roseQuartz),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        if (showYear) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: AppTheme.petalWhite,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            item.year.isNotEmpty ? item.year : (item.mediaType == 'movie' ? 'Movie' : 'Series'),
                            style: GoogleFonts.outfit(
                              color: AppTheme.blushGold.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 2. SEARCH TAB
  Widget _buildSearchTab() {
    return Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.roseQuartz),
                onPressed: () => setState(() => _currentIndex = 0),
              ),
              const SizedBox(width: 4),
              Text(
                'Search',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.roseQuartz,
                ),
              ),
            ],
          ),
        ),

        // Search Input Bar
        Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.velvet,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.roseQuartz.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: GoogleFonts.outfit(color: AppTheme.petalWhite),
              decoration: InputDecoration(
                hintText: 'Search for a movie or TV show...',
                hintStyle: GoogleFonts.outfit(color: AppTheme.petalWhite.withOpacity(0.4)),
                prefixIcon: const Icon(Icons.search, color: AppTheme.roseQuartz),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),

        // Search Results List / Grid
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator(color: AppTheme.deepRose))
              : _searchResults.isEmpty
                  ? _buildSearchEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2 / 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return GestureDetector(
                          onTap: () => _showMediaDetails(item),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                item.posterPath.isNotEmpty
                                    ? Image.network(item.posterPath, fit: BoxFit.cover)
                                    : Container(
                                        color: AppTheme.velvet,
                                        child: const Center(
                                          child: Icon(Icons.movie_creation_outlined, color: AppTheme.roseQuartz),
                                        ),
                                      ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [Colors.black87, Colors.transparent],
                                      ),
                                    ),
                                    child: Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.petalWhite,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_library_outlined, size: 60, color: AppTheme.roseQuartz),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty ? 'Type to discover magic...' : 'No results found',
            style: GoogleFonts.outfit(color: AppTheme.roseQuartz.withOpacity(0.6), fontSize: 16),
          ),
        ],
      ),
    );
  }

  // 3. WANT TO WATCH / WATCHED TABS
  Widget _buildWatchlistTab({required bool isWatchedTab}) {
    final list = isWatchedTab ? _watchedList : _wantToWatchList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.roseQuartz),
                onPressed: () => setState(() => _currentIndex = 0),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  isWatchedTab ? 'Watched Catalog 🍿' : 'Want to Watch List ⏳',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.roseQuartz,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isWatchedTab ? Icons.remove_red_eye_outlined : Icons.bookmark_border_rounded,
                        size: 60,
                        color: AppTheme.roseQuartz.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isWatchedTab ? 'No movies in Watched Catalog' : 'No movies in Want to Watch list',
                        style: GoogleFonts.outfit(color: AppTheme.petalWhite.withOpacity(0.5)),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          onTap: () => _showMediaDetails(item),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: item.posterPath.isNotEmpty
                                ? Image.network(item.posterPath, fit: BoxFit.cover)
                                : Container(
                                    color: AppTheme.velvet,
                                    child: const Center(
                                      child: Icon(Icons.movie_rounded, color: AppTheme.roseQuartz),
                                    ),
                                  ),
                          ),
                        ),

                        // Status Badge Tag at top right
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isWatchedTab ? Colors.green.withOpacity(0.9) : AppTheme.warmAmber.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: Text(
                              isWatchedTab ? item.watchedDisplay.toUpperCase() : 'TO WATCH',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  // BOTTOM NAVIGATION BAR
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.velvet,
        border: Border(
          top: BorderSide(color: AppTheme.roseQuartz.withOpacity(0.1), width: 1.0),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.deepRose,
        unselectedItemColor: AppTheme.roseQuartz.withOpacity(0.5),
        selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline_rounded),
            activeIcon: Icon(Icons.bookmark_rounded),
            label: 'Want to Watch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.remove_red_eye_outlined),
            activeIcon: Icon(Icons.remove_red_eye),
            label: 'Watched',
          ),
        ],
      ),
    );
  }
}
