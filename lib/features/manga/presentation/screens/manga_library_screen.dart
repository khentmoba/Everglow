import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/features/manga/data/models/manga_item.dart';
import 'package:everglow/features/manga/data/services/comick_service.dart';
import 'package:everglow/features/manga/data/services/mangadex_service.dart';
import 'package:everglow/features/manga/presentation/widgets/manga_cover_card.dart';
import 'package:everglow/features/manga/presentation/widgets/manga_details_drawer.dart';
import 'package:everglow/features/manga/presentation/widgets/manga_search_modal.dart';
import 'package:everglow/services/auth_service.dart';

const _cBlack = Color(0xFF080810);
const _cVelvet = Color(0xFF12091A);
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
      body: SafeArea(
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
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _cVelvet,
        border: Border(
          top: BorderSide(
            color: _cRose.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _NavItem(
                icon: Icons.collections_bookmark_rounded,
                label: 'Library',
                selected: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              _NavItem(
                icon: Icons.search_rounded,
                label: 'Search',
                selected: _currentIndex == 2,
                onTap: () {
                  setState(() => _currentIndex = 2);
                  _openSearch(_selectedLanguage);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HOME TAB ───────────────────────────────────────────────────────

  Widget _buildHomeTab() {
    return RefreshIndicator(
      color: _cDeepRose,
      onRefresh: _loadHome,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          _buildLanguageFilter(),
          const SizedBox(height: 16),
          if (_continueReading.isNotEmpty) ...[
            _buildSectionTitle('Continue Reading', icon: Icons.bookmark),
            _buildCoverRow(_continueReading, height: 180, width: 120),
            const SizedBox(height: 24),
          ],
          _buildSectionTitle(
            'Trending Now',
            icon: Icons.local_fire_department_rounded,
          ),
          _buildCoverRow(_popular, height: 200, width: 130),
          const SizedBox(height: 24),
          _buildSectionTitle(
            'Latest Updates',
            icon: Icons.fiber_new_rounded,
          ),
          _buildCoverRow(_latest, height: 180, width: 120),
          const SizedBox(height: 24),
          _buildSectionTitle('Top Manga', icon: Icons.translate),
          _buildCoverRow(_mangaList, height: 200, width: 130),
          const SizedBox(height: 24),
          _buildSectionTitle('Top Manhwa', icon: Icons.translate),
          _buildCoverRow(_manhwaList, height: 200, width: 130),
          const SizedBox(height: 24),
          _buildSectionTitle('Top Manhua', icon: Icons.translate),
          _buildCoverRow(_manhuaList, height: 200, width: 130),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
      child: Row(
        children: [
          // Back — only when there's a route to pop to (i.e. the user
          // arrived here from the dashboard). Without this, the only
          // way out is the browser back button, which breaks nested
          // routes and on iOS Safari sometimes reloads the app.
          if (canPop)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _cRose.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _cRose,
                  size: 18,
                ),
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
          IconButton(
            onPressed: () => _openSearch(_selectedLanguage),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _cRose.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search, color: _cRose, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _LangFilterChip(
            label: 'All',
            selected: _selectedLanguage == '',
            onTap: () => setState(() => _selectedLanguage = ''),
          ),
          const SizedBox(width: 8),
          _LangFilterChip(
            label: '🇯🇵 Manga',
            selected: _selectedLanguage == 'jp',
            onTap: () => setState(() => _selectedLanguage = 'jp'),
          ),
          const SizedBox(width: 8),
          _LangFilterChip(
            label: '🇰🇷 Manhwa',
            selected: _selectedLanguage == 'ko',
            onTap: () => setState(() => _selectedLanguage = 'ko'),
          ),
          const SizedBox(width: 8),
          _LangFilterChip(
            label: '🇨🇳 Manhua',
            selected: _selectedLanguage == 'cn',
            onTap: () => setState(() => _selectedLanguage = 'cn'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: [
          Icon(icon, color: _cRose, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _cRose,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverRow(
    List<MangaItem> items, {
    required double height,
    required double width,
  }) {
    if (_isLoadingHome) {
      return SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => Container(
            width: width,
            decoration: BoxDecoration(
              color: _cCard,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Text(
          'Nothing here yet.',
          style: GoogleFonts.outfit(
            color: _cMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: width,
            child: MangaCoverCard(
              item: items[index],
              onTap: () => _openDetails(items[index]),
            ),
          );
        },
      ),
    );
  }

  // ── LIBRARY TAB ────────────────────────────────────────────────────

  Widget _buildLibraryTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Text(
            'My Library',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _cRose,
            ),
          ),
        ),
        _buildLibrarySection('Reading', _library.where((i) => i.isReading).toList()),
        _buildLibrarySection('Plan to Read', _library.where((i) => i.isPlanToRead).toList()),
        _buildLibrarySection('Completed', _library.where((i) => i.isCompleted).toList()),
        _buildLibrarySection('On Hold', _library.where((i) => i.isOnHold).toList()),
        _buildLibrarySection('Dropped', _library.where((i) => i.isDropped).toList()),
      ],
    );
  }

  Widget _buildLibrarySection(String title, List<MangaItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: _cGold,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            return MangaCoverCard(
              item: items[index],
              onTap: () => _openDetails(items[index]),
            );
          },
        ),
      ],
    );
  }

  // ── SEARCH TAB (placeholder, opens modal) ──────────────────────────

  Widget _buildSearchTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _cCard,
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: _cRose,
                  size: 64,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeInUp(
              child: Text(
                'Find Your Next Read',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _cRose,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Text(
                'Tap below to open the search dialog',
                style: GoogleFonts.outfit(
                  color: _cMuted,
                ),
              ),
            ),
            const SizedBox(height: 32),
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: ElevatedButton.icon(
                onPressed: () => _openSearch(_selectedLanguage),
                icon: const Icon(Icons.search),
                label: const Text('Open Search'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? _cDeepRose : _cMuted, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: selected ? _cRose : _cMuted,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangFilterChip({
    required this.label,
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
          color: selected ? _cDeepRose : _cCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _cDeepRose : _cRose.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: selected ? _cWhite : _cRose,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
