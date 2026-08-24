import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';

/// Glassmorphic container — token-driven, reduced-motion-aware.
///
/// Replaces the old `GlassContainer`. Uses `BackdropFilter` blur
/// with `AppColors.surfaceGlass` fill and `AppColors.border` border.
/// Blur is disabled when `AppMotion.reduced` is true.
class EverglowGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double? blur;
  final EdgeInsets padding;
  final List<BoxShadow>? boxShadow;
  final Color? borderColor;
  final Color? fillColor;

  const EverglowGlass({
    super.key,
    required this.child,
    this.radius = AppRadius.x2,
    this.blur,
    this.padding = const EdgeInsets.all(20),
    this.boxShadow,
    this.borderColor,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBlur = AppMotion.reduced
        ? 0.0
        : (blur ?? AppTheme.glassBlur);
    final fill = fillColor ?? AppColors.surfaceGlass;
    final border = borderColor ?? AppColors.border;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: effectiveBlur,
            sigmaY: effectiveBlur,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border, width: 1.0),
              boxShadow: boxShadow ?? AppElevation.e2,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
