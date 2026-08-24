import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_motion.dart';

/// Unified dialog base — velvet bg, blushGold border, scale-in.
///
/// Replaces ad-hoc `Dialog`/`AlertDialog` usage. Reduced-motion → fade only.
class EverglowDialog extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets padding;

  const EverglowDialog({
    super.key,
    required this.child,
    this.radius = AppRadius.x2,
    this.padding = const EdgeInsets.all(24),
  });

  /// Show the dialog with scale-in animation (or fade when reduced).
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    double radius = AppRadius.x2,
    EdgeInsets padding = const EdgeInsets.all(24),
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dialog',
      barrierColor: Colors.black54,
      transitionDuration: AppMotion.orZero(AppMotion.page),
      transitionBuilder: (ctx, a1, a2, widget) {
        if (AppMotion.reduced) {
          return FadeTransition(opacity: a1, child: widget);
        }
        final curved = CurvedAnimation(
          parent: a1,
          curve: AppMotion.easeOutExpo,
        );
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: a1, child: widget),
        );
      },
      pageBuilder: (_, _, _) =>
          EverglowDialog(radius: radius, padding: padding, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Semantics(
        label: 'Dialog',
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.velvet,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.2),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
