import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/music_status.dart';
import '../../data/models/top_music_track.dart';
import '../providers/music_stats_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import 'stats_leaderboard_header.dart';
import 'stats_track_rows.dart';

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
              color: AppColors.moonlight.withValues(alpha: 0.10),
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
                totalPlays: provider.khentTotalPlays,
                isLeader: provider.isKhentLeader,
              ),
              const SizedBox(height: AppSpacing.x2),
              const _SectionDivider(),
              const SizedBox(height: AppSpacing.x2),
              _MusicStatsBlock(
                displayName: 'Clair',
                username: provider.clairUsername,
                topTracks: provider.clairTopTracks,
                recentTracks: provider.clairRecentTracks,
                totalPlays: provider.clairTotalPlays,
                isLeader: provider.isClairLeader,
                isClair: true,
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
  final int totalPlays;
  final bool isLeader;
  final bool isClair;

  const _MusicStatsBlock({
    required this.displayName,
    required this.username,
    required this.topTracks,
    required this.recentTracks,
    required this.totalPlays,
    required this.isLeader,
    this.isClair = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LeaderboardHeader(
          displayName: displayName,
          username: username,
          totalPlays: totalPlays,
          isLeader: isLeader,
          isClair: isClair,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (topTracks.isEmpty)
          const _EmptyStats()
        else
          Builder(
            builder: (context) {
              final maxPlays = topTracks.isEmpty
                  ? 1
                  : topTracks
                        .map((t) => t.playCount)
                        .reduce((a, b) => a > b ? a : b);
              return Column(
                children: [
                  for (var i = 0; i < topTracks.length; i++) ...[
                    TopTrackRow(
                      track: topTracks[i],
                      username: username,
                      maxPlays: maxPlays,
                      isPink: isClair,
                    ),
                    if (i != topTracks.length - 1)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: topTracks[i].rank <= 3 ? 7 : 0,
                        ),
                        child: const _Hairline(),
                      ),
                  ],
                ],
              );
            },
          ),
        const SizedBox(height: AppSpacing.x2),
        const _SectionDivider(),
        const SizedBox(height: AppSpacing.x2),
        _SectionHeader(
          icon: Icons.history_rounded,
          title: 'Recently Heard',
          subtitle: "$username's latest 5 scrobbles",
          isPink: isClair,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (recentTracks.isEmpty)
          const _EmptyStats()
        else
          for (var i = 0; i < recentTracks.length; i++) ...[
            RecentTrackRow(status: recentTracks[i]),
            if (i != recentTracks.length - 1) const _Hairline(),
          ],
      ],
    );
    if (!isClair) return content;
    // Clair gets a subtle rose-pink card so her board is instantly distinct.
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.auroraRose.withValues(alpha: 0.06),
        border: Border.all(
          color: AppColors.auroraRose.withValues(alpha: 0.14),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.auroraRose.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPink;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isPink = false,
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
              colors: isPink
                  ? [
                      AppColors.auroraRose.withValues(alpha: 0.20),
                      AppColors.cinemaPink.withValues(alpha: 0.10),
                    ]
                  : [
                      AppColors.blushGold.withValues(alpha: 0.18),
                      AppColors.blushGold.withValues(alpha: 0.05),
                    ],
            ),
            border: Border.all(
              color: isPink
                  ? AppColors.auroraRose.withValues(alpha: 0.45)
                  : AppColors.blushGold.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isPink ? AppColors.auroraRose : AppColors.blushGold,
          ),
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
                  color: isPink ? AppColors.auroraRose : AppColors.blushGold,
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
            const Row(
              children: [
                EverglowSkeleton(width: 46, height: 46, radius: 14),
                SizedBox(width: AppSpacing.md),
                Expanded(
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
                SizedBox(width: AppSpacing.md),
                EverglowSkeleton(width: 46, height: 11, radius: 5),
              ],
            ),
            if (i != 3) const SizedBox(height: 15),
          ],
        ],
      ),
    );
  }
}
