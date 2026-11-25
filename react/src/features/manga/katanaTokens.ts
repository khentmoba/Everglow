import { useEffect, useState, type CSSProperties } from 'react';
import { lineHeight } from '../../core/theme/paint';
import { clearOnLogout, setBoundedCache } from '../../core/utils/boundedCache';

/** Dedicated typography for Manga Celestia (distinct from Everglow's Cormorant Garamond + Outfit couple theme). */
export const KatanaFonts = {
  display: "'Bebas Neue', 'DM Sans', 'Everglow Emoji', 'Everglow Symbols', sans-serif",
  heading: "'DM Sans', 'Everglow Emoji', 'Everglow Symbols', sans-serif",
  body: "'DM Sans', 'Everglow Emoji', 'Everglow Symbols', sans-serif",
} as const;

/** Shared base palette hex values used by both the Manga Celestia shell and the reader canvas. */
export const KATANA_BASE_PALETTES = {
  dark: { bg: '#0C0B0E', surface: '#141318', fg: '#F4F1EC' },
  oled: { bg: '#000000', surface: '#0B0A0D', fg: '#F7F4EF' },
  light: { bg: '#F7F5F0', surface: '#FFFFFF', fg: '#17151C' },
  sepia: { bg: '#F2EAE0', surface: '#FAF5EC', fg: '#2A2118' },
} as const;

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

/** Shared cover-grid column density across Home, Browse, and Library (2 large-art columns on <480px phones, 3 in compact library mode). */
export function getKatanaGridColumns(width: number, compact = false): number {
  const base =
    width >= KATANA_BREAKPOINTS.desktop
      ? 5
      : width >= KATANA_BREAKPOINTS.tablet
        ? 4
        : width >= 480
          ? 3
          : 2;
  return compact ? base + 1 : base;
}

export const KATANA_THEME_VARS: Record<KatanaThemeMode, Record<string, string>> = {
  dark: {
    '--katana-bg': KATANA_BASE_PALETTES.dark.bg,
    '--katana-surface': KATANA_BASE_PALETTES.dark.surface,
    '--katana-surface-alt': '#1C1A22',
    '--katana-surface-glow': '#25222D',
    '--katana-border': '#26242E',
    '--katana-border-strong': '#383444',
    '--katana-text': KATANA_BASE_PALETTES.dark.fg,
    '--katana-text-muted': '#A6A0B0',
    '--katana-text-light': '#8A8496',
    '--katana-accent': '#E8923A',
    '--katana-accent-dark': '#C97522',
    '--katana-accent-soft': '#F5B873',
    '--katana-accent-ink': '#120E0A',
    '--katana-chip-selected-bg': '#2A1F14',
    '--katana-chip-selected-border': '#8C5926',
    '--katana-chip-selected-text': '#F7C992',
    '--katana-link': '#7AB0FA',
    '--katana-green': '#34C78B',
    '--katana-orange': '#F08C4B',
    '--katana-crimson': '#E05A5A',
    '--katana-teal': '#38BDB0',
    '--katana-header-dark': '#0F0E12',
    '--katana-switch-off': '#2A2733',
  },
  oled: {
    '--katana-bg': KATANA_BASE_PALETTES.oled.bg,
    '--katana-surface': KATANA_BASE_PALETTES.oled.surface,
    '--katana-surface-alt': '#141219',
    '--katana-surface-glow': '#1D1B24',
    '--katana-border': '#201E28',
    '--katana-border-strong': '#322F3D',
    '--katana-text': KATANA_BASE_PALETTES.oled.fg,
    '--katana-text-muted': '#A49EAE',
    '--katana-text-light': '#878194',
    '--katana-accent': '#E8923A',
    '--katana-accent-dark': '#C97522',
    '--katana-accent-soft': '#F5B873',
    '--katana-accent-ink': '#000000',
    '--katana-chip-selected-bg': '#24190E',
    '--katana-chip-selected-border': '#8C5926',
    '--katana-chip-selected-text': '#F7C992',
    '--katana-link': '#7AB0FA',
    '--katana-green': '#34C78B',
    '--katana-orange': '#F08C4B',
    '--katana-crimson': '#E05A5A',
    '--katana-teal': '#38BDB0',
    '--katana-header-dark': '#000000',
    '--katana-switch-off': '#22202B',
  },
  light: {
    '--katana-bg': KATANA_BASE_PALETTES.light.bg,
    '--katana-surface': KATANA_BASE_PALETTES.light.surface,
    '--katana-surface-alt': '#EEEAE2',
    '--katana-surface-glow': '#E5DFD5',
    '--katana-border': '#DDD7CC',
    '--katana-border-strong': '#C2B9AA',
    '--katana-text': KATANA_BASE_PALETTES.light.fg,
    '--katana-text-muted': '#554F5E',
    '--katana-text-light': '#746D7D',
    '--katana-accent': '#C96F1E',
    '--katana-accent-dark': '#A35512',
    '--katana-accent-soft': '#A35512',
    '--katana-accent-ink': '#FFFFFF',
    '--katana-chip-selected-bg': '#FAEBDC',
    '--katana-chip-selected-border': '#C96F1E',
    '--katana-chip-selected-text': '#7C3E0B',
    '--katana-link': '#2563EB',
    '--katana-green': '#0D8A5A',
    '--katana-orange': '#D45A1A',
    '--katana-crimson': '#C93636',
    '--katana-teal': '#0D857B',
    '--katana-header-dark': '#FFFFFF',
    '--katana-switch-off': '#D4CEC3',
  },
  sepia: {
    '--katana-bg': KATANA_BASE_PALETTES.sepia.bg,
    '--katana-surface': KATANA_BASE_PALETTES.sepia.surface,
    '--katana-surface-alt': '#E9DFCE',
    '--katana-surface-glow': '#DFD1BA',
    '--katana-border': '#D4C4AA',
    '--katana-border-strong': '#B8A280',
    '--katana-text': KATANA_BASE_PALETTES.sepia.fg,
    '--katana-text-muted': '#5B4A3A',
    '--katana-text-light': '#756250',
    '--katana-accent': '#B86212',
    '--katana-accent-dark': '#914B0A',
    '--katana-accent-soft': '#914B0A',
    '--katana-accent-ink': '#FFFDF9',
    '--katana-chip-selected-bg': '#F4DFC0',
    '--katana-chip-selected-border': '#B86212',
    '--katana-chip-selected-text': '#6B3606',
    '--katana-link': '#1D5FA7',
    '--katana-green': '#15803D',
    '--katana-orange': '#C2410C',
    '--katana-crimson': '#B91C1C',
    '--katana-teal': '#0F766E',
    '--katana-header-dark': '#FAF5EC',
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
  crimson: 'var(--katana-crimson, #EF4444)',
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
  { accent: '#818CF8', secondary: '#C084FC', bgStart: '#1A1A32', bgEnd: '#141625', stripe: '#818CF8' },
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

const coverAccentCache = new Map<string, SeriesVisualAccent>();
clearOnLogout(coverAccentCache);

function toHexByte(n: number): string {
  return Math.max(0, Math.min(255, Math.round(n)))
    .toString(16)
    .padStart(2, '0')
    .toUpperCase();
}

function rgbToHex(r: number, g: number, b: number): string {
  return `#${toHexByte(r)}${toHexByte(g)}${toHexByte(b)}`;
}

function sanitizeNonPinkRgb(r: number, g: number, b: number): [number, number, number] {
  // Prevent magenta/rose/pink hues (where R is high, B is medium-high, and G is significantly lower)
  // from producing a couple-theme pink aura in Manga Celestia.
  if (r > 150 && b > 105 && g < Math.min(r, b) * 0.78) {
    return [r, Math.max(g, Math.round(r * 0.68)), Math.round(b * 0.42)];
  }
  return [r, g, b];
}

function sampleDominantCoverPalette(img: HTMLImageElement): SeriesVisualAccent | null {
  try {
    const w = 24;
    const h = 32;
    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    if (!ctx) return null;
    ctx.drawImage(img, 0, 0, w, h);
    const data = ctx.getImageData(0, 0, w, h).data;
    const buckets = Array.from({ length: 12 }, () => ({ r: 0, g: 0, b: 0, weight: 0 }));

    for (let i = 0; i < data.length; i += 4) {
      const a = data[i + 3];
      if (a < 180) continue;
      const [r, g, b] = sanitizeNonPinkRgb(data[i], data[i + 1], data[i + 2]);
      const max = Math.max(r, g, b);
      const min = Math.min(r, g, b);
      const lum = (max + min) / 2;
      if (lum < 28 || lum > 236) continue;
      const sat = max === min ? 0 : (max - min) / (255 - Math.abs(max + min - 255));
      if (sat < 0.18) continue;
      let hue = 0;
      const d = max - min;
      if (d > 0) {
        if (max === r) hue = ((g - b) / d + (g < b ? 6 : 0)) * 60;
        else if (max === g) hue = ((b - r) / d + 2) * 60;
        else hue = ((r - g) / d + 4) * 60;
      }
      const bIdx = Math.floor(hue / 30) % 12;
      const wgt = sat * (1 - Math.abs(lum - 135) / 160);
      buckets[bIdx].r += r * wgt;
      buckets[bIdx].g += g * wgt;
      buckets[bIdx].b += b * wgt;
      buckets[bIdx].weight += wgt;
    }

    const ranked = buckets
      .map((b, idx) => ({ ...b, idx }))
      .filter((b) => b.weight > 0.25)
      .sort((a, b) => b.weight - a.weight);
    if (ranked.length === 0) return null;

    const top = ranked[0];
    const sec = ranked.find((b) => Math.abs(b.idx - top.idx) >= 2) ?? ranked[1] ?? top;

    const boost = (c: number) => Math.min(248, Math.max(58, Math.round(c * 1.12)));
    const [r1, g1, b1] = sanitizeNonPinkRgb(
      boost(top.r / top.weight),
      boost(top.g / top.weight),
      boost(top.b / top.weight),
    );
    const [r2, g2, b2] = sanitizeNonPinkRgb(
      boost(sec.r / sec.weight),
      boost(sec.g / sec.weight),
      boost(sec.b / sec.weight),
    );

    const accent = rgbToHex(r1, g1, b1);
    const secondary = rgbToHex(r2, g2, b2);
    const bgStart = rgbToHex(Math.round(r1 * 0.16 + 12), Math.round(g1 * 0.16 + 14), Math.round(b1 * 0.16 + 20));
    const bgEnd = rgbToHex(Math.round(r2 * 0.11 + 11), Math.round(g2 * 0.11 + 13), Math.round(b2 * 0.11 + 19));
    return { accent, secondary, bgStart, bgEnd, stripe: accent };
  } catch {
    return null;
  }
}

/**
 * Extracts the actual cover artwork's dominant color palette for the detail-hero and spotlight aura,
 * falling back to `getSeriesVisualAccent(title, genres)` while loading or if sampling is unavailable.
 */
export function useCoverDominantAccent(
  coverUrl: string | undefined,
  title: string,
  genres?: readonly string[],
): SeriesVisualAccent {
  const fallback = getSeriesVisualAccent(title, genres);
  const [sampled, setSampled] = useState<SeriesVisualAccent | null>(() =>
    coverUrl ? coverAccentCache.get(coverUrl) ?? null : null,
  );

  useEffect(() => {
    if (!coverUrl) {
      setSampled(null);
      return;
    }
    const cached = coverAccentCache.get(coverUrl);
    if (cached) {
      setSampled(cached);
      return;
    }
    let alive = true;
    const img = new Image();
    if (!coverUrl.startsWith('data:') && !coverUrl.startsWith('blob:') && !coverUrl.startsWith('/')) {
      img.crossOrigin = 'anonymous';
    }
    img.onload = () => {
      if (!alive) return;
      const res = sampleDominantCoverPalette(img);
      if (res) {
        setBoundedCache(coverAccentCache, coverUrl, res, 120);
        setSampled(res);
      }
    };
    img.src = coverUrl;
    return () => {
      alive = false;
    };
  }, [coverUrl]);

  return sampled ?? fallback;
}

export const KatanaType = {
  display: {
    fontFamily: KatanaFonts.heading,
    fontWeight: 700,
    color: KatanaColors.text,
    fontSize: 26,
    letterSpacing: -0.6,
    lineHeight: lineHeight(26, 1.16),
  },
  title: {
    fontFamily: KatanaFonts.body,
    fontWeight: 600,
    color: KatanaColors.text,
    fontSize: 16,
    letterSpacing: -0.2,
    lineHeight: lineHeight(16, 1.25),
  },
  heading: {
    fontFamily: KatanaFonts.heading,
    fontWeight: 700,
    color: KatanaColors.text,
    fontSize: 21,
    letterSpacing: -0.4,
    lineHeight: lineHeight(21, 1.2),
  },
  section: {
    fontFamily: KatanaFonts.heading,
    fontWeight: 700,
    color: KatanaColors.text,
    fontSize: 18,
    letterSpacing: -0.35,
    lineHeight: lineHeight(18, 1.2),
  },
  body: {
    fontFamily: KatanaFonts.body,
    fontWeight: 500,
    color: KatanaColors.textMuted,
    fontSize: 14,
    lineHeight: lineHeight(14, 1.55),
  },
  small: {
    fontFamily: KatanaFonts.body,
    fontWeight: 500,
    color: KatanaColors.textLight,
    fontSize: 13,
    lineHeight: lineHeight(13, 1.38),
  },
  link: {
    fontFamily: KatanaFonts.body,
    fontWeight: 600,
    color: KatanaColors.link,
    fontSize: 13,
    lineHeight: lineHeight(13, 1.3),
  },
  accent: {
    fontFamily: KatanaFonts.body,
    fontWeight: 600,
    color: KatanaColors.accentSoft,
    fontSize: 13,
    lineHeight: lineHeight(13, 1.3),
  },
} satisfies Record<string, CSSProperties>;
