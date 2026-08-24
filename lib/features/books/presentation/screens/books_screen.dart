import 'dart:async';
import 'package:flutter/material.dart' hide FilterChip;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/book_item.dart';
import '../../data/models/book_search_result.dart';
import '../../data/services/book_catalog_service.dart';
import '../../data/services/book_download_helper.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/open_library_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../shared/widgets/shelf/atmospheric_backdrop.dart';
import '../../../../shared/widgets/shelf/filter_chip.dart';
import '../../../../shared/widgets/shelf/scroll_edge_fade.dart';
import '../../../../shared/widgets/shelf/shelf_icon_button.dart';
import '../../../../shared/widgets/shelf/shelf_poster_card.dart';
import '../../../../shared/widgets/shelf/shelf_section_header.dart';
import '../../../../shared/widgets/shelf/shelf_empty_state.dart';
import '../../../../shared/widgets/shelf/shimmer_box.dart';
import '../../../../shared/widgets/shelf/shelf_pill_bottom_nav.dart';
import '../../../../shared/widgets/shelf/staggered_entrance.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
part 'books_screen_widgets.dart';
part 'books_screen_state_base.dart';

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

class _BooksScreenState extends _BooksScreenStateBase {
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
            child: StaggeredEntrance(index: 0, child: _buildTopHeader()),
          ),
          SliverToBoxAdapter(
            child: StaggeredEntrance(index: 1, child: _buildHomeSearch()),
          ),
          SliverToBoxAdapter(
            child: StaggeredEntrance(index: 2, child: _buildHeroBanner()),
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
            child: StaggeredEntrance(index: 4, child: _buildTrendingRankings()),
          ),
          ..._buildSubjectRows(),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildContinueReading() {
    return _ContinueReadingRail(
      items: _readHistoryList,
      onOpen: _showBookDetails,
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
                style: AppTypography.cormorantBlack.copyWith(
                  fontSize: 20,
                  letterSpacing: 4,
                  color: _cWhite,
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
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 9,
                      color: _cMuted,
                      letterSpacing: 2.5,
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
              const Icon(
                Icons.travel_explore_rounded,
                color: _cDeepRose,
                size: 20,
              ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    final diff = (_carouselController.page! - index).abs();
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
                color: isActive ? _cDeepRose : _cMuted.withValues(alpha: 0.35),
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
                    ? Image.network(
                        item.coverUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 800,
                        errorBuilder: (_, _, _) => Container(color: _cCard),
                      )
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
                              horizontal: 10,
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
                                  style: AppTypography.outfitWhite.copyWith(
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
                        style: AppTypography.cormorantBlack.copyWith(
                          fontSize: 26,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 12,
                            ),
                          ],
                          color: _cWhite,
                        ),
                      ),
                      if (item.author.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'by ${item.author}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitWhite.copyWith(
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
                              style: AppTypography.outfitBold.copyWith(
                                color: _cGold,
                                fontSize: 12,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: _cMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          Text(
                            'Tap to explore',
                            style: AppTypography.outfitWhite.copyWith(
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
  static double _responsiveListHeight(
    BuildContext context, {
    required double fallback,
  }) {
    final viewH = MediaQuery.sizeOf(context).height;
    return (viewH * 0.42).clamp(fallback * 0.6, fallback * 1.35);
  }

  // ── SUBJECT ROWS ───────────────────────────────────────────────────

  List<Widget> _buildSubjectRows() {
    final rows = <Widget>[];
    var i = 4;
    _subjectLists.forEach((name, items) {
      final meta = _BooksScreenStateBase._featuredSubjects.firstWhere(
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
            child: _buildSection(
              name,
              'Books',
              items,
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
            20,
            MediaQuery.paddingOf(context).top + 14,
            20,
            0,
          ),
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
                      style: AppTypography.cormorantExtraBold.copyWith(
                        fontSize: 26,
                        color: _cWhite,
                      ),
                    ),
                    Text(
                      'FIND YOUR NEXT OBSESSION',
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 9,
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
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              style: AppTypography.outfitWhite.copyWith(
                color: _cWhite,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Title, author, subject...',
                hintStyle: AppTypography.outfitWhite.copyWith(
                  color: _cMuted,
                  fontSize: 15,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(
                    Icons.search_rounded,
                    color: _cDeepRose,
                    size: 22,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 16,
                ),
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

  Widget _buildResultRow(BookSearchResult result) {
    final book = result.toBookItem();
    return _BookResultRow(
      result: result,
      onOpen: () {
        HapticFeedback.lightImpact();
        context.push(
          '/books/detail',
          extra: BookDetailArgs(item: book, result: result),
        );
      },
      onListen: result.readCandidates.isNotEmpty
          ? () => context.push('/books/listen', extra: book)
          : null,
      onRead: result.readCandidates.isNotEmpty
          ? () => context.push('/books/reader', extra: book)
          : null,
      onDownload: result.downloadUrls.isNotEmpty
          ? () => _showRowDownload(result)
          : null,
      onShare: () => _shareResult(result),
      onSave: () => _saveResult(result),
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
            20,
            MediaQuery.paddingOf(context).top + 14,
            20,
            0,
          ),
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
                      style: AppTypography.cormorantExtraBold.copyWith(
                        fontSize: 26,
                        color: _cWhite,
                      ),
                    ),
                    Text(
                      isReadTab ? 'OUR LIBRARY' : 'THE BOOKSHELF',
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 9,
                        color: _cMuted,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _cDeepRose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _cDeepRose.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${list.length}',
                  style: AppTypography.outfitWhite.copyWith(
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
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
              20,
              MediaQuery.paddingOf(context).top + 14,
              20,
              20,
            ),
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
