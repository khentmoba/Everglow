import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/features/books/data/models/book_item.dart';
import 'package:everglow/features/books/data/services/open_library_service.dart';
import 'package:everglow/features/books/presentation/screens/our_books_screen.dart';
import 'package:everglow/features/books/presentation/widgets/book_cover_card.dart';
import 'package:everglow/features/books/presentation/widgets/book_details_drawer.dart';
import 'package:everglow/services/auth_service.dart';

const _cBlack = Color(0xFF080810);
const _cVelvet = Color(0xFF12091A);
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
  const BooksScreen({Key? key}) : super(key: key);

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen>
    with TickerProviderStateMixin {
  final OpenLibraryService _service = OpenLibraryService();
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
  List<BookItem> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

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
    final results = await _service.searchBooks(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _showBookDetails(BookItem item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookDetailsDrawer(item: item),
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
            _buildReadlistTab(isReadTab: false),
            _buildReadlistTab(isReadTab: true),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // ── HOME TAB ───────────────────────────────────────────────────────

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
        ..._buildSubjectRows(),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
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
          if (canPop)
            _iconBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            )
          else
            const SizedBox(width: 40, height: 40),
          const Spacer(),
          Column(
            children: [
              Text(
                'OUR BOOKS',
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
          if (isCouple)
            _iconBtn(
              icon: Icons.favorite_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OurBooksScreen()),
              ),
            )
          else
            const SizedBox(width: 40, height: 40),
          const SizedBox(width: 8),
          _iconBtn(
            icon: Icons.search_rounded,
            onTap: () => _switchTab(1),
          ),
        ],
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
                            Container(color: _cVelvet))
                    : Container(color: _cVelvet),
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
                        ],
                      ),
                      const SizedBox(height: 10),
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
                      if (item.author.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'by ${item.author}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: _cWhite.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
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

  // ── TRENDING RANKINGS ──────────────────────────────────────────────

  Widget _buildTrendingRankings() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChapterHeader('Trending', 'Now',
              Icons.emoji_events_rounded,
              accentColor: _cAmber),
          const SizedBox(height: 16),
          SizedBox(
            height: 480,
            child: _trendingRankings.isEmpty
                ? _buildEmptyState('No rankings available',
                    icon: Icons.emoji_events_outlined)
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

  // ── SUBJECT ROWS ───────────────────────────────────────────────────

  List<Widget> _buildSubjectRows() {
    final rows = <Widget>[];
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
          child: _buildSection(name, 'Books', items,
              accentColor: color, icon: icon),
        ),
      );
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
          child: _buildChapterHeader(title, subtitle, icon,
              accentColor: accentColor),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: SizedBox(
                  width: 145,
                  child: BookCoverCard(
                    item: items[index],
                    onTap: () => _showBookDetails(items[index]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChapterHeader(
    String title,
    String subtitle,
    IconData? icon, {
    Color accentColor = _cRose,
  }) {
    return Row(
      children: [
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
        if (icon != null) ...[
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(width: 8),
        ],
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

  // ── SEARCH TAB ─────────────────────────────────────────────────────

  Widget _buildSearchTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 14, 20, 0),
          child: Row(
            children: [
              _iconBtn(
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
                hintText: 'Books, authors, subjects...',
                hintStyle:
                    GoogleFonts.outfit(color: _cMuted, fontSize: 15),
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
              : _searchResults.isEmpty
                  ? _buildSearchEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.6,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        return BookCoverCard(
                          item: _searchResults[index],
                          onTap: () => _showBookDetails(_searchResults[index]),
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
      icon: Icons.menu_book_outlined,
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
              20, MediaQuery.of(context).padding.top + 14, 20, 0),
          child: Row(
            children: [
              _iconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => _switchTab(0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReadTab ? 'Read' : 'To Read',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _cWhite,
                      ),
                    ),
                    Text(
                      isReadTab ? 'OUR LIBRARY' : 'THE BOOKSHELF',
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
                  isReadTab
                      ? 'Your read history is empty'
                      : 'Nothing queued yet',
                  icon: isReadTab
                      ? Icons.auto_stories_outlined
                      : Icons.bookmark_border_rounded,
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.6,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return BookCoverCard(
                      item: item,
                      onTap: () => _showBookDetails(item),
                      statusBadge: isReadTab
                          ? item.readDisplay.toUpperCase()
                          : 'TO READ',
                      badgeColor: isReadTab
                          ? _readBadgeColor(item.status)
                          : _cAmber,
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
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 6,
              itemBuilder: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _shimmerBox(width: 145, height: 240, radius: 14),
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

  // ── EMPTY STATE ────────────────────────────────────────────────────

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
            style: GoogleFonts.outfit(color: _cMuted, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────

  Widget _buildBottomNavBar() {
    final items = [
      _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
      ),
      _NavItem(
        icon: Icons.search_rounded,
        activeIcon: Icons.search_rounded,
        label: 'Search',
      ),
      _NavItem(
        icon: Icons.bookmark_border_rounded,
        activeIcon: Icons.bookmark_rounded,
        label: 'Queue',
      ),
      _NavItem(
        icon: Icons.auto_stories_outlined,
        activeIcon: Icons.auto_stories_rounded,
        label: 'Read',
      ),
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
          color: isActive
              ? _cDeepRose.withValues(alpha: 0.15)
              : Colors.transparent,
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

  Widget _iconBtn({required IconData icon, required VoidCallback onTap}) {
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

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
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
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _rankColor,
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        '$rank',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _cMuted,
                        ),
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
                    style: GoogleFonts.outfit(
                      color: _cWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (item.author.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: _cMuted,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (item.year.isNotEmpty) ...[
                        Text(
                          item.year,
                          style: GoogleFonts.outfit(
                            color: _cGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
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
            const Icon(Icons.chevron_right_rounded,
                color: _cMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

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
