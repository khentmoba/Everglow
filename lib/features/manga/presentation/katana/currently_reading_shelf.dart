import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../data/models/katana_models.dart';
import '../../data/models/manga_item.dart';
import '../../data/services/katana_service.dart';
import '../../data/services/mangakakalot_service.dart';
import '../widgets/manga_details_drawer.dart';
import 'katana_nav.dart';
import 'katana_theme.dart';

/// Currently Reading shelf for MangaCelestia.
///
/// Shows the titles the user explicitly marked as "Reading" (the
/// "Khent Reading" / "Claire Reading" button on the detail page,
/// stored in `manga_library` with `libraryStatus == 'reading'`),
/// enriched with chapter progress from `katana_bookmarks` for Katana
/// titles so Clair sees "Ch. 12 • Page 5" and a Resume button.
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
  Map<String, KatanaBookmark> _bookmarksBySlug = const {};
  String? _loadingSlug;

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
    // Bookmark progress enriches Katana cards with chapter + page.
    _bookmarkSub = _katana.bookmarkStream(widget.userName).listen((items) {
      if (!mounted) return;
      setState(() {
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
    } catch (_) {
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
    if (_mine.isEmpty && _partner.isEmpty) return const SizedBox.shrink();

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
          items: _mine.take(10).toList(),
          progressFor: _progressFor,
          loadingSlug: _loadingSlug,
          slugOf: katanaSlugOfItem,
          onResume: _resume,
          onOpen: _openDetails,
          onRemove: _remove,
          emptyText: _hasPartner
              ? 'Tap "Reading" on any series to track it here.'
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

  const _ReadingCard({
    required this.item,
    required this.progress,
    required this.isLoading,
    required this.onResume,
    required this.onOpen,
    this.onRemove,
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
                        errorBuilder: (_, _, _) => Container(
                          color: KatanaColors.surfaceAlt,
                          child: const Icon(
                            Icons.broken_image_rounded,
                            color: KatanaColors.textLight,
                            size: 24,
                          ),
                        ),
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
                      if (onRemove != null) ...[
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
