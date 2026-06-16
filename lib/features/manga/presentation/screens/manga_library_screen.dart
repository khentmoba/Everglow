import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';
import 'package:everglow/features/manga/data/services/comick_service.dart';
import 'package:everglow/features/manga/data/services/mangadex_service.dart';
import 'package:everglow/features/manga/presentation/widgets/manga_details_drawer.dart';
import 'package:everglow/features/manga/presentation/widgets/manga_search_modal.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/shared/widgets/shelf/atmospheric_backdrop.dart';
import 'package:everglow/shared/widgets/shelf/scroll_edge_fade.dart';
import 'package:everglow/shared/widgets/shelf/shelf_hero_carousel.dart';
import 'package:everglow/shared/widgets/shelf/shelf_icon_button.dart';
import 'package:everglow/shared/widgets/shelf/shelf_poster_card.dart';
import 'package:everglow/shared/widgets/shelf/shelf_section_header.dart';
import 'package:everglow/shared/widgets/shelf/shelf_empty_state.dart';
import 'package:everglow/shared/widgets/shelf/shimmer_box.dart';
import 'package:everglow/shared/widgets/shelf/shelf_pill_bottom_nav.dart';
import 'package:everglow/shared/widgets/shelf/staggered_entrance.dart';

const _cBlack = Color(0xFF080810);
const _cCard = Color(0xFF1C1228);
const _cRose = Color(0xFFF4C2C2);
const _cDeepRose = Color(0xFFC2185B);
const _cGold = Color(0xFFE8C97A);
const _cWhite = Color(0xFFFFF5F5);
const _cMuted = Color(0xFF8A7A92);

/// Main entry for the manga feature. Three-tab IndexedStack:
///   * Home    — Trending + Latest Updates carousels, content-type
///               filter chips, "Continue Reading" rail.
///   * Library — Personal collection (per-user Firestore stream).
///   * Search  — Full search modal with MangaDex results.
///
/// Mirrors `CinemaScreen` from the cinema feature.
class MangaLibraryScreen extends StatefulWidget {
  const MangaLibraryScreen({Key? key}) : super(key: key);

  @override
  State<MangaLibraryScreen> createState() => _MangaLibraryScreenState();
}

class _MangaLibraryScreenState extends State<MangaLibraryScreen>
    with TickerProviderStateMixin {
  final MangaDexService _service = MangaDexService();
  final ComickService _comick = ComickService();
  int _currentIndex = 0;

  StreamSubscription<List<MangaItem>>? _librarySub;
  List<MangaItem> _library = [];

  // Content-type filter: '' = all, 'jp' = manga, 'ko' = manhwa, 'cn' = manhua
  String _selectedLanguage = '';

  // Home tab carousels
  List<MangaItem> _popular = [];
  List<MangaItem> _latest = [];
  List<MangaItem> _mangaList = [];
  List<MangaItem> _manhwaList = [];
  List<MangaItem> _manhuaList = [];
  bool _isLoadingHome = true;
  String? _homeError;

  // Continue reading — items with lastReadChapterId
  List<MangaItem> get _continueReading => _library
      .where((i) => i.lastReadChapterId.isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final user = context.read<AuthService>().currentUser ?? '';
    if (user.isNotEmpty) {
      final cached = await _service.getCachedLibrary(user);
      if (cached.isNotEmpty && mounted) {
        setState(() => _library = cached);
      }
      _librarySub = _service.getLibraryStream(user).listen((items) {
        if (!mounted) return;
        setState(() => _library = items);
      });
    }
    await _loadHome();
  }

  Future<void> _loadHome() async {
    setState(() {
      _isLoadingHome = true;
      _homeError = null;
    });
    try {
      final results = await Future.wait([
        _comick.fetchPopular(),
        _comick.fetchLatest(),
        _comick.fetchPopular(country: 'jp'),
        _comick.fetchPopular(country: 'ko'),
        _comick.fetchPopular(country: 'cn'),
      ]);
      if (!mounted) return;
      setState(() {
        _popular = results[0];
        _latest = results[1];
        _mangaList = results[2];
        _manhwaList = results[3];
        _manhuaList = results[4];
        _isLoadingHome = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHome = false;
        _homeError = 'Could not load library. Pull down to retry.';
      });
    }
  }

  @override
  void dispose() {
    _librarySub?.cancel();
    super.dispose();
  }

  void _openSearch(String initialLanguage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MangaSearchModal(initialLanguage: initialLanguage),
    );
  }

  void _openDetails(MangaItem item) {
    // Refresh the item with current library state
    final liveItem = _library.firstWhere(
      (l) => l.mangaId == item.mangaId,
      orElse: () => item,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MangaDetailsDrawer(item: liveItem),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBlack,
      body: Stack(
        children: [
          const ShelfAtmosphericBackdrop(
            glows: [
              RadialGlow(
                color: AppTheme.roseQuartz,
                alignment: Alignment(-0.7, -0.85),
                size: 0.85,
                opacity: 0.13,
              ),
              RadialGlow(
                color: AppTheme.deepRose,
                alignment: Alignment(0.85, 0.95),
                size: 0.8,
                opacity: 0.12,
              ),
            ],
          ),
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeTab(),
                _buildLibraryTab(),
                _buildSearchTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return ShelfPillBottomNav(
      currentIndex: _currentIndex,
      onTap: (i) {
        if (i == 2) {
          setState(() => _currentIndex = i);
          _openSearch(_selectedLanguage);
        } else {
          setState(() => _currentIndex = i);
        }
      },
      items: const [
        ShelfNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        ShelfNavItem(
          icon: Icons.collections_bookmark_outlined,
          activeIcon: Icons.collections_bookmark_rounded,
          label: 'Library',
        ),
        ShelfNavItem(
          icon: Icons.search_rounded,
          activeIcon: Icons.search_rounded,
          label: 'Search',
        ),
      ],
    );
  }

  // ── HOME TAB ───────────────────────────────────────────────────────

  Widget _buildHomeTab() {
    return RefreshIndicator(
      color: _cDeepRose,
      backgroundColor: _cCard,
      onRefresh: _loadHome,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          StaggeredEntrance(index: 0, child: _buildHeader()),
          const SizedBox(height: 8),
          StaggeredEntrance(
            index: 1,
            child: _buildLanguageFilter(),
          ),
          const SizedBox(height: 16),
          if (_popular.isNotEmpty)
            StaggeredEntrance(
              index: 2,
              child: _buildHeroFromPopular(_popular),
            ),
          if (_continueReading.isNotEmpty) ...[
            StaggeredEntrance(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: ShelfSectionHeader(
                  eyebrow: 'Pick Up Where You Left Off',
                  title: 'Continue Reading',
                  icon: Icons.menu_book_rounded,
                  accent: _cDeepRose,
                  count: _continueReading.length,
                  countLabel: 'titles',
                ),
              ),
            ),
            _buildCoverRow(_continueReading, height: 230, width: 130),
            const SizedBox(height: 24),
          ],
          StaggeredEntrance(
            index: 4,
            child: _buildLibrarySectionHeader(
              'Trending Now',
              'Fan favourites this week',
              Icons.local_fire_department_rounded,
              _cGold,
              _popular,
            ),
          ),
          StaggeredEntrance(
            index: 5,
            child: _buildLibrarySectionHeader(
              'Latest Updates',
              'New chapters hot off the press',
              Icons.fiber_new_rounded,
              const Color(0xFF42A5F5),
              _latest,
              height: 230,
            ),
          ),
          StaggeredEntrance(
            index: 6,
            child: _buildLibrarySectionHeader(
              'Top Manga',
              'Japanese',
              Icons.translate_rounded,
              const Color(0xFFE91E63),
              _mangaList,
            ),
          ),
          StaggeredEntrance(
            index: 7,
            child: _buildLibrarySectionHeader(
              'Top Manhwa',
              'Korean',
              Icons.translate_rounded,
              const Color(0xFFE91E63),
              _manhwaList,
            ),
          ),
          StaggeredEntrance(
            index: 8,
            child: _buildLibrarySectionHeader(
              'Top Manhua',
              'Chinese',
              Icons.translate_rounded,
              const Color(0xFF00BCD4),
              _manhuaList,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroFromPopular(List<MangaItem> items) {
    final heroItems = items.take(5).map((m) {
      return ShelfHeroItem(
        id: m.mangaId,
        title: m.title,
        subtitle: '${m.contentType.toUpperCase()} · ${m.year}',
        eyebrow: 'Trending #${items.indexOf(m) + 1}',
        imageUrl: m.coverUrl,
        accent: _accentForLanguage(m.originalLanguage),
        onTap: () => _openDetails(m),
      );
    }).toList();

    return ShelfHeroCarousel(
      items: heroItems,
      holdDuration: const Duration(seconds: 8),
      height: 320,
    );
  }

  Widget _buildLibrarySectionHeader(
    String title,
    String eyebrow,
    IconData icon,
    Color accent,
    List<MangaItem> items, {
    double height = 230,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: ShelfSectionHeader(
            eyebrow: eyebrow,
            title: title,
            icon: icon,
            accent: accent,
            count: items.length,
            countLabel: 'titles',
          ),
        ),
        _buildCoverRow(items, height: height, width: 130, accent: accent),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeader() {
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
      child: Row(
        children: [
          if (canPop)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ShelfIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                semanticLabel: 'Back',
                tooltip: 'Back',
                onTap: () => Navigator.pop(context),
              ),
            )
          else
            const SizedBox(width: 48),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_cDeepRose, _cGold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _cDeepRose.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: _cWhite, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Manga Shelf',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: _cRose,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Manga · Manhwa · Manhua',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: _cRose.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          ShelfIconButton(
            icon: Icons.search_rounded,
            semanticLabel: 'Search Manga',
            tooltip: 'Search manga',
            onTap: () => _openSearch(_selectedLanguage),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _LangFilterChip(
            label: 'All',
            icon: Icons.public_rounded,
            selected: _selectedLanguage == '',
            onTap: () => setState(() => _selectedLanguage = ''),
          ),
          const SizedBox(width: 8),
          _LangFilterChip(
            label: 'Manga',
            icon: Icons.translate_rounded,
            selected: _selectedLanguage == 'jp',
            onTap: () => setState(() => _selectedLanguage = 'jp'),
          ),
          const SizedBox(width: 8),
          _LangFilterChip(
            label: 'Manhwa',
            icon: Icons.translate_rounded,
            selected: _selectedLanguage == 'ko',
            onTap: () => setState(() => _selectedLanguage = 'ko'),
          ),
          const SizedBox(width: 8),
          _LangFilterChip(
            label: 'Manhua',
            icon: Icons.translate_rounded,
            selected: _selectedLanguage == 'cn',
            onTap: () => setState(() => _selectedLanguage = 'cn'),
          ),
        ],
      ),
    );
  }

  Color _accentForLanguage(String lang) {
    switch (lang) {
      case 'ko':
        return const Color(0xFFE91E63);
      case 'zh':
        return const Color(0xFF00BCD4);
      default:
        return AppTheme.deepRose;
    }
  }

  Widget _buildCoverRow(
    List<MangaItem> items, {
    required double height,
    required double width,
    Color? accent,
  }) {
    if (_isLoadingHome) {
      return ScrollEdgeFade(
        fadeColor: _cBlack,
        child: SizedBox(
          height: height,
          child: ShimmerPosterRow(
            height: height,
            width: width,
            count: 6,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
        ),
      );
    }
    if (items.isEmpty) {
      if (_homeError != null && !_isLoadingHome) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              const Icon(Icons.cloud_off, color: _cMuted, size: 32),
              const SizedBox(height: 8),
              Text(
                _homeError!,
                style: GoogleFonts.outfit(
                  color: _cMuted,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _loadHome(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _cDeepRose.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _cDeepRose.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.outfit(
                      color: _cRose,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Text(
          'Nothing here yet.',
          style: GoogleFonts.outfit(
            color: _cMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return ScrollEdgeFade(
      fadeColor: _cBlack,
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final typeAccent =
                accent ?? _accentForLanguage(item.originalLanguage);
            return SizedBox(
              width: width,
              child: ShelfPosterCard(
                imageUrl: item.coverUrl,
                title: item.title,
                subtitle: item.year.isNotEmpty
                    ? '${item.contentType} · ${item.year}'
                    : item.contentType,
                badge: item.contentType.toUpperCase(),
                badgeColor: typeAccent,
                badgeIcon: Icons.menu_book_rounded,
                onTap: () => _openDetails(item),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── LIBRARY TAB ────────────────────────────────────────────────────

  int _libraryTab = 0;

  Widget _buildLibraryTab() {
    final buckets = <_LibraryBucket>[
      _LibraryBucket(
        title: 'Reading',
        icon: Icons.menu_book_rounded,
        accent: _cDeepRose,
        items: _library.where((i) => i.isReading).toList(),
      ),
      _LibraryBucket(
        title: 'Plan to Read',
        icon: Icons.bookmark_outline_rounded,
        accent: _cGold,
        items: _library.where((i) => i.isPlanToRead).toList(),
      ),
      _LibraryBucket(
        title: 'Completed',
        icon: Icons.check_circle_outline_rounded,
        accent: const Color(0xFF8BC34A),
        items: _library.where((i) => i.isCompleted).toList(),
      ),
      _LibraryBucket(
        title: 'On Hold',
        icon: Icons.pause_circle_outline_rounded,
        accent: const Color(0xFFFFB74D),
        items: _library.where((i) => i.isOnHold).toList(),
      ),
      _LibraryBucket(
        title: 'Dropped',
        icon: Icons.cancel_outlined,
        accent: _cMuted,
        items: _library.where((i) => i.isDropped).toList(),
      ),
    ];

    if (_library.isEmpty) {
      return ShelfEmptyState(
        icon: Icons.collections_bookmark_outlined,
        title: 'Your manga shelf is empty',
        subtitle:
            'Search any title on MangaDex and tap "Add to Library" to start tracking your reading. Continue where you left off from the Home tab.',
        ctaLabel: 'Search Manga',
        ctaIcon: Icons.search_rounded,
        onCta: () => _openSearch(_selectedLanguage),
        accent: _cDeepRose,
      );
    }

    final activeBucket =
        buckets.firstWhere((b) => b.items.isNotEmpty, orElse: () => buckets.first);
    final safeIndex = _libraryTab.clamp(0, buckets.length - 1);
    final showing = buckets[safeIndex].items.isNotEmpty
        ? buckets[safeIndex]
        : activeBucket;

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MANGA SHELF',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _cWhite,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: _cDeepRose,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'MANGA · MANHWA · MANHUA',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: _cMuted,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: _cDeepRose,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < buckets.length; i++)
                    _bucketChip(buckets[i], i == safeIndex,
                        () => setState(() => _libraryTab = i)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: ShelfSectionHeader(
            eyebrow: showing.items.isEmpty
                ? 'Nothing here yet'
                : 'Currently Showing',
            title: showing.title,
            icon: showing.icon,
            accent: showing.accent,
            count: showing.items.length,
            countLabel: 'titles',
          ),
        ),
        if (showing.items.isEmpty)
          ShelfEmptyState(
            icon: showing.icon,
            title: 'No ${showing.title.toLowerCase()} titles yet',
            subtitle:
                'Anything you add to your library with this status will show up here.',
            accent: showing.accent,
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: showing.items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (context, index) {
              final item = showing.items[index];
              return ShelfPosterCard(
                imageUrl: item.coverUrl,
                title: item.title,
                subtitle: item.year.isNotEmpty
                    ? '${item.contentType} · ${item.year}'
                    : item.contentType,
                badge: showing.title.toUpperCase(),
                badgeColor: showing.accent,
                badgeIcon: showing.icon,
                onTap: () => _openDetails(item),
              );
            },
          ),
      ],
    );
  }

  Widget _bucketChip(_LibraryBucket bucket, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? bucket.accent.withValues(alpha: 0.18)
              : _cCard.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? bucket.accent.withValues(alpha: 0.5)
                : _cRose.withValues(alpha: 0.12),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(bucket.icon, color: selected ? bucket.accent : _cMuted, size: 14),
            const SizedBox(width: 6),
            Text(
              bucket.title,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: selected ? bucket.accent : _cRose,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? bucket.accent.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${bucket.items.length}',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : _cMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SEARCH TAB (placeholder, opens modal) ──────────────────────────

  Widget _buildSearchTab() {
    return ShelfEmptyState(
      icon: Icons.search_rounded,
      title: 'Find Your Next Read',
      subtitle:
          'Search MangaDex by title. Tap any cover to add it to your library, mark chapters as read, and continue where you left off.',
      ctaLabel: 'Open Search',
      ctaIcon: Icons.search_rounded,
      onCta: () => _openSearch(_selectedLanguage),
      accent: _cDeepRose,
    );
  }
}

class _LibraryBucket {
  final String title;
  final IconData icon;
  final Color accent;
  final List<MangaItem> items;
  const _LibraryBucket({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
  });
}

class _LangFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _LangFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? _cDeepRose.withValues(alpha: 0.2)
              : _cCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? _cDeepRose
                : _cRose.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? _cWhite : _cRose, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: selected ? _cWhite : _cRose,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
