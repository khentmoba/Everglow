import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Dusk Petal v2 — Elevation / shadow token system.
///
/// Provides a cohesive shadow scale using deep black + romantic
/// glow accents (deepRose, blushGold, softLavender).
class AppElevation {
  AppElevation._();

  // ── Black shadow scale ─────────────────────────────────────

  static const List<BoxShadow> e1 = [
    BoxShadow(blurRadius: 8,  offset: Offset(0, 2),  color: Color(0x33000000)),
  ];
  static const List<BoxShadow> e2 = [
    BoxShadow(blurRadius: 16, offset: Offset(0, 6),  color: Color(0x40000000)),
  ];
  static const List<BoxShadow> e3 = [
    BoxShadow(blurRadius: 24, offset: Offset(0, 10), color: Color(0x4D000000)),
  ];
  static const List<BoxShadow> e4 = [
    BoxShadow(blurRadius: 32, offset: Offset(0, 14), color: Color(0x59000000)),
  ];

  // ── Romantic glow accents ──────────────────────────────────

  static List<BoxShadow> get glowRose => [
    BoxShadow(blurRadius: 24, color: AppColors.glowRose),
  ];
  static List<BoxShadow> get glowGold => [
    BoxShadow(blurRadius: 18, color: AppColors.glowGold),
  ];
  static List<BoxShadow> get glowLavender => [
    BoxShadow(blurRadius: 18, color: AppColors.glowLavender),
  ];

  // ── Combo: card default (e2 + subtle glow) ────────────────

  static List<BoxShadow> get card => [
    ...e2,
    BoxShadow(blurRadius: 16, color: AppColors.glowRose),
  ];

  // ── Combo: floating element (e3 + glow) ────────────────────

  static List<BoxShadow> get floating => [
    ...e3,
    BoxShadow(blurRadius: 24, color: AppColors.glowRose),
  ];
}
