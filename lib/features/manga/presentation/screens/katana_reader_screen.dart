import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_typography.dart';
import '../../data/models/katana_models.dart';
import '../../data/services/katana_service.dart';
import '../katana/katana_theme.dart';
import '../../../../core/services/auth_service.dart';

/// Manga Katana reader: long-strip pages with server switching,
/// two-page view, fit-height + tap-edge navigation, darken control,
/// chapter bookmarks and prev/next chapter flow.
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

  late List<KatanaChapter> _chapters;
  late KatanaChapter _chapter;
  List<String> _pages = const [];
  bool _loading = true;
  String? _error;
  String _server = '';
  bool _twoPage = false;
  bool _fitHeight = false;
  bool _darkenEnabled = false;
  double _darken = 0;
  bool _bookmarked = false;
  bool _fitAlertVisible = false;
  Timer? _fitAlertTimer;
  int _lastSavedPage = -1;

  String get _user => context.read<AuthService>().currentUser ?? '';

  int get _currentIndex {
    final i = _chapters.indexWhere((c) => c.id == _chapter.id);
    return i < 0 ? 0 : i;
  }

  KatanaChapter? get _prevChapter =>
      _currentIndex > 0 ? _chapters[_currentIndex - 1] : null;

  KatanaChapter? get _nextChapter =>
      _currentIndex < _chapters.length - 1 ? _chapters[_currentIndex + 1] : null;

  @override
  void initState() {
    super.initState();
    _chapters = sortChaptersAscending(widget.chapters);
    final initial = _chapters.where((c) => c.id == widget.chapterId).firstOrNull;
    _chapter = initial ??
        (_chapters.isNotEmpty ? _chapters.first : KatanaChapter(id: widget.chapterId, num: '', title: widget.chapterId));
    _scrollController.addListener(_onScroll);
    _loadPages();
    _loadBookmark();
  }

  @override
  void dispose() {
    _fitAlertTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadBookmark() async {
    final bookmarked = await _service.isBookmarked(widget.slug, _user);
    if (mounted) setState(() => _bookmarked = bookmarked);
  }

  Future<void> _loadPages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final pages = await _service.fetchChapterPages(
      widget.slug,
      _chapter.path,
      server: _server,
    );
    if (!mounted) return;
    if (pages.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'This chapter has no readable pages. Try another server.';
      });
      return;
    }
    setState(() {
      _pages = pages;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _pages.isEmpty) return;
    final offset = _scrollController.offset;
    final max = _scrollController.position.maxScrollExtent;
    final ratio = max > 0 ? (offset / max).clamp(0.0, 1.0) : 0.0;
    final page = (ratio * (_pages.length - 1)).round() + 1;
    if (page != _lastSavedPage && page % 3 == 0) {
      _lastSavedPage = page;
      _saveProgress(page);
    }
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
    });
    _loadPages();
  }

  void _changeServer(String server) {
    if (_server == server) return;
    setState(() => _server = server);
    _loadPages();
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
    if (next) await _saveProgress(1);
    _showSnack(next ? 'Chapter bookmarked' : 'Bookmark removed');
  }

  void _showSnack(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: KatanaType.body.copyWith(color: Colors.white)),
        backgroundColor: KatanaColors.headerDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleFitHeight() {
    setState(() => _fitHeight = !_fitHeight);
    if (_fitHeight) {
      _fitAlertTimer?.cancel();
      setState(() => _fitAlertVisible = true);
      _fitAlertTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _fitAlertVisible = false);
      });
    }
  }

  Future<void> _reportChapter() async {
    final url = 'https://mangakatana.com/manga/${widget.slug}/${_chapter.path}';
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        await _saveProgress(_lastSavedPage < 0 ? 1 : _lastSavedPage);
        navigator.pop();
      },
      child: Scaffold(
        backgroundColor: KatanaColors.background,
        body: Column(
          children: [
            _buildTopBar(),
            if (_fitAlertVisible) _buildFitAlert(),
            Expanded(child: _buildContent()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 700;
    return Container(
      color: KatanaColors.surface,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KatanaColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await _saveProgress(_lastSavedPage < 0 ? 1 : _lastSavedPage);
                  navigator.pop();
                },
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 17, color: KatanaColors.textMuted),
                tooltip: 'Back',
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.mangaTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitBold.copyWith(
                        color: KatanaColors.text,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      _chapter.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KatanaType.small.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (MediaQuery.sizeOf(context).width >= 1100)
                _toolButton(
                  label: _twoPage ? 'Single page' : 'Two-page view',
                  icon: Icons.auto_stories_rounded,
                  active: _twoPage,
                  showLabel: true,
                  onTap: () {
                    if (MediaQuery.sizeOf(context).width >= 900) {
                      setState(() => _twoPage = !_twoPage);
                    }
                  },
                ),
              _toolButton(
                label: _darkenEnabled ? 'Darken: ${_darken.round()}%' : 'Darken image',
                icon: Icons.brightness_4_rounded,
                active: _darkenEnabled,
                showLabel: !narrow,
                onTap: () => setState(() => _darkenEnabled = !_darkenEnabled),
              ),
              _toolButton(
                label: _fitHeight ? 'Fit height: on' : 'Fit height',
                icon: Icons.height_rounded,
                active: _fitHeight,
                showLabel: !narrow,
                onTap: _toggleFitHeight,
              ),
              _toolButton(
                label: _bookmarked ? 'Bookmarked' : 'Bookmark chapter',
                icon: _bookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                active: _bookmarked,
                color: _bookmarked ? KatanaColors.green : KatanaColors.accent,
                showLabel: !narrow,
                onTap: _toggleBookmark,
              ),
              if (!narrow)
                _toolButton(
                  label: 'Report',
                  icon: Icons.warning_amber_rounded,
                  active: false,
                  showLabel: true,
                  onTap: _reportChapter,
                ),
            ],
          ),
          if (_darkenEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
              child: Row(
                children: [
                  const Icon(Icons.brightness_low_rounded,
                      size: 16, color: KatanaColors.textMuted),
                  Expanded(
                    child: Slider(
                      value: _darken,
                      max: 85,
                      divisions: 17,
                      activeColor: KatanaColors.accent,
                      inactiveColor: KatanaColors.border,
                      onChanged: (v) => setState(() => _darken = v),
                    ),
                  ),
                  Text('${_darken.round()}%', style: KatanaType.small),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
            child: Row(
              children: [
                Text(
                  'Switch: ',
                  style: AppTypography.outfitBold.copyWith(
                    color: KatanaColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                _serverRadio('Server 1', ''),
                _serverRadio('Server 2', '?sv=mk'),
                _serverRadio('Server 3', '?sv=3'),
                if (!narrow) ...[
                  const Spacer(),
                  Text(
                    'Click another server if the images are not displayed.',
                    style: KatanaType.small.copyWith(fontSize: 10.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required String label,
    required IconData icon,
    required bool active,
    required bool showLabel,
    required VoidCallback onTap,
    Color color = KatanaColors.accent,
  }) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.12) : KatanaColors.surfaceAlt,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? color : KatanaColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: active ? color : KatanaColors.textMuted),
              if (showLabel) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: AppTypography.outfitBold.copyWith(
                    color: active ? color : KatanaColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _serverRadio(String label, String value) {
    final selected = _server == value;
    return GestureDetector(
      onTap: () => _changeServer(value),
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 15,
              color: selected ? KatanaColors.accent : KatanaColors.textLight,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.outfitWhite.copyWith(
                color: selected ? KatanaColors.accent : KatanaColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFitAlert() {
    return Container(
      width: double.infinity,
      color: KatanaColors.orange.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'The images have been resized to fit the height. Tap the left or right edge of the image to navigate between pages.',
        textAlign: TextAlign.center,
        style: AppTypography.outfitWhite.copyWith(
          color: KatanaColors.textMuted,
          fontSize: 11.5,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: KatanaColors.accent),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_rounded,
                  size: 46, color: KatanaColors.textLight),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: KatanaType.body),
              const SizedBox(height: 12),
              KatanaButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onTap: _loadPages,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _pages.length + 1,
      itemBuilder: (context, index) {
        if (index == _pages.length) return _buildEndCard();
        return _buildPageImage(index);
      },
    );
  }

  Widget _buildPageImage(int index) {
    final url = _service.proxiedImageUrl(_pages[index]);
    final viewportHeight = MediaQuery.sizeOf(context).height - 210;
    final decodeWidth = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(800, 2400);

    Widget image = Image.network(
      url,
      fit: _fitHeight ? BoxFit.contain : BoxFit.fitWidth,
      width: double.infinity,
      cacheWidth: decodeWidth,
      errorBuilder: (_, _, _) => Container(
        height: 220,
        color: KatanaColors.border,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_rounded,
            color: KatanaColors.textLight, size: 34),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: 260,
          alignment: Alignment.center,
          child: CircularProgressIndicator(
            color: KatanaColors.accent.withValues(alpha: 0.5),
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                : null,
          ),
        );
      },
    );

    if (_darkenEnabled && _darken > 0) {
      image = Stack(
        fit: StackFit.expand,
        children: [
          image,
          IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: _darken / 100),
            ),
          ),
        ],
      );
    }

    if (_fitHeight) {
      image = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (details) {
          final width = MediaQuery.sizeOf(context).width;
          if (details.localPosition.dx < width * 0.22) {
            _scrollByPage(-1);
          } else if (details.localPosition.dx > width * 0.78) {
            _scrollByPage(1);
          }
        },
        child: SizedBox(
          height: viewportHeight,
          width: double.infinity,
          child: image,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: image,
    );
  }

  void _scrollByPage(int delta) {
    if (!_scrollController.hasClients || _pages.isEmpty) return;
    final perPage =
        _scrollController.position.maxScrollExtent / (_pages.length - 1);
    final target = (_scrollController.offset + delta * perPage)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  Widget _buildEndCard() {
    final next = _nextChapter;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      child: Column(
        children: [
          if (next != null) ...[
            Text('End of Chapter', style: KatanaType.small),
            const SizedBox(height: 12),
            Text(
              next.displayTitle,
              style: KatanaType.heading.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            KatanaButton(
              label: 'Next Chapter',
              icon: Icons.arrow_forward_rounded,
              onTap: () => _goToChapter(next),
            ),
          ] else
            const Column(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    color: KatanaColors.green, size: 42),
                SizedBox(height: 10),
                Text('You have read the latest chapter',
                    style: TextStyle(fontSize: 14, color: KatanaColors.textMuted)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: KatanaColors.surface,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: KatanaColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _navButton(
              label: '‹ Prev',
              enabled: _prevChapter != null,
              onTap: _prevChapter != null ? () => _goToChapter(_prevChapter!) : null,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _openChapterPicker,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width < 700 ? 150 : 320,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: KatanaColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: KatanaColors.accent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.list_rounded,
                      color: KatanaColors.accent, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _chapter.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitBold.copyWith(
                        color: KatanaColors.accent,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded,
                      color: KatanaColors.accent),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _navButton(
              label: 'Next ›',
              enabled: _nextChapter != null,
              onTap: _nextChapter != null ? () => _goToChapter(_nextChapter!) : null,
            ),
          ),
        ],
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
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled ? KatanaColors.border : KatanaColors.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.outfitBold.copyWith(
            color: enabled ? KatanaColors.text : KatanaColors.textLight,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  void _openChapterPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: KatanaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: KatanaColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text('Chapters', style: KatanaType.section),
                  const Spacer(),
                  Text('${_chapters.length} total', style: KatanaType.small),
                ],
              ),
            ),
            const Divider(height: 1, color: KatanaColors.border),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _chapters.length,
                itemBuilder: (ctx, index) {
                  final chapter = _chapters[index];
                  final current = chapter.id == _chapter.id;
                  return ListTile(
                    dense: true,
                    selected: current,
                    selectedTileColor: KatanaColors.accent.withValues(alpha: 0.08),
                    leading: Icon(
                      current
                          ? Icons.play_arrow_rounded
                          : Icons.menu_book_rounded,
                      size: 18,
                      color: current ? KatanaColors.accent : KatanaColors.textLight,
                    ),
                    title: Text(
                      chapter.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitBold.copyWith(
                        color: current ? KatanaColors.accent : KatanaColors.text,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (!current) _goToChapter(chapter);
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
}
