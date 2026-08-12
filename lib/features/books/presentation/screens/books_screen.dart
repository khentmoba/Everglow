import 'dart:async';
import 'package:flutter/material.dart' hide FilterChip;
import 'package:flutter/services.dart';import 'package:provider/provider.dart';

import 'package:everglow/features/books/data/models/book_item.dart';
import 'package:everglow/features/books/data/models/book_search_result.dart';
import 'package:everglow/features/books/data/services/book_catalog_service.dart';
import 'package:everglow/features/books/data/services/book_download_helper.dart';
import 'package:go_router/go_router.dart';
import 'package:everglow/features/books/data/services/open_library_service.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/shared/widgets/shelf/atmospheric_backdrop.dart';
import 'package:everglow/shared/widgets/shelf/filter_chip.dart';
import 'package:everglow/shared/widgets/shelf/scroll_edge_fade.dart';
import 'package:everglow/shared/widgets/shelf/shelf_icon_button.dart';
import 'package:everglow/shared/widgets/shelf/shelf_poster_card.dart';
import 'package:everglow/shared/widgets/shelf/shelf_section_header.dart';
import 'package:everglow/shared/widgets/shelf/shelf_empty_state.dart';
import 'package:everglow/shared/widgets/shelf/shimmer_box.dart';
import 'package:everglow/shared/widgets/shelf/shelf_pill_bottom_nav.dart';
import 'package:everglow/shared/widgets/shelf/staggered_entrance.dart';
import 'package:everglow/core/theme/app_breakpoints.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/core/theme/app_typography.dart';

const _cBlack = Color(0xFF080810);
const _cCard = Color(0xFF1C1228);
const _cRose = Color(0xFFF4C2C2);
const _cDeepRose = Color(0xFFC2185B);
const _cGold = Color(0xFFE8C97A);
const _cAmber = Color(0xFFF0A500);
const _cWhite = Color(0xFFFFF5F5);
const _cMuted = Color(0xFF8A7A92);

/// Main entry for the books feature. Four-tab IndexedStack
/// (Home, Search, To Read, Read) with a custom glassmorphic bottom
/// nav. Mirrors `CinemaScreen` from the cinema feature.
class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  final OpenLibraryService _service = OpenLibraryService();
  final BookCatalogService _catalog = BookCatalogService();
  int _currentIndex = 0;

  StreamSubscription<List<BookItem>>? _readlistSub;
  List<BookItem> _readlist = [];
  List<BookItem> _toReadList = [];
  List<BookItem> _readHistoryList = [];

  List<BookItem> _trendingCarousel = [];
  List<BookItem> _trendingRankings = [];
  final Map<String, List<BookItem>> _subjectLists = {};
  bool _isLoadingHome = true;
  final PageController _carouselController =
      PageController(viewportFraction: 0.88);
  int _carouselPage = 0;
  Timer? _carouselTimer;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<BookSearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;
  BookSort _searchSort = BookSort.relevant;
  String? _searchFiletype;
  String? _searchLanguage;
  bool _searchRan = false;

  static final List<Map<String, dynamic>> _featuredSubjects = [
    {
      'name': 'Romance',
      'icon': Icons.favorite_rounded,
      'color': const Color(0xFFE91E63),
    },
    {
      'name': 'Mystery',
      'icon': Icons.search_rounded,
      'color': const Color(0xFF7B1FA2),
    },
    {
      'name': 'Science Fiction',
      'icon': Icons.rocket_launch_rounded,
      'color': const Color(0xFF00BCD4),
    },
    {
      'name': 'Fantasy',
      'icon': Icons.auto_awesome_rounded,
      'color': const Color(0xFF3949AB),
    },
    {
      'name': 'Classics',
      'icon': Icons.menu_book_rounded,
      'color': const Color(0xFFE8C97A),
    },
    {
      'name': 'Adventure',
      'icon': Icons.explore_rounded,
      'color': const Color(0xFFEF6C00),
    },
    {
      'name': 'Horror',
      'icon': Icons.brightness_3_rounded,
      'color': const Color(0xFF1A1A2E),
    },
    {
      'name': 'Poetry',
      'icon': Icons.auto_awesome_motion_outlined,
      'color': const Color(0xFFD4B5D6),
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userName = context.read<AuthService>().currentUser ?? '';
      if (userName.isEmpty) return;
      _loadCachedReadList(userName);
      _subscribeToReadList(userName);
    });
  }

  @override
  void dispose() {
    _readlistSub?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _carouselController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedReadList(String userName) async {
    final cached = await _service.getCachedReadList(userName);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _readlist = cached;
        _splitLists();
      });
    }
  }

  void _subscribeToReadList(String userName) {
    _readlistSub = _service.getReadListStream(userName).listen((items) {
      if (mounted) {
        setState(() {
          _readlist = items;
          _splitLists();
        });
      }
    });
  }

  void _splitLists() {
    _toReadList = _readlist.where((item) => item.isToRead).toList();
    _readHistoryList = _readlist.where((item) => item.isRead).toList();
  }

  Future<void> _fetchHomeData() async {
    setState(() => _isLoadingHome = true);

    final trending = await _service.fetchTrending();
    if (!mounted) return;
    setState(() {
      _trendingRankings = trending;
      _trendingCarousel = trending.take(5).toList();
      _isLoadingHome = false;
    });
    _startCarouselAutoPlay();
    _fetchSubjectLists();
  }

  Future<void> _fetchSubjectLists() async {
    for (final subject in _featuredSubjects) {
      final name = subject['name'] as String;
      final items = await _service.discoverBySubject(name, limit: 12);
      if (mounted && items.isNotEmpty) {
        setState(() {
          _subjectLists[name] = items;
        });
      }
    }
  }

  static const Duration _carouselHoldDuration = Duration(seconds: 12);

  void _onCarouselPageChanged(int index) {
    setState(() => _carouselPage = index);
    _restartCarouselAutoPlay();
  }

  void _startCarouselAutoPlay() => _restartCarouselAutoPlay();

  void _restartCarouselAutoPlay() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer(_carouselHoldDuration, () {
      if (!mounted) return;
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
      if (!mounted) return;
      if (query.trim().isNotEmpty) {
        _performSearch(query.trim());
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _searchRan = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final results = await _catalog.search(
      query,
      filetype: _searchFiletype,
      language: _searchLanguage,
      sort: _searchSort,
      limit: 30,
    );
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _searchRan = true;
      });
    }
  }

  void _showBookDetails(BookItem item) {
    HapticFeedback.lightImpact();
    context.push(
      '/books/detail',
      extra: BookDetailArgs(item: item),
    );
  }

  void _switchTab(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  void _openFullDatabaseSearch() {
    _switchTab(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: _cBlack,
      body: Stack(
        children: [
          const ShelfAtmosphericBackdrop(
            glows: [
              RadialGlow(
                color: AppTheme.warmAmber,
                alignment: Alignment(-0.7, -0.85),
                size: 0.85,
                opacity: 0.14,
              ),
              RadialGlow(
                color: AppTheme.deepRose,
                alignment: Alignment(0.85, 0.95),
                size: 0.8,
                opacity: 0.10,
              ),
            ],
          ),
          SafeArea(
            top: false,
            bottom: false,
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeTab(),
                _buildSearchTab(),
                _buildReadlistTab(isReadTab: false),
                _buildReadlistTab(isReadTab: true),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // ── HOME TAB ───────────────────────────────────────────────────────

  Widget _buildHomeTab() {
    if (_isLoadingHome) {
      return _buildShimmerHome();
    }
    return RefreshIndicator(
      color: _cAmber,
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
              child: _buildHomeSearch(),
            ),
          ),
          SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 2,
              child: _buildHeroBanner(),
            ),
          ),
          if (_readHistoryList.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: StaggeredEntrance(
                index: 3,
                child: _buildContinueReading(),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 4,
              child: _buildTrendingRankings(),
            ),
          ),
          ..._buildSubjectRows(),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildContinueReading() {
    // The most recent reads surface in a wide rail so users can
    // jump back into something they were already in.
    final recent = _readHistoryList.take(8).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShelfSectionHeader(
            eyebrow: 'Open That Book Again',
            title: 'Continue Reading',
            icon: Icons.menu_book_rounded,
            accent: _cAmber,
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
                    onTap: () => _showBookDetails(item),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.black.withValues(alpha: 0.05),
                          ],
                        ),
                        border: Border.all(
                          color: _cAmber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (item.coverUrl.isNotEmpty)
                              Image.network(
                                item.coverUrl,
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
                                      color: _cAmber,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'READ',
                                      style: TextStyle(
                                        color: Colors.black,
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
                                    style: AppTypography.cormorantBold.copyWith(fontSize: 15, height: 1.15, color: _cWhite),
                                  ),
                                  if (item.author.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'by ${item.author}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.outfitWhite.copyWith(color: _cRose
                                            .withValues(alpha: 0.85), fontSize: 10, fontStyle: FontStyle.italic),
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
                                  color: _cAmber.withValues(alpha: 0.9),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _cAmber.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.replay_rounded,
                                  color: Colors.black,
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
    final top = MediaQuery.paddingOf(context).top;
    final canPop = Navigator.canPop(context);
    final isCouple = context.watch<AuthService>().isCoupleUser;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 10),
      child: Row(
        children: [
          if (canPop)
            ShelfIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              semanticLabel: 'Back',
              tooltip: 'Back',
              onTap: () => Navigator.pop(context),
            )
          else
            const SizedBox(width: 44, height: 44),
          const Spacer(),
          Column(
            children: [
              Text(
                'OUR BOOKS',
                style: AppTypography.cormorantBlack.copyWith(fontSize: 20, letterSpacing: 4, color: _cWhite),
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
                    style: AppTypography.outfitBold.copyWith(fontSize: 9, color: _cMuted, letterSpacing: 2.5),
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
          if (isCouple)
            ShelfIconButton(
              icon: Icons.favorite_rounded,
              semanticLabel: 'Open Our Books',
              tooltip: 'Our Books',
              onTap: () => context.push('/our-books'),
            )
          else
            const SizedBox(width: 44, height: 44),
          const SizedBox(width: 8),
          ShelfIconButton(
            icon: Icons.search_rounded,
            semanticLabel: 'Search',
            tooltip: 'Search books',
            onTap: () => _switchTab(1),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: GestureDetector(
        onTap: _openFullDatabaseSearch,
        child: Container(
          height: 52,
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.travel_explore_rounded,
                  color: _cDeepRose, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search the full database...',
                  style: AppTypography.outfitWhite.copyWith(
                    color: _cMuted,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _cDeepRose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'FULL DATABASE',
                  style: AppTypography.outfitBold.copyWith(
                    color: _cDeepRose,
                    fontSize: 8.5,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HERO CAROUSEL ──────────────────────────────────────────────────

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
                color: isActive
                    ? _cDeepRose
                    : _cMuted.withValues(alpha: 0.35),
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

  Widget _buildHeroCard(BookItem item, int index) {
    return GestureDetector(
      onTap: () => _showBookDetails(item),
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
                item.coverUrl.isNotEmpty
                    ? Image.network(item.coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(color: _cCard))
                    : Container(color: _cCard),
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
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                  style: AppTypography.outfitWhite.copyWith(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cormorantBlack.copyWith(fontSize: 26, height: 1.1, shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 12,
                            ),
                          ], color: _cWhite),
                      ),
                      if (item.author.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'by ${item.author}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitWhite.copyWith(color: _cWhite.withValues(alpha: 0.85), fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (item.year.isNotEmpty) ...[
                            Text(
                              item.year,
                              style: AppTypography.outfitBold.copyWith(color: _cGold, fontSize: 12),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8),
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
                            style: AppTypography.outfitWhite.copyWith(color: _cMuted, fontSize: 12),
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

  // ── TRENDING RANKINGS ──────────────────────────────────────────────

  Widget _buildTrendingRankings() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShelfSectionHeader(
            eyebrow: 'This Week',
            title: 'Trending Now',
            icon: Icons.emoji_events_rounded,
            accent: _cAmber,
            count: 10,
            countLabel: 'titles',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: (_responsiveListHeight(context, fallback: 480)),
            child: _trendingRankings.isEmpty
                ? const ShelfEmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: 'No rankings available',
                    subtitle: 'Check back soon — the chart refreshes weekly.',
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _trendingRankings.take(10).length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = _trendingRankings[index];
                      return _RankingTile(
                        item: item,
                        rank: index + 1,
                        onTap: () => _showBookDetails(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Returns a responsive list height proportional to the viewport,
  /// clamped so the list never collapses on mobile or blows out on
  /// ultrawide displays.
  static double _responsiveListHeight(BuildContext context, {required double fallback}) {
    final viewH = MediaQuery.sizeOf(context).height;
    return (viewH * 0.42).clamp(fallback * 0.6, fallback * 1.35);
  }

  // ── SUBJECT ROWS ───────────────────────────────────────────────────

  List<Widget> _buildSubjectRows() {
    final rows = <Widget>[];
    var i = 4;
    _subjectLists.forEach((name, items) {
      final meta = _featuredSubjects.firstWhere(
        (s) => s['name'] == name,
        orElse: () => {
          'name': name,
          'icon': Icons.menu_book_rounded,
          'color': _cRose,
        },
      );
      final icon = meta['icon'] as IconData?;
      final color = meta['color'] as Color? ?? _cRose;
      rows.add(
        SliverToBoxAdapter(
          child: StaggeredEntrance(
            index: i,
            child: _buildSection(name, 'Books', items,
                accentColor: color, icon: icon),
          ),
        ),
      );
      i++;
    });
    return rows;
  }

  Widget _buildSection(
    String title,
    String subtitle,
    List<BookItem> items, {
    Color accentColor = _cRose,
    IconData? icon,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 14),
          child: ShelfSectionHeader(
            eyebrow: subtitle,
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
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final book = items[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 150,
                    child: ShelfPosterCard(
                      imageUrl: book.coverUrl,
                      title: book.title,
                      subtitle: book.author.isNotEmpty
                          ? 'by ${book.author}'
                          : (book.year.isNotEmpty ? book.year : null),
                      badge: 'BOOK',
                      badgeIcon: Icons.menu_book_rounded,
                      badgeColor: accentColor,
                      onTap: () => _showBookDetails(book),
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

  // ── SEARCH TAB ─────────────────────────────────────────────────────

  Widget _buildSearchTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.paddingOf(context).top + 14, 20, 0),
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
                      style: AppTypography.cormorantExtraBold.copyWith(fontSize: 26, color: _cWhite),
                    ),
                    Text(
                      'FIND YOUR NEXT OBSESSION',
                      style: AppTypography.outfitHeading.copyWith(fontSize: 9, color: _cMuted, letterSpacing: 2.0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              style: AppTypography.outfitWhite.copyWith(color: _cWhite, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Title, author, subject...',
                hintStyle:
                    AppTypography.outfitWhite.copyWith(color: _cMuted, fontSize: 15),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(Icons.search_rounded,
                      color: _cDeepRose, size: 22),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 0, vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isSearching
              ? const Center(
                  child: CircularProgressIndicator(
                    color: _cDeepRose,
                    strokeWidth: 2.5,
                  ),
                )
              : Column(
                  children: [
                    _buildSearchFilters(),
                    if (!_searchRan && _searchResults.isEmpty)
                      Expanded(child: _buildSearchEmptyState())
                    else if (_searchResults.isEmpty)
                      Expanded(
                        child: _buildSearchEmptyState(
                          title: 'No results found',
                          subtitle:
                              'Try a different title, author, or subject. The full database covers Open Library, Project Gutenberg, and the Internet Archive.',
                          icon: Icons.search_off_rounded,
                        ),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                        child: Row(
                          children: [
                            Text(
                              '${_searchResults.length} RESULTS',
                              style: AppTypography.outfitHeading.copyWith(
                                fontSize: 9,
                                color: _cMuted,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'FULL DATABASE',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 10,
                                color: _cDeepRose,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) =>
                              _buildResultRow(_searchResults[index]),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSearchFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _cCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _cRose.withValues(alpha: 0.12)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BookSort>(
                      value: _searchSort,
                      dropdownColor: _cCard,
                      style: AppTypography.outfitWhite.copyWith(
                        color: _cWhite,
                        fontSize: 11.5,
                      ),
                      icon: const Icon(Icons.expand_more_rounded,
                          color: _cMuted, size: 16),
                      items: const [
                        DropdownMenuItem(
                          value: BookSort.relevant,
                          child: Text('Order: relevant'),
                        ),
                        DropdownMenuItem(
                          value: BookSort.popular,
                          child: Text('Order: most popular'),
                        ),
                        DropdownMenuItem(
                          value: BookSort.newest,
                          child: Text('Order: newest'),
                        ),
                        DropdownMenuItem(
                          value: BookSort.oldest,
                          child: Text('Order: oldest'),
                        ),
                        DropdownMenuItem(
                          value: BookSort.largest,
                          child: Text('Order: largest'),
                        ),
                        DropdownMenuItem(
                          value: BookSort.smallest,
                          child: Text('Order: smallest'),
                        ),
                        DropdownMenuItem(
                          value: BookSort.random,
                          child: Text('Order: random'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        HapticFeedback.selectionClick();
                        setState(() => _searchSort = value);
                        if (_searchController.text.trim().isNotEmpty) {
                          _performSearch(_searchController.text.trim());
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                for (final ft in BookCatalogService.supportedFiletypes)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      icon: _filetypeIcon(ft),
                      label: ft.toUpperCase(),
                      color: _cDeepRose,
                      selected: _searchFiletype == ft,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _searchFiletype =
                              _searchFiletype == ft ? null : ft;
                        });
                        if (_searchController.text.trim().isNotEmpty) {
                          _performSearch(_searchController.text.trim());
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final lang in [
                  'All',
                  ...BookCatalogService.supportedLanguages.take(6),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      icon: Icons.language_rounded,
                      label: lang,
                      color: _cAmber,
                      selected:
                          (lang == 'All' && _searchLanguage == null) ||
                              _searchLanguage == lang,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _searchLanguage = lang == 'All' ? null : lang;
                        });
                        if (_searchController.text.trim().isNotEmpty) {
                          _performSearch(_searchController.text.trim());
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _filetypeIcon(String ft) {
    switch (ft) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'epub':
        return Icons.menu_book_rounded;
      case 'mobi':
        return Icons.phone_iphone_rounded;
      case 'txt':
        return Icons.article_rounded;
      case 'html':
        return Icons.language_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Widget _buildResultRow(BookSearchResult result) {
    final book = result.toBookItem();
    final canRead = result.readCandidates.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(
            '/books/detail',
            extra: BookDetailArgs(item: book, result: result),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cCard.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cRose.withValues(alpha: 0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 58,
                  height: 82,
                  child: result.coverUrl.isNotEmpty
                      ? Image.network(
                          result.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Container(color: _cBlack),
                        )
                      : Container(
                          color: _cBlack,
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: _cMuted,
                            size: 22,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitBold.copyWith(
                        color: _cWhite,
                        fontSize: 13.5,
                        height: 1.2,
                      ),
                    ),
                    if (result.author.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        result.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitWhite.copyWith(
                          color: _cMuted,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (result.metaLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.metaLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitWhite.copyWith(
                          color: _cGold.withValues(alpha: 0.85),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                    if (result.hasRating) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Icon(
                              i <= result.rating!.round()
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: _cGold,
                              size: 13,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            result.rating!.toStringAsFixed(1),
                            style: AppTypography.outfitBold.copyWith(
                              color: _cMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ] else if (result.ratingCount != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_compactCount(result.ratingCount!)} downloads',
                        style: AppTypography.outfitWhite.copyWith(
                          color: _cMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _RowAction(
                          icon: Icons.headphones_rounded,
                          tooltip: 'Listen',
                          color: _cAmber,
                          onTap: canRead
                              ? () => context.push('/books/listen',
                                  extra: book)
                              : null,
                        ),
                        _RowAction(
                          icon: Icons.auto_stories_rounded,
                          tooltip: 'Read',
                          color: _cDeepRose,
                          onTap: canRead
                              ? () => context.push('/books/reader',
                                  extra: book)
                              : null,
                        ),
                        _RowAction(
                          icon: Icons.download_rounded,
                          tooltip: 'Download',
                          color: const Color(0xFF2E7D32),
                          onTap: result.downloadUrls.isNotEmpty
                              ? () => _showRowDownload(result)
                              : null,
                        ),
                        _RowAction(
                          icon: Icons.share_rounded,
                          tooltip: 'Share',
                          color: const Color(0xFF1976D2),
                          onTap: () => _shareResult(result),
                        ),
                        _RowAction(
                          icon: Icons.bookmark_border_rounded,
                          tooltip: 'Save',
                          color: const Color(0xFF7B1FA2),
                          onTap: () => _saveResult(result),
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

  String _compactCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  void _showRowDownload(BookSearchResult result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _cCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _cRose.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Download',
              style: AppTypography.cormorantBlack.copyWith(
                fontSize: 24,
                color: _cWhite,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Public-domain formats from ${result.sourceLabel}',
              style: AppTypography.outfitWhite.copyWith(
                color: _cMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            for (final entry in result.downloadUrls.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _cDeepRose.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        entry.key.toUpperCase(),
                        style: AppTypography.outfitBold.copyWith(
                          color: _cDeepRose,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${entry.key.toUpperCase()} file',
                        style: AppTypography.outfitWhite.copyWith(
                          color: _cWhite,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => downloadUrl(entry.value),
                      style: TextButton.styleFrom(
                        backgroundColor: _cDeepRose,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Download'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _shareResult(BookSearchResult result) async {
    HapticFeedback.selectionClick();
    String url = '';
    if (result.gutenbergId > 0) {
      url = 'https://www.gutenberg.org/ebooks/${result.gutenbergId}';
    } else if (result.iaId.isNotEmpty) {
      url = 'https://archive.org/details/${result.iaId}';
    } else if (result.workKey.isNotEmpty) {
      url = 'https://openlibrary.org${result.workKey}';
    }
    await Clipboard.setData(
        ClipboardData(text: '$url\n${result.title}'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Link copied'),
        backgroundColor: _cDeepRose,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveResult(BookSearchResult result) async {
    HapticFeedback.selectionClick();
    final userName = context.read<AuthService>().currentUser ?? '';
    if (userName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save books'),
          backgroundColor: _cDeepRose,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    await _service.saveToReadList(
        result.toBookItem(), 'to-read', userName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved to your reading list'),
        backgroundColor: _cDeepRose,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSearchEmptyState({
    String title = 'Type to discover magic',
    String subtitle =
        'Search any book, author, or subject across the full database.',
    IconData icon = Icons.travel_explore_rounded,
  }) {
    return ShelfEmptyState(
      icon: icon,
      title: title,
      subtitle: subtitle,
      accent: _cDeepRose,
    );
  }

  // ── READLIST TABS ──────────────────────────────────────────────────

  Color _readBadgeColor(String status) {
    switch (status) {
      case 'read-clair':
        return const Color(0xFFE91E8C);
      case 'read-khent':
        return const Color(0xFF1976D2);
      case 'read-both':
      case 'read':
      default:
        return const Color(0xFF2E7D32);
    }
  }

  Widget _buildReadlistTab({required bool isReadTab}) {
    final list = isReadTab ? _readHistoryList : _toReadList;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.paddingOf(context).top + 14, 20, 0),
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
                      isReadTab ? 'Read' : 'To Read',
                      style: AppTypography.cormorantExtraBold.copyWith(fontSize: 26, color: _cWhite),
                    ),
                    Text(
                      isReadTab ? 'OUR LIBRARY' : 'THE BOOKSHELF',
                      style: AppTypography.outfitHeading.copyWith(fontSize: 9, color: _cMuted, letterSpacing: 2.0),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _cDeepRose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _cDeepRose.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${list.length}',
                  style: AppTypography.outfitWhite.copyWith(color: _cDeepRose, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: list.isEmpty
              ? ShelfEmptyState(
                  icon: isReadTab
                      ? Icons.auto_stories_outlined
                      : Icons.bookmark_border_rounded,
                  title: isReadTab
                      ? 'Your read history is empty'
                      : 'Nothing queued yet',
                  subtitle: isReadTab
                      ? 'Books you mark as read will live here so you can revisit them anytime.'
                      : 'Tap the bookmark on any book to add it to your reading queue.',
                  accent: _cAmber,
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: AppBreakpoint.isDesktop(context)
                        ? 6
                        : (AppBreakpoint.isTablet(context) ? 4 : 2),
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return ShelfPosterCard(
                      imageUrl: item.coverUrl,
                      title: item.title,
                      subtitle: item.author.isNotEmpty
                          ? 'by ${item.author}'
                          : (item.year.isNotEmpty ? item.year : null),
                      badge: isReadTab
                          ? item.readDisplay.toUpperCase()
                          : 'TO READ',
                      badgeColor: isReadTab
                          ? _readBadgeColor(item.status)
                          : _cAmber,
                      badgeIcon: isReadTab
                          ? Icons.check_rounded
                          : Icons.bookmark_rounded,
                      onTap: () => _showBookDetails(item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── SHIMMER LOADING ────────────────────────────────────────────────

  Widget _buildShimmerHome() {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.paddingOf(context).top + 14, 20, 20),
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
          child: ShimmerPosterRow(height: 240, width: 150, count: 6),
        ),
      ],
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────

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
          icon: Icons.bookmark_border_rounded,
          activeIcon: Icons.bookmark_rounded,
          label: 'Queue',
        ),
        ShelfNavItem(
          icon: Icons.auto_stories_outlined,
          activeIcon: Icons.auto_stories_rounded,
          label: 'Read',
        ),
      ],
    );
  }
}

class _RankingTile extends StatelessWidget {
  final BookItem item;
  final int rank;
  final VoidCallback onTap;

  const _RankingTile({
    required this.item,
    required this.rank,
    required this.onTap,
  });

  Color get _rankColor {
    switch (rank) {
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
    final isTop3 = rank <= 3;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _cCard.withValues(alpha: 0.5),
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
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _rankColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$rank',
                        style: AppTypography.cormorantBlack.copyWith(fontSize: 18, color: _rankColor),
                      ),
                    )
                  : Center(
                      child: Text(
                        '$rank',
                        style: AppTypography.outfitBold.copyWith(fontSize: 14, color: _cMuted),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 62,
                child: item.coverUrl.isNotEmpty
                    ? Image.network(item.coverUrl, fit: BoxFit.cover)
                    : Container(color: _cCard),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitHeading.copyWith(color: _cWhite, fontSize: 13),
                  ),
                  if (item.author.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitWhite.copyWith(color: _cMuted, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (item.year.isNotEmpty) ...[
                        Text(
                          item.year,
                          style: AppTypography.outfitBold.copyWith(color: _cGold, fontSize: 11),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _cDeepRose.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'BOOK',
                          style: AppTypography.outfitWhite.copyWith(color: _cDeepRose, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: _cMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _RowAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.3,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 15),
            ),
          ),
        ),
      ),
    );
  }
}
