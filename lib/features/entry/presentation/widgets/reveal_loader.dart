import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';

/// Streaming 0→100% loader shown while the gateway door swings open.
///
/// Mirrors the dashboard veil's look (heart, EVERGLOW, big percent,
/// determinate bar, warm status line) so the handoff from the gateway to
/// the dashboard — where the veil reports the real load percent — feels
/// like one continuous stream instead of two different spinners.
///
/// Timed, not signal-driven: the door reveal lasts ~1100ms, so the count
/// lands on 100% just as the dashboard veil takes over.
class GatewayRevealLoader extends StatelessWidget {
  const GatewayRevealLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.orZero(const Duration(milliseconds: 1000)),
      builder: (context, value, _) {
        final percent = '${(value * 100).round()}%';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite_rounded,
              color: AppColors.auroraRose,
              size: 26,
            ),
            const SizedBox(height: 10),
            Text(
              'EVERGLOW',
              style: TextStyle(
                color: AppColors.petalWhite.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 4.0,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              percent,
              style: TextStyle(
                color: AppColors.petalWhite.withValues(alpha: 0.9),
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  value: value,
                  backgroundColor: const Color(0x26F5EFE6),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.blushGold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'loading your story…',
              style: TextStyle(
                color: AppColors.petalWhite.withValues(alpha: 0.45),
                fontSize: 10,
                letterSpacing: 0.3,
              ),
            ),
          ],
        );
      },
    );
  }
}
