// lib/core/theme/app_typography.dart. Each style lists only what it sets;
// everything else comes from the body defaults in styles.css (Material 3's
// 1.4286 line height and 0.25px letter spacing, as Flutter inherits them).
import type { CSSProperties } from 'react';
import { AppColors, Derived } from './colors';

const fallback = "'Everglow Emoji', 'Everglow Symbols'";

export const Fonts = {
  display: `'Cormorant Garamond', ${fallback}, serif`,
  body: `'Outfit', ${fallback}, sans-serif`,
  hand: `'Caveat', 'Outfit', sans-serif`,
  script: `'Dancing Script', 'Outfit', sans-serif`,
  reading: `'DM Sans', 'Outfit', sans-serif`,
};

export const AppTypography = {
  outfitWhite: { fontFamily: Fonts.body, fontWeight: 500, color: AppColors.petalWhite } as CSSProperties,
  outfitMuted: { fontFamily: Fonts.body, fontWeight: 500, color: Derived.textMuted } as CSSProperties,
  outfitMedium: { fontFamily: Fonts.body, fontWeight: 500, color: Derived.textMedium } as CSSProperties,
  outfitBold: { fontFamily: Fonts.body, fontWeight: 600, color: AppColors.petalWhite } as CSSProperties,
  outfitHeading: { fontFamily: Fonts.body, fontWeight: 700, color: AppColors.petalWhite } as CSSProperties,
  cormorantHeading: { fontFamily: Fonts.display, fontWeight: 600, color: AppColors.roseQuartz } as CSSProperties,
  cormorantRegular: { fontFamily: Fonts.display, fontWeight: 400, color: AppColors.roseQuartz } as CSSProperties,
  cormorantBold: { fontFamily: Fonts.display, fontWeight: 700, color: AppColors.roseQuartz } as CSSProperties,
  cormorantBoldWhite: { fontFamily: Fonts.display, fontWeight: 700, color: AppColors.petalWhite } as CSSProperties,
  cormorantSemiBoldWhite: { fontFamily: Fonts.display, fontWeight: 600, color: AppColors.petalWhite } as CSSProperties,
  cormorantExtraBold: { fontFamily: Fonts.display, fontWeight: 700, color: AppColors.roseQuartz } as CSSProperties,
  cormorantExtraBoldWhite: { fontFamily: Fonts.display, fontWeight: 700, color: AppColors.petalWhite } as CSSProperties,
  cormorantBlack: { fontFamily: Fonts.display, fontWeight: 700, color: AppColors.roseQuartz } as CSSProperties,
  cormorantBlackWhite: { fontFamily: Fonts.display, fontWeight: 700, color: AppColors.petalWhite } as CSSProperties,
  bodySmall: { fontFamily: Fonts.body, fontSize: 12.5, fontWeight: 500, color: Derived.textMuted } as CSSProperties,
  bodyMedium: { fontFamily: Fonts.body, fontSize: 14, fontWeight: 500, color: Derived.textMedium } as CSSProperties,
  bodyLarge: { fontFamily: Fonts.body, fontSize: 16, fontWeight: 500, color: Derived.textMedium } as CSSProperties,
  titleLarge: { fontFamily: Fonts.display, fontSize: 22, fontWeight: 600, color: AppColors.roseQuartz, letterSpacing: 0.5 } as CSSProperties,
  titleMedium: { fontFamily: Fonts.body, fontSize: 16, fontWeight: 500, color: AppColors.petalWhite } as CSSProperties,
  titleSmall: { fontFamily: Fonts.body, fontSize: 14, fontWeight: 500, color: AppColors.petalWhite } as CSSProperties,
  labelLarge: { fontFamily: Fonts.body, fontSize: 14, fontWeight: 600, color: AppColors.petalWhite, letterSpacing: 0.6 } as CSSProperties,
  labelMedium: { fontFamily: Fonts.body, fontSize: 12, fontWeight: 700, color: AppColors.roseQuartz, letterSpacing: 0.6 } as CSSProperties,
  labelSmall: { fontFamily: Fonts.body, fontSize: 11, fontWeight: 700, color: AppColors.roseQuartz, letterSpacing: 0.6 } as CSSProperties,
  handwrittenTitle: { fontFamily: Fonts.script, fontSize: 30, fontWeight: 700, color: AppColors.blushGold } as CSSProperties,
  handwrittenBody: { fontFamily: Fonts.hand, fontSize: 24, fontWeight: 400, color: Derived.textHigh } as CSSProperties,
};
