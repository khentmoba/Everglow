import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';

/// Anniversary counter tile: editorial glass, big gold numeral, heirloom details.
class MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final bool animate;
  final bool pulse;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.animate = false,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.velvet.withValues(alpha: 0.96),
            AppColors.inkDeep.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: AppRadius.radiusX2,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.14),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkDeep.withValues(alpha: 0.55),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.auroraGold.withValues(alpha: 0.08),
            blurRadius: 28,
            spreadRadius: -12,
          ),
        ],
      ),
      child: Stack(
        children: [
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
                    AppColors.blushGold.withValues(alpha: pulse ? 0.85 : 0.55),
                    Colors.transparent,
                  ],
                ),
                boxShadow: pulse
                    ? [
                        BoxShadow(
                          color: AppColors.blushGold.withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 2,
            child: IgnorePointer(
              child: Text(
                value.toString().padLeft(2, '0'),
                style: AppTypography.cormorantBlackWhite.copyWith(
                  fontSize: 56,
                  height: 1.0,
                  letterSpacing: -1.5,
                  color: AppColors.petalWhite.withValues(alpha: 0.06),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.055),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (pulse)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.auroraRose,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.auroraRose.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    AnimatedSwitcher(
                      duration: AppMotion.orZero(
                        const Duration(milliseconds: 360),
                      ),
                      transitionBuilder: (child, animation) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: AppMotion.easeOutExpo,
                        );
                        return FadeTransition(
                          opacity: curved,
                          child: ScaleTransition(
                            scale: Tween(begin: 1.18, end: 1.0).animate(curved),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        value.toString().padLeft(2, '0'),
                        key: ValueKey<int>(value),
                        style: AppTypography.cormorantExtraBold.copyWith(
                          color: pulse
                              ? AppColors.petalWhite
                              : AppColors.auroraGold,
                          fontSize: pulse ? 36 : 42,
                          height: 1.0,
                          letterSpacing: -1.2,
                          shadows: [
                            BoxShadow(
                              color: (pulse
                                      ? AppColors.auroraRose
                                      : AppColors.auroraGold)
                                  .withValues(alpha: 0.45),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: 22,
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.blushGold.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label.toUpperCase(),
                  style: AppTypography.outfitHeading.copyWith(
                    color: AppColors.roseQuartz.withValues(alpha: 0.72),
                    fontSize: 10,
                    letterSpacing: 2.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
