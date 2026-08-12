import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/features/manga/data/models/katana_models.dart';
import 'package:everglow/features/manga/data/services/katana_service.dart';
import 'package:everglow/features/manga/presentation/katana/katana_header.dart';
import 'package:everglow/features/manga/presentation/katana/katana_nav.dart';
import 'package:everglow/features/manga/presentation/katana/katana_theme.dart';
import 'package:everglow/services/auth_service.dart';

/// The manga detail page: cover and meta, first chapter / read offline
/// actions plus a per-couple "Khent Reading" / "Claire Reading" button,
/// description and the full chapter table with a reverse-order toggle,
/// exactly like Manga Katana.
class KatanaDetailScreen extends StatefulWidget {
  final String slug;
  final KatanaManga? preview;

  const KatanaDetailScreen({super.key, required this.slug, this.preview});

  @override
  State<KatanaDetailScreen> createState() => _KatanaDetailScreenState();
}

class _KatanaDetailScreenState extends State<KatanaDetailScreen> {
  final KatanaService _service = KatanaService();
  KatanaManga? _manga;
  bool _loading = true;
  String? _error;
  bool _isReading = false;
  bool _reversed = true; // site shows newest first

  String get _user => context.read<AuthService>().currentUser ?? '';

  @override
  void initState() {
    super.initState();
    _manga = widget.preview;
    _load();
    _loadReading();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final manga = await _service.fetchMangaDetail(widget.slug);
      if (mounted) {
        setState(() {
          _manga = manga;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load this manga.';
        });
      }
    }
  }

  Future<void> _loadReading() async {
    final reading = await _service.isReading(widget.slug, _user);
    if (mounted) {
      setState(() {
        _isReading = reading;
      });
    }
  }

  /// "Khent Reading" for Khent, "Claire Reading" for Clair, and nothing
  /// for Breyan / Octagram so the couple-only feature stays private.
  String? get _readingButtonLabel {
    switch (_user) {
      case 'khentsgdz':
        return 'Khent Reading';
      case 'clairjassen':
        return 'Claire Reading';
      default:
        return null;
    }
  }

  Future<void> _toggleReading() async {
    final manga = _manga;
    if (manga == null || _readingButtonLabel == null || _user.isEmpty) return;
    final next = !_isReading;
    setState(() => _isReading = next);
    await _service.setReading(manga, _user, reading: next);
    _showSnack(
      next
          ? 'Added "${manga.title}" to Reading'
          : 'Removed "${manga.title}" from Reading',
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: KatanaType.body.copyWith(color: Colors.white)),
        backgroundColor: KatanaColors.headerDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<KatanaChapter> get _orderedChapters {
    final chapters = _manga?.chapters ?? const <KatanaChapter>[];
    final ascending = sortChaptersAscending(chapters);
    return _reversed ? ascending.reversed.toList() : ascending;
  }

  void _openReader(KatanaChapter chapter) {
    final manga = _manga;
    if (manga == null) return;
    pushReader(
      context,
      slug: manga.slug,
      chapterId: chapter.path,
      chapters: manga.chapters,
      mangaTitle: manga.title,
      coverUrl: manga.coverUrl,
    );
  }

  void _openFirstChapter() {
    final chapters = _manga?.chapters ?? const <KatanaChapter>[];
    final ascending = sortChaptersAscending(chapters);
    if (ascending.isNotEmpty) _openReader(ascending.first);
  }

  Future<void> _openDownload() async {
    final uri = Uri.parse('https://mangakatana.com/manga/${widget.slug}/download');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final manga = _manga;
    return Scaffold(
      backgroundColor: KatanaColors.background,
      body: Column(
        children: [
          const KatanaHeader(active: KatanaNav.home),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: _loading && manga == null
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: KatanaColors.accent),
                      )
                    : _error != null && manga == null
                        ? _buildError()
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
                            children: [
                              _buildBreadcrumb(manga),
                              const SizedBox(height: 12),
                              if (manga != null) ...[
                                _buildHero(manga),
                                const SizedBox(height: 16),
                                _buildDescription(manga),
                                const SizedBox(height: 16),
                                _buildChaptersSection(manga),
                              ],
                            ],
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 46, color: KatanaColors.textLight),
          const SizedBox(height: 12),
          Text(_error!, style: KatanaType.body),
          const SizedBox(height: 12),
          KatanaButton(label: 'Retry', icon: Icons.refresh_rounded, onTap: _load),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(KatanaManga? manga) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => pushHome(context),
          child: const Icon(Icons.home_rounded,
              size: 15, color: KatanaColors.textMuted),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded,
            size: 15, color: KatanaColors.textLight),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => pushDirectory(context),
          child: Text('Manga', style: KatanaType.link.copyWith(fontSize: 12)),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded,
            size: 15, color: KatanaColors.textLight),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            manga?.title ?? widget.slug,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.outfitBold.copyWith(
              color: KatanaColors.textMuted,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(KatanaManga manga) {
    final width = MediaQuery.sizeOf(context).width;
    final stack = width < 720;
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: stack ? 130 : 220,
        height: stack ? 185 : 315,
        child: manga.coverUrl.isEmpty
            ? Container(
                color: KatanaColors.border,
                child: const Icon(Icons.menu_book_rounded,
                    color: KatanaColors.textLight, size: 40),
              )
            : KatanaNetworkImage(
                manga.coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: KatanaColors.border,
                  child: const Icon(Icons.broken_image_rounded,
                      color: KatanaColors.textLight, size: 36),
                ),
              ),
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(manga.title, style: KatanaType.heading.copyWith(fontSize: 26)),
        const SizedBox(height: 10),
        if (manga.altNames.isNotEmpty) _metaRow('Alt name(s):', manga.altNames.join(' ; ')),
        if (manga.authors.isNotEmpty)
          _linkMetaRow(
              'Author(s) / Artist(s):', [...manga.authors, ...manga.artists]),
        if (manga.genres.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final genre in manga.genres)
                KatanaChip(
                  label: genre.name,
                  color: KatanaColors.link,
                  onTap: () => pushGenreDirectory(context, genre.slug, genre.name),
                ),
            ],
          ),
        const SizedBox(height: 6),
        _metaRow(
          'Status:',
          manga.isCompleted ? 'Completed' : 'Ongoing',
          valueColor: manga.isCompleted ? KatanaColors.green : KatanaColors.accent,
        ),
        if (manga.latestChapter != null && manga.latestChapter!.title.isNotEmpty)
          _metaRow('Latest chapter(s):', manga.latestChapter!.title),
        if (manga.updateText.isNotEmpty)
          _metaRow('Update at:', manga.updateText),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KatanaButton(
              label: 'First Chapter',
              icon: Icons.play_arrow_rounded,
              onTap: _openFirstChapter,
            ),
            KatanaButton(
              label: 'Read offline',
              icon: Icons.download_rounded,
              filled: false,
              onTap: _openDownload,
            ),
            if (_user == 'khentsgdz' || _user == 'clairjassen')
              KatanaButton(
                label: _isReading ? 'Reading' : _readingButtonLabel!,
                icon: _isReading
                    ? Icons.check_rounded
                    : Icons.auto_stories_rounded,
                filled: _isReading,
                color: _isReading ? KatanaColors.green : KatanaColors.accent,
                onTap: _toggleReading,
              ),
          ],
        ),
      ],
    );

    return KatanaCard(
      padding: const EdgeInsets.all(16),
      child: stack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    cover,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(manga.title,
                              style: KatanaType.heading.copyWith(fontSize: 20)),
                          const SizedBox(height: 8),
                          if (manga.altNames.isNotEmpty)
                            _metaRow('Alt name(s):', manga.altNames.join(' ; ')),
                          if (manga.updateText.isNotEmpty)
                            _metaRow('Update at:', manga.updateText),
                          _metaRow(
                            'Status:',
                            manga.isCompleted ? 'Completed' : 'Ongoing',
                            valueColor: manga.isCompleted
                                ? KatanaColors.green
                                : KatanaColors.accent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (manga.authors.isNotEmpty)
                  _metaRow('Author(s):', [...manga.authors, ...manga.artists].join(', ')),
                if (manga.genres.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final genre in manga.genres)
                        KatanaChip(
                          label: genre.name,
                          color: KatanaColors.link,
                          onTap: () => pushGenreDirectory(
                              context, genre.slug, genre.name),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    KatanaButton(
                      label: 'First Chapter',
                      icon: Icons.play_arrow_rounded,
                      onTap: _openFirstChapter,
                    ),
                    KatanaButton(
                      label: 'Read offline',
                      icon: Icons.download_rounded,
                      filled: false,
                      onTap: _openDownload,
                    ),
                    if (_user == 'khentsgdz' || _user == 'clairjassen')
                      KatanaButton(
                        label: _isReading ? 'Reading' : _readingButtonLabel!,
                        icon: _isReading
                            ? Icons.check_rounded
                            : Icons.auto_stories_rounded,
                        filled: _isReading,
                        color:
                            _isReading ? KatanaColors.green : KatanaColors.accent,
                        onTap: _toggleReading,
                      ),
                  ],
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cover,
                const SizedBox(width: 20),
                Expanded(child: info),
              ],
            ),
    );
  }

  Widget _metaRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: KatanaType.small),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.outfitWhite.copyWith(
                color: valueColor ?? KatanaColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkMetaRow(String label, List<String> values) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: KatanaType.small),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                for (final value in values)
                  Text(
                    '$value${values.last == value ? '' : ','}',
                    style: KatanaType.link,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(KatanaManga manga) {
    if (manga.summary.isEmpty) return const SizedBox.shrink();
    return KatanaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KatanaSectionHeader(title: 'Description'),
          const SizedBox(height: 10),
          Text(manga.summary, style: KatanaType.body.copyWith(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildChaptersSection(KatanaManga manga) {
    final chapters = _orderedChapters;
    return KatanaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: KatanaSectionHeader(
                  title: '${manga.chapters.length} Chapter(s)',
                ),
              ),
              Tooltip(
                message: _reversed ? 'Newest first' : 'Oldest first',
                child: GestureDetector(
                  onTap: () => setState(() => _reversed = !_reversed),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: KatanaColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: KatanaColors.border),
                    ),
                    child: Icon(
                      _reversed
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 16,
                      color: KatanaColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (chapters.isEmpty)
            Text('No chapters available yet.', style: KatanaType.small)
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: KatanaColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < chapters.length; i++)
                    _ChapterRow(
                      chapter: chapters[i],
                      isNew: i < 3,
                      onTap: () => _openReader(chapters[i]),
                      highlight: i % 2 == 1,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  final KatanaChapter chapter;
  final bool isNew;
  final bool highlight;
  final VoidCallback onTap;

  const _ChapterRow({
    required this.chapter,
    required this.isNew,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        color: highlight ? KatanaColors.surfaceAlt : KatanaColors.surface,
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded,
                size: 16, color: KatanaColors.textLight),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                chapter.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitWhite.copyWith(
                  color: KatanaColors.link,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isNew) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: KatanaColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'New',
                  style: AppTypography.outfitBold.copyWith(
                    color: KatanaColors.green,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 12),
            if (chapter.updateAt != null)
              Text(
                formatKatanaTime(chapter.updateAt),
                style: KatanaType.small.copyWith(fontSize: 11.5),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: KatanaColors.textLight),
          ],
        ),
      ),
    );
  }
}
