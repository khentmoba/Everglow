import type { KatanaChapter } from './katanaService';
import type { ReadingMode, TapZoneLayout } from './readerSettings';

export type TapAction = 'prev' | 'next' | 'toggle-ui';

export interface SpreadSlot {
  pageIndex: number;
  cropHalf?: 'left' | 'right';
}

/**
 * Builds page groups ("spreads") for paged and double-page reading modes.
 * - Single-page modes emit one page per spread; when `splitWidePages` is true,
 *   detected wide landscape spreads split into two half-page turns in reading order
 *   (right-then-left for RTL, left-then-right for LTR).
 * - Double-page modes pair adjacent pages, keeping page 0 solo when `coverOffset` is true
 *   and keeping detected wide landscape spreads solo when `autoSpreadWide` is true.
 */
export function buildSpreads(
  pageCount: number,
  mode: ReadingMode,
  coverOffset: boolean,
  widePages: ReadonlySet<number>,
  autoSpreadWide = true,
  splitWidePages = false,
): SpreadSlot[][] {
  if (pageCount <= 0) return [];
  const isDouble = mode === 'double-rtl' || mode === 'double-ltr';
  const isRtl = mode === 'paged-rtl' || mode === 'double-rtl';

  if (!isDouble) {
    const out: SpreadSlot[][] = [];
    for (let i = 0; i < pageCount; i++) {
      if (splitWidePages && widePages.has(i)) {
        const first: 'left' | 'right' = isRtl ? 'right' : 'left';
        const second: 'left' | 'right' = isRtl ? 'left' : 'right';
        out.push([{ pageIndex: i, cropHalf: first }]);
        out.push([{ pageIndex: i, cropHalf: second }]);
      } else {
        out.push([{ pageIndex: i }]);
      }
    }
    return out;
  }

  const spreads: SpreadSlot[][] = [];
  let i = 0;
  if (coverOffset && pageCount > 0) {
    spreads.push([{ pageIndex: 0 }]);
    i = 1;
  }
  while (i < pageCount) {
    const curWide = autoSpreadWide && widePages.has(i);
    const nextWide = autoSpreadWide && i + 1 < pageCount && widePages.has(i + 1);
    if (curWide || i + 1 >= pageCount || nextWide) {
      spreads.push([{ pageIndex: i }]);
      i += 1;
    } else {
      spreads.push([{ pageIndex: i }, { pageIndex: i + 1 }]);
      i += 2;
    }
  }
  return spreads;
}

export function findSpreadIndexForPage(spreads: SpreadSlot[][], pageIndex: number): number {
  if (spreads.length === 0) return 0;
  const clamped = Math.max(0, pageIndex);
  const found = spreads.findIndex((group) => group.some((slot) => slot.pageIndex === clamped));
  return found >= 0 ? found : spreads.length - 1;
}

/**
 * Resolves a normalized tap position (xRatio, yRatio in [0, 1]) into a navigation action.
 * Respects RTL/LTR reading direction and the user's invert-tap-zones preference.
 */
export function resolveTapZoneAction(
  xRatio: number,
  yRatio: number,
  layout: TapZoneLayout,
  isRtl: boolean,
  invert: boolean,
): TapAction {
  if (layout === 'disabled') return 'toggle-ui';

  if (layout === 'standard') {
    if (xRatio >= 0.3 && xRatio <= 0.7) return 'toggle-ui';
    const tappedLeft = xRatio < 0.3;
    const forward = isRtl ? tappedLeft : !tappedLeft;
    return (invert ? !forward : forward) ? 'next' : 'prev';
  }

  if (layout === 'edge') {
    if (xRatio >= 0.22 && xRatio <= 0.78) return 'toggle-ui';
    const tappedLeft = xRatio < 0.22;
    const forward = isRtl ? tappedLeft : !tappedLeft;
    return (invert ? !forward : forward) ? 'next' : 'prev';
  }

  if (layout === 'l-shaped') {
    // Mihon L-shaped: top 25% goes back, center 35%..65% x 25%..75% toggles HUD, rest advances forward
    if (yRatio < 0.25) return invert ? 'next' : 'prev';
    if (xRatio >= 0.3 && xRatio <= 0.7 && yRatio >= 0.25 && yRatio <= 0.75) return 'toggle-ui';
    const isBackSide = isRtl ? xRatio > 0.7 : xRatio < 0.3;
    const forward = !isBackSide || yRatio > 0.75;
    return (invert ? !forward : forward) ? 'next' : 'prev';
  }

  // Kindle layout: top 22% toggles UI; narrow back edge goes back; large area goes forward.
  if (yRatio < 0.22) return 'toggle-ui';
  const backEdge = isRtl ? xRatio > 0.75 : xRatio < 0.25;
  const forward = !backEdge;
  return (invert ? !forward : forward) ? 'next' : 'prev';
}

function normalizedChapterKey(ch: KatanaChapter | undefined): string {
  if (!ch) return '';
  const raw = (ch.num || '').trim();
  if (!raw) return '';
  const n = Number.parseFloat(raw);
  return Number.isFinite(n) ? String(n) : raw.toLowerCase();
}

/**
 * Katana chapter lists are ordered newest-first (index 0 is latest chapter,
 * index length - 1 is Chapter 1).
 */
export function adjacentChapter(
  chapters: KatanaChapter[],
  currentId: string,
  direction: 'prev' | 'next',
  options?: {
    skipRead?: boolean;
    readIds?: ReadonlySet<string>;
    skipDuplicate?: boolean;
    allowedIds?: ReadonlySet<string>;
  },
): KatanaChapter | null {
  const idx = chapters.findIndex((c) => c.id === currentId);
  if (idx < 0) return null;
  const currentNumKey = normalizedChapterKey(chapters[idx]);
  const step = direction === 'next' ? -1 : 1;
  let cursor = idx + step;
  while (cursor >= 0 && cursor < chapters.length) {
    const candidate = chapters[cursor];
    const isDuplicate =
      Boolean(options?.skipDuplicate) &&
      currentNumKey !== '' &&
      normalizedChapterKey(candidate) === currentNumKey;
    const isFilteredOut =
      options?.allowedIds != null &&
      options.allowedIds.size > 0 &&
      !options.allowedIds.has(candidate.id);
    const isRead = Boolean(options?.skipRead) && Boolean(options?.readIds?.has(candidate.id));
    if (!isDuplicate && !isFilteredOut && !isRead) {
      return candidate;
    }
    cursor += step;
  }
  const immediate = chapters[idx + step];
  return immediate ?? null;
}

export interface GuidedPanelRect {
  x: number;
  y: number;
  w: number;
  h: number;
}

/**
 * Builds ordered panel rectangles in normalized [0, 1] coordinates for guided panel-by-panel zoom.
 * Uses detected panel boxes when available, or a reading-order manga quadrant grid with gentle overlap
 * so speech bubbles near panel borders remain readable on small screens.
 */
export function buildGuidedPanels(
  aspectRatio: number,
  isRtl: boolean,
  detectedPanels?: GuidedPanelRect[],
): GuidedPanelRect[] {
  if (detectedPanels && detectedPanels.length >= 2) {
    return [...detectedPanels].sort((a, b) => {
      const rowDiff = Math.abs(a.y - b.y);
      if (rowDiff > 0.14) return a.y - b.y;
      return isRtl ? b.x - a.x : a.x - b.x;
    });
  }
  const cols = 2;
  const rows = aspectRatio >= 1.25 ? 2 : 3;
  const overlapX = 0.06;
  const overlapY = 0.05;
  const baseW = 1 / cols;
  const baseH = 1 / rows;
  const panels: GuidedPanelRect[] = [];
  for (let r = 0; r < rows; r++) {
    const colOrder = isRtl ? [1, 0] : [0, 1];
    for (const c of colOrder) {
      const x0 = Math.max(0, c * baseW - overlapX / 2);
      const y0 = Math.max(0, r * baseH - overlapY / 2);
      const x1 = Math.min(1, (c + 1) * baseW + overlapX / 2);
      const y1 = Math.min(1, (r + 1) * baseH + overlapY / 2);
      panels.push({ x: x0, y: y0, w: x1 - x0, h: y1 - y0 });
    }
  }
  return panels;
}

/**
 * Computes zoom and clamped pan offsets to center a guided panel rect inside the reader viewport.
 */
export function computeGuidedPanelTransform(
  panel: GuidedPanelRect,
  stageWidth: number,
  stageHeight: number,
  contentWidth: number,
  contentHeight: number,
): { zoom: number; pan: { x: number; y: number } } {
  if (stageWidth <= 0 || stageHeight <= 0 || contentWidth <= 0 || contentHeight <= 0) {
    return { zoom: 1.8, pan: { x: 0, y: 0 } };
  }
  const panelPxW = Math.max(1, panel.w * contentWidth);
  const panelPxH = Math.max(1, panel.h * contentHeight);
  const fitZoom = Math.min((stageWidth * 0.94) / panelPxW, (stageHeight * 0.88) / panelPxH);
  const zoom = Number(Math.min(2.6, Math.max(1.45, fitZoom)).toFixed(2));
  const centerX = panel.x + panel.w / 2;
  const centerY = panel.y + panel.h / 2;
  const rawPanX = (0.5 - centerX) * contentWidth * zoom;
  const rawPanY = (0.5 - centerY) * contentHeight * zoom;
  return {
    zoom,
    pan: clampZoomPan(rawPanX, rawPanY, contentWidth, contentHeight, stageWidth, stageHeight, zoom),
  };
}

export const WIDE_ASPECT_THRESHOLD = 1.32;

export function isWideAspect(width: number, height: number): boolean {
  return width > 0 && height > 0 && width / height >= WIDE_ASPECT_THRESHOLD;
}

export const DOUBLE_TAP_WINDOW_MS = 240;
export const SINGLE_TAP_DELAY_MS = 265;

/**
 * Clamps pan offsets based on scaled content dimensions vs viewport dimensions
 * so every corner of a zoomed or original-fit page is reachable without hitting an invisible wall.
 */
export function clampZoomPan(
  panX: number,
  panY: number,
  contentWidth: number,
  contentHeight: number,
  viewportWidth: number,
  viewportHeight: number,
  zoom: number,
): { x: number; y: number } {
  if (zoom <= 1 && contentWidth <= viewportWidth && contentHeight <= viewportHeight) {
    return { x: 0, y: 0 };
  }
  const scaledW = Math.max(viewportWidth, contentWidth) * zoom;
  const scaledH = Math.max(viewportHeight, contentHeight) * zoom;
  const maxX = Math.max(0, (scaledW - viewportWidth) / 2);
  const maxY = Math.max(0, (scaledH - viewportHeight) / 2);
  return {
    x: Math.round(Math.min(maxX, Math.max(-maxX, panX))),
    y: Math.round(Math.min(maxY, Math.max(-maxY, panY))),
  };
}

/**
 * Computes pan offsets so zooming to `targetZoom` keeps the tapped point
 * `(xRatio, yRatio)` anchored under the user's finger/cursor.
 */
export function computeTapAnchoredPan(
  xRatio: number,
  yRatio: number,
  stageWidth: number,
  stageHeight: number,
  targetZoom: number,
): { x: number; y: number } {
  if (targetZoom <= 1 || stageWidth <= 0 || stageHeight <= 0) return { x: 0, y: 0 };
  const dx = (0.5 - xRatio) * stageWidth * (targetZoom - 1);
  const dy = (0.5 - yRatio) * stageHeight * (targetZoom - 1);
  return clampZoomPan(dx, dy, stageWidth, stageHeight, stageWidth, stageHeight, targetZoom);
}

/**
 * Computes pan during a two-finger pinch gesture so the midpoint between the fingers
 * stays pinned to the exact same image coordinate as scale changes.
 */
export function computePinchAnchoredPan(
  startPan: { x: number; y: number },
  startScale: number,
  nextScale: number,
  midXRatio: number,
  midYRatio: number,
  stageWidth: number,
  stageHeight: number,
): { x: number; y: number } {
  if (nextScale <= 1.02 || stageWidth <= 0 || stageHeight <= 0) return { x: 0, y: 0 };
  const ratio = nextScale / Math.max(0.01, startScale);
  const offsetX = (midXRatio - 0.5) * stageWidth;
  const offsetY = (midYRatio - 0.5) * stageHeight;
  const nextX = offsetX - (offsetX - startPan.x) * ratio;
  const nextY = offsetY - (offsetY - startPan.y) * ratio;
  return clampZoomPan(nextX, nextY, stageWidth, stageHeight, stageWidth, stageHeight, nextScale);
}

export type SeriesReadingFormat = 'webtoon' | 'manga' | 'comic';

/** Infers reading direction/format from series genres/tags so manhwa opens as webtoon and manga opens RTL. */
export function inferSeriesReadingFormat(
  genres?: readonly string[],
  title?: string,
  demographic?: string,
): SeriesReadingFormat {
  const tokens = [
    ...(genres ?? []),
    demographic ?? '',
    title ?? '',
  ]
    .join(' ')
    .toLowerCase();
  if (/\b(manhwa|manhua|webtoon|long\s*strip|web\s*comic)\b/.test(tokens)) {
    return 'webtoon';
  }
  if (/\b(comic|western|graphic\s*novel)\b/.test(tokens)) {
    return 'comic';
  }
  return 'manga';
}

/**
 * Resolves `auto-rtl` / `auto-ltr` into:
 * - `'webtoon'` when series metadata indicates manhwa/manhua/webtoon OR tall strips (`medianAspect < 0.56`)
 * - `'double-rtl'` / `'double-ltr'` on tablets/desktop (`width >= 820 && (width > height || allowPortraitTabletSpread)`)
 * - `'paged-rtl'` / `'paged-ltr'` on phones.
 */
export function resolveEffectiveReadingMode(
  mode: ReadingMode,
  viewportWidth: number,
  viewportHeight: number,
  medianAspect?: number,
  seriesFormat?: SeriesReadingFormat,
  allowPortraitTabletSpread = false,
): ReadingMode {
  if (mode === 'auto-rtl' || mode === 'auto-ltr') {
    if (seriesFormat === 'webtoon' || (typeof medianAspect === 'number' && medianAspect > 0 && medianAspect < 0.56)) {
      return 'webtoon';
    }
    const isTabletSpread = viewportWidth >= 820 && (viewportWidth > viewportHeight || allowPortraitTabletSpread);
    if (seriesFormat === 'comic') return isTabletSpread ? 'double-ltr' : 'paged-ltr';
    if (mode === 'auto-rtl') return isTabletSpread ? 'double-rtl' : 'paged-rtl';
    return isTabletSpread ? 'double-ltr' : 'paged-ltr';
  }
  return mode;
}

/** Detects missing whole chapter numbers between two chapters (e.g. Ch. 41 -> Ch. 43 returns 1). */
export function detectChapterGap(from: KatanaChapter | null | undefined, to: KatanaChapter | null | undefined): number {
  if (!from || !to) return 0;
  const a = Number.parseFloat(from.num);
  const b = Number.parseFloat(to.num);
  if (!Number.isFinite(a) || !Number.isFinite(b)) return 0;
  const diff = Math.floor(Math.abs(b - a)) - 1;
  return diff > 0 ? diff : 0;
}

/** True LRU insert into a bounded Map (evicts oldest entry, never wholesale-clears). */
export function setLruEntry<K, V>(map: Map<K, V>, key: K, value: V, maxSize: number): void {
  if (map.has(key)) map.delete(key);
  map.set(key, value);
  while (map.size > maxSize) {
    const oldest = map.keys().next().value;
    if (oldest === undefined) break;
    map.delete(oldest);
  }
}
