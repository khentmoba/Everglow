import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/offline_media/offline_media_service.dart';
import '../../../../core/services/offline_media/offline_media_storage.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/katana_models.dart';
import '../../data/services/katana_service.dart';
import '../katana/chapter_picker_sheet.dart';
import '../katana/katana_theme.dart';
import '../katana/reader_settings_sheet.dart';
import '../katana/webtoon_page_tracker.dart';
import '../widgets/reader_page_image.dart';
import '../../../../core/utils/logger.dart';

part 'katana_reader_viewers.dart';
part 'katana_reader_chrome.dart';

@visibleForTesting
void scrollReaderWithWheel(
  PointerSignalEvent event,
  ScrollController controller,
) {
  if (event is! PointerScrollEvent || !controller.hasClients) return;
  final delta = event.scrollDelta.dy;
  if (delta == 0) return;
  final position = controller.position;
  final target = (position.pixels + delta)
      .clamp(position.minScrollExtent, position.maxScrollExtent)
      .toDouble();
  if (target != position.pixels) position.jumpTo(target);
}

@visibleForTesting
int pagedItemForPage(int page, {required bool twoPage}) {
  final zeroBased = page - 1;
  return twoPage ? zeroBased ~/ 2 : zeroBased;
}

@visibleForTesting
int lastPagedItem(int pageCount, {required bool twoPage}) =>
    twoPage ? (pageCount / 2).ceil() : pageCount;

@visibleForTesting
double proportionalResumeOffset(
  int target,
  int pageCount,
  double maxScrollExtent,
) {
  if (pageCount <= 1) return 0;
  return target * maxScrollExtent / (pageCount - 1);
}

class KatanaReaderScreen extends StatefulWidget {
  @visibleForTesting
  static bool isDesktopWeb({
    required bool isWeb,
    required TargetPlatform platform,
  }) =>
      isWeb &&
      (platform == TargetPlatform.windows ||
          platform == TargetPlatform.macOS ||
          platform == TargetPlatform.linux);

  final String slug;
  final String chapterId;
  final List<KatanaChapter> chapters;
  final String mangaTitle;
  final String coverUrl;
  final int initialPage;

  final KatanaManga? manga;

  const KatanaReaderScreen({
    super.key,
    required this.slug,
    required this.chapterId,
    required this.chapters,
    required this.mangaTitle,
    this.coverUrl = '',
    this.initialPage = 1,
    this.manga,
  });

  @override
  State<KatanaReaderScreen> createState() => _KatanaReaderScreenState();
}

class _KatanaReaderScreenState extends State<KatanaReaderScreen> {
  final KatanaService _service = KatanaService();
  final ScrollController _scrollController = ScrollController();
  late PageController _pageController;
  final TransformationController _transformController =
      TransformationController();

  late List<KatanaChapter> _chapters;
  late KatanaChapter _chapter;
  List<String> _pages = const [];
  bool _loading = true;
  String? _error;
  String _server = '';

  bool _chaptersIncomplete = false;

  bool _showChrome = false;
  ReaderMode _mode = ReaderMode.webtoon;
  ReaderThemeStyle _themeStyle = ReaderThemeStyle.plum;
  double _brightness = 1.0;
  bool _twoPage = false;
  bool _fitHeight = true;
  bool _bookmarked = false;

  int _currentPage = 1;
  int _lastSavedPage = -1;
  bool _showPagePill = false;
  Timer? _pagePillTimer;

  final WebtoonPageTracker _tracker = WebtoonPageTracker();
  final Map<int, GlobalKey> _pageKeys = {};

  int? _pendingResumePage;

  double? _lastJumpOffset;

  bool _pagedInitialJumpDone = false;

  bool _markedRead = false;

  Set<String> _readChapterIds = const {};

  final Map<int, int> _cdnStep = {};
  final Set<String> _fallbackScheduled = {};
  final Set<int> _failedPages = {};
  bool _tokenRefreshed = false;
  bool _refreshingTokens = false;

  String get _user => context.read<AuthService>().currentUser ?? '';

  int get _currentIndex {
    final i = _chapters.indexWhere((c) => c.id == _chapter.id);
    return i < 0 ? 0 : i;
  }

  KatanaChapter? get _prevChapter =>
      _currentIndex > 0 ? _chapters[_currentIndex - 1] : null;

  KatanaChapter? get _nextChapter => _currentIndex < _chapters.length - 1
      ? _chapters[_currentIndex + 1]
      : null;

  void _refresh(void Function() update) => setState(update);

  Duration get _chromeMotion => AppMotion.orZero(AppMotion.medium);

  @override
  void initState() {
    super.initState();
    _chapters = sortChaptersAscending(widget.chapters);
    _chaptersIncomplete = widget.chapters.length < 8;
    final initial =
        _chapters.where((c) => c.id == widget.chapterId).firstOrNull;
    _chapter = initial ??
        (_chapters.isNotEmpty
            ? _chapters.first
            : KatanaChapter(
                id: widget.chapterId,
                num: '',
                title: widget.chapterId,
              ));

    final startPage = widget.initialPage > 1 ? widget.initialPage : 1;
    _currentPage = startPage;
    _pageController = PageController(initialPage: startPage - 1);
    _scrollController.addListener(_onWebtoonScroll);

    _loadPreferences();
    _loadPages();
    _loadBookmark();
    _loadFullChaptersIfNeeded();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _revokeCurrentPageBlobs() {
    for (final p in _pages) {
      if (p.startsWith('blob:')) {
        unawaited(OfflineMediaStorage.instance.revokeBlobUrl(p));
      }
    }
  }

  @override
  void dispose() {
    _revokeCurrentPageBlobs();
    _pagePillTimer?.cancel();
    _scrollController.removeListener(_onWebtoonScroll);
    _scrollController.dispose();
    _pageController.dispose();
    _transformController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    PaintingBinding.instance.imageCache.clearLiveImages();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString('katana_reader_mode');
      final themeStr = prefs.getString('katana_reader_theme');
      final brightnessVal = prefs.getDouble('katana_reader_brightness');
      final twoPageVal = prefs.getBool('katana_reader_two_page');
      final fitHeightVal = prefs.getBool('katana_reader_fit_height');

      if (!mounted) return;
      setState(() {
        if (modeStr != null) {
          _mode = ReaderMode.values.firstWhere(
            (m) => m.name == modeStr,
            orElse: () => ReaderMode.webtoon,
          );
        }
        if (themeStr != null) {
          _themeStyle = ReaderThemeStyle.values.firstWhere(
            (t) => t.name == themeStr,
            orElse: () => ReaderThemeStyle.plum,
          );
        }
        if (brightnessVal != null) {
          _brightness = brightnessVal.clamp(0.2, 1.0);
        }
        if (twoPageVal != null) {
          _twoPage = twoPageVal;
        }
        if (fitHeightVal != null) {
          _fitHeight = fitHeightVal;
        }
      });
    } catch (e, st) {
      Logger.e(
        'KatanaReaderScreen: failed to load reader preferences',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('katana_reader_mode', _mode.name);
      await prefs.setString('katana_reader_theme', _themeStyle.name);
      await prefs.setDouble('katana_reader_brightness', _brightness);
      await prefs.setBool('katana_reader_two_page', _twoPage);
      await prefs.setBool('katana_reader_fit_height', _fitHeight);
    } catch (e, st) {
      Logger.e(
        'KatanaReaderScreen: failed to save reader preferences',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _loadBookmark() async {
    final bookmark = await _service.fetchBookmark(widget.slug, _user);
    if (!mounted) return;
    setState(() {
      _bookmarked = bookmark?.isBookmarked ?? false;
      _readChapterIds = {..._readChapterIds, ...?bookmark?.readChapterIds};
    });
  }

  Future<void> _loadFullChaptersIfNeeded() async {
    if (widget.chapters.length >= 8) return;
    try {
      final detail = await _service.fetchMangaDetail(widget.slug);
      if (detail == null || detail.chapters.length <= _chapters.length) return;
      if (!mounted) return;
      final full = sortChaptersAscending(detail.chapters);
      setState(() {
        _chapters = full;
        _chaptersIncomplete = false;
        final match = full.where((c) => c.id == _chapter.id).firstOrNull;
        if (match != null) _chapter = match;
      });
    } catch (e, st) {
      Logger.e(
        'KatanaReaderScreen: failed to load full chapter list for ${widget.slug}',
        error: e,
        stackTrace: st,
      );
    }
  }

  bool _autoRetried = false;

  Future<void> _loadPages() async {
    final resumePage = _currentPage;
    setState(() {
      _loading = true;
      _error = null;
      _cdnStep.clear();
      _failedPages.clear();
      _fallbackScheduled.clear();
      _tokenRefreshed = false;
      _markedRead = false;
    });

    final offlineId =
        OfflineMediaService.mangaChapterId(widget.slug, _chapter.id);
    final offlineItem = OfflineMediaService.instance.getItem(offlineId);
    if (offlineItem != null &&
        offlineItem.isCompleted &&
        offlineItem.pageUrls.isNotEmpty) {
      final resolvedPages = <String>[];
      for (var i = 1; i <= offlineItem.pageUrls.length; i++) {
        final blob = await OfflineMediaService.instance.getMangaPageUrl(
          offlineId,
          i,
        );
        resolvedPages.add(blob ?? offlineItem.pageUrls[i - 1]);
      }
      if (!mounted) return;
      _revokeCurrentPageBlobs();
      setState(() {
        _pages = resolvedPages;
        _loading = false;
        _error = null;
      });
      return;
    }

    var pages = await _service.fetchChapterPages(
      widget.slug,
      _chapter.path,
      server: _server,
    );

    if (pages.isEmpty && !_autoRetried) {
      _autoRetried = true;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      pages = await _service.fetchChapterPages(
        widget.slug,
        _chapter.path,
        server: _server,
        forceRefresh: true,
      );
    }

    if (!mounted) return;
    if (pages.isEmpty) {
      setState(() {
        _loading = false;
        _error =
            'This chapter could not load right now. Check your connection '
            'and try again — if it keeps failing, the source site may be down.';
      });
      return;
    }

    final targetPage = resumePage.clamp(1, pages.length);

    _revokeCurrentPageBlobs();
    setState(() {
      _pages = pages;
      _loading = false;
      _autoRetried = false;
      _currentPage = targetPage;
      _pagedInitialJumpDone = false;
    });
    if (_tracker.pageCount != pages.length) {
      _tracker.reset(pages.length);
      _pageKeys.clear();
    }
    _pendingResumePage = null;

    _lastSavedPage = targetPage;
    _saveProgress(targetPage);

    if (targetPage >= pages.length) _markChapterRead();

    _preloadUpcoming(targetPage - 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_mode == ReaderMode.webtoon && _scrollController.hasClients) {
        if (targetPage > 1 && _pages.length > 1) {
          _resumeToWebtoonPage(targetPage);
        } else {
          _scrollController.jumpTo(0);
        }
      } else if (_pageController.hasClients) {
        _pageController.jumpToPage(
          pagedItemForPage(targetPage, twoPage: _useTwoPage),
        );
      }
      _pagedInitialJumpDone = true;
      _triggerPagePill();
    });
  }

  void _resumeToWebtoonPage(int page) {
    if (!mounted || !_scrollController.hasClients) return;
    final target = page.clamp(1, _pages.length) - 1;
    _pendingResumePage = target;
    _jumpWebtoonToOffset(
      proportionalResumeOffset(
        target,
        _pages.length,
        _scrollController.position.maxScrollExtent,
      ),
    );
  }

  void _jumpWebtoonTo(int target) {
    if (!_scrollController.hasClients) return;
    _jumpWebtoonToOffset(_tracker.offsetForPage(target));
  }

  void _jumpWebtoonToOffset(double offset) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = offset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _lastJumpOffset = target;
    _scrollController.jumpTo(target);
  }

  void _preloadUpcoming(int currentIndex) {
    if (_pages.isEmpty || !mounted) return;
    final start = (currentIndex + 1).clamp(0, _pages.length);
    final end = (currentIndex + 4).clamp(0, _pages.length);
    for (int i = start; i < end; i++) {
      final url = _proxiedPageUrl(i);
      if (url.isNotEmpty) {
        ReaderPageImage.precachePage(context, url);
      }
    }
  }

  void _onWebtoonScroll() {
    if (!_scrollController.hasClients || _pages.isEmpty) return;
    final lastJump = _lastJumpOffset;
    if (_pendingResumePage != null &&
        lastJump != null &&
        (_scrollController.offset - lastJump).abs() > 1) {
      _pendingResumePage = null;
    }
    if (_pendingResumePage != null) return;
    final page = _tracker.pageAtOffset(_scrollController.offset) + 1;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
      _triggerPagePill();
      _preloadUpcoming(page - 1);
      if (page != _lastSavedPage && page % 3 == 0) {
        _lastSavedPage = page;
        _saveProgress(page);
      }
      if (page >= _pages.length) _markChapterRead();
    }
  }

  void _onPageChanged(int index) {
    final page = index + 1;
    setState(() => _currentPage = page);
    _triggerPagePill();
    _preloadUpcoming(index);
    if (page != _lastSavedPage) {
      _lastSavedPage = page;
      _saveProgress(page);
    }
    if (page >= _pages.length) _markChapterRead();
  }

  void _measurePage(int index) {
    final renderObject = _pageKeys[index]?.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      _tracker.measure(index, renderObject.size.height);
    }
  }

  void _onPageLoaded(int index) {
    if (!mounted || index >= _pages.length) return;
    _measurePage(index);
    final pending = _pendingResumePage;
    if (pending == null || index != pending) return;
    _pendingResumePage = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jumpWebtoonTo(pending);
    });
  }

  bool get _useTwoPage =>
      _twoPage && MediaQuery.sizeOf(context).width >= 840;

  GlobalKey _pageKey(int index) =>
      _pageKeys.putIfAbsent(index, () => GlobalKey());

  Future<void> _markChapterRead() async {
    if (_markedRead || _user.isEmpty) return;
    _markedRead = true;
    final chapterId = _chapter.id;
    await _service.markChapterRead(
      widget.slug,
      _user,
      chapterId,
      title: widget.mangaTitle,
      coverUrl: widget.coverUrl,
    );
    if (!mounted) return;
    setState(() => _readChapterIds = {..._readChapterIds, chapterId});
  }

  void _triggerPagePill() {
    _pagePillTimer?.cancel();
    if (!_showPagePill && mounted) {
      setState(() => _showPagePill = true);
    }
    _pagePillTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _showPagePill = false);
    });
  }

  Future<void> _saveProgress(int page) async {
    await _service.saveReadingProgress(
      slug: widget.slug,
      userName: _user,
      chapterId: _chapter.id,
      chapterTitle: _chapter.displayTitle,
      page: page,
      title: widget.mangaTitle,
      coverUrl: widget.coverUrl,
    );
  }

  void _goToChapter(KatanaChapter chapter) {
    if (chapter.id == _chapter.id) return;
    _saveProgress(_lastSavedPage < 0 ? 1 : _lastSavedPage);
    PaintingBinding.instance.imageCache.clearLiveImages();
    setState(() {
      _chapter = chapter;
      _pages = const [];
      _lastSavedPage = -1;
      _currentPage = 1;
      _markedRead = false;
      _transformController.value = Matrix4.identity();
      _cdnStep.clear();
      _failedPages.clear();
      _fallbackScheduled.clear();
      _tokenRefreshed = false;
      _autoRetried = false;
    });
    _tracker.reset(0);
    _pageKeys.clear();
    if (!_chapters.any((c) => c.id == chapter.id) || _chaptersIncomplete) {
      _loadFullChaptersIfNeeded();
    }
    _loadPages();
  }

  void _jumpToPage(int page) {
    final target = page.clamp(1, _pages.length);
    setState(() => _currentPage = target);
    _triggerPagePill();
    if (target >= _pages.length) _markChapterRead();

    if (_mode == ReaderMode.webtoon) {
      if (_scrollController.hasClients && _pages.length > 1) {
        final position = _scrollController.position;
        _scrollController.animateTo(
          _tracker
              .offsetForPage(target - 1)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble(),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    } else {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(
          pagedItemForPage(target, twoPage: _useTwoPage),
        );
      }
    }
  }

  void _toggleChrome() {
    setState(() => _showChrome = !_showChrome);
    if (_showChrome) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _openSettings() {
    ReaderSettingsSheet.show(
      context,
      currentMode: _mode,
      currentTheme: _themeStyle,
      brightness: _brightness,
      twoPage: _twoPage,
      currentServer: _server,
      onModeChanged: (newMode) {
        setState(() => _mode = newMode);
        _savePreferences();
      },
      onThemeChanged: (newTheme) {
        setState(() => _themeStyle = newTheme);
        _savePreferences();
      },
      onBrightnessChanged: (newBrightness) {
        setState(() => _brightness = newBrightness);
        _savePreferences();
      },
      onTwoPageChanged: (newTwoPage) {
        setState(() => _twoPage = newTwoPage);
        _savePreferences();
      },
      onServerChanged: (newServer) {
        if (_server != newServer) {
          setState(() => _server = newServer);
          _loadPages();
        }
      },
    );
  }

  void _openChapterPicker() {
    ChapterPickerSheet.show(
      context,
      chapters: _chapters,
      currentChapter: _chapter,
      readChapterIds: _readChapterIds,
      onChapterSelected: (c) => _goToChapter(c),
    );
  }

  void _changeServer(String server) {
    if (_server == server) return;
    setState(() => _server = server);
    _loadPages();
  }

  void _setDarken(double percent) {
    setState(() {
      _brightness = (1.0 - percent / 100).clamp(0.2, 1.0);
    });
    _savePreferences();
  }

  Future<void> _toggleBookmark() async {
    if (_user.isEmpty) {
      _showSnack('Sign in to bookmark chapters.');
      return;
    }
    final next = !_bookmarked;
    setState(() => _bookmarked = next);
    final manga = next
        ? (widget.manga ?? await _service.fetchMangaDetail(widget.slug))
        : widget.manga ??
              KatanaManga(
                slug: widget.slug,
                id: widget.slug,
                title: widget.mangaTitle,
                coverUrl: widget.coverUrl,
              );
    if (manga == null) {
      if (mounted) setState(() => _bookmarked = !next);
      _showSnack('Could not update the bookmark. Try again.');
      return;
    }
    await _service.setBookmark(manga, _user, bookmarked: next);
    if (next) await _saveProgress(_currentPage);
    _showSnack(next ? 'Chapter bookmarked' : 'Bookmark removed');
  }

  void _showSnack(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: KatanaType.body.copyWith(color: Colors.white),
        ),
        backgroundColor: KatanaColors.headerDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      _transformController.value = Matrix4.diagonal3Values(2.4, 2.4, 1.0);
    }
  }

  void _handleKeyScroll(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _reportChapter() async {
    final url =
        'https://mangakatana.com/manga/${widget.slug}/${_chapter.path}';
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KatanaColors.surface,
        title: const Text('Report chapter error'),
        content: const Text(
          'If this chapter has broken pages or wrong content, you can report it on the source site directly.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'copy'),
            child: const Text('Copy link'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'open'),
            child: const Text('Open source site'),
          ),
        ],
      ),
    );
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: url));
      _showSnack('Link copied');
    } else if (action == 'open') {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (_mode == ReaderMode.webtoon) return;
          _advancePaged(_mode == ReaderMode.pagedRTL ? 1 : -1);
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (_mode == ReaderMode.webtoon) return;
          _advancePaged(_mode == ReaderMode.pagedRTL ? -1 : 1);
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          if (_mode == ReaderMode.webtoon) _handleKeyScroll(300);
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          if (_mode == ReaderMode.webtoon) _handleKeyScroll(-300);
        },
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (_mode == ReaderMode.webtoon) {
            _handleKeyScroll(500);
          } else {
            _advancePaged(_mode == ReaderMode.pagedRTL ? 1 : 1);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            await _saveProgress(_currentPage);
            navigator.pop();
          },
          child: Scaffold(
            backgroundColor: _themeStyle.backgroundColor,
            body: Stack(
              children: [
                Positioned.fill(child: _buildReaderBody()),

                if (_brightness < 1.0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withValues(
                          alpha: (1.0 - _brightness).clamp(0.0, 0.85),
                        ),
                      ),
                    ),
                  ),

                if (_themeStyle == ReaderThemeStyle.sepia)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: const Color(0x10FF9E0B),
                      ),
                    ),
                  ),

                AnimatedPositioned(
                  duration: _chromeMotion,
                  curve: AppMotion.drawer,
                  bottom: _showChrome
                      ? 136 + MediaQuery.paddingOf(context).bottom
                      : 26,
                  right: 16,
                  child: AnimatedOpacity(
                    opacity: _showPagePill ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: KatanaColors.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: KatanaColors.borderStrong,
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$_currentPage',
                              style: AppTypography.outfitBold.copyWith(
                                color: KatanaColors.accent,
                                fontSize: 12,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${_pages.length}',
                              style: AppTypography.outfitBold.copyWith(
                                color: KatanaColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                if (!_showChrome && _pages.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: SizedBox(
                        height: 2,
                        child: LinearProgressIndicator(
                          value: (_currentPage / _pages.length).clamp(0.0, 1.0),
                          backgroundColor: KatanaColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            KatanaColors.accent,
                          ),
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  key: const ValueKey('reader-top-chrome'),
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    offset: _showChrome ? Offset.zero : const Offset(0, -1),
                    duration: _chromeMotion,
                    curve: AppMotion.drawer,
                    child: AnimatedOpacity(
                      opacity: _showChrome ? 1.0 : 0.0,
                      duration: _chromeMotion,
                      curve: AppMotion.drawer,
                      child: _buildTopChrome(),
                    ),
                  ),
                ),

                Positioned(
                  key: const ValueKey('reader-bottom-chrome'),
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    offset: _showChrome ? Offset.zero : const Offset(0, 1),
                    duration: _chromeMotion,
                    curve: AppMotion.drawer,
                    child: AnimatedOpacity(
                      opacity: _showChrome ? 1.0 : 0.0,
                      duration: _chromeMotion,
                      curve: AppMotion.drawer,
                      child: _buildBottomChrome(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
