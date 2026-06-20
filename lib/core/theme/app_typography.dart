import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Dusk Petal v2 — Typography token system.
///
/// Pairing: Cormorant Garamond (display/headline) + Outfit (body/UI).
/// Handwritten: Dancing Script + Caveat for romantic notes only.
///
/// Poppins is REMOVED (was off-palette in CreatorModal).
class AppTypography {
  AppTypography._();

  // ── Font family constants ──────────────────────────────────
  static const String display = 'Cormorant Garamond';
  static const String body    = 'Outfit';
  static const String script  = 'Dancing Script';
  static const String hand    = 'Caveat';

  // ── Display / Headline (Cormorant Garamond) ────────────────

  static TextStyle displayLarge() => GoogleFonts.cormorantGaramond(
    fontSize: 57, fontWeight: FontWeight.bold, color: AppColors.roseQuartz,
  );
  static TextStyle displayMedium() => GoogleFonts.cormorantGaramond(
    fontSize: 45, fontWeight: FontWeight.bold, color: AppColors.roseQuartz,
  );
  static TextStyle displaySmall() => GoogleFonts.cormorantGaramond(
    fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.roseQuartz,
  );
  static TextStyle headlineLarge() => GoogleFonts.cormorantGaramond(
    fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.roseQuartz,
  );
  static TextStyle headlineMedium() => GoogleFonts.cormorantGaramond(
    fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.roseQuartz,
  );
  static TextStyle headlineSmall() => GoogleFonts.cormorantGaramond(
    fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.roseQuartz,
  );
  static TextStyle titleLarge() => GoogleFonts.cormorantGaramond(
    fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.roseQuartz,
    letterSpacing: 0.5,
  );

  // ── Title / Body / Label (Outfit) ──────────────────────────

  static TextStyle titleMedium() => GoogleFonts.outfit(
    fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.petalWhite,
  );
  static TextStyle titleSmall() => GoogleFonts.outfit(
    fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.petalWhite,
  );
  static TextStyle bodyLarge() => GoogleFonts.outfit(
    fontSize: 16, color: AppColors.textMedium,
  );
  static TextStyle bodyMedium() => GoogleFonts.outfit(
    fontSize: 14, color: AppColors.textMedium,
  );
  static TextStyle bodySmall() => GoogleFonts.outfit(
    fontSize: 12, color: AppColors.textMuted,
  );

  /// Buttons, CTAs — Outfit 14/w600/ls1.0
  static TextStyle labelLarge() => GoogleFonts.outfit(
    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.petalWhite,
    letterSpacing: 1.0,
  );

  /// Eyebrows, chips — Outfit 12/w700/ls1.8
  static TextStyle labelMedium() => GoogleFonts.outfit(
    fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.roseQuartz,
    letterSpacing: 1.8,
  );

  /// Section eyebrows — Outfit 11/w700/ls2.0
  static TextStyle labelSmall() => GoogleFonts.outfit(
    fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.roseQuartz,
    letterSpacing: 2.0,
  );

  // ── Handwritten (NoteDialog only) ──────────────────────────

  /// Dancing Script 30/bold/blushGold — note titles
  static TextStyle handwrittenTitle() => GoogleFonts.dancingScript(
    fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.blushGold,
  );

  /// Caveat 24/textHigh — note body
  static TextStyle handwrittenBody() => GoogleFonts.caveat(
    fontSize: 24, color: AppColors.textHigh,
  );

  // ── Build a complete TextTheme for ThemeData ───────────────

  static TextTheme get textTheme => TextTheme(
    displayLarge:  displayLarge(),
    displayMedium: displayMedium(),
    displaySmall:  displaySmall(),
    headlineLarge: headlineLarge(),
    headlineMedium: headlineMedium(),
    headlineSmall: headlineSmall(),
    titleLarge:    titleLarge(),
    titleMedium:   titleMedium(),
    titleSmall:    titleSmall(),
    bodyLarge:     bodyLarge(),
    bodyMedium:    bodyMedium(),
    bodySmall:     bodySmall(),
    labelLarge:    labelLarge(),
    labelMedium:   labelMedium(),
    labelSmall:    labelSmall(),
  );
}
