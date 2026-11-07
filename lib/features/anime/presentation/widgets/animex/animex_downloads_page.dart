import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/offline_media/offline_media_item.dart';
import '../../../../../core/services/offline_media/offline_media_service.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/widgets/app_network_image.dart';
import '../../../../cinema/data/models/media_item.dart';
import 'animex_controller.dart';
import 'animex_footer.dart';
import 'animex_tokens.dart';

/// Dedicated Anime Downloads section: lets Clair and Khent manage and play
/// downloaded anime episodes across seasons offline in the PWA.
class AnimeXDownloadsPage extends StatelessWidget {
  final AnimeXController controller;

  const AnimeXDownloadsPage({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final offlineService = context.watch<OfflineMediaService>();
    final animeDownloads = offlineService.animeItems;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AnimeXTokens.desktopNavBreakpoint;

    return ColoredBox(
      color: AnimeXTokens.bg,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 32 : 16,
          24,
          isDesktop ? 32 : 16,
          AnimeXTokens.mobileNavHeight + 32,
        ),
        children: [
          _buildHeader(context, offlineService, animeDownloads.length),
          const SizedBox(height: 16),
          if (animeDownloads.isEmpty)
            _buildEmptyState(context)
          else ...[
            _buildStorageSummary(context, offlineService),
            const SizedBox(height: 20),
            ..._buildGroupedDownloads(context, offlineService, animeDownloads),
          ],
          const SizedBox(height: 48),
          AnimeXFooter(controller: controller),
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
                color: AnimeXTokens.accent,
                size: 26,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Downloads',
                  style: AppTypography.outfitHeading.copyWith(
                    color: AnimeXTokens.textPrimary,
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
                    color: AnimeXTokens.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: AnimeXTokens.border),
                  ),
                  child: Text(
                    '$count',
                    style: AppTypography.outfitHeading.copyWith(
                      color: AnimeXTokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
                child: Text(
                  '$count',
                  style: AppTypography.outfitHeading.copyWith(
                    color: AnimeXTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (count > 0)
          TextButton.icon(
            onPressed: () => _confirmClearAll(context, service),
            icon: const Icon(
              Icons.delete_sweep_outlined,
              color: AnimeXTokens.textMuted,
              size: 18,
            ),
            label: Text(
              'Clear All',
              style: AppTypography.outfitHeading.copyWith(
                color: AnimeXTokens.textMuted,
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
        color: AnimeXTokens.surface,
        borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
        border: Border.all(color: AnimeXTokens.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AnimeXTokens.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
            ),
            child: const Icon(
              Icons.offline_pin_rounded,
              color: AnimeXTokens.success,
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
                    color: AnimeXTokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Watch downloaded anime episodes without internet connection',
                  style: AppTypography.outfitHeading.copyWith(
                    color: AnimeXTokens.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            service.formattedTotalStorage,
            style: AppTypography.outfitHeading.copyWith(
              color: AnimeXTokens.gold,
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
    // Group anime episodes by series title
    final series = <String, List<OfflineMediaItem>>{};

    for (final item in items) {
      series.putIfAbsent(item.title, () => []).add(item);
    }

    final widgets = <Widget>[];

    for (final entry in series.entries) {
      widgets.add(_buildAnimeSeriesCard(context, service, entry.key, entry.value));
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }

  Widget _buildAnimeSeriesCard(
    BuildContext context,
    OfflineMediaService service,
    String title,
    List<OfflineMediaItem> episodes,
  ) {
    episodes.sort((a, b) {
      final s = (a.season ?? 0).compareTo(b.season ?? 0);
      if (s != 0) return s;
      return (a.episode ?? 0).compareTo(b.episode ?? 0);
    });

    final first = episodes.first;

    return Container(
      decoration: BoxDecoration(
        color: AnimeXTokens.surface,
        borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
        border: Border.all(color: AnimeXTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
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
                          color: AnimeXTokens.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${episodes.length} downloaded ${episodes.length == 1 ? "episode" : "episodes"}',
                        style: AppTypography.outfitHeading.copyWith(
                          color: AnimeXTokens.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: AnimeXTokens.accent,
                    size: 32,
                  ),
                  tooltip: 'Play First Episode',
                  onPressed: () => _playEpisode(context, first),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AnimeXTokens.border),
          for (final ep in episodes) _buildEpisodeRow(context, service, ep),
        ],
      ),
    );
  }

  Widget _buildEpisodeRow(
    BuildContext context,
    OfflineMediaService service,
    OfflineMediaItem item,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AnimeXTokens.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AnimeXTokens.surfaceRaised,
              borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
              border: Border.all(color: AnimeXTokens.border),
            ),
            child: Text(
              'EP ${item.episode ?? 1}',
              style: AppTypography.outfitHeading.copyWith(
                color: AnimeXTokens.gold,
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
                      : 'Episode ${item.episode ?? 1}',
                  style: AppTypography.outfitHeading.copyWith(
                    color: AnimeXTokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.formattedSize}${item.formattedDuration.isNotEmpty ? " • ${item.formattedDuration}" : ""}',
                  style: AppTypography.outfitHeading.copyWith(
                    color: AnimeXTokens.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.play_arrow_rounded,
              color: AnimeXTokens.textPrimary,
              size: 22,
            ),
            onPressed: () => _playEpisode(context, item),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AnimeXTokens.textMuted,
              size: 20,
            ),
            onPressed: () => service.deleteDownload(item.id),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverThumb(String url) {
    if (url.isEmpty || (!url.startsWith('http') && !url.startsWith('assets/'))) {
      return Container(
        color: AnimeXTokens.surfaceRaised,
        child: const Center(
          child: Icon(
            Icons.animation_rounded,
            color: AnimeXTokens.textMuted,
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
                color: AnimeXTokens.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AnimeXTokens.border),
              ),
              child: const Icon(
                Icons.file_download_outlined,
                size: 48,
                color: AnimeXTokens.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Offline Anime Downloaded Yet',
              style: AppTypography.outfitHeading.copyWith(
                color: AnimeXTokens.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download anime episodes and seasons to watch them offline anytime on your phone or tablet.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitHeading.copyWith(
                color: AnimeXTokens.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => controller.goTo(AnimexPage.home),
              style: ElevatedButton.styleFrom(
                backgroundColor: AnimeXTokens.accent,
                foregroundColor: AnimeXTokens.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
                ),
              ),
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: Text(
                'Explore Anime',
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

  void _playEpisode(BuildContext context, OfflineMediaItem item) {
    final anilistId = int.tryParse(item.mediaId) ?? 0;
    final mediaItem = MediaItem(
      id: item.mediaId,
      tmdbId: anilistId,
      anilistId: anilistId,
      title: item.title,
      mediaType: 'tv',
      posterPath: item.coverUrl,
      currentSeason: item.season ?? 1,
      currentEpisode: item.episode ?? 1,
      status: 'watching',
      addedAt: item.downloadedAt,
      isAnime: true,
    );
    controller.openWatch(mediaItem, episode: item.episode ?? 1);
  }

  void _confirmClearAll(BuildContext context, OfflineMediaService service) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AnimeXTokens.surface,
        title: Text(
          'Clear Anime Downloads',
          style: AppTypography.outfitHeading.copyWith(
            color: AnimeXTokens.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to remove all offline anime episodes from this device?',
          style: AppTypography.outfitHeading.copyWith(
            color: AnimeXTokens.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.outfitHeading.copyWith(
                color: AnimeXTokens.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AnimeXTokens.accent,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              service.clearAll(type: OfflineMediaType.anime);
            },
            child: Text(
              'Clear',
              style: AppTypography.outfitHeading.copyWith(
                color: AnimeXTokens.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
