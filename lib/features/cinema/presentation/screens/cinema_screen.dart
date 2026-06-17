import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/features/cinema/presentation/widgets/trailer_player.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/shared/widgets/adblocker_gate.dart';
import 'package:everglow/shared/widgets/shelf/atmospheric_backdrop.dart';
import 'package:everglow/shared/widgets/shelf/scroll_edge_fade.dart';
import 'package:everglow/shared/widgets/shelf/shelf_icon_button.dart';
import 'package:everglow/shared/widgets/shelf/shelf_poster_card.dart';
import 'package:everglow/shared/widgets/shelf/shelf_section_header.dart';
import 'package:everglow/shared/widgets/shelf/shelf_empty_state.dart';
import 'package:everglow/shared/widgets/shelf/shimmer_box.dart';
import 'package:everglow/shared/widgets/shelf/shelf_pill_bottom_nav.dart';
import 'package:everglow/shared/widgets/shelf/staggered_entrance.dart';
import 'anime_screen.dart';

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

  // Carousel trailer states
  String? _carouselTrailerKey;
  bool _isPlayingCarouselTrailer = false;
  final Map<int, String?> _carouselTrailerKeysCache = {};

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
    _prefetchCarouselTrailers();
    // Kick off the trailer for the first slide immediately so the user
    // lands on a playing hero, not a static backdrop.
    _startTrailerForPage(0);
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

  // Auto-rotate duration. Long enough for the trailer hook to register
  // ("so the user can actually watch what it's all about") but short enough
  // to keep the carousel feeling alive.
  static const Duration _carouselHoldDuration = Duration(seconds: 18);

  void _onCarouselPageChanged(int index) {
    setState(() {
      _carouselPage = index;
      _isPlayingCarouselTrailer = false;
      _carouselTrailerKey = null;
    });

    // Play trailer immediately — no artificial delay. If the key is already
    // cached (via _prefetchCarouselTrailers) it shows instantly; otherwise
    // we fetch in the background and update state when ready.
    _startTrailerForPage(index);
    // Reset the rotate timer so the user gets a full hold on the slide they
    // just landed on.
    _restartCarouselAutoPlay();
  }

  void _startTrailerForPage(int index) {
    if (index < 0 || index >= _trendingCarousel.length) return;
    final item = _trendingCarousel[index];

    String? key;
    if (_carouselTrailerKeysCache.containsKey(item.tmdbId)) {
      key = _carouselTrailerKeysCache[item.tmdbId];
      if (key != null && _carouselPage == index && mounted) {
        setState(() {
          _carouselTrailerKey = key;
          _isPlayingCarouselTrailer = true;
        });
      }
      return;
    }

    _tmdbService
        .fetchTrailerKey(item.tmdbId, item.mediaType)
        .then((fetchedKey) {
      _carouselTrailerKeysCache[item.tmdbId] = fetchedKey;
      if (_carouselPage == index && mounted && fetchedKey != null) {
        setState(() {
          _carouselTrailerKey = fetchedKey;
          _isPlayingCarouselTrailer = true;
        });
      }
    });
  }

  // Pre-warm trailer keys for every hero slide so the first one (and any
  // swipe) plays instantly, with no spinner or fade-in.
  void _prefetchCarouselTrailers() {
    for (var i = 0; i < _trendingCarousel.length; i++) {
      final item = _trendingCarousel[i];
      if (_carouselTrailerKeysCache.containsKey(item.tmdbId)) continue;
      _tmdbService
          .fetchTrailerKey(item.tmdbId, item.mediaType)
          .then((key) {
        _carouselTrailerKeysCache[item.tmdbId] = key;
        // If the first slide resolves after the carousel has mounted, light
        // it up without waiting for a swipe.
        if (i == _carouselPage && mounted && key != null && !_isPlayingCarouselTrailer) {
          setState(() {
            _carouselTrailerKey = key;
            _isPlayingCarouselTrailer = true;
          });
        }
      });
    }
  }

  void _startCarouselAutoPlay() {
    _restartCarouselAutoPlay();
  }

  // Re-arms the hold timer. Called on carousel start and on every manual
  // swipe so the user always gets a full 18s on the slide they landed on.
  void _restartCarouselAutoPlay() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer(_carouselHoldDuration, () {
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
      body: Stack(
        children: [
          // Atmospheric backdrop sits behind everything in the
          // scaffold so the page never reads as a flat black void.
          const ShelfAtmosphericBackdrop(),
          SafeArea(
            top: false,
            bottom: false,
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeTab(),
                _buildSearchTab(),
                _buildLibraryTab(),
              ],
            ),
          ),
        ],
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

    return RefreshIndicator(
      color: _cDeepRose,
      backgroundColor: _cCard,
      onRefresh: _fetchHomeData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 0,
              child: _buildTopHeader(),
            ),
          ),
          SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 1,
              child: _buildHeroBanner(),
            ),
          ),
          if (_watchedList.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: StaggeredEntrance(
                index: 2,
                child: _buildContinueWatching(),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 3,
              child: _buildTrendingRankings(),
            ),
          ),
          SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 4,
              child: _buildGenericSection(
                eyebrow: 'In Cinemas',
                title: 'Now Showing',
                items: _nowShowing,
                accentColor: _cDeepRose,
                icon: Icons.movie_creation_outlined,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 5,
              child: _buildGenericSection(
                eyebrow: 'Fresh Picks',
                title: 'Newly Released',
                items: _newlyReleased,
                accentColor: _cGold,
                icon: Icons.new_releases_rounded,
              ),
            ),
          ),
          ..._buildGenreRows(),
          SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 8,
              child: _buildGenericSection(
                eyebrow: 'All Time Greats',
                title: 'Top Rated',
                items: _topRatedMovies,
                accentColor: _cAmber,
                icon: Icons.workspace_premium_rounded,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 9,
              child: _buildGenericSection(
                eyebrow: 'TV Shows',
                title: 'Popular Series',
                items: _popularTVShows,
                accentColor: _cRose,
                icon: Icons.tv_rounded,
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildContinueWatching() {
    // Show the 8 most recent watched items in a wide horizontal rail
    // so users can jump back into something they already started.
    final recent = _watchedList.take(8).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShelfSectionHeader(
            eyebrow: 'Pick Up Where You Left Off',
            title: 'Continue Watching',
            icon: Icons.play_circle_outline_rounded,
            accent: _cDeepRose,
            count: 8,
            countLabel: 'titles',
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final item = recent[i];
                return SizedBox(
                  width: 220,
                  child: GestureDetector(
                    onTap: () => _showMediaDetails(item),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.black.withValues(alpha: 0.05),
                          ],
                        ),
                        border: Border.all(
                          color: _cDeepRose.withValues(alpha: 0.25),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (item.backdropPath.isNotEmpty)
                              Image.network(
                                item.backdropPath,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    Container(color: _cCard),
                              )
                            else if (item.posterPath.isNotEmpty)
                              Image.network(
                                item.posterPath,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    Container(color: _cCard),
                              )
                            else
                              Container(color: _cCard),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.85),
                                    Colors.black.withValues(alpha: 0.2),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              top: 0,
                              bottom: 0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _cDeepRose,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'WATCHED',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.cormorantGaramond(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _cWhite,
                                      height: 1.15,
                                    ),
                                  ),
                                  if (item.year.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.year,
                                      style: GoogleFonts.outfit(
                                        color: _cGold,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _cDeepRose
                                      .withValues(alpha: 0.9),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _cDeepRose
                                          .withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.replay_rounded,
                                  color: Colors.white,
                                  size: 18,
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
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    final top = MediaQuery.of(context).padding.top;
    final canPop = Navigator.canPop(context);
    final isCouple = context.watch<AuthService>().isCoupleUser;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 10),
      child: Row(
        children: [
          // Couple → back button; cinema-only → everglow anime link
          if (isCouple && canPop)
            ShelfIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              semanticLabel: 'Back',
              tooltip: 'Back',
              onTap: () => Navigator.pop(context),
            )
          else if (!isCouple)
            ShelfIconButton(
              icon: Icons.auto_awesome_rounded,
              semanticLabel: 'Open Everglow Anime',
              tooltip: 'Everglow Anime',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdblockerGate(child: AnimeScreen()),
                ),
              ),
            )
          else
            const SizedBox(width: 44, height: 44),
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
          const SizedBox(width: 44, height: 44),
          const SizedBox(width: 8),
          // Search
          ShelfIconButton(
            icon: Icons.search_rounded,
            semanticLabel: 'Search',
            tooltip: 'Search movies and shows',
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
            onPageChanged: _onCarouselPageChanged,
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
                // Backdrop / Live Trailer background
                index == _carouselPage && _isPlayingCarouselTrailer && _carouselTrailerKey != null
                    ? TrailerPlayer(
                        videoKey: _carouselTrailerKey!,
                        muted: true,
                        autoplay: true,
                        loop: true,
                      )
                    : (item.backdropPath.isNotEmpty
                        ? Image.network(item.backdropPath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _cVelvet))
                        : (item.posterPath.isNotEmpty
                            ? Image.network(item.posterPath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _cVelvet))
                            : Container(color: _cVelvet))),

                // Cinematic gradient — strengthened so the title, year, and
                // badges stay legible no matter what frame the trailer is on.
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        _cBlack.withValues(alpha: 0.15),
                        _cBlack.withValues(alpha: 0.78),
                        _cBlack.withValues(alpha: 0.98),
                      ],
                      stops: const [0.0, 0.28, 0.62, 1.0],
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
                        _cBlack.withValues(alpha: 0.45),
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
          const ShelfSectionHeader(
            eyebrow: 'This Week',
            title: 'Trending Rankings',
            icon: Icons.emoji_events_rounded,
            accent: _cAmber,
            count: 10,
            countLabel: 'titles',
          ),
          const SizedBox(height: 16),
          DefaultTabController(
            length: 2,
            child: Column(
              children: [
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
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.public_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Global'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Philippines'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 400,
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
      return const ShelfEmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'No rankings available',
        subtitle: 'Check back soon — the chart refreshes weekly.',
      );
    }

    final top10 = items.take(10).toList();
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
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

  Widget _buildGenericSection({
    required String title,
    required String eyebrow,
    required List<MediaItem> items,
    required Color accentColor,
    IconData? icon,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 14),
          child: ShelfSectionHeader(
            eyebrow: eyebrow,
            title: title,
            icon: icon,
            accent: accentColor,
            count: items.length,
            countLabel: items.length == 1 ? 'title' : 'titles',
          ),
        ),
        ScrollEdgeFade(
          fadeColor: _cBlack,
          child: SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              clipBehavior: Clip.none,
              itemCount: items.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 130,
                    child: ShelfPosterCard(
                      imageUrl: items[index].posterPath,
                      title: items[index].title,
                      subtitle: items[index].year.isNotEmpty
                          ? items[index].year
                          : null,
                      badge: items[index].mediaType == 'movie'
                          ? 'MOVIE'
                          : 'TV',
                      badgeIcon: items[index].mediaType == 'movie'
                          ? Icons.movie_outlined
                          : Icons.tv_outlined,
                      onTap: () => _showMediaDetails(items[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildGenreRows() {
    final rows = <Widget>[];
    var i = 6;
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
          child: StaggeredEntrance(
            index: i,
            child: _buildGenericSection(
              title: genreName,
              eyebrow:
                  genreMeta['type'] == 'tv' ? 'TV Series' : 'Movies',
              items: items,
              accentColor: color,
              icon: icon,
            ),
          ),
        ),
      );
      i++;
    });
    return rows;
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
              ShelfIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                semanticLabel: 'Back to Home',
                tooltip: 'Back to Home',
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
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
                          subtitle: item.year.isNotEmpty
                              ? item.year
                              : null,
                          badge: item.mediaType == 'movie'
                              ? 'MOVIE'
                              : 'TV',
                          badgeIcon: item.mediaType == 'movie'
                              ? Icons.movie_outlined
                              : Icons.tv_outlined,
                          onTap: () => _showMediaDetails(item),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchEmptyState() {
    return ShelfEmptyState(
      icon: _searchController.text.isEmpty
          ? Icons.travel_explore_rounded
          : Icons.search_off_rounded,
      title: _searchController.text.isEmpty
          ? 'Type to discover magic'
          : 'No results found',
      subtitle: _searchController.text.isEmpty
          ? 'Search any movie or TV show to add it to your queue or mark it as watched.'
          : 'Try a different keyword — the catalogue is huge.',
      accent: _cDeepRose,
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // 3. LIBRARY TAB
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildLibraryTab() {
    final currentlyWatching =
        _watchlist.where((i) => i.isCurrentlyWatching).toList();
    final wantToWatch = _watchlist.where((i) => i.isToWatch).toList();
    final watched = _watchlist.where((i) => i.isWatched).toList();

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
                    colors: [_cDeepRose, _cAmber],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _cDeepRose.withValues(alpha: 0.3),
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
                'Your cinema library is empty',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _cWhite,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search for movies or shows and add them to your library.\nItems you\'re watching or have watched will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: _cMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => _switchTab(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _cDeepRose.withValues(alpha: 0.3),
                        _cDeepRose.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _cDeepRose.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_rounded,
                          color: _cWhite, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Search Movies & TV',
                        style: GoogleFonts.outfit(
                          color: _cWhite,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 14, 20, 0),
          child: Row(
            children: [
              ShelfIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                semanticLabel: 'Back to Home',
                tooltip: 'Back to Home',
                onTap: () => _switchTab(0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Our Library',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _cWhite,
                      ),
                    ),
                    Text(
                      'CINEMA COLLECTION',
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
        const SizedBox(height: 8),
        // Currently Watching
        if (currentlyWatching.isNotEmpty) ...[
          _librarySectionHeader(
            'Currently Watching',
            'RESUME PLAYING',
            Icons.play_circle_filled_rounded,
            const Color(0xFFFF6D00),
            currentlyWatching.length,
          ),
          _libraryGrid(currentlyWatching),
        ],
        // Want to Watch
        if (wantToWatch.isNotEmpty) ...[
          _librarySectionHeader(
            'Want to Watch',
            'YOUR QUEUE',
            Icons.bookmark_rounded,
            _cGold,
            wantToWatch.length,
          ),
          _libraryGrid(wantToWatch, badgeColor: _cGold),
        ],
        // Watched
        if (watched.isNotEmpty) ...[
          _librarySectionHeader(
            'Watched',
            'COMPLETED',
            Icons.check_circle_rounded,
            const Color(0xFF2E7D32),
            watched.length,
          ),
          _libraryGrid(watched, badgeColor: const Color(0xFF2E7D32)),
        ],
      ],
    );
  }

  Widget _librarySectionHeader(String title, String subtitle, IconData icon,
      Color accent, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _cWhite,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: _cMuted,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.outfit(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _libraryGrid(List<MediaItem> items, {Color? badgeColor}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
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
        String badgeLabel;
        Color bColor;
        IconData bIcon;
        if (item.isCurrentlyWatching) {
          badgeLabel = item.currentEpisode != null
              ? 'S${item.currentSeason ?? 1}E${item.currentEpisode}'
              : 'WATCHING';
          bColor = const Color(0xFFFF6D00);
          bIcon = Icons.play_circle_filled_rounded;
        } else if (item.isWatched) {
          badgeLabel = item.watchedDisplay.toUpperCase();
          bColor = badgeColor ?? const Color(0xFF2E7D32);
          bIcon = Icons.check_rounded;
        } else {
          badgeLabel = item.wanterDisplay.toUpperCase();
          bColor = badgeColor ?? _cGold;
          bIcon = Icons.bookmark_rounded;
        }
        return ShelfPosterCard(
          imageUrl: item.posterPath,
          title: item.title,
          subtitle: item.year.isNotEmpty ? item.year : null,
          badge: badgeLabel,
          badgeColor: bColor,
          badgeIcon: bIcon,
          onTap: () => _showMediaDetails(item),
        );
      },
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
            child: const ShimmerBox(height: 40, width: 160, radius: 8),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: ShimmerBox(height: 320, radius: 24),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 32, 20, 0),
            child: ShimmerBox(height: 280, radius: 16),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 32, 20, 14),
            child: ShimmerBox(height: 36, width: 200, radius: 8),
          ),
        ),
        const SliverToBoxAdapter(
          child: ShimmerPosterRow(height: 215, width: 130, count: 6),
        ),
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // BOTTOM NAVIGATION
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildBottomNavBar() {
    return ShelfPillBottomNav(
      currentIndex: _currentIndex,
      onTap: _switchTab,
      items: const [
        ShelfNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        ShelfNavItem(
          icon: Icons.search_rounded,
          activeIcon: Icons.search_rounded,
          label: 'Search',
        ),
        ShelfNavItem(
          icon: Icons.collections_bookmark_outlined,
          activeIcon: Icons.collections_bookmark_rounded,
          label: 'Library',
        ),
      ],
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// EXTRACTED WIDGETS
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

// The 40px `_CinemaIconBtn` was replaced by the shared
// `ShelfIconButton` (44 px tap target, focus ring, tooltip,
// semantics — see `lib/shared/widgets/shelf/shelf_icon_button.dart`).

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

/// Search result / watchlist tiles are now provided by
/// `ShelfPosterCard` (see `lib/shared/widgets/shelf/`).

