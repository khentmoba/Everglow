import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'app_radius.dart';

/// Dusk Petal v2 — Master theme.
///
/// This file wires the token files into a Flutter `ThemeData`.
/// All token values live in their dedicated files:
/// - `app_colors.dart`      — color & semantic tokens
/// - `app_typography.dart`  — type scale & TextTheme
/// - `app_spacing.dart`     — 4-pt grid spacing
/// - `app_radius.dart`      — radius tokens
/// - `app_elevation.dart`   — shadow tokens
/// - `app_motion.dart`      — motion tokens (curves, durations, reduced)
/// - `app_breakpoints.dart` — responsive breakpoints
class AppTheme {
  AppTheme._();

  // ── Re-export palette for backwards compat ─────────────────
  // These now delegate to AppColors. Existing code that references
  // `AppTheme.roseQuartz` etc. will continue to work.
  static const Color roseQuartz   = AppColors.roseQuartz;
  static const Color deepRose     = AppColors.deepRose;
  static const Color blushGold    = AppColors.blushGold;
  static const Color twilight     = AppColors.twilight;
  static const Color velvet       = AppColors.velvet;
  static const Color petalWhite   = AppColors.petalWhite;
  static const Color softLavender = AppColors.softLavender;
  static const Color warmAmber    = AppColors.warmAmber;
  static const Color moonlight    = AppColors.moonlight;

  // ── Gradient / glass constants ─────────────────────────────

  static const LinearGradient gamifiedGradient = LinearGradient(
    colors: [AppColors.twilight, AppColors.velvet, AppColors.deepRose],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const double glassBlur = 18.0;
  static const double glassOpacity = 0.12;

  // ── ThemeData ──────────────────────────────────────────────

  static ThemeData get gamifiedTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.deepRose,
        primary: AppColors.deepRose,
        secondary: AppColors.softLavender,
        tertiary: AppColors.blushGold,
        surface: AppColors.twilight,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.twilight,
      textTheme: AppTypography.textTheme,
      cardTheme: CardThemeData(
        color: AppColors.surfaceGlass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusX2,
          side: BorderSide(color: AppColors.border, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepRose,
          foregroundColor: AppColors.petalWhite,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusX2,
          ),
          textStyle: AppTypography.labelLarge(),
        ),
      ),
    );
  }

  // ── Accessibility ──────────────────────────────────────────

  static bool get shouldReduceMotion =>
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;
  static const double petalFieldOpacity = 0.08;
}