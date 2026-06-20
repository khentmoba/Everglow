import 'package:flutter/material.dart';

/// Dusk Petal v2 — Spacing token system (4-pt grid).
///
/// Every spacing value in the app MUST reference these tokens.
/// Never use ad-hoc `SizedBox(height: 24)` literals — use
/// `SizedBox(height: AppSpacing.x2)` instead.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double x2 = 24;
  static const double x3 = 32;
  static const double x4 = 48;
  static const double x5 = 64;
  static const double x6 = 80;

  /// Section padding — responsive: mobile 48, tablet 64, desktop 80.
  /// Use via `AppSpacing.section(context)`.
  static double section(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1024) return x6;
    if (width >= 600) return x5;
    return x4;
  }

  /// Horizontal page padding — responsive: mobile 16, tablet 32, desktop 48.
  static double pageH(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1024) return x4;
    if (width >= 600) return x3;
    return lg;
  }

  // ── Convenience EdgeInsets ─────────────────────────────────

  /// Symmetric horizontal page padding.
  static EdgeInsets pageHorizontal(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: pageH(context));

  /// Symmetric vertical section padding.
  static EdgeInsets sectionVertical(BuildContext context) =>
      EdgeInsets.symmetric(vertical: section(context));

  /// All-around card padding.
  static const EdgeInsets card = EdgeInsets.all(x2);

  /// All-around card padding (compact).
  static const EdgeInsets cardCompact = EdgeInsets.all(lg);
}
