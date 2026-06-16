import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Motion tokens shared across the four inside screens. The custom
/// curves follow Emil Kowalski's "strong ease" pattern — they feel
/// snappier than Flutter's built-in `Curves.easeOut` because the
/// initial velocity is higher and the deceleration is steeper.
class ShelfMotion {
  /// Strong ease-out for hover, press, and micro-interactions.
  /// Equivalent to CSS `cubic-bezier(0.23, 1, 0.32, 1)`.
  static const Curve easeOutStrong = Cubic(0.23, 1.0, 0.32, 1.0);

  /// Slow ease-out-expo for entrance reveals. Equivalent to
  /// `cubic-bezier(0.16, 1, 0.3, 1)`.
  static const Curve easeOutExpo = Cubic(0.16, 1.0, 0.3, 1.0);

  /// iOS-like drawer/sheet curve for modal-bottom-sheets.
  /// Equivalent to `cubic-bezier(0.32, 0.72, 0, 1)`.
  static const Curve drawer = Cubic(0.32, 0.72, 0.0, 1.0);

  /// Standard interaction duration. Sits in the 150-250ms band
  /// recommended for hover/press feedback (motion-craft).
  static const Duration fast = Duration(milliseconds: 160);

  /// Slightly longer for tile lifts and section reveals.
  static const Duration medium = Duration(milliseconds: 220);

  /// Page transition and hero swap duration.
  static const Duration page = Duration(milliseconds: 320);

  /// Whether the user has reduced-motion enabled. When true, callers
  /// should snap to their target state instead of animating.
  static bool get reduced => AppTheme.shouldReduceMotion;

  /// Returns [duration] or zero depending on the user's motion
  /// preference — drop this in front of every `AnimatedContainer` /
  /// `AnimatedScale` to honor `prefers-reduced-motion`.
  static Duration orZero(Duration duration) =>
      reduced ? Duration.zero : duration;
}
