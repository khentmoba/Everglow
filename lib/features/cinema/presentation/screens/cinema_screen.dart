import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/features/cinema/presentation/screens/video_player_screen.dart';

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
  List<MediaItem> _trendingToday = [];
  List<MediaItem> _topRatedMovies = [];
  List<MediaItem> _popularTVShows = [];
  MediaItem? _heroBannerItem;
  bool _isLoadingHome = true;

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
    
    final trending = await _tmdbService.fetchTrendingToday();
    final topRated = await _tmdbService.fetchTopRatedMovies();
    final popularTV = await _tmdbService.fetchPopularTVShows();

    if (mounted) {
      setState(() {
        _trendingToday = trending;
        _topRatedMovies = topRated;
        _popularTVShows = popularTV;

        // Set the Hero Banner to the top trending item
        if (_trendingToday.isNotEmpty) {
          _heroBannerItem = _trendingToday.first;
        }
        _isLoadingHome = false;
      });
    }
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
        // Hero Banner
        SliverToBoxAdapter(
          child: _buildHeroBanner(),
        ),

        // Carousel Rows
        SliverPadding(
          padding: const EdgeInsets.only(top: 20, bottom: 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHorizontalRow('Trending Today', _trendingToday),
              const SizedBox(height: 24),
              _buildHorizontalRow('Top Rated Movies', _topRatedMovies),
              const SizedBox(height: 24),
              _buildHorizontalRow('Popular TV Shows', _popularTVShows),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBanner() {
    if (_heroBannerItem == null) return const SizedBox.shrink();

    return Container(
      height: 480,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Banner Backdrop Image
          if (_heroBannerItem!.posterPath.isNotEmpty)
            Image.network(
              _heroBannerItem!.posterPath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            )
          else
            Container(color: AppTheme.velvet),

          // Shadow and gradient overlays
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppTheme.twilight,
                  AppTheme.twilight.withOpacity(0.4),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Top Header (AppName and Back Button)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 20,
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
                const SizedBox(width: 48), // Spacer to balance back button
              ],
            ),
          ),

          // Bottom Content Overlay
          Positioned(
            bottom: 10,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  _heroBannerItem!.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.petalWhite,
                    shadows: [
                      const Shadow(blurRadius: 10, color: Colors.black54),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Rating & Type Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, color: AppTheme.warmAmber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      'Trending',
                      style: GoogleFonts.outfit(
                        color: AppTheme.blushGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.deepRose.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _heroBannerItem!.mediaType.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: AppTheme.petalWhite,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Play Button
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_heroBannerItem!.mediaType == 'movie') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoPlayerScreen(
                                tmdbId: _heroBannerItem!.tmdbId,
                                mediaType: 'movie',
                                title: _heroBannerItem!.title,
                              ),
                            ),
                          );
                        } else {
                          _showMediaDetails(_heroBannerItem!);
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded, color: AppTheme.petalWhite),
                      label: Text(
                        'Play',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.petalWhite),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepRose,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),

                    // Add to Watchlist
                    OutlinedButton.icon(
                      onPressed: () => _tmdbService.saveToWatchList(_heroBannerItem!, 'to-watch'),
                      icon: const Icon(Icons.add, color: AppTheme.roseQuartz),
                      label: Text(
                        'Watchlist',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.roseQuartz),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.roseQuartz),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalRow(String title, List<MediaItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            title,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.roseQuartz,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 180,
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
                  child: AspectRatio(
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
                            ? Image.network(
                                item.posterPath,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: AppTheme.velvet,
                                child: const Center(
                                  child: Icon(Icons.movie_creation_outlined, color: AppTheme.roseQuartz),
                                ),
                              ),
                      ),
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
                            child: item.posterPath.isNotEmpty
                                ? Image.network(item.posterPath, fit: BoxFit.cover)
                                : Container(
                                    color: AppTheme.velvet,
                                    child: const Center(
                                      child: Icon(Icons.movie_creation_outlined, color: AppTheme.roseQuartz),
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            isWatchedTab ? 'Watched Catalog 🍿' : 'Want to Watch List ⏳',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.roseQuartz,
            ),
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
                        
                        // Status Badge Tag at top right (for Watched: shows who watched it)
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
