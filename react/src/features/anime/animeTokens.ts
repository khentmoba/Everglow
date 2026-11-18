import type { CSSProperties } from 'react';
import { AppColors } from '../../core/theme/colors';
import { letterSpacing, lineHeight } from '../../core/theme/paint';

export const AnimeXTokens = {
  bg: '#0A0A0F',
  surface: '#111118',
  surfaceRaised: '#1A1A26',
  border: 'rgba(255, 255, 255, 0.1216)',
  glassBorder: 'rgba(255, 255, 255, 0.1804)',

  accent: AppColors.deepRose,
  accentHover: '#A0154A',
  accentWarm: AppColors.auroraRose,
  dubBlue: '#3B82F6',
  gold: '#FBBF24',
  success: '#22C55E',

  textPrimary: '#F8F8F8',
  textSecondary: '#8B8B9E',
  textMuted: '#4A4A5E',
  white85: 'rgba(255, 255, 255, 0.851)',
  borderStrong: 'rgba(255, 255, 255, 0.2)',
  card: 'rgba(255, 255, 255, 0.0392)',
  cardHover: 'rgba(255, 255, 255, 0.0784)',
  glass: 'rgba(18, 18, 25, 0.702)',
  posterScrimBottom: 'rgba(0, 0, 0, 0.851)',

  radiusSm: 4,
  radiusMd: 6,
  radiusLg: 8,
  radiusXl: 10,
  radius2xl: 12,
  radiusCard: 14,
  radiusPill: 999,

  headerHeight: 60,
  mobileNavHeight: 68,
  desktopNavBreakpoint: 1200,
  pageMaxWidth: 1536,

  rowPosterWidthMobile: 155,
  rowPosterWidthDesktop: 175,
  posterDetailsHeight: 72,
} as const;

// Flutter text styles: unset height / letter spacing fall back to the
// Material defaults set on <body> (1.4286 and 0.25px). Letter spacing is in
// pixels, as in Flutter, with Flutter's half-shift.
export function bebasStyle(opts?: { size?: number; color?: string; letterSpacing?: number }): CSSProperties {
  return {
    fontFamily: "'Bebas Neue', 'Everglow Emoji', 'Everglow Symbols', sans-serif",
    fontSize: opts?.size ?? 20,
    fontWeight: 400,
    color: opts?.color ?? AnimeXTokens.textPrimary,
    lineHeight: lineHeight(opts?.size ?? 20, 1),
    ...letterSpacing(opts?.letterSpacing ?? 0.03),
  };
}

export function dmSansStyle(opts?: {
  size?: number;
  color?: string;
  weight?: number;
  height?: number;
  letterSpacing?: number;
}): CSSProperties {
  return {
    fontFamily: "'DM Sans', 'Everglow Emoji', 'Everglow Symbols', sans-serif",
    fontSize: opts?.size ?? 14,
    fontWeight: opts?.weight ?? 400,
    color: opts?.color ?? AnimeXTokens.textPrimary,
    lineHeight: lineHeight(opts?.size ?? 14, opts?.height),
    ...(opts?.letterSpacing != null ? letterSpacing(opts.letterSpacing) : {}),
  };
}

export function interBodyStyle(opts?: { size?: number; color?: string; height?: number }): CSSProperties {
  return {
    fontFamily: "'DM Sans', 'Everglow Emoji', 'Everglow Symbols', sans-serif",
    fontSize: opts?.size ?? 13,
    fontWeight: 500, // no weight in Flutter: inherits bodyMedium w500
    color: opts?.color ?? AnimeXTokens.textSecondary,
    lineHeight: lineHeight(opts?.size ?? 13, opts?.height),
  };
}

export function animeDurationText(minutes?: number | null): string {
  if (!minutes || minutes <= 0) return '';
  if (minutes >= 60) {
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    return m > 0 ? `${h}h ${m}m` : `${h}h`;
  }
  return `${minutes}m`;
}
