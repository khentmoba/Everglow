import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/music_status.dart';
import '../../data/models/top_music_track.dart';
import '../providers/music_stats_provider.dart';
import 'listen_along_popup.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/shared/widgets/everglow/everglow_skeleton.dart';

/// Dashboard music stats for Khent only: an all-time top-10 leaderboard
/// followed by the five most recent scrobbles.
///
/// Sits directly below the "vibing to" cards. Clair's stats are not
/// included here for now.
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.velvet.withValues(alpha: 0.72),
                AppColors.inkDeep.withValues(alpha: 0.72),
              ],
            ),
            borderRadius: AppRadius.radiusX2,
            border: Border.all(
              color: AppColors.moonlight.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: Icons.leaderboard_rounded,
                title: "Khent's Top 10",
                subtitle: 'Most listened all-time',
              ),
              const SizedBox(height: 14),
              if (provider.topTracks.isEmpty)
                const _EmptyStats()
              else
                for (var i = 0; i < provider.topTracks.length; i++) ...[
                  _TopTrackRow(
                    track: provider.topTracks[i],
                    username: provider.username,
                  ),
                  if (i != provider.topTracks.length - 1)
                    const _Hairline(),
                ],
              const SizedBox(height: 20),
              const _Hairline(),
              const SizedBox(height: 20),
              const _SectionHeader(
                icon: Icons.history_rounded,
                title: 'Recently Heard',
                subtitle: "Khent's latest scrobbles",
              ),
              const SizedBox(height: 14),
              if (provider.recentTracks.isEmpty)
                const _EmptyStats()
              else
                for (var i = 0; i < provider.recentTracks.length; i++) ...[
                  _RecentTrackRow(
                    status: provider.recentTracks[i],
                    isLatest: i == 0,
                  ),
                  if (i != provider.recentTracks.length - 1)
                    const _Hairline(),
                ],
            ],
          ),
        );
      },
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.moonlight.withValues(alpha: 0.10),
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 17, color: AppColors.blushGold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 15,
                  color: AppColors.blushGold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 11,
                  color: AppColors.petalWhite.withValues(alpha: 0.6),
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
        height: 56,
        child: Row(
          children: [
            _RankBadge(rank: track.rank),
            const SizedBox(width: 12),
            _TrackArtwork(imageUrl: track.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.trackName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 12,
                      color: AppColors.petalWhite.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat.decimalPattern().format(track.playCount),
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 13,
                    color: AppColors.blushGold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.playCount == 1 ? 'play' : 'plays',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 10,
                    color: AppColors.petalWhite.withValues(alpha: 0.5),
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
  final bool isLatest;

  const _RecentTrackRow({required this.status, required this.isLatest});

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
        height: 56,
        child: Row(
          children: [
            _TrackArtwork(imageUrl: status.imageUrl),
            const SizedBox(width: 12),
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
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.petalWhite,
                          ),
                        ),
                      ),
                      if (isLive) ...[
                        const SizedBox(width: 8),
                        const _LiveBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 12,
                      color: AppColors.petalWhite.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _timeLabel(),
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 11,
                color: isLive
                    ? AppColors.warmAmber
                    : AppColors.petalWhite.withValues(alpha: 0.55),
              ),
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
      1 => (
        AppColors.auroraGold,
        AppColors.auroraGold.withValues(alpha: 0.16),
      ),
      2 => (
        AppColors.auroraRose,
        AppColors.auroraRose.withValues(alpha: 0.14),
      ),
      3 => (
        AppColors.softLavender,
        AppColors.softLavender.withValues(alpha: 0.14),
      ),
      _ => (
        AppColors.petalWhite.withValues(alpha: 0.55),
        AppColors.moonlight.withValues(alpha: 0.08),
      ),
    };

    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: Border.all(
          color: color.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Text(
        '$rank',
        style: AppTypography.outfitBold.copyWith(
          fontSize: 12,
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
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: AppRadius.radiusMd,
        color: AppColors.velvet,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.radiusMd,
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const _ArtworkFallback(),
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
        size: 20,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warmAmber.withValues(alpha: 0.14),
        borderRadius: AppRadius.radiusXs,
        border: Border.all(
          color: AppColors.warmAmber.withValues(alpha: 0.5),
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
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: AppTypography.outfitBold.copyWith(
              fontSize: 8,
              color: AppColors.warmAmber,
              letterSpacing: 1.0,
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
      color: AppColors.moonlight.withValues(alpha: 0.12),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.moonlight.withValues(alpha: 0.06),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.graphic_eq_rounded,
            size: 26,
            color: AppColors.roseQuartz,
          ),
          const SizedBox(height: 8),
          Text(
            'No music stats yet',
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 13,
              color: AppColors.petalWhite.withValues(alpha: 0.6),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.velvet.withValues(alpha: 0.72),
            AppColors.inkDeep.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: AppRadius.radiusX2,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EverglowSkeleton(width: 170, height: 18, radius: 8),
          const SizedBox(height: 16),
          for (var i = 0; i < 4; i++) ...[
            Row(
              children: [
                const EverglowSkeleton(width: 44, height: 44, radius: 14),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EverglowSkeleton(
                        width: double.infinity,
                        height: 12,
                        radius: 6,
                      ),
                      SizedBox(height: 8),
                      EverglowSkeleton(width: 120, height: 10, radius: 5),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const EverglowSkeleton(width: 46, height: 10, radius: 5),
              ],
            ),
            if (i != 3) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
