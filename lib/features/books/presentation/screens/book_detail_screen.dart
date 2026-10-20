import 'package:flutter/material.dart';
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
import '../widgets/book_cover_card.dart';
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

class _BookDetailScreenState extends State<BookDetailScreen> {
  final BookCatalogService _catalog = BookCatalogService();
  final OpenLibraryService _service = OpenLibraryService();
  final BookLibraryService _library = BookLibraryService();
  final OurBooksService _ours = OurBooksService();

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
    _saved = _item.isToRead || _item.isRead;
    _result = widget.args.result;
    _loadDetails();
    _loadSimilar();
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
        entries: _downloads,
        sourceLabel: _result?.sourceLabel ?? _item.readSourceLabel,
        onDownload: _downloadFile,
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
      body: Stack(
        children: [
          // Warm glow behind the cover; gradients only, no blur, so the
          // page stays light on phones.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 420 + top,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 0.9,
                  colors: [
                    _cAmber.withValues(alpha: 0.16),
                    _cDeepRose.withValues(alpha: 0.06),
                    _cBlack.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, top + 8, 12, 0),
                    child: Row(
                      children: [
                        _TopIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          label: 'Back',
                          onTap: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildHero()),
                SliverToBoxAdapter(child: _buildDownloadHero()),
                SliverToBoxAdapter(child: _buildActionBar()),
                SliverToBoxAdapter(child: _buildDescription()),
                SliverToBoxAdapter(child: _buildDetailsCard()),
                SliverToBoxAdapter(child: _buildSimilarRail()),
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        children: [
          SizedBox(
            width: 168,
            child: BookCover(
              imageUrl: cover,
              title: title,
              author: author,
              radius: 10,
              cacheWidth: 600,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.cormorantBlack.copyWith(
              fontSize: 28,
              height: 1.1,
              color: _cWhite,
            ),
          ),
          if (author.isNotEmpty) ...[
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: 'More by $author',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/books', extra: author);
                },
                child: Text(
                  author,
                  textAlign: TextAlign.center,
                  style: AppTypography.outfitWhite.copyWith(
                    color: _cRose.withValues(alpha: 0.9),
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: _cRose.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              meta,
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                color: _cMuted,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _buildRating(result),
          if (_loadingDetails)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: SizedBox(
                width: 80,
                child: LinearProgressIndicator(
                  color: _cAmber,
                  backgroundColor: _cCard,
                  minHeight: 2,
                ),
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
          '${_compact(result!.ratingCount!)} downloads',
          style: AppTypography.outfitBold.copyWith(
            color: _cGold,
            fontSize: 11.5,
          ),
        );
      }
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= result.rating!.round()
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            color: _cGold,
            size: 16,
          ),
        const SizedBox(width: 6),
        Text(
          '${result.rating!.toStringAsFixed(1)} (${_compact(result.ratingCount ?? 0)})',
          style: AppTypography.outfitWhite.copyWith(
            color: _cMuted,
            fontSize: 11.5,
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

  /// Main actions. Reading comes first (like Play on Netflix); download
  /// takes the lead only when the book can't be read in the app.
  Widget _buildDownloadHero() {
    final best = _bestDownload;
    final canRead =
        _result?.readCandidates.isNotEmpty == true ||
        _item.readSourceUrl.isNotEmpty ||
        (_result?.gutenbergId ?? 0) > 0;
    final size = _result?.sizeMb;
    final downloadLabel = best == null
        ? ''
        : 'Download ${best.key.toUpperCase()}'
              '${size != null && size > 0 ? ' · ${size.toStringAsFixed(1)} MB' : ''}';
    void download() {
      if (_downloads.length > 1) {
        _showDownloadSheet();
      } else {
        _downloadFile(best!.key, best.value);
      }
    }

    final roundShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    final outlined = OutlinedButton.styleFrom(
      foregroundColor: _cWhite,
      side: BorderSide(color: _cRose.withValues(alpha: 0.25)),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: roundShape,
      textStyle: AppTypography.outfitBold.copyWith(fontSize: 14),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canRead)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () => _openReader(),
                    icon: const Icon(Icons.auto_stories_rounded, size: 20),
                    label: const Text('Read'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cWhite,
                      foregroundColor: _cBlack,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: roundShape,
                      elevation: 0,
                      textStyle: AppTypography.outfitBold.copyWith(
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () => _openReader(listen: true),
                    icon: const Icon(Icons.headphones_rounded, size: 18),
                    label: const Text('Listen'),
                    style: outlined,
                  ),
                ),
              ],
            ),
          if (best != null) ...[
            if (canRead) const SizedBox(height: 10),
            if (canRead)
              OutlinedButton.icon(
                onPressed: download,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(downloadLabel),
                style: outlined,
              )
            else
              ElevatedButton.icon(
                onPressed: download,
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text(downloadLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cDeepRose,
                  foregroundColor: _cWhite,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: roundShape,
                  elevation: 0,
                  textStyle: AppTypography.outfitBold.copyWith(fontSize: 15),
                ),
              ),
          ],
          if (!canRead && best == null)
            Text(
              'This one has no free file to read or download yet.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                color: _cMuted,
                fontSize: 12.5,
              ),
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
      if ((result?.isbn ?? _item.isbn).isNotEmpty) (result?.isbn ?? _item.isbn),
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
      if ((_result?.fileLine ?? '').isNotEmpty) ('File', _result!.fileLine),
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
    final isCouple = context.select<AuthService, bool>((a) => a.isCoupleUser);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionChip(
            icon: _saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            label: _saved ? 'Saved' : 'Save',
            active: _saved,
            onTap: _toggleSave,
          ),
          _ActionChip(
            icon: _favorited
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: _favorited ? 'Loved' : 'Love',
            active: _favorited,
            onTap: _toggleFavorite,
          ),
          if (isCouple)
            _ActionChip(
              icon: Icons.volunteer_activism_rounded,
              label: 'Our Books',
              onTap: _sendToOurs,
            ),
          _ActionChip(
            icon: Icons.ios_share_rounded,
            label: 'Share',
            onTap: _share,
          ),
        ],
      ),
    );
  }

  /// Every file we can offer, nicest format first (EPUB > TXT > PDF ...).
  List<MapEntry<String, String>> get _downloads {
    final downloads = <String, String>{...?(_result?.downloadUrls)};
    if (downloads.isEmpty && _item.iaId.isNotEmpty) {
      downloads['epub'] =
          'https://archive.org/download/${_item.iaId}/${_item.iaId}.epub';
      downloads['pdf'] =
          'https://archive.org/download/${_item.iaId}/${_item.iaId}.pdf';
    }
    return downloads.entries.toList()
      ..sort((a, b) => _formatRank(a.key).compareTo(_formatRank(b.key)));
  }

  MapEntry<String, String>? get _bestDownload {
    final all = _downloads;
    return all.isEmpty ? null : all.first;
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

  Widget _buildSimilarRail() {
    if (!_loadingSimilar && _similar.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 14),
          child: Text(
            'More like this',
            style: AppTypography.cormorantBlack.copyWith(
              fontSize: 22,
              color: _cWhite,
            ),
          ),
        ),
        SizedBox(
          height: 246,
          child: _loadingSimilar
              ? const Center(
                  child: CircularProgressIndicator(
                    color: _cAmber,
                    strokeWidth: 2.5,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _similar.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final book = _similar[index];
                    return BookCoverCard(
                      width: 112,
                      item: book.toBookItem(),
                      onTap: () => context.push(
                        '/books/detail',
                        extra: BookDetailArgs(
                          item: book.toBookItem(),
                          result: book,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
