import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/anime_categories.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/jikan_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/features/cinema/presentation/widgets/jikan_search_modal.dart';
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

// Mirror of cinema_screen.dart / manga_library_screen.dart color tokens so
// the anime feature feels native to the rest of the cinema feature.
const _cBlack = Color(0xFF080810);
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
      body: Stack(
        children: [
          const ShelfAtmosphericBackdrop(
            glows: [
              RadialGlow(
                color: AppTheme.softLavender,
                alignment: Alignment(-0.7, -0.85),
                size: 0.9,
                opacity: 0.15,
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
                _buildBrowseTab(),
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
        if (i == 3) {
          // Search tab opens the modal in addition to switching tabs,
          // matching the previous behaviour.
          setState(() => _currentIndex = i);
          _openSearch();
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
          icon: Icons.explore_outlined,
          activeIcon: Icons.explore_rounded,
          label: 'Browse',
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
      onRefresh: _refreshHome,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          StaggeredEntrance(index: 0, child: _buildHeader()),
          const SizedBox(height: 8),
          for (var i = 0; i < _homeSections.length; i++) ...[
            StaggeredEntrance(
              index: i + 1,
              child: _buildHomeSection(_homeSections[i]),
            ),
            const SizedBox(height: 24),
          ],
          if (_library.where((i) => i.isToWatch).isNotEmpty) ...[
            StaggeredEntrance(
              index: _homeSections.length + 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: ShelfSectionHeader(
                  eyebrow: 'Up Next',
                  title: 'In Your Queue',
                  icon: Icons.bookmark_rounded,
                  accent: _cGold,
                  count: _library.where((i) => i.isToWatch).length,
                  countLabel: 'titles',
                ),
              ),
            ),
            _buildPosterRow(
              _library.where((i) => i.isToWatch).toList(),
            ),
            const SizedBox(height: 24),
          ],
          if (_library.where((i) => i.isWatched).isNotEmpty) ...[
            StaggeredEntrance(
              index: _homeSections.length + 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: ShelfSectionHeader(
                  eyebrow: 'Already Finished',
                  title: 'Watched',
                  icon: Icons.remove_red_eye_rounded,
                  accent: _cGold,
                  count: _library.where((i) => i.isWatched).length,
                  countLabel: 'titles',
                ),
              ),
            ),
            _buildPosterRow(
              _library.where((i) => i.isWatched).toList(),
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
      return _buildShimmerRow(height: section.isHero ? 280 : 220);
    }
    if (row.isLoading) {
      return _buildShimmerRow(height: section.isHero ? 280 : 220);
    }
    if (row.items.isEmpty) {
      return const SizedBox.shrink();
    }
    if (section.isHero) {
      return _buildHeroCarousel(row.items, section);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: ShelfSectionHeader(
            eyebrow: _eyebrowForSection(section.id),
            title: section.title,
            icon: section.icon,
            accent: section.tint,
            count: row.items.length,
            countLabel: 'titles',
          ),
        ),
        _buildPosterRow(row.items, accent: section.tint),
      ],
    );
  }

  String _eyebrowForSection(String id) {
    switch (id) {
      case 'airing':
        return 'Now Airing';
      case 'top-rated':
        return 'All Time Best';
      case 'new-releases':
        return 'Just Added';
      case 'popular-all':
        return 'Fan Favourites';
      case 'hidden-gems':
        return 'Worth Discovering';
      case 'editors-picks':
        return 'Curated For You';
      case 'trending':
      default:
        return 'Hot Right Now';
    }
  }

  Widget _buildHeroCarousel(List<MediaItem> items, _HomeSection section) {
    final heroItems = items.take(5).map((m) {
      return ShelfHeroItem(
        id: '${m.tmdbId}',
        title: m.title,
        subtitle: m.year.isNotEmpty ? m.year : 'Tap to explore',
        eyebrow: 'Trending #${items.indexOf(m) + 1}',
        imageUrl: m.backdropPath.isNotEmpty
            ? m.backdropPath
            : m.posterPath,
        accent: section.tint,
        onTap: () => _openDetails(m),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: ShelfSectionHeader(
            eyebrow: _eyebrowForSection(section.id),
            title: section.title,
            icon: section.icon,
            accent: section.tint,
            count: items.length,
            countLabel: 'titles',
          ),
        ),
        ShelfHeroCarousel(
          items: heroItems,
          holdDuration: const Duration(seconds: 7),
          height: 320,
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
          ShelfIconButton(
            icon: Icons.search_rounded,
            semanticLabel: 'Search Anime',
            tooltip: 'Search anime',
            onTap: _openSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title,
      {required IconData icon, Color tint = _cRose, int? count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: ShelfSectionHeader(
        eyebrow: 'Collection',
        title: title,
        icon: icon,
        accent: tint,
        count: count,
        countLabel: count != null ? 'titles' : null,
      ),
    );
  }

  Widget _buildShimmerRow({required double height}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: ShimmerPosterRow(
        height: height - 14,
        width: 130,
        count: 5,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildPosterRow(
    List<MediaItem> items, {
    Color accent = _cRose,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Text(
          'Nothing here yet. Search above to add your first anime!',
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
        height: 230,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return SizedBox(
              width: 130,
              child: ShelfPosterCard(
                imageUrl: item.posterPath,
                title: item.title,
                subtitle: item.year.isNotEmpty ? item.year : null,
                badge: 'ANIME',
                badgeIcon: Icons.animation_rounded,
                badgeColor: accent,
                onTap: () => _openDetails(item),
              ),
            );
          },
        ),
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
        _buildSectionTitle(
          option.label,
          icon: option.icon,
          tint: option.color,
          count: row?.items.length,
        ),
        if (row == null || row.isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (_, _) => const ShimmerBox(height: 220, radius: 14),
            ),
          )
        else if (row.items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: ShelfEmptyState(
              icon: Icons.travel_explore_rounded,
              title: 'No matches in this category yet',
              subtitle:
                  'Try another filter, or pull to refresh to fetch the latest from Jikan.',
              accent: option.color,
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: row.items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (context, i) {
              final item = row.items[i];
              return ShelfPosterCard(
                imageUrl: item.posterPath,
                title: item.title,
                subtitle: item.year.isNotEmpty ? item.year : null,
                badge: 'ANIME',
                badgeIcon: Icons.animation_rounded,
                badgeColor: option.color,
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

    if (wantToWatch.isEmpty && watched.isEmpty) {
      return ShelfEmptyState(
        icon: Icons.collections_bookmark_outlined,
        title: 'Your anime library is empty',
        subtitle:
            'Search for any series and add it to your watchlist. Items you mark as watched will live here too.',
        ctaLabel: 'Search Anime',
        ctaIcon: Icons.search_rounded,
        onCta: _openSearch,
        accent: AppTheme.deepRose,
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OUR ANIME',
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
                    'JAPANESE ANIMATION',
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
              const SizedBox(height: 12),
              Row(
                children: [
                  _LibraryStat(
                    label: 'Queue',
                    count: wantToWatch.length,
                    color: _cGold,
                  ),
                  const SizedBox(width: 8),
                  _LibraryStat(
                    label: 'Watched',
                    count: watched.length,
                    color: const Color(0xFF8BC34A),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildLibrarySection(
            'Want to Watch', wantToWatch, Icons.bookmark_rounded, _cGold),
        _buildLibrarySection('Watched', watched,
            Icons.remove_red_eye_rounded, const Color(0xFF8BC34A)),
      ],
    );
  }

  Widget _buildLibrarySection(
    String title,
    List<MediaItem> items,
    IconData icon,
    Color accent,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: ShelfSectionHeader(
            eyebrow: 'Collection',
            title: title,
            icon: icon,
            accent: accent,
            count: items.length,
            countLabel: 'titles',
          ),
        ),
        GridView.builder(
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
            return ShelfPosterCard(
              imageUrl: item.posterPath,
              title: item.title,
              subtitle: item.year.isNotEmpty ? item.year : null,
              badge: title == 'Watched' ? 'WATCHED' : 'QUEUE',
              badgeColor: accent,
              onTap: () => _openDetails(item),
            );
          },
        ),
      ],
    );
  }

  // ── SEARCH TAB ─────────────────────────────────────────────────────

  Widget _buildSearchTab() {
    return ShelfEmptyState(
      icon: Icons.search_rounded,
      title: 'Find Your Next Anime',
      subtitle:
          'Search MyAnimeList / AniList by title. We auto-detect anime from the results and drop it into your library.',
      ctaLabel: 'Open Search',
      ctaIcon: Icons.search_rounded,
      onCta: _openSearch,
      accent: _cDeepRose,
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

/// Compact poster tile used in the home + library carousels is now
/// `ShelfPosterCard` (see `lib/shared/widgets/shelf/`).

/// Hero card for the Trending carousel is now `ShelfHeroCarousel`
/// (see `lib/shared/widgets/shelf/`).

/// Small tinted stat chip used in the library header.
class _LibraryStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _LibraryStat({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.85),
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
