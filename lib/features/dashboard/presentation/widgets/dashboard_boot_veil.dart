import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';

/// Full-screen loading veil shown once per app session while the dashboard
/// finishes its cold-start load after login.
///
/// Matches the web splash (`web/index.html`) and the gateway reveal copy —
/// heart, `EVERGLOW`, thin bar, `loading your story…` — so going from the
/// door to the dashboard feels like one continuous loading screen instead
/// of a half-built site assembling in front of Clair.
///
/// The veil is purely visual: it fades out via [visible] and ignores input
/// once hidden. It never blocks dismissal on its own — [DashboardScreen]
/// owns the timing (auth ready + garden settled + minimum warmth, with a
/// safety timeout so Clair is never trapped behind it).
class DashboardBootVeil extends StatelessWidget {
  const DashboardBootVeil({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: AppMotion.orZero(const Duration(milliseconds: 600)),
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
            label: 'Loading your story',
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 120,
                    child: AppMotion.reduced
                        ? Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.blushGold.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: const LinearProgressIndicator(
                              minHeight: 2,
                              backgroundColor: Color(0x26F5EFE6),
                              valueColor: AlwaysStoppedAnimation<Color>(
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
