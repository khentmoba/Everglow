import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';

/// Anniversary counter tile — distilled heirloom.
///
/// Keeps romance, drops weight: warm gradient wash, single shadow,
/// calm gold numeral with a soft candle shadow. The live seconds tile
/// gets a tiny rose dot so Clair can see it ticking, without pulsing
/// the whole card.
class MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final bool animate;
  final bool pulse;
  final bool isLive;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.animate = false,
    this.pulse = false,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isLive
        ? AppColors.auroraRose.withValues(alpha: 0.26)
        : AppColors.moonlight.withValues(alpha: 0.12);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.silk.withValues(alpha: 0.92),
            AppColors.velvet.withValues(alpha: 0.94),
          ],
        ),
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkDeep.withValues(alpha: 0.36),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          if (isLive)
            BoxShadow(
              color: AppColors.auroraRose.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Stack(
        children: [
          // Hairline — single, warm, no glow even for seconds
          Positioned(
            top: 0,
            left: 20,
            right: 20,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.blushGold.withValues(
                      alpha: isLive ? 0.45 : 0.34,
                    ),
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
                      color: AppColors.auroraGold.withValues(alpha: 0.98),
                      fontSize: 37,
                      height: 1.0,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color: AppColors.goldShadow.withValues(alpha: 0.38),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  width: 20,
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.blushGold.withValues(alpha: 0.42),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLive) ...[
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.auroraRose,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label.toUpperCase(),
                      style: AppTypography.outfitHeading.copyWith(
                        color: AppColors.roseQuartz.withValues(alpha: 0.74),
                        fontSize: 9.5,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
