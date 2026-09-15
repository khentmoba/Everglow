import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/shelf/atmospheric_backdrop.dart';
import '../../../../shared/widgets/shelf/shelf_icon_button.dart';
import '../../data/models/book_search_result.dart';
import '../../data/services/book_catalog_service.dart';
import '../../data/services/open_library_service.dart';
import '../widgets/book_categories.dart';
import '../widgets/zlib_result_row.dart';

const _cBlack = AppColors.animeBackground;
const _cWhite = AppColors.petalWhite;
const _cMuted = AppColors.mutedPurple;
const _cDeepRose = AppColors.deepRose;

/// Which feed a [BookListScreen] shows.
enum BookListKind { popular, recent, category }

/// Arguments for the `/books/list` route.
class BookListArgs {
  final BookListKind kind;
  final BookCategory? category;

  const BookListArgs.popular() : kind = BookListKind.popular, category = null;
  const BookListArgs.recent() : kind = BookListKind.recent, category = null;
  const BookListArgs.category(this.category) : kind = BookListKind.category;
}

/// Z-Library style full list page: one feed (Popular, Recently
/// Added, or a category) as dense rows. Category feeds page through
/// Open Library with a Load-more footer; Popular / Recent are
/// curated single pages.
class BookListScreen extends StatefulWidget {
  final BookListArgs args;
  const BookListScreen({super.key, required this.args});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  final BookCatalogService _catalog = BookCatalogService();
  final OpenLibraryService _service = OpenLibraryService();

  List<BookSearchResult> _results = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  static const int _pageSize = 30;

  String get _title {
    switch (widget.args.kind) {
      case BookListKind.popular:
        return 'Most Popular';
      case BookListKind.recent:
        return 'Recently Added';
      case BookListKind.category:
        return widget.args.category?.name ?? 'Category';
    }
  }

  String get _eyebrow {
    switch (widget.args.kind) {
      case BookListKind.popular:
        return 'TRENDING THIS WEEK';
      case BookListKind.recent:
        return 'FRESH IN THE CATALOG';
      case BookListKind.category:
        return 'BROWSE BY CATEGORY';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFirst();
  }

  Future<void> _loadFirst() async {
    List<BookSearchResult> results;
    bool hasMore = false;
    switch (widget.args.kind) {
      case BookListKind.popular:
        results = await _catalog.mostPopular(limit: _pageSize);
      case BookListKind.recent:
        results = await _catalog.recentlyAdded(limit: _pageSize);
      case BookListKind.category:
        final query = widget.args.category?.query ?? '';
        results = await _catalog.byCategoryPaged(query, limit: _pageSize);
        hasMore = results.length >= _pageSize;
    }
    if (!mounted) return;
    setState(() {
      _results = results;
      _hasMore = hasMore;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    if (widget.args.kind != BookListKind.category) return;
    setState(() => _isLoadingMore = true);
    final query = widget.args.category?.query ?? '';
    final extra = await _catalog.byCategoryPaged(
      query,
      limit: _pageSize,
      offset: _results.length,
    );
    if (!mounted) return;
    setState(() {
      _results = [..._results, ...extra];
      _hasMore = extra.length >= _pageSize;
      _isLoadingMore = false;
    });
  }

  Future<void> _save(BookSearchResult result) async {
    HapticFeedback.selectionClick();
    final userName = context.read<AuthService>().currentUser ?? '';
    if (userName.isEmpty) {
      _showSnack('Please sign in to save books');
      return;
    }
    await _service.saveToReadList(result.toBookItem(), 'to-read', userName);
    if (!mounted) return;
    _showSnack('Saved to your reading list');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTypography.outfitWhite),
        backgroundColor: _cDeepRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: _cBlack,
      body: Stack(
        children: [
          const ShelfAtmosphericBackdrop(
            glows: [
              RadialGlow(
                color: AppColors.warmAmber,
                alignment: Alignment(-0.7, -0.85),
                size: 0.85,
                opacity: 0.14,
              ),
              RadialGlow(
                color: AppColors.deepRose,
                alignment: Alignment(0.85, 0.95),
                size: 0.8,
                opacity: 0.10,
              ),
            ],
          ),
          SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, top + 14, 20, 0),
                  child: Row(
                    children: [
                      ShelfIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        semanticLabel: 'Back',
                        tooltip: 'Back',
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title,
                              style: AppTypography.cormorantExtraBold.copyWith(
                                fontSize: 26,
                                color: _cWhite,
                              ),
                            ),
                            Text(
                              _eyebrow,
                              style: AppTypography.outfitHeading.copyWith(
                                fontSize: 9,
                                color: _cMuted,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_results.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _cDeepRose.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _cDeepRose.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '${_results.length}',
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
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _cDeepRose, strokeWidth: 2.5),
      );
    }
    if (_results.isEmpty) {
      return const EverglowEmptyState(
        icon: Icons.local_library_outlined,
        title: 'Nothing here yet',
        subtitle: 'Check back soon — this shelf refreshes often.',
      );
    }
    return RefreshIndicator(
      color: _cDeepRose,
      backgroundColor: AppColors.shimmerBase,
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _loadFirst();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _results.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _results.length) {
            return _ListLoadMore(loading: _isLoadingMore, onTap: _loadMore);
          }
          final result = _results[index];
          return ZlibResultRow(
            result: result,
            onOpen: () {
              final book = result.toBookItem();
              context.push(
                '/books/detail',
                extra: BookDetailArgs(item: book, result: result),
              );
            },
            onDownload: result.downloadUrls.isNotEmpty
                ? () {
                    final book = result.toBookItem();
                    context.push(
                      '/books/detail',
                      extra: BookDetailArgs(item: book, result: result),
                    );
                  }
                : null,
            onSave: () => _save(result),
          );
        },
      ),
    );
  }
}

class _ListLoadMore extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _ListLoadMore({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: loading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _cDeepRose.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cDeepRose.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: _cDeepRose,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  'Load more',
                  style: AppTypography.outfitBold.copyWith(
                    color: _cDeepRose,
                    fontSize: 13,
                  ),
                ),
        ),
      ),
    );
  }
}
