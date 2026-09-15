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
import '../widgets/advanced_search_sheet.dart';
import '../widgets/book_categories.dart';
import 'book_list_screen.dart';
import '../widgets/zlib_result_row.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../shared/widgets/shelf/atmospheric_backdrop.dart';
import '../../../../shared/widgets/shelf/filter_chip.dart';
import '../../../../shared/widgets/shelf/scroll_edge_fade.dart';
import '../../../../shared/widgets/shelf/shelf_icon_button.dart';
import '../../../../shared/widgets/shelf/shelf_poster_card.dart';
import '../../../../shared/widgets/shelf/shelf_section_header.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../shared/widgets/shelf/shelf_pill_bottom_nav.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/shelf/staggered_entrance.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_colors.dart';
part 'books_screen_widgets.dart';
part 'books_screen_state_base.dart';

const _cBlack = AppColors.animeBackground;
const _cCard = AppColors.shimmerBase;
const _cRose = AppColors.roseQuartz;
const _cDeepRose = AppColors.deepRose;
const _cAmber = AppColors.warmAmber;
const _cWhite = AppColors.petalWhite;
const _cMuted = AppColors.mutedPurple;

/// Main entry for the books feature. Four-tab IndexedStack
/// (Home, Search, To Read, Read) with a custom glassmorphic bottom
/// nav. Mirrors `CinemaScreen` from the cinema feature.
class BooksScreen extends StatefulWidget {
  /// Pre-filled search text, e.g. when tapping an author name on the
  /// detail page. Opens straight on the Search tab.
  final String initialQuery;
  const BooksScreen({super.key, this.initialQuery = ''});

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
            child: StaggeredEntrance(index: 2, child: _buildStatsStrip()),
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
            child: StaggeredEntrance(index: 4, child: _buildCategories()),
          ),
          SliverToBoxAdapter(
            child: StaggeredEntrance(index: 5, child: _buildPopularRail()),
          ),
          SliverToBoxAdapter(
            child: StaggeredEntrance(index: 6, child: _buildRecentRail()),
          ),
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

  // ── Z-LIB HOME SECTIONS ────────────────────────────────────────────

  /// Honest counts from the feeds actually loaded — no fake totals.
  Widget _buildStatsStrip() {
    final popular = _popular.length;
    final recent = _recent.length;
    if (popular == 0 && recent == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _cCard.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cRose.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatBit(value: '$popular', label: 'Popular now'),
            Container(width: 1, height: 28, color: _cRose.withValues(alpha: 0.12)),
            _StatBit(value: '$recent', label: 'Fresh titles'),
            Container(width: 1, height: 28, color: _cRose.withValues(alpha: 0.12)),
            _StatBit(value: '${bookCategories.length}', label: 'Shelves'),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: ShelfSectionHeader(
            eyebrow: 'Browse',
            title: 'Categories',
            icon: Icons.grid_view_rounded,
            accent: _cAmber,
            count: bookCategories.length,
            countLabel: 'shelves',
            onSeeAll: () => context.push('/books/categories'),
          ),
        ),
        ScrollEdgeFade(
          fadeColor: _cBlack,
          child: SizedBox(
            height: 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: bookCategories.length,
              itemBuilder: (context, index) {
                final category = bookCategories[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/books/category', extra: category);
                    },
                    child: Container(
                      width: 92,
                      decoration: BoxDecoration(
                        color: _cCard.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: category.color.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(category.icon, color: category.color, size: 24),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.outfitBold.copyWith(
                                color: _cWhite,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildPopularRail() {
    return _buildFeedRail(
      eyebrow: 'Trending this week',
      title: 'Most Popular',
      icon: Icons.local_fire_department_rounded,
      accent: _cAmber,
      results: _popular,
      onSeeAll: () => context.push(
        '/books/list',
        extra: const BookListArgs.popular(),
      ),
    );
  }

  Widget _buildRecentRail() {
    return _buildFeedRail(
      eyebrow: 'Fresh in the catalog',
      title: 'Recently Added',
      icon: Icons.fiber_new_rounded,
      accent: _cDeepRose,
      results: _recent,
      onSeeAll: () => context.push(
        '/books/list',
        extra: const BookListArgs.recent(),
      ),
    );
  }

  Widget _buildFeedRail({
    required String eyebrow,
    required String title,
    required IconData icon,
    required Color accent,
    required List<BookSearchResult> results,
    required VoidCallback onSeeAll,
  }) {
    if (results.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: ShelfSectionHeader(
            eyebrow: eyebrow,
            title: title,
            icon: icon,
            accent: accent,
            count: results.length,
            countLabel: results.length == 1 ? 'title' : 'titles',
            onSeeAll: onSeeAll,
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
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 150,
                    child: ShelfPosterCard(
                      imageUrl: result.coverUrl,
                      title: result.title,
                      subtitle: result.author.isNotEmpty
                          ? 'by ${result.author}'
                          : (result.year.isNotEmpty ? result.year : null),
                      badge: 'BOOK',
                      badgeIcon: Icons.menu_book_rounded,
                      badgeColor: accent,
                      onTap: () => _showResultDetails(result),
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
          child: Row(
            children: [
              Expanded(
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
                      hintText: 'Title, author, ISBN...',
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
              const SizedBox(width: 10),
              _AdvancedButton(
                active: _advancedFilters.isNotEmpty,
                onTap: _openAdvancedSearch,
              ),
            ],
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
                    if (_advancedFilters.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ActiveFiltersPill(
                            filters: _advancedFilters,
                            onEdit: _openAdvancedSearch,
                            onClear: () {
                              setState(
                                () => _advancedFilters =
                                    BookSearchFilters.none,
                              );
                              _rerunSearchIfNeeded();
                            },
                          ),
                        ),
                      ),
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
                              _searchTotal > 0
                                  ? '${BookCatalogService.compactCount(_searchTotal)} RESULTS'
                                  : '${_searchResults.length} RESULTS',
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
                          itemCount: _searchResults.length +
                              (_searchHasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _searchResults.length) {
                              return _LoadMoreRow(
                                loading: _isLoadingMore,
                                onTap: _loadMoreSearch,
                              );
                            }
                            return _buildResultRow(_searchResults[index]);
                          },
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
    return ZlibResultRow(
      result: result,
      onOpen: () {
        HapticFeedback.lightImpact();
        context.push(
          '/books/detail',
          extra: BookDetailArgs(item: book, result: result),
        );
      },
      onDownload: result.downloadUrls.isNotEmpty
          ? () => _showRowDownload(result)
          : null,
      onSave: () => _saveResult(result),
    );
  }

  Future<void> _openAdvancedSearch() async {
    final picked = await AdvancedSearchSheet.open(
      context,
      _advancedFilters,
    );
    if (picked == null || !mounted) return;
    setState(() => _advancedFilters = picked);
    _rerunSearchIfNeeded();
  }

  // ── READLIST TABS ──────────────────────────────────────────────────

  Color _readBadgeColor(String status) {
    switch (status) {
      case 'read-clair':
        return AppColors.cinemaPink;
      case 'read-khent':
        return AppColors.cinemaBlue;
      case 'read-both':
      case 'read':
      default:
        return AppColors.cinemaGreen;
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
              ? EverglowEmptyState(
                  icon: isReadTab
                      ? Icons.auto_stories_outlined
                      : Icons.bookmark_border_rounded,
                  title: isReadTab
                      ? 'Your read history is empty'
                      : 'Nothing queued yet',
                  subtitle: isReadTab
                      ? 'Books you mark as read will live here so you can revisit them anytime.'
                      : 'Tap the bookmark on any book to add it to your reading queue.',
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: AppBreakpoint.isDesktop(context)
                        ? 6
                        : (AppBreakpoint.isTablet(context) ? 5 : 2),
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
            child: const EverglowSkeleton(height: 40, width: 160, radius: 8),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: EverglowSkeleton(height: 320, radius: 24),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 32, 20, 0),
            child: EverglowSkeleton(height: 280, radius: 16),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 32, 20, 14),
            child: EverglowSkeleton(height: 36, width: 200, radius: 8),
          ),
        ),
        const SliverToBoxAdapter(
          child: EverglowSkeletonRow(count: 6, itemWidth: 150, itemHeight: 240),
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
