import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/system/app_update_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Wraps the whole app and shows a warm "fresh version" banner when
/// [AppUpdateService] has a new build downloaded and ready.
///
/// The switch itself is automatic: background tabs reload silently, tabs in
/// use count down a few seconds first. The banner is just the visible face
/// of that — "Switch now" hurries it, "Later" snoozes it for 30 minutes.
class AppUpdatePrompt extends StatelessWidget {
  final Widget child;

  const AppUpdatePrompt({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppUpdateService()..start(),
      child: Stack(
        children: [
          child,
          const Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: 92,
            child: _UpdateBanner(),
          ),
        ],
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AppUpdateService>();
    if (!service.updateAvailable) return const SizedBox.shrink();
    final countdown = service.countdownSeconds;
    final message = countdown != null
        ? 'A fresh Everglow just landed — switching in ${countdown}s…'
        : 'A fresh Everglow is ready — it’ll switch when you step away.';
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        borderRadius: AppRadius.radiusLg,
        color: AppColors.deepRose,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              const Text('💗', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyMedium().copyWith(
                    color: AppColors.petalWhite,
                  ),
                ),
              ),
              TextButton(
                onPressed: service.applyNow,
                child: Text(
                  'Switch now',
                  style: AppTypography.bodyMedium().copyWith(
                    color: AppColors.blushGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: service.snooze,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.petalWhite,
                ),
                tooltip: 'Later',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
