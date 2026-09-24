import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/manga_item.dart';
import '../../data/models/chapter_num.dart';
import '../../data/services/comick_service.dart';
import '../../data/services/manga_cover_proxy.dart';
import '../../data/services/mangadex_service.dart';
import '../../data/services/mangakakalot_service.dart';
import '../../data/services/mangakatana_service.dart';
import '../../data/services/bato_service.dart';
import '../../data/services/scanlation_service.dart';
import '../katana/katana_theme.dart';
import '../screens/manga_reader_screen.dart' deferred as reader_lib;
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/optimistic_action.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../core/utils/logger.dart';

/// Bottom-sheet details for a manga / manhwa / manhua, opened from the
/// dashboard "Reading" shelf.
///
/// Matches the manga page ([KatanaDetailScreen]) layout so Clair gets
/// the same familiar feel everywhere: cover-left hero card, clear
/// reading actions, library chips, clean synopsis, and a chapter table
/// with a newest/oldest toggle.
class MangaDetailsDrawer extends StatefulWidget {
  final MangaItem item;
  const MangaDetailsDrawer({super.key, required this.item});

  @override
  State<MangaDetailsDrawer> createState() => _MangaDetailsDrawerState();
}

class _MangaDetailsDrawerState extends State<MangaDetailsDrawer> {
  final ComickService _comickService = ComickService();
  final MangaDexService _mangaDexService = MangaDexService();
  final MangaKakalotService _kakalotService = MangaKakalotService();
  final MangakatanaService _mangakatanaService = MangakatanaService();
  final ScanlationService _scanlationService = ScanlationService();
  final BatoService _batoService = BatoService();

  Map<String, String>? _scanlationSlugs;

  late MangaItem _item;
  List<MangaChapter> _chapters = const [];
  bool _isLoadingChapters = true;
  String? _chapterError;
  bool _reversed = true; // newest first, like the manga page
  bool _synopsisExpanded = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadChapters();
    unawaited(_hydrateMetadata());
  }

  Future<void> _hydrateMetadata() async {
    if (_item.hasAuthor) return;
    final user = context.read<AuthService>().currentUser ?? '';
    final enriched = await _kakalotService.enrichMetadata(_item, user);
    if (!mounted || enriched == null) return;
    setState(() => _item = enriched);
  }

  /// In-memory chapter cache so reopening the same manga is instant.
  /// Shared across drawer opens; entries live for 10 minutes.
  static final Map<String, _ChapterCacheEntry> _chapterCache = {};

  Future<void> _loadChapters({bool forceRefresh = false}) async {
    setState(() {
      _isLoadingChapters = true;
      _chapterError = null;
    });

    final cacheKey = _item.mangaId.isNotEmpty ? _item.mangaId : _item.title;
    if (!forceRefresh) {
      final cached = _chapterCache[cacheKey];
      if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
        if (!mounted) return;
        setState(() {
          _chapters = cached.chapters;
          _scanlationSlugs = cached.scanlationSlugs;
          _isLoadingChapters = false;
        });
        return;
      }
    }

    const timeout = Duration(seconds: 10);

    // Stage 1: direct ID-based feeds — fast and exact, no title search.
    // Most library items carry a Comick hid, so this stage alone
    // usually fills the list in a couple of seconds.
    final idFutures = <Future<List<MangaChapter>>>[];
    // Comick chapter feeds need the hid (`mangaId`); the URL slug
    // answers with a bot-check page, so the hid is always tried when
    // we have it. Both fire in parallel and the best wins.
    if (_item.comickSlug.isNotEmpty) {
      idFutures.add(
        _comickService
            .getChapterFeed(_item.comickSlug)
            .timeout(timeout, onTimeout: () => <MangaChapter>[]),
      );
    }
    if (_item.comickId > 0 &&
        _item.mangaId.isNotEmpty &&
        _item.mangaId != _item.comickSlug) {
      idFutures.add(
        _comickService
            .getChapterFeed(_item.mangaId)
            .timeout(timeout, onTimeout: () => <MangaChapter>[]),
      );
    }
    final mangaDexId = _item.mangaKakalotId;
    if (mangaDexId.isNotEmpty) {
      idFutures.add(
        _mangaDexService
            .getChapterFeed(mangaDexId)
            .timeout(timeout, onTimeout: () => <MangaChapter>[]),
      );
    }
    if (_item.mangaId.isNotEmpty &&
        _item.mangaId != mangaDexId &&
        _item.comickId == 0) {
      idFutures.add(
        _mangaDexService
            .getChapterFeed(_item.mangaId)
            .timeout(timeout, onTimeout: () => <MangaChapter>[]),
      );
    }

    var best = await _pickBest(idFutures);

    // Scanlation slugs help the reader resolve pages later. Look them
    // up in the background so the chapter list never waits for them.
    unawaited(_discoverScanlationSlugs());

    // Stage 2: title search — only when the IDs found nothing. Limited
    // to the main title plus one alt; the full alt list (a dozen+
    // titles in many languages) used to fan out into 50+ slow scrapes
    // that all had to finish before anything showed.
    if (best.isEmpty) {
      final titles = <String>[_item.title];
      for (final alt in _item.altTitles) {
        if (alt.isNotEmpty && !titles.contains(alt)) {
          titles.add(alt);
          if (titles.length >= 2) break;
        }
      }
      final searchFutures = <Future<List<MangaChapter>>>[];
      if (_item.comickSlug.isEmpty && _item.comickId == 0) {
        for (final title in titles) {
          searchFutures.add(
            _comickService
                .search(query: title, limit: 1)
                .timeout(timeout, onTimeout: () => <MangaItem>[])
                .then((results) async {
                  if (results.isEmpty) return <MangaChapter>[];
                  final hid = results.first.comickSlug.isNotEmpty
                      ? results.first.comickSlug
                      : results.first.mangaId;
                  if (hid.isEmpty) return <MangaChapter>[];
                  return _comickService.getChapterFeed(hid);
                })
                .timeout(timeout, onTimeout: () => <MangaChapter>[]),
          );
        }
      }
      for (final title in titles) {
        searchFutures.add(
          _kakalotService
              .searchByTitle(title)
              .timeout(timeout, onTimeout: () => '')
              .then((slug) async {
                if (slug.isEmpty) return <MangaChapter>[];
                return _kakalotService.getChapterFeed(slug);
              })
              .timeout(timeout, onTimeout: () => <MangaChapter>[]),
        );
        searchFutures.add(
          _mangakatanaService
              .searchByTitle(title)
              .timeout(timeout, onTimeout: () => '')
              .then((slug) async {
                if (slug.isEmpty) return <MangaChapter>[];
                return _mangakatanaService.getChapterFeed(slug);
              })
              .timeout(timeout, onTimeout: () => <MangaChapter>[]),
        );
        searchFutures.add(
          _batoService
              .searchByTitle(title)
              .timeout(timeout, onTimeout: () => '')
              .then((slug) async {
                if (slug.isEmpty) return <MangaChapter>[];
                return _batoService.getChapterFeed(slug);
              })
              .timeout(timeout, onTimeout: () => <MangaChapter>[]),
        );
      }
      best = await _pickBest(searchFutures);
    }

    // Stage 3: scanlation sites as a last resort.
    if (best.isEmpty) {
      try {
        final slugs = await _scanlationService
            .searchAll(_item.title)
            .timeout(timeout, onTimeout: () => <String, String>{});
        if (slugs.isNotEmpty) {
          if (mounted) _scanlationSlugs = slugs;
          best = await _scanlationService
              .getChapterFeedFromAll(slugs)
              .timeout(timeout, onTimeout: () => <MangaChapter>[]);
        }
      } catch (e, st) {
        Logger.e(
          'MangaDetailsDrawer: scanlation chapter fetch failed for ${_item.title}',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (!mounted) return;
    if (best.isNotEmpty) {
      final cleaned = _dedupeAndSort(best);
      _chapterCache[cacheKey] = _ChapterCacheEntry(
        chapters: cleaned,
        scanlationSlugs: _scanlationSlugs,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );
      setState(() {
        _chapters = cleaned;
        _isLoadingChapters = false;
      });
    } else {
      setState(() {
        _chapterError = 'No English chapters available.';
        _isLoadingChapters = false;
      });
    }
  }

  /// Returns the longest non-empty chapter list: one coherent source.
  /// Merging every source used to mix foreign chapters into the list
  /// with huge number gaps (Ch. 385 jumping to Ch. 462), so we now
  /// pick a single best source instead.
  Future<List<MangaChapter>> _pickBest(
    List<Future<List<MangaChapter>>> futures,
  ) async {
    if (futures.isEmpty) return const [];
    final results = await Future.wait(
      futures.map(
        (f) => f.then((list) => list, onError: (_) => <MangaChapter>[]),
      ),
    );
    var best = const <MangaChapter>[];
    for (final list in results) {
      if (list.length > best.length) best = list;
    }
    return best;
  }

  /// Dedupe one source's chapters by chapter number (Comick returns
  /// the same chapter once per scanlation group) and sort oldest
  /// first with a stable id tie-break.
  List<MangaChapter> _dedupeAndSort(List<MangaChapter> list) {
    final byChapter = <String, MangaChapter>{};
    for (final ch in list) {
      final key = normalizeChapterNum(ch.chapter);
      if (key.isEmpty) {
        // Chapters without a number get unique keys by id
        byChapter['id:${ch.id}'] = ch;
        continue;
      }
      final existing = byChapter[key];
      if (existing == null) {
        byChapter[key] = ch;
      } else if (ch.pages > existing.pages ||
          (ch.pages == existing.pages &&
              ch.title.length > existing.title.length)) {
        byChapter[key] = ch;
      }
    }
    final sorted = byChapter.values.toList()
      ..sort((a, b) {
        final byNum = chapterNumValue(
          a.chapter,
        ).compareTo(chapterNumValue(b.chapter));
        if (byNum != 0) return byNum;
        return a.id.compareTo(b.id);
      });
    return sorted;
  }

  Future<void> _discoverScanlationSlugs() async {
    if (_scanlationSlugs != null && _scanlationSlugs!.isNotEmpty) return;
    try {
      final slugs = await _scanlationService
          .searchAll(_item.title)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => <String, String>{},
          );
      if (slugs.isNotEmpty && mounted) {
        setState(() => _scanlationSlugs = slugs);
      }
    } catch (e, st) {
      Logger.e(
        'MangaDetailsDrawer: scanlation slug discovery failed for ${_item.title}',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Chapters in display order (newest first by default, like the
  /// manga page).
  List<MangaChapter> get _orderedChapters {
    if (!_reversed) return _chapters;
    return _chapters.reversed.toList();
  }

  /// Where the big reading button should go: the next unread chapter
  /// after the last-read one, or the very first chapter for new reads.
  MangaChapter? get _continueTarget {
    if (_chapters.isEmpty) return null;
    final lastId = _item.lastReadChapterId;
    if (lastId.isEmpty) return _chapters.first;
    final idx = _chapters.indexWhere((c) => c.id == lastId);
    if (idx < 0) return _chapters.first;
    if (idx + 1 < _chapters.length) return _chapters[idx + 1];
    return _chapters[idx];
  }

  bool get _hasStarted => _item.lastReadChapterId.isNotEmpty;

  Future<void> _openReader(MangaChapter chapter) async {
    // The reader lives in a deferred chunk (see docs/PERF_NOTES.md); ensure
    // it is loaded before pushing so direct drawer opens work offline-first.
    await reader_lib.loadLibrary();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => reader_lib.MangaReaderScreen(
          manga: _item,
          chapter: chapter,
          allChapters: _chapters,
          scanlationSlugs: _scanlationSlugs,
        ),
      ),
    );
  }

  Future<void> _updateLibraryStatus(String status) async {
    final user = context.read<AuthService>().currentUser ?? '';
    if (user.isEmpty) return;

    HapticFeedback.selectionClick();
    final previousStatus = _item.libraryStatus;

    await OptimisticAction.run(
      apply: () {
        if (!mounted) return;
        setState(() {
          _item = _item.copyWith(libraryStatus: status);
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                status == 'none'
                    ? 'Removed from your library'
                    : 'Set to ${_item.libraryDisplay}',
                style: AppTypography.outfitWhite,
              ),
              backgroundColor: KatanaColors.headerDark,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
      },
      action: () => _kakalotService.saveToLibrary(_item, status, user),
      rollback: () {
        if (!mounted) return;
        setState(() {
          _item = _item.copyWith(libraryStatus: previousStatus);
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to update library. Reverted.',
                style: AppTypography.outfitWhite,
              ),
              backgroundColor: KatanaColors.headerDark,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
      },
    );
  }

  /// Strip the link-dump tail ("Official Translation: https://…") and
  /// raw URLs / markdown leftovers so the synopsis reads cleanly.
  String get _cleanSynopsis {
    var text = _item.description;
    if (text.isEmpty) return '';
    // Descriptions sometimes arrive as HTML — drop tags first.
    text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // Cut the official-links tail if present.
    for (final marker in [
      '**Links:**',
      'Links:',
      '[Official',
      '(Official',
      'Official Simplified',
      'Official Traditional',
      'https://www.webtoons.com',
      'https://www.dongmanmanhua',
      'https://webtoons.com',
    ]) {
      final i = text.indexOf(marker);
      if (i > 40) {
        text = text.substring(0, i);
        break;
      }
    }
    // Drop leftover raw URLs, markdown bold, and bracket clutter.
    text = text.replaceAll(RegExp(r'https?://\S+'), '');
    text = text.replaceAll('**', '');
    text = text.replaceAll(RegExp(r'\[\s*\]'), '');
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  String get _metaLine {
    final parts = <String>[];
    if (_item.year.isNotEmpty) parts.add(_item.year);
    final byline = _item.author.isNotEmpty ? _item.author : _item.artist;
    if (byline.isNotEmpty) parts.add(byline);
    if (_item.rating > 0) parts.add('★ ${_item.rating.toStringAsFixed(1)}');
    if (_item.followCount > 0) {
      parts.add(_formatFollows(_item.followCount));
    }
    return parts.join('  •  ');
  }

  String _formatFollows(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M follows';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K follows';
    return '$n follows';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: KatanaColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: KatanaColors.border),
              left: BorderSide(color: KatanaColors.border),
              right: BorderSide(color: KatanaColors.border),
            ),
          ),
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    _buildHero(),
                    const SizedBox(height: 12),
                    _buildActions(),
                    const SizedBox(height: 12),
                    _buildLibraryCard(),
                    const SizedBox(height: 12),
                    _buildSynopsisCard(),
                    const SizedBox(height: 12),
                    _buildChaptersCard(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: KatanaColors.textLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text('Details', style: KatanaType.small)),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: KatanaColors.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: KatanaColors.text,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Cover-left hero, exactly like the manga page so the art is never
  /// cropped into a face close-up on phones.
  Widget _buildHero() {
    return KatanaCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 112,
              height: 160,
              child: _item.coverUrl.isEmpty
                  ? Container(
                      color: KatanaColors.surfaceAlt,
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: KatanaColors.textLight,
                        size: 36,
                      ),
                    )
                  : AppNetworkImage(
                      imageUrl: proxyMangaCoverUrl(_item.coverUrl),
                      fit: BoxFit.cover,
                      cacheWidth: 400,
                      errorWidget: Container(
                        color: KatanaColors.surfaceAlt,
                        child: const Icon(
                          Icons.broken_image_rounded,
                          color: KatanaColors.textLight,
                          size: 30,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    KatanaChip(label: _item.contentType),
                    if (_item.status.isNotEmpty)
                      KatanaChip(
                        label: _item.status,
                        color: KatanaColors.orange,
                      ),
                    if (_item.isInLibrary)
                      KatanaChip(
                        label: _item.libraryDisplay,
                        color: KatanaColors.green,
                        filled: true,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _item.title,
                  style: KatanaType.heading.copyWith(fontSize: 19),
                ),
                if (_metaLine.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _metaLine,
                    style: KatanaType.small,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (_chapters.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${_chapters.length} chapter${_chapters.length == 1 ? '' : 's'} available',
                    style: KatanaType.small.copyWith(
                      color: KatanaColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final target = _continueTarget;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        KatanaButton(
          label: _isLoadingChapters
              ? 'Loading…'
              : target == null
              ? 'No chapters yet'
              : _hasStarted
              ? 'Continue ${target.shortLabel}'
              : 'Start ${target.shortLabel}',
          icon: Icons.play_arrow_rounded,
          onTap: target == null ? null : () => _openReader(target),
        ),
        KatanaButton(
          label: 'Refresh',
          icon: Icons.refresh_rounded,
          filled: false,
          onTap: _isLoadingChapters
              ? null
              : () => _loadChapters(forceRefresh: true),
        ),
      ],
    );
  }

  Widget _buildLibraryCard() {
    const options = [
      _LibOption('reading', 'Reading', Icons.auto_stories_rounded),
      _LibOption('plan-to-read', 'Plan to Read', Icons.bookmark_add_outlined),
      _LibOption('completed', 'Completed', Icons.check_circle_outline_rounded),
      _LibOption('on-hold', 'On Hold', Icons.pause_circle_outline_rounded),
      _LibOption('dropped', 'Dropped', Icons.cancel_outlined),
    ];
    return KatanaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text('My Library', style: KatanaType.section)),
              if (_item.isInLibrary)
                GestureDetector(
                  onTap: () => _updateLibraryStatus('none'),
                  child: Text('Remove', style: KatanaType.link),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                KatanaChip(
                  label: o.label,
                  color: _item.libraryStatus == o.value
                      ? KatanaColors.green
                      : KatanaColors.accent,
                  filled: _item.libraryStatus == o.value,
                  onTap: () => _updateLibraryStatus(o.value),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSynopsisCard() {
    final text = _cleanSynopsis;
    if (text.isEmpty) return const SizedBox.shrink();
    const collapsedMax = 4;
    return KatanaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const KatanaSectionHeader(title: 'Synopsis'),
          const SizedBox(height: 10),
          Text(
            text,
            style: KatanaType.body.copyWith(fontSize: 13.5),
            maxLines: _synopsisExpanded ? null : collapsedMax,
            overflow: _synopsisExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
          if (text.length > 220)
            GestureDetector(
              onTap: () =>
                  setState(() => _synopsisExpanded = !_synopsisExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _synopsisExpanded ? 'Show less' : 'Show more',
                  style: KatanaType.link,
                ),
              ),
            ),
          if (_item.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in _item.tags.take(12))
                  KatanaChip(label: tag, color: KatanaColors.link),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChaptersCard() {
    final chapters = _orderedChapters;
    return KatanaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: KatanaSectionHeader(
                  title: _isLoadingChapters
                      ? 'Chapters'
                      : '${_chapters.length} Chapter${_chapters.length == 1 ? '' : 's'}',
                ),
              ),
              if (_chapters.isNotEmpty)
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
          if (_isLoadingChapters)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: KatanaColors.accent),
              ),
            )
          else if (_chapterError != null && _chapters.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _chapterError!,
                    style: KatanaType.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  KatanaButton(
                    label: 'Try again',
                    icon: Icons.refresh_rounded,
                    filled: false,
                    onTap: () => _loadChapters(forceRefresh: true),
                  ),
                ],
              ),
            )
          else if (_chapters.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No English chapters available.',
                  style: KatanaType.body,
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: KatanaColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < chapters.length; i++)
                    _DrawerChapterRow(
                      chapter: chapters[i],
                      highlight: i % 2 == 1,
                      isLastRead: _item.lastReadChapterId == chapters[i].id,
                      onTap: () => _openReader(chapters[i]),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LibOption {
  final String value;
  final String label;
  final IconData icon;
  const _LibOption(this.value, this.label, this.icon);
}

class _ChapterCacheEntry {
  final List<MangaChapter> chapters;
  final Map<String, String>? scanlationSlugs;
  final DateTime expiresAt;
  const _ChapterCacheEntry({
    required this.chapters,
    required this.scanlationSlugs,
    required this.expiresAt,
  });
}

class _DrawerChapterRow extends StatelessWidget {
  final MangaChapter chapter;
  final bool highlight;
  final bool isLastRead;
  final VoidCallback onTap;

  const _DrawerChapterRow({
    required this.chapter,
    required this.highlight,
    required this.isLastRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (chapter.scanlationGroup.isNotEmpty) chapter.scanlationGroup,
      if (chapter.pages > 0) '${chapter.pages} pages' else 'Tap to read',
    ].join('  •  ');
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isLastRead
              ? KatanaColors.accent.withValues(alpha: 0.14)
              : highlight
              ? KatanaColors.surfaceAlt
              : KatanaColors.surface,
          border: isLastRead
              ? Border.all(color: KatanaColors.accent.withValues(alpha: 0.45))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isLastRead ? Icons.bookmark_rounded : Icons.menu_book_rounded,
              size: 16,
              color: isLastRead ? KatanaColors.accent : KatanaColors.textLight,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chapter.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KatanaType.link.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KatanaType.small.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: KatanaColors.textLight,
            ),
          ],
        ),
      ),
    );
  }
}
