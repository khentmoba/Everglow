import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/offline_media/offline_media_item.dart';
import '../../../../core/services/offline_media/offline_media_service.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../data/models/katana_models.dart';
import '../katana/katana_header.dart';
import '../katana/katana_nav.dart';
import '../katana/katana_theme.dart';

/// Dedicated Manga Celestia Downloads Screen: lets Clair and Khent manage
/// and read offline manga chapters and pages with the full native reader UI.
class KatanaDownloadsScreen extends StatelessWidget {
  final bool embed;

  const KatanaDownloadsScreen({super.key, this.embed = false});

  @override
  Widget build(BuildContext context) {
    final offlineService = context.watch<OfflineMediaService>();
    final mangaDownloads = offlineService.mangaItems;

    final content = ColoredBox(
      color: KatanaColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
        children: [
          _buildHeader(context, offlineService, mangaDownloads.length),
          const SizedBox(height: 16),
          if (mangaDownloads.isEmpty)
            _buildEmptyState(context)
          else ...[
            _buildStorageSummary(context, offlineService),
            const SizedBox(height: 20),
            ..._buildGroupedDownloads(context, offlineService, mangaDownloads),
          ],
        ],
      ),
    );

    if (embed) return content;

    return Scaffold(
      backgroundColor: KatanaColors.background,
      body: Column(
        children: [
          const KatanaHeader(active: KatanaNav.downloads),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    OfflineMediaService service,
    int count,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(
                Icons.download_for_offline_rounded,
                color: KatanaColors.accent,
                size: 26,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Downloads',
                  style: AppTypography.outfitHeading.copyWith(
                    color: KatanaColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: KatanaColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: KatanaColors.border),
                  ),
                  child: Text(
                    '$count',
                    style: AppTypography.outfitHeading.copyWith(
                      color: KatanaColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (count > 0)
          TextButton.icon(
            onPressed: () => _confirmClearAll(context, service),
            icon: const Icon(
              Icons.delete_sweep_outlined,
              color: KatanaColors.textLight,
              size: 18,
            ),
            label: Text(
              'Clear All',
              style: AppTypography.outfitHeading.copyWith(
                color: KatanaColors.textLight,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStorageSummary(
    BuildContext context,
    OfflineMediaService service,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: KatanaColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: KatanaColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: KatanaColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.offline_pin_rounded,
              color: KatanaColors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Ready',
                  style: AppTypography.outfitHeading.copyWith(
                    color: KatanaColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Read downloaded manga chapters offline without internet',
                  style: AppTypography.outfitHeading.copyWith(
                    color: KatanaColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            service.formattedTotalStorage,
            style: AppTypography.outfitHeading.copyWith(
              color: KatanaColors.orange,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedDownloads(
    BuildContext context,
    OfflineMediaService service,
    List<OfflineMediaItem> items,
  ) {
    // Group manga chapters by manga slug / title
    final series = <String, List<OfflineMediaItem>>{};

    for (final item in items) {
      series.putIfAbsent(item.title, () => []).add(item);
    }

    final widgets = <Widget>[];

    for (final entry in series.entries) {
      widgets.add(_buildMangaSeriesCard(context, service, entry.key, entry.value));
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }

  Widget _buildMangaSeriesCard(
    BuildContext context,
    OfflineMediaService service,
    String title,
    List<OfflineMediaItem> chapters,
  ) {
    chapters.sort((a, b) {
      final aCh = double.tryParse(a.chapterId ?? '0') ?? 0;
      final bCh = double.tryParse(b.chapterId ?? '0') ?? 0;
      return aCh.compareTo(bCh);
    });

    final first = chapters.first;

    return Container(
      decoration: BoxDecoration(
        color: KatanaColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: KatanaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: SizedBox(
                    width: 48,
                    height: 70,
                    child: _buildCoverThumb(first.coverUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.outfitHeading.copyWith(
                          color: KatanaColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${chapters.length} downloaded ${chapters.length == 1 ? "chapter" : "chapters"}',
                        style: AppTypography.outfitHeading.copyWith(
                          color: KatanaColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.menu_book_rounded,
                    color: KatanaColors.accent,
                    size: 28,
                  ),
                  tooltip: 'Read First Chapter',
                  onPressed: () => _readChapter(context, first, chapters),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: KatanaColors.border),
          for (final ch in chapters) _buildChapterRow(context, service, ch, chapters),
        ],
      ),
    );
  }

  Widget _buildChapterRow(
    BuildContext context,
    OfflineMediaService service,
    OfflineMediaItem item,
    List<OfflineMediaItem> allChapters,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KatanaColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: KatanaColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: KatanaColors.border),
            ),
            child: Text(
              'CH ${item.chapterId ?? "1"}',
              style: AppTypography.outfitHeading.copyWith(
                color: KatanaColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subtitle.isNotEmpty
                      ? item.subtitle
                      : 'Chapter ${item.chapterId ?? "1"}',
                  style: AppTypography.outfitHeading.copyWith(
                    color: KatanaColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.formattedSize} • ${item.pageUrls.isNotEmpty ? "${item.pageUrls.length} pages" : "Ready"}',
                  style: AppTypography.outfitHeading.copyWith(
                    color: KatanaColors.textLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.auto_stories_rounded,
              color: KatanaColors.text,
              size: 20,
            ),
            tooltip: 'Read chapter',
            onPressed: () => _readChapter(context, item, allChapters),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: KatanaColors.textLight,
              size: 20,
            ),
            tooltip: 'Delete download',
            onPressed: () => service.deleteDownload(item.id),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverThumb(String url) {
    if (url.isEmpty || (!url.startsWith('http') && !url.startsWith('assets/'))) {
      return Container(
        color: KatanaColors.surfaceAlt,
        child: const Center(
          child: Icon(
            Icons.menu_book_rounded,
            color: KatanaColors.textLight,
            size: 24,
          ),
        ),
      );
    }
    return AppNetworkImage(imageUrl: url, fit: BoxFit.cover);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: KatanaColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: KatanaColors.border),
              ),
              child: const Icon(
                Icons.file_download_outlined,
                size: 48,
                color: KatanaColors.textLight,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Offline Manga Chapters Downloaded Yet',
              style: AppTypography.outfitHeading.copyWith(
                color: KatanaColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download manga chapters and volumes to read them offline anytime without internet.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitHeading.copyWith(
                color: KatanaColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => pushHome(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: KatanaColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: Text(
                'Explore Manga Celestia',
                style: AppTypography.outfitHeading.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _readChapter(
    BuildContext context,
    OfflineMediaItem item,
    List<OfflineMediaItem> allChapters,
  ) {
    final chapters = allChapters.map((ch) {
      return KatanaChapter(
        id: ch.chapterId ?? '1',
        num: ch.chapterId ?? '1',
        title: ch.subtitle,
      );
    }).toList();

    pushReader(
      context,
      slug: item.mediaId,
      chapterId: item.chapterId ?? '1',
      chapters: chapters,
      mangaTitle: item.title,
      coverUrl: item.coverUrl,
    );
  }

  void _confirmClearAll(BuildContext context, OfflineMediaService service) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KatanaColors.surface,
        title: Text(
          'Clear Manga Downloads',
          style: AppTypography.outfitHeading.copyWith(
            color: KatanaColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to remove all offline manga chapters from this device?',
          style: AppTypography.outfitHeading.copyWith(
            color: KatanaColors.textMuted,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.outfitHeading.copyWith(
                color: KatanaColors.textLight,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KatanaColors.accent,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              service.clearAll(type: OfflineMediaType.manga);
            },
            child: Text(
              'Clear',
              style: AppTypography.outfitHeading.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
