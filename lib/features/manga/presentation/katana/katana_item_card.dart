import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/katana_models.dart';
import '../../data/services/katana_service.dart';
import './katana_nav.dart';
import './katana_theme.dart';

/// The expanded list item used on the home page and every directory
/// page: cover + status badge on the left, title, update time, first
/// chapter, genres, summary and recent chapters on the right.
class KatanaItemCard extends StatelessWidget {
  final KatanaManga manga;
  final bool dense;

  const KatanaItemCard({super.key, required this.manga, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final coverHeight = dense || compact ? 110.0 : 150.0;
    final coverWidth = dense || compact ? 76.0 : 105.0;
    return KatanaCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => pushDetail(context, manga.slug),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              _Cover(
                url: manga.coverUrl,
                width: coverWidth,
                height: coverHeight,
                status: manga.status,
              ),
              const SizedBox(width: 12),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(manga),
                    if (!compact) ...[
                      const SizedBox(height: 6),
                      _buildMetaRow(context, manga),
                      if (manga.genres.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        _buildGenres(context, manga),
                      ],
                      if (manga.summary.isNotEmpty && !dense) ...[
                        const SizedBox(height: 8),
                        Text(
                          manga.summary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: KatanaType.small.copyWith(
                            color: KatanaColors.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      if (manga.recentChapters.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildChapters(context, manga),
                      ],
                    ] else ...[
                      const SizedBox(height: 6),
                      if (manga.latestChapter != null)
                        Text(
                          'Latest: ${manga.latestChapter!.displayTitle}',
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
            const Icon(Icons.schedule_rounded,
                size: 13, color: KatanaColors.textLight),
            const SizedBox(width: 4),
            Text(manga.updateText.isEmpty ? 'recently' : manga.updateText,
                style: KatanaType.small),
          ],
        ),
        if (manga.latestChapter != null)
          GestureDetector(
            onTap: () => pushReader(
              context,
              slug: manga.slug,
              chapterId: manga.latestChapter!.path,
              chapters: manga.recentChapters,
              mangaTitle: manga.title,
              coverUrl: manga.coverUrl,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.double_arrow_rounded,
                    size: 13, color: KatanaColors.link),
                const SizedBox(width: 4),
                Text('First Chapter', style: KatanaType.link),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGenres(BuildContext context, KatanaManga manga) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final genre in manga.genres)
          GestureDetector(
            onTap: () => pushGenreDirectory(context, genre.slug, genre.name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: KatanaColors.link.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: KatanaColors.link.withValues(alpha: 0.35)),
              ),
              child: Text(
                genre.name,
                style: AppTypography.outfitWhite.copyWith(
                  color: KatanaColors.link,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChapters(BuildContext context, KatanaManga manga) {
    return Column(
      children: [
        for (final chapter in manga.recentChapters.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => pushReader(
                      context,
                      slug: manga.slug,
                      chapterId: chapter.path,
                      chapters: manga.recentChapters,
                      mangaTitle: manga.title,
                      coverUrl: manga.coverUrl,
                    ),
                    child: Text(
                      chapter.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitWhite.copyWith(
                        color: KatanaColors.link,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: KatanaColors.link.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  chapter.updateAt != null
                      ? formatKatanaTime(chapter.updateAt)
                      : '',
                  style: KatanaType.small.copyWith(fontSize: 11),
                ),
              ],
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            url.isEmpty
                ? Container(
                    color: KatanaColors.border,
                    child: const Icon(Icons.menu_book_rounded,
                        color: KatanaColors.textLight, size: 28),
                  )
                : KatanaNetworkImage(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: KatanaColors.border,
                      child: const Icon(Icons.broken_image_rounded,
                          color: KatanaColors.textLight, size: 26),
                    ),
                  ),
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: status == 'completed'
                      ? KatanaColors.green
                      : KatanaColors.accent,
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(5),
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
    );
  }
}

/// Compact cover card used by the Hot Manga rail and bookmark grid.
class KatanaCompactCard extends StatelessWidget {
  final KatanaManga manga;
  final double width;

  const KatanaCompactCard({super.key, required this.manga, this.width = 150});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => pushDetail(context, manga.slug),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: width,
              height: width * 1.42,
              child: manga.coverUrl.isEmpty
                  ? Container(
                      color: KatanaColors.border,
                      child: const Icon(Icons.menu_book_rounded,
                          color: KatanaColors.textLight),
                    )
                  : KatanaNetworkImage(
                      manga.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: KatanaColors.border,
                        child: const Icon(Icons.broken_image_rounded,
                            color: KatanaColors.textLight),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            manga.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.outfitBold.copyWith(
              color: KatanaColors.text,
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
                  color: manga.isCompleted
                      ? KatanaColors.green
                      : KatanaColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  manga.isCompleted ? 'Completed' : 'Ongoing',
                  style: KatanaType.small.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
          if (manga.latestChapter != null)
            Text(
              manga.latestChapter!.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KatanaType.accent.copyWith(fontSize: 11.5),
            ),
        ],
      ),
    );
  }
}
