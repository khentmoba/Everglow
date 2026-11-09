import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/katana_models.dart';
import '../../data/services/katana_service.dart';
import './katana_nav.dart';
import './katana_theme.dart';

/// The expanded list item used on the home page and every directory
/// page: cover + status badge on the left, title, update time, first
/// chapter, genres, summary and recent chapters on the right.
class KatanaItemCard extends StatefulWidget {
  final KatanaManga manga;
  final bool dense;

  const KatanaItemCard({super.key, required this.manga, this.dense = false});

  @override
  State<KatanaItemCard> createState() => _KatanaItemCardState();
}

class _KatanaItemCardState extends State<KatanaItemCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final coverHeight = widget.dense || compact ? 114.0 : 152.0;
    final coverWidth = widget.dense || compact ? 80.0 : 106.0;
    return Container(
      decoration: BoxDecoration(
        color: KatanaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focused ? KatanaColors.accent : KatanaColors.border,
          width: 2.0,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: KatanaColors.accent.withValues(alpha: 0.5),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
                const BoxShadow(
                  color: AppColors.scrimStrong,
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ]
            : const [
                BoxShadow(
                  color: AppColors.scrimStrong,
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => pushDetail(context, widget.manga.slug),
          onFocusChange: (focused) {
            if (focused) {
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
            }
            setState(() => _focused = focused);
          },
          focusColor: KatanaColors.accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                _Cover(
                  url: widget.manga.coverUrl,
                  width: coverWidth,
                  height: coverHeight,
                  status: widget.manga.status,
                ),
                const SizedBox(width: 12),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitle(widget.manga),
                      const SizedBox(height: 6),
                      _buildMetaRow(context, widget.manga),
                      if (widget.manga.genres.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        _buildGenres(
                          context,
                          widget.manga,
                          limit: compact ? 3 : widget.manga.genres.length,
                        ),
                      ],
                      if (!compact &&
                          widget.manga.summary.isNotEmpty &&
                          !widget.dense) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.manga.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: KatanaType.small.copyWith(
                            color: KatanaColors.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      if (widget.manga.recentChapters.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildChapters(
                          context,
                          widget.manga,
                          maxCount: compact ? 2 : 3,
                        ),
                      ] else if (widget.manga.latestChapter != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Latest: ${widget.manga.latestChapter!.displayTitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KatanaType.accent,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(KatanaManga manga) {
    return Text(
      manga.latestChapter != null
          ? '${manga.title} - Update ${manga.latestChapter!.displayTitle}'
          : manga.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.outfitBold.copyWith(
        color: KatanaColors.text,
        fontSize: 15,
        height: 1.3,
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context, KatanaManga manga) {
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 13,
              color: KatanaColors.textLight,
            ),
            const SizedBox(width: 4),
            Text(
              manga.updateText.isEmpty ? 'recently' : manga.updateText,
              style: KatanaType.small,
            ),
          ],
        ),
        if (manga.latestChapter != null)
          GestureDetector(
            // Opens the reader at the true first chapter (`fc`). The old
            // code passed latestChapter here, so "First Chapter"
            // actually opened the NEWEST chapter.
            onTap: () => pushReader(
              context,
              slug: manga.slug,
              chapterId: 'fc',
              chapters: manga.recentChapters,
              mangaTitle: manga.title,
              coverUrl: manga.coverUrl,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.double_arrow_rounded,
                  size: 13,
                  color: KatanaColors.link,
                ),
                const SizedBox(width: 4),
                Text('First Chapter', style: KatanaType.link),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGenres(
    BuildContext context,
    KatanaManga manga, {
    int? limit,
  }) {
    final visible = limit != null
        ? manga.genres.take(limit)
        : manga.genres;
    return Wrap(
      spacing: 6,
      runSpacing: 5,
      children: [
        for (final genre in visible)
          GestureDetector(
            onTap: () => pushGenreDirectory(context, genre.slug, genre.name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: KatanaColors.surfaceAlt,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: KatanaColors.link.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                genre.name,
                style: AppTypography.outfitWhite.copyWith(
                  color: KatanaColors.link,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChapters(
    BuildContext context,
    KatanaManga manga, {
    int maxCount = 3,
  }) {
    final list = manga.recentChapters.take(maxCount).toList();
    return Column(
      children: [
        for (int i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: GestureDetector(
              onTap: () => pushReader(
                context,
                slug: manga.slug,
                chapterId: list[i].path,
                chapters: manga.recentChapters,
                mangaTitle: manga.title,
                coverUrl: manga.coverUrl,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  color: i == 0
                      ? KatanaColors.accent.withValues(alpha: 0.12)
                      : KatanaColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: i == 0
                        ? KatanaColors.accent.withValues(alpha: 0.45)
                        : KatanaColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      i == 0
                          ? Icons.bolt_rounded
                          : Icons.menu_book_rounded,
                      size: 13,
                      color: i == 0
                          ? KatanaColors.accent
                          : KatanaColors.accentSoft,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        list[i].displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitWhite.copyWith(
                          color: i == 0
                              ? KatanaColors.text
                              : KatanaColors.accentSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (list[i].updateAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        formatKatanaTime(list[i].updateAt),
                        style: KatanaType.small.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final String status;

  const _Cover({
    required this.url,
    required this.width,
    required this.height,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KatanaColors.borderStrong),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              url.isEmpty
                  ? Container(
                      color: KatanaColors.surfaceAlt,
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: KatanaColors.textLight,
                        size: 28,
                      ),
                    )
                  : KatanaNetworkImage(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: KatanaColors.surfaceAlt,
                        child: const Icon(
                          Icons.broken_image_rounded,
                          color: KatanaColors.textLight,
                          size: 26,
                        ),
                      ),
                    ),
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'completed'
                        ? KatanaColors.green
                        : KatanaColors.accent,
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    status == 'completed' ? 'Completed' : 'Ongoing',
                    style: AppTypography.outfitBold.copyWith(
                      color: Colors.white,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact cover card used by the Hot Manga rail and bookmark grid.
class KatanaCompactCard extends StatefulWidget {
  final KatanaManga manga;
  final double width;

  const KatanaCompactCard({super.key, required this.manga, this.width = 150});

  @override
  State<KatanaCompactCard> createState() => _KatanaCompactCardState();
}

class _KatanaCompactCardState extends State<KatanaCompactCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onFocusChange: (focused) {
        if (focused) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        }
        setState(() => _focused = focused);
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            pushDetail(context, widget.manga.slug);
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: () => pushDetail(context, widget.manga.slug),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _focused ? KatanaColors.accent : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: KatanaColors.accent.withValues(alpha: 0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: widget.width,
                  height: widget.width * 1.42,
                  child: widget.manga.coverUrl.isEmpty
                      ? Container(
                          color: KatanaColors.border,
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: KatanaColors.textLight,
                          ),
                        )
                      : KatanaNetworkImage(
                          widget.manga.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: KatanaColors.border,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: KatanaColors.textLight,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              widget.manga.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.outfitBold.copyWith(
                color: _focused ? KatanaColors.accent : KatanaColors.text,
                fontSize: 12.5,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: widget.manga.isCompleted
                        ? KatanaColors.green
                        : KatanaColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    widget.manga.isCompleted ? 'Completed' : 'Ongoing',
                    style: KatanaType.small.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
            if (widget.manga.latestChapter != null)
              GestureDetector(
                // Like the site's rail: tapping the chapter link opens
                // the reader at that chapter, while the rest of the
                // card opens the detail page.
                onTap: () {
                  final latest = widget.manga.latestChapter!;
                  pushReader(
                    context,
                    slug: widget.manga.slug,
                    chapterId: latest.path,
                    chapters: [latest],
                    mangaTitle: widget.manga.title,
                    coverUrl: widget.manga.coverUrl,
                  );
                },
                child: Text(
                  widget.manga.latestChapter!.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KatanaType.accent.copyWith(fontSize: 11.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
