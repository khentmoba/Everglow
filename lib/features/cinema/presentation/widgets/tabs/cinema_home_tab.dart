import 'dart:async';
import 'package:flutter/material.dart' hide FilterChip;
import 'package:google_fonts/google_fonts.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/trailer_player.dart';
import 'package:everglow/shared/widgets/shelf/shelf_section_header.dart';
import 'package:everglow/shared/widgets/shelf/shelf_poster_card.dart';
import 'package:everglow/shared/widgets/shelf/shimmer_box.dart';
import 'package:everglow/shared/widgets/shelf/arrow_scroll_view.dart';
import 'package:everglow/shared/widgets/shelf/staggered_entrance.dart';
import 'package:everglow/core/theme/app_breakpoints.dart';
import 'package:everglow/features/ai/presentation/widgets/ai_recommendations.dart';
import 'package:everglow/shared/widgets/shelf/cinema_sections.dart';

// ─── Cinema Color Tokens ─────────────────────────────────────────────
const _cBlack = Color(0xFF080810);
const _cVelvet = Color(0xFF12091A);
const _cCard = Color(0xFF1C1228);
const _cRose = Color(0xFFF4C2C2);
const _cDeepRose = Color(0xFFC2185B);
const _cGold = Color(0xFFE8C97A);
const _cAmber = Color(0xFFF0A500);
const _cWhite = Color(0xFFFFF5F5);
const _cMuted = Color(0xFF8A7A92);

/// Featured genre definitions used for both data fetching (in the parent
/// screen) and display (in this tab). Made public so the parent can import.
const List<Map<String, dynamic>> featuredGenres = [
  {
    'id': 28,
    'name': 'Action',
    'type': 'movie',
    'icon': Icons.local_fire_department_rounded,
    'color': Color(0xFFE53935),
  },
  {
    'id': 35,
    'name': 'Comedy',
    'type': 'movie',
    'icon': Icons.sentiment_very_satisfied_rounded,
    'color': Color(0xFFFDD835),
  },
  {
    'id': 27,
    'name': 'Horror',
    'type': 'movie',
    'icon': Icons.brightness_3_rounded,
    'color': Color(0xFF7B1FA2),
  },
  {
    'id': 10749,
    'name': 'Romance',
    'type': 'movie',
    'icon': Icons.favorite_rounded,
    'color': Color(0xFFE91E63),
  },
  {
    'id': 18,
    'name': 'Drama',
    'type': 'movie',
    'icon': Icons.theater_comedy_rounded,
    'color': Color(0xFF1565C0),
  },
  {
    'id': 16,
    'name': 'Animation',
    'type': 'movie',
    'icon': Icons.auto_awesome_rounded,
    'color': Color(0xFF00ACC1),
  },
  {
    'id': 9648,
    'name': 'Mystery',
    'type': 'movie',
    'icon': Icons.youtube_searched_for_rounded,
    'color': Color(0xFF455A64),
  },
  {
    'id': 878,
    'name': 'Sci-Fi',
    'type': 'movie',
    'icon': Icons.rocket_launch_rounded,
    'color': Color(0xFF00BCD4),
  },
  {
    'id': 10765,
    'name': 'Sci-Fi & Fantasy',
    'type': 'tv',
    'icon': Icons.public_rounded,
    'color': Color(0xFF3949AB),
  },
  {
    'id': 10759,
    'name': 'Action & Adventure',
    'type': 'tv',
    'icon': Icons.shield_rounded,
    'color': Color(0xFFEF6C00),
  },
];

// ─────────────────────────────────────────────────────────────────────
// 1. HOME TAB
// ─────────────────────────────────────────────────────────────────────

class CinemaHomeTab extends StatefulWidget {
  final bool isLoadingHome;
  final List<MediaItem> trendingCarousel;
  final List<MediaItem> topRatedMovies;
  final List<MediaItem> popularTVShows;
  final List<MediaItem> nowShowing;
  final List<MediaItem> newlyReleased;
  final List<MediaItem> popularMovies;
  final List<MediaItem> topRatedTV;
  final List<MediaItem> airingToday;
  final List<MediaItem> onTheAir;
  final Map<String, List<MediaItem>> discoveryRows;
  final Map<String, List<MediaItem>> genreLists;
  final List<MediaItem> watchingList;
  final List<MediaItem> watchedList;
  final List<MediaItem> trendingGlobal;
  final List<MediaItem> trendingPH;
  final VoidCallback onRefresh;
  final void Function(MediaItem) onMediaTap;
  final void Function(int) onSwitchTab;

  const CinemaHomeTab({
    super.key,
    required this.isLoadingHome,
    required this.trendingCarousel,
    required this.topRatedMovies,
    required this.popularTVShows,
    required this.nowShowing,
    required this.newlyReleased,
    required this.popularMovies,
    required this.topRatedTV,
    required this.airingToday,
    required this.onTheAir,
    required this.discoveryRows,
    required this.genreLists,
    required this.watchingList,
    required this.watchedList,
    required this.trendingGlobal,
    required this.trendingPH,
    required this.onRefresh,
    required this.onMediaTap,
    required this.onSwitchTab,
  });

  @override
  State<CinemaHomeTab> createState() => _CinemaHomeTabState();
}

class _CinemaHomeTabState extends State<CinemaHomeTab> {
  final TMDBService _tmdbService = TMDBService();

  // Carousel state
  late final PageController _carouselController;
  int _carouselPage = 0;
  Timer? _carouselTimer;
  String? _carouselTrailerKey;
  bool _isPlayingCarouselTrailer = false;
  bool _carouselTrailerMuted = true;
  final Map<int, String?> _carouselTrailerKeysCache = {};

  // Auto-rotate duration
  static const Duration _carouselHoldDuration = Duration(seconds: 18);

  @override
  void initState() {
    super.initState();
    _carouselController = PageController(viewportFraction: 0.88);
    if (widget.trendingCarousel.isNotEmpty) {
      _startCarouselAutoPlay();
      _prefetchCarouselTrailers();
      _startTrailerForPage(0);
    }
  }

  @override
  void didUpdateWidget(CinemaHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trendingCarousel != oldWidget.trendingCarousel &&
        widget.trendingCarousel.isNotEmpty) {
      _carouselPage = 0;
      _carouselTrailerKey = null;
      _isPlayingCarouselTrailer = false;
      _carouselTrailerKeysCache.clear();
      _startCarouselAutoPlay();
      _prefetchCarouselTrailers();
      _startTrailerForPage(0);
    }
  }

  @override
  void dispose() {
    _carouselController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  // ─── Carousel Methods ──────────────────────────────────────────────

  void _onCarouselPageChanged(int index) {
    setState(() {
      _carouselPage = index;
      _isPlayingCarouselTrailer = false;
      _carouselTrailerKey = null;
    });
    _startTrailerForPage(index);
    _restartCarouselAutoPlay();
  }

  void _startTrailerForPage(int index) {
    if (index < 0 || index >= widget.trendingCarousel.length) return;
    final item = widget.trendingCarousel[index];

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

    _tmdbService.fetchTrailerKey(item.tmdbId, item.mediaType).then((
      fetchedKey,
    ) {
      _carouselTrailerKeysCache[item.tmdbId] = fetchedKey;
      if (_carouselPage == index && mounted && fetchedKey != null) {
        setState(() {
          _carouselTrailerKey = fetchedKey;
          _isPlayingCarouselTrailer = true;
        });
      }
    });
  }

  void _prefetchCarouselTrailers() {
    for (var i = 0; i < widget.trendingCarousel.length; i++) {
      final item = widget.trendingCarousel[i];
      if (_carouselTrailerKeysCache.containsKey(item.tmdbId)) continue;
      _tmdbService.fetchTrailerKey(item.tmdbId, item.mediaType).then((key) {
        _carouselTrailerKeysCache[item.tmdbId] = key;
        if (i == _carouselPage &&
            mounted &&
            key != null &&
            !_isPlayingCarouselTrailer) {
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

  void _restartCarouselAutoPlay() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer(_carouselHoldDuration, () {
      if (widget.trendingCarousel.isEmpty || !_carouselController.hasClients) {
        return;
      }
      final nextPage =
          (_carouselPage + 1) % widget.trendingCarousel.length;
      _carouselController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.isLoadingHome) {
      return _buildShimmerHome();
    }

    return RefreshIndicator(
      color: _cDeepRose,
      backgroundColor: _cCard,
      onRefresh: () async => widget.onRefresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Hero Carousel (always first, no header needed on desktop)
          SliverToBoxAdapter(child: _buildHeroBanner()),

          // Continue Watching — right after hero carousel
          if (widget.watchingList.isNotEmpty)
            SliverToBoxAdapter(
              child: ContinueWatchingRow(
                items: buildContinueItems(
                  items: widget.watchingList.take(8).toList(),
                  getId: (m) => '${m.tmdbId}',
                  getTitle: (m) => m.title,
                  getImageUrl: (m) =>
                      m.backdropPath.isNotEmpty ? m.backdropPath : m.posterPath,
                  getYear: (m) => m.year.isNotEmpty ? m.year : null,
                  getProgressLabel: (m) =>
                      m.mediaType == 'tv' && m.currentSeason != null
                          ? 'S${m.currentSeason} · E${m.currentEpisode ?? 1}'
                          : 'CONTINUE',
                  onTap: (m) => widget.onMediaTap(m),
                ),
              ),
            ),

          // Mochi's Picks — real AI recommendations
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AIRecommendations(
                title: "Mochi's Picks 🐱",
                autoLoad: true,
                onTapItem: (item) => widget.onMediaTap(item),
              ),
            ),
          ),

          // Top 10 Today Rankings
          SliverToBoxAdapter(
            child: TopTenRankingSection(
              items: buildRankingItems(
                items: widget.trendingGlobal.take(10).toList(),
                getTitle: (m) => m.title,
                getImageUrl: (m) =>
                    m.posterPath.isNotEmpty ? m.posterPath : m.posterUrl,
                getSubtitle: (m) => m.year.isNotEmpty ? m.year : null,
                getBadge: (m) => m.mediaType.toUpperCase(),
                onTap: (m) => widget.onMediaTap(m),
              ),
              eyebrow: 'Trending Today',
              title: 'TOP 10 Today',
              accent: _cAmber,
            ),
          ),

          // Now Showing
          SliverToBoxAdapter(
            child: _buildGenericSection(
              eyebrow: 'In Cinemas',
              title: 'Now Showing',
              items: widget.nowShowing,
              accentColor: _cDeepRose,
              icon: Icons.movie_creation_outlined,
            ),
          ),

          // Newly Released
          SliverToBoxAdapter(
            child: _buildGenericSection(
              eyebrow: 'Fresh Picks',
              title: 'Newly Released',
              items: widget.newlyReleased,
              accentColor: _cGold,
              icon: Icons.new_releases_rounded,
            ),
          ),

          // Genre rows
          ..._buildGenreRows(),

          // ══ DISCOVERY ROWS (Phase 3a) ═══════════════════════

          // Popular Movies
          SliverToBoxAdapter(
            child: _buildGenericSection(
              eyebrow: 'TRENDING',
              title: 'Popular Movies',
              items: widget.popularMovies,
              accentColor: _cDeepRose,
              icon: Icons.movie_rounded,
            ),
          ),

          // Top Rated TV
          SliverToBoxAdapter(
            child: _buildGenericSection(
              eyebrow: 'CRITICALLY ACCLAIMED',
              title: 'Top Rated TV',
              items: widget.topRatedTV,
              accentColor: _cGold,
              icon: Icons.star_rounded,
            ),
          ),

          // Airing Today
          SliverToBoxAdapter(
            child: _buildGenericSection(
              eyebrow: 'FRESH EPISODES',
              title: 'Airing Today',
              items: widget.airingToday,
              accentColor: _cAmber,
              icon: Icons.live_tv_rounded,
            ),
          ),

          // On The Air
          SliverToBoxAdapter(
            child: _buildGenericSection(
              eyebrow: 'CURRENTLY RUNNING',
              title: 'On The Air',
              items: widget.onTheAir,
              accentColor: const Color(0xFF4CAF50),
              icon: Icons.tv_rounded,
            ),
          ),

          // Korean Dramas
          if (widget.discoveryRows['korean_dramas']?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: _buildGenericSection(
                eyebrow: 'KOREAN WAVE',
                title: 'Korean Dramas',
                items: widget.discoveryRows['korean_dramas']!,
                accentColor: const Color(0xFFE53935),
                icon: Icons.language_rounded,
              ),
            ),

          // Bollywood
          if (widget.discoveryRows['bollywood']?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: _buildGenericSection(
                eyebrow: 'BOLLYWOOD',
                title: 'Bollywood',
                items: widget.discoveryRows['bollywood']!,
                accentColor: const Color(0xFFFF7043),
                icon: Icons.language_rounded,
              ),
            ),

          // Spanish Cinema
          if (widget.discoveryRows['spanish_cinema']?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: _buildGenericSection(
                eyebrow: 'CINE ESPAÑOL',
                title: 'Spanish Cinema',
                items: widget.discoveryRows['spanish_cinema']!,
                accentColor: const Color(0xFFFDD835),
                icon: Icons.language_rounded,
              ),
            ),

          // French Cinema
          if (widget.discoveryRows['french_cinema']?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: _buildGenericSection(
                eyebrow: 'CINEMA FRANÇAIS',
                title: 'French Cinema',
                items: widget.discoveryRows['french_cinema']!,
                accentColor: const Color(0xFF42A5F5),
                icon: Icons.language_rounded,
              ),
            ),

          // Best of the 2010s
          if (widget.discoveryRows['decade_2010s']?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: _buildGenericSection(
                eyebrow: 'BEST OF THE DECADE',
                title: 'Best of the 2010s',
                items: widget.discoveryRows['decade_2010s']!,
                accentColor: const Color(0xFF26A69A),
                icon: Icons.timeline_rounded,
              ),
            ),

          // Best of the 2000s
          if (widget.discoveryRows['decade_2000s']?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: _buildGenericSection(
                eyebrow: 'BEST OF THE DECADE',
                title: 'Best of the 2000s',
                items: widget.discoveryRows['decade_2000s']!,
                accentColor: const Color(0xFF66BB6A),
                icon: Icons.timeline_rounded,
              ),
            ),

          // Classic Films (pre-2000)
          if (widget.discoveryRows['classic_films']?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: _buildGenericSection(
                eyebrow: 'TIMELESS CLASSICS',
                title: 'Classic Films',
                items: widget.discoveryRows['classic_films']!,
                accentColor: const Color(0xFFAB47BC),
                icon: Icons.history_rounded,
              ),
            ),

          // Top Rated
          SliverToBoxAdapter(
            child: _buildGenericSection(
              eyebrow: 'All Time Greats',
              title: 'Top Rated',
              items: widget.topRatedMovies,
              accentColor: _cAmber,
              icon: Icons.workspace_premium_rounded,
            ),
          ),

          // Popular Series
          SliverToBoxAdapter(
            child: _buildGenericSection(
              eyebrow: 'TV Shows',
              title: 'Popular Series',
              items: widget.popularTVShows,
              accentColor: _cRose,
              icon: Icons.tv_rounded,
            ),
          ),

          // Only On — streaming provider sections
          if (widget.trendingGlobal.length >= 8)
            SliverToBoxAdapter(
              child: OnlyOnSection(
                providers: [
                  buildProviderRow(
                    name: 'Netflix',
                    icon: Icons.play_circle_rounded,
                    color: const Color(0xFFE50914),
                    items: widget.trendingGlobal.take(6).toList(),
                    getId: (m) => '${m.tmdbId}',
                    getTitle: (m) => m.title,
                    getImageUrl: (m) =>
                        m.posterPath.isNotEmpty ? m.posterPath : m.posterUrl,
                    onTap: (m) => widget.onMediaTap(m),
                  ),
                  buildProviderRow(
                    name: 'Amazon Prime',
                    icon: Icons.shopping_bag_rounded,
                    color: const Color(0xFF00A8E1),
                    items: widget.popularTVShows.take(6).toList(),
                    getId: (m) => '${m.tmdbId}',
                    getTitle: (m) => m.title,
                    getImageUrl: (m) =>
                        m.posterPath.isNotEmpty ? m.posterPath : m.posterUrl,
                    onTap: (m) => widget.onMediaTap(m),
                  ),
                ],
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }



  // ─── Hero Carousel ─────────────────────────────────────────────────

  Widget _buildHeroBanner() {
    if (widget.trendingCarousel.isEmpty) return const SizedBox.shrink();
    final isDesktop = AppBreakpoint.isDesktop(context);
    final heroHeight = isDesktop
        ? 520.0
        : MediaQuery.of(context).size.height * 0.62;

    return Column(
      children: [
        SizedBox(
          height: heroHeight,
          child: PageView.builder(
            controller: _carouselController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: _onCarouselPageChanged,
            itemCount: widget.trendingCarousel.length,
            itemBuilder: (context, index) {
              final item = widget.trendingCarousel[index];
              return AnimatedBuilder(
                animation: _carouselController,
                builder: (context, child) {
                  double scale = 1.0;
                  if (_carouselController.position.haveDimensions) {
                    final diff =
                        (_carouselController.page! - index).abs();
                    scale = (1 - (diff * 0.06)).clamp(0.92, 1.0);
                  } else {
                    scale = index == _carouselPage ? 1.0 : 0.94;
                  }
                  return Transform.scale(scale: scale, child: child);
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
          children: List.generate(widget.trendingCarousel.length, (i) {
            final isActive = i == _carouselPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 22 : 5,
              height: 5,
              decoration: BoxDecoration(
                color:
                    isActive ? _cDeepRose : _cMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: _cDeepRose.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
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
    final isDesktop = AppBreakpoint.isDesktop(context);
    return GestureDetector(
      onTap: () => widget.onMediaTap(item),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: isDesktop
              ? null
              : [
                  BoxShadow(
                    color: _cBlack.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, -10),
                  ),
                ],
        ),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop / Live Trailer background
              index == _carouselPage &&
                      _isPlayingCarouselTrailer &&
                      _carouselTrailerKey != null
                  ? TrailerPlayer(
                      videoKey: _carouselTrailerKey!,
                      muted: _carouselTrailerMuted,
                      autoplay: true,
                      loop: true,
                    )
                  : (item.backdropPath.isNotEmpty
                        ? Image.network(
                            item.backdropPath,
                            fit: BoxFit.cover,
                            cacheWidth: 1200,
                            errorBuilder: (_, __, ___) =>
                                Container(color: _cVelvet),
                          )
                        : (item.posterUrl.isNotEmpty
                              ? Image.network(
                                  item.posterUrl,
                                  fit: BoxFit.cover,
                                  cacheWidth: 500,
                                  errorBuilder: (_, __, ___) =>
                                      Container(color: _cVelvet),
                                )
                              : Container(color: _cVelvet))),

              // Bottom gradient — cinematic fade
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      _cBlack.withValues(alpha: 0.1),
                      _cBlack.withValues(alpha: 0.6),
                      _cBlack.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.35, 0.65, 1.0],
                  ),
                ),
              ),

              // Right-side blue/dark gradient (Cineby signature)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      const Color(0xFF0A1628).withValues(alpha: 0.4),
                      const Color(0xFF0A1628).withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.45, 0.75, 1.0],
                  ),
                ),
              ),

              // Mute/unmute button
              if (index == _carouselPage && _isPlayingCarouselTrailer)
                Positioned(
                  top: 16,
                  right: 16,
                  child: _CarouselMuteButton(
                    isMuted: _carouselTrailerMuted,
                    onToggle: () {
                      setState(() {
                        _carouselTrailerMuted = !_carouselTrailerMuted;
                      });
                    },
                  ),
                ),

              // Movie info content (Cineby-style overlay)
              Positioned(
                bottom: 28,
                left: isDesktop ? 48 : 20,
                right: isDesktop ? 48 : 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                    const SizedBox(height: 12),
                    // Title
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: isDesktop ? 36 : 26,
                        fontWeight: FontWeight.w900,
                        color: _cWhite,
                        height: 1.05,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Year · Media Type
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
                          const SizedBox(width: 10),
                        ],
                        Text(
                          item.mediaType.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: _cMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // Description (desktop only)
                    if (isDesktop && item.synopsis.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        item.synopsis,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: _cMuted.withValues(alpha: 0.8),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Play + See More buttons
                    Row(
                      children: [
                        // Play button
                        GestureDetector(
                          onTap: () => widget.onMediaTap(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _cWhite,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  color: _cBlack,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Play',
                                  style: GoogleFonts.outfit(
                                    color: _cBlack,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // See More button
                        GestureDetector(
                          onTap: () => widget.onMediaTap(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: _cWhite.withValues(alpha: 0.85),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'See More',
                                  style: GoogleFonts.outfit(
                                    color: _cWhite.withValues(alpha: 0.85),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
  }




  // ─── Section Row ───────────────────────────────────────────────────

  Widget _buildGenericSection({
    required String title,
    required String eyebrow,
    required List<MediaItem> items,
    required Color accentColor,
    IconData? icon,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isDesktop = AppBreakpoint.isDesktop(context);
    final horizontalPad = isDesktop ? 48.0 : 20.0;
    final posterWidth = (isDesktop ? 160 : 130).toDouble();
    final sectionHeight = isDesktop ? 270.0 : 230.0;
    final scrollController = ScrollController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPad, 32, horizontalPad, 14),
          child: ShelfSectionHeader(
            eyebrow: eyebrow,
            title: title,
            icon: icon,
            accent: accentColor,
            count: items.length,
            countLabel: items.length == 1 ? 'title' : 'titles',
          ),
        ),
        SizedBox(
          height: sectionHeight,
          child: ArrowScrollView(
            controller: scrollController,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              clipBehavior: Clip.none,
              itemCount: items.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: posterWidth,
                    child: ShelfPosterCard(
                      imageUrl: items[index].posterPath,
                      title: items[index].title,
                      subtitle: items[index].year.isNotEmpty
                          ? items[index].year
                          : null,
                      badge:
                          items[index].mediaType == 'movie' ? 'MOVIE' : 'TV',
                      badgeIcon: items[index].mediaType == 'movie'
                          ? Icons.movie_outlined
                          : Icons.tv_outlined,
                      onTap: () => widget.onMediaTap(items[index]),
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
    widget.genreLists.forEach((genreName, items) {
      final genreMeta = featuredGenres.firstWhere(
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
              eyebrow: genreMeta['type'] == 'tv' ? 'TV Series' : 'Movies',
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

  // ─── Shimmer Loading ───────────────────────────────────────────────

  Widget _buildShimmerHome() {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 14,
              20,
              20,
            ),
            child: const ShimmerBox(height: 40, width: 160, radius: 8),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: ShimmerBox(height: 400, radius: 24),
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
}

// ═══════════════════════════════════════════════════════════════════════
// EXTRACTED WIDGETS
// ═══════════════════════════════════════════════════════════════════════

/// Ranking list tile
class RankingTile extends StatefulWidget {
  final MediaItem item;
  final int rank;
  final VoidCallback onTap;

  const RankingTile({
    super.key,
    required this.item,
    required this.rank,
    required this.onTap,
  });

  @override
  State<RankingTile> createState() => _RankingTileState();
}

class _RankingTileState extends State<RankingTile> {
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
                          color: _rankColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
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
                child: widget.item.posterUrl.isNotEmpty
                    ? Image.network(
                        widget.item.posterUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 150,
                      )
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
                        widget.item.year.isNotEmpty ? widget.item.year : '—',
                        style: GoogleFonts.outfit(
                          color: _cGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
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

// ─── Hero Mute/Unmute Button ─────────────────────────────────────────

/// Floating mute/unmute toggle that appears over the hero carousel
/// when a trailer is playing — matches cineby's UX.
class _CarouselMuteButton extends StatefulWidget {
  final bool isMuted;
  final VoidCallback onToggle;

  const _CarouselMuteButton({required this.isMuted, required this.onToggle});

  @override
  State<_CarouselMuteButton> createState() => _CarouselMuteButtonState();
}

class _CarouselMuteButtonState extends State<_CarouselMuteButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                widget.isMuted ? 'Unmute' : 'Mute',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
