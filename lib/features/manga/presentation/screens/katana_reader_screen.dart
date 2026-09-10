import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/katana_models.dart';
import '../../data/services/katana_service.dart';
import '../katana/chapter_picker_sheet.dart';
import '../katana/katana_theme.dart';
import '../katana/reader_settings_sheet.dart';

/// Overhauled MangaCelestia Reader Screen:
/// - Full-screen immersive mode with tap-to-toggle controls
/// - Webtoon (0px continuous vertical strip), Manga RTL, and Paged LTR modes
/// - Pinch-to-zoom & double-tap zoom via InteractiveViewer
/// - Live floating page indicator pill and bottom scrubber slider
/// - Pre-caching upcoming pages & silent backup server failover
/// - Tablet two-page spread support
/// - Night dimmer and theme selection (OLED Black, Plum Night, Warm Sepia)
/// - Keyboard arrow navigation for desktop & tablet keyboards
class KatanaReaderScreen extends StatefulWidget {
  final String slug;
  final String chapterId;
  final List<KatanaChapter> chapters;
  final String mangaTitle;
  final String coverUrl;

  const KatanaReaderScreen({
    super.key,
    required this.slug,
    required this.chapterId,
    required this.chapters,
    required this.mangaTitle,
    this.coverUrl = '',
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

  // Reader UX Settings
  bool _showChrome = false;
  ReaderMode _mode = ReaderMode.webtoon;
  ReaderThemeStyle _themeStyle = ReaderThemeStyle.plum;
  double _brightness = 1.0;
  bool _twoPage = false;
  bool _bookmarked = false;

  // Page Tracking
  int _currentPage = 1;
  int _lastSavedPage = -1;
  bool _showPagePill = false;
  Timer? _pagePillTimer;

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

  @override
  void initState() {
    super.initState();
    _chapters = sortChaptersAscending(widget.chapters);
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

    _pageController = PageController(initialPage: 0);
    _scrollController.addListener(_onWebtoonScroll);

    _loadPreferences();
    _loadPages();
    _loadBookmark();

    // Start in immersive mode by default
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pagePillTimer?.cancel();
    _scrollController.removeListener(_onWebtoonScroll);
    _scrollController.dispose();
    _pageController.dispose();
    _transformController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString('katana_reader_mode');
      final themeStr = prefs.getString('katana_reader_theme');
      final brightnessVal = prefs.getDouble('katana_reader_brightness');
      final twoPageVal = prefs.getBool('katana_reader_two_page');

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
      });
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('katana_reader_mode', _mode.name);
      await prefs.setString('katana_reader_theme', _themeStyle.name);
      await prefs.setDouble('katana_reader_brightness', _brightness);
      await prefs.setBool('katana_reader_two_page', _twoPage);
    } catch (_) {}
  }

  Future<void> _loadBookmark() async {
    final bookmarked = await _service.isBookmarked(widget.slug, _user);
    if (mounted) setState(() => _bookmarked = bookmarked);
  }

  Future<void> _loadPages() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentPage = 1;
    });

    var pages = await _service.fetchChapterPages(
      widget.slug,
      _chapter.path,
      server: _server,
    );

    // Silent fallback: if Primary server is empty, try Server 2 (?sv=mk)
    if (pages.isEmpty && _server.isEmpty) {
      pages = await _service.fetchChapterPages(
        widget.slug,
        _chapter.path,
        server: '?sv=mk',
      );
      if (pages.isNotEmpty) {
        _server = '?sv=mk';
      }
    }

    if (!mounted) return;
    if (pages.isEmpty) {
      setState(() {
        _loading = false;
        _error =
            'This chapter could not load from the current server. Try switching backup servers in settings.';
      });
      return;
    }

    setState(() {
      _pages = pages;
      _loading = false;
    });

    _preloadUpcoming(0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mode == ReaderMode.webtoon && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      } else if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _triggerPagePill();
    });
  }

  void _preloadUpcoming(int currentIndex) {
    if (_pages.isEmpty || !mounted) return;
    final start = (currentIndex + 1).clamp(0, _pages.length);
    final end = (currentIndex + 4).clamp(0, _pages.length);
    for (int i = start; i < end; i++) {
      final url = _service.proxiedImageUrl(_pages[i]);
      if (url.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(url), context)
            .catchError((_) {});
      }
    }
  }

  void _onWebtoonScroll() {
    if (!_scrollController.hasClients || _pages.isEmpty) return;
    final offset = _scrollController.offset;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;

    final ratio = (offset / max).clamp(0.0, 1.0);
    final page = (ratio * (_pages.length - 1)).round() + 1;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
      _triggerPagePill();
      _preloadUpcoming(page - 1);
      if (page != _lastSavedPage && page % 3 == 0) {
        _lastSavedPage = page;
        _saveProgress(page);
      }
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
    );
  }

  void _goToChapter(KatanaChapter chapter) {
    if (chapter.id == _chapter.id) return;
    _saveProgress(_lastSavedPage < 0 ? 1 : _lastSavedPage);
    setState(() {
      _chapter = chapter;
      _pages = const [];
      _lastSavedPage = -1;
      _transformController.value = Matrix4.identity();
    });
    _loadPages();
  }

  void _jumpToPage(int page) {
    final target = page.clamp(1, _pages.length);
    setState(() => _currentPage = target);
    _triggerPagePill();

    if (_mode == ReaderMode.webtoon) {
      if (_scrollController.hasClients && _pages.length > 1) {
        final perPage =
            _scrollController.position.maxScrollExtent / (_pages.length - 1);
        _scrollController.animateTo(
          (target - 1) * perPage,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    } else {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(target - 1);
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
      onChapterSelected: (c) => _goToChapter(c),
    );
  }

  Future<void> _toggleBookmark() async {
    if (_user.isEmpty) {
      _showSnack('Sign in to bookmark chapters.');
      return;
    }
    final next = !_bookmarked;
    setState(() => _bookmarked = next);
    await _service.setBookmark(
      KatanaManga(
        slug: widget.slug,
        id: widget.slug,
        title: widget.mangaTitle,
        coverUrl: widget.coverUrl,
        status: 'ongoing',
        latestChapter: _chapter,
      ),
      _user,
      bookmarked: next,
    );
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
                // Reader Content Layer
                Positioned.fill(child: _buildReaderBody()),

                // Night Dimmer / Tint Filter
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

                // Live Floating Page Indicator Pill
                Positioned(
                  bottom: _showChrome ? 120 : 26,
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
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 0.8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$_currentPage / ${_pages.length}',
                        style: AppTypography.outfitBold.copyWith(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),

                // Top Floating Chrome Header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    offset: _showChrome ? Offset.zero : const Offset(0, -1),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeInOut,
                    child: AnimatedOpacity(
                      opacity: _showChrome ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 240),
                      child: _buildTopChrome(),
                    ),
                  ),
                ),

                // Bottom Floating Chrome Footer
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    offset: _showChrome ? Offset.zero : const Offset(0, 1),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeInOut,
                    child: AnimatedOpacity(
                      opacity: _showChrome ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 240),
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

  Widget _buildReaderBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: KatanaColors.accent),
            const SizedBox(height: 16),
            Text(
              'Loading ${_chapter.displayTitle}...',
              style: AppTypography.outfitBold.copyWith(
                color: KatanaColors.text,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_rounded,
                size: 46,
                color: KatanaColors.textLight,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: KatanaType.body,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KatanaButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    onTap: _loadPages,
                  ),
                  const SizedBox(width: 10),
                  KatanaButton(
                    label: 'Settings',
                    icon: Icons.tune_rounded,
                    onTap: _openSettings,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_mode == ReaderMode.webtoon) {
      return _buildWebtoonViewer();
    } else {
      return _buildPagedViewer();
    }
  }

  // ── Webtoon Continuous Mode ───────────────────────────────────────
  Widget _buildWebtoonViewer() {
    final width = MediaQuery.sizeOf(context).width;
    final maxContentWidth = width > 850 ? 850.0 : double.infinity;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _toggleChrome,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 1.0,
        maxScale: 3.5,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: _pages.length + 1,
              itemBuilder: (context, index) {
                if (index == _pages.length) return _buildEndCard();
                return _buildWebtoonImage(index);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebtoonImage(int index) {
    final url = _service.proxiedImageUrl(_pages[index]);

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.fitWidth,
      width: double.infinity,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (context, url) => Container(
        height: 380,
        alignment: Alignment.center,
        color: _themeStyle.surfaceColor,
        child: CircularProgressIndicator(
          color: KatanaColors.accent.withValues(alpha: 0.4),
          strokeWidth: 2.2,
        ),
      ),
      errorWidget: (context, url, error) => _buildImageError(index),
    );
  }

  // ── Paged Mode (RTL for Manga, LTR for Western) ───────────────────
  Widget _buildPagedViewer() {
    final isRTL = _mode == ReaderMode.pagedRTL;
    final width = MediaQuery.sizeOf(context).width;
    final useTwoPage = _twoPage && width >= 840;

    final totalItems = useTwoPage
        ? (_pages.length / 2).ceil() + 1
        : _pages.length + 1;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final dx = details.localPosition.dx;

        // Left 28% edge
        if (dx < screenWidth * 0.28) {
          if (isRTL) {
            _advancePaged(1);
          } else {
            _advancePaged(-1);
          }
        }
        // Right 28% edge
        else if (dx > screenWidth * 0.72) {
          if (isRTL) {
            _advancePaged(-1);
          } else {
            _advancePaged(1);
          }
        }
        // Center 44% zone: toggle chrome
        else {
          _toggleChrome();
        }
      },
      child: PageView.builder(
        controller: _pageController,
        reverse: isRTL,
        physics: const BouncingScrollPhysics(),
        itemCount: totalItems,
        onPageChanged: (pageIndex) {
          if (useTwoPage) {
            final firstPageIndex = pageIndex * 2;
            _onPageChanged(math.min(firstPageIndex, _pages.length - 1));
          } else {
            if (pageIndex < _pages.length) {
              _onPageChanged(pageIndex);
            }
          }
        },
        itemBuilder: (context, index) {
          if (useTwoPage) {
            final pageA = index * 2;
            final pageB = pageA + 1;
            if (pageA >= _pages.length) return _buildEndCard();

            return InteractiveViewer(
              minScale: 1.0,
              maxScale: 3.5,
              child: Row(
                children: [
                  Expanded(
                    child: _buildSinglePagedImage(
                      isRTL ? (pageB < _pages.length ? pageB : pageA) : pageA,
                    ),
                  ),
                  if (pageB < _pages.length)
                    Expanded(
                      child: _buildSinglePagedImage(
                        isRTL ? pageA : pageB,
                      ),
                    ),
                ],
              ),
            );
          }

          if (index == _pages.length) return _buildEndCard();

          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 3.5,
            child: Center(
              child: _buildSinglePagedImage(index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSinglePagedImage(int index) {
    final url = _service.proxiedImageUrl(_pages[index]);

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (context, url) => Container(
        alignment: Alignment.center,
        color: _themeStyle.surfaceColor,
        child: CircularProgressIndicator(
          color: KatanaColors.accent.withValues(alpha: 0.4),
          strokeWidth: 2.2,
        ),
      ),
      errorWidget: (context, url, error) => _buildImageError(index),
    );
  }

  void _advancePaged(int delta) {
    if (!_pageController.hasClients) return;
    final current = _pageController.page?.round() ?? 0;
    final target = current + delta;
    if (target >= 0 && target <= _pages.length) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildImageError(int index) {
    return Container(
      height: 240,
      alignment: Alignment.center,
      color: _themeStyle.surfaceColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_rounded,
            color: KatanaColors.textLight,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Page ${index + 1} failed to load',
            style: KatanaType.small,
          ),
          const SizedBox(height: 8),
          KatanaButton(
            label: 'Retry page',
            icon: Icons.refresh_rounded,
            onTap: () {
              CachedNetworkImage.evictFromCache(
                _service.proxiedImageUrl(_pages[index]),
              );
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  // ── End of Chapter Card ───────────────────────────────────────────
  Widget _buildEndCard() {
    final next = _nextChapter;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KatanaColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: KatanaColors.accent,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chapter Completed',
            style: KatanaType.small.copyWith(
              color: KatanaColors.accent,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _chapter.displayTitle,
            style: AppTypography.outfitBold.copyWith(
              color: KatanaColors.text,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (next != null) ...[
            Text(
              'Up Next: ${next.displayTitle}',
              style: KatanaType.small,
            ),
            const SizedBox(height: 12),
            KatanaButton(
              label: 'Read Next Chapter ▶',
              icon: Icons.arrow_forward_rounded,
              onTap: () => _goToChapter(next),
            ),
          ] else
            Column(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: KatanaColors.green,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  'You have caught up with the latest chapter!',
                  style: KatanaType.body.copyWith(
                    color: KatanaColors.textMuted,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Floating Top Chrome ───────────────────────────────────────────
  Widget _buildTopChrome() {
    return Container(
      decoration: BoxDecoration(
        color: _themeStyle.surfaceColor.withValues(alpha: 0.94),
        border: const Border(
          bottom: BorderSide(color: KatanaColors.border, width: 0.8),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await _saveProgress(_currentPage);
                  navigator.pop();
                },
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: KatanaColors.text,
                ),
                tooltip: 'Back',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.mangaTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitBold.copyWith(
                        color: KatanaColors.text,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      _chapter.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KatanaType.small.copyWith(
                        color: KatanaColors.accent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color:
                      _bookmarked ? KatanaColors.green : KatanaColors.textMuted,
                  size: 22,
                ),
                tooltip: _bookmarked ? 'Bookmarked' : 'Bookmark chapter',
                onPressed: _toggleBookmark,
              ),
              IconButton(
                icon: const Icon(
                  Icons.tune_rounded,
                  color: KatanaColors.text,
                  size: 21,
                ),
                tooltip: 'Reader settings',
                onPressed: _openSettings,
              ),
              IconButton(
                icon: const Icon(
                  Icons.warning_amber_rounded,
                  color: KatanaColors.textLight,
                  size: 20,
                ),
                tooltip: 'Report error',
                onPressed: _reportChapter,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Floating Bottom Chrome ────────────────────────────────────────
  Widget _buildBottomChrome() {
    return Container(
      decoration: BoxDecoration(
        color: _themeStyle.surfaceColor.withValues(alpha: 0.94),
        border: const Border(
          top: BorderSide(color: KatanaColors.border, width: 0.8),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scrubber Row
              if (_pages.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      '$_currentPage',
                      style: AppTypography.outfitBold.copyWith(
                        color: KatanaColors.accent,
                        fontSize: 12.5,
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.5,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: _currentPage
                              .toDouble()
                              .clamp(1.0, math.max(1.0, _pages.length.toDouble())),
                          min: 1.0,
                          max: math.max(1.0, _pages.length.toDouble()),
                          divisions: math.max(1, _pages.length - 1),
                          activeColor: KatanaColors.accent,
                          inactiveColor: KatanaColors.border,
                          onChanged: (v) {
                            _jumpToPage(v.round());
                          },
                        ),
                      ),
                    ),
                    Text(
                      '${_pages.length}',
                      style: KatanaType.small.copyWith(
                        color: KatanaColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],

              // Navigation Controls
              Row(
                children: [
                  Expanded(
                    child: _navButton(
                      label: '‹ Prev',
                      enabled: _prevChapter != null,
                      onTap: _prevChapter != null
                          ? () => _goToChapter(_prevChapter!)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _openChapterPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: KatanaColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: KatanaColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.list_rounded,
                              size: 16,
                              color: KatanaColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _chapter.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.outfitBold.copyWith(
                                  color: KatanaColors.text,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down_rounded,
                              color: KatanaColors.textMuted,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _navButton(
                      label: 'Next ›',
                      enabled: _nextChapter != null,
                      onTap: _nextChapter != null
                          ? () => _goToChapter(_nextChapter!)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton({
    required String label,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: enabled ? KatanaColors.surfaceAlt : KatanaColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? KatanaColors.border : KatanaColors.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.outfitBold.copyWith(
            color: enabled ? KatanaColors.text : KatanaColors.textLight,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
