import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import 'dashboard_load_tracker.dart';

/// Full-screen loading veil with a REAL percent, shown briefly on cold
/// start while the dashboard's first screen reports ready.
///
/// Matches the web splash (`web/index.html`) and the gateway reveal copy —
/// heart, `EVERGLOW`, determinate bar, big percent, warm status line — so
/// going from the door to the dashboard feels like one continuous handoff,
/// and Clair always sees how far along her story is instead of an endless
/// spinner.
///
/// The veil is purely visual: it fades out via [visible] and ignores input
/// once hidden. The number is honest — [DashboardLoadTracker.progress]
/// climbs only as each first-screen card reports its own load settled
/// (data, cache, or settled error). [DashboardScreen] owns dismissal:
/// the moment the tracker completes, or a 3s safety net, whichever first.
class DashboardLoadVeil extends StatelessWidget {
  const DashboardLoadVeil({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final progress = context.select<DashboardLoadTracker, double>(
      (t) => t.progress,
    );
    final label = context.select<DashboardLoadTracker, String>(
      (t) => t.currentLabel,
    );
    final percent = '${(progress * 100).round()}%';
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: AppMotion.orZero(const Duration(milliseconds: 500)),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.inkDeep, AppColors.twilight, AppColors.velvet],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: Semantics(
            container: true,
            label: 'Loading your story, $percent',
            child: Center(
              child: Column(
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
                        value: progress,
                        backgroundColor: const Color(0x26F5EFE6),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.blushGold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: AppMotion.orZero(
                      const Duration(milliseconds: 300),
                    ),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      style: TextStyle(
                        color: AppColors.petalWhite.withValues(alpha: 0.45),
                        fontSize: 10,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
