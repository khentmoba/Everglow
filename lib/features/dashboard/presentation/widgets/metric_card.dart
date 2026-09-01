import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';

/// Anniversary counter tile — distilled.
///
/// Keeps romance, drops weight: smaller numeral, single shadow,
/// no watermark, calmer gold. The live seconds no longer pulses;
/// the whole row reads as a quiet heirloom, not a scoreboard.
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
        color: AppColors.velvet.withValues(alpha: 0.72),
        borderRadius: AppRadius.radiusXl,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkDeep.withValues(alpha: 0.32),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Hairline — single, muted, no glow even for seconds
          Positioned(
            top: 0,
            left: 18,
            right: 18,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.blushGold.withValues(alpha: 0.32),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.orZero(
                    const Duration(milliseconds: 300),
                  ),
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: AppMotion.easeOutExpo,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: ScaleTransition(
                        scale: Tween(begin: 1.08, end: 1.0).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    value.toString().padLeft(2, '0'),
                    key: ValueKey<int>(value),
                    style: AppTypography.cormorantExtraBold.copyWith(
                      color: AppColors.auroraGold.withValues(alpha: 0.96),
                      fontSize: 34,
                      height: 1.0,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 18,
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.blushGold.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label.toUpperCase(),
                  style: AppTypography.outfitHeading.copyWith(
                    color: AppColors.roseQuartz.withValues(alpha: 0.62),
                    fontSize: 9,
                    letterSpacing: 2.2,
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
