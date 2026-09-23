import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/system/app_update_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Wraps the whole app and displays a warm, gentle notification banner when
/// [AppUpdateService] detects that a new build is downloaded and ready.
///
/// The app never restarts forcefully on its own:
/// - Users can tap "Restart" to apply the update immediately.
/// - Users can tap the close button to dismiss the notification and reload
///   manually on their own time without any interruptions.
class AppUpdatePrompt extends StatelessWidget {
  final Widget child;
  final AppUpdateService? service;

  const AppUpdatePrompt({super.key, required this.child, this.service});

  @override
  Widget build(BuildContext context) {
    if (service != null) {
      return ChangeNotifierProvider<AppUpdateService>.value(
        value: service!,
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

    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
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
                  const Text('✨', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'A fresh Everglow update is ready',
                      style: AppTypography.bodyMedium().copyWith(
                        color: AppColors.petalWhite,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: service.applyNow,
                    child: Text(
                      'Restart',
                      style: AppTypography.bodyMedium().copyWith(
                        color: AppColors.blushGold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // No Tooltip here: this banner lives in MaterialApp.builder,
                  // above Navigator/Overlay, where Tooltip crashes on hover
                  // with "No Overlay widget found" and squeezes the Row
                  // into vertical text + a 340px tall slab. Semantics keeps
                  // the screen-reader label without needing an Overlay.
                  Semantics(
                    button: true,
                    label: 'Dismiss update notification',
                    child: IconButton(
                      onPressed: service.dismiss,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.petalWhite,
                      ),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
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
