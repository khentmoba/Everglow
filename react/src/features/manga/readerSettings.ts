import { Prefs } from '../../core/system/prefs';

export type ReadingMode =
  | 'webtoon'
  | 'auto-rtl'
  | 'auto-ltr'
  | 'paged-rtl'
  | 'paged-ltr'
  | 'double-rtl'
  | 'double-ltr'
  | 'strip-rtl'
  | 'strip-ltr';

export type FitMode = 'smart-fit' | 'fit-width' | 'fit-height' | 'fit-screen' | 'stretch' | 'original';

export type ReaderBackground = 'auto' | 'oled' | 'dark' | 'gray' | 'sepia' | 'white';

export type TapZoneLayout = 'standard' | 'kindle' | 'l-shaped' | 'edge' | 'disabled';

export type PageTransition = 'slide' | 'fade' | 'none';

export type ScrollHideSensitivity = 'low' | 'medium' | 'high';

export type OrientationLock = 'auto' | 'portrait' | 'landscape';

export type WidthUnit = 'px' | 'pct';

export type VerticalSeekbarSide = 'off' | 'right' | 'left';

export interface ReaderSettings {
  readingMode: ReadingMode;
  fitMode: FitMode;
  coverOffset: boolean;
  autoSpreadWide: boolean;
  splitWidePages: boolean;
  rotateWidePages: boolean;
  spreadGutter: number;
  background: ReaderBackground;
  brightness: number;
  warmTint: number;
  contrast: number;
  grayscale: boolean;
  invertColors: boolean;
  pageGap: number;
  maxWidth: number;
  widthUnit: WidthUnit;
  maxWidthPct: number;
  doubleTapZoom: number;
  keepZoomAcrossPages: boolean;
  autoScrollSpeed: number;
  preloadCount: number;
  preloadWifiOnly: boolean;
  webtoonTapScroll: boolean;
  verticalSeekbar: VerticalSeekbarSide;
  tapZoneLayout: TapZoneLayout;
  invertTapZones: boolean;
  showTapZonesOverlay: boolean;
  confirmChapterSwipe: boolean;
  showPageIndicator: boolean;
  showModeToast: boolean;
  hideChromeOnScroll: boolean;
  showChromeOnScrollUp: boolean;
  scrollHideSensitivity: ScrollHideSensitivity;
  autoHideChrome: boolean;
  autoHideDelayMs: number;
  pageTransition: PageTransition;
  keepAwake: boolean;
  orientationLock: OrientationLock;
  seamlessNextChapter: boolean;
  alwaysShowChapterDivider: boolean;
  cropBorders: boolean;
  skipReadChapters: boolean;
  dataSaver: boolean;
  haptics: boolean;
  einkFlash: boolean;
}

export type SeriesReaderOverride = Partial<ReaderSettings>;

export interface ResumeAnchor {
  chapterId: string;
  pageIdx: number;
  offsetRatio: number;
}

export interface PageBookmark {
  chapterId: string;
  chapterTitle: string;
  pageIdx: number;
  createdAt: number;
}

export const DEFAULT_READER_SETTINGS: ReaderSettings = {
  readingMode: 'webtoon',
  fitMode: 'fit-width',
  coverOffset: true,
  autoSpreadWide: true,
  splitWidePages: false,
  rotateWidePages: false,
  spreadGutter: 8,
  background: 'oled',
  brightness: 1,
  warmTint: 0,
  contrast: 1,
  grayscale: false,
  invertColors: false,
  pageGap: 0,
  maxWidth: 850,
  widthUnit: 'px',
  maxWidthPct: 85,
  doubleTapZoom: 2,
  keepZoomAcrossPages: false,
  autoScrollSpeed: 1,
  preloadCount: 3,
  preloadWifiOnly: false,
  webtoonTapScroll: false,
  verticalSeekbar: 'right',
  tapZoneLayout: 'standard',
  invertTapZones: false,
  showTapZonesOverlay: false,
  confirmChapterSwipe: false,
  showPageIndicator: true,
  showModeToast: true,
  hideChromeOnScroll: true,
  showChromeOnScrollUp: true,
  scrollHideSensitivity: 'medium',
  autoHideChrome: true,
  autoHideDelayMs: 5000,
  pageTransition: 'fade',
  keepAwake: true,
  orientationLock: 'auto',
  seamlessNextChapter: true,
  alwaysShowChapterDivider: true,
  cropBorders: false,
  skipReadChapters: false,
  dataSaver: false,
  haptics: true,
  einkFlash: false,
};

export const READER_BACKGROUNDS: Record<
  Exclude<ReaderBackground, 'auto'>,
  { label: string; bg: string; fg: string; swatch: string }
> = {
  oled: { label: 'True Black', bg: '#000000', fg: '#FFF5F8', swatch: '#000000' },
  dark: { label: 'Katana Night', bg: '#09060C', fg: '#FFF5F8', swatch: '#140C1C' },
  gray: { label: 'Slate', bg: '#1B1B22', fg: '#F3F2F7', swatch: '#2A2A35' },
  sepia: { label: 'Warm Paper', bg: '#F2E7D3', fg: '#2C2218', swatch: '#E7D5B8' },
  white: { label: 'Paper White', bg: '#F7F7F7', fg: '#16161A', swatch: '#FFFFFF' },
};

export function resolveBackgroundTheme(bg: ReaderBackground) {
  if (bg === 'auto') {
    const prefersLight = typeof window !== 'undefined' && window.matchMedia?.('(prefers-color-scheme: light)').matches;
    return prefersLight ? READER_BACKGROUNDS.white : READER_BACKGROUNDS.oled;
  }
  return READER_BACKGROUNDS[bg];
}

export const SERVER_OPTIONS = [
  { value: '', label: 'Server 1' },
  { value: '?sv=mk', label: 'Server 2' },
  { value: '?sv=3', label: 'Server 3' },
] as const;

export interface ReaderProfilePreset {
  id: string;
  label: string;
  desc: string;
  patch: Partial<ReaderSettings>;
}

export const READER_PROFILES: ReaderProfilePreset[] = [
  {
    id: 'webtoon-night',
    label: 'Webtoon Night',
    desc: 'Long strip • OLED • 75% dim • warm',
    patch: { readingMode: 'webtoon', fitMode: 'fit-width', background: 'oled', brightness: 0.75, warmTint: 0.15, pageGap: 0 },
  },
  {
    id: 'manga-night',
    label: 'Manga Night',
    desc: 'RTL paged • OLED • 80% dim',
    patch: { readingMode: 'paged-rtl', fitMode: 'smart-fit', background: 'oled', brightness: 0.8, warmTint: 0.1 },
  },
  {
    id: 'manga-day',
    label: 'Manga Day',
    desc: 'RTL paged • Paper • 100%',
    patch: { readingMode: 'paged-rtl', fitMode: 'smart-fit', background: 'sepia', brightness: 1, warmTint: 0 },
  },
  {
    id: 'tablet-spread',
    label: 'Tablet Spread',
    desc: 'Auto RTL • double pages • gutter',
    patch: { readingMode: 'auto-rtl', fitMode: 'fit-screen', background: 'dark', brightness: 1, warmTint: 0, coverOffset: true, spreadGutter: 8 },
  },
];

export const SCROLL_HIDE_THRESHOLD: Record<ScrollHideSensitivity, number> = {
  low: 96,
  medium: 48,
  high: 22,
};

export const READING_MODE_META: Record<
  ReadingMode,
  {
    label: string;
    shortLabel: string;
    icon: string;
    isRtl: boolean;
    isDouble: boolean;
    isAuto: boolean;
    isWebtoon: boolean;
    isHorizontalStrip: boolean;
  }
> = {
  webtoon: { label: 'Webtoon (Long Strip)', shortLabel: 'Webtoon', icon: 'view_day', isRtl: false, isDouble: false, isAuto: false, isWebtoon: true, isHorizontalStrip: false },
  'auto-rtl': { label: 'Auto Manga (RTL)', shortLabel: 'Auto RTL', icon: 'devices', isRtl: true, isDouble: false, isAuto: true, isWebtoon: false, isHorizontalStrip: false },
  'auto-ltr': { label: 'Auto Comic (LTR)', shortLabel: 'Auto LTR', icon: 'devices', isRtl: false, isDouble: false, isAuto: true, isWebtoon: false, isHorizontalStrip: false },
  'paged-rtl': { label: 'Manga (Right to Left)', shortLabel: 'Manga RTL', icon: 'menu_book', isRtl: true, isDouble: false, isAuto: false, isWebtoon: false, isHorizontalStrip: false },
  'paged-ltr': { label: 'Comic (Left to Right)', shortLabel: 'Paged LTR', icon: 'auto_stories', isRtl: false, isDouble: false, isAuto: false, isWebtoon: false, isHorizontalStrip: false },
  'double-rtl': { label: 'Spread (Right to Left)', shortLabel: 'Spread RTL', icon: 'chrome_reader_mode', isRtl: true, isDouble: true, isAuto: false, isWebtoon: false, isHorizontalStrip: false },
  'double-ltr': { label: 'Spread (Left to Right)', shortLabel: 'Spread LTR', icon: 'import_contacts', isRtl: false, isDouble: true, isAuto: false, isWebtoon: false, isHorizontalStrip: false },
  'strip-rtl': { label: 'Continuous Strip (RTL)', shortLabel: 'Strip RTL', icon: 'view_carousel', isRtl: true, isDouble: false, isAuto: false, isWebtoon: false, isHorizontalStrip: true },
  'strip-ltr': { label: 'Continuous Strip (LTR)', shortLabel: 'Strip LTR', icon: 'view_week', isRtl: false, isDouble: false, isAuto: false, isWebtoon: false, isHorizontalStrip: true },
};

export const READING_MODE_ORDER: ReadingMode[] = [
  'webtoon',
  'auto-rtl',
  'auto-ltr',
  'paged-rtl',
  'paged-ltr',
  'double-rtl',
  'double-ltr',
  'strip-rtl',
  'strip-ltr',
];

const GLOBAL_KEY = 'katana_reader_settings_v3';
const SERIES_PREFIX = 'katana_reader_series_v3_';
const RESUME_PREFIX = 'katana_reader_resume_v1_';
const ASPECTS_PREFIX = 'katana_reader_aspects_v1_';
const BOOKMARKS_PREFIX = 'katana_reader_page_bm_v1_';
const HINT_SEEN_KEY = 'katana_reader_hint_seen_v1';

const VALID_MODES = new Set<string>(READING_MODE_ORDER);
const VALID_FITS = new Set<string>(['smart-fit', 'fit-width', 'fit-height', 'fit-screen', 'stretch', 'original']);
const VALID_BGS = new Set<string>(['auto', 'oled', 'dark', 'gray', 'sepia', 'white']);
const VALID_TAPS = new Set<string>(['standard', 'kindle', 'l-shaped', 'edge', 'disabled']);
const VALID_TRANSITIONS = new Set<string>(['slide', 'fade', 'none']);
const VALID_SENS = new Set<string>(['low', 'medium', 'high']);
const VALID_ORIENT = new Set<string>(['auto', 'portrait', 'landscape']);
const VALID_UNITS = new Set<string>(['px', 'pct']);
const VALID_SEEKBAR = new Set<string>(['off', 'right', 'left']);

function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n));
}

export function loadGlobalReaderSettings(): ReaderSettings {
  const raw = Prefs.getString(GLOBAL_KEY);
  if (!raw) return { ...DEFAULT_READER_SETTINGS };
  try {
    const parsed = JSON.parse(raw) as Partial<ReaderSettings>;
    return {
      readingMode: VALID_MODES.has(String(parsed.readingMode))
        ? (parsed.readingMode as ReadingMode)
        : DEFAULT_READER_SETTINGS.readingMode,
      fitMode: VALID_FITS.has(String(parsed.fitMode))
        ? (parsed.fitMode as FitMode)
        : DEFAULT_READER_SETTINGS.fitMode,
      coverOffset: typeof parsed.coverOffset === 'boolean' ? parsed.coverOffset : DEFAULT_READER_SETTINGS.coverOffset,
      autoSpreadWide:
        typeof parsed.autoSpreadWide === 'boolean' ? parsed.autoSpreadWide : DEFAULT_READER_SETTINGS.autoSpreadWide,
      splitWidePages:
        typeof parsed.splitWidePages === 'boolean' ? parsed.splitWidePages : DEFAULT_READER_SETTINGS.splitWidePages,
      rotateWidePages:
        typeof parsed.rotateWidePages === 'boolean' ? parsed.rotateWidePages : DEFAULT_READER_SETTINGS.rotateWidePages,
      spreadGutter:
        typeof parsed.spreadGutter === 'number' && Number.isFinite(parsed.spreadGutter)
          ? clamp(Math.round(parsed.spreadGutter), 0, 32)
          : DEFAULT_READER_SETTINGS.spreadGutter,
      background: VALID_BGS.has(String(parsed.background))
        ? (parsed.background as ReaderBackground)
        : DEFAULT_READER_SETTINGS.background,
      brightness:
        typeof parsed.brightness === 'number' && Number.isFinite(parsed.brightness)
          ? clamp(parsed.brightness, 0.15, 1)
          : DEFAULT_READER_SETTINGS.brightness,
      warmTint:
        typeof parsed.warmTint === 'number' && Number.isFinite(parsed.warmTint)
          ? clamp(parsed.warmTint, 0, 0.4)
          : DEFAULT_READER_SETTINGS.warmTint,
      contrast:
        typeof parsed.contrast === 'number' && Number.isFinite(parsed.contrast)
          ? clamp(parsed.contrast, 0.75, 1.35)
          : DEFAULT_READER_SETTINGS.contrast,
      grayscale: typeof parsed.grayscale === 'boolean' ? parsed.grayscale : DEFAULT_READER_SETTINGS.grayscale,
      invertColors: typeof parsed.invertColors === 'boolean' ? parsed.invertColors : DEFAULT_READER_SETTINGS.invertColors,
      pageGap:
        typeof parsed.pageGap === 'number' && Number.isFinite(parsed.pageGap)
          ? clamp(Math.round(parsed.pageGap), 0, 24)
          : DEFAULT_READER_SETTINGS.pageGap,
      maxWidth:
        typeof parsed.maxWidth === 'number' && Number.isFinite(parsed.maxWidth)
          ? parsed.maxWidth === 0
            ? 0
            : clamp(Math.round(parsed.maxWidth), 480, 1400)
          : DEFAULT_READER_SETTINGS.maxWidth,
      widthUnit: VALID_UNITS.has(String(parsed.widthUnit))
        ? (parsed.widthUnit as WidthUnit)
        : DEFAULT_READER_SETTINGS.widthUnit,
      maxWidthPct:
        typeof parsed.maxWidthPct === 'number' && Number.isFinite(parsed.maxWidthPct)
          ? clamp(Math.round(parsed.maxWidthPct), 50, 100)
          : DEFAULT_READER_SETTINGS.maxWidthPct,
      doubleTapZoom:
        typeof parsed.doubleTapZoom === 'number' && Number.isFinite(parsed.doubleTapZoom)
          ? clamp(parsed.doubleTapZoom, 1.5, 3)
          : DEFAULT_READER_SETTINGS.doubleTapZoom,
      keepZoomAcrossPages:
        typeof parsed.keepZoomAcrossPages === 'boolean'
          ? parsed.keepZoomAcrossPages
          : DEFAULT_READER_SETTINGS.keepZoomAcrossPages,
      autoScrollSpeed:
        typeof parsed.autoScrollSpeed === 'number' && Number.isFinite(parsed.autoScrollSpeed)
          ? clamp(parsed.autoScrollSpeed, 0.5, 3)
          : DEFAULT_READER_SETTINGS.autoScrollSpeed,
      preloadCount:
        typeof parsed.preloadCount === 'number' && Number.isFinite(parsed.preloadCount)
          ? clamp(Math.round(parsed.preloadCount), 1, 6)
          : DEFAULT_READER_SETTINGS.preloadCount,
      preloadWifiOnly:
        typeof parsed.preloadWifiOnly === 'boolean' ? parsed.preloadWifiOnly : DEFAULT_READER_SETTINGS.preloadWifiOnly,
      webtoonTapScroll:
        typeof parsed.webtoonTapScroll === 'boolean' ? parsed.webtoonTapScroll : DEFAULT_READER_SETTINGS.webtoonTapScroll,
      verticalSeekbar: VALID_SEEKBAR.has(String(parsed.verticalSeekbar))
        ? (parsed.verticalSeekbar as VerticalSeekbarSide)
        : DEFAULT_READER_SETTINGS.verticalSeekbar,
      tapZoneLayout: VALID_TAPS.has(String(parsed.tapZoneLayout))
        ? (parsed.tapZoneLayout as TapZoneLayout)
        : DEFAULT_READER_SETTINGS.tapZoneLayout,
      invertTapZones:
        typeof parsed.invertTapZones === 'boolean' ? parsed.invertTapZones : DEFAULT_READER_SETTINGS.invertTapZones,
      showTapZonesOverlay:
        typeof parsed.showTapZonesOverlay === 'boolean'
          ? parsed.showTapZonesOverlay
          : DEFAULT_READER_SETTINGS.showTapZonesOverlay,
      confirmChapterSwipe:
        typeof parsed.confirmChapterSwipe === 'boolean'
          ? parsed.confirmChapterSwipe
          : DEFAULT_READER_SETTINGS.confirmChapterSwipe,
      showPageIndicator:
        typeof parsed.showPageIndicator === 'boolean'
          ? parsed.showPageIndicator
          : DEFAULT_READER_SETTINGS.showPageIndicator,
      showModeToast:
        typeof parsed.showModeToast === 'boolean' ? parsed.showModeToast : DEFAULT_READER_SETTINGS.showModeToast,
      hideChromeOnScroll:
        typeof parsed.hideChromeOnScroll === 'boolean'
          ? parsed.hideChromeOnScroll
          : DEFAULT_READER_SETTINGS.hideChromeOnScroll,
      showChromeOnScrollUp:
        typeof parsed.showChromeOnScrollUp === 'boolean'
          ? parsed.showChromeOnScrollUp
          : DEFAULT_READER_SETTINGS.showChromeOnScrollUp,
      scrollHideSensitivity: VALID_SENS.has(String(parsed.scrollHideSensitivity))
        ? (parsed.scrollHideSensitivity as ScrollHideSensitivity)
        : DEFAULT_READER_SETTINGS.scrollHideSensitivity,
      autoHideChrome:
        typeof parsed.autoHideChrome === 'boolean' ? parsed.autoHideChrome : DEFAULT_READER_SETTINGS.autoHideChrome,
      autoHideDelayMs:
        typeof parsed.autoHideDelayMs === 'number' && Number.isFinite(parsed.autoHideDelayMs)
          ? clamp(Math.round(parsed.autoHideDelayMs), 0, 15000)
          : DEFAULT_READER_SETTINGS.autoHideDelayMs,
      pageTransition: VALID_TRANSITIONS.has(String(parsed.pageTransition))
        ? (parsed.pageTransition as PageTransition)
        : DEFAULT_READER_SETTINGS.pageTransition,
      keepAwake: typeof parsed.keepAwake === 'boolean' ? parsed.keepAwake : DEFAULT_READER_SETTINGS.keepAwake,
      orientationLock: VALID_ORIENT.has(String(parsed.orientationLock))
        ? (parsed.orientationLock as OrientationLock)
        : DEFAULT_READER_SETTINGS.orientationLock,
      seamlessNextChapter:
        typeof parsed.seamlessNextChapter === 'boolean'
          ? parsed.seamlessNextChapter
          : DEFAULT_READER_SETTINGS.seamlessNextChapter,
      alwaysShowChapterDivider:
        typeof parsed.alwaysShowChapterDivider === 'boolean'
          ? parsed.alwaysShowChapterDivider
          : DEFAULT_READER_SETTINGS.alwaysShowChapterDivider,
      cropBorders: typeof parsed.cropBorders === 'boolean' ? parsed.cropBorders : DEFAULT_READER_SETTINGS.cropBorders,
      skipReadChapters:
        typeof parsed.skipReadChapters === 'boolean'
          ? parsed.skipReadChapters
          : DEFAULT_READER_SETTINGS.skipReadChapters,
      dataSaver: typeof parsed.dataSaver === 'boolean' ? parsed.dataSaver : DEFAULT_READER_SETTINGS.dataSaver,
      haptics: typeof parsed.haptics === 'boolean' ? parsed.haptics : DEFAULT_READER_SETTINGS.haptics,
      einkFlash: typeof parsed.einkFlash === 'boolean' ? parsed.einkFlash : DEFAULT_READER_SETTINGS.einkFlash,
    };
  } catch {
    return { ...DEFAULT_READER_SETTINGS };
  }
}

export function saveGlobalReaderSettings(settings: ReaderSettings): void {
  Prefs.set(GLOBAL_KEY, JSON.stringify(settings));
}

export function loadSeriesReaderOverride(slug: string): SeriesReaderOverride | null {
  if (!slug) return null;
  const raw = Prefs.getString(SERIES_PREFIX + slug);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as Partial<ReaderSettings>;
    if (!parsed || typeof parsed !== 'object') return null;
    const out: SeriesReaderOverride = {};
    for (const key of Object.keys(DEFAULT_READER_SETTINGS) as Array<keyof ReaderSettings>) {
      if (parsed[key] !== undefined && typeof parsed[key] === typeof DEFAULT_READER_SETTINGS[key]) {
        (out as Record<string, unknown>)[key] = parsed[key];
      }
    }
    return Object.keys(out).length > 0 ? out : null;
  } catch {
    return null;
  }
}

export function saveSeriesReaderOverride(slug: string, override: SeriesReaderOverride | null): void {
  if (!slug) return;
  if (!override || Object.keys(override).length === 0) {
    Prefs.remove(SERIES_PREFIX + slug);
    return;
  }
  Prefs.set(SERIES_PREFIX + slug, JSON.stringify(override));
}

export function loadResumeAnchor(slug: string, chapterId: string): ResumeAnchor | null {
  if (!slug || !chapterId) return null;
  const raw = Prefs.getString(RESUME_PREFIX + slug);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as {
      chapters?: Record<string, { pageIdx: number; offsetRatio: number }>;
      chapterId?: string;
      pageIdx?: number;
      offsetRatio?: number;
    };
    const entry = parsed.chapters?.[chapterId] ?? (parsed.chapterId === chapterId ? parsed : undefined);
    if (!entry || typeof entry.pageIdx !== 'number' || typeof entry.offsetRatio !== 'number') return null;
    return {
      chapterId,
      pageIdx: Math.max(0, Math.floor(entry.pageIdx)),
      offsetRatio: clamp(entry.offsetRatio, 0, 1),
    };
  } catch {
    return null;
  }
}

export function saveResumeAnchor(slug: string, anchor: ResumeAnchor): void {
  if (!slug || !anchor.chapterId) return;
  let existing: Record<string, { pageIdx: number; offsetRatio: number }> = {};
  try {
    const raw = Prefs.getString(RESUME_PREFIX + slug);
    if (raw) {
      const parsed = JSON.parse(raw) as { chapters?: Record<string, { pageIdx: number; offsetRatio: number }> };
      if (parsed.chapters && typeof parsed.chapters === 'object') existing = { ...parsed.chapters };
    }
  } catch {
    // Reset malformed cache
  }
  delete existing[anchor.chapterId];
  existing[anchor.chapterId] = {
    pageIdx: Math.max(0, Math.floor(anchor.pageIdx)),
    offsetRatio: Number(clamp(anchor.offsetRatio, 0, 1).toFixed(3)),
  };
  const keys = Object.keys(existing);
  while (keys.length > 12) {
    const oldest = keys.shift();
    if (oldest) delete existing[oldest];
  }
  Prefs.set(RESUME_PREFIX + slug, JSON.stringify({ chapters: existing }));
}

/** Returns the median aspect ratio observed across cached chapters of this series, or 0.68 fallback. */
export function loadSeriesDefaultAspect(slug: string): number {
  if (!slug) return 0.68;
  const raw = Prefs.getString(ASPECTS_PREFIX + slug);
  if (!raw) return 0.68;
  try {
    const parsed = JSON.parse(raw) as { chapters?: Record<string, Record<string, number>> };
    if (!parsed.chapters) return 0.68;
    const values: number[] = [];
    for (const chMap of Object.values(parsed.chapters)) {
      for (const v of Object.values(chMap)) {
        if (typeof v === 'number' && v > 0.1 && v < 4) values.push(v);
      }
    }
    if (values.length === 0) return 0.68;
    values.sort((a, b) => a - b);
    return values[Math.floor(values.length / 2)];
  } catch {
    return 0.68;
  }
}

/** Persists per-page aspect ratios for up to 12 recent chapters per series (LRU) so cold-open resume & spreads never jump. */
export function loadChapterAspects(slug: string, chapterId: string): Record<number, number> {
  if (!slug || !chapterId) return {};
  const raw = Prefs.getString(ASPECTS_PREFIX + slug);
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw) as { chapters?: Record<string, Record<string, number>>; chapterId?: string; ratios?: Record<string, number> };
    const map = parsed.chapters?.[chapterId] ?? (parsed.chapterId === chapterId ? parsed.ratios : undefined);
    if (!map) return {};
    const out: Record<number, number> = {};
    for (const [k, v] of Object.entries(map)) {
      const idx = Number(k);
      if (Number.isInteger(idx) && idx >= 0 && typeof v === 'number' && v > 0.05 && v < 10) {
        out[idx] = v;
      }
    }
    return out;
  } catch {
    return {};
  }
}

export function saveChapterAspects(slug: string, chapterId: string, ratios: Record<number, number>): void {
  if (!slug || !chapterId) return;
  const entries = Object.entries(ratios).slice(0, 180);
  if (entries.length === 0) return;
  const compact: Record<string, number> = {};
  for (const [k, v] of entries) {
    compact[k] = Number(v.toFixed(3));
  }
  let existing: Record<string, Record<string, number>> = {};
  try {
    const raw = Prefs.getString(ASPECTS_PREFIX + slug);
    if (raw) {
      const parsed = JSON.parse(raw) as { chapters?: Record<string, Record<string, number>> };
      if (parsed.chapters && typeof parsed.chapters === 'object') existing = { ...parsed.chapters };
    }
  } catch {
    // Reset malformed cache
  }
  delete existing[chapterId];
  existing[chapterId] = compact;
  const keys = Object.keys(existing);
  while (keys.length > 12) {
    const oldest = keys.shift();
    if (oldest) delete existing[oldest];
  }
  Prefs.set(ASPECTS_PREFIX + slug, JSON.stringify({ chapters: existing }));
}

export function loadPageBookmarks(slug: string): PageBookmark[] {
  if (!slug) return [];
  const raw = Prefs.getString(BOOKMARKS_PREFIX + slug);
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw) as PageBookmark[];
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter((b) => b && typeof b.chapterId === 'string' && typeof b.pageIdx === 'number')
      .slice(0, 50);
  } catch {
    return [];
  }
}

export function savePageBookmarks(slug: string, bookmarks: PageBookmark[]): void {
  if (!slug) return;
  Prefs.set(BOOKMARKS_PREFIX + slug, JSON.stringify(bookmarks.slice(0, 50)));
}

export function hasSeenReaderHint(): boolean {
  return Prefs.getBool(HINT_SEEN_KEY) === true;
}

export function markReaderHintSeen(): void {
  Prefs.set(HINT_SEEN_KEY, true);
}
