import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// Unified snackbar helper.
///
/// Replaces ad-hoc `SnackBar` styling across the app.
/// Usage: `EverglowSnackbar.show(context, 'Message')`.
class EverglowSnackbar {
  EverglowSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.petalWhite),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMedium().copyWith(
                  color: AppColors.petalWhite,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.deepRose,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppColors.blushGold,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}
