import type { CSSProperties } from 'react';
import { lineHeight } from '../../core/theme/paint';
import { Fonts } from '../../core/theme/typography';

export const KATANA_BREAKPOINTS = {
  tablet: 720,
  tabletWide: 800,
  desktop: 960,
} as const;

export type KatanaThemeMode = 'dark' | 'oled' | 'light' | 'sepia';

const THEME_STORAGE_KEY = 'katana_theme_mode_v1';

export function loadKatanaThemeMode(): KatanaThemeMode {
  try {
    const raw = localStorage.getItem(THEME_STORAGE_KEY);
    if (raw === 'light' || raw === 'sepia' || raw === 'dark' || raw === 'oled') return raw;
  } catch {
    // ignore storage errors
  }
  return 'dark';
}

export function saveKatanaThemeMode(mode: KatanaThemeMode): void {
  try {
    localStorage.setItem(THEME_STORAGE_KEY, mode);
  } catch {
    // ignore storage errors
  }
}

/** Shared cover-grid column density across Home, Browse, and Library. */
export function getKatanaGridColumns(width: number, compact = false): number {
  const base = width >= 1200 ? 6 : width >= KATANA_BREAKPOINTS.desktop ? 5 : width >= KATANA_BREAKPOINTS.tablet ? 4 : 3;
  return compact ? base + 1 : base;
}

export const KATANA_THEME_VARS: Record<KatanaThemeMode, Record<string, string>> = {
  dark: {
    '--katana-bg': '#0B0D12',
    '--katana-surface': '#13161F',
    '--katana-surface-alt': '#1B202C',
    '--katana-surface-glow': '#232A3A',
    '--katana-border': '#262C3B',
    '--katana-border-strong': '#384259',
    '--katana-text': '#F3F5F9',
    '--katana-text-muted': '#A8B3C7',
    '--katana-text-light': '#9AA6BE',
    '--katana-accent': '#F59E0B',
    '--katana-accent-dark': '#D97706',
    '--katana-accent-soft': '#FCD34D',
    '--katana-accent-ink': '#111318',
    '--katana-chip-selected-bg': '#253047',
    '--katana-chip-selected-border': '#4B5E82',
    '--katana-chip-selected-text': '#F8FAFC',
    '--katana-link': '#60A5FA',
    '--katana-green': '#34D399',
    '--katana-orange': '#FB923C',
    '--katana-crimson': '#F43F5E',
    '--katana-teal': '#2DD4BF',
    '--katana-header-dark': '#0E1118',
    '--katana-switch-off': '#272E3F',
  },
  oled: {
    '--katana-bg': '#000000',
    '--katana-surface': '#090B0F',
    '--katana-surface-alt': '#12151C',
    '--katana-surface-glow': '#1A1F2A',
    '--katana-border': '#1E2430',
    '--katana-border-strong': '#303A4D',
    '--katana-text': '#F6F8FC',
    '--katana-text-muted': '#A6B1C4',
    '--katana-text-light': '#92A0B8',
    '--katana-accent': '#F59E0B',
    '--katana-accent-dark': '#D97706',
    '--katana-accent-soft': '#FCD34D',
    '--katana-accent-ink': '#000000',
    '--katana-chip-selected-bg': '#1F293D',
    '--katana-chip-selected-border': '#4B5E82',
    '--katana-chip-selected-text': '#F8FAFC',
    '--katana-link': '#60A5FA',
    '--katana-green': '#34D399',
    '--katana-orange': '#FB923C',
    '--katana-crimson': '#F43F5E',
    '--katana-teal': '#2DD4BF',
    '--katana-header-dark': '#000000',
    '--katana-switch-off': '#1F2533',
  },
  light: {
    '--katana-bg': '#F5F7FA',
    '--katana-surface': '#FFFFFF',
    '--katana-surface-alt': '#EDF0F6',
    '--katana-surface-glow': '#E2E7F0',
    '--katana-border': '#D5DCE8',
    '--katana-border-strong': '#B4C0D4',
    '--katana-text': '#111827',
    '--katana-text-muted': '#475569',
    '--katana-text-light': '#64748B',
    '--katana-accent': '#D97706',
    '--katana-accent-dark': '#B45309',
    '--katana-accent-soft': '#B45309',
    '--katana-accent-ink': '#FFFFFF',
    '--katana-chip-selected-bg': '#FEF3C7',
    '--katana-chip-selected-border': '#D97706',
    '--katana-chip-selected-text': '#92400E',
    '--katana-link': '#2563EB',
    '--katana-green': '#059669',
    '--katana-orange': '#EA580C',
    '--katana-crimson': '#E11D48',
    '--katana-teal': '#0D9488',
    '--katana-header-dark': '#FFFFFF',
    '--katana-switch-off': '#CBD5E1',
  },
  sepia: {
    '--katana-bg': '#F4EDE1',
    '--katana-surface': '#FBF7EF',
    '--katana-surface-alt': '#ECE3D2',
    '--katana-surface-glow': '#E2D4BC',
    '--katana-border': '#D7C7AE',
    '--katana-border-strong': '#BCA584',
    '--katana-text': '#2A2118',
    '--katana-text-muted': '#5B4A3A',
    '--katana-text-light': '#705D4B',
    '--katana-accent': '#C26A0B',
    '--katana-accent-dark': '#9A5208',
    '--katana-accent-soft': '#9A5208',
    '--katana-accent-ink': '#FFFDF9',
    '--katana-chip-selected-bg': '#F6E1C1',
    '--katana-chip-selected-border': '#C26A0B',
    '--katana-chip-selected-text': '#6E3904',
    '--katana-link': '#1D5FA7',
    '--katana-green': '#15803D',
    '--katana-orange': '#C2410C',
    '--katana-crimson': '#BE123C',
    '--katana-teal': '#0F766E',
    '--katana-header-dark': '#FBF7EF',
    '--katana-switch-off': '#CFC0A8',
  },
};

/**
 * Community-consensus manga/manhwa/manhua palette (inspired by MangaDex, Mihon, Comick):
 * deep neutral obsidian/slate dark mode, crisp daylight light mode, and warm sepia paper mode,
 * keeping cover artwork the star with warm editorial amber CTAs and semantic accents.
 */
export const KatanaColors = {
  background: 'var(--katana-bg, #0B0D12)',
  surface: 'var(--katana-surface, #13161F)',
  surfaceAlt: 'var(--katana-surface-alt, #1B202C)',
  surfaceGlow: 'var(--katana-surface-glow, #232A3A)',
  border: 'var(--katana-border, #262C3B)',
  borderStrong: 'var(--katana-border-strong, #384259)',
  text: 'var(--katana-text, #F3F5F9)',
  textMuted: 'var(--katana-text-muted, #A8B3C7)',
  textLight: 'var(--katana-text-light, #9AA6BE)',
  accent: 'var(--katana-accent, #F59E0B)',
  accentDark: 'var(--katana-accent-dark, #D97706)',
  accentSoft: 'var(--katana-accent-soft, #FCD34D)',
  accentInk: 'var(--katana-accent-ink, #111318)',
  chipSelectedBg: 'var(--katana-chip-selected-bg, #253047)',
  chipSelectedBorder: 'var(--katana-chip-selected-border, #4B5E82)',
  chipSelectedText: 'var(--katana-chip-selected-text, #F8FAFC)',
  link: 'var(--katana-link, #60A5FA)',
  green: 'var(--katana-green, #34D399)',
  orange: 'var(--katana-orange, #FB923C)',
  crimson: 'var(--katana-crimson, #F43F5E)',
  teal: 'var(--katana-teal, #2DD4BF)',
  headerDark: 'var(--katana-header-dark, #0E1118)',
  switchOff: 'var(--katana-switch-off, #272E3F)',
} as const;

export interface SeriesVisualAccent {
  accent: string;
  secondary: string;
  bgStart: string;
  bgEnd: string;
  stripe: string;
}

const SERIES_PALETTES: SeriesVisualAccent[] = [
  { accent: '#F59E0B', secondary: '#FB923C', bgStart: '#231C14', bgEnd: '#141824', stripe: '#F59E0B' },
  { accent: '#38BDF8', secondary: '#818CF8', bgStart: '#132032', bgEnd: '#17182B', stripe: '#38BDF8' },
  { accent: '#34D399', secondary: '#2DD4BF', bgStart: '#122622', bgEnd: '#141A24', stripe: '#34D399' },
  { accent: '#FB7185', secondary: '#F59E0B', bgStart: '#2B1721', bgEnd: '#171625', stripe: '#FB7185' },
  { accent: '#A78BFA', secondary: '#60A5FA', bgStart: '#1E1833', bgEnd: '#141826', stripe: '#A78BFA' },
  { accent: '#F97316', secondary: '#EF4444', bgStart: '#2A1814', bgEnd: '#161622', stripe: '#F97316' },
  { accent: '#2DD4BF', secondary: '#38BDF8', bgStart: '#12242A', bgEnd: '#141926', stripe: '#2DD4BF' },
  { accent: '#EAB308', secondary: '#84CC16', bgStart: '#242113', bgEnd: '#151A22', stripe: '#EAB308' },
];

/** Deterministic, art-inspired palette derived from series title + genres for detail hero aura and fallback covers. */
export function getSeriesVisualAccent(title: string, genres?: readonly string[]): SeriesVisualAccent {
  const gLower = (genres ?? []).map((g) => g.toLowerCase());
  if (gLower.some((g) => g.includes('action') || g.includes('martial'))) return SERIES_PALETTES[5];
  if (gLower.some((g) => g.includes('fantasy') || g.includes('isekai'))) return SERIES_PALETTES[4];
  if (gLower.some((g) => g.includes('sci-fi') || g.includes('mecha'))) return SERIES_PALETTES[1];
  if (gLower.some((g) => g.includes('slice of life') || g.includes('iyashikei'))) return SERIES_PALETTES[2];
  if (gLower.some((g) => g.includes('romance') || g.includes('shoujo'))) return SERIES_PALETTES[3];
  if (gLower.some((g) => g.includes('mystery') || g.includes('thriller') || g.includes('horror'))) return SERIES_PALETTES[6];
  let hash = 0;
  for (let i = 0; i < title.length; i += 1) {
    hash = (hash * 31 + title.charCodeAt(i)) >>> 0;
  }
  return SERIES_PALETTES[hash % SERIES_PALETTES.length];
}

export const KatanaType = {
  display: {
    fontFamily: Fonts.display,
    fontWeight: 700,
    color: KatanaColors.text,
    fontSize: 32,
    letterSpacing: -0.2,
    lineHeight: lineHeight(32, 1.08),
  },
  title: {
    fontFamily: Fonts.body,
    fontWeight: 600,
    color: KatanaColors.text,
    fontSize: 16,
    lineHeight: lineHeight(16, 1.25),
  },
  heading: {
    fontFamily: Fonts.display,
    fontWeight: 700,
    color: KatanaColors.text,
    fontSize: 25,
    letterSpacing: 0.1,
    lineHeight: lineHeight(25, 1.15),
  },
  section: {
    fontFamily: Fonts.display,
    fontWeight: 700,
    color: KatanaColors.text,
    fontSize: 21,
    letterSpacing: 0.15,
    lineHeight: lineHeight(21, 1.18),
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
    fontSize: 13,
    lineHeight: lineHeight(13, 1.38),
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
