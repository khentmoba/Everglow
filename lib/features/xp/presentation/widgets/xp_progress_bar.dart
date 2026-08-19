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
    final currentLevelXp = progress.xpTotal % 1000;
    final remaining = 1000 - currentLevelXp;
    final progressPercent = (currentLevelXp / 1000).clamp(0.0, 1.0);

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.velvet.withValues(alpha: 0.88),
            AppColors.inkDeep.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: AppRadius.radiusXl,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkDeep.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.deepRose.withValues(alpha: 0.10),
            blurRadius: 24,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 14,
            right: 14,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.blushGold.withValues(alpha: 0.30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppTheme.roseGoldGradient,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.deepRose.withValues(alpha: 0.35),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LEVEL ${progress.level}',
                          style: AppTypography.outfitHeading.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$currentLevelXp / 1000 XP',
                        style: AppTypography.outfitHeading.copyWith(
                          color: AppColors.petalWhite.withValues(alpha: 0.92),
                          fontSize: 12.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$remaining XP to level ${progress.level + 1}',
                        style: AppTypography.outfitBold.copyWith(
                          color: AppColors.blushGold.withValues(alpha: 0.72),
                          fontSize: 10,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fillW = constraints.maxWidth * progressPercent;
                  return SizedBox(
                    height: 14,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 10,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.moonlight.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.moonlight.withValues(
                                alpha: 0.10,
                              ),
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          height: 10,
                          width: fillW,
                          decoration: BoxDecoration(
                            gradient: AppTheme.roseGoldGradient,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.deepRose.withValues(
                                  alpha: 0.40,
                                ),
                                blurRadius: 12,
                              ),
                              BoxShadow(
                                color: AppColors.auroraGold.withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: (fillW - 7).clamp(0.0, constraints.maxWidth - 14),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Colors.white, AppColors.blushGold],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.9),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.auroraGold.withValues(
                                    alpha: 0.65,
                                  ),
                                  blurRadius: 10,
                                ),
                                BoxShadow(
                                  color: AppColors.deepRose.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.deepRose.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
