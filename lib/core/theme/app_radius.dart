import 'package:flutter/material.dart';

/// Dusk Petal v2 — Radius token system.
///
/// Every border radius in the app MUST reference these tokens.
/// Never use ad-hoc `BorderRadius.circular(24)` literals.
class AppRadius {
  AppRadius._();

  static const double xs   = 8;   // badges, tooltips
  static const double sm   = 12;  // chips, sub-panels
  static const double md   = 14;  // poster cards, shelf cards
  static const double lg   = 16;  // snackbars, author tags
  static const double xl   = 20;  // empty-state CTA, pill nav
  static const double x2   = 24;  // cards, buttons, hero carousel, dialogs
  static const double x3   = 28;  // pill nav outer
  static const double full = 999; // circular buttons, pills

  // ── Convenience BorderRadius ───────────────────────────────

  static BorderRadius get radiusXs   => BorderRadius.circular(xs);
  static BorderRadius get radiusSm   => BorderRadius.circular(sm);
  static BorderRadius get radiusMd   => BorderRadius.circular(md);
  static BorderRadius get radiusLg   => BorderRadius.circular(lg);
  static BorderRadius get radiusXl   => BorderRadius.circular(xl);
  static BorderRadius get radiusX2   => BorderRadius.circular(x2);
  static BorderRadius get radiusX3   => BorderRadius.circular(x3);
  static BorderRadius get radiusFull => BorderRadius.circular(full);

  // ── Convenience RoundedRectangleBorder ────────────────────

  static RoundedRectangleBorder get shapeX2 => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(x2),
  );
  static RoundedRectangleBorder get shapeXl => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(xl),
  );
  static RoundedRectangleBorder get shapeMd => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(md),
  );
}
