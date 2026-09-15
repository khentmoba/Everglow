import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../data/models/katana_models.dart';
import '../../data/services/katana_service.dart';
import 'katana_nav.dart';
import 'katana_theme.dart';

class ContinueReadingShelf extends StatefulWidget {
  final String userName;

  const ContinueReadingShelf({super.key, required this.userName});

  @override
  State<ContinueReadingShelf> createState() => _ContinueReadingShelfState();
}

class _ContinueReadingShelfState extends State<ContinueReadingShelf> {
  final KatanaService _service = KatanaService();
  String? _loadingSlug;
  final Set<String> _healAttempted = {};

  bool _needsHeal(KatanaBookmark bookmark) {
    if (bookmark.slug.isEmpty) return false;
    if (bookmark.title.trim().isEmpty) return true;
    if (bookmark.coverUrl.trim().isEmpty) return true;
    final uri = Uri.tryParse(bookmark.coverUrl.trim());
    if (uri == null || !uri.hasScheme) return true;
    return false;
  }

  /// Proactively fills in title/cover for progress-only docs as soon as
  /// the shelf renders, so Clair never stares at a placeholder thumbnail.
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

  Future<void> _healOne(KatanaBookmark bookmark) async {
    try {
      final detail = await _service.fetchMangaDetail(bookmark.slug);
      if (!mounted || detail == null) return;
      if (detail.title.isEmpty && detail.coverUrl.isEmpty) return;
      await _service.saveReadingProgress(
        slug: bookmark.slug,
        userName: widget.userName,
        chapterId: bookmark.lastReadChapterId,
        chapterTitle: bookmark.lastReadChapterTitle,
        page: bookmark.lastReadPage,
        title: detail.title,
        coverUrl: detail.coverUrl,
      );
    } catch (_) {}
  }

  Future<void> _resumeReading(KatanaBookmark bookmark) async {
    if (_loadingSlug != null) return;
    setState(() => _loadingSlug = bookmark.slug);

    try {
      final detail = await _service.fetchMangaDetail(bookmark.slug);
      if (!mounted) return;
      // Heal progress-only docs saved before title/cover were persisted:
      // the shelf would otherwise show a blank title + placeholder cover.
      // Use the fresh detail cover/title so the shelf heals even when the
      // user goes straight to the reader.
      if (detail != null && _needsHeal(bookmark)) {
        _healAttempted.add(bookmark.slug);
        unawaited(
          _service.saveReadingProgress(
            slug: bookmark.slug,
            userName: widget.userName,
            chapterId: bookmark.lastReadChapterId,
            chapterTitle: bookmark.lastReadChapterTitle,
            page: bookmark.lastReadPage,
            title: detail.title,
            coverUrl: detail.coverUrl,
          ),
        );
      }
      final chapters = detail?.chapters ?? const <KatanaChapter>[];
      final sorted = sortChaptersAscending(chapters);

      if (sorted.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No chapters available for this series.'),
            backgroundColor: KatanaColors.headerDark,
          ),
        );
        return;
      }

      KatanaChapter target = sorted.first;
      if (bookmark.lastReadChapterId.isNotEmpty) {
        target = sorted.firstWhere(
          (c) => c.id == bookmark.lastReadChapterId,
          orElse: () => sorted.first,
        );
      }

      final resolvedTitle = (detail?.title.trim().isNotEmpty == true)
          ? detail!.title
          : bookmark.title;
      final resolvedCover = (detail?.coverUrl.trim().isNotEmpty == true)
          ? detail!.coverUrl
          : bookmark.coverUrl;

      pushReader(
        context,
        slug: bookmark.slug,
        chapterId: target.path,
        chapters: chapters,
        mangaTitle: resolvedTitle,
        coverUrl: resolvedCover,
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

  @override
  Widget build(BuildContext context) {
    if (widget.userName.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<KatanaBookmark>>(
      stream: _service.bookmarkStream(widget.userName),
      builder: (context, snapshot) {
        final bookmarks = snapshot.data ?? const [];
        final withProgress =
            bookmarks.where((b) => b.hasProgress).take(5).toList();

        if (withProgress.isEmpty) return const SizedBox.shrink();

        // Heal placeholder thumbnails in the background as soon as we see
        // them — no need to wait for Clair to tap a card first.
        _healMissingMeta(withProgress);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const KatanaSectionHeader(
              title: 'Continue Reading',
              underline: KatanaColors.accent,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: withProgress.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = withProgress[index];
                  final isLoading = _loadingSlug == item.slug;

                  return _ResumeCard(
                    bookmark: item,
                    isLoading: isLoading,
                    onResume: () => _resumeReading(item),
                    onTapDetail: () => pushDetail(context, item.slug),
                    onCoverError: () => _requestHeal(item),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

/// Shows the saved title, falling back to a human-readable slug so
/// progress-only bookmarks never render a blank title line.
String _displayTitle(KatanaBookmark bookmark) {
  if (bookmark.title.trim().isNotEmpty) return bookmark.title;
  final slug = bookmark.slug.trim();
  if (slug.isEmpty) return 'Untitled series';
  return slug
      .split('-')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

class _ResumeCard extends StatelessWidget {
  final KatanaBookmark bookmark;
  final bool isLoading;
  final VoidCallback onResume;
  final VoidCallback onTapDetail;
  final VoidCallback? onCoverError;

  const _ResumeCard({
    required this.bookmark,
    required this.isLoading,
    required this.onResume,
    required this.onTapDetail,
    this.onCoverError,
  });

  @override
  Widget build(BuildContext context) {
    // Card tap goes to the detail/info page. Only the explicit Resume
    // button jumps straight into the reader.
    return GestureDetector(
      onTap: onTapDetail,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: KatanaColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: KatanaColors.accent.withValues(alpha: 0.35),
            width: 1.2,
          ),
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
            // Cover thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 76,
                height: 118,
                child: bookmark.coverUrl.isEmpty
                    ? Container(
                        color: KatanaColors.surfaceAlt,
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: KatanaColors.textLight,
                          size: 28,
                        ),
                      )
                    : KatanaNetworkImage(
                        bookmark.coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) {
                          if (onCoverError != null) {
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => onCoverError!(),
                            );
                          }
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

            // Metadata & Action
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _displayTitle(bookmark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitBold.copyWith(
                      color: KatanaColors.text,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bookmark.lastReadChapterTitle.isNotEmpty
                        ? bookmark.lastReadChapterTitle
                        : 'Chapter in progress',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KatanaType.small.copyWith(
                      color: KatanaColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  if (bookmark.lastReadPage > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Page ${bookmark.lastReadPage}',
                      style: KatanaType.small.copyWith(fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 10),
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
                        boxShadow: [
                          BoxShadow(
                            color: KatanaColors.accent.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
