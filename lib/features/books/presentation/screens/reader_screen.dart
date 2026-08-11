import 'dart:async';
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/books/data/models/book_item.dart';
import 'package:everglow/features/books/data/services/open_library_service.dart';
import 'package:everglow/features/books/presentation/widgets/chapter_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:everglow/core/theme/app_typography.dart';

/// In-app book reader. Mirrors the cinema's `video_player_screen`
/// — it's the fullscreen experience for a single media item.
///
/// Pipeline:
///   1. Fetch plain text from the book's `readSourceUrl` (typically
///      `https://archive.org/download/{ia}/{ia}_djvu.txt`).
///   2. Strip Gutenberg boilerplate.
///   3. Split into [BookChapter]s by chapter / part / book markers.
///   4. Render the active chapter with `flutter_html`.
///   5. Persist progress in `SharedPreferences` per workKey so the
///      next open resumes where the user left off.
enum ReaderMode { text, embed }

class ReaderScreen extends StatefulWidget {
  final BookItem book;
  const ReaderScreen({Key? key, required this.book}) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final OpenLibraryService _service = OpenLibraryService();

  bool _isLoading = true;
  String? _loadError;
  List<BookChapter> _chapters = const [];
  int _currentChapter = 0;
  double _fontSize = 17.0;
  ReaderMode _readerMode = ReaderMode.text;
  late final String _viewType;
  static int _viewTypeCounter = 0;
  ReaderTheme _theme = ReaderTheme.dark;

  // Persisted state keys
  String get _progressKey => 'reader_progress::${widget.book.workKey}';

  @override
  void initState() {
    super.initState();
    _viewType = 'reader-iframe-${_viewTypeCounter++}';
    _loadAndSplit();
  }

  Future<void> _loadAndSplit() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_progressKey);
    if (saved != null && saved >= 0) {
      _currentChapter = saved;
    }

    // Non-Gutenberg Internet Archive books use the IA embedded viewer.
    // This covers the vast majority of modern copyrighted books that
    // are borrow-only — they have no publicly accessible plain text.
    final iaId = widget.book.iaId;
    if (iaId.isNotEmpty && !iaId.startsWith('pg')) {
      _registerIframe(iaId);
      setState(() {
        _readerMode = ReaderMode.embed;
        _isLoading = false;
      });
      return;
    }

    // Build the full ordered list of read source candidates. The
    // service tries each one until one responds successfully — that
    // way a CORS block or 404 on the Internet Archive fallback
    // still leaves us with a working Gutenberg or Open Library URL.
    final candidates = _service.buildReadSourceCandidates(widget.book);
    if (candidates.isEmpty) {
      setState(() {
        _isLoading = false;
        _loadError = 'No readable copy available for this title.';
      });
      return;
    }

    try {
      final result = await _service.fetchBookTextFromCandidates(candidates);
      if (!mounted) return;
      if (!result.isSuccess) {
        setState(() {
          _isLoading = false;
          _loadError = result.error ??
              'Could not load the book text from any available source.';
        });
        return;
      }
      final cleaned = _stripGutenbergBoilerplate(result.text);
      final chapters = _splitChapters(cleaned);
      setState(() {
        _chapters = chapters;
        // Clamp currentChapter in case the saved index is now invalid
        if (_currentChapter >= chapters.length) {
          _currentChapter = 0;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Error: $e';
      });
    }
  }

  Future<void> _saveProgress(int chapter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_progressKey, chapter);
  }

  void _registerIframe(String iaId) {
    try {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        return html.IFrameElement()
          ..src = 'https://archive.org/stream/$iaId?ui=embed'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none';
      });
    } catch (e) {
      debugPrint('[ReaderScreen] Archive.org iframe registration failed: $e');
    }
  }

  // ── TEXT PROCESSING ────────────────────────────────────────────────

  /// Strip the Project Gutenberg header and footer blocks. They are
  /// delimited by `*** START OF` / `*** END OF` markers that the
  /// Gutenberg convention uses.
  String _stripGutenbergBoilerplate(String raw) {
    final startMatch = RegExp(r'\*\*\*\s*START OF (?:THE|THIS)?\s*PROJECT',
            caseSensitive: false)
        .firstMatch(raw);
    final endMatch = RegExp(r'\*\*\*\s*END OF (?:THE|THIS)?\s*PROJECT',
            caseSensitive: false)
        .firstMatch(raw);
    if (startMatch == null || endMatch == null) return raw;
    return raw.substring(startMatch.end, endMatch.start);
  }

  /// Split a book's plain text into [BookChapter]s.
  ///
  /// We try three passes in order of strictness:
  ///   1. Explicit chapter markers (CHAPTER I., Part 2, BOOK III…).
  ///   2. "***" decorative separators (Gutenberg convention for
  ///      short stories or where the author didn't use chapters).
  ///   3. A single-chapter fallback containing the whole book.
  List<BookChapter> _splitChapters(String text) {
    final explicit = _splitOnExplicitMarkers(text);
    if (explicit.length >= 2) return explicit;

    final stars = _splitOnStarSeparators(text);
    if (stars.length >= 2) return stars;

    return [
      BookChapter(
        title: widget.book.title,
        body: _normalizeWhitespace(text),
      ),
    ];
  }

  List<BookChapter> _splitOnExplicitMarkers(String text) {
    // Find all positions where a "CHAPTER / PART / BOOK / PROLOGUE /
    // EPILOGUE" line starts. We allow a chapter number/roman and an
    // optional title on the same line.
    final pattern = RegExp(
      r'^(CHAPTER|Chapter|PART|Part|BOOK|Book|PROLOGUE|EPILOGUE|Act|ACT)\s+'
      r'([IVXLCDM]+|\d+|[A-Za-z]+)'
      r'(?:[\.\:\s]+([^\n]+))?',
      multiLine: true,
    );

    final matches = pattern.allMatches(text).toList();
    if (matches.length < 2) return const [];

    final chapters = <BookChapter>[];
    for (var i = 0; i < matches.length; i++) {
      final start = matches[i].start;
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      final header = text.substring(start, end);
      final headerLines = header.split('\n');
      final title = headerLines.first.trim();
      final body = _normalizeWhitespace(
          headerLines.skip(1).join('\n'));
      if (body.trim().isEmpty) continue;
      chapters.add(BookChapter(title: title, body: body));
    }
    return chapters;
  }

  List<BookChapter> _splitOnStarSeparators(String text) {
    // Gutenberg short stories use centered "***" or "* * *" between
    // sections. We treat each separator as a chapter boundary.
    final parts = text.split(RegExp(r'^\s*\*{3,}\s*$', multiLine: true));
    if (parts.length < 2) return const [];
    final chapters = <BookChapter>[];
    for (var i = 0; i < parts.length; i++) {
      final body = _normalizeWhitespace(parts[i]);
      if (body.trim().isEmpty) continue;
      // Use the first non-empty line as the chapter title.
      final firstLine =
          body.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
      final title = firstLine.length > 80
          ? '${firstLine.substring(0, 80)}…'
          : firstLine;
      chapters.add(BookChapter(
        title: title.isEmpty ? 'Section ${chapters.length + 1}' : title,
        body: body,
      ));
    }
    return chapters;
  }

  String _normalizeWhitespace(String text) {
    return text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  // ── UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.bg,
      body: SafeArea(
        child: _isLoading
            ? _buildLoading()
            : _readerMode == ReaderMode.embed
                ? _buildEmbedReader()
                : (_loadError != null && _chapters.isEmpty
                    ? _buildError()
                    : _buildReader()),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      children: [
        _buildTopBar(),
        const Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppTheme.deepRose),
                const SizedBox(height: 16),
                Text(
                  'Opening the pages…',
                  style: TextStyle(
                    color: AppTheme.roseQuartz,
                    fontFamily: 'Cormorant Garamond',
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_book_outlined,
                      color: AppTheme.roseQuartz, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: AppTypography.outfitWhite.copyWith(color: AppTheme.roseQuartz.withValues(alpha: 0.8), fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  if (widget.book.readSourceLabel.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final url = widget.book.readSourceUrl;
                        if (url.isNotEmpty) {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text('Open on ${widget.book.readSourceLabel}',
                          style: AppTypography.outfitWhite),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepRose,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReader() {
    final chapter = _chapters[_currentChapter];
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chapter title
                Text(
                  chapter.title,
                  style: AppTypography.cormorantBlack.copyWith(fontSize: 28, height: 1.15, color: _theme.fg),
                ),
                const SizedBox(height: 16),
                // Chapter body — render plain text via flutter_html so we
                // get smart paragraphs, line wrapping, and we can theme it.
                Html(
                  data: _bodyToHtml(chapter.body),
                  style: {
                    'body': Style(
                      color: _theme.fg,
                      fontSize: FontSize(_fontSize),
                      lineHeight: const LineHeight(1.7),
                      fontFamily: 'Outfit',
                    ),
                    'p': Style(
                      color: _theme.fg,
                      fontSize: FontSize(_fontSize),
                      lineHeight: const LineHeight(1.7),
                      margin: Margins.only(bottom: 14),
                    ),
                  },
                ),
                const SizedBox(height: 32),
                _buildChapterFooter(),
              ],
            ),
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildChapterFooter() {
    final hasNext = _currentChapter < _chapters.length - 1;
    final hasPrev = _currentChapter > 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: _theme.fg.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: hasPrev ? _prevChapter : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            label: Text('Previous', style: AppTypography.outfitWhite),
          ),
          Text(
            '${_currentChapter + 1} of ${_chapters.length}',
            style: AppTypography.outfitBold.copyWith(color: _theme.fg.withValues(alpha: 0.6), fontSize: 12),
          ),
          TextButton.icon(
            onPressed: hasNext ? _nextChapter : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            label: Text('Next', style: AppTypography.outfitWhite),
            // label after icon order swap
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _theme.bg,
        border: Border(
          bottom: BorderSide(
            color: _theme.fg.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: _theme.fg, size: 18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitHeading.copyWith(color: _theme.fg, fontSize: 14),
                ),
                if (widget.book.author.isNotEmpty)
                  Text(
                    widget.book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(color: _theme.fg.withValues(alpha: 0.6), fontSize: 11, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
          if (_readerMode == ReaderMode.text)
            IconButton(
              tooltip: 'Chapters',
              onPressed: _showChapterSheet,
              icon: Icon(Icons.list_rounded, color: _theme.fg, size: 22),
            ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _showSettingsSheet,
            icon: Icon(Icons.tune_rounded, color: _theme.fg, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final progress = _chapters.isEmpty
        ? 0.0
        : (_currentChapter + 1) / _chapters.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      decoration: BoxDecoration(
        color: _theme.bg,
        border: Border(
          top: BorderSide(
            color: _theme.fg.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: _theme.fg.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.deepRose),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}% complete',
                style: AppTypography.outfitWhite.copyWith(color: _theme.fg.withValues(alpha: 0.55), fontSize: 11, fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _currentChapter > 0 ? _prevChapter : null,
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      color: _theme.fg,
                      size: 22,
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _currentChapter < _chapters.length - 1 ? _nextChapter : null,
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: _theme.fg,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmbedReader() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: HtmlElementView(viewType: _viewType),
        ),
        _buildEmbedBottomBar(),
      ],
    );
  }

  Widget _buildEmbedBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      decoration: BoxDecoration(
        color: _theme.bg,
        border: Border(
          top: BorderSide(
            color: _theme.fg.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Via Internet Archive',
            style: AppTypography.outfitWhite.copyWith(color: _theme.fg.withValues(alpha: 0.55), fontSize: 11, fontWeight: FontWeight.w500),
          ),
          if (widget.book.readSourceUrl.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                final url = widget.book.readSourceUrl;
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(
                'Full Screen',
                style: AppTypography.outfitBold,
              ),
            ),
        ],
      ),
    );
  }

  void _nextChapter() {
    HapticFeedback.selectionClick();
    setState(() => _currentChapter++);
    _saveProgress(_currentChapter);
  }

  void _prevChapter() {
    HapticFeedback.selectionClick();
    setState(() => _currentChapter--);
    _saveProgress(_currentChapter);
  }

  void _showChapterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, controller) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.velvet,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Text(
                      'Chapters',
                      style: AppTypography.cormorantExtraBoldWhite.copyWith(fontSize: 22),
                    ),
                    const Spacer(),
                    Text(
                      '${_chapters.length} total',
                      style: AppTypography.outfitWhite.copyWith(color: AppTheme.roseQuartz.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: _chapters.length,
                  itemBuilder: (ctx, i) {
                    final isCurrent = i == _currentChapter;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _currentChapter = i);
                        _saveProgress(i);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppTheme.deepRose.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? AppTheme.deepRose.withValues(alpha: 0.5)
                                : AppTheme.roseQuartz.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${i + 1}',
                                style: AppTypography.cormorantBlack.copyWith(fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _chapters[i].title,
                                style: AppTypography.outfitBold.copyWith(color: isCurrent
                                      ? AppTheme.petalWhite
                                      : AppTheme.roseQuartz, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrent)
                              const Icon(Icons.play_arrow_rounded,
                                  color: AppTheme.roseQuartz, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.velvet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Reading Settings',
              style: AppTypography.cormorantExtraBoldWhite.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 20),
            if (_readerMode == ReaderMode.text) ...[
              Text(
                'Font size',
                style: AppTypography.outfitBold.copyWith(color: AppTheme.roseQuartz, fontSize: 12, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.text_decrease_rounded,
                      color: AppTheme.roseQuartz, size: 18),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 13,
                      max: 26,
                      divisions: 13,
                      activeColor: AppTheme.deepRose,
                      inactiveColor:
                          AppTheme.roseQuartz.withValues(alpha: 0.2),
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                  ),
                  const Icon(Icons.text_increase_rounded,
                      color: AppTheme.roseQuartz, size: 22),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Theme',
              style: AppTypography.outfitBold.copyWith(color: AppTheme.roseQuartz, fontSize: 12, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            Row(
              children: ReaderTheme.values
                  .map((t) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => setState(() => _theme = t),
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _theme == t
                                    ? AppTheme.deepRose
                                        .withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _theme == t
                                      ? AppTheme.deepRose
                                      : AppTheme.roseQuartz
                                          .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: t.bg,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.roseQuartz
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    t.label,
                                    style: AppTypography.outfitHeading.copyWith(color: _theme == t
                                          ? AppTheme.petalWhite
                                          : AppTheme.roseQuartz, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            if (widget.book.readSourceUrl.isNotEmpty)
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final url = widget.book.readSourceUrl;
                    if (url.isEmpty) return;
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(
                    'Open source on ${widget.book.readSourceLabel}',
                    style: AppTypography.outfitWhite,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Convert plain text into HTML with paragraph breaks so
  /// flutter_html can render it with proper margins.
  String _bodyToHtml(String body) {
    final escaped = body
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return escaped
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .map((p) => '<p>${p.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim()}</p>')
        .join('\n');
  }
}

/// Visual theme variants for the reader.
class ReaderTheme {
  final String label;
  final Color bg;
  final Color fg;

  const ReaderTheme._(this.label, this.bg, this.fg);

  static const dark = ReaderTheme._(
    'Night',
    Color(0xFF1A1A2E),
    Color(0xFFF0E6FF),
  );
  static const sepia = ReaderTheme._(
    'Sepia',
    Color(0xFF1C1228),
    Color(0xFFE8D5B7),
  );
  static const light = ReaderTheme._(
    'Light',
    Color(0xFFFFF5F5),
    Color(0xFF1A1A2E),
  );

  static const values = [dark, sepia, light];
}
