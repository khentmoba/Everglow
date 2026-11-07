import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/offline_media/offline_media_item.dart';
import '../../../../../core/services/offline_media/offline_media_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/widgets/app_network_image.dart';
import '../../../data/models/media_item.dart';
import '../netflix/netflix_colors.dart';
import '../netflix/netflix_nav_bar.dart';

/// Dedicated Cinema Downloads tab: lets Clair and Khent manage and play
/// offline movies and multi-episode TV series natively in the PWA.
class CinemaDownloadsTab extends StatelessWidget {
  final void Function(MediaItem) onPlayMedia;
  final VoidCallback onBrowseCinema;

  const CinemaDownloadsTab({
    super.key,
    required this.onPlayMedia,
    required this.onBrowseCinema,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = cinemaTopContentInset(context);
    final offlineService = context.watch<OfflineMediaService>();
    final cinemaDownloads = offlineService.cinemaItems;

    return ColoredBox(
      color: NetflixColors.background,
      child: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 96),
          children: [
            _buildHeader(context, offlineService, cinemaDownloads.length),
            const SizedBox(height: 16),
            if (cinemaDownloads.isEmpty)
              _buildEmptyState(context)
            else ...[
              _buildStorageSummary(context, offlineService),
              const SizedBox(height: 20),
              ..._buildGroupedDownloads(context, offlineService, cinemaDownloads),
            ],
          ],
        ),
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
                color: NetflixColors.accent,
                size: 26,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Downloads',
                  style: AppTypography.outfitHeading.copyWith(
                    color: NetflixColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: NetflixColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: NetflixColors.hairline),
                  ),
                  child: Text(
                    '$count',
                    style: AppTypography.outfitHeading.copyWith(
                      color: NetflixColors.textSecondary,
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
              color: NetflixColors.textMuted,
              size: 18,
            ),
            label: Text(
              'Clear All',
              style: AppTypography.outfitHeading.copyWith(
                color: NetflixColors.textMuted,
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
        color: NetflixColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: NetflixColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cinemaGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.offline_pin_rounded,
              color: AppColors.cinemaGreen,
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
                    color: NetflixColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Watch instantly without Wi-Fi or mobile data',
                  style: AppTypography.outfitHeading.copyWith(
                    color: NetflixColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            service.formattedTotalStorage,
            style: AppTypography.outfitHeading.copyWith(
              color: NetflixColors.gold,
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
    // Group series items by mediaId / title
    final shows = <String, List<OfflineMediaItem>>{};
    final movies = <OfflineMediaItem>[];

    for (final item in items) {
      if (item.type == OfflineMediaType.tv) {
        shows.putIfAbsent(item.title, () => []).add(item);
      } else {
        movies.add(item);
      }
    }

    final widgets = <Widget>[];

    if (shows.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'TV Shows & Series',
            style: AppTypography.outfitHeading.copyWith(
              color: NetflixColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );

      for (final entry in shows.entries) {
        widgets.add(_buildSeriesGroup(context, service, entry.key, entry.value));
        widgets.add(const SizedBox(height: 16));
      }
    }

    if (movies.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text(
            'Movies',
            style: AppTypography.outfitHeading.copyWith(
              color: NetflixColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );

      for (final movie in movies) {
        widgets.add(_buildMovieTile(context, service, movie));
        widgets.add(const SizedBox(height: 10));
      }
    }

    return widgets;
  }

  Widget _buildSeriesGroup(
    BuildContext context,
    OfflineMediaService service,
    String seriesTitle,
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
        color: NetflixColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: NetflixColors.hairline),
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
                    height: 72,
                    child: _buildCoverThumb(first.coverUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seriesTitle,
                        style: AppTypography.outfitHeading.copyWith(
                          color: NetflixColors.textPrimary,
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
                          color: NetflixColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: NetflixColors.accent,
                    size: 32,
                  ),
                  tooltip: 'Play First Episode',
                  onPressed: () => _playItem(context, first),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: NetflixColors.hairline),
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
        border: Border(bottom: BorderSide(color: NetflixColors.hairline)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: NetflixColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: NetflixColors.hairline),
            ),
            child: Text(
              'S${item.season ?? 1} E${item.episode ?? 1}',
              style: AppTypography.outfitHeading.copyWith(
                color: NetflixColors.gold,
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
                    color: NetflixColors.textPrimary,
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
                    color: NetflixColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                if (item.isDownloading) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: item.progress,
                    backgroundColor: NetflixColors.surfaceElevated,
                    valueColor: const AlwaysStoppedAnimation(NetflixColors.accent),
                    minHeight: 3,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.play_arrow_rounded,
              color: NetflixColors.textPrimary,
              size: 22,
            ),
            onPressed: () => _playItem(context, item),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: NetflixColors.textMuted,
              size: 20,
            ),
            onPressed: () => service.deleteDownload(item.id),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieTile(
    BuildContext context,
    OfflineMediaService service,
    OfflineMediaItem item,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NetflixColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: NetflixColors.hairline),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: SizedBox(
              width: 52,
              height: 78,
              child: _buildCoverThumb(item.coverUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.outfitHeading.copyWith(
                    color: NetflixColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.formattedSize}${item.formattedDuration.isNotEmpty ? " • ${item.formattedDuration}" : ""}',
                  style: AppTypography.outfitHeading.copyWith(
                    color: NetflixColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (item.isDownloading) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: item.progress,
                    backgroundColor: NetflixColors.surfaceElevated,
                    valueColor: const AlwaysStoppedAnimation(NetflixColors.accent),
                    minHeight: 3,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.play_circle_fill_rounded,
              color: NetflixColors.accent,
              size: 32,
            ),
            onPressed: () => _playItem(context, item),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: NetflixColors.textMuted,
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
        color: NetflixColors.surfaceElevated,
        child: const Center(
          child: Icon(
            Icons.movie_outlined,
            color: NetflixColors.textMuted,
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
                color: NetflixColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: NetflixColors.hairline),
              ),
              child: const Icon(
                Icons.file_download_outlined,
                size: 48,
                color: NetflixColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Offline Downloads Yet',
              style: AppTypography.outfitHeading.copyWith(
                color: NetflixColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download movies and full seasons of your favorite shows to watch offline anytime on your phone or tablet.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitHeading.copyWith(
                color: NetflixColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onBrowseCinema,
              style: ElevatedButton.styleFrom(
                backgroundColor: NetflixColors.accent,
                foregroundColor: NetflixColors.textPrimary,
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
                'Explore Cinema',
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

  void _playItem(BuildContext context, OfflineMediaItem item) {
    final tmdbId = int.tryParse(item.mediaId) ?? 0;
    final mediaItem = MediaItem(
      id: tmdbId.toString(),
      tmdbId: tmdbId,
      mediaType: item.type == OfflineMediaType.tv ? 'tv' : 'movie',
      title: item.title,
      posterPath: item.coverUrl,
      currentSeason: item.season,
      currentEpisode: item.episode,
      status: 'watching',
      addedAt: item.downloadedAt,
    );
    onPlayMedia(mediaItem);
  }

  void _confirmClearAll(BuildContext context, OfflineMediaService service) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NetflixColors.surface,
        title: Text(
          'Clear Cinema Downloads',
          style: AppTypography.outfitHeading.copyWith(
            color: NetflixColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to remove all offline movies and TV episodes from this device?',
          style: AppTypography.outfitHeading.copyWith(
            color: NetflixColors.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.outfitHeading.copyWith(
                color: NetflixColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NetflixColors.accent,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              service.clearAll(type: OfflineMediaType.movie);
              service.clearAll(type: OfflineMediaType.tv);
            },
            child: Text(
              'Clear',
              style: AppTypography.outfitHeading.copyWith(
                color: NetflixColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
