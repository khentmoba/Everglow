import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Gamified Pink Palette
  static const Color primaryPink = Color(0xFFFFD1DC);
  static const Color peachyMagenta = Color(0xFFFF00FF);
  static const Color neonTeal = Color(0xFF00FFFF);
  static const Color electricBlue = Color(0xFF0000FF);
  static const Color champagneGold = Color(0xFFF7E7CE);
  
  static const LinearGradient gamifiedGradient = LinearGradient(
    colors: [primaryPink, Color(0xFFFF85A1), peachyMagenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const double glassBlur = 10.0;
  static const double glassOpacity = 0.15;

  static ThemeData get gamifiedTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPink,
        primary: peachyMagenta,
        secondary: neonTeal,
        tertiary: champagneGold,
        surface: primaryPink.withValues(alpha: 0.1),
      ),
      scaffoldBackgroundColor: primaryPink,
      
      // Stylized semi-futuristic rounded fonts
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: Colors.black87,
        displayColor: peachyMagenta,
      ),
      
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: glassOpacity),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32.0),
          side: const BorderSide(color: Colors.white24, width: 0.5),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32.0),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  // Accessibility Fallback
  static bool get shouldReduceMotion => 
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;
}
