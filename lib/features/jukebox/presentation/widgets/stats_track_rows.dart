import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/music_status.dart';
import '../../data/models/top_music_track.dart';
import '../../data/models/lastfm_image_utils.dart';
import 'listen_along_popup.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'stats_fx.dart';

class TopTrackRow extends StatelessWidget {
  final TopMusicTrack track;
  final String username;
  final int maxPlays;
  final bool isPink;

  const TopTrackRow({
    super.key,
    required this.track,
    required this.username,
    required this.maxPlays,
    this.isPink = false,
  });

  bool get _isPodium => track.rank <= 3;

  Color get _podiumColor {
    if (isPink) {
      return switch (track.rank) {
        1 => AppColors.cinemaPink,
        2 => AppColors.roseQuartz,
        3 => AppColors.softLavender,
        _ => AppColors.auroraRose,
      };
    }
    return switch (track.rank) {
      1 => AppColors.auroraGold,
      2 => AppColors.rankSilverCool,
      3 => AppColors.rankBronzeWarm,
      _ => AppColors.blushGold,
    };
  }

  @override
  Widget build(BuildContext context) {
    final rowCore = SizedBox(
      height: _isPodium ? 66 : 62,
      child: Row(
        children: [
          _RankBadge(rank: track.rank, isPink: isPink),
          const SizedBox(width: AppSpacing.md),
          _PodiumArtwork(imageUrl: track.imageUrl, rank: track.rank, isPink: isPink),
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
                        track.trackName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitHeading.copyWith(
                          fontSize: _isPodium ? 15.5 : 14.5,
                          height: 1.15,
                          color: AppColors.petalWhite,
                          shadows: _isPodium
                              ? [
                                  Shadow(
                                    color: _podiumColor.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                    if (_isPodium) ...[
                      const SizedBox(width: 6),
                      _PodiumTag(rank: track.rank, isPink: isPink),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitMedium.copyWith(
                    fontSize: 12.5,
                    height: 1.15,
                    color: _isPodium
                        ? AppColors.petalWhite.withValues(alpha: 0.88)
                        : AppColors.textMedium,
                  ),
                ),
                if (_isPodium) ...[
                  const SizedBox(height: 6),
                  _PlayBar(
                    fraction: (track.playCount / (maxPlays == 0 ? 1 : maxPlays))
                        .clamp(0.08, 1.0),
                    color: _podiumColor,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _PlayCountPill(
            playCount: track.playCount,
            color: _podiumColor,
            isPodium: _isPodium,
            isPink: isPink,
          ),
        ],
      ),
    );

    final row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openTrack(context),
      child: rowCore,
    );

    if (!_isPodium) return row;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isPink
                  ? switch (track.rank) {
                      1 => [
                        AppColors.cinemaPink.withValues(alpha: 0.22),
                        AppColors.deepRose.withValues(alpha: 0.20),
                        AppColors.inkDeep.withValues(alpha: 0.32),
                      ],
                      2 => [
                        AppColors.roseQuartz.withValues(alpha: 0.20),
                        AppColors.plum.withValues(alpha: 0.22),
                        AppColors.inkDeep.withValues(alpha: 0.30),
                      ],
                      3 => [
                        AppColors.softLavender.withValues(alpha: 0.20),
                        const Color(0xFF5B2A4A).withValues(alpha: 0.20),
                        AppColors.inkDeep.withValues(alpha: 0.28),
                      ],
                      _ => [Colors.transparent, Colors.transparent],
                    }
                  : switch (track.rank) {
                      1 => [
                        AppColors.auroraGold.withValues(alpha: 0.22),
                        AppColors.goldShadow.withValues(alpha: 0.22),
                        AppColors.inkDeep.withValues(alpha: 0.35),
                      ],
                      2 => [
                        const Color(0xFFD8D6F0).withValues(alpha: 0.22),
                        const Color(0xFF3A3566).withValues(alpha: 0.22),
                        AppColors.inkDeep.withValues(alpha: 0.32),
                      ],
                      3 => [
                        AppColors.rankBronzeWarm.withValues(alpha: 0.22),
                        const Color(0xFF6B3A14).withValues(alpha: 0.22),
                        AppColors.inkDeep.withValues(alpha: 0.30),
                      ],
                      _ => [Colors.transparent, Colors.transparent],
                    },
            ),
            border: Border.all(
              color: _podiumColor.withValues(alpha: 0.48),
              width: 1.25,
            ),
            boxShadow: [
              BoxShadow(
                color: _podiumColor.withValues(
                  alpha: track.rank == 1 ? 0.28 : 0.18,
                ),
                blurRadius: track.rank == 1 ? 22 : 16,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: StatsShimmer(color: _podiumColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: row,
              ),
            ],
          ),
        ),
        if (track.rank == 1)
          Positioned(
            top: -6,
            right: 8,
            child: StatsSparkleBadge(color: _podiumColor),
          ),
      ],
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

class _PodiumTag extends StatelessWidget {
  final int rank;
  final bool isPink;
  const _PodiumTag({required this.rank, this.isPink = false});
  @override
  Widget build(BuildContext context) {
    final c = isPink
        ? switch (rank) {
            1 => AppColors.cinemaPink,
            2 => AppColors.roseQuartz,
            3 => AppColors.softLavender,
            _ => AppColors.auroraRose,
          }
        : switch (rank) {
            1 => AppColors.auroraGold,
            2 => AppColors.rankSilverCool,
            3 => AppColors.rankBronzeWarm,
            _ => AppColors.blushGold,
          };
    final label = switch (rank) {
      1 => '#1',
      2 => '#2',
      3 => '#3',
      _ => '#$rank',
    };
    final extra = rank == 1 ? ' TOP' : '';
    final icon = switch (rank) {
      1 => Icons.emoji_events_rounded,
      2 => Icons.workspace_premium_rounded,
      3 => Icons.military_tech_rounded,
      _ => Icons.star_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: 0.48)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          const SizedBox(width: 3),
          Text(
            '$label$extra',
            style: AppTypography.outfitBold.copyWith(
              fontSize: 8,
              color: c,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayBar extends StatelessWidget {
  final double fraction;
  final Color color;
  const _PlayBar({required this.fraction, required this.color});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.petalWhite.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        FractionallySizedBox(
          widthFactor: fraction,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.95),
                  color.withValues(alpha: 0.45),
                ],
              ),
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayCountPill extends StatelessWidget {
  final int playCount;
  final Color color;
  final bool isPodium;
  final bool isPink;
  const _PlayCountPill({
    required this.playCount,
    required this.color,
    required this.isPodium,
    this.isPink = false,
  });
  @override
  Widget build(BuildContext context) {
    if (!isPodium) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            NumberFormat.decimalPattern().format(playCount),
            style: AppTypography.cormorantHeading.copyWith(
              fontSize: 18,
              height: 1.0,
              color: isPink ? AppColors.roseQuartz : AppColors.blushGold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            playCount == 1 ? 'play' : 'plays',
            style: AppTypography.outfitMedium.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isPink ? AppColors.roseQuartz.withValues(alpha: 0.72) : AppColors.textMuted,
              letterSpacing: 1.3,
            ),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.40)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 14),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            NumberFormat.decimalPattern().format(playCount),
            style: AppTypography.cormorantHeading.copyWith(
              fontSize: 15,
              height: 1.0,
              color: color,
              shadows: [
                Shadow(color: color.withValues(alpha: 0.35), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            playCount == 1 ? 'play' : 'plays',
            style: AppTypography.outfitMedium.copyWith(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.85),
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumArtwork extends StatelessWidget {
  final String? imageUrl;
  final int rank;
  final bool isPink;
  const _PodiumArtwork({this.imageUrl, required this.rank, this.isPink = false});
  @override
  Widget build(BuildContext context) {
    final isPodium = rank <= 3;
    final borderColor = isPink
        ? switch (rank) {
            1 => AppColors.cinemaPink.withValues(alpha: 0.90),
            2 => AppColors.roseQuartz.withValues(alpha: 0.75),
            3 => AppColors.softLavender.withValues(alpha: 0.75),
            _ => AppColors.moonlight.withValues(alpha: 0.14),
          }
        : switch (rank) {
            1 => AppColors.auroraGold.withValues(alpha: 0.90),
            2 => const Color(0xFFD8D6F0).withValues(alpha: 0.75),
            3 => AppColors.rankBronzeWarm.withValues(alpha: 0.75),
            _ => AppColors.moonlight.withValues(alpha: 0.14),
          };
    final size = isPodium ? 50.0 : 46.0;
    final art = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: AppRadius.radiusMd,
        color: AppColors.velvet,
        border: Border.all(color: borderColor, width: isPodium ? 1.6 : 1),
        boxShadow: isPodium
            ? [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.38),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.radiusMd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Builder(
              builder: (_) {
                final url = cleanLastfmImageUrl(imageUrl);
                if (url == null) return const _ArtworkFallback();
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  cacheWidth: 200,
                  errorBuilder: (c, e, s) => const _ArtworkFallback(),
                );
              },
            ),
            if (isPodium)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.petalWhite.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (!isPodium) return art;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        art,
        Positioned(
          top: -7,
          right: -7,
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isPink
                    ? switch (rank) {
                        1 => [AppColors.blushTint, AppColors.cinemaPink],
                        2 => [AppColors.blushTint, AppColors.roseQuartz],
                        3 => [AppColors.moonlight, AppColors.softLavender],
                        _ => [AppColors.petalWhite, AppColors.petalWhite],
                      }
                    : switch (rank) {
                        1 => [const Color(0xFFFFF3B0), AppColors.auroraGold],
                        2 => [const Color(0xFFF0F0FF), const Color(0xFFB8B9D6)],
                        3 => [const Color(0xFFFFD7B5), const Color(0xFFC47A3A)],
                        _ => [AppColors.petalWhite, AppColors.petalWhite],
                      },
              ),
              border: Border.all(
                color: AppColors.petalWhite.withValues(alpha: 0.85),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.55),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              switch (rank) {
                1 => Icons.emoji_events_rounded,
                2 => Icons.workspace_premium_rounded,
                3 => Icons.military_tech_rounded,
                _ => Icons.star_rounded,
              },
              size: 11,
              color: isPink
                  ? (rank == 1 ? AppColors.roseDark : const Color(0xFF2A2340))
                  : (rank == 1 ? AppColors.goldShadow : const Color(0xFF2A2340)),
            ),
          ),
        ),
      ],
    );
  }
}

class RecentTrackRow extends StatelessWidget {
  final MusicStatus status;

  const RecentTrackRow({super.key, required this.status});

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
  final bool isPink;
  const _RankBadge({required this.rank, this.isPink = false});
  @override
  Widget build(BuildContext context) {
    if (rank <= 3) return _PodiumBadge(rank: rank, isPink: isPink);
    if (isPink) {
      return Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.auroraRose.withValues(alpha: 0.10),
          border: Border.all(
            color: AppColors.auroraRose.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Text(
          '$rank',
          style: AppTypography.cormorantHeading.copyWith(
            fontSize: 16,
            height: 1.0,
            color: AppColors.roseQuartz,
          ),
        ),
      );
    }
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.moonlight.withValues(alpha: 0.08),
        border: Border.all(
          color: AppColors.textMuted.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Text(
        '$rank',
        style: AppTypography.cormorantHeading.copyWith(
          fontSize: 16,
          height: 1.0,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _PodiumBadge extends StatelessWidget {
  final int rank;
  final bool isPink;
  const _PodiumBadge({required this.rank, this.isPink = false});
  @override
  Widget build(BuildContext context) {
    final (Color glow, List<Color> grad, IconData icon) = isPink
        ? switch (rank) {
            1 => (
              AppColors.cinemaPink,
              [AppColors.blushTint, const Color(0xFFFF8FAB), AppColors.cinemaPink],
              Icons.favorite_rounded,
            ),
            2 => (
              AppColors.roseQuartz,
              [AppColors.petalWhite, AppColors.roseQuartz, const Color(0xFFB76B8A)],
              Icons.favorite_rounded,
            ),
            3 => (
              AppColors.softLavender,
              [AppColors.moonlight, AppColors.softLavender, const Color(0xFF8A5A8A)],
              Icons.favorite_rounded,
            ),
            _ => (AppColors.auroraRose, [AppColors.petalWhite, AppColors.petalWhite], Icons.star_rounded),
          }
        : switch (rank) {
            1 => (
              AppColors.auroraGold,
              [const Color(0xFFFFF6CC), AppColors.auroraGold, const Color(0xFFC49A2B)],
              Icons.emoji_events_rounded,
            ),
            2 => (
              AppColors.rankSilverCool,
              [AppColors.petalWhite, const Color(0xFFD8D6F0), const Color(0xFF9A98C2)],
              Icons.workspace_premium_rounded,
            ),
            3 => (
              AppColors.rankBronzeWarm,
              [const Color(0xFFFFE0C2), AppColors.rankBronzeWarm, const Color(0xFF8B5A2B)],
        Icons.military_tech_rounded,
      ),
      _ => (
        AppColors.blushGold,
        [AppColors.petalWhite, AppColors.petalWhite],
        Icons.star_rounded,
      ),
    };
    final size = rank == 1 ? 36.0 : 34.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: grad,
        ),
        border: Border.all(
          color: AppColors.petalWhite.withValues(alpha: 0.72),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.55),
            blurRadius: rank == 1 ? 16 : 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.inkDeep.withValues(alpha: 0.35),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF2A2340)),
          Text(
            '$rank',
            style: AppTypography.cormorantHeading.copyWith(
              fontSize: 11,
              height: 0.9,
              color: const Color(0xFF2A2340),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
