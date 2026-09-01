import 'package:flutter/material.dart';

/// Dusk Petal v2 — Formal color token system.
///
/// All colors in the app MUST reference these tokens.
/// Never use ad-hoc `Color(0x...)` literals in widgets.
///
/// Design principles (from aesthetic-web skill):
/// - Tinted neutrals (never pure #000 or #FFF)
/// - One accent ≤10% of any screen
/// - Atmospheric, never flat
class AppColors {
  AppColors._();

  // ── Base palette (Dusk Petal) ──────────────────────────────
  static const Color twilight = Color(0xFF1A1A2E); // bg base
  static const Color velvet = Color(
    0xFF2D1B33,
  ); // elevated surface, gradient mid
  static const Color roseQuartz = Color(
    0xFFF4C2C2,
  ); // primary text on dark, soft accent
  static const Color deepRose = Color(
    0xFFC2185B,
  ); // primary accent (≤10% of screen)
  static const Color blushGold = Color(
    0xFFE8D5B7,
  ); // tertiary accent, value numerals
  static const Color petalWhite = Color(0xFFFFF5F5); // high-emphasis text base
  static const Color softLavender = Color(0xFFD4B5D6); // secondary accent
  static const Color moonlight = Color(
    0xFFF0E6FF,
  ); // glass tint, borders, dividers
  static const Color warmAmber = Color(0xFFF0A500); // warning / doodle accent

  // ── Extended palette (Everglow v6 UI refresh) ─────────────────────────────
  static const Color auroraRose = Color(0xFFFF6F91); // vivid rose glow
  static const Color auroraGold = Color(0xFFF5C97B); // warm candle gold
  static const Color auroraLilac = Color(0xFFB79CED); // twilight violet
  static const Color auroraTeal = Color(0xFF7EE8D2); // quiet teal pop
  static const Color inkDeep = Color(0xFF100A1C); // deepest night bg
  static const Color plum = Color(0xFF3A2352); // elevated violet
  static const Color silk = Color(0xFF2E203E); // soft elevated surface

  // ── Episode drawer / card extras ───────────────────────────
  static const Color deepBlack = Color(0xFF12091A); // episode drawer bg
  static const Color mutedPurple = Color(0xFF8A7A92); // muted secondary text

  // Cinema detail (enhanced drawer) accents
  static const Color cinemaMatch = Color(0xFF7ED69A); // match-score green
  static const Color cinemaOrange = Color(0xFFFF6D00); // watching accent
  static const Color cinemaPink = Color(0xFFE91E8C); // Clair accent
  static const Color cinemaGreen = Color(0xFF2E7D32); // watched accent
  static const Color cinemaAmber = Color(0xFFFF9800); // both-watching accent
  static const Color cinemaBlue = Color(0xFF1976D2); // Khent watched accent

  // Ranking / hover accents (shared shelf widgets)
  static const Color rankGold = warmAmber; // #1 tile accent
  static const Color rankSilver = Color(0xFFB0BEC5); // #2 tile accent
  static const Color rankBronze = Color(0xFFBF8040); // #3 tile accent
  static const Color hoverSurface = Color(0xFF141418); // hover preview panel

  // Interactive rose states (pressed/gradient stops of deepRose)
  static const Color rosePressed = Color(0xFF8E1444);
  static const Color roseDark = Color(0xFF6B0F2A);
  static const Color roseDepths = Color(0xFF7A2442);

  // Gold accents (auroraGold shadows and pressed stops)
  static const Color goldShadow = Color(0xFF6B4E00);

  // Cool leaderboard ranks (jukebox insights)
  static const Color rankSilverCool = Color(0xFFB9BBFF);
  static const Color rankBronzeWarm = Color(0xFFE8A87C);

  // Cinema sidebar text + blush gradient tint
  static const Color cinemaTextDim = Color(0xFFB9A9C2);
  static const Color blushTint = Color(0xFFFFE4EC);

  // Vibrant accent (flower painters, category markers)
  static const Color accentPink = Color(0xFFE91E63);

  // Scrim overlays (alpha-carrying; use as-is, not with withValues)
  static const Color scrimLight = Color(0x33000000);
  static const Color scrimMedium = Color(0x59000000);
  static const Color scrimStrong = Color(0x66000000);

  // ── Semantic colors ────────────────────────────────────────
  static const Color success = Color(0xFF4ADE80); // online presence
  static const Color error = Color(0xFFE5739B); // on-palette rose-red
  static const Color warning = warmAmber;
  static const Color info = softLavender;

  // ── Surface hierarchy ──────────────────────────────────────
  static const Color surface = twilight;
  static const Color surfaceElevated = velvet;

  /// Glass fill — moonlight at 12% opacity.
  static Color get surfaceGlass => moonlight.withValues(alpha: 0.12);

  /// Frosted panel fill used on cards over rich gradients.
  static Color get panelGlass => inkDeep.withValues(alpha: 0.62);

  /// Softer glass for hover/reveal states.
  static Color get glassSoft => moonlight.withValues(alpha: 0.08);

  // ── Text roles (verified ≥4.5:1 on twilight) ──────────────
  // NOTE: Executor MUST run `dart run tool/contrast_check.dart` after
  // Phase 6 to verify every pair. Bump alpha upward where a pair fails.

  /// Headings, primary text — petalWhite @ 0.95
  static Color get textHigh => petalWhite.withValues(alpha: 0.95);

  /// Body text — petalWhite @ 0.82 (≥4.5:1 on twilight #1A1A2E)
  static Color get textMedium => petalWhite.withValues(alpha: 0.82);

  /// Secondary/muted text — roseQuartz @ 0.72
  static Color get textMuted => roseQuartz.withValues(alpha: 0.76);

  /// Disabled text — petalWhite @ 0.40
  static Color get textDisabled => petalWhite.withValues(alpha: 0.52);

  // ── Borders & dividers ─────────────────────────────────────

  /// Standard card/dialog border — moonlight @ 0.18
  static Color get border => moonlight.withValues(alpha: 0.18);

  /// Hairline divider — moonlight @ 0.18
  static Color get divider => moonlight.withValues(alpha: 0.18);

  // ── Glow accents (for boxShadow) ───────────────────────────
  static Color get glowRose => deepRose.withValues(alpha: 0.35);
  static Color get glowGold => blushGold.withValues(alpha: 0.30);
  static Color get glowLavender => softLavender.withValues(alpha: 0.28);

  // ── Shimmer skeleton tones ─────────────────────────────────
  static const Color shimmerBase = Color(0xFF1C1228);
  static const Color shimmerHighlight = Color(0xFF2A1F3A);

  // ── Anime palette (vibrant, energetic — used by AnimeScreen) ───
  static const Color animeBackground = Color(0xFF080810);
  static const Color animeCard = Color(0xFF1C1228);
  static const Color animeRose = Color(0xFFF4C2C2);
  static const Color animeDeepRose = Color(0xFFC2185B);
  static const Color animeGold = Color(0xFFE8C97A);
  static const Color animeWhite = Color(0xFFFFF5F5);
  static const Color animeMuted = Color(0xFF8A7A92);
  static const Color animeCyan = Color(0xFF00BCD4);
  static const Color animeMagenta = Color(0xFFFF2D55);
  static const Color animeElectricPurple = Color(0xFF7C3AED);
  static const Color animeVibrantPink = Color(0xFFFF4081);
}
