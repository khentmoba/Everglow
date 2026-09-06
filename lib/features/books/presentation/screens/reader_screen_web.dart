import 'dart:async';
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/book_item.dart';
import '../../data/services/book_download_helper.dart';
import '../../data/services/open_library_service.dart';
import '../../data/services/web_tts_service.dart';
import '../widgets/chapter_list.dart';
import '../../../../core/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_colors.dart';
part 'reader_widgets.dart';
part 'reader_screen_state_base.dart';

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
  final bool startListening;
  const ReaderScreen({
    super.key,
    required this.book,
    this.startListening = false,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends _ReaderScreenStateBase {
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
                CircularProgressIndicator(color: AppTheme.deepRose),
                SizedBox(height: 16),
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
                  const Icon(
                    Icons.menu_book_outlined,
                    color: AppTheme.roseQuartz,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: AppTypography.outfitWhite.copyWith(
                      color: AppTheme.roseQuartz.withValues(alpha: 0.8),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (widget.book.readSourceLabel.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final url = widget.book.readSourceUrl;
                        if (url.isNotEmpty) {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(
                        'Open on ${widget.book.readSourceLabel}',
                        style: AppTypography.outfitWhite,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepRose,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
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
                  style: AppTypography.cormorantBlack.copyWith(
                    fontSize: 28,
                    height: 1.15,
                    color: _theme.fg,
                  ),
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
          top: BorderSide(color: _theme.fg.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: hasPrev ? _prevChapter : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            label: const Text('Previous', style: AppTypography.outfitWhite),
          ),
          Text(
            '${_currentChapter + 1} of ${_chapters.length}',
            style: AppTypography.outfitBold.copyWith(
              color: _theme.fg.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          TextButton.icon(
            onPressed: hasNext ? _nextChapter : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            label: const Text('Next', style: AppTypography.outfitWhite),
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
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _theme.fg,
              size: 18,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitHeading.copyWith(
                    color: _theme.fg,
                    fontSize: 14,
                  ),
                ),
                if (widget.book.author.isNotEmpty)
                  Text(
                    widget.book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(
                      color: _theme.fg.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
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
          if (_readerMode == ReaderMode.text) ...[
            IconButton(
              tooltip: 'Listen',
              onPressed: _showListenSheet,
              icon: Icon(Icons.headphones_rounded, color: _theme.fg, size: 22),
            ),
          ],
          IconButton(
            tooltip: 'Download',
            onPressed: _showDownloadSheet,
            icon: Icon(Icons.download_rounded, color: _theme.fg, size: 22),
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
          top: BorderSide(color: _theme.fg.withValues(alpha: 0.08), width: 0.5),
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
                AppTheme.deepRose,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}% complete',
                style: AppTypography.outfitWhite.copyWith(
                  color: _theme.fg.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
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
                    onPressed: _currentChapter < _chapters.length - 1
                        ? _nextChapter
                        : null,
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
        Expanded(child: HtmlElementView(viewType: _viewType)),
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
          top: BorderSide(color: _theme.fg.withValues(alpha: 0.08), width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Via Internet Archive',
            style: AppTypography.outfitWhite.copyWith(
              color: _theme.fg.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.book.readSourceUrl.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                final url = widget.book.readSourceUrl;
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Full Screen', style: AppTypography.outfitBold),
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Text(
                      'Chapters',
                      style: AppTypography.cormorantExtraBoldWhite.copyWith(
                        fontSize: 22,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_chapters.length} total',
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppTheme.roseQuartz.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
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
                          horizontal: 14,
                          vertical: 12,
                        ),
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
                                style: AppTypography.cormorantBlack.copyWith(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _chapters[i].title,
                                style: AppTypography.outfitBold.copyWith(
                                  color: isCurrent
                                      ? AppTheme.petalWhite
                                      : AppTheme.roseQuartz,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrent)
                              const Icon(
                                Icons.play_arrow_rounded,
                                color: AppTheme.roseQuartz,
                                size: 18,
                              ),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
              style: AppTypography.cormorantExtraBoldWhite.copyWith(
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 20),
            if (_readerMode == ReaderMode.text) ...[
              Text(
                'Font size',
                style: AppTypography.outfitBold.copyWith(
                  color: AppTheme.roseQuartz,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.text_decrease_rounded,
                    color: AppTheme.roseQuartz,
                    size: 18,
                  ),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 13,
                      max: 26,
                      divisions: 13,
                      activeColor: AppTheme.deepRose,
                      inactiveColor: AppTheme.roseQuartz.withValues(alpha: 0.2),
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                  ),
                  const Icon(
                    Icons.text_increase_rounded,
                    color: AppTheme.roseQuartz,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Theme',
              style: AppTypography.outfitBold.copyWith(
                color: AppTheme.roseQuartz,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: ReaderTheme.values
                  .map(
                    (t) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _theme = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _theme == t
                                  ? AppTheme.deepRose.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _theme == t
                                    ? AppTheme.deepRose
                                    : AppTheme.roseQuartz.withValues(
                                        alpha: 0.2,
                                      ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: t.bg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.roseQuartz.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  t.label,
                                  style: AppTypography.outfitHeading.copyWith(
                                    color: _theme == t
                                        ? AppTheme.petalWhite
                                        : AppTheme.roseQuartz,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
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
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
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

  @override
  void _showListenSheet() {
    if (_chapters.isEmpty) {
      _showSnack('This title has no readable text to listen to.');
      return;
    }
    if (!_tts.isSupported) {
      _showSnack('Listening needs a browser with speech synthesis.');
      return;
    }
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ListenSheet(
        chapterTitle: _chapters[_currentChapter].title,
        paragraphs: _splitParagraphs(_chapters[_currentChapter].body),
        tts: _tts,
      ),
    );
  }

  List<String> _splitParagraphs(String body) {
    final cached = _paragraphCache[body.length];
    if (cached != null) return cached;
    final paragraphs = body
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim())
        .where((p) => p.isNotEmpty)
        .toList();
    _paragraphCache[body.length] = paragraphs;
    return paragraphs;
  }

  void _showDownloadSheet() {
    HapticFeedback.selectionClick();
    final formats = <String, String>{};
    final iaId = widget.book.iaId;
    if (iaId.startsWith('pg') && iaId.length > 2) {
      final id = iaId.substring(2);
      formats['txt'] = 'https://www.gutenberg.org/cache/epub/$id/pg$id.txt';
      formats['epub'] = 'https://www.gutenberg.org/ebooks/$id.epub3.images';
      formats['mobi'] = 'https://www.gutenberg.org/ebooks/$id.kindle.noimages';
    } else if (iaId.isNotEmpty) {
      formats['txt'] = 'https://archive.org/download/$iaId/${iaId}_djvu.txt';
      formats['epub'] = 'https://archive.org/download/$iaId/$iaId.epub';
      formats['pdf'] = 'https://archive.org/download/$iaId/$iaId.pdf';
    }
    if (formats.isEmpty &&
        widget.book.readSourceUrl.toLowerCase().endsWith('.txt')) {
      formats['txt'] = widget.book.readSourceUrl;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.velvet,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
              'Download',
              style: AppTypography.cormorantExtraBoldWhite.copyWith(
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Public-domain formats',
              style: AppTypography.outfitWhite.copyWith(
                color: AppTheme.roseQuartz.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            if (formats.isEmpty)
              const Text(
                'No downloadable file available for this title.',
                style: TextStyle(color: AppColors.mutedPurple, fontSize: 13),
              )
            else
              for (final entry in formats.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.deepRose.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          entry.key.toUpperCase(),
                          style: AppTypography.outfitBold.copyWith(
                            color: AppTheme.deepRose,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${entry.key.toUpperCase()} file',
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppTheme.petalWhite,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => downloadUrl(entry.value),
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.deepRose,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Download'),
                      ),
                    ],
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

/// Isolate entry point for book text splitting. Returns [title, body] pairs
/// so the result is sendable back across the isolate boundary.
List<List<String>> _splitBookTextIsolate(List<String> input) {
  final text = input[0];
  final fallbackTitle = input[1];

  final explicitPattern = RegExp(
    r'^(CHAPTER|Chapter|PART|Part|BOOK|Book|PROLOGUE|EPILOGUE|Act|ACT)\s+'
    r'([IVXLCDM]+|\d+|[A-Za-z]+)'
    r'(?:[\.\:\s]+([^\n]+))?',
    multiLine: true,
  );
  final matches = explicitPattern.allMatches(text).toList();
  if (matches.length >= 2) {
    final chapters = <List<String>>[];
    for (var i = 0; i < matches.length; i++) {
      final start = matches[i].start;
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      final header = text.substring(start, end);
      final headerLines = header.split('\n');
      final title = headerLines.first.trim();
      final body = _normalizeBookText(headerLines.skip(1).join('\n'));
      if (body.trim().isNotEmpty) chapters.add([title, body]);
    }
    if (chapters.isNotEmpty) return chapters;
  }

  final parts = text.split(RegExp(r'^\s*\*{3,}\s*$', multiLine: true));
  if (parts.length >= 2) {
    final chapters = <List<String>>[];
    for (final part in parts) {
      final body = _normalizeBookText(part);
      if (body.trim().isEmpty) continue;
      final firstLine = body
          .split('\n')
          .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
      final title = firstLine.length > 80
          ? '${firstLine.substring(0, 80)}...'
          : firstLine;
      chapters.add([
        title.isEmpty ? 'Section ${chapters.length + 1}' : title,
        body,
      ]);
    }
    if (chapters.isNotEmpty) return chapters;
  }

  return [
    [fallbackTitle, _normalizeBookText(text)],
  ];
}

String _normalizeBookText(String text) {
  return text
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// Visual theme variants for the reader.
