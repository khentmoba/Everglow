import 'package:flutter/material.dart';

/// Decorative art colors: flower painters, vinyl, weather.
///
/// These are illustration colors, not UI theme colors — they never change
/// with the Dusk Petal theme, so they live here instead of [AppColors].
/// All values are the long-standing painter values, only named.
abstract final class AppArt {
  // ── Shared foliage ──────────────────────────────────────────
  static const Color leaf = Color(0xFF66BB6A);
  static const Color leafLight = Color(0xFF81C784);
  static const Color stem = Color(0xFF4CAF50);
  static const Color stemDark = Color(0xFF388E3C);
  static const Color stemOlive = Color(0xFF558B2F);
  static const Color leafOlive = Color(0xFF7CB342);

  // ── Shared bark ─────────────────────────────────────────────
  static const Color bark = Color(0xFF5D4037);
  static const Color barkLight = Color(0xFF8D6E63);
  static const Color barkDeep = Color(0xFF795548);

  // ── Tulip (blue) ────────────────────────────────────────────
  static const Color tulipPotLight = Color(0xFFB3E5FC);
  static const Color tulipPot = Color(0xFF81D4FA);
  static const Color tulipRim = Color(0xFF4FC3F7);

  // ── Sakura ──────────────────────────────────────────────────
  static const Color sakuraPotLight = Color(0xFFD7CCC8);
  static const Color sakuraPot = Color(0xFFBCAAA4);
  static const Color sakuraPetal = Color(0xFFF8BBD0);

  // ── Rose ────────────────────────────────────────────────────
  static const Color rosePotLight = Color(0xFFE8B4B8);
  static const Color rosePot = Color(0xFFD4899A);
  static const Color roseRim = Color(0xFFC07080);
  static const Color roseBloom = Color(0xFFE57373);
  static const Color roseBud = Color(0xFFEF5350);
  static const Color rosePetalLight = Color(0xFFFFCDD2);

  // ── Sunflower ───────────────────────────────────────────────
  static const Color sunflowerPotLight = Color(0xFFA1887F);
  static const Color sunflowerCenter = Color(0xFF9E9D24);
  static const Color sunflowerPetal = Color(0xFFFFD54F);

  // ── Weather overlay ─────────────────────────────────────────
  static const Color weatherLeaf = Color(0xFFFFB74D);

  // ── Vinyl record ────────────────────────────────────────────
  static const Color vinylEdge = Color(0xFF1E1E1E);
  static const Color vinylCore = Color(0xFF050505);
  static const Color vinylLabel = Color(0xFF8E0E3A);
}
