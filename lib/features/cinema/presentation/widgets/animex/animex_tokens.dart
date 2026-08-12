import 'package:flutter/material.dart';

/// Design tokens for the Everglow anime section, modeled on the reference
/// anime streaming UI: near-black blue-tinted surfaces, a warm orange
/// accent, Bebas Neue display type and DM Sans interface type.
abstract final class AnimeXTokens {
  static const Color bg = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF111118);
  static const Color surfaceRaised = Color(0xFF1A1A26);
  static const Color border = Color(0x1FFFFFFF);
  static const Color borderStrong = Color(0x33FFFFFF);
  static const Color accent = Color(0xFFEA580C);
  static const Color accentHover = Color(0xFFD94A08);
  static const Color accentWarm = Color(0xFFF59E0B);
  static const Color textPrimary = Color(0xFFF8F8F8);
  static const Color textSecondary = Color(0xFF8B8B9E);
  static const Color textMuted = Color(0xFF4A4A5E);
  static const Color success = Color(0xFF22C55E);
  static const Color dubBlue = Color(0xFF3B82F6);
  static const Color card = Color(0x0AFFFFFF);
  static const Color cardHover = Color(0x14FFFFFF);
  static const Color white85 = Color(0xD9FFFFFF);

  static const double radiusSm = 4;
  static const double radiusMd = 6;
  static const double radiusLg = 8;
  static const double radiusXl = 10;
  static const double radius2xl = 12;

  static const double pageMaxWidth = 1536; // max-w-screen-2xl
  static const double rowPosterWidthMobile = 155;
  static const double rowPosterWidthDesktop = 175;

  static const double headerHeight = 60;
  static const double mobileNavHeight = 56;
}

/// Display type: Bebas Neue, tight line height.
TextStyle bebasStyle({
  double size = 20,
  Color color = AnimeXTokens.textPrimary,
  double letterSpacing = 0.03,
}) {
  return TextStyle(
    fontFamily: 'Bebas Neue',
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
    height: 1,
  );
}

/// Interface type: DM Sans.
TextStyle dmSansStyle({
  double size = 14,
  Color color = AnimeXTokens.textPrimary,
  FontWeight weight = FontWeight.w400,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: 'DM Sans',
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// Interface type: Inter for long body copy.
TextStyle interBodyStyle({
  double size = 13,
  Color color = AnimeXTokens.textSecondary,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Inter',
    fontSize: size,
    color: color,
    height: height,
  );
}
