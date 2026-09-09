import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/next_episode.dart';

/// Netflix-style Up Next card shown over the player when the current
/// episode is almost over.
///
/// Shows "Next episode in {secondsLeft}..." with a countdown bar, the
/// next episode's season/episode (and title when TMDB knows it), plus
/// "Play now" and "Cancel" actions. Pure UI — the player owns the timer.
class UpNextOverlay extends StatelessWidget {
  final NextEpisode next;
  final int secondsLeft;
  final int totalSeconds;
  final VoidCallback onPlayNow;
  final VoidCallback onCancel;

  const UpNextOverlay({
    super.key,
    required this.next,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.onPlayNow,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds <= 0
        ? 0.0
        : (secondsLeft / totalSeconds).clamp(0.0, 1.0);
    final title = next.name;
    return Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.deepRose.withValues(alpha: 0.55),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepRose.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.deepRose, AppColors.auroraRose],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  'UP NEXT',
                  style: AppTypography.outfitBold.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onCancel,
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            next.label,
            style: AppTypography.outfitHeading.copyWith(
              color: AppColors.roseQuartz,
              fontSize: 14,
            ),
          ),
          if (title != null && title.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.textMedium,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Next episode in $secondsLeft...',
            style: AppTypography.outfitWhite.copyWith(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Container(
              height: 4,
              color: Colors.white.withValues(alpha: 0.12),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.deepRose, AppColors.blushGold],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onPlayNow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.deepRose, AppColors.auroraRose],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Play now',
                          style: AppTypography.outfitBold.copyWith(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.moonlight.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.moonlight.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: AppTypography.outfitBold.copyWith(
                      color: AppColors.textMedium,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small persistent pill over the player corner so Clair can jump to the
/// next episode any time — no backing out to the episode list.
///
/// Shown for TV episodes whenever a next episode exists, even on
/// providers that never report playback position (where the auto
/// countdown can't trigger on its own).
class NextEpisodeButton extends StatelessWidget {
  final NextEpisode next;
  final VoidCallback onTap;

  const NextEpisodeButton({
    super.key,
    required this.next,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.inkDeep.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: AppColors.deepRose.withValues(alpha: 0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepRose.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.skip_next_rounded,
              color: AppColors.roseQuartz,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Next: ${next.label}',
              style: AppTypography.outfitBold.copyWith(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
