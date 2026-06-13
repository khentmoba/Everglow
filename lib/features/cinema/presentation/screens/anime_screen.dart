import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/features/cinema/presentation/widgets/tmdb_search_modal.dart';
import 'package:everglow/services/auth_service.dart';

// Mirror of cinema_screen.dart / manga_library_screen.dart color tokens so
// the anime feature feels native to the rest of the cinema feature.
const _cBlack = Color(0xFF080810);
const _cVelvet = Color(0xFF12091A);
const _cCard = Color(0xFF1C1228);
const _cRose = Color(0xFFF4C2C2);
const _cDeepRose = Color(0xFFC2185B);
const _cGold = Color(0xFFE8C97A);
const _cWhite = Color(0xFFFFF5F5);
const _cMuted = Color(0xFF8A7A92);

/// Dedicated entry for the anime rail. Mirrors `MangaLibraryScreen`'s
/// three-tab structure (Home / Library / Search) but is scoped to
/// Japanese animation:
///
///   * Home     — Trending anime from TMDB (filtered by
///                `original_language=ja` + Animation genre).
///   * Library  — Couple's combined anime catalog split into
///                "Want to Watch" + "Watched" with partner attribution.
///   * Search   — Opens [TMDBSearchModal]; the auto-detect in the
///                episode drawer picks up anime from the results
///                automatically, so search isn't filtered here.
class AnimeScreen extends StatefulWidget {
  const AnimeScreen({Key? key}) : super(key: key);

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen>
    with TickerProviderStateMixin {
  final TMDBService _tmdbService = TMDBService();
  int _currentIndex = 0;

  // Library / watchlist
  StreamSubscription<List<MediaItem>>? _watchlistSub;
  List<MediaItem> _library = [];

  // Home tab
  List<MediaItem> _trending = [];
  bool _isLoadingHome = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _subscribeToLibrary();
    });
    await _loadHome();
  }

  void _subscribeToLibrary() {
    final auth = context.read<AuthService>();
    final isCouple = auth.isCoupleUser;
    final userName = auth.currentUser ?? '';
    if (userName.isEmpty) return;

    _watchlistSub?.cancel();
    _watchlistSub = (isCouple
            ? _tmdbService.getCoupleAnimeStream()
            : _tmdbService.getAnimeWatchListStream(userName))
        .listen((items) {
      if (!mounted) return;
      setState(() => _library = items);
    });
  }

  Future<void> _loadHome() async {
    setState(() => _isLoadingHome = true);
    final results = await _tmdbService.fetchTrendingAnime();
    if (!mounted) return;
    setState(() {
      _trending = results;
      _isLoadingHome = false;
    });
  }

  @override
  void dispose() {
    _watchlistSub?.cancel();
    super.dispose();
  }

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TMDBSearchModal(),
    );
  }

  void _openDetails(MediaItem item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EpisodeDrawer(item: item),
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
                  _openSearch();
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
          _buildSectionTitle('Trending Anime',
              icon: Icons.local_fire_department_rounded),
          _buildPosterRow(_trending, height: 200, width: 130),
          const SizedBox(height: 24),
          if (_library.where((i) => i.isToWatch).isNotEmpty) ...[
            _buildSectionTitle('In Your Queue',
                icon: Icons.bookmark_rounded),
            _buildPosterRow(
              _library.where((i) => i.isToWatch).toList(),
              height: 180,
              width: 120,
            ),
            const SizedBox(height: 24),
          ],
          if (_library.where((i) => i.isWatched).isNotEmpty) ...[
            _buildSectionTitle('Watched', icon: Icons.remove_red_eye_rounded),
            _buildPosterRow(
              _library.where((i) => i.isWatched).toList(),
              height: 180,
              width: 120,
            ),
            const SizedBox(height: 24),
          ],
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
            child: const Icon(Icons.animation_rounded,
                color: _cWhite, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Everglow Anime',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: _cRose,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Japanese Animation',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: _cRose.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openSearch,
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

  Widget _buildPosterRow(
    List<MediaItem> items, {
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
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => Container(
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
          'Nothing here yet. Search above to add your first anime!',
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
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: width,
            child: _AnimePosterTile(
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
    final wantToWatch =
        _library.where((i) => i.isToWatch).toList();
    final watched = _library.where((i) => i.isWatched).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Text(
            'Our Anime',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _cRose,
            ),
          ),
        ),
        _buildLibrarySection('Want to Watch', wantToWatch),
        _buildLibrarySection('Watched', watched),
      ],
    );
  }

  Widget _buildLibrarySection(String title, List<MediaItem> items) {
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
            return _AnimePosterTile(
              item: items[index],
              onTap: () => _openDetails(items[index]),
            );
          },
        ),
      ],
    );
  }

  // ── SEARCH TAB (placeholder) ──────────────────────────────────────

  Widget _buildSearchTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _cCard,
              ),
              child: const Icon(
                Icons.search_rounded,
                color: _cRose,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Find Your Next Anime',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _cRose,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anime is auto-detected from your saves.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: _cMuted,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openSearch,
              icon: const Icon(Icons.search),
              label: const Text('Open Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cDeepRose,
                foregroundColor: _cWhite,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── EXTRACTED WIDGETS ─────────────────────────────────────────────

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

/// Compact poster tile used in the home + library carousels. Tapping it
/// opens the standard [EpisodeDrawer] so users can manage their
/// watchlist / play state without leaving the screen.
class _AnimePosterTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const _AnimePosterTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            item.posterPath.isNotEmpty
                ? Image.network(item.posterPath, fit: BoxFit.cover)
                : Container(
                    color: _cVelvet,
                    child: Icon(
                      Icons.animation_rounded,
                      color: _cRose.withValues(alpha: 0.4),
                      size: 28,
                    ),
                  ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _cDeepRose.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ANIME',
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    color: _cWhite,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
