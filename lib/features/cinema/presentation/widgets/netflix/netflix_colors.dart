import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// Cinema palette: near-black surfaces, neutral text, and a restrained red.
abstract final class NetflixColors {
  /// Page background.
  static const Color background = Color(0xFF080808);

  /// Slightly elevated surfaces (nav, sheets, hover cards).
  static const Color surface = Color(0xFF141414);

  /// Higher elevation surfaces (preview cards, player chrome).
  static const Color surfaceElevated = Color(0xFF202020);

  /// Action and selection accent.
  static const Color accent = AppColors.cinemaRed;

  /// Secondary brand accent for highlights and numerals.
  static const Color gold = AppColors.blushGold;

  /// Primary text.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary text.
  static const Color textSecondary = Color(0xFFB3B3B3);

  /// Muted / tertiary text.
  static const Color textMuted = Color(0xFF888888);

  /// "Match" percentage color - Netflix uses green here; a soft mint
  /// keeps the same semantic without importing a foreign hue family.
  static const Color match = AppColors.cinemaMatch;

  /// Hover overlay scrim.
  static const Color hoverScrim = AppColors.scrimLight;

  /// Bottom nav / sheet hairline.
  static const Color hairline = Color(0x23FFFFFF);
}

/// Country label for the Top 10 rail, shared by the rail header
/// ("Top 10 in the Philippines") and the drawer badge
/// ("#N in the Philippines Today").
const String topTenCountryLabel = 'the Philippines';
