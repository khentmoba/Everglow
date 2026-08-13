import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';

/// Anniversary counter tile: gradient glass, gold numeral, accent hairline.
class MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final bool animate;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.velvet.withValues(alpha: 0.85),
            AppColors.inkDeep.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: AppRadius.radiusX2,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.16),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkDeep.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.deepRose.withValues(alpha: 0.12),
            blurRadius: 22,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top accent hairline.
          Positioned(
            top: 0,
            left: 18,
            right: 18,
            child: Container(
              height: 1.4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.auroraGold.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.orZero(const Duration(milliseconds: 320)),
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: AppMotion.easeOutExpo,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: ScaleTransition(
                        scale: Tween(begin: 1.15, end: 1.0).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    value.toString().padLeft(2, '0'),
                    key: ValueKey<int>(value),
                    style: AppTypography.cormorantExtraBold.copyWith(
                      color: AppColors.auroraGold,
                      fontSize: 40,
                      height: 1.0,
                      shadows: [
                        BoxShadow(
                          color: AppColors.auroraGold.withValues(alpha: 0.55),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label.toUpperCase(),
                  style: AppTypography.labelMedium().copyWith(
                    color: AppColors.roseQuartz.withValues(alpha: 0.75),
                    fontSize: 11,
                    letterSpacing: 2.2,
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
