import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/manga_item.dart';
import '../../data/services/bato_service.dart';
import '../../data/services/mangadex_service.dart';
import '../../data/services/mangakakalot_service.dart';
import '../../data/services/mangakatana_service.dart';
import '../../data/services/scanlation_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_typography.dart';

/// Reader background — deep black, darker than the anime palette.
const _readerBg = AppColors.animeBackground; // 0xFF080810
///   • Long-strip (webtoon) mode by default — vertical continuous scroll
///   • Tap center of screen to show/hide UI chrome
///   • Chapter dropdown for quick navigation
///   • Prev/Next chapter buttons at the bottom
///   • "Next Chapter →" card at the very end of the scroll
///   • Page counter overlay
class MangaReaderScreen extends StatefulWidget {
  final MangaItem manga;
  final MangaChapter chapter;
  final List<MangaChapter> allChapters;
  final Map<String, String>? scanlationSlugs;

  const MangaReaderScreen({
    super.key,
    required this.manga,
    required this.chapter,
    required this.allChapters,
    this.scanlationSlugs,
  });

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  final MangaDexService _mangaDexService = MangaDexService();
  final MangaKakalotService _kakalotService = MangaKakalotService();
  final MangakatanaService _mangakatanaService = MangakatanaService();
  final ScanlationService _scanlationService = ScanlationService();
  final BatoService _batoService = BatoService();

  MangaChapterPages? _pages;
  bool _isLoading = true;
  String? _loadError;

  /// Scroll controller for long-strip mode
  final ScrollController _scrollController = ScrollController();

  /// Whether the UI chrome (top/bottom bars) is visible
  bool _showUI = true;

  /// Current scroll position as a page estimate
  int _currentPageEstimate = 0;

  @override
  void initState() {
    super.initState();
    _loadPages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _pages == null) return;

    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;

    // Estimate current page from scroll position
    // Each image is roughly viewport-width * aspect-ratio in height
    // We'll use a simple ratio
    final ratio = maxScroll > 0 ? offset / maxScroll : 0;
    final totalPages = _pages!.filenames.length;
    setState(() {
      _currentPageEstimate = (ratio * totalPages).clamp(0, totalPages - 1).toInt();
    });

    // Save progress periodically
    if (_currentPageEstimate % 5 == 0) {
      _saveProgress(_currentPageEstimate);
    }
  }

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
    if (_showUI) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  /// Compare two chapter numbers accounting for formatting differences
  /// (e.g. "1" vs "1.0" vs "001").
  bool _chaptersMatch(String a, String b) {
    if (a == b) return true;
    final na = double.tryParse(a);
    final nb = double.tryParse(b);
    if (na != null && nb != null) return na == nb;
    return false;
  }

  Future<void> _loadPages() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final timeout = const Duration(seconds: 15);
    final futures = <Future<MangaChapterPages?>>[];

    // 1) MangaDex — try chapter.id directly
    futures.add(_mangaDexService
        .getChapterPagesProxied(widget.chapter.id)
        .timeout(timeout, onTimeout: () => null));

    // 2) MangaDex — match by chapter number
    final mangaDexId = widget.manga.mangaKakalotId;
    if (mangaDexId.isNotEmpty && widget.chapter.chapter.isNotEmpty) {
      futures.add(_resolveMangaDexByChapterNumber(mangaDexId)
          .timeout(timeout, onTimeout: () => null));
    }
    if (widget.manga.mangaId.isNotEmpty &&
        widget.manga.mangaId != mangaDexId &&
        widget.manga.comickId == 0 &&
        widget.chapter.chapter.isNotEmpty) {
      futures.add(_resolveMangaDexByChapterNumber(widget.manga.mangaId)
          .timeout(timeout, onTimeout: () => null));
    }

    // 3) MangaKakalot
    futures.add(_kakalotService
        .getChapterPages(widget.chapter.id)
        .timeout(timeout, onTimeout: () => null));

    final kakalotTitles = <String>[widget.manga.title];
    for (final alt in widget.manga.altTitles) {
      if (alt.isNotEmpty && !kakalotTitles.contains(alt)) {
        kakalotTitles.add(alt);
      }
    }
    for (final title in kakalotTitles) {
      futures.add(_kakalotService
          .searchByTitle(title)
          .timeout(timeout, onTimeout: () => '')
          .then((slug) async {
        if (slug.isEmpty) return null;
        final chapters = await _kakalotService.getChapterFeed(slug);
        MangaChapter? match;
        for (final c in chapters) {
          if (_chaptersMatch(c.chapter, widget.chapter.chapter)) {
            match = c;
            break;
          }
        }
        if (match == null) return null;
        final pages = await _kakalotService.getChapterPages(match.id);
        if (pages == null || pages.filenames.isEmpty) return null;
        final proxied = pages.filenames
            .map((u) => _kakalotService.proxiedImageUrl(u))
            .toList();
        return MangaChapterPages(
          chapterId: pages.chapterId,
          baseUrl: '',
          hash: '',
          filenames: proxied,
          expiresAt: pages.expiresAt,
        );
      }).timeout(timeout, onTimeout: () => null));
    }

    // 4) MangaKatana
    futures.add(_resolveMangakatanaPages()
        .timeout(timeout, onTimeout: () => null));

    // 5) Bato.to — only if the chapter ID is already a Bato path
    if (widget.chapter.id.startsWith('/title/') ||
        widget.chapter.id.startsWith('/chapter/')) {
      final batoPath = widget.chapter.id.startsWith('http')
          ? widget.chapter.id
          : widget.chapter.id.startsWith('/')
              ? widget.chapter.id
              : '/${widget.chapter.id}';
      futures.add(_batoService
          .getChapterPages(batoPath)
          .timeout(timeout, onTimeout: () => null));
    }

    // 6) MangaSee123 — only if we have a known slug (skip Comick hid)
    // MangaSee123 slugs are short identifiers, not Comick hids.
    // Disabled for now since we don't store MangaSee123 slugs.

    // 7) Scanlation sites
    final slugs = widget.scanlationSlugs;
    if (slugs != null && slugs.isNotEmpty) {
      futures.add(_scanlationService
          .getChapterPagesFromAll(slugs, widget.chapter.chapter)
          .timeout(timeout, onTimeout: () => null));
    }

    // Wait for all and pick the first non-null result
    final pages = await _pickBestPages(futures);

    if (!mounted) return;
    if (pages != null && pages.filenames.isNotEmpty) {
      _applyPages(pages);
    } else {
      setState(() {
        _isLoading = false;
        _loadError = 'This chapter has no readable pages.';
      });
    }
  }

  Future<MangaChapterPages?> _resolveMangaDexByChapterNumber(
      String mangaDexId) async {
    final mdChapters = await _mangaDexService.getChapterFeed(mangaDexId);
    final targetChapter = mdChapters.cast<MangaChapter?>().firstWhere(
          (c) => c != null && _chaptersMatch(c.chapter, widget.chapter.chapter),
          orElse: () => null,
        );
    if (targetChapter != null) {
      return _mangaDexService.getChapterPagesProxied(targetChapter.id);
    }
    return null;
  }

  Future<MangaChapterPages?> _resolveMangakatanaPages() async {
    final titlesToTry = <String>[widget.manga.title];
    for (final alt in widget.manga.altTitles) {
      if (alt.isNotEmpty && !titlesToTry.contains(alt)) {
        titlesToTry.add(alt);
      }
    }
    for (final title in titlesToTry) {
      final slug = await _mangakatanaService.searchByTitle(title);
      if (slug.isEmpty) continue;
      final chapters = await _mangakatanaService.getChapterFeed(slug);
      MangaChapter? match;
      for (final c in chapters) {
        if (_chaptersMatch(c.chapter, widget.chapter.chapter)) {
          match = c;
          break;
        }
      }
      if (match == null) continue;
      final pages = await _mangakatanaService.getChapterPages(match.id);
      if (pages == null || pages.filenames.isEmpty) continue;
      final proxied = pages.filenames
          .map((u) => _mangakatanaService.proxiedImageUrl(u))
          .toList();
      return MangaChapterPages(
        chapterId: pages.chapterId,
        baseUrl: '',
        hash: '',
        filenames: proxied,
        expiresAt: pages.expiresAt,
      );
    }
    return null;
  }

  Future<MangaChapterPages?> _pickBestPages(
    List<Future<MangaChapterPages?>> futures,
  ) async {
    // Wait for ALL futures so we can pick deterministically by source
    // priority rather than whichever finishes first.
    final results = await Future.wait(
      futures.map((f) => f.then(
        (pages) => pages,
        onError: (_) => null,
      )),
    );

    // Priority order matches the order we added futures:
    // 0) MangaDex by chapter ID
    // 1) MangaDex by chapter number (mangaKakalotId)
    // 2) MangaDex by chapter number (mangaId)
    // 3) MangaKakalot direct
    // 4..N) MangaKakalot by title search(es)
    // N+1) MangaKatana
    // N+2) Bato.to
    // N+3) MangaSee123
    // N+4) Scanlation
    //
    // We prefer MangaDex (structured API, reliable page counts) over
    // scraped sources. Among equals, earlier = higher priority.
    for (final pages in results) {
      if (pages != null && pages.filenames.isNotEmpty) {
        return pages;
      }
    }
    return null;
  }

  void _applyPages(MangaChapterPages pages) {
    if (!mounted) return;
    setState(() {
      _pages = pages;
      _isLoading = false;
    });
    // Restore last read page
    if (widget.manga.lastReadChapterId == widget.chapter.id &&
        widget.manga.lastReadPage > 0 &&
        widget.manga.lastReadPage <= pages.filenames.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && mounted) {
          // Scroll to approximate position (will be refined once layout settles)
          final ratio = widget.manga.lastReadPage / pages.filenames.length;
          final target = _scrollController.position.maxScrollExtent * ratio;
          _scrollController.jumpTo(target.clamp(0, _scrollController.position.maxScrollExtent));
        }
      });
    }
  }

  Future<void> _saveProgress(int pageIndex) async {
    final user = context.read<AuthService>().currentUser ?? '';
    if (user.isEmpty) return;
    await _kakalotService.saveReadingProgress(
      mangaId: widget.manga.mangaId,
      userName: user,
      chapterId: widget.chapter.id,
      page: pageIndex + 1,
    );
  }

  // ── Chapter navigation ──────────────────────────────────────────

  MangaChapter? get _previousChapter {
    final i = widget.allChapters.indexWhere((c) => c.id == widget.chapter.id);
    if (i < 0 || i >= widget.allChapters.length - 1) return null;
    return widget.allChapters[i + 1];
  }

  MangaChapter? get _nextChapter {
    final i = widget.allChapters.indexWhere((c) => c.id == widget.chapter.id);
    if (i <= 0) return null;
    return widget.allChapters[i - 1];
  }

  void _goToChapter(MangaChapter chapter) {
    _saveProgress(_currentPageEstimate);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MangaReaderScreen(
          manga: widget.manga.copyWith(
            lastReadChapterId: chapter.id,
            lastReadPage: 0,
          ),
          chapter: chapter,
          allChapters: widget.allChapters,
          scanlationSlugs: widget.scanlationSlugs,
        ),
      ),
    );
  }

  void _openChapterPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Chapters',
                    style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.allChapters.length} total',
                    style: AppTypography.outfitWhite.copyWith(color: AppTheme.roseQuartz.withValues(alpha: 0.5), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x22F4C2C2)),
            SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.5,
              child: ListView.builder(
                itemCount: widget.allChapters.length,
                itemBuilder: (ctx, index) {
                  final c = widget.allChapters[index];
                  final isCurrent = c.id == widget.chapter.id;
                  return ListTile(
                    dense: true,
                    selected: isCurrent,
                    selectedTileColor: AppTheme.deepRose.withValues(alpha: 0.15),
                    leading: isCurrent
                        ? const Icon(Icons.play_arrow_rounded,
                            color: AppTheme.deepRose, size: 20)
                        : null,
                    title: Text(
                      c.displayTitle,
                      style: AppTypography.outfitWhite.copyWith(color: isCurrent
                            ? AppTheme.deepRose
                            : AppTheme.petalWhite, fontSize: 13, fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500),
                    ),
                    subtitle: c.pages > 0
                        ? Text(
                            '${c.pages} pages',
                            style: AppTypography.outfitWhite.copyWith(color: AppTheme.roseQuartz.withValues(alpha: 0.4), fontSize: 10),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (!isCurrent) _goToChapter(c);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _readerBg,
      body: Stack(
        children: [
          // Main content area — tap to toggle UI
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleUI,
            child: _isLoading
                ? _buildLoading()
                : _loadError != null
                    ? _buildError()
                    : _buildReader(),
          ),
          // Top bar (animated)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            top: _showUI ? 0 : -80,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),
          // Bottom bar (animated)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            bottom: _showUI ? 0 : -100,
            left: 0,
            right: 0,
            child: _buildBottomBar(),
          ),
          // Page counter (always visible, small)
          if (!_isLoading && _loadError == null && _pages != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 56 + 4,
              right: 16,
              child: AnimatedOpacity(
                opacity: _showUI ? 0.0 : 0.7,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: AppRadius.radiusSm,
                  ),
                  child: Text(
                    '${_currentPageEstimate + 1}/${_pages!.filenames.length}',
                    style: AppTypography.outfitBold.copyWith(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final statusBar = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.only(top: statusBar),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _readerBg,
            _readerBg.withValues(alpha: 0.9),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 52,
            child: Row(
              children: [
                IconButton(
                  onPressed: () async {
                    await _saveProgress(_currentPageEstimate);
                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white70, size: 18),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.manga.title,
                        style: AppTypography.outfitWhite.copyWith(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.chapter.displayTitle,
                        style: AppTypography.outfitMuted.copyWith(color: Colors.white54, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Chapter picker button
                IconButton(
                  onPressed: _openChapterPicker,
                  icon: const Icon(Icons.list_rounded,
                      color: Colors.white70, size: 22),
                  tooltip: 'Chapter list',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final prev = _previousChapter;
    final next = _nextChapter;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPad),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            _readerBg,
            _readerBg.withValues(alpha: 0.9),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress indicator
          if (_pages != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Page ${_currentPageEstimate + 1}',
                    style: AppTypography.outfitMuted.copyWith(color: Colors.white54, fontSize: 11),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: LinearProgressIndicator(
                        value: _pages!.filenames.isNotEmpty
                            ? (_currentPageEstimate + 1) /
                                _pages!.filenames.length
                            : 0,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.deepRose),
                        minHeight: 2,
                      ),
                    ),
                  ),
                  Text(
                    '${_pages!.filenames.length}',
                    style: AppTypography.outfitMuted.copyWith(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Chapter navigation
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: _NavButton(
                    label: '← Prev',
                    enabled: prev != null,
                    onTap: prev != null ? () => _goToChapter(prev) : null,
                  ),
                ),
                const SizedBox(width: 12),
                // Chapter picker center button
                GestureDetector(
                  onTap: _openChapterPicker,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.deepRose.withValues(alpha: 0.15),
                      borderRadius: AppRadius.radiusSm,
                      border: Border.all(
                        color: AppTheme.deepRose.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book_rounded,
                            color: AppTheme.deepRose, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Ch. ${widget.chapter.chapter}',
                          style: AppTypography.outfitWhite.copyWith(color: AppTheme.deepRose, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NavButton(
                    label: 'Next →',
                    enabled: next != null,
                    onTap: next != null ? () => _goToChapter(next) : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.deepRose),
          const SizedBox(height: 16),
          Text(
            'Loading pages...',
            style: AppTypography.outfitMuted.copyWith(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: AppTheme.roseQuartz, size: 56),
            const SizedBox(height: 16),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPages,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.deepRose,
                shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusSm),
              ),
              child: Text('Retry',
                  style: AppTypography.outfitWhite.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// Long-strip (webtoon) reader — continuous vertical scroll.
  Widget _buildReader() {
    if (_pages == null) return const SizedBox.shrink();
    final pageCount = _pages!.filenames.length;
    final next = _nextChapter;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 56,
        bottom: MediaQuery.paddingOf(context).bottom + 120,
      ),
      itemCount: pageCount + 1, // +1 for "Next Chapter" card
      itemBuilder: (context, index) {
        if (index == pageCount) {
          // "Next Chapter" card at the end
          return _buildNextChapterCard(next);
        }

        final url = _pages!.urlForPage(index);
        return Column(
          children: [
            // Page image — fills width, no gaps
            Image.network(
              url,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              cacheWidth: 1200,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 400),
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    color: AppTheme.deepRose.withValues(alpha: 0.6),
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stack) {
                return Container(
                  width: double.infinity,
                  height: 300,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image,
                          color: Colors.white24, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Page ${index + 1} failed to load',
                        style: AppTypography.outfitWhite.copyWith(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _loadPages,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.deepRose.withValues(alpha: 0.2),
                            borderRadius: AppRadius.radiusXs,
                          ),
                          child: Text(
                            'Retry',
                            style: AppTypography.outfitWhite.copyWith(color: AppTheme.deepRose, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildNextChapterCard(MangaChapter? next) {
    if (next == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text(
              'You\'ve reached the end',
              style: AppTypography.outfitWhite.copyWith(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.deepRose.withValues(alpha: 0.12),
            AppTheme.deepRose.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: AppTheme.deepRose.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Text(
            'End of Chapter',
            style: AppTypography.outfitWhite.copyWith(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            next.displayTitle,
            style: AppTypography.outfitWhite.copyWith(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _goToChapter(next),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(
              'Next Chapter',
              style: AppTypography.outfitWhite.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deepRose,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.radiusSm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavButton({
    required this.label,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: AppRadius.radiusSm,
          border: Border.all(
            color: enabled
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.outfitBold.copyWith(color: enabled ? Colors.white : Colors.white24, fontSize: 13),
        ),
      ),
    );
  }
}
