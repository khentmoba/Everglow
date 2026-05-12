import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color cream = Color(0xFFFDF5E6);
  static const Color taupe = Color(0xFF8E7C77);
  static const Color blush = Color(0xFFE2B6AE);
  static const Color charcoal = Color(0xFF2C2C2C);
  static const Color cardWhite = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: taupe,
        primary: taupe,
        secondary: blush,
        surface: cream,
        background: cream,
      ),
      scaffoldBackgroundColor: cream,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: charcoal,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: charcoal,
        ),
        titleLarge: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: charcoal,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 18,
          color: charcoal,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 16,
          color: charcoal.withOpacity(0.8),
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: taupe,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: cardWhite,
        elevation: 4,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0), // Polaroid look
        ),
      ),
    );
  }
}
