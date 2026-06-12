import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dusk Petal Romantic Palette
  static const Color roseQuartz = Color(0xFFF4C2C2);
  static const Color deepRose = Color(0xFFC2185B);
  static const Color blushGold = Color(0xFFE8D5B7);
  static const Color twilight = Color(0xFF1A1A2E);
  static const Color velvet = Color(0xFF2D1B33);
  static const Color petalWhite = Color(0xFFFFF5F5);
  static const Color softLavender = Color(0xFFD4B5D6);
  static const Color warmAmber = Color(0xFFF0A500);
  static const Color moonlight = Color(0xFFF0E6FF);

  // Deprecated/Legacy Mapping to maintain backwards compatibility where direct constants were referenced
  static const Color primaryPink = roseQuartz;
  static const Color peachyMagenta = deepRose;
  static const Color neonTeal = softLavender;
  static const Color electricBlue = twilight;
  static const Color champagneGold = blushGold;
  
  static const LinearGradient gamifiedGradient = LinearGradient(
    colors: [twilight, velvet, deepRose],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const double glassBlur = 18.0;
  static const double glassOpacity = 0.12;

  static ThemeData get gamifiedTheme {
    final baseTextTheme = GoogleFonts.outfitTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: deepRose,
        primary: deepRose,
        secondary: softLavender,
        tertiary: blushGold,
        surface: twilight,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: twilight,
      
      // Beautiful typography combo: Cormorant Garamond for titles/display, Outfit for body
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.cormorantGaramond(
          fontSize: 57,
          fontWeight: FontWeight.bold,
          color: roseQuartz,
        ),
        displayMedium: GoogleFonts.cormorantGaramond(
          fontSize: 45,
          fontWeight: FontWeight.bold,
          color: roseQuartz,
        ),
        displaySmall: GoogleFonts.cormorantGaramond(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: roseQuartz,
        ),
        headlineLarge: GoogleFonts.cormorantGaramond(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: roseQuartz,
        ),
        headlineMedium: GoogleFonts.cormorantGaramond(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: roseQuartz,
        ),
        headlineSmall: GoogleFonts.cormorantGaramond(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: roseQuartz,
        ),
        titleLarge: GoogleFonts.cormorantGaramond(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: roseQuartz,
          letterSpacing: 0.5,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: petalWhite,
        ),
        titleSmall: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: petalWhite,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16,
          color: petalWhite.withValues(alpha: 0.9),
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          color: petalWhite.withValues(alpha: 0.8),
        ),
        bodySmall: GoogleFonts.outfit(
          fontSize: 12,
          color: petalWhite.withValues(alpha: 0.6),
        ),
      ),
      
      cardTheme: CardThemeData(
        color: moonlight.withValues(alpha: glassOpacity),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: BorderSide(color: moonlight.withValues(alpha: 0.18), width: 1.0),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: deepRose,
          foregroundColor: petalWhite,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  static bool get shouldReduceMotion => 
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;
}

