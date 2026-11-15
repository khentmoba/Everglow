import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static const String display = 'Cormorant Garamond';
  static const String body = 'Outfit';
  static const String reading = 'DM Sans';
  static const String script = 'Dancing Script';
  static const String hand = 'Caveat';

  static const List<String> fontFallback = [
    'Everglow Emoji',
    'Everglow Symbols',
  ];

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

  static const TextStyle outfitWhite = TextStyle(
    fontFamily: body,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w500,
    color: AppColors.petalWhite,
  );

  static final TextStyle outfitMuted = TextStyle(
    fontFamily: body,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static final TextStyle outfitMedium = TextStyle(
    fontFamily: body,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w500,
    color: AppColors.textMedium,
  );

  static const TextStyle outfitBold = TextStyle(
    fontFamily: body,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w600,
    color: AppColors.petalWhite,
  );

  static const TextStyle outfitHeading = TextStyle(
    fontFamily: body,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w700,
    color: AppColors.petalWhite,
  );

  static const TextStyle cormorantHeading = TextStyle(
    fontFamily: display,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w600,
    color: AppColors.roseQuartz,
  );

  static const TextStyle cormorantRegular = TextStyle(
    fontFamily: display,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w400,
    color: AppColors.roseQuartz,
  );

  static const TextStyle cormorantBold = TextStyle(
    fontFamily: display,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
  );

  static const TextStyle cormorantBoldWhite = TextStyle(
    fontFamily: display,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w700,
    color: AppColors.petalWhite,
  );

  static const TextStyle cormorantSemiBoldWhite = TextStyle(
    fontFamily: display,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w600,
    color: AppColors.petalWhite,
  );

  static const TextStyle cormorantExtraBold = TextStyle(
    fontFamily: display,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
  );

  static const TextStyle cormorantExtraBoldWhite = TextStyle(
    fontFamily: display,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w700,
    color: AppColors.petalWhite,
  );

  static const TextStyle cormorantBlack = TextStyle(
    fontFamily: display,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w700,
    color: AppColors.roseQuartz,
  );

  static const TextStyle cormorantBlackWhite = TextStyle(
    fontFamily: display,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w700,
    color: AppColors.petalWhite,
  );

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
  ).apply(fontFamilyFallback: fontFallback);
}
