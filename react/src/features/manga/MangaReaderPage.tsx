import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { AgentMode } from '../../core/agent/agentMode';
import { useAuth } from '../../core/services/auth';
import { OfflineIds, offlineMedia } from '../../core/services/offlineMedia';
import { useViewport } from '../../core/system/viewport';
import { withAlpha } from '../../core/theme/colors';
import { motionReduced, reduceAmbientMotion } from '../../core/theme/motion';
import { Icon } from '../../shared/widgets/Icon';
import { canPop } from '../../shared/widgets/MaterialFields';
import {
  chapterDisplayTitle,
  fetchKatanaChapterPages,
  hydrateMangaReaderGlobalSettings,
  hydrateMangaReaderSeriesState,
  isKatanaIncognitoSession,
  markKatanaChaptersRead,
  proxyKatanaImageUrl,
  saveKatanaReadingProgress,
  setKatanaIncognitoSession,
  setKatanaSeriesCover,
  subscribeKatanaIncognitoSession,
  syncMangaReaderGlobalSettings,
  syncMangaReaderSeriesState,
  type KatanaChapter,
} from './katanaService';
import { KatanaColors, KatanaType } from './katanaTokens';
import { createDemoMangaReaderParams, getDemoChapterPages } from './readerDemo';
import { normalizeAssetUrl, ReaderPageImage, resolveReaderImageUrl } from './ReaderPageImage';
import {
  getFitModeBucket,
  hasSeenReaderHint,
  loadAllResumeAnchors,
  loadChapterAspects,
  loadGlobalReaderSettings,
  loadPageBookmarks,
  loadResumeAnchor,
  loadSeriesChapterFilter,
  loadSeriesDefaultAspect,
  loadSeriesReaderOverride,
  markReaderHintSeen,
  mergeRemoteResumeAnchors,
  READING_MODE_META,
  READING_MODE_ORDER,
  resolveBackgroundTheme,
  saveChapterAspects,
  saveGlobalReaderSettings,
  savePageBookmarks,
  saveResumeAnchor,
  saveSeriesReaderOverride,
  SCROLL_HIDE_THRESHOLD,
  SERVER_OPTIONS,
  type PageBookmark,
  type ReaderSettings,
  type SeriesReaderOverride,
} from './readerSettings';
import { ChapterDrawerSheet, PageActionSheet, PageJumpDialog, QuickDisplayPopover, ReaderSettingsSheet } from './ReaderSheets';
import {
  adjacentChapter,
  buildGuidedPanels,
  buildSpreads,
  clampZoomPan,
  computeGuidedPanelTransform,
  computePinchAnchoredPan,
  computeTapAnchoredPan,
  detectChapterGap,
  DOUBLE_TAP_WINDOW_MS,
  findSpreadIndexForPage,
  isWideAspect,
  loadPersistedSeriesFormat,
  resolveEffectiveReadingMode,
  resolveTapZoneAction,
  savePersistedSeriesFormat,
  setLruEntry,
  SINGLE_TAP_DELAY_MS,
  WIDE_ASPECT_THRESHOLD,
  type GuidedPanelRect,
  type SeriesReadingFormat,
} from './readerSpread';

export interface MangaReaderParams {
  slug: string;
  chapterId: string;
  mangaTitle: string;
  coverUrl: string;
  chapters: KatanaChapter[];
  initialPage?: number;
  /** The series status; a finished read needs `completed`. */
  mangaStatus?: string;
  /** The series' last chapter; reaching its last page finishes the read. */
  finalChapterId?: string;
  /** Already-read chapter IDs for chapter drawer badges & skip-read navigation. */
  readChapterIds?: string[];
  /** Inferred content format (manga / webtoon / comic) for content-aware Auto reading mode. */
  seriesFormat?: SeriesReadingFormat;
}

interface ChapterSegment {
  chapter: KatanaChapter;
  pages: string[];
}

const MAX_PREFETCH_CACHE = 16;
const MAX_ASPECT_CACHE = 240;

export function MangaReaderView({
  params,
  onClose,
}: {
  params: MangaReaderParams;
  onClose: () => void;
}) {
  const { currentUser } = useAuth();
  const { width: viewportWidth, height: viewportHeight } = useViewport();
  const allowBlur = !reduceAmbientMotion(viewportWidth, viewportHeight);
  const rootRef = useRef<HTMLDivElement>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const stageContentRef = useRef<HTMLDivElement>(null);
  const hudTopRef = useRef<HTMLDivElement>(null);
  const hudBottomRef = useRef<HTMLDivElement>(null);
  const [hudInset, setHudInset] = useState({ top: 0, bottom: 0 });
  const [osColorTick, setOsColorTick] = useState(0);

  useEffect(() => {
    const measure = () => {
      const top = hudTopRef.current?.offsetHeight ?? 0;
      const bottom = hudBottomRef.current?.offsetHeight ?? 0;
      setHudInset((prev) => (prev.top === top && prev.bottom === bottom ? prev : { top, bottom }));
    };
    measure();
    if (typeof ResizeObserver === 'undefined') return;
    const ro = new ResizeObserver(measure);
    if (hudTopRef.current) ro.observe(hudTopRef.current);
    if (hudBottomRef.current) ro.observe(hudBottomRef.current);
    return () => ro.disconnect();
  }, []);

  useEffect(() => {
    const mq = window.matchMedia?.('(prefers-color-scheme: light)');
    if (!mq?.addEventListener) return;
    const onChange = () => setOsColorTick((t) => t + 1);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);

  const canFullscreen = useMemo(() => {
    if (typeof document === 'undefined') return false;
    const doc = document as Document & { webkitFullscreenEnabled?: boolean };
    const el = document.documentElement as HTMLElement & { webkitRequestFullscreen?: () => Promise<void> | void };
    return Boolean((doc.fullscreenEnabled || doc.webkitFullscreenEnabled) && (el.requestFullscreen || el.webkitRequestFullscreen));
  }, []);

  const seriesDefaultAspect = useMemo(() => loadSeriesDefaultAspect(params.slug), [params.slug]);
  const [persistedFormat, setPersistedFormat] = useState<SeriesReadingFormat | undefined>(() =>
    loadPersistedSeriesFormat(params.slug),
  );
  const [liveMedianAspect, setLiveMedianAspect] = useState<number | undefined>(undefined);

  // Settings & expanded per-series overrides (with per-reading-mode fit memory)
  const [globalSettings, setGlobalSettings] = useState<ReaderSettings>(() => loadGlobalReaderSettings());
  const [seriesOverride, setSeriesOverride] = useState<SeriesReaderOverride | null>(() =>
    loadSeriesReaderOverride(params.slug),
  );
  const rawReadingMode = seriesOverride?.readingMode ?? globalSettings.readingMode;
  const effectiveSeriesFormat = persistedFormat ?? params.seriesFormat;
  const effectiveMode = useMemo(
    () =>
      resolveEffectiveReadingMode(
        rawReadingMode,
        viewportWidth,
        viewportHeight,
        liveMedianAspect ?? seriesDefaultAspect,
        effectiveSeriesFormat,
      ),
    [rawReadingMode, viewportWidth, viewportHeight, liveMedianAspect, seriesDefaultAspect, effectiveSeriesFormat],
  );
  const fitBucket = getFitModeBucket(effectiveMode);
  const settings: ReaderSettings = useMemo(() => {
    const merged: ReaderSettings = {
      ...globalSettings,
      ...(seriesOverride ?? {}),
    };
    const mergedFitByMode = {
      ...(globalSettings.fitByMode ?? {}),
      ...(seriesOverride?.fitByMode ?? {}),
    };
    const modeFit = mergedFitByMode[fitBucket];
    return {
      ...merged,
      fitByMode: mergedFitByMode,
      fitMode: modeFit ?? merged.fitMode,
    };
  }, [globalSettings, seriesOverride, fitBucket]);
  const modeMeta = READING_MODE_META[settings.readingMode];
  const effectiveMeta = READING_MODE_META[effectiveMode];
  const resolvedModeShortLabel =
    effectiveMode !== settings.readingMode
      ? `${effectiveMeta.shortLabel} (Auto)`
      : effectiveMeta.shortLabel;
  const resolvedModeAriaLabel =
    effectiveMode !== settings.readingMode
      ? `${effectiveMeta.label} (${modeMeta.label})`
      : effectiveMeta.label;
  const isWebtoon = effectiveMeta.isWebtoon;
  const isHorizontalStrip = effectiveMeta.isHorizontalStrip;
  const isRtl = effectiveMeta.isRtl;
  const isDouble = effectiveMeta.isDouble;
  const bgTheme = useMemo(() => {
    void osColorTick;
    return resolveBackgroundTheme(settings.background);
  }, [settings.background, osColorTick]);

  // Keep document root background aligned with the reader surface to prevent couple-plum overscroll flashes.
  useEffect(() => {
    const html = document.documentElement;
    const body = document.body;
    const root = document.getElementById('root');
    const prevHtmlBg = html.style.backgroundColor;
    const prevBodyBg = body.style.backgroundColor;
    const prevRootBg = root?.style.backgroundColor ?? '';
    html.style.backgroundColor = bgTheme.bg;
    body.style.backgroundColor = bgTheme.bg;
    if (root) root.style.backgroundColor = bgTheme.bg;
    return () => {
      html.style.backgroundColor = prevHtmlBg;
      body.style.backgroundColor = prevBodyBg;
      if (root) root.style.backgroundColor = prevRootBg;
    };
  }, [bgTheme.bg]);

  // Chapter, pages, bookmarks & finished-read state
  const [chapterId, setChapterId] = useState(params.chapterId);
  const [segments, setSegments] = useState<ChapterSegment[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadFailed, setLoadFailed] = useState(false);
  const [appendingNext, setAppendingNext] = useState(false);
  const [reloadNonce, setReloadNonce] = useState(0);
  const [server, setServer] = useState('');
  const [pageIdx, setPageIdx] = useState(Math.max(0, (params.initialPage ?? 1) - 1));
  const [spreadCursor, setSpreadCursor] = useState(0);
  const [readIds, setReadIds] = useState<Set<string>>(() => new Set(params.readChapterIds ?? []));
  const [pageBookmarks, setPageBookmarks] = useState<PageBookmark[]>(() => loadPageBookmarks(params.slug));

  // Page natural dimensions (seeded from persisted aspects to prevent cold-open resume drift & spread reflow)
  const [widePages, setWidePages] = useState<Set<number>>(() => {
    const saved = loadChapterAspects(params.slug, params.chapterId);
    const w = new Set<number>();
    for (const [idxStr, ratio] of Object.entries(saved)) {
      if (ratio >= WIDE_ASPECT_THRESHOLD) w.add(Number(idxStr));
    }
    return w;
  });
  const aspectMapRef = useRef<Map<string, number>>(new Map());
  const chapterAspectsRef = useRef<Record<number, number>>({});
  const aspectSaveTimerRef = useRef(0);
  const [pageReloadTokens, setPageReloadTokens] = useState<Record<string, number>>({});

  // Chrome, sheets, toast, hints & auto-scroll
  const [showUi, setShowUi] = useState(true);
  const [activeSheet, setActiveSheet] = useState<'none' | 'chapters' | 'settings' | 'jump' | 'quick-display'>('none');
  const [pageAction, setPageAction] = useState<{ url: string; pageNumber: number; key: string } | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [showTapHint, setShowTapHint] = useState(false);
  const [seenOnboardingHint, setSeenOnboardingHint] = useState(() => hasSeenReaderHint());

  // The controls pill is the last thing on the page; it steps aside too, and any
  // tap on the page brings the chrome (and the pill) back.
  const [pillQuiet, setPillQuiet] = useState(false);
  useEffect(() => {
    if (showUi) {
      setPillQuiet(false);
      return;
    }
    const timer = window.setTimeout(() => setPillQuiet(true), 3200);
    return () => window.clearTimeout(timer);
  }, [showUi, pageIdx, chapterId]);

  // The tip sits over the artwork, so it steps aside on its own after a few seconds.
  useEffect(() => {
    if (seenOnboardingHint) return;
    const timer = window.setTimeout(() => setSeenOnboardingHint(true), 5200);
    return () => window.clearTimeout(timer);
  }, [seenOnboardingHint]);
  const [evictedOfflineState, setEvictedOfflineState] = useState<{
    itemId: string;
    missingPages: number;
    totalPages: number;
  } | null>(null);
  const [repairingOffline, setRepairingOffline] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [autoScrolling, setAutoScrolling] = useState(false);
  const [einkFlashing, setEinkFlashing] = useState(false);
  const [isPinching, setIsPinching] = useState(false);
  const [failedPageKeys, setFailedPageKeys] = useState<string[]>([]);
  const [adaptiveBgColor, setAdaptiveBgColor] = useState<string | null>(null);
  const [transitionDir, setTransitionDir] = useState<'next' | 'prev' | 'fade'>('fade');
  const lastWheelTurnRef = useRef(0);

  // Zoom & pan
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [guidedPanelIdx, setGuidedPanelIdx] = useState(0);
  const [detectedPanelsByKey, setDetectedPanelsByKey] = useState<Record<string, GuidedPanelRect[]>>({});
  const [sleepTimerEndAt, setSleepTimerEndAt] = useState<number | null>(null);
  const [sleepWaitChapterEnd, setSleepWaitChapterEnd] = useState(false);
  const [sleepPendingChapterEnd, setSleepPendingChapterEnd] = useState(false);
  const [sleepTimerExpired, setSleepTimerExpired] = useState(false);
  const [incognitoSession, setIncognitoSession] = useState(() => isKatanaIncognitoSession());

  useEffect(() => subscribeKatanaIncognitoSession(setIncognitoSession), []);
  const cloudResumeTimerRef = useRef(0);
  const pinchStartRef = useRef<{ dist: number; scale: number; pan: { x: number; y: number } } | null>(null);
  const dragStartRef = useRef<{ x: number; y: number; panX: number; panY: number } | null>(null);
  const swipeStartRef = useRef<{ x: number; y: number; time: number } | null>(null);
  const lastSwipeAtRef = useRef(0);
  const chapterEdgeGuardRef = useRef<{ dir: 'prev' | 'next'; at: number } | null>(null);
  const lastTapRef = useRef<{ time: number; x: number; y: number } | null>(null);
  const tapTimerRef = useRef<number | null>(null);

  // Scroll tracking, O(1) IntersectionObserver, exact-line resume, virtualization & prefetch refs
  const pageElMapRef = useRef<Map<string, HTMLDivElement>>(new Map());
  const segmentElMapRef = useRef<Map<string, HTMLDivElement>>(new Map());
  const activeKeyRef = useRef<string>(`${params.chapterId}:${Math.max(0, (params.initialPage ?? 1) - 1)}`);
  const initialAnchor = useMemo(() => loadResumeAnchor(params.slug, params.chapterId), [params.slug, params.chapterId]);
  const pendingResumeRef = useRef<{ chapterId: string; pageIdx: number; offsetRatio: number } | null>(
    initialAnchor
      ? { chapterId: params.chapterId, pageIdx: initialAnchor.pageIdx, offsetRatio: initialAnchor.offsetRatio }
      : { chapterId: params.chapterId, pageIdx: Math.max(0, (params.initialPage ?? 1) - 1), offsetRatio: 0 },
  );
  const userScrolledRef = useRef(false);
  const programmaticScrollRef = useRef(false);
  const programmaticScrollTimerRef = useRef(0);
  const scrollRafRef = useRef<number | null>(null);
  const lastScrollTopRef = useRef(0);
  const scrollDownAccumRef = useRef(0);
  const scrollUpAccumRef = useRef(0);
  const saveTimerRef = useRef(0);
  const toastTimerRef = useRef(0);
  const idleTimerRef = useRef(0);
  const einkTimerRef = useRef(0);
  const workingCdnStepRef = useRef(0);
  const prefetchedImagesRef = useRef<Map<string, HTMLImageElement>>(new Map());
  const prefetchedChapterRef = useRef<Map<string, string[]>>(new Map());
  const segmentsRef = useRef<ChapterSegment[]>(segments);
  segmentsRef.current = segments;
  const explicitNavRef = useRef(false);
  const navEpochRef = useRef(0);
  const lastLoadKeyRef = useRef('');
  const offlineBlobUrlsRef = useRef<Set<string>>(new Set());
  const appendingNextRef = useRef(false);
  const prependingPrevRef = useRef(false);
  const latestProgressRef = useRef({
    chapterId: params.chapterId,
    page: Math.max(1, params.initialPage ?? 1),
    offsetRatio: initialAnchor?.offsetRatio ?? 0,
    total: 0,
  });

  // Clear bounded caches & reload bookmarks on series change
  useEffect(() => {
    const blobs = offlineBlobUrlsRef.current;
    prefetchedImagesRef.current.clear();
    prefetchedChapterRef.current.clear();
    aspectMapRef.current.clear();
    setFailedPageKeys([]);
    setDetectedPanelsByKey({});
    setPageBookmarks(loadPageBookmarks(params.slug));
    return () => {
      offlineMedia.revokeBlobUrls(blobs);
      blobs.clear();
    };
  }, [params.slug]);

  const chapterById = useCallback(
    (id: string): KatanaChapter => params.chapters.find((c) => c.id === id) ?? { id, num: '', title: id },
    [params.chapters],
  );

  const activeChapter = useMemo(() => chapterById(chapterId), [chapterById, chapterId]);
  const activeSegment = useMemo(
    () => segments.find((s) => s.chapter.id === chapterId) ?? segments[0],
    [segments, chapterId],
  );
  const pages = activeSegment?.pages ?? [];

  const seriesChapterFilter = useMemo(
    () => (settings.skipFilteredChapters ? loadSeriesChapterFilter(params.slug) : null),
    [params.slug, settings.skipFilteredChapters],
  );
  const allowedChapterIds = useMemo(() => {
    if (!seriesChapterFilter) return undefined;
    const set = new Set<string>();
    for (const c of params.chapters) {
      if (seriesChapterFilter.lang && (c.language || '').trim().toLowerCase() !== seriesChapterFilter.lang) continue;
      if (seriesChapterFilter.group && (c.scanlationGroup || '').trim() !== seriesChapterFilter.group) continue;
      set.add(c.id);
    }
    return set.size > 0 ? set : undefined;
  }, [params.chapters, seriesChapterFilter]);

  const chapterNavOpts = useMemo(
    () => ({
      skipRead: settings.skipReadChapters,
      readIds,
      skipDuplicate: settings.skipDuplicateChapters,
      allowedIds: allowedChapterIds,
    }),
    [settings.skipReadChapters, settings.skipDuplicateChapters, readIds, allowedChapterIds],
  );

  const prevChapter = useMemo(
    () => adjacentChapter(params.chapters, chapterId, 'prev', chapterNavOpts),
    [params.chapters, chapterId, chapterNavOpts],
  );
  const nextChapter = useMemo(
    () => adjacentChapter(params.chapters, chapterId, 'next', chapterNavOpts),
    [params.chapters, chapterId, chapterNavOpts],
  );

  // Hydrate global reader settings & per-series state (override, resume anchor, bookmarks) from Firestore
  useEffect(() => {
    if (!currentUser) return;
    let alive = true;
    void hydrateMangaReaderGlobalSettings<ReaderSettings>(currentUser).then((remote) => {
      if (!alive || !remote) return;
      setGlobalSettings((prev) => {
        const merged = { ...prev, ...remote };
        saveGlobalReaderSettings(merged);
        return merged;
      });
    });
    return () => {
      alive = false;
    };
  }, [currentUser]);

  useEffect(() => {
    if (!currentUser || !params.slug) return;
    let alive = true;
    void hydrateMangaReaderSeriesState(currentUser, params.slug).then((remote) => {
      if (!alive || !remote) return;
      if (remote.override && Object.keys(remote.override).length > 0) {
        const nextOverride = remote.override as SeriesReaderOverride;
        setSeriesOverride(nextOverride);
        saveSeriesReaderOverride(params.slug, nextOverride);
      }
      if (remote.bookmarks && remote.bookmarks.length > 0) {
        setPageBookmarks((prev) => {
          const seen = new Set(prev.map((b) => `${b.chapterId}:${b.pageIdx}`));
          const merged = [...prev];
          for (const b of remote.bookmarks!) {
            if (!seen.has(`${b.chapterId}:${b.pageIdx}`)) merged.push(b);
          }
          savePageBookmarks(params.slug, merged);
          return merged;
        });
      }
      if (remote.resume || remote.resumeChapters) {
        const { mergedChapters, updatedChapterIds } = mergeRemoteResumeAnchors(
          params.slug,
          remote.resume,
          remote.resumeChapters,
          remote.updatedAt,
        );
        if (updatedChapterIds.has(chapterId) && !userScrolledRef.current) {
          const synced = mergedChapters[chapterId];
          if (synced) {
            pendingResumeRef.current = {
              chapterId,
              pageIdx: synced.pageIdx,
              offsetRatio: synced.offsetRatio,
            };
            setPageIdx(synced.pageIdx);
          }
        }
      }
    });
    return () => {
      alive = false;
    };
  }, [currentUser, params.slug]);

  const spreads = useMemo(
    () =>
      buildSpreads(
        pages.length,
        effectiveMode,
        settings.coverOffset,
        widePages,
        settings.autoSpreadWide,
        settings.splitWidePages,
      ),
    [pages.length, effectiveMode, settings.coverOffset, widePages, settings.autoSpreadWide, settings.splitWidePages],
  );

  const safeSpreadIdx = Math.min(Math.max(0, spreadCursor), Math.max(0, spreads.length - 1));
  const currentSpread = spreads[safeSpreadIdx] ?? (pages.length > 0 ? [{ pageIndex: 0 }] : []);

  useEffect(() => {
    if (spreads.length === 0) return;
    const currentSlots = spreads[safeSpreadIdx];
    if (!currentSlots || !currentSlots.some((s) => s.pageIndex === pageIdx)) {
      setSpreadCursor(findSpreadIndexForPage(spreads, pageIdx));
    }
  }, [spreads, pageIdx, safeSpreadIdx]);

  const triggerHaptic = useCallback(
    (ms = 8) => {
      if (!settings.haptics) return;
      try {
        navigator.vibrate?.(ms);
      } catch {
        // Unsupported on iOS Safari / desktop
      }
    },
    [settings.haptics],
  );

  const flashToast = useCallback(
    (msg: string, force = false) => {
      if (!force && !settings.showModeToast) return;
      setToast(msg);
      window.clearTimeout(toastTimerRef.current);
      toastTimerRef.current = window.setTimeout(() => setToast(null), 1900);
    },
    [settings.showModeToast],
  );

  const isPageBookmarked = useCallback(
    (targetChId: string, targetPageIdx: number) =>
      pageBookmarks.some((b) => b.chapterId === targetChId && b.pageIdx === targetPageIdx),
    [pageBookmarks],
  );

  const togglePageBookmark = useCallback(
    (targetChId: string, targetPageIdx: number) => {
      setPageBookmarks((prev) => {
        const exists = prev.some((b) => b.chapterId === targetChId && b.pageIdx === targetPageIdx);
        const next = exists
          ? prev.filter((b) => !(b.chapterId === targetChId && b.pageIdx === targetPageIdx))
          : [
              {
                chapterId: targetChId,
                chapterTitle: chapterDisplayTitle(chapterById(targetChId)),
                pageIdx: targetPageIdx,
                createdAt: Date.now(),
              },
              ...prev,
            ];
        savePageBookmarks(params.slug, next);
        if (currentUser) {
          void syncMangaReaderSeriesState(currentUser, params.slug, { bookmarks: next });
        }
        triggerHaptic(10);
        flashToast(exists ? `Removed bookmark (Page ${targetPageIdx + 1})` : `Bookmarked Page ${targetPageIdx + 1}`, true);
        return next;
      });
    },
    [chapterById, params.slug, currentUser, flashToast, triggerHaptic],
  );

  const updatePageBookmarkNote = useCallback(
    (targetBm: PageBookmark, note: string) => {
      setPageBookmarks((prev) => {
        const next = prev.map((b) =>
          b.chapterId === targetBm.chapterId && b.pageIdx === targetBm.pageIdx
            ? { ...b, note: note || undefined }
            : b,
        );
        savePageBookmarks(params.slug, next);
        if (currentUser) {
          void syncMangaReaderSeriesState(currentUser, params.slug, { bookmarks: next });
        }
        flashToast(note ? 'Saved Moment note' : 'Cleared Moment note', true);
        return next;
      });
    },
    [params.slug, currentUser, flashToast],
  );

  const updateSettings = useCallback(
    (patch: Partial<ReaderSettings>) => {
      const normalizedPatch: Partial<ReaderSettings> = patch.fitMode
        ? {
            ...patch,
            fitByMode: {
              ...(settings.fitByMode ?? {}),
              ...(patch.fitByMode ?? {}),
              [fitBucket]: patch.fitMode,
            },
          }
        : patch;
      if (seriesOverride) {
        const nextOverride: SeriesReaderOverride = { ...seriesOverride, ...normalizedPatch };
        setSeriesOverride(nextOverride);
        saveSeriesReaderOverride(params.slug, nextOverride);
        if (currentUser) {
          void syncMangaReaderSeriesState(currentUser, params.slug, { override: nextOverride });
        }
      } else {
        setGlobalSettings((prev) => {
          const next = { ...prev, ...normalizedPatch };
          saveGlobalReaderSettings(next);
          if (currentUser) {
            void syncMangaReaderGlobalSettings(currentUser, next);
          }
          return next;
        });
      }
      if (patch.guidedPanelZoom === false) {
        setZoom(1);
        setPan({ x: 0, y: 0 });
        setGuidedPanelIdx(0);
      } else if (patch.guidedPanelZoom === true) {
        setGuidedPanelIdx(0);
      }
      if (patch.readingMode) {
        setAutoScrolling(false);
        flashToast(READING_MODE_META[patch.readingMode].label, true);
        setZoom(1);
        setPan({ x: 0, y: 0 });
        if (patch.readingMode === 'webtoon') {
          pendingResumeRef.current = { chapterId, pageIdx, offsetRatio: 0 };
          userScrolledRef.current = false;
        } else if (!hasSeenReaderHint()) {
          setShowTapHint(true);
          markReaderHintSeen();
          window.setTimeout(() => setShowTapHint(false), 2800);
        }
      }
    },
    [seriesOverride, params.slug, currentUser, flashToast, chapterId, pageIdx, fitBucket, settings.fitByMode],
  );

  const toggleSeriesOverride = useCallback(
    (enabled: boolean) => {
      if (enabled) {
        const next: SeriesReaderOverride = { ...settings };
        setSeriesOverride(next);
        saveSeriesReaderOverride(params.slug, next);
        if (currentUser) {
          void syncMangaReaderSeriesState(currentUser, params.slug, { override: next });
        }
        flashToast('Saved custom settings for this series', true);
      } else {
        setSeriesOverride(null);
        saveSeriesReaderOverride(params.slug, null);
        if (currentUser) {
          void syncMangaReaderSeriesState(currentUser, params.slug, { override: null });
        }
        flashToast('Using global reader settings', true);
      }
    },
    [settings, params.slug, currentUser, flashToast],
  );

  const markChapterFinished = useCallback(
    (finishedChapterId: string) => {
      setReadIds((prev) => (prev.has(finishedChapterId) ? prev : new Set([...prev, finishedChapterId])));
      if (currentUser && !incognitoSession) {
        void markKatanaChaptersRead(
          {
            slug: params.slug,
            title: params.mangaTitle,
            coverUrl: params.coverUrl ?? '',
            status: params.mangaStatus ?? 'ongoing',
          },
          currentUser,
          [finishedChapterId],
          true,
        );
      }
      if (sleepTimerEndAt === -1 || sleepPendingChapterEnd) {
        setAutoScrolling(false);
        setSleepTimerExpired(true);
        setSleepTimerEndAt(null);
        setSleepPendingChapterEnd(false);
      }
    },
    [
      currentUser,
      incognitoSession,
      params.slug,
      params.mangaTitle,
      params.coverUrl,
      params.mangaStatus,
      sleepTimerEndAt,
      sleepPendingChapterEnd,
    ],
  );

  const writeProgressNow = useCallback(
    (
      targetChapterId: string,
      page: number,
      totalPages: number,
      offsetRatio = 0,
      allowMarkFinished = true,
      immediateCloudSync = false,
    ) => {
      const safePage = Math.max(1, page);
      const chapterCompleted = allowMarkFinished && totalPages > 0 && safePage >= totalPages;
      if (!incognitoSession) {
        const now = Date.now();
        const resumeAnchor = {
          chapterId: targetChapterId,
          pageIdx: safePage - 1,
          offsetRatio,
          updatedAt: now,
        };
        saveResumeAnchor(params.slug, resumeAnchor);
        if (currentUser) {
          window.clearTimeout(cloudResumeTimerRef.current);
          const pushCloud = () => {
            void syncMangaReaderSeriesState(currentUser, params.slug, {
              resume: resumeAnchor,
              resumeChapters: loadAllResumeAnchors(params.slug),
            });
          };
          if (immediateCloudSync) {
            pushCloud();
          } else {
            cloudResumeTimerRef.current = window.setTimeout(pushCloud, 900);
          }
        }
      }
      // Mark chapter finished only on active reading advance to the true final page
      if (chapterCompleted) {
        markChapterFinished(targetChapterId);
      }
      const ch = chapterById(targetChapterId);
      const finished =
        params.mangaStatus === 'completed' &&
        !!params.finalChapterId &&
        targetChapterId === params.finalChapterId &&
        chapterCompleted;
      const offlineId = OfflineIds.mangaChapterId(params.slug, targetChapterId);
      if (offlineMedia.getItem(offlineId) && !incognitoSession) {
        offlineMedia.updatePlaybackPosition(offlineId, safePage, true);
      }
      if (!currentUser || incognitoSession) return;
      void saveKatanaReadingProgress({
        slug: params.slug,
        userName: currentUser,
        chapterId: targetChapterId,
        chapterTitle: chapterDisplayTitle(ch),
        page: safePage,
        title: params.mangaTitle,
        coverUrl: params.coverUrl,
        finished,
        chapterCompleted,
      });
    },
    [
      chapterById,
      markChapterFinished,
      incognitoSession,
      params.mangaStatus,
      params.finalChapterId,
      params.slug,
      params.mangaTitle,
      params.coverUrl,
      currentUser,
    ],
  );

  const persistProgress = useCallback(
    (targetChapterId: string, page: number, totalPages: number, offsetRatio = 0) => {
      latestProgressRef.current = {
        chapterId: targetChapterId,
        page: Math.max(1, page),
        offsetRatio,
        total: totalPages,
      };
      window.clearTimeout(saveTimerRef.current);
      saveTimerRef.current = window.setTimeout(() => {
        writeProgressNow(targetChapterId, page, totalPages, offsetRatio);
      }, 350);
    },
    [writeProgressNow],
  );

  const flushProgressRef = useRef(writeProgressNow);
  flushProgressRef.current = writeProgressNow;

  // Flush progress & timers on unmount
  useEffect(() => {
    return () => {
      window.clearTimeout(saveTimerRef.current);
      window.clearTimeout(toastTimerRef.current);
      window.clearTimeout(idleTimerRef.current);
      window.clearTimeout(einkTimerRef.current);
      window.clearTimeout(aspectSaveTimerRef.current);
      window.clearTimeout(programmaticScrollTimerRef.current);
      window.clearTimeout(cloudResumeTimerRef.current);
      if (tapTimerRef.current != null) window.clearTimeout(tapTimerRef.current);
      if (scrollRafRef.current != null) window.cancelAnimationFrame(scrollRafRef.current);
      const latest = latestProgressRef.current;
      if (latest.total > 0) {
        flushProgressRef.current(latest.chapterId, latest.page, latest.total, latest.offsetRatio, true, true);
      }
    };
  }, []);

  const loadChapterPages = useCallback(
    async (targetChapterId: string, targetServer: string): Promise<string[]> => {
      const cacheKey = `${targetChapterId}|${targetServer}`;
      const cached = prefetchedChapterRef.current.get(cacheKey);
      if (cached && cached.length > 0) return cached;

      offlineMedia.init();
      const offlineItem = offlineMedia.getItem(OfflineIds.mangaChapterId(params.slug, targetChapterId));
      if (offlineItem && offlineItem.pageUrls.length > 0) {
        let evictedCount = 0;
        const demoFallback =
          AgentMode.demo && params.slug.startsWith('demo-') ? getDemoChapterPages(targetChapterId) : null;
        const resolved = await Promise.all(
          offlineItem.pageUrls.map(async (raw, i) => {
            const blobUrl = await offlineMedia.getMangaPageUrl(offlineItem.id, i + 1);
            if (blobUrl && (blobUrl.startsWith('blob:') || blobUrl.startsWith('data:'))) {
              if (blobUrl.startsWith('blob:')) offlineBlobUrlsRef.current.add(blobUrl);
              return blobUrl;
            }
            if (blobUrl && AgentMode.demo && blobUrl.startsWith('/images/demo/')) {
              return demoFallback?.[i] ?? blobUrl;
            }
            evictedCount += 1;
            if (demoFallback && demoFallback[i]) return demoFallback[i];
            const isOffline = typeof navigator !== 'undefined' && navigator.onLine === false;
            if (isOffline) return '';
            const candidate = normalizeAssetUrl(raw);
            return candidate.startsWith('http') ? proxyKatanaImageUrl(candidate) : candidate;
          }),
        );
        if (evictedCount > 0) {
          setEvictedOfflineState({
            itemId: offlineItem.id,
            missingPages: evictedCount,
            totalPages: offlineItem.pageUrls.length,
          });
        } else {
          setEvictedOfflineState(null);
        }
        const filtered = resolved.filter(Boolean);
        if (filtered.length > 0) {
          return filtered;
        }
      } else {
        setEvictedOfflineState(null);
      }

      if (AgentMode.demo && params.slug.startsWith('demo-')) {
        return getDemoChapterPages(targetChapterId);
      }

      const urls = await fetchKatanaChapterPages(params.slug, targetChapterId, targetServer);
      if (urls.length > 0) {
        setLruEntry(prefetchedChapterRef.current, cacheKey, urls, 12);
      }
      return urls;
    },
    [params.slug],
  );

  const navigateToChapter = useCallback(
    (targetId: string, options?: { startAtEnd?: boolean; targetPageIdx?: number; markPrevFinished?: boolean; warnGap?: boolean }) => {
      if (!targetId) return;
      if (options?.markPrevFinished && targetId !== chapterId) markChapterFinished(chapterId);
      if (options?.warnGap) {
        const fromChap = params.chapters.find((c) => c.id === chapterId);
        const toChap = params.chapters.find((c) => c.id === targetId);
        const gap = detectChapterGap(fromChap, toChap);
        if (gap > 0) {
          flashToast(`Note: ${gap} missing chapter${gap === 1 ? '' : 's'} between Ch. ${fromChap?.num} & Ch. ${toChap?.num}`, true);
        }
      }
      navEpochRef.current += 1;
      explicitNavRef.current = true;
      appendingNextRef.current = false;
      prependingPrevRef.current = false;
      setAppendingNext(false);
      setAutoScrolling(false);
      setZoom(1);
      setPan({ x: 0, y: 0 });
      setWidePages(new Set());
      setFailedPageKeys([]);
      const startPage = options?.startAtEnd ? -1 : (options?.targetPageIdx ?? 0);
      const existing = segmentsRef.current.find((s) => s.chapter.id === targetId);
      const resolvedStart =
        existing != null
          ? startPage === -1
            ? Math.max(0, existing.pages.length - 1)
            : Math.min(existing.pages.length - 1, Math.max(0, startPage))
          : Math.max(0, startPage);
      pendingResumeRef.current = {
        chapterId: targetId,
        pageIdx: existing != null ? resolvedStart : startPage,
        offsetRatio: 0,
      };
      userScrolledRef.current = false;
      setPageIdx(resolvedStart);
      setSpreadCursor(0);
      activeKeyRef.current = `${targetId}:${resolvedStart}`;
      if (existing) {
        setSegments([existing]);
        setLoading(false);
        setLoadFailed(false);
      } else {
        setSegments([]);
        setLoading(true);
        setLoadFailed(false);
      }
      if (targetId === chapterId) {
        if (scrollRef.current) {
          programmaticScrollRef.current = true;
          scrollRef.current.scrollTop = 0;
          scrollRef.current.scrollLeft = 0;
          lastScrollTopRef.current = 0;
          window.requestAnimationFrame(() => {
            programmaticScrollRef.current = false;
          });
        }
        explicitNavRef.current = false;
      } else {
        setChapterId(targetId);
      }
    },
    [chapterId, markChapterFinished, params.chapters, flashToast],
  );

  // Load active chapter & seed persisted aspect ratios before first paint
  useEffect(() => {
    let alive = true;
    window.clearTimeout(aspectSaveTimerRef.current);
    const loadKey = `${params.slug}|${server}|${reloadNonce}`;
    const forceReload = loadKey !== lastLoadKeyRef.current;
    const isExplicitNav = explicitNavRef.current;
    explicitNavRef.current = false;
    lastLoadKeyRef.current = loadKey;

    const savedAspects = loadChapterAspects(params.slug, chapterId);
    const seededAspects: Record<number, number> = { ...savedAspects };
    const seededWide = new Set<number>();
    for (const [idxStr, ratio] of Object.entries(savedAspects)) {
      const idx = Number(idxStr);
      aspectMapRef.current.set(`${chapterId}:${idx}`, ratio);
      if (ratio >= WIDE_ASPECT_THRESHOLD) seededWide.add(idx);
    }

    const existing = segmentsRef.current.find((s) => s.chapter.id === chapterId);
    if (existing) {
      for (let idx = 0; idx < existing.pages.length; idx++) {
        const measured = aspectMapRef.current.get(`${chapterId}:${idx}`);
        if (measured != null) {
          seededAspects[idx] = measured;
          if (measured >= WIDE_ASPECT_THRESHOLD) seededWide.add(idx);
        }
      }
    }
    chapterAspectsRef.current = seededAspects;
    setWidePages(seededWide);

    if (existing && !forceReload) {
      setLoading(false);
      setLoadFailed(false);
      if (isExplicitNav) {
        const resume = pendingResumeRef.current;
        const targetIdx =
          resume?.pageIdx === -1
            ? Math.max(0, existing.pages.length - 1)
            : resume != null
              ? Math.min(existing.pages.length - 1, Math.max(0, resume.pageIdx))
              : 0;
        if (resume) {
          pendingResumeRef.current = { chapterId, pageIdx: targetIdx, offsetRatio: resume.offsetRatio };
        }
        activeKeyRef.current = `${chapterId}:${targetIdx}`;
        setSegments([existing]);
        setPageIdx(targetIdx);
        if (targetIdx === 0 && scrollRef.current) {
          programmaticScrollRef.current = true;
          scrollRef.current.scrollTop = 0;
          scrollRef.current.scrollLeft = 0;
          lastScrollTopRef.current = 0;
          window.requestAnimationFrame(() => {
            programmaticScrollRef.current = false;
          });
        }
        const portraitTabletSpreadHint =
          viewportWidth >= 720 && viewportWidth <= viewportHeight && !isWebtoon && !isDouble
            ? ' • Rotate or tap Spread for 2-page view'
            : '';
        writeProgressNow(chapterId, targetIdx + 1, existing.pages.length, resume?.offsetRatio ?? 0, false);
        flashToast(`${resolvedModeShortLabel} • ${chapterDisplayTitle(existing.chapter)}${portraitTabletSpreadHint}`);
      }
      return;
    }

    if (forceReload) {
      navEpochRef.current += 1;
      appendingNextRef.current = false;
      prependingPrevRef.current = false;
      setAppendingNext(false);
    }

    setLoading(true);
    setLoadFailed(false);
    setSegments([]);

    void loadChapterPages(chapterId, server).then((urls) => {
      if (!alive) return;
      const ch = chapterById(chapterId);
      if (urls.length === 0) {
        setSegments([]);
        setLoadFailed(true);
        setLoading(false);
        return;
      }
      setSegments([{ chapter: ch, pages: urls }]);
      setLoading(false);
      const resume = pendingResumeRef.current;
      const targetIdx =
        resume?.pageIdx === -1
          ? Math.max(0, urls.length - 1)
          : resume != null
            ? Math.min(urls.length - 1, Math.max(0, resume.pageIdx))
            : 0;
      if (resume) {
        pendingResumeRef.current = { chapterId, pageIdx: targetIdx, offsetRatio: resume.offsetRatio };
      }
      activeKeyRef.current = `${chapterId}:${targetIdx}`;
      setPageIdx(targetIdx);
      const portraitTabletSpreadHint =
        viewportWidth >= 720 && viewportWidth <= viewportHeight && !isWebtoon && !isDouble
          ? ' • Rotate or tap Spread for 2-page view'
          : '';
      writeProgressNow(chapterId, targetIdx + 1, urls.length, resume?.offsetRatio ?? 0, false);
      flashToast(`${resolvedModeShortLabel} • ${chapterDisplayTitle(ch)}${portraitTabletSpreadHint}`);
    });

    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [params.slug, chapterId, server, reloadNonce]);

  // Programmatic scroll alignment that never trips userScrolledRef
  const scrollToWebtoonPage = useCallback(
    (targetChapterId: string, targetPageIdx: number, offsetRatio = 0, behavior: ScrollBehavior = 'auto') => {
      const el = pageElMapRef.current.get(`${targetChapterId}:${targetPageIdx}`);
      const container = scrollRef.current;
      if (!el || !container) return false;
      const lineOffset = offsetRatio > 0 ? el.offsetHeight * offsetRatio - container.clientHeight * 0.35 : 0;
      const targetTop = Math.max(0, Math.round(el.offsetTop + lineOffset));
      programmaticScrollRef.current = true;
      scrollDownAccumRef.current = 0;
      scrollUpAccumRef.current = 0;
      container.scrollTo({ top: targetTop, behavior });
      lastScrollTopRef.current = targetTop;
      window.clearTimeout(programmaticScrollTimerRef.current);
      programmaticScrollTimerRef.current = window.setTimeout(
        () => {
          programmaticScrollRef.current = false;
          scrollDownAccumRef.current = 0;
          scrollUpAccumRef.current = 0;
          if (scrollRef.current) {
            lastScrollTopRef.current = scrollRef.current.scrollTop;
          }
        },
        behavior === 'smooth' ? 950 : 220,
      );
      return true;
    },
    [],
  );

  // Initial webtoon resume alignment
  useEffect(() => {
    if (!isWebtoon || loading || pages.length === 0) return;
    const resume = pendingResumeRef.current;
    if (!resume || resume.chapterId !== chapterId || (resume.pageIdx <= 0 && resume.offsetRatio <= 0)) {
      pendingResumeRef.current = null;
      return;
    }
    const clamped = Math.min(pages.length - 1, Math.max(0, resume.pageIdx));
    const tryAlign = () => {
      if (userScrolledRef.current) return;
      scrollToWebtoonPage(chapterId, clamped, resume.offsetRatio, 'auto');
    };
    const raf = window.requestAnimationFrame(tryAlign);
    const t1 = window.setTimeout(tryAlign, 200);
    return () => {
      window.cancelAnimationFrame(raf);
      window.clearTimeout(t1);
    };
  }, [isWebtoon, loading, pages.length, chapterId, scrollToWebtoonPage]);

  // O(1) IntersectionObserver to track the active page in webtoon & continuous horizontal strip modes
  useEffect(() => {
    if ((!isWebtoon && !isHorizontalStrip) || loading || !scrollRef.current || segments.length === 0) return;
    if (typeof IntersectionObserver === 'undefined') return;

    const root = scrollRef.current;
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          const el = entry.target as HTMLElement;
          const chId = el.dataset.chapterId;
          const pIdx = Number(el.dataset.pageIdx);
          if (!chId || !Number.isInteger(pIdx)) continue;
          const nextKey = `${chId}:${pIdx}`;
          if (activeKeyRef.current === nextKey) continue;
          activeKeyRef.current = nextKey;

          const seg = segments.find((s) => s.chapter.id === chId);
          const total = seg?.pages.length ?? pages.length;

          if (chId !== chapterId) {
            // Only mark previous chapter finished when moving FORWARD (smaller index in newest-first list)
            const oldPos = params.chapters.findIndex((c) => c.id === chapterId);
            const newPos = params.chapters.findIndex((c) => c.id === chId);
            if (oldPos >= 0 && newPos >= 0 && newPos < oldPos) {
              markChapterFinished(chapterId);
            }
            setChapterId(chId);
            flashToast(chapterDisplayTitle(chapterById(chId)));

            const activeSegIdx = segments.findIndex((s) => s.chapter.id === chId);
            if (isWebtoon && activeSegIdx >= 2) {
              const dropCount = activeSegIdx - 1;
              let removedHeight = 0;
              for (let k = 0; k < dropCount; k++) {
                const segEl = segmentElMapRef.current.get(segments[k].chapter.id);
                if (segEl) removedHeight += segEl.offsetHeight;
              }
              const beforeTop = scrollRef.current?.scrollTop ?? 0;
              setSegments((prev) => prev.slice(dropCount));
              if (removedHeight > 0) {
                window.requestAnimationFrame(() => {
                  if (!scrollRef.current) return;
                  const expectedTop = Math.max(0, beforeTop - removedHeight);
                  if (Math.abs(scrollRef.current.scrollTop - expectedTop) > 4) {
                    programmaticScrollRef.current = true;
                    scrollRef.current.scrollTop = expectedTop;
                    lastScrollTopRef.current = expectedTop;
                    window.requestAnimationFrame(() => {
                      programmaticScrollRef.current = false;
                    });
                  } else {
                    lastScrollTopRef.current = scrollRef.current.scrollTop;
                  }
                });
              }
            }
          }

          setPageIdx(pIdx);
          const node = pageElMapRef.current.get(`${chId}:${pIdx}`);
          const ratio =
            isWebtoon && node && node.offsetHeight > 0
              ? Math.max(0, Math.min(0.95, (root.scrollTop - node.offsetTop) / node.offsetHeight))
              : 0;
          persistProgress(chId, pIdx + 1, total, ratio);
        }
      },
      {
        root,
        rootMargin: isHorizontalStrip ? '0px -40% 0px -40%' : '-30% 0px -58% 0px',
        threshold: 0,
      },
    );

    for (const seg of segments) {
      for (let i = 0; i < seg.pages.length; i++) {
        const node = pageElMapRef.current.get(`${seg.chapter.id}:${i}`);
        if (node) observer.observe(node);
      }
    }
    return () => observer.disconnect();
  }, [isWebtoon, isHorizontalStrip, loading, segments, chapterId, pages.length, markChapterFinished, flashToast, chapterById, persistProgress]);

  // Persist progress in paged/spread modes
  useEffect(() => {
    if (!isWebtoon && pages.length > 0) {
      persistProgress(chapterId, pageIdx + 1, pages.length, 0);
    }
  }, [isWebtoon, pageIdx, pages.length, chapterId, persistProgress]);

  // Explicit bounded LRU page preloading (uses working CDN mirror step, respects dataSaver & Wi-Fi-only)
  useEffect(() => {
    if (pages.length === 0) return;
    const conn = (navigator as Navigator & { connection?: { type?: string; saveData?: boolean } }).connection;
    const cellularRestricted =
      settings.preloadWifiOnly && Boolean(conn && (conn.saveData || conn.type === 'cellular'));
    const liteMode = settings.dataSaver || cellularRestricted;
    const ahead = liteMode ? 1 : settings.preloadCount >= 99 ? pages.length : settings.preloadCount;
    const indices: number[] = [];
    if (!liteMode && settings.preloadCount >= 99) {
      for (let i = 0; i < pages.length; i++) indices.push(i);
    } else {
      for (let i = 1; i <= ahead; i++) indices.push(pageIdx + i);
      if (!liteMode) indices.push(pageIdx - 1);
    }
    const cdnStep = workingCdnStepRef.current;
    for (const idx of indices) {
      if (idx < 0 || idx >= pages.length) continue;
      const resolved = resolveReaderImageUrl(pages[idx], cdnStep);
      if (!resolved || prefetchedImagesRef.current.has(resolved)) continue;
      const img = new Image();
      img.decoding = 'async';
      img.src = resolved;
      setLruEntry(prefetchedImagesRef.current, resolved, img, MAX_PREFETCH_CACHE);
    }
    if (!liteMode && nextChapter && pageIdx >= Math.max(0, pages.length - Math.max(2, ahead))) {
      const cacheKey = `${nextChapter.id}|${server}`;
      if (!prefetchedChapterRef.current.has(cacheKey)) {
        void loadChapterPages(nextChapter.id, server);
      }
    }
    if (!liteMode && prevChapter && pageIdx <= 1) {
      const cacheKey = `${prevChapter.id}|${server}`;
      if (!prefetchedChapterRef.current.has(cacheKey)) {
        void loadChapterPages(prevChapter.id, server);
      }
    }
  }, [pageIdx, pages, settings.dataSaver, settings.preloadWifiOnly, settings.preloadCount, nextChapter, prevChapter, server, loadChapterPages]);

  // Screen Wake Lock with visibilitychange AND silent release-event re-acquisition
  useEffect(() => {
    if (!settings.keepAwake || sleepTimerExpired) return;
    let alive = true;
    type WakeSentinel = {
      release: () => Promise<void>;
      addEventListener?: (type: 'release', listener: () => void) => void;
    };
    let sentinel: WakeSentinel | null = null;
    const nav = navigator as Navigator & { wakeLock?: { request: (type: 'screen') => Promise<WakeSentinel> } };
    const acquire = () => {
      if (!alive || document.visibilityState !== 'visible' || !nav.wakeLock?.request) return;
      void nav.wakeLock
        .request('screen')
        .then((s) => {
          if (!alive) {
            void s.release().catch(() => {});
            return;
          }
          sentinel = s;
          s.addEventListener?.('release', () => {
            if (alive && document.visibilityState === 'visible') {
              acquire();
            }
          });
        })
        .catch(() => {});
    };
    acquire();
    const onVis = () => {
      if (document.visibilityState === 'visible') acquire();
    };
    document.addEventListener('visibilitychange', onVis);
    return () => {
      alive = false;
      document.removeEventListener('visibilitychange', onVis);
      void sentinel?.release().catch(() => {});
    };
  }, [settings.keepAwake, sleepTimerExpired]);

  // Sleep timer: stops auto-scroll, releases wake lock, and dims screen gently when expired (or waits for chapter end)
  useEffect(() => {
    if (!sleepTimerEndAt || sleepTimerEndAt === -1) return;
    const check = () => {
      if (Date.now() >= sleepTimerEndAt) {
        if (sleepWaitChapterEnd && pages.length > 0 && pageIdx < pages.length - 1) {
          setSleepPendingChapterEnd(true);
          setSleepTimerEndAt(-1);
          flashToast('Sleep timer reached — will pause at end of chapter', true);
          return;
        }
        setAutoScrolling(false);
        setSleepTimerExpired(true);
        setSleepTimerEndAt(null);
        setSleepPendingChapterEnd(false);
      }
    };
    check();
    const id = window.setInterval(check, 5000);
    return () => window.clearInterval(id);
  }, [sleepTimerEndAt, sleepWaitChapterEnd, pages.length, pageIdx, flashToast]);

  const handleSetSleepTimer = useCallback(
    (minutes: number) => {
      if (minutes === -1) {
        setSleepTimerEndAt(-1);
        setSleepPendingChapterEnd(true);
        setSleepTimerExpired(false);
        flashToast('Sleep timer: will pause at end of chapter', true);
      } else if (minutes <= 0) {
        setSleepTimerEndAt(null);
        setSleepPendingChapterEnd(false);
        setSleepTimerExpired(false);
        flashToast('Sleep timer off', true);
      } else {
        setSleepTimerEndAt(Date.now() + minutes * 60000);
        setSleepPendingChapterEnd(false);
        setSleepTimerExpired(false);
        flashToast(`Sleep timer set for ${minutes} min`, true);
      }
    },
    [flashToast],
  );

  // Screen Orientation Lock
  useEffect(() => {
    const orient = screen.orientation as ScreenOrientation & { lock?: (mode: string) => Promise<void>; unlock?: () => void };
    if (!orient) return;
    if (settings.orientationLock === 'auto') {
      try {
        orient.unlock?.();
      } catch {
        // Ignore
      }
      return;
    }
    void orient.lock?.(settings.orientationLock)?.catch(() => {});
    return () => {
      try {
        orient.unlock?.();
      } catch {
        // Ignore
      }
    };
  }, [settings.orientationLock]);

  // Fullscreen listener
  useEffect(() => {
    const onFs = () => setIsFullscreen(Boolean(document.fullscreenElement));
    document.addEventListener('fullscreenchange', onFs);
    return () => document.removeEventListener('fullscreenchange', onFs);
  }, []);

  // Idle auto-hide HUD (respects user-configured autoHideDelayMs)
  useEffect(() => {
    window.clearTimeout(idleTimerRef.current);
    if (
      !showUi ||
      !settings.autoHideChrome ||
      settings.autoHideDelayMs <= 0 ||
      activeSheet !== 'none' ||
      pageAction != null ||
      loading ||
      loadFailed
    ) {
      return;
    }
    idleTimerRef.current = window.setTimeout(() => {
      if (!hasSeenReaderHint()) {
        markReaderHintSeen();
        idleTimerRef.current = window.setTimeout(() => {
          setSeenOnboardingHint(true);
          setShowUi(false);
        }, 2200);
        return;
      }
      setShowUi(false);
    }, settings.autoHideDelayMs);
    return () => window.clearTimeout(idleTimerRef.current);
  }, [showUi, settings.autoHideChrome, settings.autoHideDelayMs, activeSheet, pageAction, loading, loadFailed, pageIdx, chapterId, flashToast]);

  // Seamless next-chapter append in webtoon & continuous horizontal strip modes
  const appendNextChapterSegment = useCallback(async () => {
    if (
      appendingNextRef.current ||
      (!isWebtoon && !isHorizontalStrip) ||
      !settings.seamlessNextChapter ||
      segmentsRef.current.length === 0
    ) {
      return;
    }
    const lastSeg = segmentsRef.current[segmentsRef.current.length - 1];
    const following = adjacentChapter(params.chapters, lastSeg.chapter.id, 'next', chapterNavOpts);
    if (!following || segmentsRef.current.some((s) => s.chapter.id === following.id)) return;
    const myEpoch = navEpochRef.current;
    appendingNextRef.current = true;
    setAppendingNext(true);
    try {
      const nextPages = await loadChapterPages(following.id, server);
      if (navEpochRef.current !== myEpoch) return;
      if (nextPages.length > 0) {
        setSegments((prev) =>
          prev.some((s) => s.chapter.id === following.id) ? prev : [...prev, { chapter: following, pages: nextPages }],
        );
      }
    } finally {
      if (navEpochRef.current === myEpoch) {
        appendingNextRef.current = false;
        setAppendingNext(false);
      }
    }
  }, [
    isWebtoon,
    isHorizontalStrip,
    settings.seamlessNextChapter,
    settings.skipReadChapters,
    params.chapters,
    readIds,
    loadChapterPages,
    server,
  ]);

  // Smooth rAF auto-scroll for webtoon & continuous horizontal strip modes
  useEffect(() => {
    if (!autoScrolling || (!isWebtoon && !isHorizontalStrip) || activeSheet !== 'none' || pageAction != null || loading) return;
    let rafId = 0;
    let lastTime = performance.now();
    const pxPerSec = 95 * settings.autoScrollSpeed;
    const tick = (now: number) => {
      const dt = Math.min(0.08, (now - lastTime) / 1000);
      lastTime = now;
      const el = scrollRef.current;
      if (el) {
        if (isWebtoon) {
          const atBottom = el.scrollTop + el.clientHeight >= el.scrollHeight - 2;
          if (atBottom) {
            if (settings.seamlessNextChapter && nextChapter) {
              void appendNextChapterSegment();
            } else if (!appendingNext) {
              setAutoScrolling(false);
              return;
            }
          } else {
            el.scrollTop += pxPerSec * dt;
          }
        } else {
          // Horizontal strip: LTR scrolls toward +maxScroll, RTL scrolls toward -maxScroll (flex row-reverse)
          const maxScroll = Math.max(0, el.scrollWidth - el.clientWidth);
          const cur = Math.abs(el.scrollLeft);
          if (cur >= maxScroll - 2) {
            if (nextChapter) {
              navigateToChapter(nextChapter.id, { markPrevFinished: true, warnGap: true });
            } else {
              setAutoScrolling(false);
            }
            return;
          }
          el.scrollLeft += (isRtl ? -1 : 1) * pxPerSec * dt;
        }
      }
      rafId = window.requestAnimationFrame(tick);
    };
    rafId = window.requestAnimationFrame(tick);
    return () => window.cancelAnimationFrame(rafId);
  }, [
    autoScrolling,
    isWebtoon,
    isHorizontalStrip,
    isRtl,
    activeSheet,
    pageAction,
    loading,
    settings.autoScrollSpeed,
    settings.seamlessNextChapter,
    nextChapter,
    appendingNext,
    appendNextChapterSegment,
    navigateToChapter,
  ]);

  // Seamless previous-chapter prepend when reaching the top in webtoon mode
  const prependPrevChapterSegment = useCallback(async () => {
    if (prependingPrevRef.current || !isWebtoon || !settings.seamlessNextChapter || segmentsRef.current.length === 0) return;
    const firstSeg = segmentsRef.current[0];
    const preceding = adjacentChapter(params.chapters, firstSeg.chapter.id, 'prev', chapterNavOpts);
    if (!preceding || segmentsRef.current.some((s) => s.chapter.id === preceding.id)) return;
    const myEpoch = navEpochRef.current;
    prependingPrevRef.current = true;
    try {
      const prevPages = await loadChapterPages(preceding.id, server);
      if (navEpochRef.current !== myEpoch) return;
      if (prevPages.length > 0) {
        const beforeHeight = scrollRef.current?.scrollHeight ?? 0;
        const beforeTop = scrollRef.current?.scrollTop ?? 0;
        setSegments((prev) => {
          if (prev.some((s) => s.chapter.id === preceding.id)) return prev;
          const next = [{ chapter: preceding, pages: prevPages }, ...prev];
          const activePos = next.findIndex((s) => s.chapter.id === chapterId);
          // Keep at most 1 trailing segment beyond the active chapter so active is never evicted
          const keepEnd = activePos >= 0 ? Math.min(next.length, activePos + 2) : next.length;
          return next.slice(0, Math.max(2, keepEnd));
        });
        window.requestAnimationFrame(() => {
          const el = scrollRef.current;
          if (!el || navEpochRef.current !== myEpoch) return;
          const added = el.scrollHeight - beforeHeight;
          if (added > 0) {
            programmaticScrollRef.current = true;
            el.scrollTop = beforeTop + added;
            lastScrollTopRef.current = el.scrollTop;
            window.requestAnimationFrame(() => {
              programmaticScrollRef.current = false;
            });
          }
        });
      }
    } finally {
      if (navEpochRef.current === myEpoch) {
        prependingPrevRef.current = false;
      }
    }
  }, [
    isWebtoon,
    settings.seamlessNextChapter,
    settings.skipReadChapters,
    params.chapters,
    readIds,
    loadChapterPages,
    server,
    chapterId,
  ]);

  // rAF-throttled O(1) webtoon & horizontal-strip scroll handler (measures ONLY the single active page!)
  const handleWebtoonScroll = useCallback(() => {
    if ((!isWebtoon && !isHorizontalStrip) || !scrollRef.current || segments.length === 0) return;
    if (scrollRafRef.current != null) return;

    scrollRafRef.current = window.requestAnimationFrame(() => {
      scrollRafRef.current = null;
      const container = scrollRef.current;
      if (!container) return;

      if (isHorizontalStrip) {
        const remainingX = container.scrollWidth - (Math.abs(container.scrollLeft) + container.clientWidth);
        if (remainingX < container.clientWidth * 1.4) {
          void appendNextChapterSegment();
        }
        return;
      }

      const curTop = container.scrollTop;
      const delta = curTop - lastScrollTopRef.current;
      lastScrollTopRef.current = curTop;

      if (programmaticScrollRef.current) {
        scrollDownAccumRef.current = 0;
        scrollUpAccumRef.current = 0;
      } else if (!autoScrolling && activeSheet === 'none' && pageAction == null) {
        const threshold = SCROLL_HIDE_THRESHOLD[settings.scrollHideSensitivity];
        if (delta > 0) {
          scrollDownAccumRef.current += delta;
          scrollUpAccumRef.current = 0;
          if (settings.hideChromeOnScroll && showUi && scrollDownAccumRef.current >= threshold) {
            setShowUi(false);
            scrollDownAccumRef.current = 0;
          }
        } else if (delta < 0) {
          scrollUpAccumRef.current += -delta;
          scrollDownAccumRef.current = 0;
          if (settings.showChromeOnScrollUp && !showUi && scrollUpAccumRef.current >= Math.max(44, threshold)) {
            setShowUi(true);
            scrollUpAccumRef.current = 0;
          }
        }
      }

      // O(1) reading-line offsetRatio measurement on ONLY the active page
      const activeNode = pageElMapRef.current.get(activeKeyRef.current);
      if (activeNode) {
        const containerRect = container.getBoundingClientRect();
        const probeY = containerRect.top + containerRect.height * 0.35;
        const rect = activeNode.getBoundingClientRect();
        const offsetRatio = rect.height > 0 ? Math.min(1, Math.max(0, (probeY - rect.top) / rect.height)) : 0;
        persistProgress(chapterId, pageIdx + 1, pages.length, offsetRatio);
      }

      // Near bottom -> seamlessly append next chapter; near top on upward scroll -> prepend prev chapter
      const remaining = container.scrollHeight - (container.scrollTop + container.clientHeight);
      if (remaining < container.clientHeight * 1.4) {
        void appendNextChapterSegment();
      } else if (delta < 0 && curTop < 140 && userScrolledRef.current) {
        void prependPrevChapterSegment();
      }
    });
  }, [
    isWebtoon,
    isHorizontalStrip,
    segments.length,
    autoScrolling,
    settings.scrollHideSensitivity,
    settings.hideChromeOnScroll,
    settings.showChromeOnScrollUp,
    showUi,
    activeSheet,
    pageAction,
    chapterId,
    pageIdx,
    pages.length,
    persistProgress,
    appendNextChapterSegment,
    prependPrevChapterSegment,
  ]);

  const computeZoomStartPan = useCallback(
    (targetZoom: number): { x: number; y: number } => {
      if (targetZoom <= 1) return { x: 0, y: 0 };
      const stage = scrollRef.current;
      const content = stageContentRef.current;
      const vw = stage?.clientWidth ?? viewportWidth;
      const vh = stage?.clientHeight ?? viewportHeight;
      const cw = content?.offsetWidth ?? vw;
      const ch = content?.offsetHeight ?? vh;
      const pos = settings.zoomStartPosition;
      const xRatio =
        pos === 'left'
          ? 0
          : pos === 'right'
            ? 1
            : pos === 'center'
              ? 0.5
              : isWebtoon
                ? 0.5
                : isRtl
                  ? 1
                  : 0;
      const rawX = (0.5 - xRatio) * Math.max(vw, cw) * (targetZoom - 1);
      const rawY = 0.5 * Math.max(vh, ch) * (targetZoom - 1);
      return clampZoomPan(rawX, rawY, cw, ch, vw, vh, targetZoom);
    },
    [viewportWidth, viewportHeight, settings.zoomStartPosition, isWebtoon, isRtl],
  );

  // Paged / Spread navigation
  const goToSpread = useCallback(
    (nextSpreadIdx: number, dir: 'next' | 'prev' | 'fade') => {
      if (spreads.length === 0) return;
      if (nextSpreadIdx < 0) {
        if (prevChapter) {
          flashToast(`Previous: ${chapterDisplayTitle(prevChapter)}`, true);
          navigateToChapter(prevChapter.id, { startAtEnd: true, warnGap: true });
        } else {
          flashToast('First page of first chapter', true);
        }
        return;
      }
      if (nextSpreadIdx >= spreads.length) {
        if (nextChapter) {
          flashToast(`Next: ${chapterDisplayTitle(nextChapter)}`, true);
          navigateToChapter(nextChapter.id, { markPrevFinished: true, warnGap: true });
        } else {
          markChapterFinished(chapterId);
          flashToast('Reached the latest page', true);
        }
        return;
      }
      const targetGroup = spreads[nextSpreadIdx];
      triggerHaptic(6);
      if (settings.einkFlash) {
        setEinkFlashing(true);
        window.clearTimeout(einkTimerRef.current);
        einkTimerRef.current = window.setTimeout(() => setEinkFlashing(false), 90);
      }
      setTransitionDir(dir);
      setSpreadCursor(nextSpreadIdx);
      setPageIdx(targetGroup[0].pageIndex);
      if (!settings.keepZoomAcrossPages) {
        setZoom(1);
        setPan({ x: 0, y: 0 });
      } else if (zoom > 1) {
        setPan(computeZoomStartPan(zoom));
      }
      if (scrollRef.current) scrollRef.current.scrollTop = 0;
    },
    [spreads, prevChapter, nextChapter, chapterId, markChapterFinished, flashToast, navigateToChapter, settings.einkFlash, settings.keepZoomAcrossPages, triggerHaptic, zoom, computeZoomStartPan],
  );

  const guidedActive = settings.guidedPanelZoom && !isWebtoon && !isHorizontalStrip && pages.length > 0;
  const currentPageAspect = aspectMapRef.current.get(`${chapterId}:${pageIdx}`) ?? 0.7;
  const activeDetectedPanels = detectedPanelsByKey[`${chapterId}:${pageIdx}`];
  const guidedPanels = useMemo(
    () => (guidedActive ? buildGuidedPanels(currentPageAspect, isRtl, activeDetectedPanels) : []),
    [guidedActive, currentPageAspect, isRtl, activeDetectedPanels],
  );

  useEffect(() => {
    if (!guidedActive || guidedPanels.length === 0) return;
    const clampedIdx = Math.min(Math.max(0, guidedPanelIdx), guidedPanels.length - 1);
    const panel = guidedPanels[clampedIdx];
    const stageEl = scrollRef.current;
    const contentEl = stageContentRef.current;
    const stageW = stageEl?.clientWidth || viewportWidth;
    const stageH = stageEl?.clientHeight || viewportHeight;
    const contentW = contentEl?.clientWidth || stageW;
    const contentH = contentEl?.clientHeight || stageH;
    const next = computeGuidedPanelTransform(panel, stageW, stageH, contentW, contentH);
    setZoom(next.zoom);
    setPan(next.pan);
  }, [guidedActive, guidedPanels, guidedPanelIdx, pageIdx, viewportWidth, viewportHeight]);

  // `delta = +1` always advances forward in reading order (page 1 -> page 2) in both RTL and LTR;
  // arrow keys map physical left/right to `isRtl ? +1 : -1` and `isRtl ? -1 : +1`.
  const stepPage = useCallback(
    (delta: 1 | -1) => {
      const behavior: ScrollBehavior = motionReduced() ? 'auto' : 'smooth';
      if (isWebtoon) {
        const el = scrollRef.current;
        if (!el) return;
        userScrolledRef.current = true;
        el.scrollBy({ top: delta * Math.round(el.clientHeight * 0.82), behavior });
        return;
      }
      if (isHorizontalStrip) {
        const el = scrollRef.current;
        if (!el) return;
        const sign = isRtl ? -delta : delta;
        el.scrollBy({ left: sign * Math.round(el.clientWidth * 0.85), behavior });
        return;
      }
      if (guidedActive && guidedPanels.length > 1) {
        const nextPanel = guidedPanelIdx + delta;
        if (nextPanel >= 0 && nextPanel < guidedPanels.length) {
          triggerHaptic(5);
          setGuidedPanelIdx(nextPanel);
          return;
        }
        setGuidedPanelIdx(delta > 0 ? 0 : guidedPanels.length - 1);
      }
      goToSpread(safeSpreadIdx + delta, delta > 0 ? 'next' : 'prev');
    },
    [isWebtoon, isHorizontalStrip, isRtl, guidedActive, guidedPanels.length, guidedPanelIdx, triggerHaptic, goToSpread, safeSpreadIdx],
  );

  const jumpToPage = useCallback(
    (targetPageIdx: number) => {
      const clamped = Math.min(Math.max(0, targetPageIdx), Math.max(0, pages.length - 1));
      setPageIdx(clamped);
      setSpreadCursor(findSpreadIndexForPage(spreads, clamped));
      setTransitionDir('fade');
      activeKeyRef.current = `${chapterId}:${clamped}`;
      if (isWebtoon) {
        userScrolledRef.current = true;
        pendingResumeRef.current = null;
        scrollToWebtoonPage(chapterId, clamped, 0, motionReduced() ? 'auto' : 'smooth');
      } else if (isHorizontalStrip) {
        pageElMapRef.current.get(`${chapterId}:${clamped}`)?.scrollIntoView({
          inline: 'center',
          behavior: motionReduced() ? 'auto' : 'smooth',
        });
      } else {
        setZoom(1);
        setPan({ x: 0, y: 0 });
      }
    },
    [pages.length, spreads, isWebtoon, isHorizontalStrip, scrollToWebtoonPage, chapterId],
  );

  const toggleFullscreen = useCallback(() => {
    const doc = document as Document & {
      webkitFullscreenElement?: Element | null;
      webkitExitFullscreen?: () => Promise<void> | void;
    };
    const target = (rootRef.current ?? document.documentElement) as HTMLElement & {
      webkitRequestFullscreen?: () => Promise<void> | void;
    };
    if (!doc.fullscreenElement && !doc.webkitFullscreenElement) {
      if (target.requestFullscreen) {
        void target.requestFullscreen().catch(() => {});
      } else if (target.webkitRequestFullscreen) {
        void Promise.resolve(target.webkitRequestFullscreen()).catch(() => {});
      }
    } else if (doc.exitFullscreen) {
      void doc.exitFullscreen().catch(() => {});
    } else if (doc.webkitExitFullscreen) {
      void Promise.resolve(doc.webkitExitFullscreen()).catch(() => {});
    }
  }, []);

  const cycleMode = useCallback(() => {
    const idx = READING_MODE_ORDER.indexOf(settings.readingMode);
    const next = READING_MODE_ORDER[(idx + 1) % READING_MODE_ORDER.length];
    updateSettings({ readingMode: next });
  }, [settings.readingMode, updateSettings]);

  // Keyboard shortcuts
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.tagName === 'SELECT')) {
        return;
      }
      if (e.key === 'Escape') {
        if (pageAction) {
          setPageAction(null);
          return;
        }
        if (activeSheet !== 'none') {
          setActiveSheet('none');
          return;
        }
        if (autoScrolling) {
          setAutoScrolling(false);
          return;
        }
        if (zoom > 1) {
          setZoom(1);
          setPan({ x: 0, y: 0 });
          return;
        }
        onClose();
        return;
      }
      if (activeSheet !== 'none' || pageAction) return;

      switch (e.key) {
        case 'ArrowRight':
        case 'd':
        case 'D':
          e.preventDefault();
          stepPage(isRtl ? -1 : 1);
          break;
        case 'ArrowLeft':
        case 'a':
        case 'A':
          e.preventDefault();
          stepPage(isRtl ? 1 : -1);
          break;
        case ' ':
          e.preventDefault();
          stepPage(e.shiftKey ? -1 : 1);
          break;
        case 'PageDown':
          e.preventDefault();
          stepPage(1);
          break;
        case 'PageUp':
          e.preventDefault();
          stepPage(-1);
          break;
        case 'AudioVolumeDown':
        case 'VolumeDown':
          if (!settings.volumeKeys) break;
          e.preventDefault();
          stepPage(settings.invertVolumeKeys ? -1 : 1);
          break;
        case 'AudioVolumeUp':
        case 'VolumeUp':
          if (!settings.volumeKeys) break;
          e.preventDefault();
          stepPage(settings.invertVolumeKeys ? 1 : -1);
          break;
        case 'ArrowDown':
        case 'j':
        case 'J':
          if (isWebtoon) {
            e.preventDefault();
            userScrolledRef.current = true;
            scrollRef.current?.scrollBy({ top: 320, behavior: motionReduced() ? 'auto' : 'smooth' });
          }
          break;
        case 'ArrowUp':
        case 'k':
        case 'K':
          if (isWebtoon) {
            e.preventDefault();
            userScrolledRef.current = true;
            scrollRef.current?.scrollBy({ top: -320, behavior: motionReduced() ? 'auto' : 'smooth' });
          }
          break;
        case ']':
          if (nextChapter) navigateToChapter(nextChapter.id, { warnGap: true });
          break;
        case '[':
          if (prevChapter) navigateToChapter(prevChapter.id, { warnGap: true });
          break;
        case 'm':
        case 'M':
          cycleMode();
          break;
        case 'b':
        case 'B':
          if (pages.length > 0) togglePageBookmark(chapterId, pageIdx);
          break;
        case 'p':
        case 'P':
          if (isWebtoon) setAutoScrolling((a) => !a);
          break;
        case 'g':
        case 'G':
          if (pages.length > 1) setActiveSheet('jump');
          break;
        case 'c':
        case 'C':
          setActiveSheet('chapters');
          break;
        case 's':
        case 'S':
          setActiveSheet('settings');
          break;
        case 'f':
        case 'F':
          toggleFullscreen();
          break;
        case 'h':
        case 'H':
        case 'Enter':
          setShowUi((s) => !s);
          break;
        case '+':
        case '=':
          setZoom((z) => {
            const next = Math.min(3, Number((z + 0.5).toFixed(2)));
            if (z <= 1 && next > 1) setPan(computeZoomStartPan(next));
            return next;
          });
          break;
        case '-':
          setZoom((z) => {
            const minZoom = settings.disableZoomOut ? 1 : 0.75;
            const next = Math.max(minZoom, Number((z - 0.25).toFixed(2)));
            if (next <= 1) setPan({ x: 0, y: 0 });
            return next;
          });
          break;
        case '0':
          setZoom(1);
          setPan({ x: 0, y: 0 });
          break;
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [
    activeSheet,
    pageAction,
    autoScrolling,
    zoom,
    onClose,
    stepPage,
    isRtl,
    isWebtoon,
    nextChapter,
    prevChapter,
    navigateToChapter,
    cycleMode,
    toggleFullscreen,
    togglePageBookmark,
    chapterId,
    pageIdx,
    pages.length,
    settings.volumeKeys,
    settings.invertVolumeKeys,
  ]);

  // Auto-advance timer for paged & spread modes (reuses autoScrolling toggle)
  useEffect(() => {
    if (!autoScrolling || isWebtoon || isHorizontalStrip || activeSheet !== 'none' || pageAction != null || loading) return;
    const intervalMs = Math.max(2000, Math.round(7500 / settings.autoScrollSpeed));
    const timer = window.setInterval(() => {
      stepPage(1);
    }, intervalMs);
    return () => window.clearInterval(timer);
  }, [autoScrolling, isWebtoon, isHorizontalStrip, activeSheet, pageAction, loading, settings.autoScrollSpeed, stepPage]);

  // Bluetooth Gamepad / Page-Turner Remote support (polls only while a gamepad is connected)
  useEffect(() => {
    if (typeof navigator === 'undefined' || !navigator.getGamepads) return;
    let rafId = 0;
    let lastActionAt = 0;
    let active = false;

    const poll = () => {
      const pads = navigator.getGamepads?.() ?? [];
      let anyConnected = false;
      const now = performance.now();
      for (const pad of pads) {
        if (!pad) continue;
        anyConnected = true;
        if (now - lastActionAt < 260 || activeSheet !== 'none' || pageAction != null) continue;
        const leftPressed = pad.buttons[14]?.pressed || pad.buttons[4]?.pressed || (pad.axes[0] ?? 0) < -0.6;
        const rightPressed = pad.buttons[15]?.pressed || pad.buttons[5]?.pressed || (pad.axes[0] ?? 0) > 0.6;
        const nextBtn = pad.buttons[0]?.pressed;
        const prevBtn = pad.buttons[1]?.pressed;
        if (nextBtn) {
          lastActionAt = now;
          stepPage(1);
        } else if (prevBtn) {
          lastActionAt = now;
          stepPage(-1);
        } else if (leftPressed) {
          lastActionAt = now;
          stepPage(isRtl ? 1 : -1);
        } else if (rightPressed) {
          lastActionAt = now;
          stepPage(isRtl ? -1 : 1);
        }
      }
      if (anyConnected) {
        rafId = window.requestAnimationFrame(poll);
      } else {
        active = false;
      }
    };

    const startIfConnected = () => {
      if (active) return;
      const pads = navigator.getGamepads?.() ?? [];
      if (Array.from(pads).some(Boolean)) {
        active = true;
        rafId = window.requestAnimationFrame(poll);
      }
    };

    startIfConnected();
    window.addEventListener('gamepadconnected', startIfConnected);
    return () => {
      window.removeEventListener('gamepadconnected', startIfConnected);
      window.cancelAnimationFrame(rafId);
    };
  }, [activeSheet, pageAction, isRtl, stepPage]);

  // Keep fresh state ref so the tap timer never uses stale closures
  const latestTapCtxRef = useRef({
    zoom,
    isWebtoon,
    isHorizontalStrip,
    isRtl,
    webtoonTapScroll: settings.webtoonTapScroll,
    tapZoneLayout: settings.tapZoneLayout,
    invertTapZones: settings.invertTapZones,
    stepPage,
  });
  latestTapCtxRef.current = {
    zoom,
    isWebtoon,
    isHorizontalStrip,
    isRtl,
    webtoonTapScroll: settings.webtoonTapScroll,
    tapZoneLayout: settings.tapZoneLayout,
    invertTapZones: settings.invertTapZones,
    stepPage,
  };

  // Tap, tap-anchored double-tap zoom, swipe (with click suppression) & pinch handlers
  const handleStageClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (pageAction != null) return;
    if (Date.now() - lastSwipeAtRef.current < 420) return;
    if (showTapHint) {
      setShowTapHint(false);
      return;
    }
    const stageRect = e.currentTarget.getBoundingClientRect();
    const contentRect = stageContentRef.current?.getBoundingClientRect() ?? stageRect;
    const xRatio = stageRect.width > 0 ? (e.clientX - stageRect.left) / stageRect.width : 0.5;
    const yRatio = stageRect.height > 0 ? (e.clientY - stageRect.top) / stageRect.height : 0.5;
    const now = Date.now();
    const prev = lastTapRef.current;

    if (prev && now - prev.time < DOUBLE_TAP_WINDOW_MS && Math.hypot(e.clientX - prev.x, e.clientY - prev.y) < 36) {
      if (tapTimerRef.current != null) {
        window.clearTimeout(tapTimerRef.current);
        tapTimerRef.current = null;
      }
      lastTapRef.current = null;
      if (zoom > 1) {
        setZoom(1);
        setPan({ x: 0, y: 0 });
      } else {
        const targetZoom = settings.doubleTapZoom;
        const cXRatio = contentRect.width > 0 ? (e.clientX - contentRect.left) / contentRect.width : xRatio;
        const cYRatio = isWebtoon ? yRatio : contentRect.height > 0 ? (e.clientY - contentRect.top) / contentRect.height : yRatio;
        setZoom(targetZoom);
        setPan(computeTapAnchoredPan(cXRatio, cYRatio, contentRect.width, isWebtoon ? stageRect.height : contentRect.height, targetZoom));
      }
      return;
    }

    // Instant 0ms side-zone page/panel turns in paged/spread modes (no 265ms wait on every turn!)
    if ((zoom === 1 || guidedActive) && !isWebtoon && !isHorizontalStrip) {
      const action = resolveTapZoneAction(xRatio, yRatio, settings.tapZoneLayout, isRtl, settings.invertTapZones);
      if (action === 'next' || action === 'prev') {
        lastTapRef.current = null;
        if (tapTimerRef.current != null) {
          window.clearTimeout(tapTimerRef.current);
          tapTimerRef.current = null;
        }
        stepPage(action === 'next' ? 1 : -1);
        return;
      }
    }

    lastTapRef.current = { time: now, x: e.clientX, y: e.clientY };

    if (tapTimerRef.current != null) window.clearTimeout(tapTimerRef.current);
    tapTimerRef.current = window.setTimeout(() => {
      tapTimerRef.current = null;
      const ctx = latestTapCtxRef.current;
      if (ctx.zoom > 1 || ctx.isHorizontalStrip) {
        setShowUi((s) => !s);
        return;
      }
      if (ctx.isWebtoon) {
        if (ctx.webtoonTapScroll) {
          if (yRatio > 0.65) {
            ctx.stepPage(1);
            return;
          }
          if (yRatio < 0.25) {
            ctx.stepPage(-1);
            return;
          }
        }
        setShowUi((s) => !s);
        return;
      }
      const action = resolveTapZoneAction(xRatio, yRatio, ctx.tapZoneLayout, ctx.isRtl, ctx.invertTapZones);
      if (action === 'toggle-ui') setShowUi((s) => !s);
      else if (action === 'next') ctx.stepPage(1);
      else ctx.stepPage(-1);
    }, SINGLE_TAP_DELAY_MS);
  };

  const handleTouchStart = (e: React.TouchEvent<HTMLDivElement>) => {
    if (autoScrolling) setAutoScrolling(false);
    if (e.touches.length === 2) {
      lastSwipeAtRef.current = Date.now();
      setIsPinching(true);
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      pinchStartRef.current = { dist: Math.hypot(dx, dy), scale: zoom, pan: { ...pan } };
      swipeStartRef.current = null;
      return;
    }
    if (e.touches.length === 1) {
      const t = e.touches[0];
      if (zoom > 1) {
        dragStartRef.current = { x: t.clientX, y: t.clientY, panX: pan.x, panY: pan.y };
      } else if (!isWebtoon) {
        swipeStartRef.current = { x: t.clientX, y: t.clientY, time: Date.now() };
      }
    }
  };

  const handleTouchMove = (e: React.TouchEvent<HTMLDivElement>) => {
    userScrolledRef.current = true;
    pendingResumeRef.current = null;
    if (e.touches.length === 2 && pinchStartRef.current) {
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      const minScale = settings.disableZoomOut ? 1 : 0.75;
      const nextScale = Math.min(
        3,
        Math.max(minScale, pinchStartRef.current.scale * (Math.hypot(dx, dy) / Math.max(1, pinchStartRef.current.dist))),
      );
      const rounded = Number(nextScale.toFixed(2));
      setZoom(rounded);
      const stage = scrollRef.current;
      if (rounded <= 1.02 || !stage) {
        setPan({ x: 0, y: 0 });
      } else {
        const rect = stage.getBoundingClientRect();
        const midX = (e.touches[0].clientX + e.touches[1].clientX) / 2;
        const midY = (e.touches[0].clientY + e.touches[1].clientY) / 2;
        const midXRatio = rect.width > 0 ? (midX - rect.left) / rect.width : 0.5;
        const midYRatio = rect.height > 0 ? (midY - rect.top) / rect.height : 0.5;
        setPan(
          computePinchAnchoredPan(
            pinchStartRef.current.pan,
            pinchStartRef.current.scale,
            rounded,
            midXRatio,
            midYRatio,
            rect.width,
            rect.height,
          ),
        );
      }
      return;
    }
    if (e.touches.length === 1 && zoom > 1 && dragStartRef.current) {
      const t = e.touches[0];
      const stage = scrollRef.current;
      const content = stageContentRef.current;
      const vw = stage?.clientWidth ?? viewportWidth;
      const vh = stage?.clientHeight ?? viewportHeight;
      const cw = content?.offsetWidth ?? vw;
      const ch = content?.offsetHeight ?? vh;
      const rawX = dragStartRef.current.panX + (t.clientX - dragStartRef.current.x);
      const rawY = dragStartRef.current.panY + (t.clientY - dragStartRef.current.y);
      const clamped = clampZoomPan(rawX, rawY, cw, ch, vw, vh, zoom);
      setPan(clamped);
    }
  };

  const handleTouchEnd = (e: React.TouchEvent<HTMLDivElement>) => {
    if (pinchStartRef.current) {
      lastSwipeAtRef.current = Date.now();
      setIsPinching(false);
      if (tapTimerRef.current != null) {
        window.clearTimeout(tapTimerRef.current);
        tapTimerRef.current = null;
      }
    }
    pinchStartRef.current = null;
    dragStartRef.current = null;
    if (swipeStartRef.current && e.changedTouches.length === 1 && zoom === 1 && !isWebtoon && !isHorizontalStrip) {
      const t = e.changedTouches[0];
      const dx = t.clientX - swipeStartRef.current.x;
      const dy = t.clientY - swipeStartRef.current.y;
      const dt = Date.now() - swipeStartRef.current.time;
      swipeStartRef.current = null;
      if (dt < 550 && Math.abs(dx) > 54 && Math.abs(dx) > Math.abs(dy) * 1.4) {
        lastSwipeAtRef.current = Date.now();
        if (tapTimerRef.current != null) {
          window.clearTimeout(tapTimerRef.current);
          tapTimerRef.current = null;
        }
        const swipedLeft = dx < 0;
        const forward = isRtl ? !swipedLeft : swipedLeft;
        const delta: 1 | -1 = forward ? 1 : -1;
        const atBoundary = (delta === 1 && safeSpreadIdx >= spreads.length - 1) || (delta === -1 && safeSpreadIdx <= 0);
        if (settings.confirmChapterSwipe && atBoundary) {
          const dir = delta === 1 ? 'next' : 'prev';
          const prevGuard = chapterEdgeGuardRef.current;
          if (!prevGuard || prevGuard.dir !== dir || Date.now() - prevGuard.at > 2500) {
            chapterEdgeGuardRef.current = { dir, at: Date.now() };
            flashToast(dir === 'next' ? 'Swipe again for Next Chapter' : 'Swipe again for Previous Chapter', true);
            return;
          }
          chapterEdgeGuardRef.current = null;
        }
        stepPage(delta);
      }
    }
  };

  const handlePageErrorChange = useCallback((pageKey: string, errored: boolean) => {
    setFailedPageKeys((prev) => {
      const has = prev.includes(pageKey);
      if (errored && !has) return [...prev, pageKey];
      if (!errored && has) return prev.filter((k) => k !== pageKey);
      return prev;
    });
  }, []);

  const retryAllFailedPages = useCallback(() => {
    if (failedPageKeys.length === 0) return;
    setPageReloadTokens((prev) => {
      const next = { ...prev };
      for (const k of failedPageKeys) next[k] = (next[k] ?? 0) + 1;
      return next;
    });
    setFailedPageKeys([]);
    flashToast('Retrying failed pages…', true);
  }, [failedPageKeys, flashToast]);

  // Persist measured aspects with true LRU eviction & re-anchor cold-open resume when earlier images settle
  const handlePageDimensions = useCallback(
    (segChapterId: string, idx: number, w: number, h: number) => {
      const ratio = w / Math.max(1, h);
      setLruEntry(aspectMapRef.current, `${segChapterId}:${idx}`, ratio, MAX_ASPECT_CACHE);

      if (segChapterId === chapterId) {
        chapterAspectsRef.current[idx] = ratio;
        const measured = Object.values(chapterAspectsRef.current);
        if (measured.length >= 1 && measured.length <= 5) {
          const sorted = [...measured].sort((a, b) => a - b);
          const median = sorted[Math.floor(sorted.length / 2)];
          setLiveMedianAspect(median);
          if (median > 0 && median < 0.56) {
            savePersistedSeriesFormat(params.slug, 'webtoon');
            setPersistedFormat('webtoon');
          } else if (measured.length >= 2 && !loadPersistedSeriesFormat(params.slug)) {
            const fmt = params.seriesFormat ?? 'manga';
            savePersistedSeriesFormat(params.slug, fmt);
            setPersistedFormat(fmt);
          }
        }
        window.clearTimeout(aspectSaveTimerRef.current);
        aspectSaveTimerRef.current = window.setTimeout(() => {
          saveChapterAspects(params.slug, chapterId, chapterAspectsRef.current);
        }, 400);

        if (isWideAspect(w, h)) {
          setWidePages((prev) => {
            if (prev.has(idx)) return prev;
            const next = new Set(prev);
            next.add(idx);
            return next;
          });
        }

        // Re-anchor webtoon resume if an image above or at the resume target just resolved
        const resume = pendingResumeRef.current;
        if (isWebtoon && resume && !userScrolledRef.current && resume.chapterId === chapterId && idx <= resume.pageIdx) {
          window.requestAnimationFrame(() => {
            if (!userScrolledRef.current && pendingResumeRef.current) {
              scrollToWebtoonPage(chapterId, resume.pageIdx, resume.offsetRatio, 'auto');
            }
          });
        }
      }
    },
    [chapterId, params.slug, isWebtoon, scrollToWebtoonPage],
  );

  // RTL-mirrored slide page animations
  const pageAnimClass = useMemo(() => {
    if (settings.pageTransition === 'none') return '';
    if (settings.pageTransition === 'fade' || transitionDir === 'fade') return 'manga-page-fade';
    const slideForward = isRtl ? transitionDir === 'prev' : transitionDir === 'next';
    return slideForward ? 'manga-page-slide-next' : 'manga-page-slide-prev';
  }, [settings.pageTransition, transitionDir, isRtl]);

  const visualSpreadOrder = useMemo(() => {
    if (currentSpread.length <= 1) return currentSpread;
    return isRtl ? [...currentSpread].reverse() : currentSpread;
  }, [currentSpread, isRtl]);

  const containerMaxWidth = useMemo(() => {
    if (settings.widthUnit === 'pct') return `${settings.maxWidthPct}%`;
    return settings.maxWidth === 0 ? '100%' : settings.maxWidth;
  }, [settings.widthUnit, settings.maxWidthPct, settings.maxWidth]);

  const displayPageLabel = useMemo(() => {
    if (pages.length === 0) return '0 / 0';
    if (!isWebtoon && currentSpread.length === 2) {
      return `${currentSpread[0].pageIndex + 1}–${currentSpread[1].pageIndex + 1} / ${pages.length}`;
    }
    const slot = currentSpread[0];
    if (!isWebtoon && slot?.cropHalf) {
      return `${slot.pageIndex + 1}${slot.cropHalf === 'right' ? 'R' : 'L'} / ${pages.length}`;
    }
    return `${Math.min(pageIdx + 1, pages.length)} / ${pages.length}`;
  }, [pages.length, isWebtoon, currentSpread, pageIdx]);

  const stripWidth = useMemo(() => {
    if (settings.widthUnit === 'pct') return Math.round((viewportWidth * settings.maxWidthPct) / 100);
    return settings.maxWidth === 0 ? viewportWidth : Math.min(viewportWidth, settings.maxWidth);
  }, [settings.widthUnit, settings.maxWidthPct, settings.maxWidth, viewportWidth]);

  // Lightweight color filter applied ONLY when user enables tint/contrast/grayscale/invert;
  // brightness dimming uses a separate GPU-friendly overlay so True Black stays pure #000000.
  const stageFilter = useMemo(() => {
    const parts: string[] = [];
    if (settings.warmTint > 0) parts.push(`sepia(${(settings.warmTint * 1.4).toFixed(2)})`);
    if (settings.contrast !== 1) parts.push(`contrast(${settings.contrast.toFixed(2)})`);
    if (settings.grayscale) parts.push('grayscale(1)');
    if (settings.invertColors) parts.push('invert(1)');
    return parts.length > 0 ? parts.join(' ') : undefined;
  }, [settings.warmTint, settings.contrast, settings.grayscale, settings.invertColors]);

  const isCompactPhone = viewportWidth < 480;
  const isTabletOrWide = viewportWidth >= 768;
  const showZoneGuide = !isWebtoon && (showTapHint || (settings.showTapZonesOverlay && settings.tapZoneLayout !== 'disabled'));
  const currentBookmarked = pages.length > 0 && isPageBookmarked(chapterId, pageIdx);

  return (
    <div
      ref={rootRef}
      role="region"
      aria-label={`Manga reader: ${params.mangaTitle}`}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 90,
        background: settings.background === 'auto' && adaptiveBgColor ? adaptiveBgColor : bgTheme.bg,
        transition: motionReduced() ? 'none' : 'background 260ms ease, padding 180ms ease',
        color: bgTheme.fg,
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
        paddingTop: showUi ? hudInset.top : 0,
        paddingBottom: showUi ? hudInset.bottom : 0,
        boxSizing: 'border-box',
      }}
    >
      {/* Screen-reader live page announcement */}
      <div
        aria-live="polite"
        aria-atomic="true"
        style={{
          position: 'absolute',
          width: 1,
          height: 1,
          overflow: 'hidden',
          clipPath: 'inset(50%)',
          whiteSpace: 'nowrap',
        }}
      >
        {!loading && pages.length > 0 ? `${chapterDisplayTitle(activeChapter)}, page ${displayPageLabel}` : ''}
      </div>

      {/* Reading canvas */}
      <div
        ref={scrollRef}
        onScroll={handleWebtoonScroll}
        onWheel={(e) => {
          userScrolledRef.current = true;
          pendingResumeRef.current = null;
          if (autoScrolling) setAutoScrolling(false);
          // Wheel / trackpad page turning in paged & spread modes (when not zoomed)
          if (!isWebtoon && !isHorizontalStrip && zoom === 1 && activeSheet === 'none' && !pageAction) {
            const now = Date.now();
            if (now - lastWheelTurnRef.current < 260) return;
            const useHoriz = Math.abs(e.deltaX) > Math.abs(e.deltaY) && Math.abs(e.deltaX) > 24;
            const useVert = Math.abs(e.deltaY) > 28;
            if (useHoriz) {
              lastWheelTurnRef.current = now;
              const forward = isRtl ? e.deltaX < 0 : e.deltaX > 0;
              stepPage(forward ? 1 : -1);
            } else if (useVert && settings.fitMode !== 'fit-width' && settings.fitMode !== 'original') {
              lastWheelTurnRef.current = now;
              stepPage(e.deltaY > 0 ? 1 : -1);
            }
          }
        }}
        onClick={handleStageClick}
        onTouchStart={handleTouchStart}
        onTouchMove={handleTouchMove}
        onTouchEnd={handleTouchEnd}
        style={{
          flex: 1,
          overflowY:
            isHorizontalStrip
              ? 'hidden'
              : isWebtoon
                ? 'auto'
                : zoom > 1
                  ? 'hidden'
                  : settings.fitMode === 'fit-width' || settings.fitMode === 'original'
                    ? 'auto'
                    : 'hidden',
          overflowX: isWebtoon && zoom > 1 ? 'auto' : zoom > 1 ? 'hidden' : isHorizontalStrip || settings.fitMode === 'original' ? 'auto' : 'hidden',
          scrollSnapType: isHorizontalStrip && zoom === 1 ? 'x proximity' : undefined,
          overflowAnchor: 'auto',
          display: 'flex',
          flexDirection: isHorizontalStrip ? (isRtl ? 'row-reverse' : 'row') : 'column',
          alignItems: isWebtoon && zoom > 1 ? 'flex-start' : 'center',
          justifyContent:
            !isWebtoon &&
            !isHorizontalStrip &&
            !loading &&
            !loadFailed &&
            (settings.fitMode === 'fit-height' || settings.fitMode === 'fit-screen' || settings.fitMode === 'smart-fit' || settings.fitMode === 'stretch')
              ? 'center'
              : 'flex-start',
          touchAction: isWebtoon ? (zoom > 1 ? 'pan-x pan-y' : 'pan-y') : zoom > 1 ? 'none' : isHorizontalStrip ? 'pan-x' : 'pan-y',
          position: 'relative',
        }}
      >
        {loading ? (
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              margin: 'auto',
              padding: 32,
              maxWidth: 380,
              textAlign: 'center',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 14,
            }}
          >
            <div
              className="vinyl-spin"
              style={{
                width: 40,
                height: 40,
                borderRadius: '50%',
                border: `3px solid ${KatanaColors.border}`,
                borderTopColor: KatanaColors.accent,
              }}
            />
            <div style={{ ...KatanaType.title, fontSize: 15, color: bgTheme.fg }}>
              Loading {chapterDisplayTitle(activeChapter)}…
            </div>
            <div style={{ ...KatanaType.small, color: KatanaColors.textMuted }}>
              Fetching pages from the source. You can switch servers below if it stalls.
            </div>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', justifyContent: 'center', marginTop: 4 }}>
              {SERVER_OPTIONS.map((srv) => (
                <button
                  key={srv.label}
                  type="button"
                  className="bare-button player-focusable"
                  onClick={() => {
                    setServer(srv.value);
                    setReloadNonce((n) => n + 1);
                  }}
                  style={{
                    minHeight: 44,
                    padding: '0 14px',
                    borderRadius: 99,
                    background: server === srv.value ? KatanaColors.accent : KatanaColors.surfaceAlt,
                    border: `1px solid ${server === srv.value ? KatanaColors.accent : KatanaColors.border}`,
                    color: '#FFFFFF',
                    fontSize: 12.5,
                    fontWeight: 600,
                  }}
                >
                  {srv.label}
                </button>
              ))}
            </div>
          </div>
        ) : loadFailed || pages.length === 0 ? (
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              margin: 'auto',
              padding: 28,
              maxWidth: 400,
              textAlign: 'center',
              background: KatanaColors.surface,
              border: `1px solid ${KatanaColors.border}`,
              borderRadius: 18,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 12,
            }}
          >
            <Icon name="cloud_off" size={38} color={KatanaColors.accentSoft} />
            <div style={{ ...KatanaType.title, fontSize: 16 }}>Could not load chapter pages</div>
            <div style={{ ...KatanaType.small }}>
              The current image source didn&apos;t respond. Retry or switch to another server below.
            </div>
            <button
              type="button"
              className="bare-button player-focusable"
              onClick={() => setReloadNonce((n) => n + 1)}
              style={{
                minHeight: 44,
                padding: '0 22px',
                borderRadius: 99,
                background: KatanaColors.accent,
                color: '#FFFFFF',
                fontSize: 13.5,
                fontWeight: 700,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
              }}
            >
              <Icon name="refresh" size={18} color="#FFFFFF" />
              Retry Chapter
            </button>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', justifyContent: 'center' }}>
              {SERVER_OPTIONS.map((srv) => (
                <button
                  key={srv.label}
                  type="button"
                  className="bare-button player-focusable"
                  onClick={() => {
                    setServer(srv.value);
                    setReloadNonce((n) => n + 1);
                  }}
                  style={{
                    minHeight: 44,
                    padding: '0 14px',
                    borderRadius: 99,
                    background: server === srv.value ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                    border: `1px solid ${server === srv.value ? KatanaColors.accent : KatanaColors.border}`,
                    color: KatanaColors.text,
                    fontSize: 12.5,
                    fontWeight: 600,
                  }}
                >
                  {srv.label}
                </button>
              ))}
            </div>
          </div>
        ) : isWebtoon ? (
          <div
            ref={stageContentRef}
            style={{
              width: zoom !== 1 ? `${Math.round(zoom * 100)}%` : '100%',
              maxWidth: zoom > 1 ? 'none' : containerMaxWidth,
              paddingLeft: settings.webtoonSidePadding > 0 ? `${settings.webtoonSidePadding}%` : undefined,
              paddingRight: settings.webtoonSidePadding > 0 ? `${settings.webtoonSidePadding}%` : undefined,
              boxSizing: 'border-box',
              display: 'flex',
              flexDirection: 'column',
              gap: settings.pageGap,
              transition: isPinching ? 'none' : 'width 140ms ease-out',
              paddingBottom: 'max(36px, env(safe-area-inset-bottom))',
            }}
          >
            {segments.map((seg, segIdx) => (
              <div
                key={seg.chapter.id}
                ref={(node) => {
                  if (node) segmentElMapRef.current.set(seg.chapter.id, node);
                  else segmentElMapRef.current.delete(seg.chapter.id);
                }}
                style={{ display: 'flex', flexDirection: 'column', gap: settings.pageGap, filter: stageFilter }}
              >
                {segIdx > 0 && settings.alwaysShowChapterDivider && (
                  <div
                    onClick={(e) => e.stopPropagation()}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 10,
                      padding: '8px 14px',
                      opacity: 0.85,
                    }}
                  >
                    <div style={{ flex: 1, height: 1, background: KatanaColors.border }} />
                    <span
                      style={{
                        fontSize: 11,
                        fontWeight: 600,
                        letterSpacing: 0.3,
                        color: KatanaColors.accentSoft,
                        whiteSpace: 'nowrap',
                      }}
                    >
                      {chapterDisplayTitle(seg.chapter)}
                    </span>
                    <div style={{ flex: 1, height: 1, background: KatanaColors.border }} />
                  </div>
                )}
                {seg.pages.map((url, idx) => {
                  const key = `${seg.chapter.id}:${idx}`;
                  const pendingIdx = pendingResumeRef.current?.chapterId === seg.chapter.id ? pendingResumeRef.current.pageIdx : -1;
                  const eagerForResume = pendingIdx >= 0 && idx <= pendingIdx;
                  return (
                    <div
                      key={key}
                      data-chapter-id={seg.chapter.id}
                      data-page-idx={idx}
                      ref={(node) => {
                        if (node) pageElMapRef.current.set(key, node);
                        else pageElMapRef.current.delete(key);
                      }}
                      style={{
                        // 1px overlap eliminates subpixel hairline seams in gapless webtoon strips
                        marginTop: idx > 0 && settings.pageGap === 0 ? -1 : 0,
                      }}
                    >
                      <ReaderPageImage
                        src={url}
                        pageNumber={idx + 1}
                        fitMode={settings.fitMode}
                        isWebtoon
                        eager={settings.dataSaver ? idx === pageIdx : eagerForResume || Math.abs(idx - pageIdx) <= 2}
                        lowPriority={settings.dataSaver && idx !== pageIdx}
                        cropBorders={settings.cropBorders}
                        knownAspect={aspectMapRef.current.get(key)}
                        defaultAspect={seriesDefaultAspect}
                        containerWidth={stripWidth}
                        reloadToken={pageReloadTokens[key] ?? 0}
                        sampleEdgeColor={settings.background === 'auto' && idx === pageIdx}
                        onEdgeColor={setAdaptiveBgColor}
                        onDimensions={(w, h) => handlePageDimensions(seg.chapter.id, idx, w, h)}
                        onCdnStepResolved={(s) => { workingCdnStepRef.current = s; }}
                        onErrorChange={(err) => handlePageErrorChange(key, err)}
                        onLongPress={(resolvedUrl, num) => {
                          lastSwipeAtRef.current = Date.now();
                          setPageAction({ url: resolvedUrl, pageNumber: num, key });
                        }}
                      />
                    </div>
                  );
                })}
              </div>
            ))}

            {/* End-of-chapter footer */}
            <div
              onClick={(e) => e.stopPropagation()}
              style={{
                margin: '20px 16px 40px',
                padding: '18px 20px',
                borderRadius: 16,
                background: KatanaColors.surface,
                border: `1px solid ${KatanaColors.border}`,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 10,
                textAlign: 'center',
              }}
            >
              <div style={{ ...KatanaType.small, textTransform: 'uppercase', letterSpacing: 0.7 }}>
                End of {chapterDisplayTitle(segments[segments.length - 1]?.chapter ?? activeChapter)}
              </div>
              {appendingNext ? (
                <div style={{ ...KatanaType.body, color: KatanaColors.accentSoft }}>Loading next chapter…</div>
              ) : (() => {
                  const lastSegCh = segments[segments.length - 1]?.chapter ?? activeChapter;
                  const upcoming = adjacentChapter(params.chapters, lastSegCh.id, 'next', chapterNavOpts);
                  return upcoming ? (
                    <button
                      type="button"
                      className="bare-button player-focusable"
                      onClick={() => navigateToChapter(upcoming.id, { markPrevFinished: true, warnGap: true })}
                      style={{
                        minHeight: 46,
                        padding: '0 24px',
                        borderRadius: 99,
                        background: KatanaColors.accent,
                        color: '#FFFFFF',
                        fontSize: 14,
                        fontWeight: 700,
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 8,
                      }}
                    >
                      <span>Read {chapterDisplayTitle(upcoming)}</span>
                      <Icon name="arrow_forward" size={18} color="#FFFFFF" />
                    </button>
                  ) : (
                    <div style={{ ...KatanaType.body }}>You&apos;re all caught up on {params.mangaTitle}.</div>
                  );
                })()}
            </div>
          </div>
        ) : isHorizontalStrip ? (
          /* Continuous horizontal strip (RTL or LTR, with seamless chapter chaining) */
          <div
            ref={stageContentRef}
            style={{
              display: 'flex',
              flexDirection: isRtl ? 'row-reverse' : 'row',
              alignItems: 'center',
              height: '100%',
              gap: settings.pageGap,
              padding: '0 12px',
              filter: stageFilter,
              transform: zoom > 1 ? `translate3d(${pan.x}px, ${pan.y}px, 0) scale(${zoom})` : undefined,
              transformOrigin: 'center center',
              transition: isPinching || motionReduced() ? 'none' : 'transform 140ms ease-out',
            }}
          >
            {segments.map((seg, segIdx) => (
              <div
                key={seg.chapter.id}
                style={{ display: 'flex', flexDirection: isRtl ? 'row-reverse' : 'row', alignItems: 'center', height: '100%', gap: settings.pageGap }}
              >
                {segIdx > 0 && settings.alwaysShowChapterDivider && (
                  <div
                    onClick={(e) => e.stopPropagation()}
                    style={{
                      height: '70%',
                      padding: '0 10px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      borderLeft: `1px solid ${KatanaColors.border}`,
                      borderRight: `1px solid ${KatanaColors.border}`,
                      flexShrink: 0,
                    }}
                  >
                    <span style={{ fontSize: 11.5, fontWeight: 600, color: KatanaColors.accentSoft, writingMode: 'vertical-rl' }}>
                      {chapterDisplayTitle(seg.chapter)}
                    </span>
                  </div>
                )}
                {seg.pages.map((url, idx) => {
                  const key = `${seg.chapter.id}:${idx}`;
                  return (
                    <div
                      key={key}
                      data-chapter-id={seg.chapter.id}
                      data-page-idx={idx}
                      ref={(node) => {
                        if (node) pageElMapRef.current.set(key, node);
                        else pageElMapRef.current.delete(key);
                      }}
                      style={{
                        height: '100%',
                        flexShrink: 0,
                        display: 'flex',
                        alignItems: 'center',
                        scrollSnapAlign: 'center',
                      }}
                    >
                      <ReaderPageImage
                        src={url}
                        pageNumber={idx + 1}
                        fitMode="fit-height"
                        isWebtoon={false}
                        eager={settings.dataSaver ? idx === pageIdx : Math.abs(idx - pageIdx) <= 2}
                        lowPriority={settings.dataSaver && idx !== pageIdx}
                        cropBorders={settings.cropBorders}
                        knownAspect={aspectMapRef.current.get(key)}
                        defaultAspect={seriesDefaultAspect}
                        containerWidth={stripWidth}
                        reloadToken={pageReloadTokens[key] ?? 0}
                        sampleEdgeColor={settings.background === 'auto' && idx === pageIdx}
                        onEdgeColor={setAdaptiveBgColor}
                        onDimensions={(w, h) => handlePageDimensions(seg.chapter.id, idx, w, h)}
                        onCdnStepResolved={(s) => { workingCdnStepRef.current = s; }}
                        onErrorChange={(err) => handlePageErrorChange(key, err)}
                        onLongPress={(resolvedUrl, num) => {
                          lastSwipeAtRef.current = Date.now();
                          setPageAction({ url: resolvedUrl, pageNumber: num, key });
                        }}
                      />
                    </div>
                  );
                })}
              </div>
            ))}
          </div>
        ) : (
          /* Paged / Double-Page Spread stage */
          <div
            ref={stageContentRef}
            key={`${chapterId}:${safeSpreadIdx}`}
            className={pageAnimClass}
            style={{
              position: 'relative',
              width: '100%',
              height:
                settings.fitMode === 'fit-height' || settings.fitMode === 'fit-screen' || settings.fitMode === 'smart-fit' || settings.fitMode === 'stretch'
                  ? '100%'
                  : 'auto',
              maxWidth: isDouble
                ? settings.widthUnit === 'pct'
                  ? `${settings.maxWidthPct}%`
                  : settings.maxWidth === 0
                    ? '100%'
                    : Math.max(settings.maxWidth, 1280)
                : containerMaxWidth,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: visualSpreadOrder.length > 1 ? settings.spreadGutter : 0,
              padding:
                settings.fitMode === 'fit-height' || settings.fitMode === 'fit-screen' || settings.fitMode === 'smart-fit' || settings.fitMode === 'stretch'
                  ? '0 4px'
                  : '12px 0 80px',
              filter: stageFilter,
              transform: zoom > 1 ? `translate3d(${pan.x}px, ${pan.y}px, 0) scale(${zoom})` : undefined,
              transformOrigin: 'center center',
              transition: isPinching || motionReduced() ? 'none' : 'transform 140ms ease-out',
            }}
          >
            {visualSpreadOrder.map((slot) => {
              const key = `${chapterId}:${slot.pageIndex}:${slot.cropHalf ?? 'full'}`;
              const rawKey = `${chapterId}:${slot.pageIndex}`;
              return (
                <ReaderPageImage
                  key={key}
                  src={pages[slot.pageIndex]}
                  pageNumber={slot.pageIndex + 1}
                  fitMode={settings.fitMode}
                  isWebtoon={false}
                  isDoubleSpread={visualSpreadOrder.length === 2}
                  cropHalf={slot.cropHalf}
                  rotateWide={settings.rotateWidePages}
                  eager
                  cropBorders={settings.cropBorders}
                  detectPanels={settings.guidedPanelZoom}
                  knownAspect={aspectMapRef.current.get(rawKey)}
                  reloadToken={pageReloadTokens[rawKey] ?? 0}
                  onDimensions={(w, h) => handlePageDimensions(chapterId, slot.pageIndex, w, h)}
                  onPanelsDetected={(panels) =>
                    setDetectedPanelsByKey((prev) => (prev[rawKey] ? prev : { ...prev, [rawKey]: panels }))
                  }
                  onLongPress={(resolvedUrl, num) => {
                    lastSwipeAtRef.current = Date.now();
                    setPageAction({ url: resolvedUrl, pageNumber: num, key: rawKey });
                  }}
                />
              );
            })}
            {/* Subtle comic-book spine shadow along center seam in double-page spreads */}
            {isDouble && visualSpreadOrder.length === 2 && (
              <div
                aria-hidden
                style={{
                  position: 'absolute',
                  top: 0,
                  bottom: 0,
                  left: '50%',
                  width: 24,
                  transform: 'translateX(-50%)',
                  background: 'linear-gradient(90deg, transparent 0%, rgba(0,0,0,0.28) 50%, transparent 100%)',
                  pointerEvents: 'none',
                }}
              />
            )}
          </div>
        )}
      </div>

      {/* GPU-friendly brightness dimmer overlay (preserves OLED True Black) */}
      {settings.brightness < 1 && (
        <div
          aria-hidden
          style={{
            position: 'fixed',
            inset: 0,
            zIndex: 92,
            background: `rgba(0, 0, 0, ${(1 - settings.brightness).toFixed(2)})`,
            pointerEvents: 'none',
          }}
        />
      )}

      {/* E-ink page-turn refresh flash */}
      {einkFlashing && (
        <div
          aria-hidden
          style={{
            position: 'fixed',
            inset: 0,
            zIndex: 94,
            background: '#000000',
            pointerEvents: 'none',
          }}
        />
      )}

      {/* Tap-zone guide overlay (accurately reflects Standard, Edge, Kindle & L-Shaped layouts) */}
      {showZoneGuide && (
        <div
          aria-hidden="true"
          onClick={() => showTapHint && setShowTapHint(false)}
          style={{
            position: 'fixed',
            inset: 0,
            zIndex: 96,
            display: 'grid',
            gridTemplateColumns:
              settings.tapZoneLayout === 'edge'
                ? '22% 56% 22%'
                : settings.tapZoneLayout === 'kindle'
                  ? isRtl
                    ? '75% 25%'
                    : '25% 75%'
                  : '30% 40% 30%',
            gridTemplateRows:
              settings.tapZoneLayout === 'kindle'
                ? '22% 78%'
                : settings.tapZoneLayout === 'l-shaped'
                  ? '25% 50% 25%'
                  : '100%',
            pointerEvents: showTapHint ? 'auto' : 'none',
            opacity: showTapHint ? 1 : 0.35,
          }}
        >
          {settings.tapZoneLayout === 'kindle' ? (
            <>
              <div style={{ gridColumn: '1 / -1', background: 'rgba(11, 13, 18, 0.5)', borderBottom: '1px dashed rgba(255,255,255,0.45)', display: 'grid', placeItems: 'center', color: '#FFF', fontWeight: 700, fontSize: 13 }}>
                HUD Menu
              </div>
              <div style={{ background: isRtl ? 'rgba(245, 158, 11, 0.22)' : 'rgba(96, 165, 250, 0.22)', borderRight: '1px dashed rgba(255,255,255,0.45)', display: 'grid', placeItems: 'center', color: '#FFF', fontWeight: 700, fontSize: 13 }}>
                {isRtl !== settings.invertTapZones ? 'Next' : 'Prev'}
              </div>
              <div style={{ background: isRtl ? 'rgba(96, 165, 250, 0.22)' : 'rgba(245, 158, 11, 0.22)', display: 'grid', placeItems: 'center', color: '#FFF', fontWeight: 700, fontSize: 13 }}>
                {isRtl !== settings.invertTapZones ? 'Prev' : 'Next'}
              </div>
            </>
          ) : settings.tapZoneLayout === 'l-shaped' ? (
            <>
              <div style={{ gridColumn: '1 / -1', background: 'rgba(96, 165, 250, 0.22)', borderBottom: '1px dashed rgba(255,255,255,0.45)', display: 'grid', placeItems: 'center', color: '#FFF', fontWeight: 700, fontSize: 13 }}>
                {settings.invertTapZones ? 'Next' : 'Prev'}
              </div>
              <div style={{ background: isRtl ? 'rgba(245, 158, 11, 0.22)' : 'rgba(96, 165, 250, 0.22)', borderRight: '1px dashed rgba(255,255,255,0.45)', display: 'grid', placeItems: 'center', color: '#FFF', fontWeight: 700, fontSize: 13 }}>
                {isRtl !== settings.invertTapZones ? 'Next' : 'Prev'}
              </div>
              <div style={{ background: 'rgba(11, 13, 18, 0.5)', display: 'grid', placeItems: 'center', color: '#FFF', fontWeight: 700, fontSize: 13 }}>
                HUD
              </div>
              <div style={{ background: isRtl ? 'rgba(96, 165, 250, 0.22)' : 'rgba(245, 158, 11, 0.22)', borderLeft: '1px dashed rgba(255,255,255,0.45)', display: 'grid', placeItems: 'center', color: '#FFF', fontWeight: 700, fontSize: 13 }}>
                {isRtl !== settings.invertTapZones ? 'Prev' : 'Next'}
              </div>
              <div style={{ gridColumn: '1 / -1', background: 'rgba(245, 158, 11, 0.22)', borderTop: '1px dashed rgba(255,255,255,0.45)', display: 'grid', placeItems: 'center', color: '#FFF', fontWeight: 700, fontSize: 13 }}>
                {settings.invertTapZones ? 'Prev' : 'Next'}
              </div>
            </>
          ) : (
            <>
              <div style={{ background: 'rgba(245, 158, 11, 0.22)', borderRight: '1px dashed rgba(255,255,255,0.45)', display: 'grid', placeItems: 'center', color: '#FFF', fontWeight: 700, fontSize: 13 }}>
                {isRtl !== settings.invertTapZones ? 'Next' : 'Prev'}
              </div>
              <div style={{ background: showTapHint ? 'rgba(11, 13, 18, 0.5)' : 'transparent', display: 'grid', placeItems: 'center', color: '#FFF', fontWeight: 700, fontSize: 13, textAlign: 'center', padding: 12 }}>
                {showTapHint ? (
                  <div>
                    <div>Tap Center for Menu</div>
                    <div style={{ fontSize: 11.5, fontWeight: 500, opacity: 0.85, marginTop: 6 }}>
                      Double-tap to zoom • Swipe to turn
                      {viewportWidth >= 720 && viewportWidth <= viewportHeight && !isDouble
                        ? ' • Rotate or tap Spread for 2-page view'
                        : ''}
                    </div>
                  </div>
                ) : (
                  'HUD'
                )}
              </div>
              <div style={{ background: 'rgba(123, 97, 255, 0.2)', borderLeft: '1px dashed rgba(255,255,255,0.45)', display: 'grid', placeItems: 'center', color: '#FFF', fontWeight: 700, fontSize: 13 }}>
                {isRtl !== settings.invertTapZones ? 'Prev' : 'Next'}
              </div>
            </>
          )}
        </div>
      )}

      {/* Touch fast-scroll scrubber for long-strip reading (reachable even mid-scroll, with chapter tick marks) */}
      {isWebtoon && settings.verticalSeekbar !== 'off' && showUi && pages.length > 1 && !loading && (
        <div
          onClick={(e) => e.stopPropagation()}
          onPointerDown={(e) => {
            e.stopPropagation();
            const track = e.currentTarget.getBoundingClientRect();
            const innerTop = track.top + 14;
            const innerHeight = Math.max(1, track.height - 28);
            const ratio = Math.min(1, Math.max(0, (e.clientY - innerTop) / innerHeight));
            const targetIdx = Math.min(pages.length - 1, Math.max(0, Math.round(ratio * (pages.length - 1))));
            jumpToPage(targetIdx);
          }}
          style={{
            position: 'fixed',
            top: 'calc(76px + env(safe-area-inset-top))',
            bottom: 'calc(126px + env(safe-area-inset-bottom))',
            ...(settings.verticalSeekbar === 'left'
              ? { left: 'max(4px, env(safe-area-inset-left))' }
              : { right: 'max(4px, env(safe-area-inset-right))' }),
            zIndex: 97,
            width: viewportWidth < 600 ? 32 : 38,
            borderRadius: 99,
            background: allowBlur ? 'rgba(11, 13, 18, 0.56)' : 'rgba(11, 13, 18, 0.82)',
            border: `1px solid ${showUi ? 'rgba(245, 158, 11, 0.36)' : 'rgba(255, 255, 255, 0.14)'}`,
            ...(allowBlur ? { backdropFilter: 'blur(8px)' } : {}),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '10px 0',
            opacity: showUi ? 1 : 0.48,
            transition: 'opacity 180ms ease, border-color 180ms ease',
            touchAction: 'none',
          }}
        >
          {/* Chapter tick marks along the fast-scroll scrubber track */}
          {segments.length > 1 &&
            (() => {
              const totalChainedPages = segments.reduce((sum, s) => sum + s.pages.length, 0);
              let accum = 0;
              return segments.slice(0, -1).map((seg) => {
                accum += seg.pages.length;
                const pct = totalChainedPages > 0 ? Math.min(96, Math.max(4, Math.round((accum / totalChainedPages) * 100))) : 50;
                return (
                  <span
                    key={`tick-${seg.chapter.id}`}
                    title={`Chapter boundary: ${chapterDisplayTitle(seg.chapter)}`}
                    aria-hidden="true"
                    style={{
                      position: 'absolute',
                      top: `${pct}%`,
                      left: 5,
                      right: 5,
                      height: 2,
                      borderRadius: 2,
                      background: KatanaColors.accent,
                      opacity: 0.85,
                      pointerEvents: 'none',
                    }}
                  />
                );
              });
            })()}
          <input
            type="range"
            className="manga-range manga-range--vertical"
            min={1}
            max={pages.length}
            value={Math.min(pages.length, pageIdx + 1)}
            aria-label="Vertical page scrubber"
            onChange={(e) => jumpToPage(Number(e.target.value) - 1)}
            style={{
              writingMode: 'vertical-lr',
            }}
          />
          <span
            aria-hidden="true"
            style={{
              position: 'absolute',
              bottom: 4,
              fontSize: 9.5,
              fontWeight: 800,
              color: KatanaColors.accentSoft,
              pointerEvents: 'none',
            }}
          >
            {pageIdx + 1}
          </span>
        </div>
      )}

      {/* De-conflicted bottom-left floating pill stack (Retry Failed + Auto-Read + Zoom Reset) */}
      {(autoScrolling || zoom > 1 || failedPageKeys.length > 0) && (
        <div
          style={{
            position: 'fixed',
            left: 'max(14px, env(safe-area-inset-left))',
            bottom: showUi ? 'calc(118px + env(safe-area-inset-bottom))' : 'max(14px, env(safe-area-inset-bottom))',
            zIndex: 99,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'flex-start',
            gap: 8,
          }}
        >
          {failedPageKeys.length > 0 && (
            <button
              type="button"
              className="bare-button player-focusable"
              onClick={(e) => {
                e.stopPropagation();
                retryAllFailedPages();
              }}
              style={{
                minHeight: 38,
                padding: '0 14px',
                borderRadius: 99,
                background: KatanaColors.accent,
                color: '#FFFFFF',
                fontSize: 12.5,
                fontWeight: 700,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
              }}
            >
              <Icon name="refresh" size={16} color="#FFFFFF" />
              Retry {failedPageKeys.length} Failed
            </button>
          )}
          {zoom > 1 && (
            <button
              type="button"
              className="bare-button player-focusable"
              onClick={(e) => {
                e.stopPropagation();
                setZoom(1);
                setPan({ x: 0, y: 0 });
              }}
              style={{
                minHeight: 38,
                padding: '0 14px',
                borderRadius: 99,
                background: 'rgba(14, 9, 18, 0.88)',
                border: `1px solid ${KatanaColors.accent}`,
                color: KatanaColors.accentSoft,
                fontSize: 12.5,
                fontWeight: 700,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
                ...(allowBlur ? { backdropFilter: 'blur(10px)' } : {}),
              }}
            >
              <Icon name="zoom_out_map" size={16} color={KatanaColors.accentSoft} />
              {zoom.toFixed(1)}× Reset
            </button>
          )}
          {autoScrolling && (
            <button
              type="button"
              className="bare-button player-focusable"
              onClick={(e) => {
                e.stopPropagation();
                setAutoScrolling(false);
              }}
              style={{
                minHeight: 36,
                padding: '0 12px',
                borderRadius: 99,
                background: 'rgba(14, 9, 18, 0.86)',
                border: `1px solid ${KatanaColors.accent}`,
                color: KatanaColors.accentSoft,
                fontSize: 12,
                fontWeight: 700,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
                ...(allowBlur ? { backdropFilter: 'blur(8px)' } : {}),
              }}
            >
              <Icon name="pause" size={16} color={KatanaColors.accentSoft} />
              {isWebtoon ? `Auto-Scroll ${settings.autoScrollSpeed}×` : `Auto-Advance ${Math.round(7.5 / settings.autoScrollSpeed)}s`}
            </button>
          )}
        </div>
      )}

      {/* Brief mode / chapter toast */}
      {toast && (
        <div
          role="status"
          aria-live="polite"
          style={{
            position: 'fixed',
            left: '50%',
            bottom: showUi ? hudInset.bottom + 10 : 'max(18px, env(safe-area-inset-bottom))',
            transform: 'translateX(-50%)',
            zIndex: 100,
            padding: '6px 14px',
            borderRadius: 99,
            background: 'rgba(11, 13, 18, 0.94)',
            border: `1px solid ${KatanaColors.borderStrong}`,
            color: KatanaColors.text,
            fontSize: 12.5,
            fontWeight: 600,
            pointerEvents: 'none',
            whiteSpace: 'nowrap',
            maxWidth: '86vw',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            ...(allowBlur ? { backdropFilter: 'blur(10px)' } : {}),
          }}
        >
          {toast}
        </div>
      )}

      {/* Persistent unobtrusive interactive control & page indicator pill when HUD is hidden */}
      {!showUi && pages.length > 0 && !loading && (
        <button
          type="button"
          className="bare-button player-focusable"
          aria-label={`Show reader controls (${displayPageLabel})`}
          title="Show reader controls"
          onClick={(e) => {
            e.stopPropagation();
            setShowUi(true);
          }}
          style={{
            position: 'fixed',
            right: 'max(12px, env(safe-area-inset-right))',
            bottom: 'max(12px, env(safe-area-inset-bottom))',
            zIndex: 95,
            minHeight: 44,
            minWidth: 44,
            padding: '5px 14px',
            borderRadius: 99,
            background: allowBlur ? 'rgba(11, 13, 18, 0.72)' : 'rgba(11, 13, 18, 0.9)',
            border: `1px solid ${withAlpha(KatanaColors.accent, 0.28)}`,
            color: KatanaColors.text,
            opacity: pillQuiet ? 0 : pageIdx === pages.length - 1 ? 0.62 : 0.92,
            pointerEvents: pillQuiet ? 'none' : 'auto',
            transition: motionReduced() ? 'none' : 'opacity 260ms ease',
            fontSize: 11.5,
            fontWeight: 700,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 5,
            cursor: 'pointer',
            boxShadow: '0 4px 12px rgba(0, 0, 0, 0.45)',
            ...(allowBlur ? { backdropFilter: 'blur(8px)' } : {}),
          }}
        >
          <Icon name="tune" size={14} color={KatanaColors.accentSoft} />
          <span>{settings.showPageIndicator ? `${displayPageLabel} · Controls` : 'Controls'}</span>
        </button>
      )}

      {/* Compact translucent top HUD bar */}
      <div
        ref={hudTopRef}
        onClick={(e) => e.stopPropagation()}
        style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          zIndex: 98,
          paddingTop: 'max(6px, env(safe-area-inset-top))',
          paddingLeft: 'max(8px, env(safe-area-inset-left))',
          paddingRight: 'max(8px, env(safe-area-inset-right))',
          paddingBottom: 8,
          background: allowBlur ? 'rgba(11, 13, 18, 0.82)' : 'rgba(11, 13, 18, 0.96)',
          borderBottom: `1px solid ${KatanaColors.border}`,
          ...(allowBlur ? { backdropFilter: 'blur(12px)' } : {}),
          display: 'flex',
          alignItems: 'center',
          gap: 6,
          opacity: showUi ? 1 : 0,
          transform: showUi ? 'translateY(0)' : 'translateY(-100%)',
          pointerEvents: showUi ? 'auto' : 'none',
          transition: motionReduced() ? 'none' : 'opacity 180ms ease, transform 200ms cubic-bezier(0.22, 1, 0.36, 1)',
        }}
      >
        <button
          type="button"
          className="bare-button player-focusable"
          aria-label="Close reader"
          onClick={onClose}
          style={{
            width: 44,
            height: 44,
            borderRadius: 12,
            display: 'grid',
            placeItems: 'center',
            flexShrink: 0,
          }}
        >
          <Icon name="arrow_back" size={22} color={KatanaColors.accentSoft} />
        </button>

        <button
          type="button"
          className="bare-button player-focusable"
          aria-label="Open chapters and bookmarks"
          onClick={() => setActiveSheet('chapters')}
          style={{
            flex: 1,
            minWidth: 0,
            minHeight: 44,
            padding: '2px 4px',
            borderRadius: 10,
            textAlign: 'left',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, minWidth: 0 }}>
            <div className="ellipsis" style={{ ...KatanaType.title, fontSize: isCompactPhone ? 13.5 : 14 }}>
              {params.mangaTitle}
            </div>
            {!incognitoSession && currentUser && (
              <span
                title="Exact page and scroll position synced across phone and tablet"
                style={{
                  fontSize: 9.5,
                  fontWeight: 700,
                  padding: '1px 5px',
                  borderRadius: 4,
                  background: KatanaColors.surfaceAlt,
                  border: `1px solid ${KatanaColors.border}`,
                  color: KatanaColors.textMuted,
                  flexShrink: 0,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 2,
                }}
              >
                <Icon name="cloud_done" size={10} color={KatanaColors.accentSoft} />
                <span>Synced</span>
              </span>
            )}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, marginTop: 1 }}>
            <span className="ellipsis" style={{ ...KatanaType.small, lineHeight: 1.4, paddingBottom: 1, color: KatanaColors.accentSoft }}>
              {chapterDisplayTitle(activeChapter)}
            </span>
            {incognitoSession && (
              <span
                style={{
                  fontSize: 10,
                  fontWeight: 700,
                  padding: '1px 5px',
                  borderRadius: 4,
                  background: KatanaColors.surfaceGlow,
                  border: `1px solid ${KatanaColors.accent}`,
                  color: KatanaColors.accentSoft,
                  flexShrink: 0,
                }}
              >
                Incognito
              </span>
            )}
            <Icon name="expand_more" size={16} color={KatanaColors.accentSoft} />
          </div>
        </button>

        <button
          type="button"
          className="bare-button player-focusable"
          aria-label={`Reading mode: ${resolvedModeAriaLabel}. Tap to switch`}
          title={`Reading mode: ${resolvedModeAriaLabel}`}
          onClick={cycleMode}
          style={{
            minHeight: 44,
            padding: isCompactPhone ? '0 8px' : '0 10px',
            borderRadius: 10,
            background: KatanaColors.surfaceAlt,
            border: `1px solid ${KatanaColors.border}`,
            color: KatanaColors.accentSoft,
            fontSize: isCompactPhone ? 11.5 : 12,
            fontWeight: 600,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 4,
            flexShrink: 0,
          }}
        >
          <Icon name={effectiveMeta.icon} size={16} color={KatanaColors.accentSoft} />
          <span>{isCompactPhone ? effectiveMeta.shortLabel : resolvedModeShortLabel}</span>
        </button>

        {isTabletOrWide && !isWebtoon && (
          <button
            type="button"
            className="bare-button player-focusable"
            aria-label={isDouble ? 'Switch to single page view' : 'Switch to 2-page spread view'}
            aria-pressed={isDouble}
            title={isDouble ? '2-Page Spread active (tap for 1-Page)' : 'Enable 2-Page Spread on tablet'}
            onClick={() => {
              const nextMode = isDouble
                ? isRtl
                  ? 'paged-rtl'
                  : 'paged-ltr'
                : isRtl
                  ? 'double-rtl'
                  : 'double-ltr';
              updateSettings({ readingMode: nextMode });
            }}
            style={{
              minHeight: 44,
              padding: '0 10px',
              borderRadius: 10,
              background: isDouble ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
              border: `1px solid ${isDouble ? KatanaColors.accent : KatanaColors.border}`,
              color: isDouble ? KatanaColors.accentSoft : KatanaColors.textMuted,
              fontSize: 12,
              fontWeight: 700,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 4,
              flexShrink: 0,
            }}
          >
            <Icon name="auto_stories" size={16} color={isDouble ? KatanaColors.accent : KatanaColors.textMuted} />
            <span>{isDouble ? '2P Spread' : '2P'}</span>
          </button>
        )}

        {canFullscreen && !isCompactPhone && (
          <button
            type="button"
            className="bare-button player-focusable"
            aria-label={isFullscreen ? 'Exit fullscreen' : 'Enter fullscreen'}
            onClick={toggleFullscreen}
            style={{
              width: 44,
              height: 44,
              borderRadius: 10,
              display: 'grid',
              placeItems: 'center',
              background: KatanaColors.surfaceAlt,
              border: `1px solid ${KatanaColors.border}`,
              flexShrink: 0,
            }}
          >
            <Icon name={isFullscreen ? 'fullscreen_exit' : 'fullscreen'} size={20} color={KatanaColors.textMuted} />
          </button>
        )}

        <button
          type="button"
          className="bare-button player-focusable"
          aria-label="Reader settings"
          onClick={() => setActiveSheet('settings')}
          style={{
            width: 44,
            height: 44,
            borderRadius: 10,
            display: 'grid',
            placeItems: 'center',
            background: KatanaColors.surfaceAlt,
            border: `1px solid ${KatanaColors.border}`,
            flexShrink: 0,
          }}
        >
          <Icon name="tune" size={20} color={KatanaColors.accentSoft} />
        </button>
      </div>

      {/* Compact translucent bottom HUD bar */}
      <div
        ref={hudBottomRef}
        onClick={(e) => e.stopPropagation()}
        style={{
          position: 'fixed',
          bottom: 0,
          left: 0,
          right: 0,
          zIndex: 98,
          paddingTop: 8,
          paddingLeft: 'max(12px, env(safe-area-inset-left))',
          paddingRight: 'max(12px, env(safe-area-inset-right))',
          paddingBottom: 'max(8px, env(safe-area-inset-bottom))',
          background: allowBlur ? 'rgba(11, 13, 18, 0.88)' : 'rgba(11, 13, 18, 0.97)',
          borderTop: `1px solid ${KatanaColors.border}`,
          ...(allowBlur ? { backdropFilter: 'blur(12px)' } : {}),
          display: 'flex',
          flexDirection: 'column',
          gap: 6,
          opacity: showUi ? 1 : 0,
          transform: showUi ? 'translateY(0)' : 'translateY(100%)',
          pointerEvents: showUi ? 'auto' : 'none',
          transition: motionReduced() ? 'none' : 'opacity 180ms ease, transform 200ms cubic-bezier(0.22, 1, 0.36, 1)',
        }}
      >
        <div
          style={{
            width: '100%',
            maxWidth: 760,
            margin: '0 auto',
            display: 'flex',
            flexDirection: 'column',
            gap: 8,
          }}
        >
        {evictedOfflineState && evictedOfflineState.missingPages > 0 && (
          <div
            style={{
              padding: '6px 10px',
              borderRadius: 8,
              background: 'rgba(245, 158, 11, 0.15)',
              border: `1px solid ${KatanaColors.accent}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              flexWrap: 'wrap',
              gap: 8,
            }}
          >
            <span style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.text, fontWeight: 600 }}>
              <Icon name="warning_amber" size={14} color={KatanaColors.accent} />{' '}
              {evictedOfflineState.missingPages} of {evictedOfflineState.totalPages} offline page(s) evicted from cache
            </span>
            <button
              type="button"
              className="bare-button player-focusable"
              disabled={repairingOffline}
              onClick={async () => {
                if (repairingOffline) return;
                setRepairingOffline(true);
                try {
                  await offlineMedia.repairMangaChapter(evictedOfflineState.itemId, proxyKatanaImageUrl);
                  const check = await offlineMedia.verifyMangaChapterCache(evictedOfflineState.itemId);
                  if (check.isComplete) {
                    setEvictedOfflineState(null);
                    prefetchedChapterRef.current.delete(`${chapterId}|${server}`);
                    setReloadNonce((n) => n + 1);
                  } else {
                    setEvictedOfflineState({
                      itemId: evictedOfflineState.itemId,
                      missingPages: check.missingPages,
                      totalPages: check.totalPages,
                    });
                  }
                } finally {
                  setRepairingOffline(false);
                }
              }}
              style={{
                minHeight: 30,
                padding: '3px 10px',
                borderRadius: 6,
                background: KatanaColors.accent,
                color: KatanaColors.accentInk,
                fontSize: 11.5,
                fontWeight: 800,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 4,
              }}
            >
              <Icon name="build" size={13} color={KatanaColors.accentInk} />
              <span>{repairingOffline ? 'Repairing…' : 'Repair Offline Cache'}</span>
            </button>
          </div>
        )}
        {!seenOnboardingHint && (
          <div
            style={{
              padding: '5px 10px',
              borderRadius: 8,
              background: KatanaColors.surfaceAlt,
              border: `1px solid ${KatanaColors.border}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              flexWrap: 'wrap',
              gap: 6,
            }}
          >
            <span style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.textMuted }}>
              {isWebtoon
                ? 'Tap the middle of the page to show or hide the menu · Scroll to keep reading'
                : 'Tap the middle of the page to show or hide the menu · Tap or swipe the left and right edges to turn pages'}
            </span>
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
              {!isWebtoon && (
                <button
                  type="button"
                  className="bare-button player-focusable"
                  onClick={() => setShowTapHint((v) => !v)}
                  style={{
                    minHeight: 44,
                    padding: '8px 14px',
                    borderRadius: 8,
                    background: KatanaColors.surface,
                    border: `1px solid ${KatanaColors.borderStrong}`,
                    color: KatanaColors.accentSoft,
                    fontSize: 12.5,
                    fontWeight: 700,
                  }}
                >
                  {showTapHint ? 'Hide Zones' : 'Touch Zones'}
                </button>
              )}
              <button
                type="button"
                className="bare-button player-focusable"
                aria-label="Got it, hide this tip"
                onClick={() => {
                  markReaderHintSeen();
                  setSeenOnboardingHint(true);
                }}
                style={{
                  minHeight: 44,
                  padding: '6px 12px',
                  borderRadius: 6,
                  background: 'transparent',
                  color: KatanaColors.textLight,
                  fontSize: 12,
                  fontWeight: 700,
                }}
              >
                Got it
              </button>
            </div>
          </div>
        )}
        {pages.length > 1 && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <button
              type="button"
              className="bare-button player-focusable"
              aria-label={`Page ${displayPageLabel}. Tap to type a page number`}
              onClick={() => setActiveSheet('jump')}
              style={{
                minWidth: 62,
                minHeight: 44,
                padding: '0 8px',
                borderRadius: 8,
                background: KatanaColors.surfaceAlt,
                border: `1px solid ${KatanaColors.border}`,
                color: KatanaColors.text,
                fontSize: 12,
                fontWeight: 700,
                textAlign: 'center',
              }}
            >
              {displayPageLabel}
            </button>
            <input
              type="range"
              className="manga-range"
              min={1}
              max={pages.length}
              value={Math.min(pages.length, pageIdx + 1)}
              aria-label="Jump to page"
              onChange={(e) => jumpToPage(Number(e.target.value) - 1)}
              style={{
                flex: 1,
                direction: isRtl ? 'rtl' : 'ltr',
              }}
            />
            {isRtl && (
              <span
                style={{
                  fontSize: 10.5,
                  fontWeight: 700,
                  padding: '2px 7px',
                  borderRadius: 6,
                  background: KatanaColors.surfaceAlt,
                  border: `1px solid ${KatanaColors.border}`,
                  color: KatanaColors.accentSoft,
                }}
              >
                Right to left
              </span>
            )}
          </div>
        )}

        <div
          style={{
            display: 'flex',
            flexDirection: isRtl ? 'row-reverse' : 'row',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 6,
          }}
        >
          <button
            type="button"
            className="bare-button player-focusable"
            disabled={!prevChapter}
            aria-label="Previous chapter"
            onClick={() => prevChapter && navigateToChapter(prevChapter.id, { warnGap: true })}
            style={{
              minHeight: 44,
              padding: '0 10px',
              borderRadius: 10,
              background: KatanaColors.surfaceAlt,
              border: `1px solid ${KatanaColors.border}`,
              color: prevChapter ? KatanaColors.text : KatanaColors.textLight,
              opacity: prevChapter ? 1 : 0.45,
              fontSize: 12,
              fontWeight: 600,
              display: 'inline-flex',
              flexDirection: isRtl ? 'row-reverse' : 'row',
              alignItems: 'center',
              gap: 3,
            }}
          >
            <Icon name={isRtl ? 'skip_next' : 'skip_previous'} size={18} color={prevChapter ? KatanaColors.text : KatanaColors.textLight} />
            {!isCompactPhone && <span>Prev</span>}
          </button>

          <div style={{ display: 'flex', alignItems: 'center', gap: isCompactPhone ? 8 : 6 }}>
            <button
              type="button"
              className="bare-button player-focusable"
              aria-label={autoScrolling ? 'Pause auto-read' : 'Start auto-read'}
              onClick={() => setAutoScrolling((a) => !a)}
              style={{
                width: 44,
                height: 44,
                borderRadius: 10,
                background: autoScrolling ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                border: `1px solid ${autoScrolling ? KatanaColors.accent : KatanaColors.border}`,
                display: 'grid',
                placeItems: 'center',
              }}
            >
              <Icon
                name={autoScrolling ? 'pause' : 'play_arrow'}
                size={19}
                color={autoScrolling ? KatanaColors.accentSoft : KatanaColors.textMuted}
              />
            </button>

            <button
              type="button"
              className="bare-button player-focusable"
              aria-label={currentBookmarked ? 'Remove page bookmark' : 'Bookmark current page'}
              onClick={() => pages.length > 0 && togglePageBookmark(chapterId, pageIdx)}
              style={{
                width: 44,
                height: 44,
                borderRadius: 10,
                background: currentBookmarked ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                border: `1px solid ${currentBookmarked ? KatanaColors.accent : KatanaColors.border}`,
                display: 'grid',
                placeItems: 'center',
              }}
            >
              <Icon
                name={currentBookmarked ? 'bookmark' : 'bookmark_border'}
                size={19}
                color={currentBookmarked ? KatanaColors.accentSoft : KatanaColors.textMuted}
              />
            </button>

            <button
              type="button"
              className="bare-button player-focusable"
              aria-label="Quick brightness and display"
              onClick={() => setActiveSheet('quick-display')}
              style={{
                width: 44,
                height: 44,
                borderRadius: 10,
                background: activeSheet === 'quick-display' ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                border: `1px solid ${activeSheet === 'quick-display' ? KatanaColors.accent : KatanaColors.border}`,
                display: 'grid',
                placeItems: 'center',
              }}
            >
              <Icon name="brightness_6" size={19} color={KatanaColors.textMuted} />
            </button>

            {!isCompactPhone && (
              <button
                type="button"
                className="bare-button player-focusable"
                aria-label="Open chapters and bookmarks"
                onClick={() => setActiveSheet('chapters')}
                style={{
                  width: 44,
                  height: 44,
                  borderRadius: 10,
                  background: KatanaColors.surfaceAlt,
                  border: `1px solid ${KatanaColors.border}`,
                  display: 'grid',
                  placeItems: 'center',
                }}
              >
                <Icon name="format_list_numbered" size={19} color={KatanaColors.textMuted} />
              </button>
            )}
          </div>

          <button
            type="button"
            className="bare-button player-focusable"
            disabled={!nextChapter}
            aria-label="Next chapter"
            onClick={() => nextChapter && navigateToChapter(nextChapter.id, { markPrevFinished: true, warnGap: true })}
            style={{
              minHeight: 44,
              padding: '0 10px',
              borderRadius: 10,
              background: nextChapter ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
              border: `1px solid ${nextChapter ? KatanaColors.accent : KatanaColors.border}`,
              color: nextChapter ? KatanaColors.accentSoft : KatanaColors.textLight,
              opacity: nextChapter ? 1 : 0.45,
              fontSize: 12,
              fontWeight: 600,
              display: 'inline-flex',
              flexDirection: isRtl ? 'row-reverse' : 'row',
              alignItems: 'center',
              gap: 3,
            }}
          >
            {!isCompactPhone && <span>Next</span>}
            <Icon name={isRtl ? 'skip_previous' : 'skip_next'} size={18} color={nextChapter ? KatanaColors.accentSoft : KatanaColors.textLight} />
          </button>
        </div>
        </div>
      </div>

      {/* Sheets & dialogs */}
      {activeSheet === 'chapters' && (
        <ChapterDrawerSheet
          chapters={params.chapters}
          currentChapterId={chapterId}
          currentPageIdx={pageIdx}
          pages={pages}
          readChapterIds={readIds}
          pageBookmarks={pageBookmarks}
          mangaTitle={params.mangaTitle}
          onSelectChapter={(id) => navigateToChapter(id)}
          onSelectPage={(idx) => jumpToPage(idx)}
          onToggleChapterRead={(id) => {
            setReadIds((prev) => {
              const next = new Set(prev);
              const willRead = !next.has(id);
              if (willRead) next.add(id);
              else next.delete(id);
              if (currentUser && !incognitoSession) {
                void markKatanaChaptersRead(
                  {
                    slug: params.slug,
                    title: params.mangaTitle,
                    coverUrl: params.coverUrl ?? '',
                    status: params.mangaStatus ?? 'ongoing',
                  },
                  currentUser,
                  [id],
                  willRead,
                );
              }
              return next;
            });
          }}
          onSelectBookmark={(bm) => {
            if (bm.chapterId === chapterId) {
              jumpToPage(bm.pageIdx);
            } else {
              navigateToChapter(bm.chapterId, { targetPageIdx: bm.pageIdx });
            }
          }}
          onRemoveBookmark={(bm) => togglePageBookmark(bm.chapterId, bm.pageIdx)}
          onUpdateBookmarkNote={updatePageBookmarkNote}
          onClose={() => setActiveSheet('none')}
        />
      )}

      {activeSheet === 'quick-display' && (
        <QuickDisplayPopover
          settings={settings}
          onUpdateSettings={updateSettings}
          onOpenFullSettings={() => setActiveSheet('settings')}
          onClose={() => setActiveSheet('none')}
        />
      )}

      {guidedActive && guidedPanels.length > 1 && (
        <button
          type="button"
          className="bare-button"
          aria-label={`Guided panel ${guidedPanelIdx + 1} of ${guidedPanels.length}. Tap to exit guided panel zoom.`}
          onClick={() => updateSettings({ guidedPanelZoom: false })}
          style={{
            position: 'fixed',
            bottom: showUi ? 124 : 18,
            left: 16,
            zIndex: 92,
            padding: '5px 11px',
            borderRadius: 99,
            background: 'rgba(12, 13, 19, 0.84)',
            border: `1px solid ${KatanaColors.accent}`,
            color: KatanaColors.accentSoft,
            fontSize: 11.5,
            fontWeight: 700,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 5,
          }}
        >
          <Icon name="center_focus_strong" size={14} color={KatanaColors.accent} />
          <span>Panel {Math.min(guidedPanelIdx + 1, guidedPanels.length)}/{guidedPanels.length}</span>
        </button>
      )}

      {sleepTimerExpired && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="Sleep timer ended"
          onClick={() => setSleepTimerExpired(false)}
          style={{
            position: 'fixed',
            inset: 0,
            zIndex: 145,
            background: 'rgba(6, 7, 11, 0.92)',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 12,
            padding: 24,
            textAlign: 'center',
            cursor: 'pointer',
          }}
        >
          <Icon name="bedtime" size={38} color={KatanaColors.accent} />
          <div style={{ ...KatanaType.title, fontSize: 20 }}>Sleep timer ended</div>
          <div style={{ ...KatanaType.body, maxWidth: 320 }}>
            Auto-scroll paused and screen wake lock released. Tap anywhere to keep reading.
          </div>
        </div>
      )}

      {activeSheet === 'settings' && (
        <ReaderSettingsSheet
          settings={settings}
          hasSeriesOverride={seriesOverride != null}
          server={server}
          sleepTimerEndAt={sleepTimerEndAt}
          sleepWaitChapterEnd={sleepWaitChapterEnd}
          incognitoSession={incognitoSession}
          onSetSleepTimer={handleSetSleepTimer}
          onToggleSleepWaitChapterEnd={(enabled) => {
            setSleepWaitChapterEnd(enabled);
            flashToast(enabled ? 'Sleep timer will finish current chapter first' : 'Sleep timer pauses immediately when time ends', true);
          }}
          onToggleIncognitoSession={(enabled) => {
            setKatanaIncognitoSession(enabled);
            flashToast(enabled ? 'Incognito reading session enabled' : 'Incognito reading session off', true);
          }}
          onUpdateSettings={updateSettings}
          onToggleSeriesOverride={toggleSeriesOverride}
          onChangeServer={(nextServer) => {
            setServer(nextServer);
            setReloadNonce((n) => n + 1);
            flashToast(`Switched to ${SERVER_OPTIONS.find((s) => s.value === nextServer)?.label ?? 'Server'}`, true);
          }}
          onClose={() => setActiveSheet('none')}
        />
      )}

      {activeSheet === 'jump' && pages.length > 1 && (
        <PageJumpDialog
          currentPage={pageIdx + 1}
          totalPages={pages.length}
          onJump={(num) => jumpToPage(num - 1)}
          onClose={() => setActiveSheet('none')}
        />
      )}

      {pageAction && (
        <PageActionSheet
          pageNumber={pageAction.pageNumber}
          mangaTitle={params.mangaTitle}
          chapterLabel={chapterDisplayTitle(activeChapter)}
          imageUrl={pageAction.url}
          isBookmarked={isPageBookmarked(chapterId, pageAction.pageNumber - 1)}
          onToggleBookmark={() => togglePageBookmark(chapterId, pageAction.pageNumber - 1)}
          onSetAsCover={
            currentUser
              ? () => {
                  void setKatanaSeriesCover(params.slug, params.mangaTitle, pageAction.url, currentUser);
                  flashToast('Updated series cover', true);
                }
              : undefined
          }
          onReloadPage={() =>
            setPageReloadTokens((prev) => ({ ...prev, [pageAction.key]: (prev[pageAction.key] ?? 0) + 1 }))
          }
          onOpenSettings={() => setActiveSheet('settings')}
          onClose={() => setPageAction(null)}
        />
      )}
    </div>
  );
}

export function MangaReaderPage() {
  const location = useLocation();
  const navigate = useNavigate();
  const stateParams = (location.state as MangaReaderParams | null) ?? null;
  const params = stateParams ?? (AgentMode.demo ? createDemoMangaReaderParams() : null);

  if (!params) {
    return (
      <div style={{ height: '100%', display: 'grid', placeItems: 'center', background: KatanaColors.background, color: KatanaColors.text }}>
        <div style={{ textAlign: 'center', padding: 24 }}>
          <div style={KatanaType.heading}>Open a chapter from Mangacelestia</div>
          <button
            type="button"
            className="bare-button player-focusable"
            onClick={() => navigate('/manga')}
            style={{
              marginTop: 14,
              minHeight: 44,
              padding: '0 20px',
              borderRadius: 99,
              background: KatanaColors.accent,
              color: '#FFF',
              fontWeight: 600,
            }}
          >
            Go to Mangacelestia
          </button>
        </div>
      </div>
    );
  }
  return <MangaReaderView params={params} onClose={() => (canPop() ? navigate(-1) : navigate('/manga'))} />;
}
