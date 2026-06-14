import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/features/cinema/data/anime_categories.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/jikan_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/features/cinema/presentation/widgets/jikan_search_modal.dart';
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

/// Dedicated entry for the anime rail. Four tabs:
///   * Home     — Leads with Trending Now + Currently Airing (the two
///                hooks for both casuals and hardcore fans), followed
///                by Top Rated, Popular All Time, New Releases, Hidden
///                Gems, Editor's Picks, and the user's own queue.
///   * Browse   — Filterable chips for By Format, By Genre, By Status,
///                and Discovery. Tapping a chip loads its results
///                inline below the chip row.
///   * Library  — Couple's combined anime catalog split into
///                "Want to Watch" + "Watched" with partner attribution.
///   * Search   — Opens [TMDBSearchModal]; the auto-detect in the
///                episode drawer picks up anime from the results.
class AnimeScreen extends StatefulWidget {
  const AnimeScreen({Key? key}) : super(key: key);

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen>
    with TickerProviderStateMixin {
  final JikanService _jikanService = JikanService();
  // Kept around for the shared watchlist / Firestore plumbing; the
  // anime screen itself only reads from Jikan + AniList.
  final TMDBService _tmdbService = TMDBService();
  int _currentIndex = 0;

  // Library / watchlist
  StreamSubscription<List<MediaItem>>? _watchlistSub;
  List<MediaItem> _library = [];

  // Home tab — one slot per curated row. Each slot owns its own
  // loading flag and result list so the home screen can render them
  // independently and replace one without rerunning the others.
  final Map<String, _AnimeRow> _homeRows = {};
  late final List<_HomeSection> _homeSections;

  // Browse tab
  String? _selectedCategoryId;
  final Map<String, _AnimeRow> _browseResults = {};

  @override
  void initState() {
    super.initState();
    _homeSections = _buildHomeSections();
    _bootstrap();
  }

  List<_HomeSection> _buildHomeSections() => [
        _HomeSection(
          id: 'trending',
          title: 'Trending Now',
          icon: Icons.local_fire_department_rounded,
          tint: const Color(0xFFFF7043),
          builder: () => _jikanService.fetchTopAiring(),
          isHero: true,
        ),
        _HomeSection(
          id: 'airing',
          title: 'Currently Airing',
          icon: Icons.live_tv_rounded,
          tint: const Color(0xFFE53935),
          builder: () => _jikanService.fetchSeasonNow(),
        ),
        _HomeSection(
          id: 'top-rated',
          title: 'Top Rated',
          icon: Icons.star_rounded,
          tint: const Color(0xFFFFCA28),
          builder: () => _jikanService.fetchTopAnime(
            type: 'tv',
            filter: 'favorite',
          ),
        ),
        _HomeSection(
          id: 'new-releases',
          title: 'New Releases',
          icon: Icons.fiber_new_rounded,
          tint: const Color(0xFF42A5F5),
          builder: () => _jikanService.fetchNewReleases(),
        ),
        _HomeSection(
          id: 'popular-all',
          title: 'Popular All Time',
          icon: Icons.public_rounded,
          tint: const Color(0xFFAB47BC),
          builder: () => _jikanService.fetchTopAnime(
            type: 'tv',
            filter: 'bypopularity',
          ),
        ),
        _HomeSection(
          id: 'hidden-gems',
          title: 'Hidden Gems',
          icon: Icons.diamond_rounded,
          tint: const Color(0xFF26C6DA),
          builder: () => _jikanService.fetchHiddenGems(),
        ),
        _HomeSection(
          id: 'editors-picks',
          title: "Editor's Picks",
          icon: Icons.workspace_premium_rounded,
          tint: const Color(0xFFEC407A),
          builder: () =>
              animeCategoryOptions.firstWhere((o) => o.id == 'curated-editors-picks')
                  .fetch(_jikanService),
        ),
      ];

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
    for (final section in _homeSections) {
      _homeRows[section.id] ??= _AnimeRow(isLoading: true);
      _runRow(section.id, _homeRows, section.builder);
    }
    if (mounted) setState(() {});
  }

  Future<void> _runRow(
    String id,
    Map<String, _AnimeRow> rows,
    Future<List<MediaItem>> Function() builder,
  ) async {
    try {
      final items = await builder();
      if (!mounted) return;
      rows[id] = _AnimeRow(items: items, isLoading: false);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      rows[id] = _AnimeRow(items: const [], isLoading: false);
      setState(() {});
    }
  }

  Future<void> _refreshHome() async {
    for (final section in _homeSections) {
      _homeRows[section.id] = _AnimeRow(isLoading: true);
    }
    if (mounted) setState(() {});
    await _loadHome();
  }

  Future<void> _selectCategory(AnimeCategoryOption option) async {
    setState(() {
      _selectedCategoryId = option.id;
      _browseResults[option.id] ??= _AnimeRow(isLoading: true);
    });
    await _runRow(option.id, _browseResults, () => option.fetch(_jikanService));
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
      builder: (_) => const JikanSearchModal(),
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
            _buildBrowseTab(),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                icon: Icons.explore_rounded,
                label: 'Browse',
                selected: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              _NavItem(
                icon: Icons.collections_bookmark_rounded,
                label: 'Library',
                selected: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
              _NavItem(
                icon: Icons.search_rounded,
                label: 'Search',
                selected: _currentIndex == 3,
                onTap: () {
                  setState(() => _currentIndex = 3);
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
      onRefresh: _refreshHome,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          for (final section in _homeSections) ...[
            _buildHomeSection(section),
            const SizedBox(height: 24),
          ],
          if (_library.where((i) => i.isToWatch).isNotEmpty) ...[
            _buildSectionTitle('In Your Queue',
                icon: Icons.bookmark_rounded, tint: _cGold),
            _buildPosterRow(
              _library.where((i) => i.isToWatch).toList(),
              height: 180,
              width: 120,
            ),
            const SizedBox(height: 24),
          ],
          if (_library.where((i) => i.isWatched).isNotEmpty) ...[
            _buildSectionTitle('Watched',
                icon: Icons.remove_red_eye_rounded, tint: _cGold),
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

  Widget _buildHomeSection(_HomeSection section) {
    final row = _homeRows[section.id];
    if (row == null) {
      return _buildShimmerRow(height: section.isHero ? 220 : 180);
    }
    if (row.isLoading) {
      return _buildShimmerRow(height: section.isHero ? 220 : 180);
    }
    if (row.items.isEmpty) {
      return const SizedBox.shrink();
    }
    if (section.isHero) {
      return _buildHeroCarousel(row.items);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(section.title,
            icon: section.icon, tint: section.tint),
        _buildPosterRow(row.items, height: 180, width: 120),
      ],
    );
  }

  Widget _buildHeroCarousel(List<MediaItem> items) {
    final pageCtrl = PageController(viewportFraction: 0.78);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Trending Now',
            icon: Icons.local_fire_department_rounded,
            tint: const Color(0xFFFF7043)),
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: pageCtrl,
            padEnds: true,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _AnimeHeroCard(
                  item: item,
                  onTap: () => _openDetails(item),
                ),
              );
            },
          ),
        ),
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

  Widget _buildSectionTitle(String title,
      {required IconData icon, Color tint = _cRose}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: [
          Icon(icon, color: tint, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerRow({required double height}) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Container(
          width: 120,
          decoration: BoxDecoration(
            color: _cCard,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterRow(
    List<MediaItem> items, {
    required double height,
    required double width,
  }) {
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

  // ── BROWSE TAB ─────────────────────────────────────────────────────

  Widget _buildBrowseTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
          child: Text(
            'Browse',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _cRose,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Text(
            'Filter by format, genre, status, or curated list.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: _cRose.withValues(alpha: 0.6),
            ),
          ),
        ),
        ...AnimeCategoryGroup.values.map(_buildBrowseGroup),
        const SizedBox(height: 16),
        if (_selectedCategoryId != null) _buildBrowseResults(),
      ],
    );
  }

  Widget _buildBrowseGroup(AnimeCategoryGroup group) {
    final options =
        animeCategoryOptions.where((o) => o.group == group).toList();
    final groupMeta = _groupMeta(group);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Row(
              children: [
                Icon(groupMeta.icon, color: groupMeta.tint, size: 18),
                const SizedBox(width: 8),
                Text(
                  groupMeta.title,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: groupMeta.tint,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  groupMeta.subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: _cMuted,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final option = options[i];
                final selected = _selectedCategoryId == option.id;
                return _AnimeFilterChip(
                  option: option,
                  selected: selected,
                  onTap: () => _selectCategory(option),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseResults() {
    final row = _browseResults[_selectedCategoryId];
    final option = animeCategoryOptions.firstWhere(
      (o) => o.id == _selectedCategoryId,
      orElse: () => animeCategoryOptions.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildSectionTitle(option.label, icon: option.icon, tint: option.color),
        if (row == null || row.isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (_, _) => Container(
                decoration: BoxDecoration(
                  color: _cCard,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )
        else if (row.items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Text(
              'No matches in this category yet.',
              style: GoogleFonts.outfit(
                color: _cMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: row.items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, i) {
              final item = row.items[i];
              return _AnimePosterTile(
                item: item,
                onTap: () => _openDetails(item),
              );
            },
          ),
      ],
    );
  }

  _BrowseGroupMeta _groupMeta(AnimeCategoryGroup g) {
    switch (g) {
      case AnimeCategoryGroup.format:
        return const _BrowseGroupMeta(
          title: 'By Format',
          subtitle: 'MOVIES · SERIES · OVAs',
          icon: Icons.movie_filter_rounded,
          tint: _cGold,
        );
      case AnimeCategoryGroup.genre:
        return const _BrowseGroupMeta(
          title: 'By Genre',
          subtitle: 'TAP TO FILTER',
          icon: Icons.theater_comedy_rounded,
          tint: _cRose,
        );
      case AnimeCategoryGroup.status:
        return const _BrowseGroupMeta(
          title: 'By Status',
          subtitle: 'AIRING · COMPLETED · NEW',
          icon: Icons.live_tv_rounded,
          tint: Color(0xFFE53935),
        );
      case AnimeCategoryGroup.discovery:
        return const _BrowseGroupMeta(
          title: 'Discovery',
          subtitle: 'CURATED PICKS',
          icon: Icons.workspace_premium_rounded,
          tint: Color(0xFFEC407A),
        );
    }
  }

  // ── LIBRARY TAB ────────────────────────────────────────────────────

  Widget _buildLibraryTab() {
    final wantToWatch = _library.where((i) => i.isToWatch).toList();
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

  // ── SEARCH TAB ─────────────────────────────────────────────────────

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

// ── INTERNAL MODELS ──────────────────────────────────────────────

class _AnimeRow {
  final List<MediaItem> items;
  final bool isLoading;
  const _AnimeRow({this.items = const [], this.isLoading = false});
}

class _HomeSection {
  final String id;
  final String title;
  final IconData icon;
  final Color tint;
  final Future<List<MediaItem>> Function() builder;
  final bool isHero;

  const _HomeSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.tint,
    required this.builder,
    this.isHero = false,
  });
}

class _BrowseGroupMeta {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  const _BrowseGroupMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

class _AnimeFilterChip extends StatelessWidget {
  final AnimeCategoryOption option;
  final bool selected;
  final VoidCallback onTap;
  const _AnimeFilterChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = option.color;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? tint.withValues(alpha: 0.18) : _cCard,
          border: Border.all(
            color: selected ? tint : _cRose.withValues(alpha: 0.12),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(option.icon, color: selected ? tint : _cMuted, size: 14),
            const SizedBox(width: 6),
            Text(
              option.label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: selected ? tint : _cRose.withValues(alpha: 0.85),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
            if (item.year.isNotEmpty)
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.year,
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: _cWhite,
                      fontWeight: FontWeight.w600,
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

/// Larger hero card for the Trending Now carousel on the home tab.
class _AnimeHeroCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const _AnimeHeroCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final backdrop = item.backdropPath.isNotEmpty
        ? item.backdropPath
        : item.posterPath;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (backdrop.isNotEmpty)
              Image.network(backdrop, fit: BoxFit.cover)
            else
              Container(color: _cVelvet),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _cDeepRose.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TRENDING',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    color: _cWhite,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _cWhite,
                      height: 1.1,
                    ),
                  ),
                  if (item.year.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.year,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: _cGold,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
