import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_network_image.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/book_item.dart';
import '../../data/models/book_search_result.dart';
import '../../data/services/book_catalog_service.dart';
import '../../data/services/book_download_helper.dart';
import '../../data/services/book_library_service.dart';
import '../../data/services/open_library_service.dart';
import '../../data/services/our_books_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/shelf/shelf_poster_card.dart';
import '../../../../core/theme/app_colors.dart';
part 'book_detail_widgets.dart';

const _cBlack = AppColors.animeBackground;
const _cCard = AppColors.shimmerBase;
const _cRose = AppColors.roseQuartz;
const _cDeepRose = AppColors.deepRose;
const _cGold = AppColors.animeGold;
const _cAmber = AppColors.warmAmber;
const _cWhite = AppColors.petalWhite;
const _cMuted = AppColors.mutedPurple;

/// WeLib-style full book page: cover + title + meta chips + rating,
/// expandable description, the Listen / Read / Download / Share /
/// Save action row, and Downloads / Technical details / Similar
/// tabs. Powers both the search results and the read list.
class BookDetailScreen extends StatefulWidget {
  final BookDetailArgs args;
  const BookDetailScreen({super.key, required this.args});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen>
    with SingleTickerProviderStateMixin {
  final BookCatalogService _catalog = BookCatalogService();
  final OpenLibraryService _service = OpenLibraryService();
  final BookLibraryService _library = BookLibraryService();
  final OurBooksService _ours = OurBooksService();
  late final TabController _tabController;

  BookSearchResult? _result;
  bool _loadingDetails = true;
  List<BookSearchResult> _similar = const [];
  bool _loadingSimilar = true;
  bool _descExpanded = false;
  bool _saved = false;
  bool _favorited = false;

  BookItem get _item => widget.args.item;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _saved = _item.isToRead || _item.isRead;
    _result = widget.args.result;
    _loadDetails();
    _loadSimilar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    if (_result == null) {
      // Build a bare result from the stored item so detail lookup
      // still works for read-list entries.
      final ia = _item.iaId.isNotEmpty && !_item.iaId.startsWith('pg')
          ? _item.iaId
          : '';
      final gutenberg = _item.iaId.startsWith('pg') && _item.iaId.length > 2
          ? int.tryParse(_item.iaId.substring(2)) ?? 0
          : 0;
      _result = BookSearchResult(
        title: _item.title,
        author: _item.author,
        coverUrl: _item.coverUrl,
        year: _item.year,
        subjects: _item.subjects,
        sourceLabel: _item.readSourceLabel,
        workKey: _item.workKey,
        iaId: ia,
        gutenbergId: gutenberg,
        readCandidates: _item.readSourceUrl.isNotEmpty
            ? [_item.readSourceUrl]
            : const [],
      );
    }
    final enriched = await _catalog.details(_result!);
    if (!mounted) return;
    setState(() {
      _result = enriched;
      _loadingDetails = false;
    });
  }

  Future<void> _loadSimilar() async {
    final similar = await _catalog.similar(_result ?? _bareResult());
    if (!mounted) return;
    setState(() {
      _similar = similar;
      _loadingSimilar = false;
    });
  }

  BookSearchResult _bareResult() {
    return BookSearchResult(
      title: _item.title,
      author: _item.author,
      subjects: _item.subjects,
      workKey: _item.workKey,
      iaId: _item.iaId,
    );
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  BookItem _bookForReading() {
    final result = _result;
    if (result != null) {
      final candidates = result.readCandidates.isNotEmpty
          ? result.readCandidates
          : (result.gutenbergId > 0
                ? [
                    'https://www.gutenberg.org/cache/epub/${result.gutenbergId}/pg${result.gutenbergId}.txt',
                  ]
                : const <String>[]);
      return result.copyWith(readCandidates: candidates).toBookItem();
    }
    return _item;
  }

  void _openReader({bool listen = false}) {
    HapticFeedback.lightImpact();
    final book = _bookForReading();
    context.push(listen ? '/books/listen' : '/books/reader', extra: book);
  }

  void _share() async {
    HapticFeedback.selectionClick();
    final result = _result;
    String url = '';
    if (result != null) {
      if (result.gutenbergId > 0) {
        url = 'https://www.gutenberg.org/ebooks/${result.gutenbergId}';
      } else if (result.iaId.isNotEmpty) {
        url = 'https://archive.org/details/${result.iaId}';
      } else if (result.workKey.isNotEmpty) {
        url = 'https://openlibrary.org${result.workKey}';
      }
    }
    if (url.isEmpty) {
      url = 'https://openlibrary.org${_item.workKey}';
    }
    final data = ClipboardData(text: '$url\n${_item.title}');
    await Clipboard.setData(data);
    if (!mounted) return;
    _showSnack('Link copied - share it with someone you love');
  }

  Future<void> _toggleSave() async {
    HapticFeedback.selectionClick();
    final userName = context.read<AuthService>().currentUser ?? '';
    if (userName.isEmpty) {
      _showSnack('Please sign in to save books');
      return;
    }
    final book = _bookForReading();
    if (_saved) {
      await _service.removeFromReadList(book.workKey, userName);
      if (mounted) {
        setState(() => _saved = false);
        _showSnack('Removed from your list');
      }
    } else {
      await _service.saveToReadList(book, 'to-read', userName);
      if (mounted) {
        setState(() => _saved = true);
        _showSnack('Saved to your reading list');
      }
    }
  }

  void _showDownloadSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DownloadSheet(
        result: _result,
        item: _item,
        onDownloaded: _logDownload,
      ),
    );
  }

  /// Download one file and remember it in the personal history.
  Future<void> _downloadFile(String format, String url) async {
    HapticFeedback.selectionClick();
    final fileName =
        '${_sanitizeFileName(_item.title)}.${format.toUpperCase()}';
    downloadUrl(url, filename: fileName);
    await _logDownload(format);
  }

  Future<void> _logDownload(String format) async {
    final userName = context.read<AuthService>().currentUser ?? '';
    if (userName.isEmpty) return;
    await _library.logDownload(_bookForReading(), userName, format: format);
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.selectionClick();
    final userName = context.read<AuthService>().currentUser ?? '';
    if (userName.isEmpty) {
      _showSnack('Please sign in to favorite books');
      return;
    }
    final book = _bookForReading();
    if (_favorited) {
      await _library.removeFavorite(book.workKey, userName);
      if (mounted) {
        setState(() => _favorited = false);
        _showSnack('Removed from favorites');
      }
    } else {
      await _library.addFavorite(book, userName);
      if (mounted) {
        setState(() => _favorited = true);
        _showSnack('Added to favorites');
      }
    }
  }

  Future<void> _sendToOurs() async {
    HapticFeedback.selectionClick();
    final userName = context.read<AuthService>().currentUser ?? '';
    if (userName != 'khentsgdz' && userName != 'clairjassen') {
      _showSnack('Our Books is just for the two of you');
      return;
    }
    final added = await _ours.addToOurBooks(_bookForReading(), userName);
    if (!mounted) return;
    _showSnack(
      added == null ? 'Could not add right now' : 'Added to Our Books',
    );
  }

  /// Best download format first (EPUB > PDF > TXT ...) so the big
  /// button always offers the nicest file.
  MapEntry<String, String>? get _bestDownload {
    final downloads = <String, String>{...?(_result?.downloadUrls)};
    if (downloads.isEmpty && _item.iaId.isNotEmpty) {
      downloads['epub'] =
          'https://archive.org/download/${_item.iaId}/${_item.iaId}.epub';
      downloads['pdf'] =
          'https://archive.org/download/${_item.iaId}/${_item.iaId}.pdf';
    }
    if (downloads.isEmpty) return null;
    final entries = downloads.entries.toList()
      ..sort((a, b) => _formatRank(a.key).compareTo(_formatRank(b.key)));
    return entries.first;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTypography.outfitWhite),
        backgroundColor: AppTheme.deepRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: _cBlack,
      body: SafeArea(
        top: false,
        child: DefaultTabController(
          length: 2,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.fromLTRB(12, top + 8, 12, 0),
                  child: Row(
                    children: [
                      _TopIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        label: 'Back',
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BOOK DETAILS',
                              style: AppTypography.outfitHeading.copyWith(
                                fontSize: 10,
                                color: _cMuted,
                              ),
                            ),
                            Text(
                              _item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 14,
                                color: _cWhite,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TopIconButton(
                        icon: Icons.share_rounded,
                        label: 'Share',
                        onTap: _share,
                      ),
                      const SizedBox(width: 8),
                      _TopIconButton(
                        icon: _favorited
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: _favorited ? 'Favorited' : 'Favorite',
                        active: _favorited,
                        onTap: _toggleFavorite,
                      ),
                      const SizedBox(width: 8),
                      _TopIconButton(
                        icon: _saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        label: _saved ? 'Saved' : 'Save',
                        active: _saved,
                        onTap: _toggleSave,
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildHero()),
              SliverToBoxAdapter(child: _buildDownloadHero()),
              SliverToBoxAdapter(child: _buildDescription()),
              SliverToBoxAdapter(child: _buildDetailsCard()),
              SliverToBoxAdapter(child: _buildActionBar()),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabHeaderDelegate(
                  controller: _tabController,
                  count: 2,
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDownloadsTab(),
                    _buildSimilarTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    final result = _result;
    final title = result?.title ?? _item.title;
    final author = result?.author ?? _item.author;
    final cover = result?.coverUrl ?? _item.coverUrl;
    final meta = (result?.metaLine.isNotEmpty == true)
        ? result!.metaLine
        : [
            _item.year,
            _item.readSourceLabel,
          ].where((e) => e.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 132,
              height: 196,
              child: cover.isNotEmpty
                  ? AppNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      cacheWidth: 600,
                      errorWidget: Container(color: _cCard),
                    )
                  : Container(
                      color: _cCard,
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: _cMuted,
                        size: 40,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.cormorantBlack.copyWith(
                    fontSize: 24,
                    height: 1.12,
                    color: _cWhite,
                  ),
                ),
                if (author.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/books', extra: author);
                    },
                    child: Text(
                      author,
                      style: AppTypography.outfitWhite.copyWith(
                        color: _cRose.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        decoration: TextDecoration.underline,
                        decorationColor: _cRose.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  meta,
                  style: AppTypography.outfitWhite.copyWith(
                    color: _cMuted,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRating(result),
                if (_loadingDetails)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(
                      color: _cDeepRose,
                      backgroundColor: _cCard,
                      minHeight: 2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRating(BookSearchResult? result) {
    if (result == null || !result.hasRating) {
      if (result?.ratingCount != null) {
        return Text(
          '${result!.ratingCount} downloads',
          style: AppTypography.outfitBold.copyWith(color: _cGold, fontSize: 11),
        );
      }
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= result.rating!.round()
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            color: _cGold,
            size: 15,
          ),
        const SizedBox(width: 6),
        Text(
          '${result.rating!.toStringAsFixed(1)} (${_compact(result.ratingCount ?? 0)})',
          style: AppTypography.outfitWhite.copyWith(
            color: _cMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  Widget _buildDescription() {
    final description = _result?.description ?? '';
    if (description.isEmpty) return const SizedBox.shrink();
    final maxLines = _descExpanded ? null : 4;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            maxLines: maxLines,
            overflow: _descExpanded ? null : TextOverflow.ellipsis,
            style: AppTypography.outfitWhite.copyWith(
              color: _cRose.withValues(alpha: 0.78),
              fontSize: 13,
              height: 1.55,
            ),
          ),
          if (description.length > 260)
            GestureDetector(
              onTap: () => setState(() => _descExpanded = !_descExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _descExpanded ? 'Read less' : 'Read more...',
                  style: AppTypography.outfitBold.copyWith(
                    color: _cDeepRose,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Z-Lib style primary download block: one big button offering
  /// the best format, with Read / Listen as quiet secondaries.
  Widget _buildDownloadHero() {
    final best = _bestDownload;
    final canRead =
        _result?.readCandidates.isNotEmpty == true ||
        _item.readSourceUrl.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (best != null)
            ElevatedButton.icon(
              onPressed: () {
                final count = (_result?.downloadUrls.length ?? 0);
                if (count > 1) {
                  _showDownloadSheet();
                } else {
                  _downloadFile(best.key, best.value);
                }
              },
              icon: const Icon(Icons.download_rounded, size: 20),
              label: Text(
                'Download ${best.key.toUpperCase()}${_result?.sizeMb != null && _result!.sizeMb! > 0 ? ' · ${_result!.sizeMb!.toStringAsFixed(1)} MB' : ''}',
                style: AppTypography.outfitBold.copyWith(fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cDeepRose,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: _cDeepRose.withValues(alpha: 0.5),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canRead ? () => _openReader() : null,
                  icon: const Icon(Icons.auto_stories_rounded, size: 18),
                  label: const Text('Read Online'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cWhite,
                    side: BorderSide(color: _cRose.withValues(alpha: 0.25)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canRead ? () => _openReader(listen: true) : null,
                  icon: const Icon(Icons.headphones_rounded, size: 18),
                  label: const Text('Listen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cWhite,
                    side: BorderSide(color: _cRose.withValues(alpha: 0.25)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Z-Lib style details card: the full metadata table up front
  /// instead of hidden behind a tab.
  Widget _buildDetailsCard() {
    final rows = _detailRows();
    if (rows.isEmpty) return const SizedBox.shrink();
    final result = _result;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: _cCard.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cRose.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DETAILS',
              style: AppTypography.outfitHeading.copyWith(
                color: _cMuted,
                fontSize: 10,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 10),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        row.$1,
                        style: AppTypography.outfitHeading.copyWith(
                          color: _cMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        style: AppTypography.outfitWhite.copyWith(
                          color: _cWhite,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if ((result?.subjects ?? const []).isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: result!.subjects
                    .take(8)
                    .map(
                      (s) => GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.push('/books/category', extra: s);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _cBlack.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _cRose.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            s,
                            style: AppTypography.outfitWhite.copyWith(
                              color: _cRose.withValues(alpha: 0.85),
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<(String, String)> _detailRows() {
    final result = _result;
    final isbn = [
      if ((result?.isbn13 ?? '').isNotEmpty) result!.isbn13,
      if ((result?.isbn ?? _item.isbn).isNotEmpty)
        (result?.isbn ?? _item.isbn),
    ].join(' · ');
    return <(String, String)>[
      if ((result?.subjects ?? const []).isNotEmpty)
        ('Category', result!.subjects.first),
      ('Type', 'Book'),
      if ((result?.year ?? _item.year).isNotEmpty)
        ('Year', (result?.year ?? _item.year)),
      if ((result?.publisher ?? _item.publisher).isNotEmpty)
        ('Publisher', (result?.publisher ?? _item.publisher)),
      if ((result?.language ?? '').isNotEmpty) ('Language', result!.language),
      if ((result?.pageCount ?? _item.pageCount) > 0)
        ('Pages', '${result?.pageCount ?? _item.pageCount}'),
      if (isbn.isNotEmpty) ('ISBN', isbn),
      if ((_result?.fileLine ?? '').isNotEmpty)
        ('File', _result!.fileLine),
      ('Source', result?.sourceLabel ?? _item.readSourceLabel),
      if (result?.ratingCount != null)
        ('Downloads', _compact(result!.ratingCount!)),
      if ((result?.gutenbergId ?? 0) > 0)
        ('Gutenberg ID', '${result!.gutenbergId}'),
      if ((result?.iaId ?? _item.iaId).isNotEmpty)
        ('Archive ID', result?.iaId ?? _item.iaId),
    ];
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ActionChip(
            icon: Icons.favorite_rounded,
            label: 'Ours',
            color: _cDeepRose,
            enabled: true,
            onTap: _sendToOurs,
          ),
          _ActionChip(
            icon: Icons.share_rounded,
            label: 'Share',
            color: AppColors.cinemaBlue,
            enabled: true,
            onTap: _share,
          ),
          _ActionChip(
            icon: _saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            label: _saved ? 'Saved' : 'Save',
            color: const Color(0xFF7B1FA2),
            enabled: true,
            onTap: _toggleSave,
          ),
          _ActionChip(
            icon: _favorited
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            label: _favorited ? 'Loved' : 'Love',
            color: _cAmber,
            enabled: true,
            onTap: _toggleFavorite,
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsTab() {
    final result = _result;
    final downloads = <String, String>{...?(result?.downloadUrls)};
    if (downloads.isEmpty && _item.iaId.isNotEmpty) {
      downloads['epub'] =
          'https://archive.org/download/${_item.iaId}/${_item.iaId}.epub';
      downloads['pdf'] =
          'https://archive.org/download/${_item.iaId}/${_item.iaId}.pdf';
    }
    if (downloads.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'No downloadable file available for this title in our legal catalogs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _cMuted, fontSize: 13, height: 1.5),
          ),
        ),
      );
    }
    final entries = downloads.entries.toList()
      ..sort((a, b) => _formatRank(a.key).compareTo(_formatRank(b.key)));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == entries.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              'Public-domain files only. Free to read, download, and share.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                color: _cMuted,
                fontSize: 10.5,
              ),
            ),
          );
        }
        final entry = entries[index];
        final ext = entry.key.toUpperCase();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _cCard.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cRose.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _cDeepRose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  ext,
                  style: AppTypography.outfitBold.copyWith(
                    color: _cDeepRose,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$ext file',
                      style: AppTypography.outfitBold.copyWith(
                        color: _cWhite,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      result?.sourceLabel ?? _item.readSourceLabel,
                      style: AppTypography.outfitWhite.copyWith(
                        color: _cMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _downloadFile(entry.key, entry.value),
                style: TextButton.styleFrom(
                  backgroundColor: _cDeepRose,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Download', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        );
      },
    );
  }

  int _formatRank(String ext) {
    switch (ext) {
      case 'epub':
        return 0;
      case 'txt':
        return 1;
      case 'pdf':
        return 2;
      case 'mobi':
        return 3;
      case 'html':
        return 4;
      default:
        return 5;
    }
  }

  String _sanitizeFileName(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .trim();
    return cleaned.isEmpty ? 'book' : cleaned;
  }

  Widget _buildSimilarTab() {
    if (_loadingSimilar) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: _cDeepRose, strokeWidth: 2.5),
        ),
      );
    }
    if (_similar.isEmpty) {
      return const EverglowEmptyState(
        icon: Icons.local_library_rounded,
        title: 'No similar titles found',
        subtitle: 'Try exploring the search tab for more books.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      scrollDirection: Axis.horizontal,
      itemCount: _similar.length,
      itemBuilder: (context, index) {
        final book = _similar[index];
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
            width: 130,
            child: ShelfPosterCard(
              imageUrl: book.coverUrl,
              title: book.title,
              subtitle: book.author.isNotEmpty ? book.author : null,
              badge: 'BOOK',
              badgeIcon: Icons.menu_book_rounded,
              badgeColor: _cDeepRose,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookDetailScreen(
                      args: BookDetailArgs(
                        item: book.toBookItem(),
                        result: book,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
