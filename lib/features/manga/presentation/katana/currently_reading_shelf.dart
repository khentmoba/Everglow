import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/logger.dart';
import '../../data/models/katana_models.dart';
import '../../data/models/manga_item.dart';
import '../../data/services/katana_service.dart';
import '../../data/services/mangakakalot_service.dart';
import '../widgets/manga_details_drawer.dart';
import 'katana_nav.dart';
import 'katana_theme.dart';

/// Currently Reading shelf for MangaCelestia.
///
/// Shows the titles the user is reading — pinned automatically on
/// the first page read, or via the "Reading" button on the detail
/// page (stored in `manga_library` with `libraryStatus == 'reading'`),
/// enriched with chapter progress from `katana_bookmarks` for Katana
/// titles so Clair sees "Ch. 12 • Page 5" and a Resume button.
///
/// The "You" row also folds in titles with chapter progress that were
/// never pinned as Reading (the old Continue Reading shelf), so there
/// is exactly one resume shelf on home and nothing resumable hides.
/// Those entries show no Remove button — there is no library entry to
/// remove — and vanish from this row only when their progress does.
///
/// For couple users the shelf splits into "You" and partner rows, just
/// like the dashboard Reading shelf. Hidden entirely until there is
/// something to show, so the home page stays clean for new readers.
/// Extracts the Katana slug from a library entry. Katana titles are
/// keyed as `katana|<slug>` with the slug duplicated in
/// `mangaKakalotId` for backwards compatibility.
String katanaSlugOfItem(MangaItem item) {
  if (item.mangaId.startsWith('katana|')) {
    final parts = item.mangaId.split('|');
    if (parts.length > 1 && parts[1].isNotEmpty) return parts[1];
  }
  return item.mangaKakalotId;
}

/// Turns a bare slug into a readable title so progress-only entries
/// saved before title/cover were persisted never render blank.
String humanizeKatanaSlug(String slug) {
  final clean = slug.trim();
  if (clean.isEmpty) return 'Untitled series';
  return clean
      .split('-')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// Builds a display-only library entry from a progress bookmark for
/// titles Clair read but never pinned as Reading. `libraryStatus`
/// stays `'none'` so the card renders without a Remove button.
MangaItem progressOnlyReadingItem(KatanaBookmark bookmark, String userName) {
  final title = bookmark.title.trim().isNotEmpty
      ? bookmark.title
      : humanizeKatanaSlug(bookmark.slug);
  return MangaItem(
    id: 'progress|${bookmark.slug}',
    mangaId: 'katana|${bookmark.slug}',
    title: title,
    coverUrl: bookmark.coverUrl,
    status: bookmark.status,
    userName: userName,
    addedAt: bookmark.addedAt,
    lastReadChapterId: bookmark.lastReadChapterId,
    lastReadPage: bookmark.lastReadPage,
    mangaKakalotId: bookmark.slug,
  );
}

/// Merges the pinned Reading list with progress-only bookmarks
/// (read but never pinned), deduplicated by Katana slug. Pinned
/// entries keep their order first; progress-only entries follow.
List<MangaItem> mergeReadingWithProgress({
  required List<MangaItem> reading,
  required List<KatanaBookmark> bookmarks,
  required String userName,
}) {
  final pinnedSlugs = <String>{
    for (final item in reading)
      if (katanaSlugOfItem(item).isNotEmpty) katanaSlugOfItem(item),
  };
  final merged = List<MangaItem>.from(reading);
  for (final bookmark in bookmarks) {
    if (!bookmark.hasProgress) continue;
    if (bookmark.slug.isEmpty) continue;
    if (pinnedSlugs.contains(bookmark.slug)) continue;
    pinnedSlugs.add(bookmark.slug);
    merged.add(progressOnlyReadingItem(bookmark, userName));
  }
  return merged;
}

class CurrentlyReadingShelf extends StatefulWidget {
  final String userName;
  final String? partnerName;

  const CurrentlyReadingShelf({
    super.key,
    required this.userName,
    this.partnerName,
  });

  static String katanaSlugOf(MangaItem item) => katanaSlugOfItem(item);

  @override
  State<CurrentlyReadingShelf> createState() => _CurrentlyReadingShelfState();
}

class _CurrentlyReadingShelfState extends State<CurrentlyReadingShelf> {
  final MangaKakalotService _library = MangaKakalotService();
  final KatanaService _katana = KatanaService();

  StreamSubscription<List<MangaItem>>? _mineSub;
  StreamSubscription<List<MangaItem>>? _partnerSub;
  StreamSubscription<List<KatanaBookmark>>? _bookmarkSub;

  List<MangaItem> _mine = const [];
  List<MangaItem> _partner = const [];
  List<KatanaBookmark> _bookmarks = const [];
  Map<String, KatanaBookmark> _bookmarksBySlug = const {};
  String? _loadingSlug;
  final Set<String> _healAttempted = {};

  bool get _hasPartner =>
      widget.partnerName != null && widget.partnerName!.isNotEmpty;

  String _displayName(String user) {
    if (user == 'khentsgdz') return 'Khent';
    if (user == 'clairjassen') return 'Clair';
    return user;
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant CurrentlyReadingShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName ||
        oldWidget.partnerName != widget.partnerName) {
      _mineSub?.cancel();
      _partnerSub?.cancel();
      _bookmarkSub?.cancel();
      _mine = const [];
      _partner = const [];
      _bookmarks = const [];
      _bookmarksBySlug = const {};
      _subscribe();
    }
  }

  void _subscribe() {
    if (widget.userName.isEmpty) return;
    _mineSub = _library
        .getReadingPreviewStream(widget.userName, limit: 24)
        .listen((items) {
      if (mounted) setState(() => _mine = items);
    });
    if (_hasPartner) {
      _partnerSub = _library
          .getReadingPreviewStream(widget.partnerName!, limit: 24)
          .listen((items) {
        if (mounted) setState(() => _partner = items);
      });
    }
    // Bookmark progress enriches Katana cards with chapter + page,
    // and progress-only entries join the "You" row (see build).
    _bookmarkSub = _katana.bookmarkStream(widget.userName).listen((items) {
      if (!mounted) return;
      setState(() {
        _bookmarks = items;
        _bookmarksBySlug = {for (final b in items) b.slug: b};
      });
    });
  }

  @override
  void dispose() {
    _mineSub?.cancel();
    _partnerSub?.cancel();
    _bookmarkSub?.cancel();
    super.dispose();
  }

  KatanaBookmark? _progressFor(MangaItem item) {
    final slug = katanaSlugOfItem(item);
    if (slug.isEmpty) return null;
    return _bookmarksBySlug[slug];
  }

  bool _needsHeal(KatanaBookmark bookmark) {
    if (bookmark.slug.isEmpty) return false;
    if (bookmark.title.trim().isEmpty) return true;
    if (bookmark.coverUrl.trim().isEmpty) return true;
    final uri = Uri.tryParse(bookmark.coverUrl.trim());
    if (uri == null || !uri.hasScheme) return true;
    return false;
  }

  /// Fills in title/cover for progress-only entries as soon as the
  /// shelf renders, so Clair never stares at a placeholder thumbnail.
  /// Runs once per slug per session; the bookmark stream rebuilds the
  /// shelf once Firestore has the healed values.
  void _healMissingMeta(List<KatanaBookmark> bookmarks) {
    for (final bookmark in bookmarks) {
      if (!_needsHeal(bookmark)) continue;
      _requestHeal(bookmark);
    }
  }

  void _requestHeal(KatanaBookmark bookmark) {
    if (bookmark.slug.isEmpty) return;
    if (_healAttempted.contains(bookmark.slug)) return;
    _healAttempted.add(bookmark.slug);
    unawaited(_healOne(bookmark));
  }

  /// Reactive heal: a cover URL that looks valid but 404s (stale link)
  /// triggers one background heal instead of a permanent broken image.
  void _handleCoverError(MangaItem item) {
    final bookmark = _progressFor(item);
    if (bookmark != null) _requestHeal(bookmark);
  }

  Future<void> _healOne(KatanaBookmark bookmark) async {
    try {
      final detail = await _katana.fetchMangaDetail(bookmark.slug);
      if (!mounted || detail == null) return;
      if (detail.title.isEmpty && detail.coverUrl.isEmpty) return;
      await _katana.saveReadingProgress(
        slug: bookmark.slug,
        userName: widget.userName,
        chapterId: bookmark.lastReadChapterId,
        chapterTitle: bookmark.lastReadChapterTitle,
        page: bookmark.lastReadPage,
        title: detail.title,
        coverUrl: detail.coverUrl,
      );
    } catch (e) {
      Logger.e('Manga: shelf cover heal failed', error: e);
    }
  }

  Future<void> _resume(MangaItem item) async {
    final slug = katanaSlugOfItem(item);
    if (slug.isEmpty || _loadingSlug != null) return;
    // Non-Katana library entries open the classic details drawer,
    // which owns its own reader.
    if (!item.mangaId.startsWith('katana|')) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MangaDetailsDrawer(item: item),
      );
      return;
    }
    setState(() => _loadingSlug = slug);
    try {
      final detail = await _katana.fetchMangaDetail(slug);
      if (!mounted) return;
      final chapters = detail?.chapters ?? const <KatanaChapter>[];
      final sorted = sortChaptersAscending(chapters);
      if (sorted.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No chapters available for this series yet.'),
            backgroundColor: KatanaColors.headerDark,
          ),
        );
        return;
      }
      final progress = _progressFor(item);
      KatanaChapter target = sorted.first;
      final wantId = progress?.lastReadChapterId.isNotEmpty == true
          ? progress!.lastReadChapterId
          : item.lastReadChapterId;
      if (wantId.isNotEmpty) {
        target = sorted.firstWhere((c) => c.id == wantId,
            orElse: () => sorted.first);
      }
      pushReader(
        context,
        slug: slug,
        chapterId: target.path,
        chapters: chapters,
        mangaTitle: item.title,
        coverUrl: item.coverUrl,
      );
    } catch (e, st) {
      Logger.e(
        'CurrentlyReadingShelf: failed to open reader for $slug',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open reader. Please try again.'),
            backgroundColor: KatanaColors.headerDark,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSlug = null);
    }
  }

  void _openDetails(MangaItem item) {
    final slug = katanaSlugOfItem(item);
    if (slug.isNotEmpty && item.mangaId.startsWith('katana|')) {
      pushDetail(context, slug);
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MangaDetailsDrawer(item: item),
    );
  }

  Future<void> _remove(MangaItem item) async {
    if (item.mangaId.startsWith('katana|')) {
      await _katana.setReading(
        KatanaManga(
          slug: katanaSlugOfItem(item),
          id: katanaSlugOfItem(item),
          title: item.title,
          coverUrl: item.coverUrl,
        ),
        widget.userName,
        reading: false,
      );
    } else {
      await _library.removeFromLibrary(item.mangaId, widget.userName);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${item.title}" from Currently Reading'),
          backgroundColor: KatanaColors.headerDark,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userName.isEmpty) return const SizedBox.shrink();
    // One resume shelf: pinned Reading entries plus progress-only
    // titles, deduplicated by slug so nothing appears twice.
    final mergedMine = mergeReadingWithProgress(
      reading: _mine,
      bookmarks: _bookmarks,
      userName: widget.userName,
    );
    if (mergedMine.isEmpty && _partner.isEmpty) {
      return const SizedBox.shrink();
    }
    // Heal placeholder thumbnails in the background as soon as we
    // see them — no need to wait for Clair to tap a card first.
    _healMissingMeta(_bookmarks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KatanaSectionHeader(
          title: 'Currently Reading',
          trailing: GestureDetector(
            onTap: () => pushCurrentlyReading(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('View all', style: KatanaType.accent),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: KatanaColors.accent,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ReadingRow(
          label: _hasPartner ? 'You' : null,
          items: mergedMine.take(10).toList(),
          progressFor: _progressFor,
          loadingSlug: _loadingSlug,
          slugOf: katanaSlugOfItem,
          onResume: _resume,
          onOpen: _openDetails,
          onRemove: _remove,
          onCoverError: _handleCoverError,
          emptyText: _hasPartner
              ? 'Read anything and it lands here on its own.'
              : null,
        ),
        if (_hasPartner) ...[
          const SizedBox(height: 12),
          _ReadingRow(
            label: _displayName(widget.partnerName!),
            items: _partner.take(10).toList(),
            progressFor: (_) => null,
            loadingSlug: null,
            slugOf: katanaSlugOfItem,
            onResume: _resume,
            onOpen: _openDetails,
            onRemove: null,
            emptyText: 'Nothing on their reading list yet.',
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class _ReadingRow extends StatelessWidget {
  final String? label;
  final List<MangaItem> items;
  final KatanaBookmark? Function(MangaItem) progressFor;
  final String? loadingSlug;
  final String Function(MangaItem) slugOf;
  final Future<void> Function(MangaItem) onResume;
  final void Function(MangaItem) onOpen;
  final Future<void> Function(MangaItem)? onRemove;
  final void Function(MangaItem)? onCoverError;
  final String? emptyText;

  const _ReadingRow({
    required this.items,
    required this.progressFor,
    required this.slugOf,
    required this.onResume,
    required this.onOpen,
    this.label,
    this.loadingSlug,
    this.onRemove,
    this.onCoverError,
    this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final header = label != null
        ? Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label!.toUpperCase(),
              style: KatanaType.small.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          )
        : const SizedBox.shrink();

    if (items.isEmpty) {
      if (emptyText == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Text(emptyText!, style: KatanaType.small),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        SizedBox(
          height: 142,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final progress = progressFor(item);
              final isLoading = loadingSlug == slugOf(item);
              return _ReadingCard(
                item: item,
                progress: progress,
                isLoading: isLoading,
                onResume: () => onResume(item),
                onOpen: () => onOpen(item),
                onRemove:
                    onRemove == null ? null : () => onRemove!(item),
                onCoverError: onCoverError == null
                    ? null
                    : () => onCoverError!(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReadingCard extends StatelessWidget {
  final MangaItem item;
  final KatanaBookmark? progress;
  final bool isLoading;
  final VoidCallback onResume;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;
  final VoidCallback? onCoverError;

  const _ReadingCard({
    required this.item,
    required this.progress,
    required this.isLoading,
    required this.onResume,
    required this.onOpen,
    this.onRemove,
    this.onCoverError,
  });

  String get _progressLine {
    final chapter = progress?.lastReadChapterTitle.isNotEmpty == true
        ? progress!.lastReadChapterTitle
        : (item.lastReadChapterId.isNotEmpty
            ? item.lastReadChapterId
            : '');
    final page = progress?.lastReadPage ?? item.lastReadPage;
    if (chapter.isEmpty && page <= 0) return 'Just started';
    if (chapter.isEmpty) return 'Page $page';
    if (page > 0) return '$chapter • Page $page';
    return chapter;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        width: 308,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: KatanaColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KatanaColors.border),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 76,
                height: 118,
                child: item.coverUrl.isEmpty
                    ? Container(
                        color: KatanaColors.surfaceAlt,
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: KatanaColors.textLight,
                          size: 28,
                        ),
                      )
                    : KatanaNetworkImage(
                        item.coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) {
                          onCoverError?.call();
                          return Container(
                            color: KatanaColors.surfaceAlt,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: KatanaColors.textLight,
                              size: 24,
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title.isEmpty ? 'Untitled series' : item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitBold.copyWith(
                      color: KatanaColors.text,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _progressLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KatanaType.small.copyWith(
                      color: KatanaColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: onResume,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: KatanaColors.accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isLoading)
                                const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              const SizedBox(width: 4),
                              Text(
                                isLoading ? 'Opening...' : 'Resume',
                                style: AppTypography.outfitBold.copyWith(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Progress-only entries have no library entry
                      // to remove, so they render without the X.
                      if (onRemove != null && item.isReading) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onRemove,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.close_rounded,
                              color: KatanaColors.textLight,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
