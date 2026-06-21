import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';
import 'package:everglow/features/manga/data/services/mangakakalot_service.dart';
import 'package:everglow/services/auth_service.dart';

/// Page turn mode — one image per page, swipe / arrow keys to advance.
enum _ReaderMode { paginated, longStrip }

/// In-app manga / manhwa / manhua reader. Mirrors `VideoPlayerScreen`
/// from the cinema feature — it's the fullscreen experience for a
/// single media item.
///
/// Pipeline:
///   1. Resolve page filenames + baseUrl from
///      `MangaKakalotService.getChapterPages`.
///   2. Build proxy URLs (so the browser doesn't get blocked by CORS).
///   3. Display pages through `Image.network` in a `PageView` (paginated)
///      or a vertical `ListView` (long-strip).
///   4. On close, persist `lastReadChapterId` and `lastReadPage` to
///      Firestore so the "Continue Reading" rail can resume here.
class MangaReaderScreen extends StatefulWidget {
  final MangaItem manga;
  final MangaChapter chapter;
  final List<MangaChapter> allChapters;

  const MangaReaderScreen({
    Key? key,
    required this.manga,
    required this.chapter,
    required this.allChapters,
  }) : super(key: key);

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  final MangaKakalotService _service = MangaKakalotService();

  MangaChapterPages? _pages;
  bool _isLoading = true;
  String? _loadError;
  _ReaderMode _mode = _ReaderMode.paginated;
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadPages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPages() async {
    try {
      final pages = await _service.getChapterPages(widget.chapter.id);
      if (!mounted) return;
      if (pages == null || pages.filenames.isEmpty) {
        setState(() {
          _isLoading = false;
          _loadError = 'This chapter has no readable pages.';
        });
        return;
      }
      setState(() {
        _pages = pages;
        _isLoading = false;
      });
      // Restore last read page if applicable
      if (widget.manga.lastReadChapterId == widget.chapter.id &&
          widget.manga.lastReadPage > 0 &&
          widget.manga.lastReadPage <= pages.filenames.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients && mounted) {
            _pageController.jumpToPage(widget.manga.lastReadPage - 1);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load: $e';
      });
    }
  }

  Future<void> _saveProgress(int pageIndex) async {
    final user = context.read<AuthService>().currentUser ?? '';
    if (user.isEmpty) return;
    await _service.saveReadingProgress(
      mangaId: widget.manga.mangaId,
      userName: user,
      chapterId: widget.chapter.id,
      page: pageIndex + 1,
    );
  }

  void _goToChapter(MangaChapter chapter) {
    // Persist progress for the current chapter before navigating
    _saveProgress(_currentPage);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MangaReaderScreen(
          manga: widget.manga.copyWith(
            lastReadChapterId: chapter.id,
            lastReadPage: 0,
          ),
          chapter: chapter,
          allChapters: widget.allChapters,
        ),
      ),
    );
  }

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

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    // Persist every 5 pages to keep Firestore writes light
    if (index % 5 == 0 || index == (_pages?.filenames.length ?? 0) - 1) {
      _saveProgress(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? _buildLoading()
                  : _loadError != null
                      ? _buildError()
                      : _buildReader(),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: Color(0x33F4C2C2), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              await _saveProgress(_currentPage);
              if (mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.petalWhite, size: 18),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.manga.title,
                  style: GoogleFonts.outfit(
                    color: AppTheme.petalWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.chapter.displayTitle,
                  style: GoogleFonts.outfit(
                    color: AppTheme.roseQuartz.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _mode = _mode == _ReaderMode.paginated
                    ? _ReaderMode.longStrip
                    : _ReaderMode.paginated;
              });
            },
            icon: Icon(
              _mode == _ReaderMode.paginated
                  ? Icons.view_stream_rounded
                  : Icons.view_day_rounded,
              color: AppTheme.petalWhite,
              size: 22,
            ),
            tooltip: _mode == _ReaderMode.paginated
                ? 'Long strip mode'
                : 'Paginated mode',
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.deepRose),
          SizedBox(height: 16),
          Text(
            'Loading pages...',
            style: TextStyle(color: AppTheme.roseQuartz),
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
              style: GoogleFonts.outfit(color: AppTheme.petalWhite),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _loadError = null;
                });
                _loadPages();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReader() {
    if (_pages == null) return const SizedBox.shrink();
    final pageCount = _pages!.filenames.length;

    if (_mode == _ReaderMode.paginated) {
      return PageView.builder(
        controller: _pageController,
        itemCount: pageCount,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final url = _pages!.urlForPage(index);
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                _service.proxiedImageUrl(url),
                fit: BoxFit.contain,
                cacheWidth: 1200,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.deepRose,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stack) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image,
                            color: AppTheme.roseQuartz, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Page ${index + 1} failed to load',
                          style: GoogleFonts.outfit(
                              color: AppTheme.roseQuartz),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    } else {
      return ListView.builder(
        itemCount: pageCount,
        itemBuilder: (context, index) {
          final url = _pages!.urlForPage(index);
          return Image.network(
            _service.proxiedImageUrl(url),
            fit: BoxFit.contain,
            cacheWidth: 1200,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 400,
                alignment: Alignment.center,
                child: CircularProgressIndicator(
                  color: AppTheme.deepRose,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stack) => Container(
              height: 200,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image,
                      color: AppTheme.roseQuartz),
                  const SizedBox(height: 4),
                  Text(
                    'Page ${index + 1} failed to load',
                    style: GoogleFonts.outfit(
                        color: AppTheme.roseQuartz, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildBottomBar() {
    if (_pages == null) return const SizedBox(height: 56);
    final pageCount = _pages!.filenames.length;
    final prev = _previousChapter;
    final next = _nextChapter;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Color(0x33F4C2C2), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed:
                prev == null ? null : () => _goToChapter(prev),
            icon: const Icon(Icons.skip_previous_rounded),
            color: prev == null
                ? AppTheme.roseQuartz.withValues(alpha: 0.3)
                : AppTheme.petalWhite,
            tooltip: prev == null ? null : 'Previous chapter',
          ),
          Expanded(
            child: Center(
              child: Text(
                'Page ${_currentPage + 1} / $pageCount',
                style: GoogleFonts.outfit(
                  color: AppTheme.roseQuartz,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed:
                next == null ? null : () => _goToChapter(next),
            icon: const Icon(Icons.skip_next_rounded),
            color: next == null
                ? AppTheme.roseQuartz.withValues(alpha: 0.3)
                : AppTheme.petalWhite,
            tooltip: next == null ? null : 'Next chapter',
          ),
        ],
      ),
    );
  }
}
