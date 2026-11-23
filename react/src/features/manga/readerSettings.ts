import { Prefs } from '../../core/system/prefs';
import { KATANA_BASE_PALETTES } from './katanaTokens';

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

export type FitModeBucket = 'webtoon' | 'single' | 'double' | 'strip';

export const FIT_MODE_BUCKET_LABEL: Record<FitModeBucket, string> = {
  webtoon: 'Webtoon',
  single: 'Single Page',
  double: 'Double Page',
  strip: 'Horizontal Strip',
};

export function getFitModeBucket(effectiveMode: ReadingMode): FitModeBucket {
  if (effectiveMode === 'webtoon') return 'webtoon';
  if (effectiveMode === 'double-rtl' || effectiveMode === 'double-ltr') return 'double';
  if (effectiveMode === 'strip-rtl' || effectiveMode === 'strip-ltr') return 'strip';
  return 'single';
}

export type ReaderBackground = 'auto' | 'oled' | 'dark' | 'gray' | 'sepia' | 'white';

export type TapZoneLayout = 'standard' | 'kindle' | 'l-shaped' | 'edge' | 'disabled';

export type PageTransition = 'slide' | 'fade' | 'none';

export type ScrollHideSensitivity = 'low' | 'medium' | 'high';

export type OrientationLock = 'auto' | 'portrait' | 'landscape';

export type WidthUnit = 'px' | 'pct';

export type VerticalSeekbarSide = 'off' | 'right' | 'left';

export type ZoomStartPosition = 'automatic' | 'left' | 'right' | 'center';

export interface ReaderSettings {
  readingMode: ReadingMode;
  fitMode: FitMode;
  fitByMode?: Partial<Record<FitModeBucket, FitMode>>;
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
  webtoonSidePadding: number;
  maxWidth: number;
  widthUnit: WidthUnit;
  maxWidthPct: number;
  doubleTapZoom: number;
  disableZoomOut: boolean;
  zoomStartPosition: ZoomStartPosition;
  keepZoomAcrossPages: boolean;
  guidedPanelZoom: boolean;
  autoScrollSpeed: number;
  preloadCount: number;
  preloadWifiOnly: boolean;
  webtoonTapScroll: boolean;
  verticalSeekbar: VerticalSeekbarSide;
  tapZoneLayout: TapZoneLayout;
  invertTapZones: boolean;
  volumeKeys: boolean;
  invertVolumeKeys: boolean;
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
  skipDuplicateChapters: boolean;
  skipFilteredChapters: boolean;
  dataSaver: boolean;
  haptics: boolean;
  einkFlash: boolean;
}

export interface SeriesChapterFilter {
  lang?: string;
  group?: string;
  preferredGroup?: string;
  blockedGroups?: string[];
  waitForPreferredHours?: number;
}

export type SeriesReaderOverride = Partial<ReaderSettings>;

export interface ResumeAnchor {
  chapterId: string;
  pageIdx: number;
  offsetRatio: number;
  updatedAt?: number;
}

export interface PageBookmark {
  chapterId: string;
  chapterTitle: string;
  pageIdx: number;
  createdAt: number;
  note?: string;
}

export const DEFAULT_READER_SETTINGS: ReaderSettings = {
  readingMode: 'auto-rtl',
  fitMode: 'smart-fit',
  fitByMode: {
    webtoon: 'fit-width',
    single: 'smart-fit',
    double: 'fit-screen',
    strip: 'fit-height',
  },
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
  webtoonSidePadding: 0,
  maxWidth: 850,
  widthUnit: 'px',
  maxWidthPct: 85,
  doubleTapZoom: 2,
  disableZoomOut: false,
  zoomStartPosition: 'automatic',
  keepZoomAcrossPages: false,
  guidedPanelZoom: false,
  autoScrollSpeed: 1,
  preloadCount: 3,
  preloadWifiOnly: false,
  webtoonTapScroll: false,
  verticalSeekbar: 'off',
  tapZoneLayout: 'standard',
  invertTapZones: false,
  volumeKeys: true,
  invertVolumeKeys: false,
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
  skipDuplicateChapters: true,
  skipFilteredChapters: false,
  dataSaver: false,
  haptics: true,
  einkFlash: false,
};

export const READER_BACKGROUNDS: Record<
  Exclude<ReaderBackground, 'auto'>,
  { label: string; bg: string; fg: string; swatch: string }
> = {
  oled: { label: 'True Black', bg: KATANA_BASE_PALETTES.oled.bg, fg: KATANA_BASE_PALETTES.oled.fg, swatch: KATANA_BASE_PALETTES.oled.bg },
  dark: { label: 'Katana Night', bg: KATANA_BASE_PALETTES.dark.bg, fg: KATANA_BASE_PALETTES.dark.fg, swatch: KATANA_BASE_PALETTES.dark.surface },
  gray: { label: 'Slate', bg: '#1B1B22', fg: '#F3F2F7', swatch: '#2A2A35' },
  sepia: { label: 'Warm Paper', bg: KATANA_BASE_PALETTES.sepia.bg, fg: KATANA_BASE_PALETTES.sepia.fg, swatch: KATANA_BASE_PALETTES.sepia.surface },
  white: { label: 'Paper White', bg: KATANA_BASE_PALETTES.light.bg, fg: KATANA_BASE_PALETTES.light.fg, swatch: KATANA_BASE_PALETTES.light.surface },
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
    desc: 'Picks right-to-left for manga, left-to-right for comics',
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
  webtoon: { label: 'Webtoon (long strip)', shortLabel: 'Webtoon', icon: 'view_day', isRtl: false, isDouble: false, isAuto: false, isWebtoon: true, isHorizontalStrip: false },
  'auto-rtl': { label: 'Manga, right to left', shortLabel: 'Right to left', icon: 'devices', isRtl: true, isDouble: false, isAuto: true, isWebtoon: false, isHorizontalStrip: false },
  'auto-ltr': { label: 'Comic, left to right', shortLabel: 'Left to right', icon: 'devices', isRtl: false, isDouble: false, isAuto: true, isWebtoon: false, isHorizontalStrip: false },
  'paged-rtl': { label: 'Manga, right to left', shortLabel: 'Right to left', icon: 'menu_book', isRtl: true, isDouble: false, isAuto: false, isWebtoon: false, isHorizontalStrip: false },
  'paged-ltr': { label: 'Comic, left to right', shortLabel: 'Left to right', icon: 'auto_stories', isRtl: false, isDouble: false, isAuto: false, isWebtoon: false, isHorizontalStrip: false },
  'double-rtl': { label: 'Two pages, right to left', shortLabel: '2 pages · RTL', icon: 'chrome_reader_mode', isRtl: true, isDouble: true, isAuto: false, isWebtoon: false, isHorizontalStrip: false },
  'double-ltr': { label: 'Two pages, left to right', shortLabel: '2 pages · LTR', icon: 'import_contacts', isRtl: false, isDouble: true, isAuto: false, isWebtoon: false, isHorizontalStrip: false },
  'strip-rtl': { label: 'Strip, right to left', shortLabel: 'Strip · RTL', icon: 'view_carousel', isRtl: true, isDouble: false, isAuto: false, isWebtoon: false, isHorizontalStrip: true },
  'strip-ltr': { label: 'Strip, left to right', shortLabel: 'Strip · LTR', icon: 'view_week', isRtl: false, isDouble: false, isAuto: false, isWebtoon: false, isHorizontalStrip: true },
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
const CHAPTER_FILTER_PREFIX = 'katana_reader_ch_filter_v1_';
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
const VALID_ZOOM_START = new Set<string>(['automatic', 'left', 'right', 'center']);

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
      fitByMode: (() => {
        const out: Partial<Record<FitModeBucket, FitMode>> = { ...(DEFAULT_READER_SETTINGS.fitByMode ?? {}) };
        if (parsed.fitByMode && typeof parsed.fitByMode === 'object') {
          for (const bucket of ['webtoon', 'single', 'double', 'strip'] as const) {
            const candidate = (parsed.fitByMode as Record<string, unknown>)[bucket];
            if (typeof candidate === 'string' && VALID_FITS.has(candidate)) {
              out[bucket] = candidate as FitMode;
            }
          }
        }
        return out;
      })(),
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
      webtoonSidePadding:
        typeof parsed.webtoonSidePadding === 'number' && Number.isFinite(parsed.webtoonSidePadding)
          ? clamp(Math.round(parsed.webtoonSidePadding), 0, 25)
          : DEFAULT_READER_SETTINGS.webtoonSidePadding,
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
      disableZoomOut:
        typeof parsed.disableZoomOut === 'boolean'
          ? parsed.disableZoomOut
          : DEFAULT_READER_SETTINGS.disableZoomOut,
      zoomStartPosition: VALID_ZOOM_START.has(String(parsed.zoomStartPosition))
        ? (parsed.zoomStartPosition as ZoomStartPosition)
        : DEFAULT_READER_SETTINGS.zoomStartPosition,
      keepZoomAcrossPages:
        typeof parsed.keepZoomAcrossPages === 'boolean'
          ? parsed.keepZoomAcrossPages
          : DEFAULT_READER_SETTINGS.keepZoomAcrossPages,
      guidedPanelZoom:
        typeof parsed.guidedPanelZoom === 'boolean'
          ? parsed.guidedPanelZoom
          : DEFAULT_READER_SETTINGS.guidedPanelZoom,
      autoScrollSpeed:
        typeof parsed.autoScrollSpeed === 'number' && Number.isFinite(parsed.autoScrollSpeed)
          ? clamp(parsed.autoScrollSpeed, 0.5, 3)
          : DEFAULT_READER_SETTINGS.autoScrollSpeed,
      preloadCount:
        typeof parsed.preloadCount === 'number' && Number.isFinite(parsed.preloadCount)
          ? parsed.preloadCount >= 99
            ? 99
            : clamp(Math.round(parsed.preloadCount), 1, 6)
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
      volumeKeys:
        typeof parsed.volumeKeys === 'boolean' ? parsed.volumeKeys : DEFAULT_READER_SETTINGS.volumeKeys,
      invertVolumeKeys:
        typeof parsed.invertVolumeKeys === 'boolean'
          ? parsed.invertVolumeKeys
          : DEFAULT_READER_SETTINGS.invertVolumeKeys,
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
      skipDuplicateChapters:
        typeof parsed.skipDuplicateChapters === 'boolean'
          ? parsed.skipDuplicateChapters
          : DEFAULT_READER_SETTINGS.skipDuplicateChapters,
      skipFilteredChapters:
        typeof parsed.skipFilteredChapters === 'boolean'
          ? parsed.skipFilteredChapters
          : DEFAULT_READER_SETTINGS.skipFilteredChapters,
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

export interface StoredChapterResumeEntry {
  pageIdx: number;
  offsetRatio: number;
  updatedAt: number;
}

/**
 * Loads the per-chapter map of fine-grained reading positions (page index + vertical scroll ratio
 * + timestamp). Synced across phone and tablet via Firestore `reader_state` (`hydrateMangaReaderSeriesState`
 * / `syncMangaReaderSeriesState`) and cached locally in `Prefs` for instant offline cold-open.
 */
export function loadAllResumeAnchors(slug: string): Record<string, StoredChapterResumeEntry> {
  if (!slug) return {};
  const raw = Prefs.getString(RESUME_PREFIX + slug);
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw) as {
      chapters?: Record<string, { pageIdx: number; offsetRatio: number; updatedAt?: number }>;
      chapterId?: string;
      pageIdx?: number;
      offsetRatio?: number;
      updatedAt?: number;
    };
    const out: Record<string, StoredChapterResumeEntry> = {};
    if (parsed.chapters && typeof parsed.chapters === 'object') {
      for (const [chId, entry] of Object.entries(parsed.chapters)) {
        if (entry && typeof entry.pageIdx === 'number' && typeof entry.offsetRatio === 'number') {
          out[chId] = {
            pageIdx: Math.max(0, Math.floor(entry.pageIdx)),
            offsetRatio: Number(clamp(entry.offsetRatio, 0, 1).toFixed(3)),
            updatedAt: typeof entry.updatedAt === 'number' ? entry.updatedAt : 0,
          };
        }
      }
    } else if (parsed.chapterId && typeof parsed.pageIdx === 'number' && typeof parsed.offsetRatio === 'number') {
      out[parsed.chapterId] = {
        pageIdx: Math.max(0, Math.floor(parsed.pageIdx)),
        offsetRatio: Number(clamp(parsed.offsetRatio, 0, 1).toFixed(3)),
        updatedAt: typeof parsed.updatedAt === 'number' ? parsed.updatedAt : 0,
      };
    }
    return out;
  } catch {
    return {};
  }
}

export function loadResumeAnchor(slug: string, chapterId: string): ResumeAnchor | null {
  if (!slug || !chapterId) return null;
  const all = loadAllResumeAnchors(slug);
  const entry = all[chapterId];
  if (!entry) return null;
  return {
    chapterId,
    pageIdx: entry.pageIdx,
    offsetRatio: entry.offsetRatio,
    updatedAt: entry.updatedAt,
  };
}

export function saveResumeAnchor(slug: string, anchor: ResumeAnchor): void {
  if (!slug || !anchor.chapterId) return;
  const existing = loadAllResumeAnchors(slug);
  const now = typeof anchor.updatedAt === 'number' && anchor.updatedAt > 0 ? anchor.updatedAt : Date.now();
  delete existing[anchor.chapterId];
  existing[anchor.chapterId] = {
    pageIdx: Math.max(0, Math.floor(anchor.pageIdx)),
    offsetRatio: Number(clamp(anchor.offsetRatio, 0, 1).toFixed(3)),
    updatedAt: now,
  };
  const keys = Object.keys(existing);
  while (keys.length > 12) {
    const oldest = keys.shift();
    if (oldest) delete existing[oldest];
  }
  Prefs.set(RESUME_PREFIX + slug, JSON.stringify({ chapters: existing }));
}

/**
 * Merges Firestore-synced resume anchors from another device (e.g. phone -> tablet) into the local
 * cache using `updatedAt` timestamps so the freshest reading position always wins across devices.
 */
export function mergeRemoteResumeAnchors(
  slug: string,
  remoteResume?: ResumeAnchor | null,
  remoteChapters?: Record<string, { pageIdx: number; offsetRatio: number; updatedAt?: number }> | null,
  remoteDocUpdatedAt?: number,
): { mergedChapters: Record<string, StoredChapterResumeEntry>; updatedChapterIds: Set<string> } {
  const local = loadAllResumeAnchors(slug);
  const updatedChapterIds = new Set<string>();
  const applyCandidate = (chId: string, cand: { pageIdx: number; offsetRatio: number; updatedAt?: number }) => {
    if (!chId || typeof cand.pageIdx !== 'number' || typeof cand.offsetRatio !== 'number') return;
    const candTime =
      typeof cand.updatedAt === 'number' && cand.updatedAt > 0
        ? cand.updatedAt
        : typeof remoteDocUpdatedAt === 'number' && remoteDocUpdatedAt > 0
          ? remoteDocUpdatedAt
          : 1;
    const cur = local[chId];
    if (!cur || candTime > (cur.updatedAt || 0)) {
      local[chId] = {
        pageIdx: Math.max(0, Math.floor(cand.pageIdx)),
        offsetRatio: Number(clamp(cand.offsetRatio, 0, 1).toFixed(3)),
        updatedAt: candTime,
      };
      updatedChapterIds.add(chId);
    }
  };
  if (remoteChapters && typeof remoteChapters === 'object') {
    for (const [chId, entry] of Object.entries(remoteChapters)) {
      if (entry) applyCandidate(chId, entry);
    }
  }
  if (remoteResume && remoteResume.chapterId) {
    applyCandidate(remoteResume.chapterId, remoteResume);
  }
  if (updatedChapterIds.size > 0) {
    Prefs.set(RESUME_PREFIX + slug, JSON.stringify({ chapters: local }));
  }
  return { mergedChapters: local, updatedChapterIds };
}

export function clearResumeAnchor(slug: string): void {
  if (!slug) return;
  Prefs.remove(RESUME_PREFIX + slug);
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

export function loadSeriesChapterFilter(slug: string): SeriesChapterFilter | null {
  if (!slug) return null;
  const raw = Prefs.getString(CHAPTER_FILTER_PREFIX + slug);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as SeriesChapterFilter;
    if (!parsed || typeof parsed !== 'object') return null;
    const lang = typeof parsed.lang === 'string' && parsed.lang.trim() ? parsed.lang.trim() : undefined;
    const group = typeof parsed.group === 'string' && parsed.group.trim() ? parsed.group.trim() : undefined;
    const preferredGroup =
      typeof parsed.preferredGroup === 'string' && parsed.preferredGroup.trim()
        ? parsed.preferredGroup.trim()
        : undefined;
    const blockedGroups = Array.isArray(parsed.blockedGroups)
      ? Array.from(new Set(parsed.blockedGroups.map((g) => String(g).trim()).filter(Boolean)))
      : undefined;
    const waitForPreferredHours =
      typeof parsed.waitForPreferredHours === 'number' && parsed.waitForPreferredHours > 0
        ? Math.min(168, Math.round(parsed.waitForPreferredHours))
        : undefined;
    return lang || group || preferredGroup || (blockedGroups && blockedGroups.length > 0) || waitForPreferredHours
      ? {
          lang,
          group,
          preferredGroup,
          ...(blockedGroups && blockedGroups.length > 0 ? { blockedGroups } : {}),
          ...(waitForPreferredHours ? { waitForPreferredHours } : {}),
        }
      : null;
  } catch {
    return null;
  }
}

export function saveSeriesChapterFilter(slug: string, filter: SeriesChapterFilter | null): void {
  if (!slug) return;
  const blocked = Array.isArray(filter?.blockedGroups)
    ? Array.from(new Set(filter.blockedGroups.map((g) => String(g).trim()).filter(Boolean)))
    : [];
  const waitHrs =
    typeof filter?.waitForPreferredHours === 'number' && filter.waitForPreferredHours > 0
      ? Math.min(168, Math.round(filter.waitForPreferredHours))
      : undefined;
  if (!filter || (!filter.lang && !filter.group && !filter.preferredGroup && blocked.length === 0 && !waitHrs)) {
    Prefs.remove(CHAPTER_FILTER_PREFIX + slug);
    return;
  }
  Prefs.set(
    CHAPTER_FILTER_PREFIX + slug,
    JSON.stringify({
      ...(filter.lang ? { lang: filter.lang } : {}),
      ...(filter.group ? { group: filter.group } : {}),
      ...(filter.preferredGroup ? { preferredGroup: filter.preferredGroup } : {}),
      ...(blocked.length > 0 ? { blockedGroups: blocked } : {}),
      ...(waitHrs ? { waitForPreferredHours: waitHrs } : {}),
    }),
  );
}

export interface ReaderBackupBundle {
  globalSettings: ReaderSettings;
  seriesOverrides: Record<string, SeriesReaderOverride>;
  pageBookmarks: Record<string, PageBookmark[]>;
  resumeAnchors: Record<string, Record<string, { pageIdx: number; offsetRatio: number }>>;
}

/** Collects global reader settings, per-series overrides, page bookmarks, and resume anchors for full-backup export. */
export function exportReaderBackupData(slugs: string[]): ReaderBackupBundle {
  const uniqueSlugs = Array.from(new Set(slugs.filter(Boolean)));
  const seriesOverrides: Record<string, SeriesReaderOverride> = {};
  const pageBookmarks: Record<string, PageBookmark[]> = {};
  const resumeAnchors: Record<string, Record<string, { pageIdx: number; offsetRatio: number }>> = {};
  for (const slug of uniqueSlugs) {
    const ov = loadSeriesReaderOverride(slug);
    if (ov && Object.keys(ov).length > 0) seriesOverrides[slug] = ov;
    const bms = loadPageBookmarks(slug);
    if (bms.length > 0) pageBookmarks[slug] = bms;
    const rawResume = Prefs.getString(RESUME_PREFIX + slug);
    if (rawResume) {
      try {
        const parsed = JSON.parse(rawResume) as { chapters?: Record<string, { pageIdx: number; offsetRatio: number }> };
        if (parsed.chapters && Object.keys(parsed.chapters).length > 0) {
          resumeAnchors[slug] = parsed.chapters;
        }
      } catch {
        // ignore malformed anchor cache
      }
    }
  }
  return {
    globalSettings: loadGlobalReaderSettings(),
    seriesOverrides,
    pageBookmarks,
    resumeAnchors,
  };
}

/** Restores reader settings, per-series overrides, page bookmarks, and resume anchors from a full backup. */
export function importReaderBackupData(bundle: unknown): void {
  if (!bundle || typeof bundle !== 'object') return;
  const rec = bundle as Partial<ReaderBackupBundle>;
  if (rec.globalSettings && typeof rec.globalSettings === 'object') {
    saveGlobalReaderSettings({ ...loadGlobalReaderSettings(), ...rec.globalSettings });
  }
  if (rec.seriesOverrides && typeof rec.seriesOverrides === 'object') {
    for (const [slug, ov] of Object.entries(rec.seriesOverrides)) {
      if (slug && ov && typeof ov === 'object') saveSeriesReaderOverride(slug, ov);
    }
  }
  if (rec.pageBookmarks && typeof rec.pageBookmarks === 'object') {
    for (const [slug, bms] of Object.entries(rec.pageBookmarks)) {
      if (slug && Array.isArray(bms)) savePageBookmarks(slug, bms);
    }
  }
  if (rec.resumeAnchors && typeof rec.resumeAnchors === 'object') {
    for (const [slug, chapters] of Object.entries(rec.resumeAnchors)) {
      if (!slug || !chapters || typeof chapters !== 'object') continue;
      for (const [chapterId, anchor] of Object.entries(chapters)) {
        if (chapterId && anchor && typeof anchor.pageIdx === 'number' && typeof anchor.offsetRatio === 'number') {
          saveResumeAnchor(slug, { chapterId, pageIdx: anchor.pageIdx, offsetRatio: anchor.offsetRatio });
        }
      }
    }
  }
}

export function hasSeenReaderHint(): boolean {
  return Prefs.getBool(HINT_SEEN_KEY) === true;
}

export function markReaderHintSeen(): void {
  Prefs.set(HINT_SEEN_KEY, true);
}
