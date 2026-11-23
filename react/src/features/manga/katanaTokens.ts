import type { CSSProperties } from 'react';
import { lineHeight } from '../../core/theme/paint';
import { Fonts } from '../../core/theme/typography';

export const KATANA_BREAKPOINTS = {
  tablet: 720,
  tabletWide: 800,
  desktop: 960,
} as const;

/** Shared cover-grid column density across Home, Browse, and Library. */
export function getKatanaGridColumns(width: number, compact = false): number {
  const base = width >= 1200 ? 6 : width >= KATANA_BREAKPOINTS.desktop ? 5 : width >= KATANA_BREAKPOINTS.tablet ? 4 : 3;
  return compact ? base + 1 : base;
}

/**
 * Community-consensus manga/manhwa/manhua palette (inspired by MangaDex, Mihon, Comick):
 * deep neutral obsidian/slate surfaces that keep cover artwork the star, paired with
 * warm editorial amber for primary CTAs and restrained sky/emerald/coral semantic accents.
 */
export const KatanaColors = {
  background: '#0B0D12',
  surface: '#13161F',
  surfaceAlt: '#1B202C',
  surfaceGlow: '#232A3A',
  border: '#262C3B',
  borderStrong: '#384259',
  text: '#F3F5F9',
  textMuted: '#A8B3C7',
  textLight: '#9AA6BE',
  accent: '#F59E0B',
  accentDark: '#D97706',
  accentSoft: '#FCD34D',
  accentInk: '#111318',
  chipSelectedBg: '#253047',
  chipSelectedBorder: '#4B5E82',
  chipSelectedText: '#F8FAFC',
  link: '#60A5FA',
  green: '#34D399',
  orange: '#FB923C',
  crimson: '#F43F5E',
  teal: '#2DD4BF',
  headerDark: '#0E1118',
  switchOff: '#272E3F',
} as const;

export const KatanaType = {
  display: {
    fontFamily: Fonts.body,
    fontWeight: 800,
    color: KatanaColors.text,
    fontSize: 28,
    letterSpacing: -0.5,
    lineHeight: lineHeight(28, 1.12),
  },
  title: {
    fontFamily: Fonts.body,
    fontWeight: 600,
    color: KatanaColors.text,
    fontSize: 16,
    lineHeight: lineHeight(16, 1.25),
  },
  heading: {
    fontFamily: Fonts.body,
    fontWeight: 700,
    color: KatanaColors.text,
    fontSize: 22,
    letterSpacing: -0.2,
    lineHeight: lineHeight(22, 1.2),
  },
  section: {
    fontFamily: Fonts.body,
    fontWeight: 700,
    color: KatanaColors.text,
    fontSize: 18,
    letterSpacing: -0.15,
    lineHeight: lineHeight(18, 1.2),
  },
  body: {
    fontFamily: Fonts.body,
    fontWeight: 500,
    color: KatanaColors.textMuted,
    fontSize: 14,
    lineHeight: lineHeight(14, 1.55),
  },
  small: {
    fontFamily: Fonts.body,
    fontWeight: 500,
    color: KatanaColors.textLight,
    fontSize: 12.5,
    lineHeight: lineHeight(12.5, 1.35),
  },
  link: {
    fontFamily: Fonts.body,
    fontWeight: 600,
    color: KatanaColors.link,
    fontSize: 13,
    lineHeight: lineHeight(13, 1.3),
  },
  accent: {
    fontFamily: Fonts.body,
    fontWeight: 600,
    color: KatanaColors.accentSoft,
    fontSize: 13,
    lineHeight: lineHeight(13, 1.3),
  },
} satisfies Record<string, CSSProperties>;
