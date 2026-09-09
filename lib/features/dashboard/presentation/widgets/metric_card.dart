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
///
/// [flat] renders the same numeral + label with no card chrome, for use
/// as a cell inside a unified panel (see AnniversaryMetrics grid).
class MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final bool animate;
  final bool pulse;
  final bool isLive;
  final bool flat;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.animate = false,
    this.pulse = false,
    this.isLive = false,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    if (flat) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
        child: _MetricContent(label: label, value: value, isLive: isLive),
      );
    }
    final borderColor = isLive
        ? AppColors.auroraRose.withValues(alpha: 0.35)
        : AppColors.moonlight.withValues(alpha: 0.16);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.moonlight.withValues(alpha: 0.12),
            AppColors.velvet.withValues(alpha: 0.32),
            AppColors.inkDeep.withValues(alpha: 0.45),
          ],
        ),
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          if (isLive)
            BoxShadow(
              color: AppColors.auroraRose.withValues(alpha: 0.16),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Stack(
        children: [
          // Specular hairline highlight
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
                      alpha: isLive ? 0.50 : 0.38,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: _MetricContent(label: label, value: value, isLive: isLive),
          ),
        ],
      ),
    );
  }
}

/// Shared numeral + divider + label. One place so the card and flat
/// cell always tick and read the same way.
class _MetricContent extends StatelessWidget {
  final String label;
  final int value;
  final bool isLive;

  const _MetricContent({
    required this.label,
    required this.value,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
              color: AppColors.auroraGold,
              fontSize: 38,
              height: 1.0,
              letterSpacing: -0.5,
              shadows: [
                Shadow(
                  color: AppColors.auroraGold.withValues(alpha: 0.42),
                  blurRadius: 14,
                  offset: const Offset(0, 1),
                ),
                Shadow(
                  color: AppColors.goldShadow.withValues(alpha: 0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        Container(
          width: 22,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.blushGold.withValues(alpha: 0.48),
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
                decoration: BoxDecoration(
                  color: AppColors.auroraRose,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.auroraRose.withValues(alpha: 0.70),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTypography.outfitHeading.copyWith(
                  color: AppColors.roseQuartz.withValues(alpha: 0.85),
                  fontSize: 9.5,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
