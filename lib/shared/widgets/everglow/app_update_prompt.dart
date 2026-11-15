import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/system/app_update_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

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
