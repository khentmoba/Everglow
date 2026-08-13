import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// Everglow Cinema palette - Netflix-like structure, Everglow skin.
///
/// Netflix builds its experience on a near-black, neutral stage where
/// artwork does the talking and the brand accent is used sparingly.
/// These tokens keep that discipline while staying in the Dusk Petal
/// family: deep plum blacks, rose gold accents, petal-white type.
abstract final class NetflixColors {
  /// Page background - near-black with a plum undertone.
  static const Color background = Color(0xFF0A0710);

  /// Slightly elevated surfaces (nav, sheets, hover cards).
  static const Color surface = Color(0xFF14101A);

  /// Higher elevation surfaces (preview cards, player chrome).
  static const Color surfaceElevated = Color(0xFF1C1624);

  /// Primary brand accent - used sparingly, like Netflix uses its red.
  static const Color accent = AppColors.deepRose;

  /// Secondary brand accent for highlights and numerals.
  static const Color gold = AppColors.blushGold;

  /// Primary text.
  static const Color textPrimary = AppColors.petalWhite;

  /// Secondary text - rose-tinted gray.
  static const Color textSecondary = Color(0xFFB9A9C2);

  /// Muted / tertiary text.
  static const Color textMuted = AppColors.mutedPurple;

  /// "Match" percentage color - Netflix uses green here; a soft mint
  /// keeps the same semantic without importing a foreign hue family.
  static const Color match = Color(0xFF7ED69A);

  /// Hover overlay scrim.
  static const Color hoverScrim = Color(0x33000000);

  /// Bottom nav / sheet hairline.
  static Color get hairline => AppColors.moonlight.withValues(alpha: 0.14);
}
