import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Dusk Petal v2 Typography token system.
///
/// Pairing: Cormorant Garamond (display/headline) + Outfit (body/UI).
/// Handwritten: Dancing Script + Caveat for romantic notes only.
///
/// All styles use fonts bundled in `pubspec.yaml` (`assets/google_fonts/`)
/// via `fontFamily` — never runtime-fetched. This keeps Flutter Web
/// CanvasKit text synchronous and sharp: no FOUT, no one-frame fallback,
/// no synthetic faux-bold from a half-loaded network font.
///
/// All styles are cached as static finals so they are allocated once and
/// reused across every build -- critical for 60 fps on Flutter web.
class AppTypography {
  AppTypography._();

  // Font family constants — must match `family:` in pubspec.yaml.
  static const String display = 'Cormorant Garamond';
  static const String body = 'Outfit';
  static const String script = 'Dancing Script';
  static const String hand = 'Caveat';

  // Cached Display / Headline (Cormorant Garamond)
  // NOTE: only 400/600/700 are bundled — never request w800/w900 for
  // Cormorant (Flutter would synthesize faux-bold = soft text on web).

  static const TextStyle _displayLarge = TextStyle(
    fontFamily: display,
    fontSize: 57,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
  );
  static const TextStyle _displayMedium = TextStyle(
    fontFamily: display,
    fontSize: 45,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
  );
  static const TextStyle _displaySmall = TextStyle(
    fontFamily: display,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
  );
  static const TextStyle _headlineLarge = TextStyle(
    fontFamily: display,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
  );
  static const TextStyle _headlineMedium = TextStyle(
    fontFamily: display,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.roseQuartz,
  );
  static const TextStyle _headlineSmall = TextStyle(
    fontFamily: display,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.roseQuartz,
  );
  static const TextStyle _titleLarge = TextStyle(
    fontFamily: display,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.roseQuartz,
    letterSpacing: 0.5,
  );

  // Cached Title / Body / Label (Outfit — 400..900 all bundled)
  // Body uses w500 minimum: Outfit 400 at 12-14px on dark glass is too
  // thin for CanvasKit grayscale AA and reads as blur. 500 stays sharp.

  static const TextStyle _titleMedium = TextStyle(
    fontFamily: body,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.petalWhite,
  );
  static const TextStyle _titleSmall = TextStyle(
    fontFamily: body,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.petalWhite,
  );
  static final TextStyle _bodyLarge = TextStyle(
    fontFamily: body,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textMedium,
  );
  static final TextStyle _bodyMedium = TextStyle(
    fontFamily: body,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textMedium,
  );
  static final TextStyle _bodySmall = TextStyle(
    fontFamily: body,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );
  static const TextStyle _labelLarge = TextStyle(
    fontFamily: body,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.petalWhite,
    letterSpacing: 0.6,
  );
  static const TextStyle _labelMedium = TextStyle(
    fontFamily: body,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
    letterSpacing: 0.6,
  );
  static const TextStyle _labelSmall = TextStyle(
    fontFamily: body,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
    letterSpacing: 0.6,
  );

  // Cached Handwritten (NoteDialog only)

  static const TextStyle _handwrittenTitle = TextStyle(
    fontFamily: script,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: AppColors.blushGold,
  );
  static final TextStyle _handwrittenBody = TextStyle(
    fontFamily: hand,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    color: AppColors.textHigh,
  );

  // Common inline styles used ~500 times across the codebase.
  // Callers use .copyWith() for custom sizes/colors.

  /// Outfit base -- white text, any size via copyWith.
  static const TextStyle outfitWhite = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w500,
    color: AppColors.petalWhite,
  );

  /// Outfit base -- muted text, any size via copyWith.
  static final TextStyle outfitMuted = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  /// Outfit base -- medium text, any size via copyWith.
  static final TextStyle outfitMedium = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w500,
    color: AppColors.textMedium,
  );

  /// Outfit w600 white -- buttons/labels base.
  static const TextStyle outfitBold = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w600,
    color: AppColors.petalWhite,
  );

  /// Outfit w700 white -- headings base.
  static const TextStyle outfitHeading = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w700,
    color: AppColors.petalWhite,
  );

  /// Cormorant w600 rose -- display headings base.
  static const TextStyle cormorantHeading = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w600,
    color: AppColors.roseQuartz,
  );

  /// Cormorant regular rose -- neutral display base.
  static const TextStyle cormorantRegular = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w400,
    color: AppColors.roseQuartz,
  );

  /// Cormorant w700 rose -- bold display base.
  static const TextStyle cormorantBold = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
  );

  /// Cormorant w700 white -- bold light display base.
  static const TextStyle cormorantBoldWhite = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    color: AppColors.petalWhite,
  );

  /// Cormorant w600 white -- semi-bold light display base.
  static const TextStyle cormorantSemiBoldWhite = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w600,
    color: AppColors.petalWhite,
  );

  /// Cormorant extra-bold display base (clamped to w700 — 800 not bundled).
  static const TextStyle cormorantExtraBold = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
  );

  /// Cormorant extra-bold light display base (clamped to w700).
  static const TextStyle cormorantExtraBoldWhite = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    color: AppColors.petalWhite,
  );

  /// Cormorant heavy display base (clamped to w700 — 900 not bundled).
  static const TextStyle cormorantBlack = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
  );

  /// Cormorant heavy light display base (clamped to w700).
  static const TextStyle cormorantBlackWhite = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
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
