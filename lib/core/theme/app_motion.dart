import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Dusk Petal v2 — Motion token system.
///
/// Promotes `ShelfMotion` to app-wide usage. All animations
/// MUST check `AppMotion.reduced` and skip when true.
///
/// Curves follow Emil Kowalski's "strong ease" pattern —
/// snappier than Flutter's built-in `Curves.easeOut`.
class AppMotion {
  AppMotion._();

  // ── Curves ─────────────────────────────────────────────────

  /// Strong ease-out for hover, press, micro-interactions.
  /// CSS `cubic-bezier(0.23, 1, 0.32, 1)`.
  static const Curve easeOutStrong = Cubic(0.23, 1.0, 0.32, 1.0);

  /// Slow ease-out-expo for entrance reveals.
  /// CSS `cubic-bezier(0.16, 1, 0.3, 1)`.
  static const Curve easeOutExpo = Cubic(0.16, 1.0, 0.3, 1.0);

  /// iOS-like drawer/sheet curve.
  /// CSS `cubic-bezier(0.32, 0.72, 0, 1)`.
  static const Curve drawer = Cubic(0.32, 0.72, 0.0, 1.0);

  /// Smooth quint for slide-ins.
  static const Curve easeOutQuint = Cubic(0.22, 1.0, 0.36, 1.0);

  // ── Durations ──────────────────────────────────────────────

  /// 160ms — hover, press feedback.
  static const Duration fast = Duration(milliseconds: 160);

  /// 220ms — toggles, section reveals.
  static const Duration medium = Duration(milliseconds: 220);

  /// 320ms — page transitions.
  static const Duration page = Duration(milliseconds: 320);

  /// 600ms — scroll reveal entrance.
  static const Duration reveal = Duration(milliseconds: 400);

  /// 700ms — carousel slide.
  static const Duration carousel = Duration(milliseconds: 700);

  // ── Reduced-motion ─────────────────────────────────────────

  /// Whether the user has reduced-motion enabled.
  static bool get reduced => AppTheme.shouldReduceMotion;

  /// Returns [duration] or [Duration.zero] depending on the
  /// user's motion preference. Drop in front of every
  /// `AnimatedContainer` / `AnimatedScale` / `TweenAnimationBuilder`.
  static Duration orZero(Duration duration) =>
      reduced ? Duration.zero : duration;

  /// Returns [curve] or [Curves.linear] when reduced.
  static Curve orLinear(Curve curve) => reduced ? Curves.linear : curve;

  // ── Press / hover feedback ─────────────────────────────────

  /// Standard press scale factor.
  static const double pressScale = 0.96;

  /// Standard hover lift (translateY).
  static const double hoverLift = -4.0;

  /// Standard hover scale.
  static const double hoverScale = 1.03;
}
