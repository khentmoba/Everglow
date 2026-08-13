import 'package:flutter/material.dart';
import '../../domain/models/user_progress.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

class XPProgressBar extends StatelessWidget {
  final UserProgress progress;

  const XPProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    // Each level is 1000 XP
    final currentLevelXp = progress.xpTotal % 1000;
    final progressPercent = (currentLevelXp / 1000).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.moonlight.withValues(alpha: 0.10),
            AppColors.inkDeep.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkDeep.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.roseGoldGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.deepRose.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      size: 15,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'LEVEL ${progress.level}',
                    style: AppTypography.outfitHeading.copyWith(
                      color: AppColors.auroraGold,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                    ),
                  ),
                ],
              ),
              Text(
                '$currentLevelXp / 1000 XP',
                style: AppTypography.outfitHeading.copyWith(
                  color: AppColors.roseQuartz.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Background track
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.moonlight.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.moonlight.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  // Progress fill
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 1000),
                    height: 12,
                    width: constraints.maxWidth * progressPercent,
                    decoration: BoxDecoration(
                      gradient: AppTheme.roseGoldGradient,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.deepRose.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: AppColors.auroraGold.withValues(alpha: 0.35),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                  // Leading spark
                  Positioned(
                    left: (constraints.maxWidth * progressPercent).clamp(
                      0.0,
                      constraints.maxWidth - 16,
                    ),
                    child: Container(
                      width: 16,
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: AppTheme.roseGoldGradient,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.auroraGold.withValues(alpha: 0.7),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
