import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/music_status.dart';
import '../../data/models/top_music_track.dart';
import '../../data/models/lastfm_image_utils.dart';
import '../providers/music_stats_provider.dart';
import 'listen_along_popup.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';

/// Dashboard music stats for both people: each user's all-time top-10
/// leaderboard followed by their five most recent scrobbles.
class MusicStatsSection extends StatelessWidget {
  const MusicStatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicStatsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && !provider.hasData) {
          return const _MusicStatsSkeleton();
        }

        return Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.velvet.withValues(alpha: 0.86),
                AppColors.inkDeep.withValues(alpha: 0.88),
              ],
            ),
            borderRadius: AppRadius.radiusX2,
            border: Border.all(
              color: AppColors.moonlight.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MusicStatsBlock(
                displayName: 'Khent',
                username: provider.username,
                topTracks: provider.topTracks,
                recentTracks: provider.recentTracks,
              ),
              const SizedBox(height: AppSpacing.x2),
              const _SectionDivider(),
              const SizedBox(height: AppSpacing.x2),
              _MusicStatsBlock(
                displayName: 'Clair',
                username: provider.clairUsername,
                topTracks: provider.clairTopTracks,
                recentTracks: provider.clairRecentTracks,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MusicStatsBlock extends StatelessWidget {
  final String displayName;
  final String username;
  final List<TopMusicTrack> topTracks;
  final List<MusicStatus> recentTracks;

  const _MusicStatsBlock({
    required this.displayName,
    required this.username,
    required this.topTracks,
    required this.recentTracks,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.leaderboard_rounded,
          title: "$displayName's Top 10",
          subtitle: '$username · most listened all-time',
        ),
        const SizedBox(height: AppSpacing.lg),
        if (topTracks.isEmpty)
          const _EmptyStats()
        else
          for (var i = 0; i < topTracks.length; i++) ...[
            _TopTrackRow(track: topTracks[i], username: username),
            if (i != topTracks.length - 1) const _Hairline(),
          ],
        const SizedBox(height: AppSpacing.x2),
        const _SectionDivider(),
        const SizedBox(height: AppSpacing.x2),
        _SectionHeader(
          icon: Icons.history_rounded,
          title: 'Recently Heard',
          subtitle: "$username's latest 5 scrobbles",
        ),
        const SizedBox(height: AppSpacing.lg),
        if (recentTracks.isEmpty)
          const _EmptyStats()
        else
          for (var i = 0; i < recentTracks.length; i++) ...[
            _RecentTrackRow(status: recentTracks[i]),
            if (i != recentTracks.length - 1) const _Hairline(),
          ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.blushGold.withValues(alpha: 0.18),
                AppColors.blushGold.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 18, color: AppColors.blushGold),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cormorantBoldWhite.copyWith(
                  fontSize: 21,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitMedium.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blushGold,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopTrackRow extends StatelessWidget {
  final TopMusicTrack track;
  final String username;

  const _TopTrackRow({required this.track, required this.username});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openTrack(context),
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            _RankBadge(rank: track.rank),
            const SizedBox(width: AppSpacing.md),
            _TrackArtwork(imageUrl: track.imageUrl),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.trackName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 15,
                      height: 1.15,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitMedium.copyWith(
                      fontSize: 12.5,
                      height: 1.15,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat.decimalPattern().format(track.playCount),
                  style: AppTypography.cormorantHeading.copyWith(
                    fontSize: 18,
                    height: 1.0,
                    color: AppColors.blushGold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  track.playCount == 1 ? 'play' : 'plays',
                  style: AppTypography.outfitMedium.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openTrack(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ListenAlongPopup(
        status: MusicStatus(
          username: username,
          trackName: track.trackName,
          artistName: track.artistName,
          albumName: 'No Album',
          imageUrl: track.imageUrl,
          isPlaying: false,
          spotifyUrl: track.spotifyUrl,
        ),
      ),
    );
  }
}

class _RecentTrackRow extends StatelessWidget {
  final MusicStatus status;

  const _RecentTrackRow({required this.status});

  @override
  Widget build(BuildContext context) {
    final bool isLive = status.isPlaying;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showDialog(
        context: context,
        builder: (context) => ListenAlongPopup(status: status),
      ),
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            _TrackArtwork(imageUrl: status.imageUrl),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          status.trackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitHeading.copyWith(
                            fontSize: 15,
                            height: 1.15,
                            color: AppColors.petalWhite,
                          ),
                        ),
                      ),
                      if (isLive) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const _LiveBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    status.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitMedium.copyWith(
                      fontSize: 12.5,
                      height: 1.15,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: isLive ? AppColors.warmAmber : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  _timeLabel(),
                  style: AppTypography.outfitMedium.copyWith(
                    fontSize: 11.5,
                    height: 1.0,
                    fontWeight: isLive ? FontWeight.w700 : FontWeight.w500,
                    color: isLive ? AppColors.warmAmber : AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel() {
    if (status.isPlaying) return 'now';
    final timestamp = status.timestamp;
    if (timestamp == null) return 'heard';
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(timestamp);
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final (Color color, Color background) = switch (rank) {
      1 => (AppColors.auroraGold, AppColors.auroraGold.withValues(alpha: 0.18)),
      2 => (AppColors.auroraRose, AppColors.auroraRose.withValues(alpha: 0.16)),
      3 => (
        AppColors.softLavender,
        AppColors.softLavender.withValues(alpha: 0.16),
      ),
      _ => (AppColors.textMuted, AppColors.moonlight.withValues(alpha: 0.08)),
    };

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        '$rank',
        style: AppTypography.cormorantHeading.copyWith(
          fontSize: 16,
          height: 1.0,
          color: color,
        ),
      ),
    );
  }
}

class _TrackArtwork extends StatelessWidget {
  final String? imageUrl;

  const _TrackArtwork({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = cleanLastfmImageUrl(imageUrl);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: AppRadius.radiusMd,
        color: AppColors.velvet,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.radiusMd,
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: 200,
                errorBuilder: (context, error, stack) =>
                    const _ArtworkFallback(),
              )
            : const _ArtworkFallback(),
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.velvet,
      child: const Icon(
        Icons.music_note_rounded,
        size: 21,
        color: AppColors.roseQuartz,
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warmAmber.withValues(alpha: 0.16),
        borderRadius: AppRadius.radiusXs,
        border: Border.all(
          color: AppColors.warmAmber.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.warmAmber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: AppTypography.outfitBold.copyWith(
              fontSize: 8.5,
              color: AppColors.warmAmber,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.moonlight.withValues(alpha: 0.14),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.blushGold.withValues(alpha: 0.28),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.moonlight.withValues(alpha: 0.06),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.graphic_eq_rounded,
            size: 26,
            color: AppColors.roseQuartz,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No music stats yet',
            style: AppTypography.outfitMedium.copyWith(
              fontSize: 13,
              color: AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicStatsSkeleton extends StatelessWidget {
  const _MusicStatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.velvet.withValues(alpha: 0.86),
            AppColors.inkDeep.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: AppRadius.radiusX2,
        border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EverglowSkeleton(width: 170, height: 18, radius: 8),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 4; i++) ...[
            Row(
              children: [
                const EverglowSkeleton(width: 46, height: 46, radius: 14),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EverglowSkeleton(
                        width: double.infinity,
                        height: 13,
                        radius: 6,
                      ),
                      SizedBox(height: 8),
                      EverglowSkeleton(width: 120, height: 11, radius: 5),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const EverglowSkeleton(width: 46, height: 11, radius: 5),
              ],
            ),
            if (i != 3) const SizedBox(height: 15),
          ],
        ],
      ),
    );
  }
}
