import 'package:flutter/material.dart';
import 'package:everglow/features/xp/domain/models/user_progress.dart';
import 'package:everglow/core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

class XPProgressBar extends StatelessWidget {
  final UserProgress progress;

  const XPProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    // Each level is 1000 XP
    final currentLevelXp = progress.xpTotal % 1000;
    final progressPercent = (currentLevelXp / 1000).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LEVEL ${progress.level}',
              style: AppTypography.outfitHeading.copyWith(
                color: AppTheme.blushGold,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            Text(
              '$currentLevelXp / 1000 XP',
              style: AppTypography.outfitHeading.copyWith(
                color: AppTheme.roseQuartz.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Background track
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.moonlight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                // Progress fill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 1000),
                  height: 10,
                  width: constraints.maxWidth * progressPercent,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.deepRose, AppTheme.blushGold],
                    ),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.deepRose.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        ),
      ],
    );
  }
}
