import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Dusk Petal v2 Typography token system.
///
/// Pairing: Cormorant Garamond (display/headline) + Outfit (body/UI).
/// Handwritten: Dancing Script + Caveat for romantic notes only.
///
/// All styles are cached as static finals so they are allocated once and
/// reused across every build -- critical for 60 fps on Flutter web.
class AppTypography {
  AppTypography._();

  // Font family constants
  static const String display = 'Cormorant Garamond';
  static const String body = 'Outfit';
  static const String script = 'Dancing Script';
  static const String hand = 'Caveat';

  // Cached Display / Headline (Cormorant Garamond)

  static final TextStyle _displayLarge = GoogleFonts.cormorantGaramond(
    fontSize: 57,
    fontWeight: FontWeight.bold,
    color: AppColors.roseQuartz,
  );
  static final TextStyle _displayMedium = GoogleFonts.cormorantGaramond(
    fontSize: 45,
    fontWeight: FontWeight.bold,
    color: AppColors.roseQuartz,
  );
  static final TextStyle _displaySmall = GoogleFonts.cormorantGaramond(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: AppColors.roseQuartz,
  );
  static final TextStyle _headlineLarge = GoogleFonts.cormorantGaramond(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
  );
  static final TextStyle _headlineMedium = GoogleFonts.cormorantGaramond(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.roseQuartz,
  );
  static final TextStyle _headlineSmall = GoogleFonts.cormorantGaramond(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.roseQuartz,
  );
  static final TextStyle _titleLarge = GoogleFonts.cormorantGaramond(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.roseQuartz,
    letterSpacing: 0.5,
  );

  // Cached Title / Body / Label (Outfit)

  static final TextStyle _titleMedium = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.petalWhite,
  );
  static final TextStyle _titleSmall = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.petalWhite,
  );
  static final TextStyle _bodyLarge = GoogleFonts.outfit(
    fontSize: 16,
    color: AppColors.textMedium,
  );
  static final TextStyle _bodyMedium = GoogleFonts.outfit(
    fontSize: 14,
    color: AppColors.textMedium,
  );
  static final TextStyle _bodySmall = GoogleFonts.outfit(
    fontSize: 12,
    color: AppColors.textMuted,
  );
  static final TextStyle _labelLarge = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.petalWhite,
    letterSpacing: 1.0,
  );
  static final TextStyle _labelMedium = GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
    letterSpacing: 1.8,
  );
  static final TextStyle _labelSmall = GoogleFonts.outfit(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
    letterSpacing: 2.0,
  );

  // Cached Handwritten (NoteDialog only)

  static final TextStyle _handwrittenTitle = GoogleFonts.dancingScript(
    fontSize: 30,
    fontWeight: FontWeight.bold,
    color: AppColors.blushGold,
  );
  static final TextStyle _handwrittenBody = GoogleFonts.caveat(
    fontSize: 24,
    color: AppColors.textHigh,
  );

  // Common inline styles used ~500 times across the codebase.
  // Callers use .copyWith() for custom sizes/colors.

  /// Outfit base -- white text, any size via copyWith.
  static final TextStyle outfitWhite = GoogleFonts.outfit(
    color: AppColors.petalWhite,
  );

  /// Outfit base -- muted text, any size via copyWith.
  static final TextStyle outfitMuted = GoogleFonts.outfit(
    color: AppColors.textMuted,
  );

  /// Outfit base -- medium text, any size via copyWith.
  static final TextStyle outfitMedium = GoogleFonts.outfit(
    color: AppColors.textMedium,
  );

  /// Outfit w600 white -- buttons/labels base.
  static final TextStyle outfitBold = GoogleFonts.outfit(
    fontWeight: FontWeight.w600,
    color: AppColors.petalWhite,
  );

  /// Outfit w700 white -- headings base.
  static final TextStyle outfitHeading = GoogleFonts.outfit(
    fontWeight: FontWeight.w700,
    color: AppColors.petalWhite,
  );

  /// Cormorant w600 rose -- display headings base.
  static final TextStyle cormorantHeading = GoogleFonts.cormorantGaramond(
    fontWeight: FontWeight.w600,
    color: AppColors.roseQuartz,
  );

  /// Cormorant regular rose -- neutral display base.
  static final TextStyle cormorantRegular = GoogleFonts.cormorantGaramond(
    color: AppColors.roseQuartz,
  );

  /// Cormorant w700 rose -- bold display base.
  static final TextStyle cormorantBold = GoogleFonts.cormorantGaramond(
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
  );

  /// Cormorant w700 white -- bold light display base.
  static final TextStyle cormorantBoldWhite = GoogleFonts.cormorantGaramond(
    fontWeight: FontWeight.w700,
    color: AppColors.petalWhite,
  );

  /// Cormorant w600 white -- semi-bold light display base.
  static final TextStyle cormorantSemiBoldWhite = GoogleFonts.cormorantGaramond(
    fontWeight: FontWeight.w600,
    color: AppColors.petalWhite,
  );

  /// Cormorant w800 rose -- extra-bold display base.
  static final TextStyle cormorantExtraBold = GoogleFonts.cormorantGaramond(
    fontWeight: FontWeight.w800,
    color: AppColors.roseQuartz,
  );

  /// Cormorant w800 white -- extra-bold light display base.
  static final TextStyle cormorantExtraBoldWhite =
      GoogleFonts.cormorantGaramond(
        fontWeight: FontWeight.w800,
        color: AppColors.petalWhite,
      );

  /// Cormorant w900 rose -- heavy display base.
  static final TextStyle cormorantBlack = GoogleFonts.cormorantGaramond(
    fontWeight: FontWeight.w900,
    color: AppColors.roseQuartz,
  );

  /// Cormorant w900 white -- heavy light display base.
  static final TextStyle cormorantBlackWhite = GoogleFonts.cormorantGaramond(
    fontWeight: FontWeight.w900,
    color: AppColors.petalWhite,
  );

  // Public accessors -- return cached instances.

  static TextStyle displayLarge() => _displayLarge;
  static TextStyle displayMedium() => _displayMedium;
  static TextStyle displaySmall() => _displaySmall;
  static TextStyle headlineLarge() => _headlineLarge;
  static TextStyle headlineMedium() => _headlineMedium;
  static TextStyle headlineSmall() => _headlineSmall;
  static TextStyle titleLarge() => _titleLarge;
  static TextStyle titleMedium() => _titleMedium;
  static TextStyle titleSmall() => _titleSmall;
  static TextStyle bodyLarge() => _bodyLarge;
  static TextStyle bodyMedium() => _bodyMedium;
  static TextStyle bodySmall() => _bodySmall;
  static TextStyle labelLarge() => _labelLarge;
  static TextStyle labelMedium() => _labelMedium;
  static TextStyle labelSmall() => _labelSmall;
  static TextStyle handwrittenTitle() => _handwrittenTitle;
  static TextStyle handwrittenBody() => _handwrittenBody;

  // Build a complete TextTheme for ThemeData

  static TextTheme get textTheme => TextTheme(
    displayLarge: _displayLarge,
    displayMedium: _displayMedium,
    displaySmall: _displaySmall,
    headlineLarge: _headlineLarge,
    headlineMedium: _headlineMedium,
    headlineSmall: _headlineSmall,
    titleLarge: _titleLarge,
    titleMedium: _titleMedium,
    titleSmall: _titleSmall,
    bodyLarge: _bodyLarge,
    bodyMedium: _bodyMedium,
    bodySmall: _bodySmall,
    labelLarge: _labelLarge,
    labelMedium: _labelMedium,
    labelSmall: _labelSmall,
  );
}
