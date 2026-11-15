import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color twilight = Color(0xFF1A1A2E);
  static const Color velvet = Color(
    0xFF2D1B33,
  );
  static const Color roseQuartz = Color(
    0xFFF4C2C2,
  );
  static const Color deepRose = Color(
    0xFFC2185B,
  );
  static const Color blushGold = Color(
    0xFFE8D5B7,
  );
  static const Color petalWhite = Color(0xFFFFF5F5);
  static const Color softLavender = Color(0xFFD4B5D6);
  static const Color moonlight = Color(
    0xFFF0E6FF,
  );
  static const Color warmAmber = Color(0xFFF0A500);

  static const Color auroraRose = Color(0xFFFF6F91);
  static const Color auroraGold = Color(0xFFF5C97B);
  static const Color auroraLilac = Color(0xFFB79CED);
  static const Color auroraTeal = Color(0xFF7EE8D2);
  static const Color inkDeep = Color(0xFF100A1C);
  static const Color plum = Color(0xFF3A2352);
  static const Color silk = Color(0xFF2E203E);

  static const Color deepBlack = Color(0xFF12091A);
  static const Color mutedPurple = Color(0xFF8A7A92);

  static const Color cinemaRed = Color(0xFFE50914);
  static const Color cinemaMatch = Color(0xFF7ED69A);
  static const Color cinemaOrange = Color(0xFFFF6D00);
  static const Color cinemaPink = Color(0xFFE91E8C);
  static const Color cinemaGreen = Color(0xFF2E7D32);
  static const Color cinemaAmber = Color(0xFFFF9800);
  static const Color cinemaBlue = Color(0xFF1976D2);

  static const Color rankGold = warmAmber;
  static const Color rankSilver = Color(0xFFB0BEC5);
  static const Color rankBronze = Color(0xFFBF8040);
  static const Color hoverSurface = Color(0xFF141418);

  static const Color rosePressed = Color(0xFF8E1444);
  static const Color roseDark = Color(0xFF6B0F2A);
  static const Color roseDepths = Color(0xFF7A2442);

  static const Color goldShadow = Color(0xFF6B4E00);

  static const Color rankSilverCool = Color(0xFFB9BBFF);
  static const Color rankBronzeWarm = Color(0xFFE8A87C);

  static const Color cinemaTextDim = Color(0xFFB9A9C2);
  static const Color blushTint = Color(0xFFFFE4EC);

  static const Color accentPink = Color(0xFFE91E63);

  static const Color scrimLight = Color(0x33000000);
  static const Color scrimMedium = Color(0x59000000);
  static const Color scrimStrong = Color(0x66000000);

  static const Color success = Color(0xFF4ADE80);
  static const Color error = Color(0xFFE5739B);
  static const Color warning = warmAmber;
  static const Color info = softLavender;

  static const Color surface = twilight;
  static const Color surfaceElevated = velvet;

  static Color get surfaceGlass => moonlight.withValues(alpha: 0.12);

  static Color get panelGlass => inkDeep.withValues(alpha: 0.62);

  static Color get glassSoft => moonlight.withValues(alpha: 0.08);

  static Color get textHigh => petalWhite.withValues(alpha: 0.95);

  static Color get textMedium => petalWhite.withValues(alpha: 0.82);

  static Color get textMuted => roseQuartz.withValues(alpha: 0.76);

  static Color get textDisabled => petalWhite.withValues(alpha: 0.52);

  static Color get border => moonlight.withValues(alpha: 0.18);

  static Color get divider => moonlight.withValues(alpha: 0.18);

  static Color get glowRose => deepRose.withValues(alpha: 0.35);
  static Color get glowGold => blushGold.withValues(alpha: 0.30);
  static Color get glowLavender => softLavender.withValues(alpha: 0.28);

  static const Color shimmerBase = Color(0xFF1C1228);
  static const Color shimmerHighlight = Color(0xFF2A1F3A);

  static const Color animeBackground = Color(0xFF080810);
  static const Color animeCard = Color(0xFF1C1228);
  static const Color animeRose = roseQuartz;
  static const Color animeDeepRose = deepRose;
  static const Color animeGold = Color(0xFFE8C97A);
  static const Color animeWhite = petalWhite;
  static const Color animeMuted = mutedPurple;
  static const Color animeCyan = Color(0xFF00BCD4);
  static const Color animeMagenta = Color(0xFFFF2D55);
  static const Color animeElectricPurple = Color(0xFF7C3AED);
  static const Color animeVibrantPink = Color(0xFFFF4081);
}
