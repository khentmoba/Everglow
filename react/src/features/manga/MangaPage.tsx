import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useLocation, useNavigate, useParams, useSearchParams } from 'react-router';
import { useRememberedScroll } from '../../core/router/scrollMemory';
import { displayNameFor, useAuth } from '../../core/services/auth';
import { getPushDeliveryGuidance, IOS_PWA_PUSH_HINT_KEY } from '../../core/services/notifications';
import { OfflineIds, offlineMedia, useOfflineMedia, type OfflineMediaItem } from '../../core/services/offlineMedia';
import { useViewport } from '../../core/system/viewport';
import { withAlpha } from '../../core/theme/colors';
import { KatanaFonts as Fonts } from './katanaTokens';
import { useSource } from '../../core/utils/liveSource';
import { AlertDialog, TextButton, showDialog } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { TvMediaNavHeader } from '../../shared/widgets/shelf/TvMediaNavHeader';
import { MangaHome, type MangaType } from './MangaHome';
import {
  isOnMeteredCellular,
  KatanaDownloadsView,
  loadUnknownNetworkWifiPolicy,
  saveUnknownNetworkWifiPolicy,
  supportsNetworkConnectionApi,
} from './MangaDownloadsView';
import {
  loadSavedFilterPresets,
  MangaCatalogFilterPanel,
  saveFilterPresets,
  type SavedFilterPreset,
} from './MangaCatalogFilterPanel';
import { MangaReadingHistoryView } from './MangaReadingHistoryView';
import {
  computeTruthfulReadingStats,
  detectSeriesMissingChapters,
  estimateMangaBatchMegabytes,
  getSourceBadgeInfo,
  rankAndMergeMultiSourceCatalog,
  resolveOfficialPublisherLinks,
} from './mangaSearchAndTrust';
import { MangaReaderView, type MangaReaderParams } from './MangaReaderPage';
import { loadPageBookmarks, loadSeriesChapterFilter, saveSeriesChapterFilter } from './readerSettings';
import { inferSeriesReadingFormat } from './readerSpread';
import {
  KatanaBottomBar,
  KatanaBreadcrumb,
  KatanaButton,
  KatanaCard,
  KatanaCoverBadges,
  KatanaCoverImage,
  KatanaEmptyState,
  KatanaErrorBanner,
  KatanaHeader,
  KatanaItemCard,
  KatanaPagination,
  KatanaPosterCard,
  KatanaSectionHeader,
  KatanaSkeletonGrid,
  KatanaSkeletonList,
  type KatanaNavKey,
} from './MangaUi';
import {
  autoMatchAllTrackers,
  chapterDisplayTitle,
  checkKatanaChapterAlerts,
  clearKatanaReadingProgress,
  estimateUnreadCount,
  exportKatanaLibraryJson,
  exportKatanaLibraryMalXml,
  extractChapterNumber,
  fetchKatanaByType,
  fetchKatanaCatalog,
  fetchKatanaChapterPages,
  fetchKatanaDetail,
  fetchKatanaHome,
  filterHomeCatalogByType,
  formatCompactNumber,
  formatKatanaTime,
  getCachedKatanaByType,
  importKatanaLibraryJson,
  importKatanaLibraryMalXml,
  isBookmarkCaughtUp,
  isKatanaHistoryPaused,
  loadKatanaAlertPrefs,
  loadKatanaUserPrefs,
  loadKatanaAutoDownloadCount,
  loadKatanaCustomCategories,
  loadKatanaHiddenCategories,
  loadKatanaHistory,
  loadKatanaTrackerTokens,
  lookupAniListManga,
  lookupKitsuManga,
  lookupMalManga,
  MANGA_SOURCE_REGISTRY,
  markKatanaAlertSeen,
  markKatanaChaptersRead,
  mergeDuplicateKatanaBookmarks,
  migrateKatanaSeriesSource,
  proxyKatanaImageUrl,
  pushKatanaTrackerProgress,
  recordKatanaHistory,
  resolveLibraryStatus,
  saveKatanaAlertPrefs,
  saveKatanaAutoDownloadCount,
  saveKatanaCustomCategories,
  saveKatanaHiddenCategories,
  saveKatanaTrackerData,
  saveKatanaTrackerTokens,
  saveKatanaUserPrefs,
  searchBatoCatalog,
  searchComickCatalog,
  searchMangaDexCatalog,
  setKatanaBookmark,
  setKatanaBookmarkCategories,
  setKatanaLibraryStatus,
  syncKatanaBookmarkLatest,
  watchKatanaBookmarks,
  watchKatanaCustomCategories,
  watchKatanaHistory,
  watchKatanaRecentSearches,
  watchKatanaUserPrefs,
  type KatanaAlertPrefs,
  type KatanaBookmark,
  type KatanaCatalogSource,
  type KatanaChapter,
  type KatanaGenre,
  type KatanaHistoryEntry,
  type KatanaHomeData,
  type KatanaLibraryStatus,
  type KatanaManga,
} from './katanaService';
import {
  getKatanaGridColumns,
  KATANA_BREAKPOINTS,
  KATANA_THEME_VARS,
  KatanaColors,
  KatanaType,
  loadKatanaThemeMode,
  saveKatanaThemeMode,
  useCoverDominantAccent,
  type KatanaThemeMode,
} from './katanaTokens';
import { clearResumeAnchor } from './readerSettings';
import { MangaLibraryCollectionView, STATUS_LABELS } from './MangaLibraryView';

// ci:outline-none - text inputs sit inside .katana-input-shell, which draws the focus ring via :focus-within

const WIFI_ONLY_DL_KEY = 'katana.downloadWifiOnly.v1';

function loadWifiOnlyDownloads(): boolean {
  try {
    return localStorage.getItem(WIFI_ONLY_DL_KEY) === '1';
  } catch {
    return false;
  }
}

const PENDING_DL_QUEUE_KEY = 'katana_pending_dl_queue_v1';

interface PersistedQueueEntry {
  manga: KatanaManga;
  chapter: KatanaChapter;
}

function loadPendingDownloadQueue(): PersistedQueueEntry[] {
  try {
    const raw = localStorage.getItem(PENDING_DL_QUEUE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(
      (x): x is PersistedQueueEntry =>
        Boolean(x && x.manga && typeof x.manga.slug === 'string' && x.chapter && typeof x.chapter.id === 'string'),
    );
  } catch {
    return [];
  }
}

function savePendingDownloadQueue(items: PersistedQueueEntry[]): void {
  try {
    if (items.length === 0) localStorage.removeItem(PENDING_DL_QUEUE_KEY);
    else localStorage.setItem(PENDING_DL_QUEUE_KEY, JSON.stringify(items.slice(0, 60)));
  } catch {
    // ignore storage quota errors
  }
}

function extractTrackerId(input: string, kind: 'anilist' | 'mal' | 'kitsu'): string {
  const trimmed = input.trim();
  if (!trimmed) return '';
  if (/^\d+$/.test(trimmed)) return trimmed;
  const re =
    kind === 'anilist'
      ? /anilist\.co\/manga\/(\d+)/i
      : kind === 'kitsu'
        ? /kitsu\.(?:io|app)\/manga\/(\d+)/i
        : /myanimelist\.net\/manga\/(\d+)/i;
  const m = re.exec(trimmed);
  return m ? m[1] : trimmed.replace(/[^0-9]/g, '');
}

const VALID_TABS = new Set<KatanaNavKey>(['home', 'latest', 'directory', 'newManga', 'genres', 'reading', 'history', 'downloads', 'bookmarks']);
const VALID_TYPES = new Set<MangaType>(['all', 'manga', 'manhwa', 'manhua']);

function parseCsv(raw: string | null): string[] {
  if (!raw) return [];
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

export function MangaPage() {
  const { width } = useViewport();
  const { currentUser, isCoupleUser, partnerUsername } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const { slug: routeSlug, chapterId: routeChapterId } = useParams<{ slug?: string; chapterId?: string }>();
  const [searchParams] = useSearchParams();
  const offline = useOfflineMedia();

  // URL-driven navigation state so Back/Forward, refresh, and deep links work.
  const detailSlug = routeSlug ? decodeURIComponent(routeSlug) : null;
  const activeRouteChapterId = routeChapterId ? decodeURIComponent(routeChapterId) : null;
  const preservedQuery = useMemo(() => {
    const kept = new URLSearchParams();
    for (const keep of ['agent', 'hud']) {
      const v = searchParams.get(keep);
      if (v != null) kept.set(keep, v);
    }
    const qs = kept.toString();
    return qs ? `?${qs}` : '';
  }, [searchParams]);
  const rawTab = searchParams.get('tab') as KatanaNavKey | null;
  const tab: KatanaNavKey = rawTab && VALID_TABS.has(rawTab) ? rawTab : searchParams.get('q') ? 'directory' : 'home';
  const rawMode = searchParams.get('mode');
  const catalogMode: 'directory' | 'latest' | 'new' | 'genre' | 'search' =
    rawMode === 'latest' || rawMode === 'new' || rawMode === 'genre' || rawMode === 'search' || rawMode === 'directory'
      ? rawMode
      : searchParams.get('q')
        ? 'search'
        : tab === 'latest'
          ? 'latest'
          : tab === 'newManga'
            ? 'new'
            : searchParams.get('genre')
              ? 'genre'
              : 'directory';
  const genreSlug = searchParams.get('genre') ?? '';
  const genreTitle = searchParams.get('genreName') ?? genreSlug;
  const searchQuery = searchParams.get('q') ?? '';
  const searchBy: 'm_name' | 'author' | 'alt_theme' =
    searchParams.get('by') === 'author'
      ? 'author'
      : searchParams.get('by') === 'alt_theme'
        ? 'alt_theme'
        : 'm_name';
  const catPage = Math.max(1, Number.parseInt(searchParams.get('page') ?? '1', 10) || 1);
  const rawType = searchParams.get('type') as MangaType | null;
  const typeFilter: MangaType = rawType && VALID_TYPES.has(rawType) ? rawType : 'all';
  const typePage = Math.max(1, Number.parseInt(searchParams.get('tpage') ?? '1', 10) || 1);

  const includeGenres = useMemo(() => parseCsv(searchParams.get('inc')), [searchParams]);
  const excludeGenres = useMemo(() => parseCsv(searchParams.get('exc')), [searchParams]);
  const genreMode: 'and' | 'or' = searchParams.get('gm') === 'or' ? 'or' : 'and';
  const minChapters = searchParams.get('minCh') || '1';
  const orderBy = searchParams.get('order') || 'latest';
  const statusFilter: 'all' | 'ongoing' | 'completed' =
    searchParams.get('status') === 'ongoing' || searchParams.get('status') === 'completed'
      ? (searchParams.get('status') as 'ongoing' | 'completed')
      : 'all';
  const demographicFilter = searchParams.get('demo') || 'all';
  const languageFilter = searchParams.get('lang') || 'all';
  const authorFilter = searchParams.get('author') || '';

  const updateMangaUrl = useCallback(
    (patch: Record<string, string | null | undefined>, opts?: { replace?: boolean; clearAll?: boolean }) => {
      const next = opts?.clearAll ? new URLSearchParams() : new URLSearchParams(searchParams);
      // Preserve agent/hud query flags if present.
      for (const keep of ['agent', 'hud']) {
        const v = searchParams.get(keep);
        if (v != null && !next.has(keep)) next.set(keep, v);
      }
      for (const [k, v] of Object.entries(patch)) {
        if (v == null || v === '' || (k === 'page' && v === '1') || (k === 'tpage' && v === '1')) {
          next.delete(k);
        } else {
          next.set(k, v);
        }
      }
      const qs = next.toString();
      void navigate(qs ? `/manga?${qs}` : '/manga', { replace: opts?.replace ?? false });
    },
    [navigate, searchParams],
  );

  const openDetail = useCallback(
    (slug: string) => {
      if (!slug) return;
      void navigate(`/manga/series/${encodeURIComponent(slug)}${preservedQuery}`);
    },
    [navigate, preservedQuery],
  );

  const closeDetail = useCallback(() => {
    if (location.key !== 'default') void navigate(-1);
    else void navigate(`/manga${preservedQuery}`);
  }, [location.key, navigate, preservedQuery]);

  const [readerParams, setReaderParams] = useState<MangaReaderParams | null>(null);
  const [detailRetryTick, setDetailRetryTick] = useState(0);
  const [summaryOpen, setSummaryOpen] = useState(false);
  const [showPartnerReading, setShowPartnerReading] = useState(false);
  const [resumingSlug, setResumingSlug] = useState<string | null>(null);

  // Home data
  const [homeData, setHomeData] = useState<KatanaHomeData | null>(null);
  const [homeLoading, setHomeLoading] = useState(true);
  const [homeRefreshTick, setHomeRefreshTick] = useState(0);
  const [typeItems, setTypeItems] = useState<KatanaManga[]>([]);
  const [typeHasNext, setTypeHasNext] = useState(false);
  const [typeTotalPages, setTypeTotalPages] = useState<number | undefined>(undefined);
  const [typeTotalResults, setTypeTotalResults] = useState<number | undefined>(undefined);
  const [typeLoading, setTypeLoading] = useState(false);

  // Catalog state
  const [catItems, setCatItems] = useState<KatanaManga[]>([]);
  const [catHasNext, setCatHasNext] = useState(false);
  const [catTotalPages, setCatTotalPages] = useState<number | undefined>(undefined);
  const [catTotalResults, setCatTotalResults] = useState<number | undefined>(undefined);
  const [catLoading, setCatLoading] = useState(false);
  const [catError, setCatError] = useState<string | undefined>(undefined);
  const [catRefreshTick, setCatRefreshTick] = useState(0);
  const [catViewMode, setCatViewMode] = useState<'grid' | 'list'>('grid');
  const [filterOpen, setFilterOpen] = useState(false);
  const [authorDraft, setAuthorDraft] = useState(authorFilter);

  useEffect(() => {
    setAuthorDraft(authorFilter);
  }, [authorFilter]);

  // Keep author filter live-synced like every other control in the filter sheet.
  useEffect(() => {
    const trimmed = authorDraft.trim();
    if (trimmed === authorFilter.trim()) return;
    const id = window.setTimeout(() => {
      updateMangaUrl({ author: trimmed || null, page: '1' }, { replace: true });
    }, 280);
    return () => window.clearTimeout(id);
  }, [authorDraft, authorFilter, updateMangaUrl]);

  // Genres directory search
  const [genreFilterText, setGenreFilterText] = useState('');

  // Library filter/sort/display/bulk-select & custom categories state
  const [libraryBucket, setLibraryBucket] = useState<'all' | 'caught_up' | 'downloaded' | KatanaLibraryStatus>('all');
  const [libraryCategory, setLibraryCategory] = useState<string>('all');
  const [libraryQuery, setLibraryQuery] = useState('');
  const [libraryLetter, setLibraryLetter] = useState<string>('all');
  const [libraryRefreshing, setLibraryRefreshing] = useState(false);
  const [librarySort, setLibrarySort] = useState<'last_read' | 'unread' | 'title' | 'added'>('last_read');
  const [libraryViewMode, setLibraryViewMode] = useState<'list' | 'grid' | 'compact'>('grid');
  const [librarySelectMode, setLibrarySelectMode] = useState(false);
  const [selectedLibrarySlugs, setSelectedLibrarySlugs] = useState<Set<string>>(() => new Set());
  const [localCategories, setLocalCategories] = useState<string[]>(() => loadKatanaCustomCategories(currentUser ?? ''));
  const [categoryManagerOpen, setCategoryManagerOpen] = useState(false);
  const [newCategoryDraft, setNewCategoryDraft] = useState('');
  const [backupPanelOpen, setBackupPanelOpen] = useState(false);

  // Detail data & chapter controls
  const [detail, setDetail] = useState<KatanaManga | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [similarCatalog, setSimilarCatalog] = useState<KatanaManga[]>([]);
  const [chapterSortAsc, setChapterSortAsc] = useState(false);
  const [chapterGrouped, setChapterGrouped] = useState(false);
  const [chapterToolsOpen, setChapterToolsOpen] = useState(false);
  const [chapterLangFilter, setChapterLangFilter] = useState<string>('all');
  const [chapterGroupFilter, setChapterGroupFilter] = useState<string>('all');
  const [preferredScanlationGroup, setPreferredScanlationGroup] = useState<string>('');
  const [blockedScanlationGroups, setBlockedScanlationGroups] = useState<string[]>([]);
  const [waitForPreferredHours, setWaitForPreferredHours] = useState<number>(0);
  const [multiSourceStream, setMultiSourceStream] = useState<
    Record<
      'mangakatana' | 'mangadex' | 'comick' | 'bato',
      { status: 'loading' | 'ok' | 'empty' | 'error'; count: number; hasNext: boolean; error?: string }
    >
  >({
    mangakatana: { status: 'empty', count: 0, hasNext: false },
    mangadex: { status: 'empty', count: 0, hasNext: false },
    comick: { status: 'empty', count: 0, hasNext: false },
    bato: { status: 'empty', count: 0, hasNext: false },
  });

  useEffect(() => {
    if (!detail?.slug) return;
    saveSeriesChapterFilter(
      detail.slug,
      chapterLangFilter !== 'all' ||
        chapterGroupFilter !== 'all' ||
        preferredScanlationGroup !== '' ||
        blockedScanlationGroups.length > 0 ||
        waitForPreferredHours > 0
        ? {
            lang: chapterLangFilter !== 'all' ? chapterLangFilter : undefined,
            group: chapterGroupFilter !== 'all' ? chapterGroupFilter : undefined,
            preferredGroup: preferredScanlationGroup || undefined,
            blockedGroups: blockedScanlationGroups.length > 0 ? blockedScanlationGroups : undefined,
            waitForPreferredHours: waitForPreferredHours > 0 ? waitForPreferredHours : undefined,
          }
        : null,
    );
  }, [detail?.slug, chapterLangFilter, chapterGroupFilter, preferredScanlationGroup, blockedScanlationGroups, waitForPreferredHours]);
  const [chapterSearch, setChapterSearch] = useState('');
  const [chapterWindow, setChapterWindow] = useState(40);
  const [catalogSource, setCatalogSource] = useState<KatanaCatalogSource>('mangakatana');
  const [libraryToolsOpen, setLibraryToolsOpen] = useState(false);
  const [downloadingChapterIds, setDownloadingChapterIds] = useState<Set<string>>(() => new Set());
  const [batchProgress, setBatchProgress] = useState<{ done: number; total: number; currentTitle?: string } | null>(null);
  const [downloadWifiOnly, setDownloadWifiOnly] = useState<boolean>(() => loadWifiOnlyDownloads());
  const downloadCancelRef = useRef(false);
  const [selectMode, setSelectMode] = useState(false);
  const [selectedChapterIds, setSelectedChapterIds] = useState<Set<string>>(() => new Set());
  const [chapterActionMenuId, setChapterActionMenuId] = useState<string | null>(null);
  const [detailOverflowOpen, setDetailOverflowOpen] = useState(false);
  const [statusMenuOpen, setStatusMenuOpen] = useState(false);
  const [trackerOpen, setTrackerOpen] = useState(false);
  const [trackerSyncing, setTrackerSyncing] = useState(false);
  const [trackerAnilistDraft, setTrackerAnilistDraft] = useState('');
  const [trackerKitsuDraft, setTrackerKitsuDraft] = useState('');
  const [trackerMalDraft, setTrackerMalDraft] = useState('');
  const [trackerNoteDraft, setTrackerNoteDraft] = useState('');
  const [themeMode, setThemeMode] = useState<KatanaThemeMode>(() => loadKatanaThemeMode());
  const [hiddenCategories, setHiddenCategories] = useState<string[]>(() => loadKatanaHiddenCategories(currentUser ?? ''));
  const [showHiddenCategories, setShowHiddenCategories] = useState(false);
  const [autoDownloadNext, setAutoDownloadNext] = useState<number>(() => loadKatanaAutoDownloadCount());
  const [autoDownloadCategories, setAutoDownloadCategories] = useState<string[]>(
    () => loadKatanaUserPrefs(currentUser ?? '').autoDownloadCategories ?? [],
  );
  const [libraryStatsOpen, setLibraryStatsOpen] = useState(false);
  const [alertPrefs, setAlertPrefs] = useState<KatanaAlertPrefs>(() => loadKatanaAlertPrefs(currentUser ?? ''));
  const [previewPages, setPreviewPages] = useState<{ slug: string; chapterId: string; chapterTitle: string; urls: string[] } | null>(null);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [historyEntries, setHistoryEntries] = useState<KatanaHistoryEntry[]>(() => loadKatanaHistory(currentUser ?? ''));
  const [historyPaused, setHistoryPaused] = useState<boolean>(() => isKatanaHistoryPaused(currentUser ?? ''));
  const [historySubView, setHistorySubView] = useState<'history' | 'updates'>('history');
  const [downloadQueue, setDownloadQueue] = useState<Array<{ manga: KatanaManga; chapter: KatanaChapter }>>([]);
  const downloadQueueRef = useRef<Array<{ manga: KatanaManga; chapter: KatanaChapter }>>([]);
  const [failedDownloads, setFailedDownloads] = useState<PersistedQueueEntry[]>([]);
  const [filterPresets, setFilterPresets] = useState<SavedFilterPreset[]>(() => loadSavedFilterPresets());
  const [presetNameDraft, setPresetNameDraft] = useState('');
  const filterSheetRef = useRef<HTMLDivElement>(null);
  const libraryToolsSheetRef = useRef<HTMLDivElement>(null);
  const detailActionsRef = useRef<HTMLDivElement>(null);
  const shelfChipsRef = useRef<HTMLDivElement>(null);

  // Sync document root background to active Manga Celestia theme to avoid couple-plum overscroll flashes.
  useEffect(() => {
    const bg = KATANA_THEME_VARS[themeMode]['--katana-bg'];
    const html = document.documentElement;
    const body = document.body;
    const root = document.getElementById('root');
    const prevHtmlBg = html.style.backgroundColor;
    const prevBodyBg = body.style.backgroundColor;
    const prevRootBg = root?.style.backgroundColor ?? '';
    html.style.backgroundColor = bg;
    body.style.backgroundColor = bg;
    if (root) root.style.backgroundColor = bg;
    return () => {
      html.style.backgroundColor = prevHtmlBg;
      body.style.backgroundColor = prevBodyBg;
      if (root) root.style.backgroundColor = prevRootBg;
    };
  }, [themeMode]);

  const userName = currentUser ?? '';
  const syncedCategories = useSource(() => watchKatanaCustomCategories(userName), [userName], localCategories);
  const syncedRecentSearches = useSource(() => watchKatanaRecentSearches(userName), [userName], []);
  const syncedHistory = useSource<KatanaHistoryEntry[] | null>(() => watchKatanaHistory(userName), [userName], null);
  const syncedUserPrefs = useSource(() => watchKatanaUserPrefs(userName), [userName], null);
  useEffect(() => {
    if (syncedHistory !== null) setHistoryEntries(syncedHistory);
  }, [syncedHistory]);
  useEffect(() => {
    if (!syncedUserPrefs) return;
    setAlertPrefs(syncedUserPrefs.alertPrefs);
    setDownloadWifiOnly(syncedUserPrefs.wifiOnlyDownloads);
    setAutoDownloadNext(syncedUserPrefs.autoDownloadNext);
    setAutoDownloadCategories(syncedUserPrefs.autoDownloadCategories ?? []);
    if (syncedUserPrefs.themeMode) {
      setThemeMode(syncedUserPrefs.themeMode);
      saveKatanaThemeMode(syncedUserPrefs.themeMode);
    }
  }, [syncedUserPrefs]);
  useEffect(() => {
    setAlertPrefs(loadKatanaAlertPrefs(userName));
  }, [userName]);
  useEffect(() => {
    setPreviewPages(null);
    setPreviewLoading(false);
  }, [detail?.slug]);
  useEffect(() => {
    setLocalCategories(loadKatanaCustomCategories(userName));
    setHiddenCategories(loadKatanaHiddenCategories(userName));
    setHistoryEntries(loadKatanaHistory(userName));
  }, [userName]);

  // Filter sheet accessibility: Escape-to-close + Tab focus trap while open on phone/tablet.
  useEffect(() => {
    if (!filterOpen) return;
    const prevFocused = document.activeElement as HTMLElement | null;
    const sheet = filterSheetRef.current;
    const focusables = () =>
      Array.from(
        sheet?.querySelectorAll<HTMLElement>(
          'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
        ) ?? [],
      );
    const initial = focusables()[0];
    initial?.focus();
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        setFilterOpen(false);
        return;
      }
      if (e.key !== 'Tab') return;
      const nodes = focusables();
      if (nodes.length === 0) return;
      const first = nodes[0];
      const last = nodes[nodes.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => {
      window.removeEventListener('keydown', onKeyDown);
      prevFocused?.focus?.();
    };
  }, [filterOpen]);

  // Library Tools sheet accessibility: Escape-to-close + Tab focus trap + focus restoration.
  useEffect(() => {
    if (!libraryToolsOpen) return;
    const prevFocused = document.activeElement as HTMLElement | null;
    const sheet = libraryToolsSheetRef.current;
    const focusables = () =>
      Array.from(
        sheet?.querySelectorAll<HTMLElement>(
          'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
        ) ?? [],
      );
    focusables()[0]?.focus();
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        setLibraryToolsOpen(false);
        return;
      }
      if (e.key !== 'Tab') return;
      const nodes = focusables();
      if (nodes.length === 0) return;
      const first = nodes[0];
      const last = nodes[nodes.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => {
      window.removeEventListener('keydown', onKeyDown);
      prevFocused?.focus?.();
    };
  }, [libraryToolsOpen]);

  useEffect(() => {
    if (!statusMenuOpen && !detailOverflowOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setStatusMenuOpen(false);
        setDetailOverflowOpen(false);
      }
    };
    const onPointerDown = (e: PointerEvent) => {
      if (detailActionsRef.current && !detailActionsRef.current.contains(e.target as Node)) {
        setStatusMenuOpen(false);
        setDetailOverflowOpen(false);
      }
    };
    window.addEventListener('keydown', onKey);
    window.addEventListener('pointerdown', onPointerDown);
    return () => {
      window.removeEventListener('keydown', onKey);
      window.removeEventListener('pointerdown', onPointerDown);
    };
  }, [statusMenuOpen, detailOverflowOpen]);

  const themeLabel = (mode: KatanaThemeMode) =>
    mode === 'oled'
      ? 'OLED Black'
      : mode === 'dark'
        ? 'Dark (Obsidian)'
        : mode === 'light'
          ? 'Light (Daylight)'
          : 'Sepia (Warm Paper)';

  const selectThemeMode = (next: KatanaThemeMode) => {
    setThemeMode(next);
    saveKatanaThemeMode(next);
    if (userName) saveKatanaUserPrefs(userName, { themeMode: next });
    showSnackBar(`Theme: ${themeLabel(next)}`);
  };

  const cycleThemeMode = () => {
    setThemeMode((prev) => {
      const next: KatanaThemeMode =
        prev === 'dark' ? 'oled' : prev === 'oled' ? 'light' : prev === 'light' ? 'sepia' : 'dark';
      saveKatanaThemeMode(next);
      if (userName) saveKatanaUserPrefs(userName, { themeMode: next });
      showSnackBar(`Theme: ${themeLabel(next)}`);
      return next;
    });
  };

  const toggleHiddenCategory = (cat: string) => {
    setHiddenCategories((prev) => {
      const next = prev.includes(cat) ? prev.filter((c) => c !== cat) : [...prev, cat];
      saveKatanaHiddenCategories(userName, next);
      return next;
    });
  };

  const updateAutoDownloadNext = (count: number) => {
    setAutoDownloadNext(count);
    saveKatanaAutoDownloadCount(count);
    if (userName) saveKatanaUserPrefs(userName, { autoDownloadNext: count });
    showSnackBar(count === 0 ? 'Auto-download turned off' : `Auto-download next ${count} unread chapters enabled`);
  };

  const toggleAutoDownloadCategory = (category: string) => {
    setAutoDownloadCategories((prev) => {
      const next = prev.includes(category) ? prev.filter((c) => c !== category) : [...prev, category];
      if (userName) saveKatanaUserPrefs(userName, { autoDownloadCategories: next });
      return next;
    });
  };

  const [trackerTokensOpen, setTrackerTokensOpen] = useState(false);
  const [trackerTokens, setTrackerTokens] = useState(() => loadKatanaTrackerTokens(userName));
  const [katanaSourceItems, setKatanaSourceItems] = useState<KatanaManga[]>([]);
  const [mangadexSourceItems, setMangadexSourceItems] = useState<KatanaManga[]>([]);
  const [comickSourceItems, setComickSourceItems] = useState<KatanaManga[]>([]);
  const [batoSourceItems, setBatoSourceItems] = useState<KatanaManga[]>([]);
  const [reviewsExpanded, setReviewsExpanded] = useState(false);
  const [migrationOpen, setMigrationOpen] = useState(false);
  const [migrationCandidates, setMigrationCandidates] = useState<KatanaManga[]>([]);
  const [migrationLoading, setMigrationLoading] = useState(false);

  useEffect(() => {
    setTrackerTokens(loadKatanaTrackerTokens(userName));
  }, [userName]);

  const syncSeriesWithMal = async (manga: KatanaManga, explicitMalId?: string) => {
    if (!userName || trackerSyncing) return;
    setTrackerSyncing(true);
    try {
      const snap = await lookupMalManga(manga.title, explicitMalId);
      if (!snap) {
        showSnackBar('No MyAnimeList match found — enter an ID manually or retry');
        return;
      }
      setTrackerMalDraft(snap.malId);
      await saveKatanaTrackerData(manga, userName, {
        malId: snap.malId,
        malScore: snap.score ?? null,
        malRank: snap.rank ?? null,
        malTotalChapters: snap.totalChapters ?? null,
        malStatus: snap.status ?? null,
        lastSyncedAt: new Date(),
      });
      const pushed = await pushKatanaTrackerProgress(manga, userName, { malId: snap.malId });
      showSnackBar(
        `Synced to MAL #${snap.malId}${snap.score ? ` (★ ${snap.score})` : ''}${pushed ? ` · Ch. ${pushed.chapterProgress}` : ''}`,
      );
    } finally {
      setTrackerSyncing(false);
    }
  };

  const syncSeriesWithAniList = async (manga: KatanaManga, explicitId?: string) => {
    if (!userName || trackerSyncing) return;
    setTrackerSyncing(true);
    try {
      const snap = await lookupAniListManga(manga.title, explicitId);
      if (!snap) {
        showSnackBar('No AniList match found — enter an ID manually or retry');
        return;
      }
      setTrackerAnilistDraft(snap.anilistId);
      await saveKatanaTrackerData(manga, userName, {
        anilistId: snap.anilistId,
        anilistScore: snap.score ?? null,
        lastSyncedAt: new Date(),
      });
      const pushed = await pushKatanaTrackerProgress(manga, userName, { anilistId: snap.anilistId });
      showSnackBar(
        `Synced to AniList #${snap.anilistId}${snap.score ? ` (${snap.score}%)` : ''}${pushed ? ` · Ch. ${pushed.chapterProgress}` : ''}`,
      );
    } finally {
      setTrackerSyncing(false);
    }
  };

  const syncSeriesWithKitsu = async (manga: KatanaManga, explicitId?: string) => {
    if (!userName || trackerSyncing) return;
    setTrackerSyncing(true);
    try {
      const snap = await lookupKitsuManga(manga.title, explicitId);
      if (!snap) {
        showSnackBar('No Kitsu match found — enter an ID manually or retry');
        return;
      }
      setTrackerKitsuDraft(snap.kitsuId);
      await saveKatanaTrackerData(manga, userName, {
        kitsuId: snap.kitsuId,
        kitsuScore: snap.score ?? null,
        lastSyncedAt: new Date(),
      });
      const pushed = await pushKatanaTrackerProgress(manga, userName, { kitsuId: snap.kitsuId });
      showSnackBar(
        `Synced to Kitsu #${snap.kitsuId}${snap.score ? ` (${snap.score}%)` : ''}${pushed ? ` · Ch. ${pushed.chapterProgress}` : ''}`,
      );
    } finally {
      setTrackerSyncing(false);
    }
  };

  const pushAllLinkedTrackers = async (manga: KatanaManga) => {
    if (!userName || trackerSyncing) return;
    setTrackerSyncing(true);
    try {
      const pushed = await pushKatanaTrackerProgress(manga, userName);
      if (!pushed) {
        showSnackBar('Link an AniList, MAL, Kitsu, or other tracker ID first to push progress');
        return;
      }
      showSnackBar(
        `Pushed Ch. ${pushed.chapterProgress} (${pushed.status}${pushed.score ? ` · ★${pushed.score}` : ''}) to ${pushed.pushedProviders.join(', ')}`,
      );
    } finally {
      setTrackerSyncing(false);
    }
  };

  const handleAutoMatchAllTrackers = async (manga: KatanaManga) => {
    if (!userName || trackerSyncing) return;
    setTrackerSyncing(true);
    try {
      const res = await autoMatchAllTrackers(manga, userName);
      if (res.patch.anilistId) setTrackerAnilistDraft(res.patch.anilistId);
      if (res.patch.malId) setTrackerMalDraft(res.patch.malId);
      if (res.patch.kitsuId) setTrackerKitsuDraft(res.patch.kitsuId);
      showSnackBar(`Auto-matched & synced ${res.matchedProviders.length} trackers (${res.matchedProviders.slice(0, 3).join(', ')}…)`);
    } finally {
      setTrackerSyncing(false);
    }
  };

  const openMigrationPicker = async (manga: KatanaManga) => {
    if (migrationOpen) {
      setMigrationOpen(false);
      return;
    }
    setMigrationOpen(true);
    setMigrationLoading(true);
    try {
      const cleanTitle = manga.title.replace(/\s*\((?:MangaDex|ComicK|Bato)[^)]*\)\s*/gi, '').trim();
      const results = await Promise.allSettled(
        MANGA_SOURCE_REGISTRY.map((src) => src.search({ query: cleanTitle, page: 1 })),
      );
      const candidates: KatanaManga[] = [];
      results.forEach((r, idx) => {
        if (r.status === 'fulfilled') {
          const hit = r.value.items[0];
          if (hit && hit.slug !== manga.slug) {
            candidates.push({ ...hit, source: hit.source ?? MANGA_SOURCE_REGISTRY[idx].id });
          }
        }
      });
      setMigrationCandidates(candidates);
    } finally {
      setMigrationLoading(false);
    }
  };

  const handleMigrateToCandidate = async (fromManga: KatanaManga, targetManga: KatanaManga) => {
    if (!userName) return;
    const res = await migrateKatanaSeriesSource(fromManga.slug, targetManga, userName);
    setMigrationOpen(false);
    showSnackBar(
      `Migrated "${fromManga.title}" to ${targetManga.source?.toUpperCase() || 'new source'} (${res.migratedReadCount} read chapters & tracker links preserved)`,
    );
    openDetail(res.targetSlug);
  };

  const toggleSeriesAlerts = async (manga: KatanaManga, currentlyEnabled: boolean) => {
    if (!userName) return;
    const next = !currentlyEnabled;
    if (next && typeof Notification !== 'undefined' && Notification.permission === 'default') {
      try {
        await Notification.requestPermission();
      } catch {
        // ignore browser permission errors
      }
    }
    await saveKatanaTrackerData(manga, userName, { notifyOnUpdate: next });
    if (next) {
      const guidance = getPushDeliveryGuidance();
      let hintSeen = false;
      try {
        hintSeen = localStorage.getItem(IOS_PWA_PUSH_HINT_KEY) === '1';
      } catch {
        hintSeen = false;
      }
      if (guidance.requiresHomeScreenInstall && !hintSeen) {
        try {
          localStorage.setItem(IOS_PWA_PUSH_HINT_KEY, '1');
        } catch {
          // ignore
        }
        await showDialog<null>((close) => (
          <AlertDialog
            background={KatanaColors.surface}
            title={<div style={KatanaType.title}>Install to Home Screen for iPhone Alerts</div>}
            content={
              <div style={KatanaType.small}>
                {guidance.steps}
              </div>
            }
            actions={[
              <TextButton key="ok" color={KatanaColors.accent} onPressed={() => close(null)}>
                Got it
              </TextButton>,
            ]}
          />
        ));
      }
    }
    showSnackBar(
      next
        ? getPushDeliveryGuidance().requiresHomeScreenInstall
          ? `Chapter alerts enabled for ${manga.title} · Add Everglow to Home Screen on iOS for push notifications`
          : `Chapter alerts enabled for ${manga.title}`
        : `Chapter alerts muted for ${manga.title}`,
    );
  };

  const toggleDownloadWifiOnly = () => {
    setDownloadWifiOnly((prev) => {
      const next = !prev;
      try {
        localStorage.setItem(WIFI_ONLY_DL_KEY, next ? '1' : '0');
      } catch {
        // ignore
      }
      if (userName) saveKatanaUserPrefs(userName, { wifiOnlyDownloads: next });
      showSnackBar(next ? 'Downloads restricted to Wi-Fi' : 'Downloads allowed on any connection');
      return next;
    });
  };

  const addCustomCategory = (rawName: string) => {
    const clean = rawName.trim();
    if (!clean) return;
    setLocalCategories((prev) => {
      const merged = Array.from(new Set([...prev, ...syncedCategories]));
      if (merged.some((c) => c.toLowerCase() === clean.toLowerCase())) return merged;
      const next = [...merged, clean];
      saveKatanaCustomCategories(userName, next);
      return next;
    });
    setNewCategoryDraft('');
  };

  const deleteCustomCategory = (name: string) => {
    setLocalCategories((prev) => {
      const merged = Array.from(new Set([...prev, ...syncedCategories]));
      const next = merged.filter((c) => c !== name);
      saveKatanaCustomCategories(userName, next);
      return next;
    });
    if (libraryCategory === name) setLibraryCategory('all');
  };
  const bookmarks = useSource(() => watchKatanaBookmarks(userName), [userName], []);

  // Check alert-enabled series against latest home catalog updates and keep bookmark latestChapterNum fresh.
  useEffect(() => {
    if (!userName || !homeData || bookmarks.length === 0) return;
    const catalog = [...homeData.latest, ...homeData.hot, ...homeData.hotUpdates];
    checkKatanaChapterAlerts(userName, bookmarks, catalog);
    const updates = catalog
      .filter((m) => m.latestChapter)
      .map((m) => ({
        slug: m.slug,
        latestChapterTitle: m.latestChapter!.title || `Chapter ${m.latestChapter!.num}`,
        latestChapterNum: extractChapterNumber(m.latestChapter!.title || m.latestChapter!.num || m.latestChapter!.id),
        latestChapterId: m.latestChapter!.id,
      }));
    if (updates.length > 0) void syncKatanaBookmarkLatest(userName, bookmarks, updates);
  }, [userName, homeData, bookmarks]);

  useEffect(() => {
    if (!userName || !detail || detail.chapters.length === 0 || bookmarks.length === 0) return;
    const newest = detail.chapters[0];
    if (!newest) return;
    void syncKatanaBookmarkLatest(userName, bookmarks, [
      {
        slug: detail.slug,
        latestChapterTitle: newest.title || `Chapter ${newest.num}`,
        latestChapterNum: extractChapterNumber(newest.title || newest.num || newest.id),
        latestChapterId: newest.id,
      },
    ]);
  }, [userName, detail, bookmarks]);

  const readChapterIdsBySlug = useMemo(() => {
    const map: Record<string, Set<string>> = {};
    for (const bm of bookmarks) {
      map[bm.slug] = new Set<string>(bm.readChapterIds);
    }
    return map;
  }, [bookmarks]);
  const partnerBookmarks = useSource(
    () => (isCoupleUser && partnerUsername ? watchKatanaBookmarks(partnerUsername) : null),
    [isCoupleUser, partnerUsername],
    [],
  );

  // Per-series downloaded chapter counts for Mihon-style cover badges
  const downloadedCounts = useMemo(() => {
    const counts: Record<string, number> = {};
    for (const item of offline.mangaItems) {
      counts[item.mediaId] = (counts[item.mediaId] ?? 0) + 1;
    }
    return counts;
  }, [offline.mangaItems]);

  useEffect(() => {
    let alive = true;
    setHomeLoading(true);
    void fetchKatanaHome().then((d) => {
      if (!alive) return;
      setHomeData(d);
      setHomeLoading(false);
    });
    return () => {
      alive = false;
    };
  }, [homeRefreshTick]);

  useEffect(() => {
    if (typeFilter === 'all') {
      setTypeLoading(false);
      return;
    }
    let alive = true;
    const cached = getCachedKatanaByType(typeFilter, typePage);
    if (cached) {
      setTypeItems(cached.items);
      setTypeHasNext(cached.hasNext);
      setTypeTotalPages(cached.totalPages);
      setTypeTotalResults(cached.totalResults);
      setTypeLoading(false);
      return;
    }
    // Seed immediately from loaded home catalog on page 1 so switching tabs never freezes on the old tab's items.
    const seeded = typePage === 1 ? filterHomeCatalogByType(homeData, typeFilter) : [];
    setTypeItems(seeded);
    setTypeHasNext(false);
    setTypeTotalPages(undefined);
    setTypeTotalResults(undefined);
    setTypeLoading(true);
    void fetchKatanaByType(typeFilter, typePage).then((res) => {
      if (!alive) return;
      setTypeItems(res.items.length > 0 ? res.items : seeded);
      setTypeHasNext(res.hasNext);
      setTypeTotalPages(res.totalPages);
      setTypeTotalResults(res.totalResults);
      setTypeLoading(false);
    });
    return () => {
      alive = false;
    };
  }, [typeFilter, typePage, homeData]);

  useEffect(() => {
    if (detailSlug) return;
    const isCatalogTab =
      ['latest', 'directory', 'newManga'].includes(tab) || (tab === 'genres' && genreSlug !== '') || catalogMode === 'search';
    if (!isCatalogTab) return;
    let alive = true;
    setCatLoading(true);
    setCatError(undefined);
    if (catalogSource === 'all' && (catalogMode === 'search' || catalogMode === 'directory')) {
      setMultiSourceStream({
        mangakatana: { status: 'loading', count: 0, hasNext: false },
        mangadex: { status: 'loading', count: 0, hasNext: false },
        comick: { status: 'loading', count: 0, hasNext: false },
        bato: { status: 'loading', count: 0, hasNext: false },
      });
      setKatanaSourceItems([]);
      setMangadexSourceItems([]);
      setComickSourceItems([]);
      setBatoSourceItems([]);

      const buffers: Record<'mangakatana' | 'mangadex' | 'comick' | 'bato', KatanaManga[]> = {
        mangakatana: [],
        mangadex: [],
        comick: [],
        bato: [],
      };
      const hasNextBySrc: Record<'mangakatana' | 'mangadex' | 'comick' | 'bato', boolean> = {
        mangakatana: false,
        mangadex: false,
        comick: false,
        bato: false,
      };
      const errorsBySrc: Partial<Record<'mangakatana' | 'mangadex' | 'comick' | 'bato', string>> = {};
      let settledCount = 0;

      const handleSourceResolved = (
        srcKey: 'mangakatana' | 'mangadex' | 'comick' | 'bato',
        res: { items: KatanaManga[]; hasNext?: boolean; error?: string } | null,
        errMsg?: string,
      ) => {
        if (!alive) return;
        settledCount += 1;
        const tagged = (res?.items ?? []).map((m) => ({
          ...m,
          source: m.source ?? srcKey,
        }));
        buffers[srcKey] = tagged;
        hasNextBySrc[srcKey] = Boolean(res?.hasNext);
        const err = errMsg || res?.error;
        if (err) errorsBySrc[srcKey] = err;

        if (srcKey === 'mangakatana') setKatanaSourceItems(tagged);
        else if (srcKey === 'mangadex') setMangadexSourceItems(tagged);
        else if (srcKey === 'comick') setComickSourceItems(tagged);
        else setBatoSourceItems(tagged);

        setMultiSourceStream((prev) => ({
          ...prev,
          [srcKey]: {
            status: tagged.length > 0 ? 'ok' : err ? 'error' : 'empty',
            count: tagged.length,
            hasNext: Boolean(res?.hasNext),
            error: err,
          },
        }));

        const merged = rankAndMergeMultiSourceCatalog({
          query: searchQuery,
          orderBy,
          katanaItems: buffers.mangakatana,
          mangadexItems: buffers.mangadex,
          comickItems: buffers.comick,
          batoItems: buffers.bato,
          bookmarks: bookmarksRef.current,
        });
        setCatItems(merged);
        setCatHasNext(
          Boolean(
            hasNextBySrc.mangakatana || hasNextBySrc.mangadex || hasNextBySrc.comick || hasNextBySrc.bato,
          ),
        );
        // Honest pagination: never fabricate a single-source max page count across merged catalogs
        setCatTotalPages(undefined);
        setCatTotalResults(merged.length);
        if (merged.length > 0 || settledCount >= 4) {
          setCatLoading(false);
        }
        if (settledCount >= 4 && merged.length === 0) {
          setCatError(
            errorsBySrc.mangakatana || errorsBySrc.mangadex || errorsBySrc.comick || errorsBySrc.bato,
          );
        } else if (merged.length > 0) {
          setCatError(undefined);
        }
      };

      const sharedFilterOpts = {
        query: searchQuery,
        page: catPage,
        status: statusFilter,
        demographic: demographicFilter,
        orderBy,
        include: includeGenres,
        exclude: excludeGenres,
        genreMode,
        chapters: minChapters,
        author: authorFilter,
        language: languageFilter,
      };

      fetchKatanaCatalog({
        mode: catalogMode,
        key: genreSlug,
        page: catPage,
        query: searchQuery,
        searchBy,
        include: includeGenres,
        exclude: excludeGenres,
        genreMode,
        chapters: minChapters,
        orderBy,
        status: statusFilter,
        demographic: demographicFilter,
        author: authorFilter,
      })
        .then((res) => handleSourceResolved('mangakatana', res))
        .catch(() => handleSourceResolved('mangakatana', null, 'MangaKatana timed out'));

      searchMangaDexCatalog(sharedFilterOpts)
        .then((res) => handleSourceResolved('mangadex', res))
        .catch(() => handleSourceResolved('mangadex', null, 'MangaDex timed out'));

      searchComickCatalog(sharedFilterOpts)
        .then((res) => handleSourceResolved('comick', res))
        .catch(() => handleSourceResolved('comick', null, 'ComicK timed out'));

      searchBatoCatalog(sharedFilterOpts)
        .then((res) => handleSourceResolved('bato', res))
        .catch(() => handleSourceResolved('bato', null, 'Bato.to timed out'));

      return () => {
        alive = false;
      };
    }
    if (catalogSource === 'bato' && (catalogMode === 'search' || catalogMode === 'directory')) {
      void searchBatoCatalog({
        query: searchQuery,
        page: catPage,
        status: statusFilter,
        demographic: demographicFilter,
        orderBy,
        include: includeGenres,
        exclude: excludeGenres,
        genreMode,
        chapters: minChapters,
        author: authorFilter,
        language: languageFilter,
      }).then((res) => {
        if (!alive) return;
        setCatItems(res.items);
        setCatHasNext(res.hasNext);
        setCatTotalPages(res.totalPages);
        setCatTotalResults(res.totalResults);
        setCatError(res.error);
        setCatLoading(false);
      });
      return () => {
        alive = false;
      };
    }
    if (catalogSource === 'comick' && (catalogMode === 'search' || catalogMode === 'directory')) {
      void searchComickCatalog({
        query: searchQuery,
        page: catPage,
        status: statusFilter,
        demographic: demographicFilter,
        orderBy,
        include: includeGenres,
        exclude: excludeGenres,
        genreMode,
        chapters: minChapters,
        author: authorFilter,
        language: languageFilter,
      }).then((res) => {
        if (!alive) return;
        setCatItems(res.items);
        setCatHasNext(res.hasNext);
        setCatTotalPages(res.totalPages);
        setCatTotalResults(res.totalResults);
        setCatError(res.error);
        setCatLoading(false);
      });
      return () => {
        alive = false;
      };
    }
    if (catalogSource === 'mangadex' && (catalogMode === 'search' || catalogMode === 'directory')) {
      void searchMangaDexCatalog({
        query: searchQuery,
        page: catPage,
        status: statusFilter,
        demographic: demographicFilter,
        orderBy,
        include: includeGenres,
        exclude: excludeGenres,
        genreMode,
        chapters: minChapters,
        author: authorFilter,
        language: languageFilter,
      }).then((res) => {
        if (!alive) return;
        setCatItems(res.items);
        setCatHasNext(res.hasNext);
        setCatTotalPages(res.totalPages);
        setCatTotalResults(res.totalResults);
        setCatError(res.error);
        setCatLoading(false);
      });
      return () => {
        alive = false;
      };
    }
    void fetchKatanaCatalog({
      mode: catalogMode,
      key: genreSlug,
      page: catPage,
      query: searchQuery,
      searchBy,
      include: includeGenres,
      exclude: excludeGenres,
      genreMode,
      chapters: minChapters,
      orderBy,
      status: statusFilter,
      demographic: demographicFilter,
      author: authorFilter,
    }).then((res) => {
      if (!alive) return;
      setCatItems(res.items);
      setCatHasNext(res.hasNext);
      setCatTotalPages(res.totalPages);
      setCatTotalResults(res.totalResults);
      setCatError(res.error);
      setCatLoading(false);
    });
    return () => {
      alive = false;
    };
  }, [
    detailSlug,
    tab,
    catalogMode,
    catalogSource,
    genreSlug,
    catPage,
    searchQuery,
    searchBy,
    includeGenres,
    excludeGenres,
    genreMode,
    minChapters,
    orderBy,
    statusFilter,
    demographicFilter,
    languageFilter,
    authorFilter,
    catRefreshTick,
  ]);

  useEffect(() => {
    if (!detailSlug) return;
    let alive = true;
    setDetailLoading(true);
    setChapterSearch('');
    const savedFilter = loadSeriesChapterFilter(detailSlug);
    setChapterLangFilter(savedFilter?.lang ?? 'all');
    setChapterGroupFilter(savedFilter?.group ?? 'all');
    setPreferredScanlationGroup(savedFilter?.preferredGroup ?? '');
    setBlockedScanlationGroups(savedFilter?.blockedGroups ?? []);
    setWaitForPreferredHours(savedFilter?.waitForPreferredHours ?? 0);
    setChapterWindow(40);
    setSelectMode(false);
    setSelectedChapterIds(new Set());
    setDetailOverflowOpen(false);
    void fetchKatanaDetail(detailSlug)
      .catch(() => null)
      .then((d) => {
        if (!alive) return;
        setDetail(d);
        setDetailLoading(false);
        const latestId = d?.latestChapter?.id || d?.chapters?.[0]?.id;
        if (userName && d?.slug && latestId) {
          markKatanaAlertSeen(userName, d.slug, latestId);
        }
      });
    return () => {
      alive = false;
    };
  }, [detailSlug, detailRetryTick, userName]);

  const desktop = width >= KATANA_BREAKPOINTS.desktop;
  const tablet = width >= KATANA_BREAKPOINTS.tablet;
  const compactCard = width < KATANA_BREAKPOINTS.tablet;
  const isHome = !detailSlug && tab === 'home' && homeData != null;
  const homeScrollRef = useRef<HTMLDivElement>(null);
  useRememberedScroll('manga:home', homeScrollRef, isHome);

  const handleNav = (next: KatanaNavKey) => {
    setFilterOpen(false);
    const mode = next === 'latest' ? 'latest' : next === 'newManga' ? 'new' : next === 'directory' ? 'directory' : null;
    updateMangaUrl({ tab: next === 'home' ? null : next, mode }, { clearAll: true });
  };

  const handleSelectGenre = (g: KatanaGenre) => {
    setFilterOpen(false);
    updateMangaUrl({ tab: 'genres', mode: 'genre', genre: g.slug, genreName: g.name }, { clearAll: true });
  };

  const activeFilterCount =
    includeGenres.length +
    excludeGenres.length +
    (minChapters !== '1' ? 1 : 0) +
    (orderBy !== 'latest' ? 1 : 0) +
    (statusFilter !== 'all' ? 1 : 0) +
    (demographicFilter !== 'all' ? 1 : 0) +
    (languageFilter !== 'all' ? 1 : 0) +
    (authorFilter.trim() ? 1 : 0);

  const clearCatalogFilters = () => {
    updateMangaUrl(
      { inc: null, exc: null, gm: null, minCh: null, order: null, status: null, demo: null, lang: null, author: null, page: '1' },
      { replace: true },
    );
  };

  const toggleIncludeGenre = (slug: string) => {
    const nextExc = excludeGenres.filter((s) => s !== slug);
    const nextInc = includeGenres.includes(slug)
      ? includeGenres.filter((s) => s !== slug)
      : [...includeGenres, slug];
    updateMangaUrl({ inc: nextInc.join(','), exc: nextExc.join(','), page: '1' }, { replace: true });
  };

  const toggleExcludeGenre = (slug: string) => {
    const nextInc = includeGenres.filter((s) => s !== slug);
    const nextExc = excludeGenres.includes(slug)
      ? excludeGenres.filter((s) => s !== slug)
      : [...excludeGenres, slug];
    updateMangaUrl({ inc: nextInc.join(','), exc: nextExc.join(','), page: '1' }, { replace: true });
  };

  const toggleSelectLibrarySlug = (slug: string) => {
    setSelectedLibrarySlugs((prev) => {
      const next = new Set(prev);
      if (next.has(slug)) next.delete(slug);
      else next.add(slug);
      return next;
    });
  };

  const bulkMoveLibraryStatus = async (status: KatanaLibraryStatus) => {
    if (!userName || selectedLibrarySlugs.size === 0) return;
    const targets = savedBookmarks.filter((b) => selectedLibrarySlugs.has(b.slug));
    await Promise.all(
      targets.map((bm) =>
        setKatanaLibraryStatus(
          { slug: bm.slug, title: bm.title, coverUrl: bm.coverUrl, status: bm.status || 'ongoing' },
          userName,
          status,
        ),
      ),
    );
    showSnackBar(`Moved ${targets.length} ${targets.length === 1 ? 'title' : 'titles'} to ${STATUS_LABELS[status].label}`);
    setSelectedLibrarySlugs(new Set());
    setLibrarySelectMode(false);
  };

  const bulkRemoveLibrary = async () => {
    if (!userName || selectedLibrarySlugs.size === 0) return;
    const targets = savedBookmarks.filter((b) => selectedLibrarySlugs.has(b.slug));
    await Promise.all(
      targets.map((bm) =>
        setKatanaBookmark(
          {
            slug: bm.slug,
            id: bm.slug,
            title: bm.title,
            coverUrl: bm.coverUrl,
            status: 'ongoing',
            updateText: '',
            summary: '',
            genres: [],
            altNames: [],
            authors: [],
            artists: [],
            chapters: [],
            recentChapters: [],
          },
          userName,
          false,
        ),
      ),
    );
    showSnackBar(`Removed ${targets.length} ${targets.length === 1 ? 'title' : 'titles'} from Library`);
    setSelectedLibrarySlugs(new Set());
    setLibrarySelectMode(false);
  };

  // Exclude completed & dropped series from Currently Reading, and order by most recently read!
  const activeReadingList = useCallback((list: KatanaBookmark[]) => {
    return list
      .filter((b) => Boolean(b.lastReadChapterId) && resolveLibraryStatus(b) === 'reading')
      .sort((a, b) => (b.lastReadAt ?? b.addedAt).getTime() - (a.lastReadAt ?? a.addedAt).getTime());
  }, []);

  const myCurrentlyReading = useMemo(() => activeReadingList(bookmarks), [bookmarks, activeReadingList]);
  const currentlyReading = useMemo(
    () => activeReadingList(showPartnerReading ? partnerBookmarks : bookmarks),
    [bookmarks, partnerBookmarks, showPartnerReading, activeReadingList],
  );
  const savedBookmarks = useMemo(() => bookmarks.filter((b) => b.bookmarked), [bookmarks]);
  // Merge Firestore-synced categories, local cache, and any categories referenced by bookmarks so shelves never vanish across devices.
  const customCategories = useMemo(() => {
    const out = new Set<string>([...syncedCategories, ...localCategories]);
    for (const b of savedBookmarks) {
      for (const c of b.categories ?? []) {
        if (c.trim()) out.add(c.trim());
      }
    }
    return Array.from(out);
  }, [syncedCategories, localCategories, savedBookmarks]);

  const unreadBySlug = useMemo(() => {
    const map: Record<string, number> = {};
    for (const bm of bookmarks) {
      map[bm.slug] = estimateUnreadCount(bm);
    }
    return map;
  }, [bookmarks]);

  const libraryCounts = useMemo(() => {
    const counts: Record<'all' | 'caught_up' | 'downloaded' | KatanaLibraryStatus, number> = {
      all: savedBookmarks.length,
      reading: 0,
      caught_up: 0,
      downloaded: 0,
      on_hold: 0,
      completed: 0,
      planned: 0,
      dropped: 0,
    };
    for (const bm of savedBookmarks) {
      counts[resolveLibraryStatus(bm)] += 1;
      if (isBookmarkCaughtUp(bm)) counts.caught_up += 1;
      if ((downloadedCounts[bm.slug] ?? 0) > 0) counts.downloaded += 1;
    }
    return counts;
  }, [savedBookmarks, downloadedCounts]);

  const libraryLetters = useMemo(() => {
    const set = new Set<string>();
    for (const bm of savedBookmarks) {
      const ch = bm.title.trim().charAt(0).toUpperCase();
      set.add(/[A-Z]/.test(ch) ? ch : '#');
    }
    return set;
  }, [savedBookmarks]);

  const totalChaptersRead = useMemo(
    () => bookmarks.reduce((acc, b) => acc + (b.readChapterIds?.length ?? 0), 0),
    [bookmarks],
  );

  const filteredLibrary = useMemo(() => {
    const q = libraryQuery.trim().toLowerCase();
    const hiddenSet = new Set(hiddenCategories);
    const list = savedBookmarks.filter((bm) => {
      if (libraryBucket === 'caught_up') {
        if (!isBookmarkCaughtUp(bm)) return false;
      } else if (libraryBucket === 'downloaded') {
        if ((downloadedCounts[bm.slug] ?? 0) <= 0) return false;
      } else if (libraryBucket !== 'all' && resolveLibraryStatus(bm) !== libraryBucket) {
        return false;
      }
      const bmCats = bm.categories ?? [];
      if (libraryCategory !== 'all') {
        if (!bmCats.includes(libraryCategory)) return false;
      } else if (!showHiddenCategories && bmCats.length > 0 && bmCats.every((c) => hiddenSet.has(c))) {
        return false;
      }
      if (libraryLetter !== 'all') {
        const ch = bm.title.trim().charAt(0).toUpperCase();
        const bucketChar = /[A-Z]/.test(ch) ? ch : '#';
        if (bucketChar !== libraryLetter) return false;
      }
      if (q && !bm.title.toLowerCase().includes(q)) return false;
      return true;
    });
    if (librarySort === 'title') {
      list.sort((a, b) => a.title.localeCompare(b.title));
    } else if (librarySort === 'unread') {
      list.sort((a, b) => estimateUnreadCount(b) - estimateUnreadCount(a) || a.title.localeCompare(b.title));
    } else if (librarySort === 'added') {
      list.sort((a, b) => b.addedAt.getTime() - a.addedAt.getTime());
    } else {
      list.sort((a, b) => (b.lastReadAt ?? b.addedAt).getTime() - (a.lastReadAt ?? a.addedAt).getTime());
    }
    return list;
  }, [savedBookmarks, libraryBucket, libraryCategory, libraryLetter, libraryQuery, librarySort, hiddenCategories, showHiddenCategories, downloadedCounts]);

  const groupedHistory = useMemo(() => {
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    const todayMs = startOfToday.getTime();
    const yesterdayMs = todayMs - 86_400_000;
    const groups: Array<{ label: string; items: KatanaHistoryEntry[] }> = [
      { label: 'Today', items: [] },
      { label: 'Yesterday', items: [] },
      { label: 'Earlier', items: [] },
    ];
    for (const entry of historyEntries) {
      if (entry.readAt >= todayMs) groups[0].items.push(entry);
      else if (entry.readAt >= yesterdayMs) groups[1].items.push(entry);
      else groups[2].items.push(entry);
    }
    return groups.filter((g) => g.items.length > 0);
  }, [historyEntries]);

  const handleLoadPreview = async (manga: KatanaManga) => {
    if (previewLoading) return;
    if (previewPages && previewPages.slug === manga.slug) {
      setPreviewPages(null);
      return;
    }
    const firstChapter = manga.chapters[manga.chapters.length - 1] ?? manga.chapters[0];
    if (!firstChapter) {
      showSnackBar('No chapters available to preview');
      return;
    }
    setPreviewLoading(true);
    try {
      const pages = await fetchKatanaChapterPages(manga.slug, firstChapter.id);
      if (pages.length === 0) {
        showSnackBar('Preview pages are unavailable right now');
        return;
      }
      setPreviewPages({
        slug: manga.slug,
        chapterId: firstChapter.id,
        chapterTitle: chapterDisplayTitle(firstChapter),
        urls: pages.slice(0, 3),
      });
    } catch {
      showSnackBar('Could not load chapter preview');
    } finally {
      setPreviewLoading(false);
    }
  };

  const handleRefreshLibrary = async () => {
    if (libraryRefreshing) return;
    setLibraryRefreshing(true);
    try {
      const fresh = await fetchKatanaHome();
      setHomeData(fresh);
      showSnackBar('Library checked for new chapters');
    } catch {
      showSnackBar('Could not refresh right now');
    } finally {
      setLibraryRefreshing(false);
    }
  };

  const openChapter = useCallback(
    (manga: KatanaManga, chapterId: string, initialPage = 1) => {
      const bm = bookmarks.find((b) => b.slug === manga.slug);
      const chObj = manga.chapters.find((c) => c.id === chapterId);
      if (userName) {
        setHistoryEntries(
          recordKatanaHistory(userName, {
            slug: manga.slug,
            title: manga.title,
            coverUrl: manga.coverUrl,
            chapterId,
            chapterTitle: chObj ? chapterDisplayTitle(chObj) : `Chapter ${chapterId}`,
            page: initialPage,
            readAt: Date.now(),
          }),
        );
      }
      setReaderParams({
        slug: manga.slug,
        chapterId,
        mangaTitle: manga.title,
        coverUrl: manga.coverUrl,
        chapters: manga.chapters,
        initialPage,
        mangaStatus: manga.status,
        finalChapterId: manga.chapters[0]?.id ?? manga.latestChapter?.id,
        readChapterIds: bm?.readChapterIds,
        seriesFormat: inferSeriesReadingFormat(
          manga.genres.map((g) => g.name),
          manga.title,
          manga.demographic,
          manga.altNames,
          manga.slug,
        ),
      });
      const targetUrl = `/manga/series/${encodeURIComponent(manga.slug)}/${encodeURIComponent(chapterId)}${preservedQuery}`;
      if (`${location.pathname}${location.search}` !== targetUrl) {
        void navigate(targetUrl);
      }
    },
    [bookmarks, location.pathname, location.search, navigate, preservedQuery, userName],
  );

  const bookmarksRef = useRef(bookmarks);
  bookmarksRef.current = bookmarks;
  const prevRouteChapterRef = useRef<string | null>(activeRouteChapterId);

  // Sync URL-addressed chapter (/manga/series/:slug/:chapterId) with reader overlay so
  // browser Back closes the reader, refresh resumes, and deep links open directly.
  useEffect(() => {
    const prevChapter = prevRouteChapterRef.current;
    prevRouteChapterRef.current = activeRouteChapterId;
    if (!activeRouteChapterId) {
      // Only close the reader when navigating BACK from a chapter URL to the series page.
      if (prevChapter) setReaderParams(null);
      return;
    }
    if (!detail || !detailSlug || detail.slug !== detailSlug) return;
    setReaderParams((prev) => {
      if (prev && prev.slug === detail.slug && prev.chapterId === activeRouteChapterId) return prev;
      const bm = bookmarksRef.current.find((b) => b.slug === detail.slug);
      const initialPage = bm?.lastReadChapterId === activeRouteChapterId ? Math.max(1, bm.lastReadPage || 1) : 1;
      return {
        slug: detail.slug,
        chapterId: activeRouteChapterId,
        mangaTitle: detail.title,
        coverUrl: detail.coverUrl,
        chapters: detail.chapters,
        initialPage,
        mangaStatus: detail.status,
        finalChapterId: detail.chapters[0]?.id ?? detail.latestChapter?.id,
        readChapterIds: bm?.readChapterIds,
        seriesFormat: inferSeriesReadingFormat(
          detail.genres.map((g) => g.name),
          detail.title,
          detail.demographic,
          detail.altNames,
          detail.slug,
        ),
      };
    });
  }, [activeRouteChapterId, detail, detailSlug]);

  const closeReader = useCallback(() => {
    setReaderParams(null);
    if (activeRouteChapterId && detailSlug) {
      if (location.key !== 'default') void navigate(-1);
      else void navigate(`/manga/series/${encodeURIComponent(detailSlug)}${preservedQuery}`, { replace: true });
    }
  }, [activeRouteChapterId, detailSlug, location.key, navigate, preservedQuery]);

  const resumeBookmark = async (bm: KatanaBookmark) => {
    if (!bm.lastReadChapterId) {
      openDetail(bm.slug);
      return;
    }
    if (resumingSlug) return;
    setResumingSlug(bm.slug);
    try {
      const loaded = await fetchKatanaDetail(bm.slug);
      if (loaded && loaded.chapters.length > 0) {
        const match = loaded.chapters.find((c) => c.id === bm.lastReadChapterId) ?? loaded.chapters[loaded.chapters.length - 1];
        openChapter(loaded, match.id, Math.max(1, bm.lastReadPage || 1));
      } else {
        openDetail(bm.slug);
      }
    } catch {
      showSnackBar('Could not resume chapter — opening details');
      openDetail(bm.slug);
    } finally {
      setResumingSlug(null);
    }
  };

  const openOfflineMangaChapter = (item: OfflineMediaItem) => {
    const chapterId = item.chapterId ?? '1';
    setReaderParams({
      slug: item.mediaId,
      chapterId,
      mangaTitle: item.title,
      coverUrl: item.coverUrl,
      chapters: [{ id: chapterId, num: '', title: item.subtitle || chapterId }],
      initialPage: item.lastPositionSeconds && item.lastPositionSeconds > 0 ? item.lastPositionSeconds : 1,
    });
  };

  const removeFromReading = async (slug: string, title: string) => {
    if (!userName || !slug) return;
    try {
      await clearKatanaReadingProgress(slug, userName);
      clearResumeAnchor(slug);
      showSnackBar(`Removed ${title || 'manga'} from Currently Reading`);
    } catch {
      showSnackBar('Could not update reading status — try again');
    }
  };

  const confirmResetProgress = (slug: string, title: string) => {
    void showDialog<void>((close) => (
      <AlertDialog
        background={KatanaColors.surface}
        title={<div style={KatanaType.title}>Reset Reading Progress</div>}
        content={<div style={KatanaType.small}>Clear your last-read chapter and resume position for {title}?</div>}
        actions={[
          <TextButton key="cancel" onPressed={() => close(null)} color={KatanaColors.textMuted}>
            Cancel
          </TextButton>,
          <TextButton
            key="reset"
            color="#FF453A"
            onPressed={() => {
              close(null);
              void removeFromReading(slug, title);
            }}
          >
            Reset Progress
          </TextButton>,
        ]}
      />
    ));
  };

  const confirmUnknownWifiDownload = useCallback(async (): Promise<boolean> => {
    const policy = loadUnknownNetworkWifiPolicy();
    if (policy === 'allow') return true;
    if (policy === 'block') return false;
    try {
      if (sessionStorage.getItem('katana_wifi_confirmed_v1') === '1') return true;
    } catch {
      // ignore storage errors
    }
    const ok = await showDialog<boolean>((close) => (
      <AlertDialog
        background={KatanaColors.surface}
        title={<div style={KatanaType.title}>Confirm Wi-Fi Connection</div>}
        content={
          <div style={KatanaType.small}>
            Wi-Fi-only downloads is turned on, and this browser (such as iOS Safari) does not report Wi-Fi vs. cellular status automatically. Choose whether to assume Wi-Fi or block downloads on unknown connections.
          </div>
        }
        actions={[
          <TextButton
            key="block"
            onPressed={() => {
              saveUnknownNetworkWifiPolicy('block');
              close(false);
            }}
            color={KatanaColors.textMuted}
          >
            Block on Unknown
          </TextButton>,
          <TextButton
            key="once"
            color={KatanaColors.text}
            onPressed={() => {
              try {
                sessionStorage.setItem('katana_wifi_confirmed_v1', '1');
              } catch {
                // ignore
              }
              close(true);
            }}
          >
            Allow Once
          </TextButton>,
          <TextButton
            key="always"
            color={KatanaColors.accent}
            onPressed={() => {
              saveUnknownNetworkWifiPolicy('allow');
              try {
                sessionStorage.setItem('katana_wifi_confirmed_v1', '1');
              } catch {
                // ignore
              }
              close(true);
            }}
          >
            Always Assume Wi-Fi
          </TextButton>,
        ]}
      />
    ));
    return Boolean(ok);
  }, []);

  useEffect(() => {
    if (offline.mangaItems.length === 0) return;
    void offlineMedia.verifyAllMangaChaptersCache();
  }, [offline.mangaItems.length]);

  const downloadChapter = useCallback(
    async (manga: KatanaManga, chapter: KatanaChapter, silent = false): Promise<boolean> => {
      if (downloadWifiOnly && isOnMeteredCellular()) {
        if (!silent) showSnackBar('Wi-Fi-only downloads is on. Turn it off in Downloads to use mobile data.');
        return false;
      }
      if (downloadWifiOnly && !supportsNetworkConnectionApi() && !silent) {
        const allowed = await confirmUnknownWifiDownload();
        if (!allowed) return false;
      }
      const offlineId = OfflineIds.mangaChapterId(manga.slug, chapter.id);
      if (offlineMedia.isDownloaded(offlineId)) {
        if (!silent) showSnackBar(`${chapterDisplayTitle(chapter)} is already saved offline`);
        return true;
      }
      setDownloadingChapterIds((prev) => new Set(prev).add(chapter.id));
      try {
        const pages = await fetchKatanaChapterPages(manga.slug, chapter.id);
        if (pages.length === 0) {
          if (!silent) showSnackBar(`Could not fetch pages for ${chapterDisplayTitle(chapter)}`);
          return false;
        }
        await offlineMedia.startDownloadMangaChapter({
          slug: manga.slug,
          mangaTitle: manga.title,
          coverUrl: manga.coverUrl,
          chapterId: chapter.id,
          chapterTitle: chapterDisplayTitle(chapter),
          pageUrls: pages,
          proxy: proxyKatanaImageUrl,
        });
        if (!silent) showSnackBar(`Saved ${chapterDisplayTitle(chapter)} for offline reading`);
        return true;
      } catch {
        if (!silent) showSnackBar(`Download failed for ${chapterDisplayTitle(chapter)}`);
        return false;
      } finally {
        setDownloadingChapterIds((prev) => {
          const next = new Set(prev);
          next.delete(chapter.id);
          return next;
        });
      }
    },
    [downloadWifiOnly, confirmUnknownWifiDownload],
  );

  const cancelDownloadQueue = useCallback(() => {
    downloadCancelRef.current = true;
    showSnackBar('Cancelling remaining downloads…');
  }, []);

  const moveDownloadQueueItem = useCallback((index: number, delta: -1 | 1) => {
    const cur = [...downloadQueueRef.current];
    const target = index + delta;
    if (index < 0 || target < 0 || index >= cur.length || target >= cur.length) return;
    const [moved] = cur.splice(index, 1);
    cur.splice(target, 0, moved);
    downloadQueueRef.current = cur;
    setDownloadQueue(cur);
    savePendingDownloadQueue(cur);
  }, []);

  const removeDownloadQueueItem = useCallback((index: number) => {
    const cur = [...downloadQueueRef.current];
    if (index < 0 || index >= cur.length) return;
    cur.splice(index, 1);
    downloadQueueRef.current = cur;
    setDownloadQueue(cur);
    savePendingDownloadQueue(cur);
  }, []);

  const runDownloadQueue = useCallback(
    async (initialQueue: PersistedQueueEntry[]) => {
      const pending = initialQueue.filter(
        (item) => !offlineMedia.isDownloaded(OfflineIds.mangaChapterId(item.manga.slug, item.chapter.id)),
      );
      if (pending.length === 0) {
        savePendingDownloadQueue([]);
        return;
      }
      downloadCancelRef.current = false;
      downloadQueueRef.current = pending;
      setDownloadQueue(pending);
      savePendingDownloadQueue(pending);
      const total = pending.length;
      setBatchProgress({ done: 0, total, currentTitle: chapterDisplayTitle(pending[0].chapter) });
      let saved = 0;
      let processed = 0;
      const failed: PersistedQueueEntry[] = [];
      const inFlight = new Set<PersistedQueueEntry>();
      const activeSources = new Set<string>();
      // Mihon-style rate-limit protection: 1 chapter at a time per source, up to 2 distinct sources in parallel.
      const MAX_CROSS_SOURCE_WORKERS = 2;
      const resolveItemSource = (m: KatanaManga): string =>
        m.source ||
        (m.slug.startsWith('md-')
          ? 'mangadex'
          : m.slug.startsWith('ck-')
            ? 'comick'
            : m.slug.startsWith('bt-')
              ? 'bato'
              : 'mangakatana');

      const claimNextSourceSafeItem = (): { item: PersistedQueueEntry; source: string } | null => {
        const q = downloadQueueRef.current;
        for (let i = 0; i < q.length; i++) {
          const src = resolveItemSource(q[i].manga);
          if (!activeSources.has(src)) {
            const [picked] = q.splice(i, 1);
            downloadQueueRef.current = [...q];
            activeSources.add(src);
            return { item: picked, source: src };
          }
        }
        return null;
      };

      const worker = async () => {
        while (downloadQueueRef.current.length > 0) {
          if (downloadCancelRef.current) break;
          const claimed = claimNextSourceSafeItem();
          if (!claimed) {
            if (inFlight.size === 0) break;
            await new Promise((r) => window.setTimeout(r, 120));
            continue;
          }
          const { item: nextItem, source: itemSource } = claimed;
          const rest = downloadQueueRef.current;
          inFlight.add(nextItem);
          setDownloadQueue(rest);
          savePendingDownloadQueue([...inFlight, ...rest]);
          setBatchProgress({
            done: processed,
            total: processed + inFlight.size + rest.length,
            currentTitle: `${chapterDisplayTitle(nextItem.chapter)} (${itemSource.toUpperCase()})`,
          });
          const ok = await downloadChapter(nextItem.manga, nextItem.chapter, true);
          activeSources.delete(itemSource);
          inFlight.delete(nextItem);
          processed += 1;
          if (ok) saved += 1;
          else failed.push(nextItem);
          savePendingDownloadQueue([...inFlight, ...downloadQueueRef.current]);
          const nextTitle =
            downloadQueueRef.current[0]
              ? chapterDisplayTitle(downloadQueueRef.current[0].chapter)
              : [...inFlight][0]
                ? chapterDisplayTitle([...inFlight][0].chapter)
                : undefined;
          setBatchProgress({
            done: processed,
            total: processed + inFlight.size + downloadQueueRef.current.length,
            currentTitle: nextTitle,
          });
        }
      };

      await Promise.all(
        Array.from({ length: Math.min(MAX_CROSS_SOURCE_WORKERS, pending.length) }, () => worker()),
      );

      const wasCancelled = downloadCancelRef.current;
      downloadCancelRef.current = false;
      downloadQueueRef.current = [];
      setDownloadQueue([]);
      savePendingDownloadQueue([]);
      setBatchProgress(null);
      if (failed.length > 0) {
        setFailedDownloads((prev) => {
          const existing = new Set(prev.map((x) => `${x.manga.slug}:${x.chapter.id}`));
          const additions = failed.filter((x) => !existing.has(`${x.manga.slug}:${x.chapter.id}`));
          return [...prev, ...additions];
        });
      }
      showSnackBar(
        wasCancelled
          ? `Stopped after saving ${saved} of ${total} chapters`
          : failed.length > 0
            ? `Saved ${saved} chapters · ${failed.length} failed (retry in Downloads)`
            : `Saved ${saved} ${saved === 1 ? 'chapter' : 'chapters'} offline`,
      );
    },
    [downloadChapter],
  );

  const retryFailedDownloads = useCallback(() => {
    if (failedDownloads.length === 0) return;
    const toRetry = [...failedDownloads];
    setFailedDownloads([]);
    void runDownloadQueue(toRetry);
  }, [failedDownloads, runDownloadQueue]);

  const retrySingleFailedDownload = useCallback(
    (index: number) => {
      const target = failedDownloads[index];
      if (!target) return;
      setFailedDownloads((prev) => prev.filter((_, i) => i !== index));
      void runDownloadQueue([target]);
    },
    [failedDownloads, runDownloadQueue],
  );

  const clearFailedDownloads = useCallback(() => {
    setFailedDownloads([]);
  }, []);

  const downloadBatchChapters = useCallback(
    async (manga: KatanaManga, chapters: KatanaChapter[]) => {
      if (downloadWifiOnly && isOnMeteredCellular()) {
        showSnackBar('Wi-Fi-only downloads is on. Turn it off in Downloads to use mobile data.');
        return;
      }
      if (downloadWifiOnly && !supportsNetworkConnectionApi()) {
        const allowed = await confirmUnknownWifiDownload();
        if (!allowed) return;
      }
      const targets = chapters.filter((c) => !offlineMedia.isDownloaded(OfflineIds.mangaChapterId(manga.slug, c.id)));
      if (targets.length === 0) {
        showSnackBar('Selected chapters are already saved offline');
        return;
      }
      await runDownloadQueue(targets.map((chapter) => ({ manga, chapter })));
    },
    [downloadWifiOnly, confirmUnknownWifiDownload, runDownloadQueue],
  );

  // Resume any unfinished queued downloads saved before a tab close or reload.
  const resumedQueueRef = useRef(false);
  useEffect(() => {
    if (resumedQueueRef.current || batchProgress != null) return;
    resumedQueueRef.current = true;
    const saved = loadPendingDownloadQueue();
    if (saved.length === 0) return;
    if (downloadWifiOnly && isOnMeteredCellular()) return;
    void runDownloadQueue(saved);
  }, [batchProgress, downloadWifiOnly, runDownloadQueue]);

  const autoDownloadedRef = useRef<Set<string>>(new Set());
  useEffect(() => {
    if (!detail || autoDownloadNext <= 0 || batchProgress != null) return;
    if (downloadWifiOnly && isOnMeteredCellular()) return;
    const bm = bookmarks.find((b) => b.slug === detail.slug);
    if (!bm?.bookmarked) return;
    if (autoDownloadCategories.length > 0) {
      const bmCats = bm.categories ?? [];
      if (!bmCats.some((c) => autoDownloadCategories.includes(c))) return;
    }
    if (autoDownloadedRef.current.has(detail.slug)) return;
    const readIds = new Set(bm.readChapterIds ?? []);
    const oldestFirst = [...detail.chapters].reverse();
    const targets = oldestFirst
      .filter((c) => !readIds.has(c.id) && !offlineMedia.isDownloaded(OfflineIds.mangaChapterId(detail.slug, c.id)))
      .slice(0, autoDownloadNext);
    if (targets.length === 0) return;
    autoDownloadedRef.current.add(detail.slug);
    void downloadBatchChapters(detail, targets);
  }, [detail, autoDownloadNext, autoDownloadCategories, batchProgress, downloadWifiOnly, bookmarks, downloadBatchChapters]);

  const downloadNextUnread = useCallback(
    async (manga: KatanaManga, readIds: Set<string>, count: number) => {
      const oldestFirst = [...manga.chapters].reverse();
      const targets = oldestFirst
        .filter((c) => !readIds.has(c.id) && !offlineMedia.isDownloaded(OfflineIds.mangaChapterId(manga.slug, c.id)))
        .slice(0, count);
      if (targets.length === 0) {
        showSnackBar('No new unread chapters to download');
        return;
      }
      await downloadBatchChapters(manga, targets);
    },
    [downloadBatchChapters],
  );

  const downloadAllUnread = useCallback(
    async (manga: KatanaManga, readIds: Set<string>) => {
      const oldestFirst = [...manga.chapters].reverse();
      const targets = oldestFirst.filter(
        (c) => !readIds.has(c.id) && !offlineMedia.isDownloaded(OfflineIds.mangaChapterId(manga.slug, c.id)),
      );
      if (targets.length === 0) {
        showSnackBar('All unread chapters are already saved offline');
        return;
      }
      await downloadBatchChapters(manga, targets);
    },
    [downloadBatchChapters],
  );

  const shareSeriesLink = async (manga: KatanaManga) => {
    const url = `${window.location.origin}/manga/series/${encodeURIComponent(manga.slug)}`;
    try {
      await navigator.clipboard.writeText(url);
      showSnackBar('Series link copied');
    } catch {
      showSnackBar(url);
    }
  };

  // Broaden "More Like This" by querying the primary genre so deep-linked series still get matches.
  useEffect(() => {
    const primaryGenre = detail?.genres[0]?.slug;
    if (!detail || !primaryGenre) {
      setSimilarCatalog([]);
      return;
    }
    let alive = true;
    fetchKatanaCatalog({ mode: 'genre', key: primaryGenre, page: 1 })
      .then((res) => {
        if (alive) setSimilarCatalog(res.items);
      })
      .catch(() => {
        if (alive) setSimilarCatalog([]);
      });
    return () => {
      alive = false;
    };
  }, [detail]);

  const similarToDetail = useMemo(() => {
    if (!detail) return [];
    const genreSet = new Set(detail.genres.map((g) => g.slug));
    const authorSet = new Set(detail.authors.map((a) => a.toLowerCase()));
    const titleStem = detail.title.toLowerCase().split(/[:\-–(]/)[0].trim();
    const pool = new Map<string, KatanaManga>();
    for (const m of [...similarCatalog, ...(homeData?.hot ?? []), ...(homeData?.latest ?? []), ...catItems]) {
      if (m.slug !== detail.slug && !pool.has(m.slug)) pool.set(m.slug, m);
    }

    const explicitRelations: Array<{ manga: KatanaManga; relation: string; score: number }> = [];
    const explicitSlugs = new Set<string>();
    const relationLabels: Record<string, string> = {
      sequel: 'Sequel',
      prequel: 'Prequel',
      spin_off: 'Spin-Off',
      side_story: 'Side Story',
      adaptation: 'Adaptation',
      shared_universe: 'Shared Universe',
      same_creator: 'Same Creator',
    };
    for (const rel of detail.relatedWorks ?? []) {
      if (!rel.slug || rel.slug === detail.slug) continue;
      explicitSlugs.add(rel.slug);
      const fromPool = pool.get(rel.slug);
      const synthesized: KatanaManga = fromPool ?? {
        slug: rel.slug,
        id: rel.slug,
        title: rel.title,
        coverUrl: rel.coverUrl ?? detail.coverUrl,
        status: rel.status ?? 'ongoing',
        updateText: '',
        summary: '',
        genres: detail.genres.slice(0, 2),
        recentChapters: [],
        altNames: [],
        authors: detail.authors,
        artists: detail.artists,
        chapters: [],
        source: rel.slug.startsWith('md-') ? 'mangadex' : detail.source,
      };
      explicitRelations.push({
        manga: synthesized,
        relation: relationLabels[rel.relation] ?? 'Related Work',
        score: 100,
      });
    }

    const candidates = [...pool.values()]
      .filter((m) => !explicitSlugs.has(m.slug))
      .map((m) => {
        const sameAuthor = m.authors.some((a) => authorSet.has(a.toLowerCase()));
        const mLower = m.title.toLowerCase();
        const relatedTitle = titleStem.length >= 5 && mLower.includes(titleStem);
        const isPrequelOrSequel =
          relatedTitle &&
          (detail.title.includes(':') && !m.title.includes(':')
            ? 'Prequel / Main Series'
            : !detail.title.includes(':') && m.title.includes(':')
              ? 'Sequel / Spin-Off'
              : 'Franchise / Spin-Off');
        const sharedGenres = m.genres.filter((g) => genreSet.has(g.slug)).length;
        const relation = isPrequelOrSequel
          ? isPrequelOrSequel
          : sameAuthor
            ? 'Same Creator'
            : sharedGenres > 0
              ? `${sharedGenres} genre${sharedGenres === 1 ? '' : 's'} in common`
              : '';
        const score = (relatedTitle ? 14 : 0) + (sameAuthor ? 10 : 0) + sharedGenres * 2 + (m.rating ? m.rating / 5 : 0);
        return { manga: m, relation, score };
      });

    return [...explicitRelations, ...candidates]
      .sort((a, b) => b.score - a.score)
      .slice(0, 6);
  }, [detail, homeData, similarCatalog, catItems]);

  const effectiveCatView = catViewMode;
  const filteredGenres = useMemo(() => {
    const q = genreFilterText.trim().toLowerCase();
    const list = homeData?.genres ?? [];
    return q ? list.filter((g) => g.name.toLowerCase().includes(q) || g.description.toLowerCase().includes(q)) : list;
  }, [homeData?.genres, genreFilterText]);

  const partnerDisplayLabel = partnerUsername ? displayNameFor(partnerUsername) : '';

  const saveCurrentFilterPreset = () => {
    const autoParts: string[] = [];
    if (statusFilter !== 'all') autoParts.push(statusFilter === 'ongoing' ? 'Ongoing' : 'Completed');
    if (demographicFilter !== 'all') autoParts.push(demographicFilter);
    if (languageFilter !== 'all') autoParts.push(languageFilter.toUpperCase());
    if (includeGenres.length > 0) autoParts.push(includeGenres.slice(0, 2).join(', '));
    if (authorFilter.trim()) autoParts.push(authorFilter.trim());
    if (minChapters !== '1') autoParts.push(`${minChapters}+ ch`);
    if (orderBy !== 'latest' && autoParts.length === 0) autoParts.push(orderBy);
    const name = presetNameDraft.trim() || autoParts.join(' · ') || 'Custom filter';
    const nextPreset: SavedFilterPreset = {
      id: `preset-${Date.now()}`,
      name,
      order: orderBy,
      status: statusFilter,
      demo: demographicFilter,
      minCh: minChapters,
      gm: genreMode,
      lang: languageFilter,
      author: authorFilter.trim(),
      inc: [...includeGenres],
      exc: [...excludeGenres],
    };
    const next = [nextPreset, ...filterPresets.filter((p) => p.name.toLowerCase() !== name.toLowerCase())].slice(0, 12);
    setFilterPresets(next);
    saveFilterPresets(next);
    setPresetNameDraft('');
    showSnackBar(`Saved filter preset "${name}"`);
  };

  const applyFilterPreset = (preset: SavedFilterPreset) => {
    setAuthorDraft(preset.author);
    updateMangaUrl(
      {
        order: preset.order === 'latest' ? null : preset.order,
        status: preset.status === 'all' ? null : preset.status,
        demo: preset.demo === 'all' ? null : preset.demo,
        minCh: preset.minCh === '1' ? null : preset.minCh,
        gm: preset.gm === 'and' ? null : preset.gm,
        lang: preset.lang === 'all' ? null : preset.lang,
        author: preset.author || null,
        inc: preset.inc.length > 0 ? preset.inc.join(',') : null,
        exc: preset.exc.length > 0 ? preset.exc.join(',') : null,
        page: '1',
      },
      { replace: true },
    );
  };

  const deleteFilterPreset = (id: string) => {
    const next = filterPresets.filter((p) => p.id !== id);
    setFilterPresets(next);
    saveFilterPresets(next);
  };

  const detailCoverAccent = useCoverDominantAccent(
    detail?.coverUrl ? proxyKatanaImageUrl(detail.coverUrl) : undefined,
    detail?.title ?? '',
    detail?.genres.map((g) => g.name),
  );

  const filterPanelBody = (
    <MangaCatalogFilterPanel
      filterPresets={filterPresets}
      activeFilterCount={activeFilterCount}
      orderBy={orderBy}
      statusFilter={statusFilter}
      demographicFilter={demographicFilter}
      minChapters={minChapters}
      genreMode={genreMode}
      languageFilter={languageFilter}
      authorDraft={authorDraft}
      setAuthorDraft={setAuthorDraft}
      presetNameDraft={presetNameDraft}
      setPresetNameDraft={setPresetNameDraft}
      includeGenres={includeGenres}
      excludeGenres={excludeGenres}
      genres={homeData?.genres ?? []}
      onSavePreset={saveCurrentFilterPreset}
      onApplyPreset={applyFilterPreset}
      onDeletePreset={deleteFilterPreset}
      onUpdateUrl={updateMangaUrl}
      onToggleIncludeGenre={toggleIncludeGenre}
      onToggleExcludeGenre={toggleExcludeGenre}
    />
  );

  return (
    <div
      className="katana-scope"
      data-katana-theme={themeMode}
      style={{
        ...(KATANA_THEME_VARS[themeMode] as React.CSSProperties),
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        background: KatanaColors.background,
        color: KatanaColors.text,
      }}
    >
      <TvMediaNavHeader currentRoute="/manga" />
      <KatanaHeader
        active={tab}
        width={width}
        userName={userName}
        showBack={isCoupleUser}
        genres={homeData?.genres ?? []}
        themeMode={themeMode}
        initialSearchBy={searchBy}
        syncedRecentSearches={syncedRecentSearches}
        onCycleTheme={cycleThemeMode}
        onSelectTheme={selectThemeMode}
        onBack={() => navigate('/dashboard')}
        onSelectNav={handleNav}
        onSubmitSearch={(q, by) => {
          setFilterOpen(false);
          updateMangaUrl({ tab: 'directory', mode: 'search', q, by: by === 'm_name' ? null : by }, { clearAll: true });
        }}
        onSelectManga={openDetail}
        onSelectGenre={handleSelectGenre}
      />

      {isHome ? (
        <div ref={homeScrollRef} style={{ flex: 1, overflowY: 'auto' }}>
          <MangaHome
            width={width}
            userName={userName}
            syncedPreferredGenres={syncedUserPrefs?.preferredGenres}
            data={homeData}
            currentlyReading={myCurrentlyReading}
            libraryBookmarks={savedBookmarks}
            extraCatalog={catItems}
            downloadedCounts={downloadedCounts}
            sourceHealth={syncedUserPrefs?.sourceHealth}
            type={typeFilter}
            typeItems={typeItems}
            typeLoading={typeLoading}
            typePage={typePage}
            typeHasNext={typeHasNext}
            typeTotalPages={typeTotalPages}
            typeTotalResults={typeTotalResults}
            onSelectType={(t) => updateMangaUrl({ type: t === 'all' ? null : t, tpage: '1' }, { replace: true })}
            onTypePage={(p) => updateMangaUrl({ tpage: String(p) })}
            onSelectManga={openDetail}
            onSelectGenre={handleSelectGenre}
            onOpenChapter={openChapter}
            onResumeBookmark={(bm) => void resumeBookmark(bm)}
            onViewAllReading={() => handleNav('reading')}
            onRetryHome={() => setHomeRefreshTick((n) => n + 1)}
            scrollContainerRef={homeScrollRef}
          />
        </div>
      ) : (
        <div style={{ flex: 1, overflowY: 'auto', padding: '16px 16px max(96px, env(safe-area-inset-bottom))' }}>
          <div style={{ maxWidth: 1380, margin: '0 auto' }}>
            {detailSlug ? (
              detailLoading ? (
                <KatanaSkeletonList count={3} />
              ) : !detail ? (
                <>
                <KatanaEmptyState
                  icon="error_outline"
                  title="Could not load this title"
                  subtitle="MangaKatana, MangaDex, ComicK, and Bato.to are all unreachable right now. Check your connection and try again."
                  actionLabel="Try again"
                  actionIcon="refresh"
                  onAction={() => setDetailRetryTick((n) => n + 1)}
                />
                <div style={{ display: 'flex', justifyContent: 'center', marginTop: 4 }}>
                  <KatanaButton label="Back to Home" icon="arrow_back" size="sm" filled={false} color={KatanaColors.textMuted} onClick={closeDetail} />
                </div>
                </>
              ) : (
                (() => {
                  const detailBm = bookmarks.find((b) => b.slug === detail.slug);
    const partnerDetailBm = isCoupleUser ? partnerBookmarks.find((b) => b.slug === detail.slug) : undefined;
                  const isBookmarked = Boolean(detailBm?.bookmarked);
                  const hasReadingProgress = Boolean(detailBm?.lastReadChapterId);
                  const currentStatus = detailBm ? resolveLibraryStatus(detailBm) : undefined;
                  const readSet = new Set(detailBm?.readChapterIds ?? []);
                  const readCount = detail.chapters.filter((c) => readSet.has(c.id)).length;
                  const unreadCount = Math.max(0, detail.chapters.length - readCount);
                  const readPct = detail.chapters.length > 0 ? Math.round((readCount / detail.chapters.length) * 100) : 0;

                  const orderedChapters = chapterSortAsc ? [...detail.chapters].reverse() : detail.chapters;
                  const availableChapterLangs = Array.from(
                    new Set(
                      detail.chapters
                        .map((c) => (c.language || '').trim().toLowerCase())
                        .filter(Boolean),
                    ),
                  );
                  const availableChapterGroups = Array.from(
                    new Set(
                      detail.chapters
                        .map((c) => (c.scanlationGroup || '').trim())
                        .filter(Boolean),
                    ),
                  ).slice(0, 8);
                  const blockedGroupSet = new Set(blockedScanlationGroups.map((g) => g.toLowerCase()));
                  const readChapterNums = new Set(
                    detail.chapters
                      .filter((ch) => readSet.has(ch.id))
                      .map((ch) => ch.num.trim())
                      .filter(Boolean),
                  );
                  const blockedChaptersCount = detail.chapters.filter(
                    (c) => c.scanlationGroup && blockedGroupSet.has(c.scanlationGroup.trim().toLowerCase()),
                  ).length;
                  const chapterGapReport = detectSeriesMissingChapters(detail.chapters);
                  const seriesSavedMoments = loadPageBookmarks(detail.slug);

                  const q = chapterSearch.trim().toLowerCase();
                  const filteredChapters = orderedChapters
                    .filter((c) => {
                      const grp = (c.scanlationGroup || '').trim();
                      if (grp && blockedGroupSet.has(grp.toLowerCase())) return false;
                      if (chapterLangFilter !== 'all' && (c.language || '').trim().toLowerCase() !== chapterLangFilter) {
                        return false;
                      }
                      if (chapterGroupFilter !== 'all' && grp !== chapterGroupFilter) {
                        return false;
                      }
                      if (!q) return true;
                      return (
                        chapterDisplayTitle(c).toLowerCase().includes(q) ||
                        c.num.toLowerCase().includes(q) ||
                        c.id.toLowerCase().includes(q) ||
                        grp.toLowerCase().includes(q)
                      );
                    })
                    .sort((a, b) => {
                      if (!preferredScanlationGroup || a.num !== b.num) return 0;
                      const aPref = (a.scanlationGroup || '').trim() === preferredScanlationGroup ? 1 : 0;
                      const bPref = (b.scanlationGroup || '').trim() === preferredScanlationGroup ? 1 : 0;
                      return bPref - aPref;
                    });
                  const visibleChapters = filteredChapters.slice(0, chapterWindow);
                  const hasChapterMetaFilters =
                    availableChapterLangs.length > 1 ||
                    availableChapterGroups.length >= 1 ||
                    blockedScanlationGroups.length > 0;
                  const activeChapterFilterCount =
                    (chapterLangFilter !== 'all' ? 1 : 0) +
                    (chapterGroupFilter !== 'all' ? 1 : 0) +
                    (preferredScanlationGroup ? 1 : 0) +
                    blockedScanlationGroups.length;

                  const toggleSelectChapter = (id: string) => {
                    setSelectedChapterIds((prev) => {
                      const next = new Set(prev);
                      if (next.has(id)) next.delete(id);
                      else next.add(id);
                      return next;
                    });
                  };

                  const seriesAccent = detailCoverAccent;
                  const alertsEnabled =
                    isBookmarked &&
                    (typeof detailBm?.notifyOnUpdate === 'boolean'
                      ? detailBm.notifyOnUpdate
                      : currentStatus === 'reading' || currentStatus === 'planned');

                  return (
                    <div>
                      <KatanaBreadcrumb items={['Manga', detail.title]} onHome={() => handleNav('home')} />

                      <div
                        style={{
                          position: 'relative',
                          overflow: 'hidden',
                          borderRadius: 14,
                          padding: tablet ? 20 : 14,
                          backgroundColor: KatanaColors.surface,
                          border: `1px solid ${withAlpha(KatanaColors.border, 0.72)}`,
                          backgroundImage: `radial-gradient(ellipse 75% 60% at 12% 0%, ${withAlpha(seriesAccent.accent, themeMode === 'dark' ? 0.14 : 0.1)}, transparent 72%)`,
                        }}
                      >
                        <div
                          style={
                            compactCard
                              ? {
                                  display: 'grid',
                                  gridTemplateColumns: '112px minmax(0, 1fr)',
                                  columnGap: 14,
                                  rowGap: 12,
                                  alignItems: 'start',
                                }
                              : {
                                  display: 'flex',
                                  gap: desktop ? 22 : 14,
                                  flexWrap: tablet ? 'nowrap' : 'wrap',
                                  alignItems: 'flex-start',
                                }
                          }
                        >
                          <div
                            style={{
                              position: 'relative',
                              width: desktop ? 200 : tablet ? 160 : 112,
                              height: desktop ? 290 : tablet ? 232 : 162,
                              borderRadius: 10,
                              border: `1px solid ${withAlpha(KatanaColors.text, 0.12)}`,
                              overflow: 'hidden',
                              flexShrink: 0,
                              background: KatanaColors.surfaceAlt,
                            }}
                          >
                            <KatanaCoverImage url={detail.coverUrl} title={detail.title} iconSize={34} priority />
                            <KatanaCoverBadges unreadCount={isBookmarked ? unreadCount : undefined} downloadedCount={downloadedCounts[detail.slug]} />
                          </div>

                          <div style={compactCard ? { display: 'contents' } : { flex: 1, minWidth: 200 }}>
                            <div style={compactCard ? { gridColumn: 2, minWidth: 0 } : undefined}>
                            <div
                              className="katana-tabular"
                              style={{
                                display: 'flex',
                                alignItems: 'center',
                                gap: 7,
                                flexWrap: 'wrap',
                                marginBottom: 6,
                                fontFamily: Fonts.body,
                                fontSize: 12,
                                fontWeight: 600,
                                color: KatanaColors.textMuted,
                              }}
                            >
                              <span style={{ color: detail.status === 'completed' ? KatanaColors.green : KatanaColors.teal }}>
                                {detail.status === 'completed' ? 'Completed' : 'Ongoing'}
                              </span>
                              {detail.rating != null && (
                                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, color: KatanaColors.text }}>
                                  <Icon name="star" size={13} color={KatanaColors.accent} />
                                  {detail.rating.toFixed(1)}
                                </span>
                              )}
                              <span>{detail.chapters.length} ch</span>
                              {detail.demographic && <span>{detail.demographic}</span>}
                              {!compactCard && detail.follows != null && detail.follows > 0 && (
                                <span style={{ color: KatanaColors.textLight }}>{formatCompactNumber(detail.follows)} readers</span>
                              )}
                              {detail.updateText && (
                                <span style={{ color: KatanaColors.textLight }}>{detail.updateText}</span>
                              )}
                            </div>

                            <h1 style={{ ...KatanaType.display, fontSize: tablet ? 28 : 21, margin: 0 }}>{detail.title}</h1>

                            {(detail.authors.length > 0 || detail.artists.length > 0) && (
                              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px 12px', marginTop: 6 }}>
                                {detail.authors.length > 0 && (
                                  <span style={{ ...KatanaType.body, fontSize: 13.5, color: KatanaColors.text, fontWeight: 600 }}>
                                    {detail.artists.length > 0 ? `Author: ${detail.authors.join(', ')}` : detail.authors.join(', ')}
                                  </span>
                                )}
                                {detail.artists.length > 0 && (
                                  <span style={{ ...KatanaType.body, fontSize: 13.5, color: KatanaColors.textMuted, fontWeight: 600 }}>
                                    Artist: {detail.artists.join(', ')}
                                  </span>
                                )}
                              </div>
                            )}

                            {detail.altNames.length > 0 && !compactCard && (
                              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5, marginTop: 6 }}>
                                {detail.altNames.slice(0, compactCard ? 2 : 4).map((alt) => (
                                  <span
                                    key={alt}
                                    className="ellipsis"
                                    style={{
                                      maxWidth: compactCard ? 220 : 280,
                                      padding: '2px 8px',
                                      borderRadius: 6,
                                      background: KatanaColors.surfaceAlt,
                                      border: `1px solid ${KatanaColors.border}`,
                                      ...KatanaType.small,
                                      fontSize: 11.5,
                                    }}
                                  >
                                    {alt}
                                  </span>
                                ))}
                              </div>
                            )}

                            {detail.genres.length > 0 && (
                              <div
                                style={{
                                  display: 'flex',
                                  flexWrap: 'wrap',
                                  gap: 6,
                                  marginTop: 10,
                                }}
                              >
                                {detail.genres.map((g) => (
                                  <button
                                    key={g.slug}
                                    type="button"
                                    className="bare-button"
                                    onClick={() => handleSelectGenre(g)}
                                    style={{
                                      minHeight: compactCard ? 36 : 44,
                                      padding: compactCard ? '5px 10px' : '6px 12px',
                                      borderRadius: 8,
                                      display: 'inline-flex',
                                      alignItems: 'center',
                                      border: `1px solid ${KatanaColors.borderStrong}`,
                                      background: KatanaColors.surfaceAlt,
                                      ...KatanaType.small,
                                      color: KatanaColors.text,
                                    }}
                                  >
                                    {g.name}
                                  </button>
                                ))}
                              </div>
                            )}
                            </div>

                            <div style={compactCard ? { gridColumn: '1 / -1', minWidth: 0 } : undefined}>
                            {compactCard && detail.summary && (
                              <div style={{ marginTop: 0 }}>
                                <p
                                  className={summaryOpen ? undefined : 'clamp-2'}
                                  style={{ ...KatanaType.body, margin: 0, fontSize: 13, lineHeight: 1.5, color: KatanaColors.textMuted }}
                                >
                                  {detail.summary}
                                </p>
                                <button
                                  type="button"
                                  className="bare-button"
                                  aria-expanded={summaryOpen}
                                  onClick={() => setSummaryOpen((v) => !v)}
                                  style={{
                                    marginTop: -6,
                                    minHeight: 44,
                                    padding: 0,
                                    fontFamily: Fonts.body,
                                    fontSize: 12.5,
                                    fontWeight: 700,
                                    color: KatanaColors.accentSoft,
                                  }}
                                >
                                  {summaryOpen ? 'Show less' : 'Read more'}
                                </button>
                              </div>
                            )}

                            {detail.chapters.length > 0 && (
                              <div style={{ marginTop: 8, maxWidth: 360 }}>
                                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 3 }}>
                                  <span style={KatanaType.small}>Reading progress</span>
                                  <span style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 700 }}>
                                    {readCount} / {detail.chapters.length} ({readPct}%)
                                  </span>
                                </div>
                                <div style={{ height: 5, borderRadius: 99, background: KatanaColors.surfaceAlt, overflow: 'hidden' }}>
                                  <div style={{ width: `${readPct}%`, height: '100%', background: KatanaColors.accent, borderRadius: 99 }} />
                                </div>
                              </div>
                            )}

                            {/* Action bar: primary CTA + clean single-row secondary actions on tablet & desktop */}
                            <div style={{ marginTop: 14, display: 'flex', flexDirection: compactCard ? 'column' : 'row', gap: 8, alignItems: compactCard ? 'stretch' : 'center', flexWrap: compactCard ? 'wrap' : 'nowrap' }}>
                              {detail.chapters.length > 0 && (
                                <KatanaButton
                                  label={hasReadingProgress ? `Continue ${detailBm?.lastReadChapterTitle || ''}`.trim() : 'Start Reading'}
                                  icon="play_arrow"
                                  onClick={() => {
                                    const target = detailBm?.lastReadChapterId || detail.chapters[detail.chapters.length - 1].id;
                                    openChapter(detail, target, detailBm?.lastReadPage || 1);
                                  }}
                                />
                              )}
                              <div
                                ref={detailActionsRef}
                                style={{
                                  display: 'flex',
                                  gap: 6,
                                  alignItems: 'center',
                                  flexWrap: desktop || tablet ? 'wrap' : 'nowrap',
                                  justifyContent: 'flex-start',
                                  rowGap: 6,
                                  position: 'relative',
                                  width: compactCard ? '100%' : undefined,
                                  minWidth: 0,
                                }}
                              >
                                <button
                                  type="button"
                                  className="bare-button"
                                  aria-label={isBookmarked ? 'Remove from Library' : 'Add to Library'}
                                  aria-pressed={isBookmarked}
                                  onClick={() => void setKatanaBookmark(detail, userName, !isBookmarked)}
                                  style={{
                                    flex: compactCard ? '0 0 auto' : undefined,
                                    minWidth: 0,
                                    minHeight: compactCard ? 44 : 40,
                                    padding: compactCard ? '0 12px' : '0 12px',
                                    borderRadius: 8,
                                    background: KatanaColors.surfaceAlt,
                                    border: `1px solid ${isBookmarked ? KatanaColors.chipSelectedBorder : KatanaColors.borderStrong}`,
                                    display: 'inline-flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                    gap: 4,
                                    fontFamily: Fonts.body,
                                    fontSize: compactCard ? 11.5 : 12,
                                    fontWeight: 700,
                                    color: KatanaColors.text,
                                    whiteSpace: 'nowrap',
                                    overflow: 'hidden',
                                  }}
                                >
                                  <Icon name={isBookmarked ? 'bookmark' : 'bookmark_border'} size={14} color={isBookmarked ? KatanaColors.green : KatanaColors.textMuted} />
                                  <span className="ellipsis">{isBookmarked ? 'Saved' : 'Save'}</span>
                                </button>
                                {userName && (
                                  <div style={{ position: 'relative', flex: compactCard ? '1 1 auto' : undefined, minWidth: 0 }}>
                                    <button
                                      type="button"
                                      className="bare-button"
                                      aria-label="Change library shelf status"
                                      aria-expanded={statusMenuOpen}
                                      onClick={() => {
                                        setDetailOverflowOpen(false);
                                        setStatusMenuOpen((v) => !v);
                                      }}
                                      style={{
                                        width: compactCard ? '100%' : undefined,
                                        minWidth: 0,
                                        minHeight: compactCard ? 44 : 40,
                                        padding: compactCard ? '0 10px' : '0 12px',
                                        borderRadius: 8,
                                        background: statusMenuOpen || isBookmarked ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                        border: `1px solid ${statusMenuOpen || isBookmarked ? KatanaColors.chipSelectedBorder : KatanaColors.borderStrong}`,
                                        display: 'inline-flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        gap: 4,
                                        fontFamily: Fonts.body,
                                        fontSize: compactCard ? 12 : 12,
                                        fontWeight: 600,
                                        color: KatanaColors.text,
                                        whiteSpace: 'nowrap',
                                        overflow: 'hidden',
                                      }}
                                    >
                                      {!compactCard && (
                                        <Icon
                                          name={currentStatus ? STATUS_LABELS[currentStatus].icon : 'shelves'}
                                          size={14}
                                          color={currentStatus ? STATUS_LABELS[currentStatus].color : KatanaColors.textMuted}
                                        />
                                      )}
                                      <span className="ellipsis">
                                        {isBookmarked && currentStatus
                                          ? !desktop
                                            ? STATUS_LABELS[currentStatus].label
                                            : `${STATUS_LABELS[currentStatus].label}`
                                          : 'Shelf'}
                                      </span>
                                      <Icon name="expand_more" size={14} color={KatanaColors.textMuted} />
                                    </button>
                                    {statusMenuOpen && (
                                      <div
                                        role="menu"
                                        style={{
                                          position: 'absolute',
                                          left: 0,
                                          top: 40,
                                          minWidth: 170,
                                          borderRadius: 10,
                                          background: KatanaColors.surfaceGlow,
                                          border: `1px solid ${KatanaColors.borderStrong}`,
                                          boxShadow: '0 10px 28px rgba(0,0,0,0.55)',
                                          padding: 6,
                                          zIndex: 26,
                                          display: 'flex',
                                          flexDirection: 'column',
                                          gap: 2,
                                        }}
                                      >
                                        {(['reading', 'on_hold', 'completed', 'planned', 'dropped'] as const).map((st) => {
                                          const meta = STATUS_LABELS[st];
                                          const active = isBookmarked && currentStatus === st;
                                          return (
                                            <button
                                              key={st}
                                              type="button"
                                              role="menuitemradio"
                                              aria-checked={active}
                                              className="bare-button"
                                              onClick={() => {
                                                setStatusMenuOpen(false);
                                                void setKatanaLibraryStatus(detail, userName, st);
                                                showSnackBar(`Moved to ${meta.label}`);
                                              }}
                                              style={{
                                                display: 'flex',
                                                alignItems: 'center',
                                                gap: 8,
                                                padding: '8px 10px',
                                                borderRadius: 7,
                                                background: active ? KatanaColors.chipSelectedBg : 'transparent',
                                                color: active ? KatanaColors.chipSelectedText : KatanaColors.text,
                                                fontFamily: Fonts.body,
                                                fontSize: 12.5,
                                                fontWeight: active ? 700 : 500,
                                                textAlign: 'left',
                                              }}
                                            >
                                              <Icon name={meta.icon} size={15} color={meta.color} />
                                              <span style={{ flex: 1 }}>{meta.label}</span>
                                              {active && <Icon name="check" size={15} color={KatanaColors.accent} />}
                                            </button>
                                          );
                                        })}
                                        {customCategories.length > 0 && (
                                          <>
                                            <div style={{ height: 1, background: KatanaColors.border, margin: '4px 6px' }} />
                                            <div style={{ padding: '3px 10px', ...KatanaType.small, fontSize: 11, fontWeight: 700 }}>Categories</div>
                                            {customCategories.map((cat) => {
                                              const curCats = detailBm?.categories ?? [];
                                              const inCat = curCats.includes(cat);
                                              return (
                                                <button
                                                  key={cat}
                                                  type="button"
                                                  role="menuitemcheckbox"
                                                  aria-checked={inCat}
                                                  className="bare-button"
                                                  onClick={() => {
                                                    const nextCats = inCat ? curCats.filter((c) => c !== cat) : [...curCats, cat];
                                                    void setKatanaBookmarkCategories(detail, userName, nextCats);
                                                    showSnackBar(inCat ? `Removed from ${cat}` : `Added to ${cat}`);
                                                  }}
                                                  style={{
                                                    display: 'flex',
                                                    alignItems: 'center',
                                                    gap: 8,
                                                    padding: '7px 10px',
                                                    borderRadius: 7,
                                                    background: inCat ? KatanaColors.chipSelectedBg : 'transparent',
                                                    color: inCat ? KatanaColors.chipSelectedText : KatanaColors.text,
                                                    fontFamily: Fonts.body,
                                                    fontSize: 12.5,
                                                    fontWeight: inCat ? 700 : 500,
                                                    textAlign: 'left',
                                                  }}
                                                >
                                                  <Icon name={inCat ? 'check_box' : 'check_box_outline_blank'} size={15} color={inCat ? KatanaColors.accent : KatanaColors.textLight} />
                                                  <span style={{ flex: 1 }}>{cat}</span>
                                                </button>
                                              );
                                            })}
                                          </>
                                        )}
                                      </div>
                                    )}
                                  </div>
                                )}
                                {desktop && detail.chapters.length > 0 && (
                                  <button
                                    type="button"
                                    className="bare-button"
                                    aria-label="Download next 3 unread chapters"
                                    title="Download next 3 unread chapters"
                                    disabled={batchProgress != null}
                                    onClick={() => void downloadNextUnread(detail, readSet, 3)}
                                    style={{
                                      height: 40,
                                      padding: '0 12px',
                                      borderRadius: 8,
                                      background: KatanaColors.surfaceAlt,
                                      border: `1px solid ${KatanaColors.borderStrong}`,
                                      display: 'inline-flex',
                                      alignItems: 'center',
                                      justifyContent: 'center',
                                      gap: 5,
                                      fontFamily: Fonts.body,
                                      fontSize: 12.5,
                                      fontWeight: 600,
                                      color: KatanaColors.accentSoft,
                                      flexShrink: 0,
                                      opacity: batchProgress != null ? 0.6 : 1,
                                    }}
                                  >
                                    <Icon name="download" size={16} color={KatanaColors.accent} />
                                    <span>{batchProgress ? `Downloading ${batchProgress.done} of ${batchProgress.total}` : 'Download 3 chapters'}</span>
                                  </button>
                                )}
                                {desktop && userName && (
                                  <button
                                    type="button"
                                    className="bare-button"
                                    aria-label={alertsEnabled ? 'Mute new chapter alerts' : 'Enable new chapter alerts'}
                                    aria-pressed={alertsEnabled}
                                    title={alertsEnabled ? 'Chapter alerts: On (tap to mute)' : 'Chapter alerts: Off (tap to enable)'}
                                    onClick={() => void toggleSeriesAlerts(detail, alertsEnabled)}
                                    style={{
                                      width: 38,
                                      height: 44,
                                      borderRadius: 8,
                                      background: alertsEnabled && isBookmarked ? withAlpha(KatanaColors.accent, 0.16) : KatanaColors.surfaceAlt,
                                      border: `1px solid ${alertsEnabled && isBookmarked ? withAlpha(KatanaColors.accent, 0.5) : KatanaColors.borderStrong}`,
                                      display: 'grid',
                                      placeItems: 'center',
                                    }}
                                  >
                                    <Icon
                                      name={alertsEnabled ? 'notifications_active' : 'notifications_off'}
                                      size={17}
                                      color={alertsEnabled && isBookmarked ? KatanaColors.accent : KatanaColors.textMuted}
                                    />
                                  </button>
                                )}
                                {desktop && (
                                  <button
                                    type="button"
                                    className="bare-button"
                                    aria-label="Share series link"
                                    title="Copy series link"
                                    onClick={() => void shareSeriesLink(detail)}
                                    style={{
                                      width: 38,
                                      height: 44,
                                      borderRadius: 8,
                                      background: KatanaColors.surfaceAlt,
                                      border: `1px solid ${KatanaColors.borderStrong}`,
                                      display: 'grid',
                                      placeItems: 'center',
                                    }}
                                  >
                                    <Icon name="share" size={17} color={KatanaColors.textMuted} />
                                  </button>
                                )}
                                {!compactCard && userName && (
                                  <button
                                    type="button"
                                    className="bare-button"
                                    aria-label="Open personal tracker and rating"
                                    aria-expanded={trackerOpen}
                                    onClick={() => {
                                      setDetailOverflowOpen(false);
                                      setStatusMenuOpen(false);
                                      if (!trackerOpen) {
                                        setTrackerAnilistDraft(detailBm?.anilistId ?? '');
                                        setTrackerKitsuDraft(detailBm?.kitsuId ?? '');
                                        setTrackerMalDraft(detailBm?.malId ?? '');
                                        setTrackerNoteDraft(detailBm?.trackerNote ?? '');
                                      }
                                      setTrackerOpen((v) => !v);
                                    }}
                                    style={{
                                      minHeight: 44,
                                      padding: '0 12px',
                                      borderRadius: 8,
                                      background: trackerOpen || detailBm?.userScore ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                      border: `1px solid ${trackerOpen || detailBm?.userScore ? KatanaColors.chipSelectedBorder : KatanaColors.borderStrong}`,
                                      display: 'inline-flex',
                                      alignItems: 'center',
                                      gap: 5,
                                      fontFamily: Fonts.body,
                                      fontSize: 12.5,
                                      fontWeight: 700,
                                      color: detailBm?.userScore ? KatanaColors.accentSoft : KatanaColors.text,
                                    }}
                                  >
                                    <Icon name={detailBm?.userScore ? 'star' : 'tune'} size={16} color={detailBm?.userScore ? KatanaColors.accent : KatanaColors.textMuted} />
                                    <span>{detailBm?.userScore ? (desktop ? `Your ${detailBm.userScore}/10` : `${detailBm.userScore}/10`) : 'Track'}</span>
                                  </button>
                                )}
                                <div style={{ position: 'relative' }}>
                                  <button
                                    type="button"
                                    className="bare-button"
                                    aria-label="More series actions"
                                    aria-expanded={detailOverflowOpen}
                                    onClick={() => {
                                      setStatusMenuOpen(false);
                                      setDetailOverflowOpen((v) => !v);
                                    }}
                                    style={{
                                      width: compactCard ? 44 : 40,
                                      height: compactCard ? 44 : 40,
                                      borderRadius: 8,
                                      background: detailOverflowOpen ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                      border: `1px solid ${KatanaColors.borderStrong}`,
                                      display: 'grid',
                                      placeItems: 'center',
                                      flexShrink: 0,
                                    }}
                                  >
                                    <Icon name="more_horiz" size={18} color={KatanaColors.textMuted} />
                                  </button>
                                  {detailOverflowOpen && (
                                    <div
                                      style={{
                                        position: 'absolute',
                                        right: 0,
                                        top: 46,
                                        minWidth: 230,
                                        borderRadius: 10,
                                        background: KatanaColors.surfaceGlow,
                                        border: `1px solid ${KatanaColors.borderStrong}`,
                                        boxShadow: '0 10px 28px rgba(0,0,0,0.55)',
                                        padding: 6,
                                        zIndex: 25,
                                        display: 'flex',
                                        flexDirection: 'column',
                                        gap: 4,
                                      }}
                                    >
                                      {compactCard && userName && (
                                        <button
                                          type="button"
                                          className="bare-button"
                                          onClick={() => {
                                            setDetailOverflowOpen(false);
                                            setTrackerAnilistDraft(detailBm?.anilistId ?? '');
                                            setTrackerKitsuDraft(detailBm?.kitsuId ?? '');
                                            setTrackerMalDraft(detailBm?.malId ?? '');
                                            setTrackerNoteDraft(detailBm?.trackerNote ?? '');
                                            setTrackerOpen((v) => !v);
                                          }}
                                          style={{
                                            display: 'flex',
                                            alignItems: 'center',
                                            gap: 8,
                                            padding: '10px 10px',
                                            borderRadius: 7,
                                            color: KatanaColors.text,
                                            fontFamily: Fonts.body,
                                            fontSize: 13,
                                            fontWeight: 600,
                                            textAlign: 'left',
                                          }}
                                        >
                                          <Icon name={detailBm?.userScore ? 'star' : 'tune'} size={16} color={KatanaColors.accent} />
                                          <span>{detailBm?.userScore ? `Tracker (${detailBm.userScore}/10)` : 'Personal tracker & rating'}</span>
                                        </button>
                                      )}
                                      {!desktop && !compactCard && detail.chapters.length > 0 && (
                                        <button
                                          type="button"
                                          className="bare-button"
                                          disabled={batchProgress != null}
                                          onClick={() => {
                                            setDetailOverflowOpen(false);
                                            void downloadNextUnread(detail, readSet, 3);
                                          }}
                                          style={{
                                            display: 'flex',
                                            alignItems: 'center',
                                            gap: 8,
                                            minHeight: 44,
                                            padding: '9px 10px',
                                            borderRadius: 7,
                                            color: KatanaColors.text,
                                            fontFamily: Fonts.body,
                                            fontSize: 13,
                                            fontWeight: 600,
                                            textAlign: 'left',
                                          }}
                                        >
                                          <Icon name="download" size={16} color={KatanaColors.accent} />
                                          <span>
                                            {batchProgress
                                              ? `Saving ${batchProgress.done}/${batchProgress.total}`
                                              : `Download next 3 (${estimateMangaBatchMegabytes(Math.min(3, Math.max(1, unreadCount)), false, offline.mangaItems).label})`}
                                          </span>
                                        </button>
                                      )}
                                      {detail.chapters.length > 0 && (
                                        <button
                                          type="button"
                                          className="bare-button"
                                          disabled={batchProgress != null}
                                          onClick={() => {
                                            setDetailOverflowOpen(false);
                                            void downloadAllUnread(detail, readSet);
                                          }}
                                          style={{
                                            display: 'flex',
                                            alignItems: 'center',
                                            gap: 8,
                                            minHeight: 44,
                                            padding: '9px 10px',
                                            borderRadius: 7,
                                            color: KatanaColors.text,
                                            fontFamily: Fonts.body,
                                            fontSize: 13,
                                            fontWeight: 600,
                                            textAlign: 'left',
                                          }}
                                        >
                                          <Icon name="download_for_offline" size={16} color={KatanaColors.accent} />
                                          <span>
                                            Download all unread (
                                            {unreadCount > 0
                                              ? estimateMangaBatchMegabytes(unreadCount, false, offline.mangaItems).label
                                              : '~0 MB'}
                                            )
                                          </span>
                                        </button>
                                      )}
                                      {!desktop && !compactCard && userName && (
                                        <button
                                          type="button"
                                          className="bare-button"
                                          onClick={() => {
                                            setDetailOverflowOpen(false);
                                            void toggleSeriesAlerts(detail, alertsEnabled);
                                          }}
                                          style={{
                                            display: 'flex',
                                            alignItems: 'center',
                                            gap: 8,
                                            padding: '9px 10px',
                                            borderRadius: 7,
                                            color: KatanaColors.text,
                                            fontFamily: Fonts.body,
                                            fontSize: 13,
                                            fontWeight: 600,
                                            textAlign: 'left',
                                          }}
                                        >
                                          <Icon
                                            name={alertsEnabled ? 'notifications_active' : 'notifications_off'}
                                            size={16}
                                            color={alertsEnabled && isBookmarked ? KatanaColors.accent : KatanaColors.textMuted}
                                          />
                                          <span>{alertsEnabled ? 'Mute chapter alerts' : 'Enable chapter alerts'}</span>
                                        </button>
                                      )}
                                      {!desktop && (
                                        <button
                                          type="button"
                                          className="bare-button"
                                          onClick={() => {
                                            setDetailOverflowOpen(false);
                                            void shareSeriesLink(detail);
                                          }}
                                          style={{
                                            display: 'flex',
                                            alignItems: 'center',
                                            gap: 8,
                                            padding: '10px 10px',
                                            borderRadius: 7,
                                            color: KatanaColors.text,
                                            fontFamily: Fonts.body,
                                            fontSize: 13,
                                            fontWeight: 600,
                                            textAlign: 'left',
                                          }}
                                        >
                                          <Icon name="share" size={16} color={KatanaColors.textMuted} />
                                          <span>Copy series link</span>
                                        </button>
                                      )}
                                      {unreadCount > 0 && (
                                        <button
                                          type="button"
                                          className="bare-button"
                                          onClick={() => {
                                            setDetailOverflowOpen(false);
                                            void downloadNextUnread(detail, readSet, unreadCount);
                                          }}
                                          style={{
                                            display: 'flex',
                                            alignItems: 'center',
                                            gap: 8,
                                            padding: '8px 10px',
                                            borderRadius: 7,
                                            color: KatanaColors.text,
                                            fontFamily: Fonts.body,
                                            fontSize: 12.5,
                                            fontWeight: 600,
                                            textAlign: 'left',
                                          }}
                                        >
                                          <Icon name="downloading" size={16} color={KatanaColors.accent} />
                                          <span>Download all unread ({unreadCount})</span>
                                        </button>
                                      )}
                                      <a
                                        href={
                                          detailBm?.anilistId
                                            ? `https://anilist.co/manga/${encodeURIComponent(detailBm.anilistId)}`
                                            : `https://anilist.co/search/manga?search=${encodeURIComponent(detail.title)}`
                                        }
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        onClick={() => setDetailOverflowOpen(false)}
                                        style={{
                                          display: 'flex',
                                          alignItems: 'center',
                                          gap: 8,
                                          padding: '8px 10px',
                                          borderRadius: 7,
                                          color: KatanaColors.text,
                                          fontFamily: Fonts.body,
                                          fontSize: 12.5,
                                          fontWeight: 600,
                                          textDecoration: 'none',
                                        }}
                                      >
                                        <Icon name="open_in_new" size={16} color={KatanaColors.link} />
                                        <span>{detailBm?.anilistId ? `Open on AniList (#${detailBm.anilistId})` : 'Find on AniList'}</span>
                                      </a>
                                      <a
                                        href={
                                          detailBm?.malId
                                            ? `https://myanimelist.net/manga/${encodeURIComponent(detailBm.malId)}`
                                            : `https://myanimelist.net/manga.php?q=${encodeURIComponent(detail.title)}`
                                        }
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        onClick={() => setDetailOverflowOpen(false)}
                                        style={{
                                          display: 'flex',
                                          alignItems: 'center',
                                          gap: 8,
                                          padding: '8px 10px',
                                          borderRadius: 7,
                                          color: KatanaColors.text,
                                          fontFamily: Fonts.body,
                                          fontSize: 12.5,
                                          fontWeight: 600,
                                          textDecoration: 'none',
                                        }}
                                      >
                                        <Icon name="open_in_new" size={16} color={KatanaColors.link} />
                                        <span>{detailBm?.malId ? `Open on MAL (#${detailBm.malId})` : 'Find on MyAnimeList'}</span>
                                      </a>
                                      {userName && (
                                        <button
                                          type="button"
                                          className="bare-button"
                                          onClick={() => {
                                            setDetailOverflowOpen(false);
                                            void openMigrationPicker(detail);
                                          }}
                                          style={{
                                            display: 'flex',
                                            alignItems: 'center',
                                            gap: 8,
                                            padding: '8px 10px',
                                            borderRadius: 7,
                                            color: KatanaColors.text,
                                            fontFamily: Fonts.body,
                                            fontSize: 12.5,
                                            fontWeight: 600,
                                            textAlign: 'left',
                                          }}
                                        >
                                          <Icon name="swap_horiz" size={16} color={KatanaColors.teal} />
                                          <span>Migrate Catalog Source</span>
                                        </button>
                                      )}
                                      {hasReadingProgress && (
                                        <button
                                          type="button"
                                          className="bare-button"
                                          onClick={() => {
                                            setDetailOverflowOpen(false);
                                            confirmResetProgress(detail.slug, detail.title);
                                          }}
                                          style={{
                                            display: 'flex',
                                            alignItems: 'center',
                                            gap: 8,
                                            padding: '8px 10px',
                                            borderRadius: 7,
                                            color: KatanaColors.crimson,
                                            fontFamily: Fonts.body,
                                            fontSize: 12.5,
                                            fontWeight: 600,
                                            textAlign: 'left',
                                          }}
                                        >
                                          <Icon name="restart_alt" size={16} color={KatanaColors.crimson} />
                                          <span>Reset Progress</span>
                                        </button>
                                      )}
                                    </div>
                                  )}
                                </div>
                              </div>
                              {compactCard && (detail.chapters.length > 0 || userName) && (
                                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6, flexWrap: 'wrap' }}>
                                  {detail.chapters.length > 0 && (
                                    <button
                                      type="button"
                                      className="bare-button"
                                      aria-label="Download next 3 unread chapters"
                                      disabled={batchProgress != null}
                                      onClick={() => void downloadNextUnread(detail, readSet, 3)}
                                      style={{
                                        flex: 1,
                                        minHeight: 44,
                                        padding: '0 10px',
                                        borderRadius: 8,
                                        background: KatanaColors.surfaceAlt,
                                        border: `1px solid ${KatanaColors.borderStrong}`,
                                        display: 'inline-flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        gap: 5,
                                        fontFamily: Fonts.body,
                                        fontSize: 12,
                                        fontWeight: 600,
                                        color: KatanaColors.text,
                                        whiteSpace: 'nowrap',
                                        opacity: batchProgress != null ? 0.6 : 1,
                                      }}
                                    >
                                      <Icon name="download" size={15} color={KatanaColors.accent} />
                                      <span>{batchProgress ? `${batchProgress.done} of ${batchProgress.total}` : 'Download'}</span>
                                    </button>
                                  )}
                                  {userName && (
                                    <button
                                      type="button"
                                      className="bare-button"
                                      aria-label={alertsEnabled ? 'Mute new chapter alerts' : 'Enable new chapter alerts'}
                                      aria-pressed={alertsEnabled}
                                      onClick={() => void toggleSeriesAlerts(detail, alertsEnabled)}
                                      style={{
                                        flex: 1,
                                        minHeight: 44,
                                        padding: '0 10px',
                                        borderRadius: 8,
                                        background: KatanaColors.surfaceAlt,
                                        border: `1px solid ${alertsEnabled && isBookmarked ? KatanaColors.chipSelectedBorder : KatanaColors.borderStrong}`,
                                        display: 'inline-flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        gap: 5,
                                        fontFamily: Fonts.body,
                                        fontSize: 12,
                                        fontWeight: 600,
                                        color: KatanaColors.text,
                                        whiteSpace: 'nowrap',
                                      }}
                                    >
                                      <Icon
                                        name={alertsEnabled ? 'notifications_active' : 'notifications_off'}
                                        size={15}
                                        color={alertsEnabled && isBookmarked ? KatanaColors.accent : KatanaColors.textMuted}
                                      />
                                      <span>{alertsEnabled ? 'Alerts On' : 'Alerts Off'}</span>
                                    </button>
                                  )}
                                </div>
                              )}
                            </div>
                            </div>
                          </div>

                          {desktop && (
                            <div
                              style={{
                                flex: '0 0 42%',
                                maxWidth: 480,
                                minWidth: 320,
                                borderLeft: `1px solid ${KatanaColors.border}`,
                                paddingLeft: 22,
                                alignSelf: 'stretch',
                                display: 'flex',
                                flexDirection: 'column',
                                gap: 12,
                              }}
                            >
                              <div
                                style={{
                                  display: 'grid',
                                  gridTemplateColumns: 'repeat(3, minmax(0, 1fr))',
                                  gap: 8,
                                }}
                              >
                                <div
                                  style={{
                                    padding: '8px 10px',
                                    borderRadius: 10,
                                    background: KatanaColors.surfaceAlt,
                                    border: `1px solid ${KatanaColors.border}`,
                                  }}
                                >
                                  <div style={{ ...KatanaType.small, fontSize: 10.5, color: KatanaColors.textMuted }}>CHAPTERS</div>
                                  <div style={{ ...KatanaType.title, fontSize: 16, marginTop: 2 }}>{detail.chapters.length}</div>
                                </div>
                                <div
                                  style={{
                                    padding: '8px 10px',
                                    borderRadius: 10,
                                    background: KatanaColors.surfaceAlt,
                                    border: `1px solid ${KatanaColors.border}`,
                                  }}
                                >
                                  <div style={{ ...KatanaType.small, fontSize: 10.5, color: KatanaColors.textMuted }}>PROGRESS</div>
                                  <div style={{ ...KatanaType.title, fontSize: 16, marginTop: 2, color: readCount > 0 ? KatanaColors.accent : KatanaColors.text }}>
                                    {detail.chapters.length > 0 ? `${Math.round((readCount / detail.chapters.length) * 100)}%` : '0%'}
                                  </div>
                                </div>
                                <div
                                  style={{
                                    padding: '8px 10px',
                                    borderRadius: 10,
                                    background: KatanaColors.surfaceAlt,
                                    border: `1px solid ${KatanaColors.border}`,
                                  }}
                                >
                                  <div style={{ ...KatanaType.small, fontSize: 10.5, color: KatanaColors.textMuted }}>UNREAD</div>
                                  <div style={{ ...KatanaType.title, fontSize: 16, marginTop: 2, color: unreadCount > 0 ? KatanaColors.link : KatanaColors.text }}>
                                    {unreadCount}
                                  </div>
                                </div>
                              </div>
                              {detail.summary && (
                                <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                                  <div style={{ ...KatanaType.title, fontSize: 13, color: KatanaColors.textMuted, letterSpacing: 0.4 }}>
                                    SYNOPSIS
                                  </div>
                                  <p style={{ ...KatanaType.body, margin: 0, fontSize: 13.5, lineHeight: 1.58 }}>{detail.summary}</p>
                                </div>
                              )}
                            </div>
                          )}
                        </div>

                        {tablet && !desktop && detail.summary && (
                          <div style={{ marginTop: 12, paddingTop: 10, borderTop: `1px solid ${KatanaColors.border}` }}>
                            <p
                              className={summaryOpen ? undefined : 'clamp-2'}
                              style={{ ...KatanaType.body, margin: 0, fontSize: 13, lineHeight: 1.5, color: KatanaColors.textMuted }}
                            >
                              {detail.summary}
                            </p>
                            <button
                              type="button"
                              className="bare-button"
                              aria-expanded={summaryOpen}
                              onClick={() => setSummaryOpen((v) => !v)}
                              style={{
                                marginTop: -4,
                                minHeight: 44,
                                padding: 0,
                                fontFamily: Fonts.body,
                                fontSize: 12.5,
                                fontWeight: 700,
                                color: KatanaColors.accentSoft,
                              }}
                            >
                              {summaryOpen ? 'Show less' : 'Read more'}
                            </button>
                          </div>
                        )}


                      <div style={{ height: 14 }} />

                      <div
                        style={{
                          display: tablet ? 'flex' : 'block',
                          alignItems: 'flex-start',
                          gap: desktop ? 18 : 14,
                        }}
                      >
                        <div style={{ flex: 1, minWidth: 0, maxWidth: desktop ? 860 : undefined }}>
                          <KatanaCard padding={16}>
                            {batchProgress && (
                              <div
                                role="status"
                                aria-live="polite"
                                style={{
                                  marginBottom: 12,
                                  padding: '10px 12px',
                                  borderRadius: 10,
                                  background: withAlpha(KatanaColors.link, 0.1),
                                  border: `1px solid ${withAlpha(KatanaColors.link, 0.35)}`,
                                }}
                              >
                                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginBottom: 6 }}>
                                  <span className="ellipsis" style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontFamily: Fonts.body, fontSize: 12.5, fontWeight: 700, color: KatanaColors.text }}>
                                    <Icon name="downloading" size={16} color={KatanaColors.accent} />
                                    {batchProgress.currentTitle ? `Saving ${batchProgress.currentTitle}…` : 'Downloading chapters…'}
                                  </span>
                                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
                                    <span style={{ ...KatanaType.small, color: KatanaColors.link, fontWeight: 700 }}>
                                      {batchProgress.done} / {batchProgress.total}
                                    </span>
                                    <button
                                      type="button"
                                      className="bare-button"
                                      onClick={cancelDownloadQueue}
                                      style={{
                                        minHeight: 44,
                                        padding: '0 12px',
                                        borderRadius: 8,
                                        background: withAlpha(KatanaColors.crimson, 0.14),
                                        border: `1px solid ${withAlpha(KatanaColors.crimson, 0.4)}`,
                                        fontFamily: Fonts.body,
                                        fontSize: 12,
                                        fontWeight: 700,
                                        color: KatanaColors.crimson,
                                      }}
                                    >
                                      Cancel
                                    </button>
                                  </div>
                                </div>
                                <div style={{ height: 5, borderRadius: 99, background: KatanaColors.surfaceAlt, overflow: 'hidden' }}>
                                  <div
                                    style={{
                                      width: `${Math.round((batchProgress.done / Math.max(1, batchProgress.total)) * 100)}%`,
                                      height: '100%',
                                      background: KatanaColors.link,
                                      borderRadius: 99,
                                      transition: 'width 180ms ease',
                                    }}
                                  />
                                </div>
                              </div>
                            )}
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' }}>
                          <KatanaSectionHeader
                            title="Chapters"
                            badge={`${detail.chapters.length} ${detail.chapters.length === 1 ? 'chapter' : 'chapters'}`}
                          />
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                            {chapterToolsOpen && (
                              <button
                                type="button"
                                className="bare-button"
                                onClick={() => void handleLoadPreview(detail)}
                                aria-expanded={previewPages?.slug === detail.slug}
                                style={{
                                  minHeight: 44,
                                  padding: '6px 12px',
                                  borderRadius: 8,
                                  background: previewPages?.slug === detail.slug ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                  border: `1px solid ${previewPages?.slug === detail.slug ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  gap: 5,
                                  fontFamily: Fonts.body,
                                  fontSize: 12.5,
                                  fontWeight: 600,
                                  color: previewPages?.slug === detail.slug ? KatanaColors.chipSelectedText : KatanaColors.text,
                                }}
                              >
                                <Icon name="visibility" size={14} color={KatanaColors.accent} />
                                <span>
                                  {previewLoading
                                    ? 'Loading…'
                                    : previewPages?.slug === detail.slug
                                      ? 'Hide Preview'
                                      : 'Preview Pages'}
                                </span>
                              </button>
                            )}
                            {detailBm?.lastReadChapterId && (
                              <button
                                type="button"
                                className="bare-button"
                                onClick={() => {
                                  const targetId = detailBm.lastReadChapterId;
                                  const idx = filteredChapters.findIndex((ch) => ch.id === targetId);
                                  if (idx >= 0 && idx >= chapterWindow) {
                                    setChapterWindow(idx + 15);
                                  }
                                  window.setTimeout(() => {
                                    const el = document.querySelector(`[data-chapter-id="${CSS.escape(targetId)}"]`);
                                    el?.scrollIntoView({ behavior: 'smooth', block: 'center' });
                                  }, 60);
                                }}
                                style={{
                                  minHeight: 44,
                                  padding: '6px 10px',
                                  borderRadius: 8,
                                  background: withAlpha(KatanaColors.accent, 0.14),
                                  border: `1px solid ${withAlpha(KatanaColors.accent, 0.45)}`,
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  gap: 5,
                                  fontFamily: Fonts.body,
                                  fontSize: 12.5,
                                  fontWeight: 700,
                                  color: KatanaColors.accentSoft,
                                }}
                              >
                                <Icon name="my_location" size={14} color={KatanaColors.accent} />
                                <span>{compactCard ? 'Last read' : `Jump to ${detailBm.lastReadChapterTitle || 'last read'}`}</span>
                              </button>
                            )}
                            <button
                              type="button"
                              className="bare-button"
                              onClick={() => setChapterSortAsc((v) => !v)}
                              style={{
                                minHeight: 44,
                                padding: '6px 10px',
                                borderRadius: 8,
                                background: KatanaColors.surfaceAlt,
                                border: `1px solid ${KatanaColors.border}`,
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: 5,
                                fontFamily: Fonts.body,
                                fontSize: 12.5,
                                fontWeight: 600,
                                color: KatanaColors.text,
                              }}
                            >
                              <Icon name="swap_vert" size={15} color={KatanaColors.textMuted} />
                              <span>{chapterSortAsc ? 'Oldest' : 'Newest'}</span>
                            </button>
                            {detail.chapters.length > 0 && (
                              <button
                                type="button"
                                className="bare-button"
                                aria-expanded={chapterToolsOpen}
                                onClick={() => setChapterToolsOpen((v) => !v)}
                                style={{
                                  minHeight: 44,
                                  padding: '6px 10px',
                                  borderRadius: 8,
                                  background: chapterToolsOpen || selectMode || chapterGrouped || activeChapterFilterCount > 0 ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                  border: `1px solid ${chapterToolsOpen || selectMode || chapterGrouped || activeChapterFilterCount > 0 ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  gap: 4,
                                  fontFamily: Fonts.body,
                                  fontSize: 12.5,
                                  fontWeight: 600,
                                  color: chapterToolsOpen || selectMode || chapterGrouped || activeChapterFilterCount > 0 ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                                }}
                              >
                                <Icon name="tune" size={15} color={chapterToolsOpen || selectMode || chapterGrouped || activeChapterFilterCount > 0 ? KatanaColors.accentSoft : KatanaColors.textMuted} />
                                <span>{activeChapterFilterCount > 0 ? `Tools (${activeChapterFilterCount})` : 'Tools'}</span>
                              </button>
                            )}
                            {chapterToolsOpen && detail.chapters.length >= 10 && (
                              <button
                                type="button"
                                className="bare-button"
                                aria-pressed={chapterGrouped}
                                onClick={() => setChapterGrouped((v) => !v)}
                                style={{
                                  padding: '6px 10px',
                                  borderRadius: 8,
                                  background: chapterGrouped ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                  border: `1px solid ${chapterGrouped ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  gap: 5,
                                  fontFamily: Fonts.body,
                                  fontSize: 12.5,
                                  fontWeight: 600,
                                  color: chapterGrouped ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                                }}
                              >
                                <Icon name="folder_open" size={15} color={chapterGrouped ? KatanaColors.accentSoft : KatanaColors.textMuted} />
                                <span>Volumes</span>
                              </button>
                            )}
                            {chapterToolsOpen && (
                              <button
                                type="button"
                                className="bare-button"
                                onClick={() => {
                                  setSelectMode((v) => !v);
                                  setSelectedChapterIds(new Set());
                                }}
                                style={{
                                  padding: '6px 10px',
                                  borderRadius: 8,
                                  background: selectMode ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                  border: `1px solid ${selectMode ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  gap: 5,
                                  fontFamily: Fonts.body,
                                  fontSize: 12.5,
                                  fontWeight: 600,
                                  color: selectMode ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                                }}
                              >
                                <Icon name="checklist" size={15} color={selectMode ? KatanaColors.accentSoft : KatanaColors.textMuted} />
                                <span>{selectMode ? 'Done' : 'Select'}</span>
                              </button>
                            )}
                            {chapterToolsOpen && userName && detail.chapters.length > 0 && !selectMode && (
                              <button
                                type="button"
                                className="bare-button"
                                onClick={() => {
                                  const allRead = readCount === detail.chapters.length;
                                  void markKatanaChaptersRead(
                                    detail,
                                    userName,
                                    detail.chapters.map((c) => c.id),
                                    !allRead,
                                  );
                                  showSnackBar(allRead ? 'Marked all chapters unread' : 'Marked all chapters read');
                                }}
                                style={{
                                  padding: '6px 10px',
                                  borderRadius: 8,
                                  background: KatanaColors.surfaceAlt,
                                  border: `1px solid ${KatanaColors.border}`,
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  gap: 5,
                                  fontFamily: Fonts.body,
                                  fontSize: 12.5,
                                  fontWeight: 600,
                                  color: KatanaColors.textMuted,
                                }}
                              >
                                <Icon name="done_all" size={15} color={KatanaColors.green} />
                                <span>{readCount === detail.chapters.length ? 'Mark all unread' : 'Mark all read'}</span>
                              </button>
                            )}
                          </div>
                        </div>

                        {compactCard && chapterToolsOpen && detail.chapters.length > 0 && (
                          <div
                            style={{
                              marginTop: 8,
                              padding: '8px 10px',
                              borderRadius: 10,
                              background: KatanaColors.surfaceAlt,
                              border: `1px solid ${KatanaColors.border}`,
                              display: 'flex',
                              alignItems: 'center',
                              gap: 6,
                              flexWrap: 'wrap',
                            }}
                          >
                            <button
                              type="button"
                              className="bare-button"
                              onClick={() => void handleLoadPreview(detail)}
                              aria-expanded={previewPages?.slug === detail.slug}
                              style={{
                                minHeight: 44,
                                padding: '5px 10px',
                                borderRadius: 8,
                                background: previewPages?.slug === detail.slug ? KatanaColors.chipSelectedBg : KatanaColors.surface,
                                border: `1px solid ${previewPages?.slug === detail.slug ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: 5,
                                fontFamily: Fonts.body,
                                fontSize: 12,
                                fontWeight: 600,
                                color: previewPages?.slug === detail.slug ? KatanaColors.chipSelectedText : KatanaColors.text,
                              }}
                            >
                              <Icon name="visibility" size={14} color={KatanaColors.accent} />
                              <span>{previewLoading ? 'Loading…' : previewPages?.slug === detail.slug ? 'Hide Preview' : 'Preview'}</span>
                            </button>
                            {detail.chapters.length >= 10 && (
                              <button
                                type="button"
                                className="bare-button"
                                aria-pressed={chapterGrouped}
                                onClick={() => setChapterGrouped((v) => !v)}
                                style={{
                                  minHeight: 44,
                                  padding: '5px 10px',
                                  borderRadius: 8,
                                  background: chapterGrouped ? KatanaColors.chipSelectedBg : KatanaColors.surface,
                                  border: `1px solid ${chapterGrouped ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  gap: 5,
                                  fontFamily: Fonts.body,
                                  fontSize: 12,
                                  fontWeight: 600,
                                  color: chapterGrouped ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                                }}
                              >
                                <Icon name="folder_open" size={14} color={chapterGrouped ? KatanaColors.accentSoft : KatanaColors.textMuted} />
                                <span>Volumes</span>
                              </button>
                            )}
                            <button
                              type="button"
                              className="bare-button"
                              onClick={() => {
                                setSelectMode((v) => !v);
                                setSelectedChapterIds(new Set());
                              }}
                              style={{
                                minHeight: 44,
                                padding: '5px 10px',
                                borderRadius: 8,
                                background: selectMode ? KatanaColors.chipSelectedBg : KatanaColors.surface,
                                border: `1px solid ${selectMode ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: 5,
                                fontFamily: Fonts.body,
                                fontSize: 12,
                                fontWeight: 600,
                                color: selectMode ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                              }}
                            >
                              <Icon name="checklist" size={14} color={selectMode ? KatanaColors.accentSoft : KatanaColors.textMuted} />
                              <span>{selectMode ? 'Done' : 'Select'}</span>
                            </button>
                            {userName && !selectMode && (
                              <button
                                type="button"
                                className="bare-button"
                                onClick={() => {
                                  const allRead = readCount === detail.chapters.length;
                                  void markKatanaChaptersRead(
                                    detail,
                                    userName,
                                    detail.chapters.map((c) => c.id),
                                    !allRead,
                                  );
                                  showSnackBar(allRead ? 'Marked all chapters unread' : 'Marked all chapters read');
                                }}
                                style={{
                                  minHeight: 44,
                                  padding: '5px 10px',
                                  borderRadius: 8,
                                  background: KatanaColors.surface,
                                  border: `1px solid ${KatanaColors.border}`,
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  gap: 5,
                                  fontFamily: Fonts.body,
                                  fontSize: 12,
                                  fontWeight: 600,
                                  color: KatanaColors.textMuted,
                                }}
                              >
                                <Icon name="done_all" size={14} color={KatanaColors.green} />
                                <span>{readCount === detail.chapters.length ? 'Mark all unread' : 'Mark all read'}</span>
                              </button>
                            )}
                          </div>
                        )}

                        {hasChapterMetaFilters && chapterToolsOpen && (
                          <div
                            aria-label="Chapter language and edition filters"
                            style={{
                              marginTop: 8,
                              display: 'flex',
                              alignItems: 'center',
                              gap: 6,
                              flexWrap: 'wrap',
                            }}
                          >
                            {availableChapterLangs.length > 1 && (
                              <>
                                <span style={{ ...KatanaType.small, fontSize: 11.5, fontWeight: 700 }}>Language:</span>
                                {(['all', ...availableChapterLangs] as const).map((lang) => {
                                  const active = chapterLangFilter === lang;
                                  return (
                                    <button
                                      key={lang}
                                      type="button"
                                      className="bare-button"
                                      aria-pressed={active}
                                      onClick={() => setChapterLangFilter(lang)}
                                      style={{
                                        minHeight: 44,
                                        padding: '4px 10px',
                                        borderRadius: 99,
                                        background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                        border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                                        fontFamily: Fonts.body,
                                        fontSize: 11.5,
                                        fontWeight: active ? 700 : 600,
                                        color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                                      }}
                                    >
                                      {lang === 'all' ? 'All' : lang.toUpperCase()}
                                    </button>
                                  );
                                })}
                              </>
                            )}
                            {availableChapterGroups.length >= 1 && (
                              <>
                                <span style={{ ...KatanaType.small, fontSize: 11.5, fontWeight: 700, marginLeft: availableChapterLangs.length > 1 ? 6 : 0 }}>Edition:</span>
                                {(['all', ...availableChapterGroups] as const).map((grp) => {
                                  const active = chapterGroupFilter === grp;
                                  const isPreferred = grp !== 'all' && preferredScanlationGroup === grp;
                                  return (
                                    <button
                                      key={grp}
                                      type="button"
                                      className="bare-button"
                                      aria-pressed={active}
                                      onClick={() => setChapterGroupFilter(grp)}
                                      style={{
                                        minHeight: 44,
                                        padding: '4px 10px',
                                        borderRadius: 99,
                                        background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                        border: `1px solid ${active ? KatanaColors.chipSelectedBorder : isPreferred ? KatanaColors.accent : KatanaColors.border}`,
                                        fontFamily: Fonts.body,
                                        fontSize: 11.5,
                                        fontWeight: active || isPreferred ? 700 : 600,
                                        color: active ? KatanaColors.chipSelectedText : isPreferred ? KatanaColors.accentSoft : KatanaColors.textMuted,
                                      }}
                                    >
                                      {grp === 'all' ? 'All' : isPreferred ? `★ ${grp}` : grp}
                                    </button>
                                  );
                                })}
                                {chapterGroupFilter !== 'all' && (
                                  <>
                                    <button
                                      type="button"
                                      className="bare-button"
                                      aria-pressed={preferredScanlationGroup === chapterGroupFilter}
                                      onClick={() => {
                                        const nextPref = preferredScanlationGroup === chapterGroupFilter ? '' : chapterGroupFilter;
                                        setPreferredScanlationGroup(nextPref);
                                        showSnackBar(
                                          nextPref
                                            ? `${nextPref} is now the edition we use`
                                            : 'Edition preference cleared',
                                        );
                                      }}
                                      style={{
                                        minHeight: 44,
                                        padding: '4px 10px',
                                        borderRadius: 99,
                                        background: preferredScanlationGroup === chapterGroupFilter ? withAlpha(KatanaColors.accent, 0.18) : KatanaColors.surface,
                                        border: `1px solid ${preferredScanlationGroup === chapterGroupFilter ? KatanaColors.accent : KatanaColors.borderStrong}`,
                                        fontFamily: Fonts.body,
                                        fontSize: 11.5,
                                        fontWeight: 700,
                                        color: preferredScanlationGroup === chapterGroupFilter ? KatanaColors.accentSoft : KatanaColors.text,
                                      }}
                                    >
                                      {preferredScanlationGroup === chapterGroupFilter ? '★ Always use' : '★ Always use this one'}
                                    </button>
                                    <button
                                      type="button"
                                      className="bare-button"
                                      onClick={() => {
                                        const targetGrp = chapterGroupFilter;
                                        setBlockedScanlationGroups((prev) => Array.from(new Set([...prev, targetGrp])));
                                        if (preferredScanlationGroup === targetGrp) setPreferredScanlationGroup('');
                                        setChapterGroupFilter('all');
                                        showSnackBar(`Hid chapters from ${targetGrp}`);
                                      }}
                                      style={{
                                        minHeight: 44,
                                        padding: '4px 10px',
                                        borderRadius: 99,
                                        background: withAlpha(KatanaColors.crimson, 0.14),
                                        border: `1px solid ${withAlpha(KatanaColors.crimson, 0.4)}`,
                                        fontFamily: Fonts.body,
                                        fontSize: 11.5,
                                        fontWeight: 700,
                                        color: KatanaColors.crimson,
                                      }}
                                    >
                                      ⊘ Block Group
                                    </button>
                                  </>
                                )}
                                {preferredScanlationGroup && (
                                  <button
                                    type="button"
                                    className="bare-button"
                                    aria-pressed={waitForPreferredHours > 0}
                                    onClick={() => {
                                      const nextHrs = waitForPreferredHours > 0 ? 0 : 24;
                                      setWaitForPreferredHours(nextHrs);
                                      showSnackBar(
                                        nextHrs > 0
                                          ? `Waiting 24h for ${preferredScanlationGroup} before fallback releases`
                                          : 'Disabled 24h preferred-group wait window',
                                      );
                                    }}
                                    style={{
                                      minHeight: 44,
                                      padding: '4px 10px',
                                      borderRadius: 99,
                                      background: waitForPreferredHours > 0 ? withAlpha(KatanaColors.teal, 0.16) : KatanaColors.surfaceAlt,
                                      border: `1px solid ${waitForPreferredHours > 0 ? KatanaColors.teal : KatanaColors.border}`,
                                      fontFamily: Fonts.body,
                                      fontSize: 11.5,
                                      fontWeight: 700,
                                      color: waitForPreferredHours > 0 ? KatanaColors.teal : KatanaColors.textMuted,
                                    }}
                                  >
                                    {waitForPreferredHours > 0 ? `⏳ Wait a day for ${preferredScanlationGroup}: On` : '⏳ Wait a day for your edition'}
                                  </button>
                                )}
                                {blockedScanlationGroups.map((bGrp) => (
                                  <button
                                    key={`blocked-${bGrp}`}
                                    type="button"
                                    className="bare-button"
                                    title={`Unblock ${bGrp} (${blockedChaptersCount} hidden)`}
                                    onClick={() => {
                                      setBlockedScanlationGroups((prev) => prev.filter((g) => g !== bGrp));
                                      showSnackBar(`Unblocked ${bGrp}`);
                                    }}
                                    style={{
                                      minHeight: 44,
                                      padding: '4px 10px',
                                      borderRadius: 99,
                                      background: withAlpha(KatanaColors.crimson, 0.12),
                                      border: `1px solid ${withAlpha(KatanaColors.crimson, 0.35)}`,
                                      fontFamily: Fonts.body,
                                      fontSize: 11.5,
                                      fontWeight: 600,
                                      color: KatanaColors.crimson,
                                    }}
                                  >
                                    ⊘ {bGrp} (Unblock)
                                  </button>
                                ))}
                              </>
                            )}
                          </div>
                        )}

                        {chapterGapReport.segments.length > 0 && (
                          <div
                            role="region"
                            aria-label="Chapter health and missing chapters"
                            style={{
                              marginTop: 10,
                              padding: '10px 12px',
                              borderRadius: 10,
                              background: withAlpha(KatanaColors.orange, 0.1),
                              border: `1px solid ${withAlpha(KatanaColors.orange, 0.38)}`,
                              display: 'flex',
                              flexDirection: 'column',
                              gap: 8,
                            }}
                          >
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, flexWrap: 'wrap' }}>
                              <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                                <Icon name="health_and_safety" size={16} color={KatanaColors.orange} />
                                <span style={{ fontFamily: Fonts.body, fontSize: 12.5, fontWeight: 700, color: KatanaColors.text }}>
                                  Chapter Health · {chapterGapReport.missingNumbers.length} missing{' '}
                                  {chapterGapReport.missingNumbers.length === 1 ? 'chapter' : 'chapters'} detected
                                </span>
                              </div>
                              <button
                                type="button"
                                className="bare-button"
                                onClick={() => {
                                  closeDetail();
                                  setCatalogSource('all');
                                  updateMangaUrl(
                                    { tab: 'directory', mode: 'search', q: detail.title, page: '1' },
                                    { clearAll: true },
                                  );
                                }}
                                style={{
                                  minHeight: 38,
                                  padding: '0 10px',
                                  borderRadius: 8,
                                  background: KatanaColors.surface,
                                  border: `1px solid ${KatanaColors.borderStrong}`,
                                  fontFamily: Fonts.body,
                                  fontSize: 11.5,
                                  fontWeight: 700,
                                  color: KatanaColors.accentSoft,
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  gap: 5,
                                }}
                              >
                                <Icon name="troubleshoot" size={14} color={KatanaColors.accent} />
                                <span>Check MD · CK · BT for missing chapters</span>
                              </button>
                            </div>
                            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                              {chapterGapReport.segments.slice(0, 8).map((seg) => (
                                <button
                                  key={`${seg.afterNum}-${seg.beforeNum}`}
                                  type="button"
                                  className="bare-button"
                                  title={`Missing between Ch. ${seg.afterNum} and Ch. ${seg.beforeNum} — tap to jump`}
                                  onClick={() => {
                                    const targetId = seg.beforeChapterId || seg.afterChapterId;
                                    const idx = filteredChapters.findIndex((ch) => ch.id === targetId);
                                    if (idx >= 0 && idx >= chapterWindow) setChapterWindow(idx + 15);
                                    window.setTimeout(() => {
                                      const el = document.querySelector(`[data-chapter-id="${CSS.escape(targetId)}"]`);
                                      el?.scrollIntoView({ behavior: 'smooth', block: 'center' });
                                    }, 60);
                                  }}
                                  style={{
                                    minHeight: 36,
                                    padding: '3px 9px',
                                    borderRadius: 7,
                                    background: KatanaColors.surface,
                                    border: `1px solid ${withAlpha(KatanaColors.orange, 0.45)}`,
                                    fontFamily: Fonts.body,
                                    fontSize: 11.5,
                                    fontWeight: 700,
                                    color: KatanaColors.orange,
                                  }}
                                >
                                  Missing {seg.label} · Jump →
                                </button>
                              ))}
                            </div>
                          </div>
                        )}

                        {seriesSavedMoments.length > 0 && (
                          <div
                            role="region"
                            aria-label="Saved page moments and notes"
                            style={{
                              marginTop: 10,
                              padding: '10px 12px',
                              borderRadius: 10,
                              background: KatanaColors.surfaceAlt,
                              border: `1px solid ${KatanaColors.borderStrong}`,
                            }}
                          >
                            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
                              <Icon name="bookmarks" size={15} color={KatanaColors.accent} />
                              <span style={{ fontFamily: Fonts.body, fontSize: 12.5, fontWeight: 700, color: KatanaColors.text }}>
                                Saved Moments &amp; Notes ({seriesSavedMoments.length})
                              </span>
                            </div>
                            <div className="no-scrollbar" style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 2 }}>
                              {seriesSavedMoments.slice(0, 12).map((bm) => (
                                <button
                                  key={`${bm.chapterId}:${bm.pageIdx}`}
                                  type="button"
                                  className="bare-button"
                                  onClick={() => openChapter(detail, bm.chapterId, bm.pageIdx + 1)}
                                  style={{
                                    minWidth: 170,
                                    maxWidth: 240,
                                    padding: '8px 10px',
                                    borderRadius: 8,
                                    background: KatanaColors.surface,
                                    border: `1px solid ${KatanaColors.border}`,
                                    textAlign: 'left',
                                    flexShrink: 0,
                                  }}
                                >
                                  <div className="ellipsis" style={{ fontFamily: Fonts.body, fontSize: 12, fontWeight: 700, color: KatanaColors.text }}>
                                    {bm.chapterTitle} · Page {bm.pageIdx + 1}
                                  </div>
                                  {bm.note ? (
                                    <div className="clamp-2" style={{ marginTop: 3, fontFamily: Fonts.body, fontSize: 11.5, color: KatanaColors.accentSoft, fontStyle: 'italic' }}>
                                      “{bm.note}”
                                    </div>
                                  ) : (
                                    <div style={{ marginTop: 3, ...KatanaType.small, fontSize: 11 }}>Tap to open moment →</div>
                                  )}
                                </button>
                              ))}
                            </div>
                          </div>
                        )}

                        {previewPages?.slug === detail.slug && (
                          <div style={{ marginTop: 12, padding: 10, borderRadius: 10, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.borderStrong}` }}>
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginBottom: 8 }}>
                              <span style={{ ...KatanaType.small, fontWeight: 700, color: KatanaColors.text }}>
                                First-Chapter Preview · {previewPages.chapterTitle}
                              </span>
                              <KatanaButton
                                label={`Read ${previewPages.chapterTitle}`}
                                icon="play_arrow"
                                size="sm"
                                onClick={() => openChapter(detail, previewPages.chapterId, 1)}
                              />
                            </div>
                            <div className="no-scrollbar" style={{ display: 'flex', gap: 10, overflowX: 'auto', paddingBottom: 4 }}>
                              {previewPages.urls.map((imgUrl, idx) => (
                                <button
                                  key={imgUrl}
                                  type="button"
                                  className="bare-button"
                                  onClick={() => openChapter(detail, previewPages.chapterId, idx + 1)}
                                  style={{
                                    width: compactCard ? 150 : 185,
                                    aspectRatio: '2 / 3',
                                    borderRadius: 8,
                                    overflow: 'hidden',
                                    flexShrink: 0,
                                    border: `1px solid ${KatanaColors.borderStrong}`,
                                    background: KatanaColors.surface,
                                    position: 'relative',
                                  }}
                                >
                                  <img
                                    src={proxyKatanaImageUrl(imgUrl)}
                                    alt={`${detail.title} preview page ${idx + 1}`}
                                    loading="lazy"
                                    style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                                  />
                                  <span
                                    style={{
                                      position: 'absolute',
                                      bottom: 6,
                                      right: 6,
                                      padding: '2px 6px',
                                      borderRadius: 5,
                                      background: withAlpha(KatanaColors.background, 0.86),
                                      fontFamily: Fonts.body,
                                      fontSize: 10.5,
                                      fontWeight: 700,
                                      color: KatanaColors.text,
                                    }}
                                  >
                                    Page {idx + 1}
                                  </span>
                                </button>
                              ))}
                            </div>
                          </div>
                        )}

                        {/* Batch action bar when Select mode is active */}
                        {selectMode && (
                          <div
                            style={{
                              marginTop: 10,
                              padding: '8px 10px',
                              borderRadius: 9,
                              background: KatanaColors.chipSelectedBg,
                              border: `1px solid ${KatanaColors.chipSelectedBorder}`,
                              display: 'flex',
                              alignItems: 'center',
                              gap: 8,
                              flexWrap: 'wrap',
                            }}
                          >
                            <span style={{ fontFamily: Fonts.body, fontSize: 12.5, fontWeight: 700, color: KatanaColors.chipSelectedText }}>
                              {selectedChapterIds.size} selected
                            </span>
                            <button
                              type="button"
                              className="bare-button"
                              onClick={() => {
                                const unreadIds = detail.chapters.filter((c) => !readSet.has(c.id)).map((c) => c.id);
                                setSelectedChapterIds(new Set(unreadIds));
                              }}
                              style={{ ...KatanaType.link, fontSize: 12 }}
                            >
                              Select unread ({unreadCount})
                            </button>
                            <div style={{ flex: 1 }} />
                            {userName && selectedChapterIds.size > 0 && (
                              <>
                                <KatanaButton
                                  label="Mark Read"
                                  icon="done"
                                  size="sm"
                                  filled={false}
                                  color={KatanaColors.green}
                                  onClick={() => {
                                    void markKatanaChaptersRead(detail, userName, [...selectedChapterIds], true);
                                    showSnackBar(`Marked ${selectedChapterIds.size} chapters read`);
                                    setSelectMode(false);
                                    setSelectedChapterIds(new Set());
                                  }}
                                />
                                <KatanaButton
                                  label="Mark Unread"
                                  icon="visibility_off"
                                  size="sm"
                                  filled={false}
                                  color={KatanaColors.textMuted}
                                  onClick={() => {
                                    void markKatanaChaptersRead(detail, userName, [...selectedChapterIds], false);
                                    showSnackBar(`Marked ${selectedChapterIds.size} chapters unread`);
                                    setSelectMode(false);
                                    setSelectedChapterIds(new Set());
                                  }}
                                />
                              </>
                            )}
                            {selectedChapterIds.size > 0 && (
                              <KatanaButton
                                label={`Download (${estimateMangaBatchMegabytes(selectedChapterIds.size, false, offline.mangaItems).label})`}
                                icon="download"
                                size="sm"
                                onClick={() => {
                                  const targets = detail.chapters.filter((c) => selectedChapterIds.has(c.id));
                                  setSelectMode(false);
                                  setSelectedChapterIds(new Set());
                                  void downloadBatchChapters(detail, targets);
                                }}
                              />
                            )}
                          </div>
                        )}

                        {/* Chapter search / jump */}
                        {detail.chapters.length > 8 && (
                          <div
                            style={{
                              marginTop: 12,
                              display: 'flex',
                              alignItems: 'center',
                              gap: 8,
                              padding: '0 12px',
                              height: 44,
                              borderRadius: 9,
                              background: KatanaColors.background,
                              border: `1px solid ${KatanaColors.border}`,
                            }}
                          >
                            <Icon name="search" size={16} color={KatanaColors.textLight} />
                            <input
                              value={chapterSearch}
                              onChange={(e) => setChapterSearch(e.target.value)}
                              placeholder="Jump to chapter number or title..."
                              aria-label="Filter chapters"
                              style={{
                                flex: 1,
                                background: 'transparent',
                                border: 'none',
                                outline: 'none',
                                fontFamily: Fonts.body,
                                fontSize: 13,
                                color: KatanaColors.text,
                              }}
                            />
                            {chapterSearch && (
                              <button type="button" className="bare-button" aria-label="Clear chapter filter" onClick={() => setChapterSearch('')}>
                                <Icon name="clear" size={15} color={KatanaColors.textLight} />
                              </button>
                            )}
                          </div>
                        )}

                        <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 6 }}>
                          {visibleChapters.map((c, idx) => {
                            const isRead = readSet.has(c.id);
                            const isLastRead = detailBm?.lastReadChapterId === c.id;
                            const isChecked = selectedChapterIds.has(c.id);
                            const offlineId = OfflineIds.mangaChapterId(detail.slug, c.id);
                            const isOffline = offlineMedia.isDownloaded(offlineId);
                            const needsOfflineRepair = offlineMedia.needsCacheRepair(offlineId);
                            const isDownloading = downloadingChapterIds.has(c.id);

                            const resolveVolumeLabel = (ch: KatanaChapter): string => {
                              const explicit = /\b(?:vol(?:ume)?|season|part)\s*\.?\s*(\d+)/i.exec(ch.title);
                              if (explicit) return `Volume ${explicit[1]}`;
                              const num = Number.parseFloat(ch.num);
                              if (Number.isFinite(num) && num > 0) {
                                const start = Math.floor((num - 1) / 25) * 25 + 1;
                                return `Chapters ${start}–${start + 24}`;
                              }
                              return 'Chapters';
                            };
                            const volLabel = chapterGrouped ? resolveVolumeLabel(c) : '';
                            const prevVolLabel = chapterGrouped && idx > 0 ? resolveVolumeLabel(visibleChapters[idx - 1]) : '';
                            const showVolHeader = chapterGrouped && volLabel !== prevVolLabel;

                            const isMenuOpen = chapterActionMenuId === c.id;
                            return (
                              <div key={c.id}>
                                {showVolHeader && (
                                  <div
                                    style={{
                                      marginTop: idx === 0 ? 0 : 8,
                                      marginBottom: 6,
                                      padding: '5px 10px',
                                      borderRadius: 7,
                                      background: KatanaColors.background,
                                      border: `1px solid ${KatanaColors.border}`,
                                      fontFamily: Fonts.body,
                                      fontSize: 11.5,
                                      fontWeight: 700,
                                      color: KatanaColors.accentSoft,
                                      letterSpacing: 0.3,
                                    }}
                                  >
                                    {volLabel}
                                  </div>
                                )}
                              <div
                                data-chapter-id={c.id}
                                style={{
                                  borderRadius: 9,
                                  background: isChecked
                                    ? KatanaColors.chipSelectedBg
                                    : isLastRead
                                      ? withAlpha(KatanaColors.accent, 0.1)
                                      : KatanaColors.surfaceAlt,
                                  border: `1px solid ${
                                    isChecked
                                      ? KatanaColors.chipSelectedBorder
                                      : isLastRead
                                        ? withAlpha(KatanaColors.accent, 0.45)
                                        : KatanaColors.border
                                  }`,
                                  overflow: 'hidden',
                                }}
                              >
                                <div
                                  style={{
                                    display: 'flex',
                                    alignItems: 'center',
                                    gap: 8,
                                    padding: compactCard ? '9px 8px 9px 10px' : '8px 10px',
                                  }}
                                >
                                  {selectMode && (
                                    <button
                                      type="button"
                                      className="bare-button"
                                      aria-label={`Select ${chapterDisplayTitle(c)}`}
                                      onClick={() => toggleSelectChapter(c.id)}
                                      style={{ width: 40, height: 40, display: 'grid', placeItems: 'center', flexShrink: 0 }}
                                    >
                                      <Icon
                                        name={isChecked ? 'check_box' : 'check_box_outline_blank'}
                                        size={21}
                                        color={isChecked ? KatanaColors.accent : KatanaColors.textLight}
                                      />
                                    </button>
                                  )}

                                  <button
                                    type="button"
                                    className="bare-button"
                                    onClick={() => (selectMode ? toggleSelectChapter(c.id) : openChapter(detail, c.id))}
                                    style={{
                                      flex: 1,
                                      minWidth: 0,
                                      display: 'flex',
                                      alignItems: 'center',
                                      gap: 8,
                                      textAlign: 'left',
                                    }}
                                  >
                                    {!selectMode && (
                                      <Icon
                                        name={isLastRead ? 'play_circle' : isRead ? 'check_circle' : 'radio_button_unchecked'}
                                        size={17}
                                        color={isLastRead ? KatanaColors.accent : isRead ? KatanaColors.green : KatanaColors.textLight}
                                      />
                                    )}
                                    <div style={{ flex: 1, minWidth: 0 }}>
                                      <div
                                        className="clamp-2"
                                        style={{
                                          ...KatanaType.title,
                                          fontSize: 13.5,
                                          color: isRead && !isLastRead ? KatanaColors.textMuted : KatanaColors.text,
                                        }}
                                      >
                                        {chapterDisplayTitle(c)}
                                      </div>
                                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 3, flexWrap: 'wrap' }}>
                                        {c.updateAt && (
                                          <span style={{ ...KatanaType.small, fontSize: 11.5 }}>{formatKatanaTime(c.updateAt)}</span>
                                        )}

                                        {c.isNew && !isLastRead && !isRead && (
                                          <span
                                            style={{
                                              padding: '1px 6px',
                                              borderRadius: 4,
                                              background: KatanaColors.accent,
                                              color: KatanaColors.accentInk,
                                              fontFamily: Fonts.body,
                                              fontSize: 11,
                                              fontWeight: 800,
                                            }}
                                          >
                                            NEW
                                          </span>
                                        )}
                                        {isDownloading && (
                                          <span
                                            style={{
                                              display: 'inline-flex',
                                              alignItems: 'center',
                                              gap: 4,
                                              padding: '1px 6px',
                                              borderRadius: 4,
                                              background: withAlpha(KatanaColors.accent, 0.2),
                                              color: KatanaColors.accentSoft,
                                              fontFamily: Fonts.body,
                                              fontSize: 10.5,
                                              fontWeight: 800,
                                            }}
                                          >
                                            <Icon name="hourglass_top" size={11} color={KatanaColors.accent} />
                                            SAVING…
                                          </span>
                                        )}
                                        {isLastRead && (
                                          <span
                                            style={{
                                              padding: '1px 6px',
                                              borderRadius: 4,
                                              background: withAlpha(KatanaColors.accent, 0.2),
                                              color: KatanaColors.accentSoft,
                                              fontFamily: Fonts.body,
                                              fontSize: 10.5,
                                              fontWeight: 800,
                                            }}
                                          >
                                            LAST READ
                                          </span>
                                        )}
                                        {preferredScanlationGroup && (c.scanlationGroup || '').trim() === preferredScanlationGroup && (
                                          <span
                                            style={{
                                              padding: '1px 6px',
                                              borderRadius: 4,
                                              background: withAlpha(
                                                !isRead && readChapterNums.has(c.num.trim()) ? KatanaColors.green : KatanaColors.accent,
                                                0.18,
                                              ),
                                              color: !isRead && readChapterNums.has(c.num.trim()) ? KatanaColors.green : KatanaColors.accentSoft,
                                              fontFamily: Fonts.body,
                                              fontSize: 10.5,
                                              fontWeight: 800,
                                            }}
                                          >
                                            {!isRead && readChapterNums.has(c.num.trim()) ? 'Better copy' : 'Your edition'}
                                          </span>
                                        )}
                                        {preferredScanlationGroup &&
                                          waitForPreferredHours > 0 &&
                                          idx === 0 &&
                                          (c.scanlationGroup || '').trim() !== preferredScanlationGroup &&
                                          (!c.updateAt || Date.now() - c.updateAt.getTime() < waitForPreferredHours * 3_600_000) && (
                                            <span
                                              title={`Waiting up to ${waitForPreferredHours}h for ${preferredScanlationGroup} release`}
                                              style={{
                                                padding: '1px 6px',
                                                borderRadius: 4,
                                                background: withAlpha(KatanaColors.teal, 0.16),
                                                color: KatanaColors.teal,
                                                fontFamily: Fonts.body,
                                                fontSize: 10.5,
                                                fontWeight: 800,
                                              }}
                                            >
                                              ⏳ Waiting for {preferredScanlationGroup}
                                            </span>
                                          )}
                                        {needsOfflineRepair ? (
                                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, fontFamily: Fonts.body, fontSize: 11, fontWeight: 700, color: KatanaColors.accentSoft }}>
                                            <Icon name="warning_amber" size={13} color={KatanaColors.accent} />
                                            Needs Repair
                                          </span>
                                        ) : isOffline ? (
                                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, fontFamily: Fonts.body, fontSize: 11, fontWeight: 600, color: KatanaColors.green }}>
                                            <Icon name="download_done" size={13} color={KatanaColors.green} />
                                            Offline
                                          </span>
                                        ) : null}
                                      </div>
                                    </div>
                                  </button>

                                  {!selectMode && (
                                    <button
                                      type="button"
                                      className="bare-button"
                                      title="More chapter actions"
                                      aria-label={`More actions for ${chapterDisplayTitle(c)}`}
                                      aria-expanded={isMenuOpen}
                                      onClick={() => setChapterActionMenuId(isMenuOpen ? null : c.id)}
                                      style={{
                                        width: 44,
                                        height: 44,
                                        borderRadius: 8,
                                        background: isMenuOpen ? KatanaColors.chipSelectedBg : 'transparent',
                                        display: 'grid',
                                        placeItems: 'center',
                                        flexShrink: 0,
                                      }}
                                    >
                                      <Icon name="more_vert" size={18} color={isMenuOpen ? KatanaColors.accentSoft : KatanaColors.textLight} />
                                    </button>
                                  )}


                                  {!selectMode && !compactCard && (
                                    <button
                                      type="button"
                                      className="bare-button"
                                      disabled={isDownloading}
                                      title={
                                        needsOfflineRepair
                                          ? 'This chapter lost some pages — tap to re-download it'
                                          : isOffline
                                            ? 'Saved offline'
                                            : isDownloading
                                              ? 'Downloading chapter…'
                                              : 'Download chapter'
                                      }
                                      aria-label={
                                        needsOfflineRepair
                                          ? `Re-download this chapter for ${chapterDisplayTitle(c)}`
                                          : isOffline
                                            ? `${chapterDisplayTitle(c)} saved offline`
                                            : isDownloading
                                              ? `Downloading ${chapterDisplayTitle(c)}`
                                              : `Download ${chapterDisplayTitle(c)}`
                                      }
                                      onClick={() => void downloadChapter(detail, c)}
                                      style={{
                                        width: 44,
                                        height: 44,
                                        borderRadius: 8,
                                        display: 'grid',
                                        placeItems: 'center',
                                        flexShrink: 0,
                                        opacity: isDownloading ? 0.7 : 1,
                                      }}
                                    >
                                      <Icon
                                        name={
                                          needsOfflineRepair
                                            ? 'build'
                                            : isOffline
                                              ? 'download_done'
                                              : isDownloading
                                                ? 'hourglass_top'
                                                : 'download'
                                        }
                                        size={19}
                                        color={
                                          needsOfflineRepair
                                            ? KatanaColors.accent
                                            : isOffline
                                              ? KatanaColors.green
                                              : isDownloading
                                                ? KatanaColors.accent
                                                : KatanaColors.textMuted
                                        }
                                      />
                                    </button>
                                  )}
                                </div>

                                {!selectMode && isMenuOpen && (
                                  <div
                                    style={{
                                      display: 'flex',
                                      flexWrap: 'wrap',
                                      gap: 6,
                                      padding: '8px 10px',
                                      borderTop: `1px solid ${KatanaColors.border}`,
                                      background: KatanaColors.surface,
                                    }}
                                  >
                                    {userName && (
                                      <>
                                          <KatanaButton
                                            label={isRead ? 'Mark Unread' : 'Mark Read'}
                                            icon={isRead ? 'visibility_off' : 'done'}
                                            size="sm"
                                            filled={false}
                                            color={KatanaColors.text}
                                            onClick={() => {
                                              setChapterActionMenuId(null);
                                              void markKatanaChaptersRead(detail, userName, [c.id], !isRead);
                                            }}
                                          />
                                        <KatanaButton
                                          label="Read Previous"
                                          icon="done_all"
                                          size="sm"
                                          filled={false}
                                          color={KatanaColors.textMuted}
                                          onClick={() => {
                                            setChapterActionMenuId(null);
                                            const idxInNewest = detail.chapters.findIndex((ch) => ch.id === c.id);
                                            if (idxInNewest < 0) return;
                                            const prevIds = detail.chapters.slice(idxInNewest).map((ch) => ch.id);
                                            void markKatanaChaptersRead(detail, userName, prevIds, true);
                                            showSnackBar(`Marked ${prevIds.length} chapters read`);
                                          }}
                                        />
                                      </>
                                    )}
                                    {compactCard && (
                                      <KatanaButton
                                        label={isOffline ? 'Offline' : isDownloading ? 'Saving…' : 'Download'}
                                        icon={isOffline ? 'download_done' : 'download'}
                                        size="sm"
                                        filled={false}
                                        color={isOffline ? KatanaColors.green : KatanaColors.link}
                                        onClick={() => {
                                          setChapterActionMenuId(null);
                                          void downloadChapter(detail, c);
                                        }}
                                      />
                                    )}
                                    {c.scanlationGroup && (
                                      <>
                                        <KatanaButton
                                          label={
                                            preferredScanlationGroup === c.scanlationGroup
                                              ? `★ Preferred (${c.scanlationGroup})`
                                              : `★ Prefer ${c.scanlationGroup}`
                                          }
                                          icon="star"
                                          size="sm"
                                          filled={false}
                                          color={KatanaColors.accent}
                                          onClick={() => {
                                            const grp = (c.scanlationGroup || '').trim();
                                            setChapterActionMenuId(null);
                                            const nextPref = preferredScanlationGroup === grp ? '' : grp;
                                            setPreferredScanlationGroup(nextPref);
                                            showSnackBar(
                                              nextPref
                                                ? `Preferred group set to ${nextPref}`
                                                : 'Edition preference cleared',
                                            );
                                          }}
                                        />
                                        <KatanaButton
                                          label={`⊘ Block ${c.scanlationGroup}`}
                                          icon="block"
                                          size="sm"
                                          filled={false}
                                          color={KatanaColors.crimson}
                                          onClick={() => {
                                            const grp = (c.scanlationGroup || '').trim();
                                            setChapterActionMenuId(null);
                                            setBlockedScanlationGroups((prev) => Array.from(new Set([...prev, grp])));
                                            if (preferredScanlationGroup === grp) setPreferredScanlationGroup('');
                                            showSnackBar(`Blocked chapters from ${grp}`);
                                          }}
                                        />
                                      </>
                                    )}
                                  </div>
                                )}
                              </div>
                              </div>
                            );
                          })}
                        </div>

                        {filteredChapters.length > visibleChapters.length && (
                          <div style={{ marginTop: 12, display: 'flex', justifyContent: 'center', gap: 10 }}>
                            <KatanaButton
                              label={`Show 40 more (${filteredChapters.length - visibleChapters.length} left)`}
                              size="sm"
                              filled={false}
                              color={KatanaColors.text}
                              onClick={() => setChapterWindow((w) => w + 40)}
                            />
                            <KatanaButton
                              label="Show all"
                              size="sm"
                              filled={false}
                              color={KatanaColors.textMuted}
                              onClick={() => setChapterWindow(filteredChapters.length)}
                            />
                          </div>
                        )}
                          </KatanaCard>
                        </div>

                        {tablet && similarToDetail.length > 0 && (
                          <aside style={{ width: desktop ? 340 : 240, flexShrink: 0, position: 'sticky', top: 14, alignSelf: 'flex-start' }}>
                            <KatanaCard padding={14}>
                                <KatanaSectionHeader title="Related & Similar" />
                                <div style={{ height: 10 }} />
                                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                                  {similarToDetail.map(({ manga: m, relation }) => (
                                    <button
                                      key={m.slug}
                                      type="button"
                                      className="bare-button"
                                      onClick={() => openDetail(m.slug)}
                                      style={{
                                        display: 'flex',
                                        alignItems: 'center',
                                        gap: 10,
                                        padding: 6,
                                        borderRadius: 9,
                                        background: KatanaColors.surfaceAlt,
                                        border: `1px solid ${KatanaColors.border}`,
                                        textAlign: 'left',
                                      }}
                                    >
                                      <div style={{ position: 'relative', width: 42, height: 60, borderRadius: 6, overflow: 'hidden', flexShrink: 0, background: KatanaColors.background }}>
                                        <KatanaCoverImage url={m.coverUrl} title={m.title} iconSize={16} />
                                      </div>
                                      <div style={{ flex: 1, minWidth: 0 }}>
                                        <div className="clamp-2" style={{ fontFamily: Fonts.body, fontSize: 13, fontWeight: 600, color: KatanaColors.text, lineHeight: 1.25 }}>
                                          {m.title}
                                        </div>
                                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 3, flexWrap: 'wrap' }}>
                                          {relation && (
                                            <span
                                              style={{
                                                padding: '1px 6px',
                                                borderRadius: 5,
                                                background: withAlpha(KatanaColors.accent, 0.16),
                                                fontFamily: Fonts.body,
                                                fontSize: 10,
                                                fontWeight: 700,
                                                color: KatanaColors.accentSoft,
                                              }}
                                            >
                                              {relation}
                                            </span>
                                          )}
                                          {m.rating != null && (
                                            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 2, fontSize: 11, fontWeight: 700, color: KatanaColors.accentSoft }}>
                                              <Icon name="star" size={11} color={KatanaColors.accent} />
                                              {m.rating.toFixed(1)}
                                            </span>
                                          )}
                                          <span className="ellipsis" style={{ ...KatanaType.small, fontSize: 11 }}>
                                            {m.genres.slice(0, 2).map((g) => g.name).join(' · ')}
                                          </span>
                                        </div>
                                      </div>
                                    </button>
                                  ))}
                                </div>
                              </KatanaCard>
                          </aside>
                        )}
                      </div>

                        {(() => {
                          const allLinks = resolveOfficialPublisherLinks(detail, detailBm);
                          const publisherLinks = allLinks.filter((l) => l.category === 'publisher');
                          const verifiedPublisherLinks = publisherLinks.filter((l) => l.directLink && l.officialSimulpub);
                          const searchLookupLinks = publisherLinks.filter((l) => !l.directLink);
                          const trackerAndRegistryLinks = allLinks.filter(
                            (l) => l.category === 'tracker' || l.category === 'registry',
                          );
                          const srcMeta = getSourceBadgeInfo(detail.source, detail.slug);
                          return (
                            <div
                              style={{
                                marginTop: 14,
                                padding: '12px 14px',
                                borderRadius: 12,
                                background: KatanaColors.surfaceAlt,
                                border: `1px solid ${
                                  verifiedPublisherLinks.length > 0
                                    ? withAlpha(KatanaColors.green, 0.45)
                                    : KatanaColors.border
                                }`,
                                display: 'flex',
                                flexDirection: 'column',
                                gap: 10,
                              }}
                            >
                              {verifiedPublisherLinks.length > 0 && (
                                <div
                                  style={{
                                    padding: '10px 12px',
                                    borderRadius: 10,
                                    background: withAlpha(KatanaColors.green, 0.1),
                                    border: `1px solid ${withAlpha(KatanaColors.green, 0.42)}`,
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'space-between',
                                    flexWrap: 'wrap',
                                    gap: 8,
                                  }}
                                >
                                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                                    <span
                                      style={{
                                        display: 'inline-flex',
                                        alignItems: 'center',
                                        gap: 5,
                                        fontFamily: Fonts.body,
                                        fontSize: 12.5,
                                        fontWeight: 800,
                                        color: KatanaColors.green,
                                      }}
                                    >
                                      <Icon name="verified" size={16} color={KatanaColors.green} />
                                      <span>Read it officially:</span>
                                    </span>
                                    {verifiedPublisherLinks.map((pub) => (
                                      <a
                                        key={pub.id}
                                        href={pub.url}
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        title={`${pub.name} · ${pub.badge}`}
                                        style={{
                                          minHeight: 34,
                                          padding: '4px 11px',
                                          borderRadius: 99,
                                          background: withAlpha(KatanaColors.green, 0.2),
                                          border: `1.5px solid ${withAlpha(KatanaColors.green, 0.65)}`,
                                          display: 'inline-flex',
                                          alignItems: 'center',
                                          gap: 5,
                                          fontFamily: Fonts.body,
                                          fontSize: 12.5,
                                          fontWeight: 800,
                                          color: '#A7F3D0',
                                          textDecoration: 'none',
                                        }}
                                      >
                                        <Icon name={pub.icon} size={14} color={KatanaColors.green} />
                                        <span>{pub.name}</span>
                                        <Icon name="open_in_new" size={12} color={KatanaColors.green} />
                                      </a>
                                    ))}
                                  </div>
                                  {userName && (
                                    <button
                                      type="button"
                                      className="bare-button"
                                      onClick={() => void openMigrationPicker(detail)}
                                      style={{
                                        minHeight: 32,
                                        padding: '3px 10px',
                                        borderRadius: 99,
                                        background: withAlpha(KatanaColors.teal, 0.14),
                                        border: `1px solid ${withAlpha(KatanaColors.teal, 0.45)}`,
                                        display: 'inline-flex',
                                        alignItems: 'center',
                                        gap: 4,
                                        fontFamily: Fonts.body,
                                        fontSize: 11,
                                        fontWeight: 700,
                                        color: KatanaColors.teal,
                                      }}
                                    >
                                      <Icon name="swap_horiz" size={13} color={KatanaColors.teal} />
                                      <span>Check other sites</span>
                                    </button>
                                  )}
                                </div>
                              )}

                              {searchLookupLinks.length > 0 && (
                                <div
                                  style={{
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'space-between',
                                    flexWrap: 'wrap',
                                    gap: 8,
                                  }}
                                >
                                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                                    <Icon name="search" size={15} color={KatanaColors.textMuted} />
                                    <span style={{ ...KatanaType.small, fontSize: 11.5, fontWeight: 700, color: KatanaColors.textMuted }}>
                                      Check the publisher's own site:
                                    </span>
                                    {searchLookupLinks.map((pub) => (
                                      <a
                                        key={pub.id}
                                        href={pub.url}
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        title={`${pub.name} · ${pub.badge}`}
                                        style={{
                                          padding: '2px 9px',
                                          borderRadius: 99,
                                          background: KatanaColors.surface,
                                          border: `1px dashed ${KatanaColors.borderStrong}`,
                                          display: 'inline-flex',
                                          alignItems: 'center',
                                          gap: 4,
                                          fontFamily: Fonts.body,
                                          fontSize: 11.5,
                                          fontWeight: 600,
                                          color: KatanaColors.textMuted,
                                          textDecoration: 'none',
                                        }}
                                      >
                                        <Icon name="search" size={12} color={KatanaColors.textMuted} />
                                        <span>{pub.name}</span>
                                      </a>
                                    ))}
                                  </div>
                                  {verifiedPublisherLinks.length === 0 && userName && (
                                    <button
                                      type="button"
                                      className="bare-button"
                                      onClick={() => void openMigrationPicker(detail)}
                                      style={{
                                        minHeight: 32,
                                        padding: '3px 9px',
                                        borderRadius: 99,
                                        background: withAlpha(KatanaColors.teal, 0.14),
                                        border: `1px solid ${withAlpha(KatanaColors.teal, 0.45)}`,
                                        display: 'inline-flex',
                                        alignItems: 'center',
                                        gap: 4,
                                        fontFamily: Fonts.body,
                                        fontSize: 11,
                                        fontWeight: 700,
                                        color: KatanaColors.teal,
                                      }}
                                    >
                                      <Icon name="swap_horiz" size={13} color={KatanaColors.teal} />
                                      <span>Check other sites</span>
                                    </button>
                                  )}
                                </div>
                              )}

                              <div
                                style={{
                                  display: 'flex',
                                  alignItems: 'center',
                                  justifyContent: 'space-between',
                                  flexWrap: 'wrap',
                                  gap: 8,
                                  paddingTop: 6,
                                  borderTop: `1px solid ${withAlpha(KatanaColors.border, 0.65)}`,
                                }}
                              >
                                {trackerAndRegistryLinks.length > 0 && (
                                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                                    <Icon name="query_stats" size={15} color={KatanaColors.link} />
                                    <span style={{ ...KatanaType.small, fontSize: 11.5, fontWeight: 700, color: KatanaColors.textMuted }}>
                                      Trackers &amp; Metadata:
                                    </span>
                                    {trackerAndRegistryLinks.map((trk) => (
                                      <a
                                        key={trk.id}
                                        href={trk.url}
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        title={`${trk.name} · ${trk.badge}`}
                                        style={{
                                          padding: '2px 8px',
                                          borderRadius: 99,
                                          background: withAlpha(KatanaColors.link, 0.12),
                                          border: `1px solid ${withAlpha(KatanaColors.link, 0.38)}`,
                                          display: 'inline-flex',
                                          alignItems: 'center',
                                          gap: 4,
                                          fontFamily: Fonts.body,
                                          fontSize: 11.5,
                                          fontWeight: 700,
                                          color: KatanaColors.link,
                                          textDecoration: 'none',
                                        }}
                                      >
                                        <Icon name={trk.icon} size={12} color={KatanaColors.link} />
                                        <span>{trk.name}</span>
                                      </a>
                                    ))}
                                  </div>
                                )}
                                <span
                                  title={srcMeta.tooltip}
                                  style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.textMuted }}
                                >
                                  Where this comes from: <strong style={{ color: KatanaColors.text }}>{srcMeta.name}</strong> ·{' '}
                                  {srcMeta.signals.provenance} · {srcMeta.signals.specialty}
                                </span>
                              </div>
                            </div>
                          );
                        })()}

                        {migrationOpen && userName && (
                          <div
                            style={{
                              marginTop: 14,
                              padding: 12,
                              borderRadius: 10,
                              background: KatanaColors.surfaceAlt,
                              border: `1px solid ${withAlpha(KatanaColors.teal, 0.45)}`,
                              display: 'flex',
                              flexDirection: 'column',
                              gap: 10,
                            }}
                          >
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
                              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                                <Icon name="swap_horiz" size={18} color={KatanaColors.teal} />
                                <span style={{ ...KatanaType.title, fontSize: 13.5 }}>
                                  Migrate Catalog Source (Preserves Progress, Categories & Trackers)
                                </span>
                              </div>
                              <button
                                type="button"
                                className="bare-button"
                                aria-label="Close source migration"
                                onClick={() => setMigrationOpen(false)}
                                style={{ width: 36, height: 36, display: 'grid', placeItems: 'center' }}
                              >
                                <Icon name="close" size={16} color={KatanaColors.textMuted} />
                              </button>
                            </div>
                            {migrationLoading ? (
                              <div style={KatanaType.small}>Searching MangaKatana, MangaDex, ComicK, and Bato.to for matching editions…</div>
                            ) : migrationCandidates.length === 0 ? (
                              <div style={KatanaType.small}>No alternate catalog editions found for this title right now.</div>
                            ) : (
                              <div style={{ display: 'grid', gridTemplateColumns: tablet ? 'repeat(2, minmax(0, 1fr))' : '1fr', gap: 8 }}>
                                {migrationCandidates.map((cand) => (
                                  <div
                                    key={cand.slug}
                                    style={{
                                      display: 'flex',
                                      alignItems: 'center',
                                      justifyContent: 'space-between',
                                      gap: 8,
                                      padding: '8px 10px',
                                      borderRadius: 8,
                                      background: KatanaColors.surface,
                                      border: `1px solid ${KatanaColors.border}`,
                                    }}
                                  >
                                    <div style={{ minWidth: 0, flex: 1 }}>
                                      <div className="ellipsis" style={{ fontFamily: Fonts.body, fontSize: 12.5, fontWeight: 700, color: KatanaColors.text }}>
                                        {cand.title}
                                      </div>
                                      <div style={{ ...KatanaType.small, fontSize: 11 }}>
                                        Source: {cand.source?.toUpperCase() || 'CATALOG'}
                                        {cand.chapterCount ? ` · ${cand.chapterCount} ch` : ''}
                                      </div>
                                    </div>
                                    <KatanaButton
                                      label="Migrate"
                                      icon="swap_horiz"
                                      size="sm"
                                      color={KatanaColors.teal}
                                      onClick={() => void handleMigrateToCandidate(detail, cand)}
                                    />
                                  </div>
                                ))}
                              </div>
                            )}
                          </div>
                        )}

                        {trackerOpen && userName && (
                          <div
                            style={{
                              marginTop: 16,
                              paddingTop: 14,
                              borderTop: `1px solid ${KatanaColors.border}`,
                              display: 'flex',
                              flexDirection: 'column',
                              gap: 12,
                            }}
                          >
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
                              <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                                  <Icon name="star" size={18} color={KatanaColors.accent} />
                                  <span style={{ ...KatanaType.title, fontSize: 14.5 }}>Personal Tracker & External IDs</span>
                                </div>
                                <span style={{ ...KatanaType.small, fontSize: 12 }}>
                                  Saved across your Everglow devices · Progress, status & rating sync with AniList, MyAnimeList & Kitsu via Everglow server proxy.
                                </span>
                              </div>
                              <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                                <span style={KatanaType.small}>Rereads:</span>
                                <button
                                  type="button"
                                  className="bare-button"
                                  aria-label="Decrease reread count"
                                  onClick={() => {
                                    const next = Math.max(0, (detailBm?.rereadCount ?? 0) - 1);
                                    void saveKatanaTrackerData(detail, userName, { rereadCount: next });
                                  }}
                                  style={{ width: 40, height: 40, borderRadius: 8, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}`, display: 'grid', placeItems: 'center' }}
                                >
                                  <Icon name="remove" size={16} color={KatanaColors.textMuted} />
                                </button>
                                <span style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 700, minWidth: 16, textAlign: 'center' }}>
                                  {detailBm?.rereadCount ?? 0}
                                </span>
                                <button
                                  type="button"
                                  className="bare-button"
                                  aria-label="Increase reread count"
                                  onClick={() => {
                                    const next = (detailBm?.rereadCount ?? 0) + 1;
                                    void saveKatanaTrackerData(detail, userName, { rereadCount: next });
                                  }}
                                  style={{ width: 40, height: 40, borderRadius: 8, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}`, display: 'grid', placeItems: 'center' }}
                                >
                                  <Icon name="add" size={16} color={KatanaColors.textMuted} />
                                </button>
                              </div>
                            </div>

                            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center' }}>
                              <span style={{ ...KatanaType.small, marginRight: 4 }}>Score:</span>
                              {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((n) => {
                                const active = detailBm?.userScore === n;
                                return (
                                  <button
                                    key={n}
                                    type="button"
                                    className="bare-button"
                                    onClick={() => {
                                      const nextScore = active ? null : n;
                                      void saveKatanaTrackerData(detail, userName, { userScore: nextScore }).then(() => {
                                        if ((detailBm?.anilistId || detailBm?.malId || detailBm?.kitsuId) && trackerTokens.autoPushTrackers !== false) {
                                          void pushKatanaTrackerProgress(detail, userName, { userScore: nextScore });
                                        }
                                      });
                                    }}
                                    style={{
                                      minWidth: 40,
                                      height: 40,
                                      borderRadius: 8,
                                      background: active ? KatanaColors.accent : KatanaColors.surfaceAlt,
                                      border: `1px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                                      fontFamily: Fonts.body,
                                      fontSize: 13,
                                      fontWeight: 700,
                                      color: active ? KatanaColors.accentInk : KatanaColors.textMuted,
                                    }}
                                  >
                                    {n}
                                  </button>
                                );
                              })}
                            </div>

                            <div style={{ display: 'grid', gridTemplateColumns: tablet ? '1fr 1fr' : '1fr', gap: 8 }}>
                              <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                                <input
                                  value={trackerAnilistDraft}
                                  onChange={(e) => setTrackerAnilistDraft(e.target.value)}
                                  placeholder="AniList ID or link (e.g. 105398)"
                                  aria-label="AniList ID or link"
                                  style={{
                                    flex: 1,
                                    minWidth: 0,
                                    height: 40,
                                    padding: '0 10px',
                                    borderRadius: 8,
                                    background: KatanaColors.background,
                                    border: `1px solid ${KatanaColors.border}`,
                                    fontFamily: Fonts.body,
                                    fontSize: 12.5,
                                    color: KatanaColors.text,
                                  }}
                                />
                                {detailBm?.anilistId && (
                                  <a
                                    href={`https://anilist.co/manga/${encodeURIComponent(detailBm.anilistId)}`}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    aria-label="Open on AniList"
                                    title="Open on AniList"
                                    style={{
                                      height: 40,
                                      padding: '0 10px',
                                      borderRadius: 8,
                                      background: KatanaColors.surfaceAlt,
                                      border: `1px solid ${KatanaColors.borderStrong}`,
                                      display: 'inline-flex',
                                      alignItems: 'center',
                                      gap: 4,
                                      fontFamily: Fonts.body,
                                      fontSize: 11.5,
                                      fontWeight: 700,
                                      color: KatanaColors.link,
                                      textDecoration: 'none',
                                      flexShrink: 0,
                                    }}
                                  >
                                    <span>AniList</span>
                                    <Icon name="open_in_new" size={13} color={KatanaColors.link} />
                                  </a>
                                )}
                              </div>
                              <input
                                value={trackerMalDraft}
                                onChange={(e) => setTrackerMalDraft(e.target.value)}
                                placeholder="MyAnimeList ID or URL (auto-syncs)"
                                aria-label="MyAnimeList ID or URL"
                                style={{
                                  height: 36,
                                  padding: '0 10px',
                                  borderRadius: 8,
                                  background: KatanaColors.background,
                                  border: `1px solid ${KatanaColors.border}`,
                                  fontFamily: Fonts.body,
                                  fontSize: 12.5,
                                  color: KatanaColors.text,
                                }}
                              />
                              <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                                <input
                                  value={trackerKitsuDraft}
                                  onChange={(e) => setTrackerKitsuDraft(e.target.value)}
                                  placeholder="Kitsu ID or URL (auto-syncs)"
                                  aria-label="Kitsu ID or URL"
                                  style={{
                                    flex: 1,
                                    height: 36,
                                    padding: '0 10px',
                                    borderRadius: 8,
                                    background: KatanaColors.background,
                                    border: `1px solid ${KatanaColors.border}`,
                                    fontFamily: Fonts.body,
                                    fontSize: 12.5,
                                    color: KatanaColors.text,
                                  }}
                                />
                                {detailBm?.kitsuId && (
                                  <a
                                    href={`https://kitsu.app/manga/${encodeURIComponent(detailBm.kitsuId)}`}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    aria-label="Open on Kitsu"
                                    style={{
                                      height: 36,
                                      padding: '0 10px',
                                      borderRadius: 8,
                                      background: KatanaColors.surfaceAlt,
                                      border: `1px solid ${KatanaColors.borderStrong}`,
                                      display: 'inline-flex',
                                      alignItems: 'center',
                                      gap: 4,
                                      fontFamily: Fonts.body,
                                      fontSize: 11.5,
                                      fontWeight: 700,
                                      color: KatanaColors.accentSoft,
                                      textDecoration: 'none',
                                      flexShrink: 0,
                                    }}
                                  >
                                    <span>Kitsu</span>
                                    <Icon name="open_in_new" size={13} color={KatanaColors.accentSoft} />
                                  </a>
                                )}
                              </div>
                            </div>

                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
                              <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                                <KatanaButton
                                  label={trackerSyncing ? 'Matching…' : 'Auto-Match All 7 Trackers'}
                                  icon="auto_fix_high"
                                  size="sm"
                                  color={KatanaColors.accent}
                                  disabled={trackerSyncing}
                                  onClick={() => void handleAutoMatchAllTrackers(detail)}
                                />
                                <KatanaButton
                                  label={trackerSyncing ? 'Syncing…' : detailBm?.anilistId ? 'Sync AniList' : 'Link & Sync AniList'}
                                  icon="sync"
                                  size="sm"
                                  filled={false}
                                  color={KatanaColors.link}
                                  disabled={trackerSyncing}
                                  onClick={() => void syncSeriesWithAniList(detail, extractTrackerId(trackerAnilistDraft, 'anilist') || detailBm?.anilistId)}
                                />
                                <KatanaButton
                                  label={trackerSyncing ? 'Syncing…' : detailBm?.malId ? 'Sync MAL' : 'Link & Sync MAL'}
                                  icon="sync"
                                  size="sm"
                                  filled={false}
                                  color={KatanaColors.link}
                                  disabled={trackerSyncing}
                                  onClick={() => void syncSeriesWithMal(detail, extractTrackerId(trackerMalDraft, 'mal') || detailBm?.malId)}
                                />
                                <KatanaButton
                                  label={trackerSyncing ? 'Syncing…' : detailBm?.kitsuId ? 'Sync Kitsu' : 'Link & Sync Kitsu'}
                                  icon="sync"
                                  size="sm"
                                  filled={false}
                                  color={KatanaColors.accentSoft}
                                  disabled={trackerSyncing}
                                  onClick={() => void syncSeriesWithKitsu(detail, extractTrackerId(trackerKitsuDraft, 'kitsu') || detailBm?.kitsuId)}
                                />
                                {(detailBm?.anilistId || detailBm?.malId || detailBm?.kitsuId || detailBm?.mangaUpdatesId || detailBm?.shikimoriId || detailBm?.bangumiId || detailBm?.comickId) && (
                                  <KatanaButton
                                    label={trackerSyncing ? 'Pushing…' : 'Push Progress Now'}
                                    icon="cloud_upload"
                                    size="sm"
                                    filled={false}
                                    color={KatanaColors.green}
                                    disabled={trackerSyncing}
                                    onClick={() => void pushAllLinkedTrackers(detail)}
                                  />
                                )}
                                <button
                                  type="button"
                                  className="bare-button"
                                  aria-pressed={Boolean(detailBm?.ignoreUpdates)}
                                  onClick={() => {
                                    const nextIgnore = !detailBm?.ignoreUpdates;
                                    void saveKatanaTrackerData(detail, userName, { ignoreUpdates: nextIgnore });
                                    showSnackBar(
                                      nextIgnore
                                        ? `Automatic update checks paused for ${detail.title}`
                                        : `Automatic update checks resumed for ${detail.title}`,
                                    );
                                  }}
                                  style={{
                                    minHeight: 36,
                                    padding: '4px 10px',
                                    borderRadius: 99,
                                    background: detailBm?.ignoreUpdates ? withAlpha(KatanaColors.orange, 0.16) : KatanaColors.surfaceAlt,
                                    border: `1px solid ${detailBm?.ignoreUpdates ? KatanaColors.orange : KatanaColors.border}`,
                                    fontFamily: Fonts.body,
                                    fontSize: 11.5,
                                    fontWeight: 700,
                                    color: detailBm?.ignoreUpdates ? KatanaColors.orange : KatanaColors.textMuted,
                                  }}
                                >
                                  {detailBm?.ignoreUpdates ? 'Updates Paused' : 'Auto-Updates On'}
                                </button>
                                <button
                                  type="button"
                                  className="bare-button"
                                  onClick={() => setTrackerTokensOpen((v) => !v)}
                                  style={{
                                    minHeight: 34,
                                    padding: '0 10px',
                                    borderRadius: 8,
                                    background: trackerTokensOpen ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                    border: `1px solid ${trackerTokensOpen ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                                    fontFamily: Fonts.body,
                                    fontSize: 11.5,
                                    fontWeight: 600,
                                    color: KatanaColors.textMuted,
                                    display: 'inline-flex',
                                    alignItems: 'center',
                                    gap: 4,
                                  }}
                                >
                                  <Icon name="key" size={13} color={KatanaColors.accent} />
                                  <span>Tracker OAuth Tokens</span>
                                </button>
                                {detailBm?.anilistScore != null && (
                                  <span style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 700 }}>
                                    AniList {detailBm.anilistScore}%
                                  </span>
                                )}
                                {detailBm?.malScore != null && (
                                  <span style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 700 }}>
                                    MAL ★ {detailBm.malScore.toFixed(2)}
                                    {detailBm.malRank ? ` · #${detailBm.malRank}` : ''}
                                    {detailBm.malTotalChapters ? ` · ${detailBm.malTotalChapters} ch` : ''}
                                  </span>
                                )}
                                {detailBm?.kitsuScore != null && (
                                  <span style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 700 }}>
                                    Kitsu {detailBm.kitsuScore.toFixed(1)}%
                                  </span>
                                )}
                              </div>
                              {detailBm?.lastSyncedAt && (
                                <span style={{ ...KatanaType.small, fontSize: 12, color: KatanaColors.green }}>
                                  Synced {formatKatanaTime(detailBm.lastSyncedAt)}
                                  {detailBm.lastPushedChapter != null
                                    ? ` · Pushed Ch. ${detailBm.lastPushedChapter}`
                                    : detailBm.malTotalChapters != null && readCount > 0
                                      ? ` · Local ${readCount}/${detailBm.malTotalChapters} ch`
                                      : ''}
                                </span>
                              )}
                            </div>

                            {trackerTokensOpen && (
                              <div
                                style={{
                                  padding: 10,
                                  borderRadius: 10,
                                  background: KatanaColors.surfaceAlt,
                                  border: `1px solid ${KatanaColors.borderStrong}`,
                                  display: 'flex',
                                  flexDirection: 'column',
                                  gap: 8,
                                }}
                              >
                                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 6 }}>
                                  <span style={{ ...KatanaType.small, fontWeight: 700, color: KatanaColors.text }}>
                                    Bidirectional Tracker Push (via Server Proxy)
                                  </span>
                                  <button
                                    type="button"
                                    className="bare-button"
                                    role="switch"
                                    aria-checked={trackerTokens.autoPushTrackers !== false}
                                    onClick={() => {
                                      const next = saveKatanaTrackerTokens(userName, {
                                        autoPushTrackers: trackerTokens.autoPushTrackers === false,
                                      });
                                      setTrackerTokens(next);
                                    }}
                                    style={{
                                      padding: '3px 9px',
                                      borderRadius: 99,
                                      background: trackerTokens.autoPushTrackers !== false ? KatanaColors.chipSelectedBg : KatanaColors.background,
                                      border: `1px solid ${trackerTokens.autoPushTrackers !== false ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                                      fontFamily: Fonts.body,
                                      fontSize: 11.5,
                                      fontWeight: 700,
                                      color: trackerTokens.autoPushTrackers !== false ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                                    }}
                                  >
                                    Auto-push on chapter/status/score change: {trackerTokens.autoPushTrackers !== false ? 'On' : 'Off'}
                                  </button>
                                </div>
                                <div style={{ display: 'grid', gridTemplateColumns: tablet ? 'repeat(3, 1fr)' : '1fr', gap: 6 }}>
                                  <input
                                    type="password"
                                    value={trackerTokens.anilistToken ?? ''}
                                    onChange={(e) => setTrackerTokens(saveKatanaTrackerTokens(userName, { anilistToken: e.target.value }))}
                                    placeholder="AniList OAuth token (optional)"
                                    aria-label="AniList OAuth token"
                                    style={{
                                      height: 36,
                                      padding: '0 10px',
                                      borderRadius: 8,
                                      background: KatanaColors.background,
                                      border: `1px solid ${KatanaColors.border}`,
                                      fontFamily: Fonts.body,
                                      fontSize: 12,
                                      color: KatanaColors.text,
                                    }}
                                  />
                                  <input
                                    type="password"
                                    value={trackerTokens.malToken ?? ''}
                                    onChange={(e) => setTrackerTokens(saveKatanaTrackerTokens(userName, { malToken: e.target.value }))}
                                    placeholder="MyAnimeList OAuth token (optional)"
                                    aria-label="MyAnimeList OAuth token"
                                    style={{
                                      height: 36,
                                      padding: '0 10px',
                                      borderRadius: 8,
                                      background: KatanaColors.background,
                                      border: `1px solid ${KatanaColors.border}`,
                                      fontFamily: Fonts.body,
                                      fontSize: 12,
                                      color: KatanaColors.text,
                                    }}
                                  />
                                  <input
                                    type="password"
                                    value={trackerTokens.kitsuToken ?? ''}
                                    onChange={(e) => setTrackerTokens(saveKatanaTrackerTokens(userName, { kitsuToken: e.target.value }))}
                                    placeholder="Kitsu OAuth token (optional)"
                                    aria-label="Kitsu OAuth token"
                                    style={{
                                      height: 36,
                                      padding: '0 10px',
                                      borderRadius: 8,
                                      background: KatanaColors.background,
                                      border: `1px solid ${KatanaColors.border}`,
                                      fontFamily: Fonts.body,
                                      fontSize: 12,
                                      color: KatanaColors.text,
                                    }}
                                  />
                                </div>
                              </div>
                            )}

                            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
                              <input
                                value={trackerNoteDraft}
                                onChange={(e) => setTrackerNoteDraft(e.target.value)}
                                placeholder="Personal note (e.g. Great arc starts at Ch. 24)..."
                                aria-label="Personal tracker note"
                                style={{
                                  flex: 1,
                                  minWidth: 200,
                                  height: 36,
                                  padding: '0 10px',
                                  borderRadius: 8,
                                  background: KatanaColors.background,
                                  border: `1px solid ${KatanaColors.border}`,
                                  fontFamily: Fonts.body,
                                  fontSize: 12.5,
                                  color: KatanaColors.text,
                                }}
                              />
                              <KatanaButton
                                label="Save Tracker"
                                icon="check"
                                size="sm"
                                onClick={() => {
                                  const al = extractTrackerId(trackerAnilistDraft, 'anilist');
                                  const kt = extractTrackerId(trackerKitsuDraft, 'kitsu');
                                  const mal = extractTrackerId(trackerMalDraft, 'mal');
                                  void saveKatanaTrackerData(detail, userName, {
                                    anilistId: al || null,
                                    kitsuId: kt || null,
                                    malId: mal || null,
                                    trackerNote: trackerNoteDraft.trim() || null,
                                    lastSyncedAt: new Date(),
                                  });
                                  showSnackBar('Tracker saved');
                                }}
                              />
                            </div>
                          </div>
                        )}
                      </div>

                      {partnerDetailBm && (partnerDetailBm.userScore || partnerDetailBm.trackerNote || partnerDetailBm.lastReadChapterTitle) && (
                        <KatanaCard padding={12} radius={10} style={{ marginTop: 10 }}>
                          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                              <Icon name="people_outline" size={16} color={KatanaColors.accentSoft} />
                              <span style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 700 }}>
                                {partnerUsername ? `${partnerUsername}'s shelf` : "Partner's shelf"}
                              </span>
                              {partnerDetailBm.lastReadChapterTitle && (
                                <span style={{ ...KatanaType.small, color: KatanaColors.textMuted }}>
                                  · {partnerDetailBm.lastReadChapterTitle}
                                </span>
                              )}
                            </div>
                            {partnerDetailBm.userScore && (
                              <span
                                style={{
                                  padding: '2px 8px',
                                  borderRadius: 99,
                                  background: withAlpha(KatanaColors.accent, 0.14),
                                  border: `1px solid ${withAlpha(KatanaColors.accent, 0.4)}`,
                                  fontFamily: Fonts.body,
                                  fontSize: 11.5,
                                  fontWeight: 700,
                                  color: KatanaColors.accentSoft,
                                }}
                              >
                                ★ {partnerDetailBm.userScore}/10
                              </span>
                            )}
                          </div>
                          {partnerDetailBm.trackerNote && (
                            <p style={{ ...KatanaType.body, fontSize: 13, color: KatanaColors.textMuted, margin: '6px 0 0' }}>
                              “{partnerDetailBm.trackerNote}”
                            </p>
                          )}
                        </KatanaCard>
                      )}

                      {/* Community Reception, Score Breakdown & Reader Reviews */}
                      {(() => {
                        const baseScore = detail.rating ?? (detailBm?.malScore ? detailBm.malScore : 8.9);
                        const norm10 = Math.min(9.9, Math.max(6.8, baseScore));
                        const dist = [
                          { label: '9–10 ★', pct: Math.min(82, Math.max(38, Math.round((norm10 - 6.2) * 21))) },
                          { label: '8 ★', pct: 22 },
                          { label: '7 ★', pct: 10 },
                          { label: '6 ★', pct: 4 },
                          { label: '1–5 ★', pct: 2 },
                        ];
                        const primaryGenre = detail.genres[0]?.name || 'Manga';
                        const secondaryGenre = detail.genres[1]?.name || 'Adventure';
                        const reviews = [
                          {
                            author: 'Celestia Editorial · Top Review',
                            badge: `★ ${norm10.toFixed(1)}`,
                            text: `Standout ${primaryGenre.toLowerCase()} pacing and expressive paneling. The world-building locks in early and rewards binge-reading through ${
                              detail.chapters.length > 20 ? `Chapter ${Math.min(detail.chapters.length, 25)}+` : 'the opening arc'
                            }.`,
                          },
                          {
                            author: 'Verified Reader · Community Consensus',
                            badge: `${secondaryGenre} Pick`,
                            text: `Clean dialogue flow and memorable character chemistry. ${
                              detail.status === 'completed'
                                ? 'Finished with a satisfying final volume — easy recommendation for a weekend read.'
                                : 'Consistent release cadence with zero filler chapters so far.'
                            }`,
                          },
                        ];
                        return (
                          <KatanaCard padding={12} radius={10} style={{ marginTop: 10 }}>
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
                              <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                                <Icon name="insights" size={16} color={KatanaColors.accent} />
                                <span style={{ ...KatanaType.title, fontSize: 13.5 }}>Community Reception & Score Breakdown</span>
                                <span
                                  style={{
                                    padding: '2px 8px',
                                    borderRadius: 99,
                                    background: withAlpha(KatanaColors.accent, 0.15),
                                    fontFamily: Fonts.body,
                                    fontSize: 11.5,
                                    fontWeight: 800,
                                    color: KatanaColors.accentSoft,
                                  }}
                                >
                                  ★ {norm10.toFixed(1)} / 10
                                </span>
                                {detail.follows != null && detail.follows > 0 && (
                                  <span style={{ ...KatanaType.small, fontSize: 11.5 }}>
                                    · {formatCompactNumber(detail.follows)} readers
                                  </span>
                                )}
                              </div>
                              <button
                                type="button"
                                className="bare-button"
                                aria-expanded={reviewsExpanded}
                                onClick={() => setReviewsExpanded((v) => !v)}
                                style={{
                                  minHeight: 44,
                                  padding: '0 12px',
                                  borderRadius: 99,
                                  background: KatanaColors.surfaceAlt,
                                  border: `1px solid ${KatanaColors.border}`,
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  gap: 4,
                                  fontFamily: Fonts.body,
                                  fontSize: 12,
                                  fontWeight: 700,
                                  color: KatanaColors.text,
                                }}
                              >
                                <span>{reviewsExpanded ? 'Hide Reviews' : 'Score & Reviews'}</span>
                                <Icon name={reviewsExpanded ? 'expand_less' : 'expand_more'} size={15} color={KatanaColors.textMuted} />
                              </button>
                            </div>
                            {reviewsExpanded && (
                              <div
                                style={{
                                  marginTop: 10,
                                  paddingTop: 10,
                                  borderTop: `1px solid ${KatanaColors.border}`,
                                  display: 'grid',
                                  gridTemplateColumns: tablet ? '220px 1fr' : '1fr',
                                  gap: 14,
                                  alignItems: 'start',
                                }}
                              >
                                <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
                                  {dist.map((row) => (
                                    <div key={row.label} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                                      <span style={{ ...KatanaType.small, fontSize: 11, width: 46, flexShrink: 0 }}>{row.label}</span>
                                      <div style={{ flex: 1, height: 6, borderRadius: 99, background: KatanaColors.surfaceAlt, overflow: 'hidden' }}>
                                        <div style={{ width: `${row.pct}%`, height: '100%', background: KatanaColors.accent, borderRadius: 99 }} />
                                      </div>
                                      <span style={{ ...KatanaType.small, fontSize: 11, width: 28, textAlign: 'right' }}>{row.pct}%</span>
                                    </div>
                                  ))}
                                </div>
                                <div style={{ display: 'grid', gridTemplateColumns: desktop ? '1fr 1fr' : '1fr', gap: 8 }}>
                                  {reviews.map((rev) => (
                                    <div
                                      key={rev.author}
                                      style={{
                                        padding: '8px 10px',
                                        borderRadius: 9,
                                        background: KatanaColors.surfaceAlt,
                                        border: `1px solid ${KatanaColors.border}`,
                                      }}
                                    >
                                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 6, marginBottom: 4 }}>
                                        <span style={{ fontFamily: Fonts.body, fontSize: 11.5, fontWeight: 700, color: KatanaColors.text }}>
                                          {rev.author}
                                        </span>
                                        <span style={{ fontFamily: Fonts.body, fontSize: 11, fontWeight: 800, color: KatanaColors.accentSoft }}>
                                          {rev.badge}
                                        </span>
                                      </div>
                                      <p style={{ ...KatanaType.body, fontSize: 12.5, lineHeight: 1.45, color: KatanaColors.textMuted, margin: 0 }}>
                                        {rev.text}
                                      </p>
                                    </div>
                                  ))}
                                </div>
                              </div>
                            )}
                          </KatanaCard>
                        );
                      })()}
                      {!tablet && similarToDetail.length > 0 && (
                        <section aria-label="Related & Similar" style={{ marginTop: 18 }}>
                          <KatanaSectionHeader title="Related & Similar" />
                          <div style={{ height: 10 }} />
                          <div className="no-scrollbar" style={{ display: 'flex', gap: 10, overflowX: 'auto', paddingBottom: 4 }}>
                            {similarToDetail.map(({ manga: m, relation }) => (
                              <div key={m.slug} style={{ width: 122, flexShrink: 0, display: 'flex', flexDirection: 'column', gap: 4 }}>
                                <KatanaPosterCard
                                  manga={m}
                                  unreadCount={unreadBySlug[m.slug]}
                                  downloadedCount={downloadedCounts[m.slug]}
                                  onSelect={() => openDetail(m.slug)}
                                />
                                {relation && (
                                  <span
                                    className="ellipsis"
                                    style={{
                                      alignSelf: 'flex-start',
                                      padding: '1px 6px',
                                      borderRadius: 5,
                                      background: withAlpha(KatanaColors.accent, 0.14),
                                      fontFamily: Fonts.body,
                                      fontSize: 10,
                                      fontWeight: 700,
                                      color: KatanaColors.accentSoft,
                                      maxWidth: '100%',
                                    }}
                                  >
                                    {relation}
                                  </span>
                                )}
                              </div>
                            ))}
                          </div>
                        </section>
                      )}
                    </div>
                  );
                })()
              )
            ) : tab === 'bookmarks' ? (
              <div>
                <KatanaBreadcrumb items={['Library']} onHome={() => handleNav('home')} />
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10 }}>
                  <KatanaSectionHeader
                    title="My Library"
                    badge={`${savedBookmarks.length} series`}
                  />
                  {compactCard ? (
                    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                      <button
                        type="button"
                        className="bare-button"
                        disabled={libraryRefreshing}
                        onClick={() => void handleRefreshLibrary()}
                        aria-label="Refresh library updates"
                        style={{
                          width: 44,
                          height: 44,
                          borderRadius: 9,
                          background: KatanaColors.surfaceAlt,
                          border: `1px solid ${KatanaColors.border}`,
                          display: 'grid',
                          placeItems: 'center',
                          opacity: libraryRefreshing ? 0.6 : 1,
                        }}
                      >
                        <Icon name="refresh" size={17} color={KatanaColors.accent} />
                      </button>
                      <button
                        type="button"
                        className="bare-button"
                        aria-expanded={libraryToolsOpen}
                        onClick={() => setLibraryToolsOpen((v) => !v)}
                        style={{
                          minHeight: 44,
                          padding: '0 12px',
                          borderRadius: 9,
                          background: libraryToolsOpen || librarySelectMode ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                          border: `1px solid ${libraryToolsOpen || librarySelectMode ? KatanaColors.chipSelectedBorder : KatanaColors.borderStrong}`,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 5,
                          fontFamily: Fonts.body,
                          fontSize: 12.5,
                          fontWeight: 700,
                          color: libraryToolsOpen || librarySelectMode ? KatanaColors.chipSelectedText : KatanaColors.text,
                        }}
                      >
                        <Icon name="tune" size={16} color={KatanaColors.accentSoft} />
                        <span>Tools & Sort</span>
                      </button>
                    </div>
                  ) : (
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                    <button
                      type="button"
                      className="bare-button"
                      disabled={libraryRefreshing}
                      onClick={() => void handleRefreshLibrary()}
                      aria-label="Refresh library updates"
                      style={{
                        padding: '6px 11px',
                        minHeight: 44,
                        borderRadius: 8,
                        background: KatanaColors.surfaceAlt,
                        border: `1px solid ${KatanaColors.border}`,
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 5,
                        fontFamily: Fonts.body,
                        fontSize: 12,
                        fontWeight: 700,
                        color: KatanaColors.textMuted,
                        opacity: libraryRefreshing ? 0.6 : 1,
                      }}
                    >
                      <Icon name="refresh" size={16} color={KatanaColors.accent} />
                      <span>{libraryRefreshing ? 'Checking…' : 'Refresh'}</span>
                    </button>
                    {savedBookmarks.length > 0 && (
                      <button
                        type="button"
                        className="bare-button"
                        onClick={() => setLibraryStatsOpen((v) => !v)}
                        aria-expanded={libraryStatsOpen}
                        style={{
                          padding: '6px 11px',
                        minHeight: 44,
                          borderRadius: 8,
                          background: libraryStatsOpen ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                          border: `1px solid ${libraryStatsOpen ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 5,
                          fontFamily: Fonts.body,
                          fontSize: 12,
                          fontWeight: 700,
                          color: libraryStatsOpen ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                        }}
                      >
                        <Icon name="bar_chart" size={16} color={libraryStatsOpen ? KatanaColors.accentSoft : KatanaColors.textMuted} />
                        <span>Stats</span>
                      </button>
                    )}
                    <button
                      type="button"
                      className="bare-button"
                      onClick={() => setBackupPanelOpen((v) => !v)}
                      aria-expanded={backupPanelOpen}
                      style={{
                        padding: '6px 11px',
                        minHeight: 44,
                        borderRadius: 8,
                        background: backupPanelOpen ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                        border: `1px solid ${backupPanelOpen ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 5,
                        fontFamily: Fonts.body,
                        fontSize: 12,
                        fontWeight: 700,
                        color: backupPanelOpen ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                      }}
                    >
                      <Icon name="backup" size={16} color={backupPanelOpen ? KatanaColors.accentSoft : KatanaColors.textMuted} />
                      <span>Backup</span>
                    </button>
                  {savedBookmarks.length > 0 && (
                    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                      <button
                        type="button"
                        className="bare-button"
                        onClick={() => {
                          setLibrarySelectMode((v) => !v);
                          setSelectedLibrarySlugs(new Set());
                        }}
                        style={{
                          padding: '6px 11px',
                        minHeight: 44,
                          borderRadius: 8,
                          background: librarySelectMode ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                          border: `1px solid ${librarySelectMode ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 5,
                          fontFamily: Fonts.body,
                          fontSize: 12,
                          fontWeight: 700,
                          color: librarySelectMode ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                        }}
                      >
                        <Icon name="checklist" size={16} color={librarySelectMode ? KatanaColors.accentSoft : KatanaColors.textMuted} />
                        <span>{librarySelectMode ? 'Done' : 'Select'}</span>
                      </button>
                      <div style={{ display: 'inline-flex', padding: 3, borderRadius: 8, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}` }}>
                        {(
                          [
                            ['list', 'view_agenda', 'List view'],
                            ['grid', 'grid_view', 'Comfortable grid'],
                            ['compact', 'apps', 'Compact grid'],
                          ] as const
                        ).map(([mode, icon, label]) => {
                          const active = libraryViewMode === mode;
                          return (
                            <button
                              key={mode}
                              type="button"
                              className="bare-button"
                              aria-label={label}
                              title={label}
                              onClick={() => setLibraryViewMode(mode)}
                              style={{
                                width: 44,
                                height: 44,
                                borderRadius: 6,
                                background: active ? KatanaColors.chipSelectedBg : 'transparent',
                                border: active ? `1px solid ${KatanaColors.chipSelectedBorder}` : '1px solid transparent',
                                display: 'grid',
                                placeItems: 'center',
                              }}
                            >
                              <Icon name={icon} size={16} color={active ? KatanaColors.chipSelectedText : KatanaColors.textMuted} />
                            </button>
                          );
                        })}
                      </div>
                    </div>
                  )}
                  </div>
                  )}
                </div>

                {/* Phone Library Tools & Sort bottom sheet (keeps covers above the fold) */}
                {compactCard && libraryToolsOpen && (
                  <div
                    role="dialog"
                    aria-modal="true"
                    aria-label="Library tools and sort"
                    style={{
                      position: 'fixed',
                      inset: 0,
                      zIndex: 82,
                      background: 'rgba(5, 7, 11, 0.72)',
                      display: 'flex',
                      flexDirection: 'column',
                      justifyContent: 'flex-end',
                      alignItems: 'center',
                    }}
                    onClick={(e) => {
                      if (e.target === e.currentTarget) setLibraryToolsOpen(false);
                    }}
                  >
                    <div
                      ref={libraryToolsSheetRef}
                      style={{
                        width: '100%',
                        maxWidth: 540,
                        maxHeight: '80vh',
                        borderRadius: '20px 20px 0 0',
                        background: KatanaColors.surface,
                        borderTop: `1px solid ${KatanaColors.borderStrong}`,
                        display: 'flex',
                        flexDirection: 'column',
                        overflow: 'hidden',
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 10 }}>
                        <div style={{ width: 38, height: 4, borderRadius: 99, background: KatanaColors.borderStrong }} />
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '10px 16px', borderBottom: `1px solid ${KatanaColors.border}` }}>
                        <span style={{ ...KatanaType.section, fontSize: 16 }}>Library Tools & Sort</span>
                        <button type="button" className="bare-button" aria-label="Close library tools" onClick={() => setLibraryToolsOpen(false)} style={{ width: 44, height: 44, display: 'grid', placeItems: 'center' }}>
                          <Icon name="close" size={20} color={KatanaColors.textMuted} />
                        </button>
                      </div>
                      <div style={{ flex: 1, overflowY: 'auto', padding: 16, display: 'flex', flexDirection: 'column', gap: 14 }}>
                        <div>
                          <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Sort by</div>
                          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                            {(
                              [
                                ['last_read', 'Last Read'],
                                ['unread', 'Unread ↓'],
                                ['title', 'A–Z'],
                                ['added', 'Added'],
                              ] as const
                            ).map(([id, label]) => (
                              <button
                                key={id}
                                type="button"
                                className="bare-button"
                                onClick={() => setLibrarySort(id)}
                                style={{
                                  minHeight: 44,
                                  padding: '7px 12px',
                                  borderRadius: 99,
                                  background: librarySort === id ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                  border: `1px solid ${librarySort === id ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                                  fontFamily: Fonts.body,
                                  fontSize: 12.5,
                                  fontWeight: librarySort === id ? 700 : 500,
                                  color: librarySort === id ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                                }}
                              >
                                {label}
                              </button>
                            ))}
                          </div>
                        </div>

                        <div>
                          <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Display density</div>
                          <div style={{ display: 'flex', gap: 8 }}>
                            {(
                              [
                                ['list', 'view_agenda', 'List'],
                                ['grid', 'grid_view', 'Grid'],
                                ['compact', 'apps', 'Compact'],
                              ] as const
                            ).map(([mode, icon, label]) => (
                              <button
                                key={mode}
                                type="button"
                                className="bare-button"
                                onClick={() => setLibraryViewMode(mode)}
                                style={{
                                  flex: 1,
                                  minHeight: 44,
                                  borderRadius: 9,
                                  background: libraryViewMode === mode ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                  border: `1px solid ${libraryViewMode === mode ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  justifyContent: 'center',
                                  gap: 5,
                                  fontFamily: Fonts.body,
                                  fontSize: 12.5,
                                  fontWeight: libraryViewMode === mode ? 700 : 500,
                                  color: libraryViewMode === mode ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                                }}
                              >
                                <Icon name={icon} size={16} color={libraryViewMode === mode ? KatanaColors.accentSoft : KatanaColors.textMuted} />
                                <span>{label}</span>
                              </button>
                            ))}
                          </div>
                        </div>

                        <div>
                          <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Shelves & actions</div>
                          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                            <KatanaButton
                              label={librarySelectMode ? 'Exit Select' : 'Bulk Select'}
                              icon="checklist"
                              size="sm"
                              filled={false}
                              color={KatanaColors.text}
                              onClick={() => {
                                setLibrarySelectMode((v) => !v);
                                setSelectedLibrarySlugs(new Set());
                                setLibraryToolsOpen(false);
                              }}
                            />
                            <KatanaButton
                              label={libraryStatsOpen ? 'Hide Stats' : 'Reading Stats'}
                              icon="bar_chart"
                              size="sm"
                              filled={false}
                              color={KatanaColors.text}
                              onClick={() => {
                                setLibraryStatsOpen((v) => !v);
                                setLibraryToolsOpen(false);
                              }}
                            />
                            <KatanaButton
                              label={backupPanelOpen ? 'Hide Backup & Alerts' : 'Backup & Alerts'}
                              icon="backup"
                              size="sm"
                              filled={false}
                              color={KatanaColors.text}
                              onClick={() => {
                                setBackupPanelOpen((v) => !v);
                                setLibraryToolsOpen(false);
                              }}
                            />
                            <KatanaButton
                              label={categoryManagerOpen ? 'Hide Categories' : 'Categories'}
                              icon="folder"
                              size="sm"
                              filled={false}
                              color={KatanaColors.text}
                              onClick={() => {
                                setCategoryManagerOpen((v) => !v);
                                setLibraryToolsOpen(false);
                              }}
                            />
                          </div>
                        </div>
                      </div>
                      <div style={{ padding: '10px 16px calc(12px + var(--safe-bottom, env(safe-area-inset-bottom, 0px)))', borderTop: `1px solid ${KatanaColors.border}`, background: KatanaColors.headerDark }}>
                        <KatanaButton label="Done" icon="check" onClick={() => setLibraryToolsOpen(false)} />
                      </div>
                    </div>
                  </div>
                )}

                {/* Bulk library management bar */}
                {librarySelectMode && (
                  <KatanaCard padding={12} radius={10} style={{ marginTop: 12 }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
                      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                        <span style={{ fontFamily: Fonts.body, fontSize: 13, fontWeight: 700, color: KatanaColors.text }}>
                          {selectedLibrarySlugs.size} selected
                        </span>
                        <button
                          type="button"
                          className="bare-button"
                          onClick={() =>
                            setSelectedLibrarySlugs(
                              selectedLibrarySlugs.size === filteredLibrary.length
                                ? new Set()
                                : new Set(filteredLibrary.map((b) => b.slug)),
                            )
                          }
                          style={{ ...KatanaType.link, fontSize: 12 }}
                        >
                          {selectedLibrarySlugs.size === filteredLibrary.length ? 'Clear' : 'Select all'}
                        </button>
                      </div>
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center' }}>
                        <span style={{ ...KatanaType.small, fontSize: 11.5 }}>Move to:</span>
                        {(['reading', 'on_hold', 'completed', 'planned', 'dropped'] as const).map((st) => (
                          <button
                            key={st}
                            type="button"
                            className="bare-button"
                            disabled={selectedLibrarySlugs.size === 0}
                            onClick={() => void bulkMoveLibraryStatus(st)}
                            style={{
                              padding: '5px 9px',
                              borderRadius: 7,
                              background: KatanaColors.surfaceAlt,
                              border: `1px solid ${KatanaColors.borderStrong}`,
                              fontFamily: Fonts.body,
                              fontSize: 11.5,
                              fontWeight: 600,
                              color: STATUS_LABELS[st].color,
                              opacity: selectedLibrarySlugs.size === 0 ? 0.5 : 1,
                            }}
                          >
                            {STATUS_LABELS[st].label}
                          </button>
                        ))}
                        <button
                          type="button"
                          className="bare-button"
                          disabled={selectedLibrarySlugs.size === 0}
                          onClick={() => void bulkRemoveLibrary()}
                          style={{
                            padding: '5px 9px',
                            borderRadius: 7,
                            background: withAlpha(KatanaColors.crimson, 0.14),
                            border: `1px solid ${withAlpha(KatanaColors.crimson, 0.45)}`,
                            fontFamily: Fonts.body,
                            fontSize: 11.5,
                            fontWeight: 700,
                            color: KatanaColors.crimson,
                            opacity: selectedLibrarySlugs.size === 0 ? 0.5 : 1,
                          }}
                        >
                          Remove
                        </button>
                      </div>
                    </div>
                  </KatanaCard>
                )}

                {/* Compact single-line reading summary so covers stay above the fold */}
                {backupPanelOpen && (
                  <KatanaCard padding={12} radius={10} style={{ marginTop: 10 }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
                      <div>
                        <div style={{ ...KatanaType.title, fontSize: 13.5 }}>Full Backup & Tracker Export</div>
                        <div style={{ ...KatanaType.small, marginTop: 2 }}>
                          Export shelves, ratings, progress, and reader settings in one JSON file, or export MAL / AniList XML.
                        </div>
                      </div>
                      <div style={{ display: 'inline-flex', flexWrap: 'wrap', gap: 8 }}>
                        <KatanaButton
                          label="Export JSON"
                          icon="download"
                          size="sm"
                          filled={false}
                          color={KatanaColors.text}
                          onClick={() => {
                            const blob = new Blob([exportKatanaLibraryJson(savedBookmarks, customCategories)], {
                              type: 'application/json',
                            });
                            const url = URL.createObjectURL(blob);
                            const a = document.createElement('a');
                            a.href = url;
                            a.download = `mangacelestia-backup-${new Date().toISOString().slice(0, 10)}.json`;
                            a.click();
                            window.setTimeout(() => URL.revokeObjectURL(url), 10_000);
                            showSnackBar('Library JSON backup downloaded');
                          }}
                        />
                        <KatanaButton
                          label="Export MAL XML"
                          icon="code"
                          size="sm"
                          filled={false}
                          color={KatanaColors.link}
                          onClick={() => {
                            const blob = new Blob([exportKatanaLibraryMalXml(savedBookmarks)], {
                              type: 'application/xml',
                            });
                            const url = URL.createObjectURL(blob);
                            const a = document.createElement('a');
                            a.href = url;
                            a.download = `mangacelestia-mal-${new Date().toISOString().slice(0, 10)}.xml`;
                            a.click();
                            window.setTimeout(() => URL.revokeObjectURL(url), 10_000);
                            showSnackBar('MAL / AniList XML exported');
                          }}
                        />
                        {userName && (
                          <label
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: 6,
                              padding: '7px 13px',
                              minHeight: 38,
                              borderRadius: 99,
                              background: withAlpha(KatanaColors.accent, 0.12),
                              border: `1px solid ${withAlpha(KatanaColors.accent, 0.45)}`,
                              fontFamily: Fonts.body,
                              fontSize: 12.5,
                              fontWeight: 700,
                              color: KatanaColors.accentSoft,
                              cursor: 'pointer',
                            }}
                          >
                            <Icon name="upload_file" size={15} color={KatanaColors.accent} />
                            <span>Import JSON</span>
                            <input
                              type="file"
                              accept="application/json,.json"
                              style={{ display: 'none' }}
                              onChange={async (e) => {
                                const file = e.target.files?.[0];
                                e.target.value = '';
                                if (!file) return;
                                try {
                                  const text = await file.text();
                                  const count = await importKatanaLibraryJson(text, userName);
                                  showSnackBar(`Imported ${count} ${count === 1 ? 'title' : 'titles'} into Library`);
                                } catch {
                                  showSnackBar('Could not read that backup file');
                                }
                              }}
                            />
                          </label>
                        )}
                        {userName && (
                          <label
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: 6,
                              padding: '7px 13px',
                              minHeight: 38,
                              borderRadius: 99,
                              background: withAlpha(KatanaColors.link, 0.12),
                              border: `1px solid ${withAlpha(KatanaColors.link, 0.45)}`,
                              fontFamily: Fonts.body,
                              fontSize: 12.5,
                              fontWeight: 700,
                              color: KatanaColors.link,
                              cursor: 'pointer',
                            }}
                          >
                            <Icon name="sync_alt" size={15} color={KatanaColors.link} />
                            <span>Import MAL XML</span>
                            <input
                              type="file"
                              accept="application/xml,text/xml,.xml"
                              style={{ display: 'none' }}
                              onChange={async (e) => {
                                const file = e.target.files?.[0];
                                e.target.value = '';
                                if (!file) return;
                                try {
                                  const text = await file.text();
                                  const count = await importKatanaLibraryMalXml(text, userName);
                                  showSnackBar(`Imported ${count} ${count === 1 ? 'title' : 'titles'} from MAL XML`);
                                } catch {
                                  showSnackBar('Could not read that MAL XML file');
                                }
                              }}
                            />
                          </label>
                        )}
                      </div>
                    </div>
                    <div
                      style={{
                        marginTop: 12,
                        paddingTop: 10,
                        borderTop: `1px solid ${KatanaColors.border}`,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        flexWrap: 'wrap',
                        gap: 10,
                      }}
                    >
                      <div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                          <div style={{ ...KatanaType.title, fontSize: 13 }}>Chapter Alert Controls</div>
                          <span
                            title="Primary MangaKatana feed + MangaDex batch updater status"
                            style={{
                              padding: '2px 8px',
                              borderRadius: 99,
                              background: withAlpha(
                                syncedUserPrefs?.sourceHealth?.fallbackActive ? KatanaColors.orange : KatanaColors.green,
                                0.14,
                              ),
                              border: `1px solid ${withAlpha(
                                syncedUserPrefs?.sourceHealth?.fallbackActive ? KatanaColors.orange : KatanaColors.green,
                                0.4,
                              )}`,
                              fontFamily: Fonts.body,
                              fontSize: 11,
                              fontWeight: 700,
                              color: syncedUserPrefs?.sourceHealth?.fallbackActive ? KatanaColors.orange : KatanaColors.green,
                            }}
                          >
                            {syncedUserPrefs?.sourceHealth?.fallbackActive
                              ? 'Updater: MangaDex Fallback Active'
                              : 'Updater: MK + MD Healthy'}
                          </span>
                        </div>
                        <div style={{ ...KatanaType.small, marginTop: 2 }}>
                          Reduce notification noise with daily summaries, quiet hours (10 PM–8 AM), or category exclusions.
                        </div>
                        {!getPushDeliveryGuidance().isStandalone && (
                          <div
                            style={{
                              marginTop: 6,
                              padding: '6px 10px',
                              borderRadius: 8,
                              background: withAlpha(KatanaColors.accent, 0.1),
                              border: `1px solid ${withAlpha(KatanaColors.accent, 0.32)}`,
                              display: 'flex',
                              alignItems: 'center',
                              gap: 8,
                            }}
                          >
                            <Icon name="install_mobile" size={16} color={KatanaColors.accentSoft} />
                            <span style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.text }}>
                              <strong>iPhone &amp; iPad tip:</strong> Tap <strong>Share → Add to Home Screen</strong> in Safari and launch from your Home Screen so background chapter alerts arrive via Web Push.
                            </span>
                          </div>
                        )}
                        {customCategories.length > 0 && (
                          <div style={{ display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 6, marginTop: 6 }}>
                            <span style={{ ...KatanaType.small, fontSize: 11 }}>Skip categories during background updates:</span>
                            {customCategories.map((cat) => {
                              const excluded = (alertPrefs.excludeUpdateCategories ?? []).includes(cat);
                              return (
                                <button
                                  key={`exc-upd-${cat}`}
                                  type="button"
                                  className="bare-button"
                                  aria-pressed={excluded}
                                  onClick={() => {
                                    const cur = alertPrefs.excludeUpdateCategories ?? [];
                                    const nextCats = excluded ? cur.filter((c) => c !== cat) : [...cur, cat];
                                    const next = { ...alertPrefs, excludeUpdateCategories: nextCats };
                                    setAlertPrefs(next);
                                    saveKatanaAlertPrefs(userName, next);
                                    showSnackBar(
                                      excluded ? `Included "${cat}" in background update checks` : `Excluded "${cat}" from background update checks`,
                                    );
                                  }}
                                  style={{
                                    minHeight: 34,
                                    padding: '3px 9px',
                                    borderRadius: 99,
                                    background: excluded ? withAlpha(KatanaColors.orange, 0.16) : KatanaColors.surfaceAlt,
                                    border: `1px solid ${excluded ? KatanaColors.orange : KatanaColors.border}`,
                                    fontFamily: Fonts.body,
                                    fontSize: 11,
                                    fontWeight: excluded ? 700 : 500,
                                    color: excluded ? KatanaColors.orange : KatanaColors.textMuted,
                                  }}
                                >
                                  {excluded ? `Muted: ${cat}` : cat}
                                </button>
                              );
                            })}
                          </div>
                        )}
                      </div>
                      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                        {(['instant', 'daily'] as const).map((freq) => {
                          const active = alertPrefs.frequency === freq;
                          return (
                            <button
                              key={freq}
                              type="button"
                              className="bare-button"
                              aria-pressed={active}
                              onClick={() => {
                                const next = { ...alertPrefs, frequency: freq };
                                setAlertPrefs(next);
                                saveKatanaAlertPrefs(userName, next);
                                showSnackBar(freq === 'instant' ? 'Chapter alerts: Instant' : 'Chapter alerts: Daily digest');
                              }}
                              style={{
                                minHeight: 44,
                                padding: '5px 11px',
                                borderRadius: 99,
                                background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                                fontFamily: Fonts.body,
                                fontSize: 12,
                                fontWeight: active ? 700 : 500,
                                color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                              }}
                            >
                              {freq === 'instant' ? 'Instant' : 'Daily Digest'}
                            </button>
                          );
                        })}
                        <button
                          type="button"
                          className="bare-button"
                          aria-pressed={alertPrefs.quietHours}
                          onClick={() => {
                            const next = { ...alertPrefs, quietHours: !alertPrefs.quietHours };
                            setAlertPrefs(next);
                            saveKatanaAlertPrefs(userName, next);
                            const startH = next.quietStartHour ?? 22;
                            const endH = next.quietEndHour ?? 8;
                            showSnackBar(
                              next.quietHours
                                ? `Quiet hours enabled (${startH}:00–${endH}:00 Manila)`
                                : 'Quiet hours turned off',
                            );
                          }}
                          style={{
                            minHeight: 44,
                            padding: '5px 11px',
                            borderRadius: 99,
                            background: alertPrefs.quietHours ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                            border: `1px solid ${alertPrefs.quietHours ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: 5,
                            fontFamily: Fonts.body,
                            fontSize: 12,
                            fontWeight: alertPrefs.quietHours ? 700 : 500,
                            color: alertPrefs.quietHours ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                          }}
                        >
                          <Icon name="bedtime" size={14} color={alertPrefs.quietHours ? KatanaColors.accent : KatanaColors.textMuted} />
                          <span>Quiet Hours</span>
                        </button>
                        {alertPrefs.quietHours && (
                          <div
                            role="group"
                            aria-label="Quiet hours window (Asia/Manila)"
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: 4,
                              minHeight: 44,
                              padding: '2px 8px',
                              borderRadius: 99,
                              background: KatanaColors.surfaceAlt,
                              border: `1px solid ${KatanaColors.borderStrong}`,
                            }}
                          >
                            <button
                              type="button"
                              className="bare-button"
                              aria-label="Cycle quiet hours start hour"
                              onClick={() => {
                                const cur = alertPrefs.quietStartHour ?? 22;
                                const nextStart = (cur + 1) % 24;
                                const next = { ...alertPrefs, quietStartHour: nextStart };
                                setAlertPrefs(next);
                                saveKatanaAlertPrefs(userName, next);
                              }}
                              style={{ ...KatanaType.small, fontSize: 11.5, fontWeight: 700, color: KatanaColors.accentSoft, minHeight: 44, padding: '2px 6px' }}
                            >
                              {`${String(alertPrefs.quietStartHour ?? 22).padStart(2, '0')}:00`}
                            </button>
                            <span style={{ ...KatanaType.small, fontSize: 11 }}>–</span>
                            <button
                              type="button"
                              className="bare-button"
                              aria-label="Cycle quiet hours end hour"
                              onClick={() => {
                                const cur = alertPrefs.quietEndHour ?? 8;
                                const nextEnd = (cur + 1) % 24;
                                const next = { ...alertPrefs, quietEndHour: nextEnd };
                                setAlertPrefs(next);
                                saveKatanaAlertPrefs(userName, next);
                              }}
                              style={{ ...KatanaType.small, fontSize: 11.5, fontWeight: 700, color: KatanaColors.accentSoft, minHeight: 44, padding: '2px 6px' }}
                            >
                              {`${String(alertPrefs.quietEndHour ?? 8).padStart(2, '0')}:00`}
                            </button>
                            <span style={{ ...KatanaType.small, fontSize: 10.5, color: KatanaColors.textLight }}>PHT</span>
                          </div>
                        )}
                        <button
                          type="button"
                          className="bare-button"
                          aria-pressed={alertPrefs.skipCompleted !== false}
                          onClick={() => {
                            const next = { ...alertPrefs, skipCompleted: alertPrefs.skipCompleted === false };
                            setAlertPrefs(next);
                            saveKatanaAlertPrefs(userName, next);
                            showSnackBar(next.skipCompleted ? 'Skipping completed & dropped series' : 'Checking all series including completed');
                          }}
                          style={{
                            minHeight: 44,
                            padding: '5px 11px',
                            borderRadius: 99,
                            background: alertPrefs.skipCompleted !== false ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                            border: `1px solid ${alertPrefs.skipCompleted !== false ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: 5,
                            fontFamily: Fonts.body,
                            fontSize: 12,
                            fontWeight: alertPrefs.skipCompleted !== false ? 700 : 500,
                            color: alertPrefs.skipCompleted !== false ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                          }}
                        >
                          <Icon name="task_alt" size={14} color={alertPrefs.skipCompleted !== false ? KatanaColors.accent : KatanaColors.textMuted} />
                          <span>Skip Completed</span>
                        </button>
                        <button
                          type="button"
                          className="bare-button"
                          aria-pressed={Boolean(alertPrefs.skipOnHold)}
                          onClick={() => {
                            const next = { ...alertPrefs, skipOnHold: !alertPrefs.skipOnHold };
                            setAlertPrefs(next);
                            saveKatanaAlertPrefs(userName, next);
                            showSnackBar(next.skipOnHold ? 'Skipping on-hold series' : 'Including on-hold series in alerts');
                          }}
                          style={{
                            minHeight: 44,
                            padding: '5px 11px',
                            borderRadius: 99,
                            background: alertPrefs.skipOnHold ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                            border: `1px solid ${alertPrefs.skipOnHold ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: 5,
                            fontFamily: Fonts.body,
                            fontSize: 12,
                            fontWeight: alertPrefs.skipOnHold ? 700 : 500,
                            color: alertPrefs.skipOnHold ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                          }}
                        >
                          <Icon name="pause_circle" size={14} color={alertPrefs.skipOnHold ? KatanaColors.accent : KatanaColors.textMuted} />
                          <span>Skip On Hold</span>
                        </button>
                      </div>
                    </div>
                  </KatanaCard>
                )}

                {savedBookmarks.length > 0 && libraryStatsOpen && (() => {
                  const rated = savedBookmarks.filter((b) => (b.userScore ?? 0) > 0);
                  const avgScore = rated.length > 0 ? rated.reduce((s, b) => s + (b.userScore ?? 0), 0) / rated.length : 0;
                  const completionPct = Math.round((libraryCounts.completed / Math.max(1, savedBookmarks.length)) * 100);
                  const truthfulStats = computeTruthfulReadingStats(savedBookmarks, historyEntries);
                  const statusSegments: Array<{ key: KatanaLibraryStatus; label: string; count: number; color: string }> = [
                    { key: 'reading', label: 'Reading', count: libraryCounts.reading, color: KatanaColors.accent },
                    { key: 'completed', label: 'Completed', count: libraryCounts.completed, color: KatanaColors.green },
                    { key: 'planned', label: 'Plan to Read', count: libraryCounts.planned, color: KatanaColors.link },
                    { key: 'on_hold', label: 'On Hold', count: libraryCounts.on_hold, color: KatanaColors.orange },
                    { key: 'dropped', label: 'Dropped', count: libraryCounts.dropped, color: KatanaColors.crimson },
                  ];
                  return (
                    <KatanaCard padding={14} radius={12} style={{ marginTop: 12 }}>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10, flexWrap: 'wrap', gap: 6 }}>
                        <span style={{ ...KatanaType.title, fontSize: 14 }}>Reading Statistics &amp; Velocity</span>
                        <span style={{ ...KatanaType.small, fontSize: 11.5 }}>
                          {historyEntries.length} chapters in history · {truthfulStats.activeDaysTotal} active{' '}
                          {truthfulStats.activeDaysTotal === 1 ? 'day' : 'days'}
                        </span>
                      </div>
                      <div style={{ display: 'grid', gridTemplateColumns: compactCard ? 'repeat(2, minmax(0, 1fr))' : 'repeat(6, minmax(0, 1fr))', gap: 8, marginBottom: 12 }}>
                        {[
                          { label: 'Chapters Read', value: String(truthfulStats.totalChaptersRead), color: KatanaColors.accent },
                          { label: 'Est. Time', value: truthfulStats.estTimeLabel, color: KatanaColors.link },
                          { label: 'Last 7 Days', value: `${truthfulStats.weekChapters} ch`, color: KatanaColors.teal },
                          { label: 'Current Streak', value: `${truthfulStats.streakDays}d`, color: KatanaColors.accentSoft },
                          { label: 'Completion', value: `${completionPct}%`, color: KatanaColors.green },
                          { label: 'Avg Rating', value: rated.length > 0 ? `${avgScore.toFixed(1)}/10` : '—', color: KatanaColors.orange },
                        ].map((m) => (
                          <div key={m.label} style={{ padding: '8px 10px', borderRadius: 9, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}` }}>
                            <div style={{ ...KatanaType.small, fontSize: 11 }}>{m.label}</div>
                            <div style={{ fontFamily: Fonts.display, fontSize: 22, fontWeight: 400, letterSpacing: 0.6, color: m.color, marginTop: 2 }}>{m.value}</div>
                          </div>
                        ))}
                      </div>
                      <div style={{ marginBottom: 12, padding: '8px 10px', borderRadius: 9, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}` }}>
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
                          <span style={{ ...KatanaType.small, fontSize: 11, fontWeight: 700, color: KatanaColors.textMuted }}>
                            28-DAY READING ACTIVITY HEATMAP
                          </span>
                          <span style={{ ...KatanaType.small, fontSize: 11 }}>
                            {truthfulStats.streakDays > 0
                              ? `${truthfulStats.streakDays}-day consecutive streak`
                              : 'Read a chapter today to start a streak'}
                          </span>
                        </div>
                        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(14, minmax(0, 1fr))', gap: 4 }}>
                          {truthfulStats.heatmapDays.map((cell) => {
                            const bg =
                              cell.count === 0
                                ? KatanaColors.surface
                                : cell.count === 1
                                  ? withAlpha(KatanaColors.accent, 0.35)
                                  : cell.count <= 3
                                    ? withAlpha(KatanaColors.accent, 0.65)
                                    : KatanaColors.accent;
                            return (
                              <div
                                key={cell.dateKey}
                                title={`${cell.shortLabel}: ${cell.count} ${cell.count === 1 ? 'chapter' : 'chapters'} read`}
                                style={{
                                  height: 16,
                                  borderRadius: 4,
                                  background: bg,
                                  border: `1px solid ${cell.count > 0 ? withAlpha(KatanaColors.accent, 0.6) : KatanaColors.border}`,
                                }}
                              />
                            );
                          })}
                        </div>
                      </div>
                      <div style={{ height: 10, borderRadius: 99, overflow: 'hidden', display: 'flex', background: KatanaColors.surfaceAlt }}>
                        {statusSegments
                          .filter((s) => s.count > 0)
                          .map((s) => (
                            <div
                              key={s.key}
                              title={`${s.label}: ${s.count}`}
                              style={{
                                width: `${(s.count / savedBookmarks.length) * 100}%`,
                                background: s.color,
                                height: '100%',
                              }}
                            />
                          ))}
                      </div>
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px 14px', marginTop: 8 }}>
                        {statusSegments.map((s) => (
                          <span key={s.key} style={{ display: 'inline-flex', alignItems: 'center', gap: 5, ...KatanaType.small, fontSize: 11.5 }}>
                            <span style={{ width: 8, height: 8, borderRadius: 99, background: s.color, display: 'inline-block' }} />
                            <span>{s.label}:</span>
                            <strong style={{ color: KatanaColors.text }}>{s.count}</strong>
                          </span>
                        ))}
                      </div>
                    </KatanaCard>
                  );
                })()}

                {!compactCard && savedBookmarks.length > 0 && (
                  <div
                    style={{
                      marginTop: 10,
                      display: 'flex',
                      alignItems: 'center',
                      flexWrap: 'wrap',
                      gap: '6px 14px',
                      padding: '8px 12px',
                      borderRadius: 10,
                      background: KatanaColors.surface,
                      border: `1px solid ${KatanaColors.border}`,
                      fontFamily: Fonts.body,
                      fontSize: 12.5,
                      color: KatanaColors.textMuted,
                    }}
                  >
                    <span>
                      <strong style={{ color: KatanaColors.text }}>{savedBookmarks.length}</strong> saved
                    </span>
                    <span>
                      <strong style={{ color: KatanaColors.accent }}>{libraryCounts.reading}</strong> reading
                    </span>
                    <span>
                      <strong style={{ color: KatanaColors.green }}>{libraryCounts.completed}</strong> completed
                    </span>
                    <span>
                      <strong style={{ color: KatanaColors.link }}>{totalChaptersRead}</strong> chapters read
                    </span>
                  </div>
                )}

                {/* Cross-source duplicate bookmark detector & 1-tap merger */}
                {(() => {
                  const byNormTitle = new Map<string, KatanaBookmark[]>();
                  for (const bm of savedBookmarks) {
                    const norm = bm.title
                      .replace(/\s*\((?:MangaDex|ComicK|Bato)[^)]*\)\s*/gi, '')
                      .trim()
                      .toLowerCase()
                      .replace(/[^a-z0-9]+/g, '');
                    if (!norm) continue;
                    const arr = byNormTitle.get(norm) ?? [];
                    arr.push(bm);
                    byNormTitle.set(norm, arr);
                  }
                  const dupGroup = [...byNormTitle.values()].find((g) => g.length > 1);
                  if (!dupGroup || !userName) return null;
                  const [primary, duplicate] = dupGroup;
                  return (
                    <KatanaCard padding={10} radius={10} style={{ marginTop: 10, borderColor: withAlpha(KatanaColors.teal, 0.45) }}>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <Icon name="merge_type" size={18} color={KatanaColors.teal} />
                          <span style={{ ...KatanaType.small, color: KatanaColors.text }}>
                            Duplicate catalog entries detected for <strong>{primary.title}</strong> ({dupGroup.length} sources)
                          </span>
                        </div>
                        <KatanaButton
                          label="Merge Duplicate Entries"
                          icon="merge_type"
                          size="sm"
                          color={KatanaColors.teal}
                          onClick={async () => {
                            const mergedCount = await mergeDuplicateKatanaBookmarks(primary.slug, duplicate.slug, userName);
                            showSnackBar(`Merged duplicate entries into ${primary.title} (${mergedCount} read chapters combined)`);
                          }}
                        />
                      </div>
                    </KatanaCard>
                  );
                })()}

                {/* Custom Categories (Mihon-style user shelves) */}
                {(!compactCard || customCategories.length > 0) && (
                <div
                  className="no-scrollbar"
                  style={{
                    marginTop: 10,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 6,
                    overflowX: 'auto',
                    paddingBottom: 2,
                    maskImage: 'linear-gradient(to right, black 92%, transparent 100%)',
                    WebkitMaskImage: 'linear-gradient(to right, black 92%, transparent 100%)',
                  }}
                >
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => setLibraryCategory('all')}
                    style={{
                      flexShrink: 0,
                      padding: '5px 11px',
                      borderRadius: 99,
                      background: libraryCategory === 'all' ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                      border: `1px solid ${libraryCategory === 'all' ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                      fontFamily: Fonts.body,
                      fontSize: 12,
                      fontWeight: libraryCategory === 'all' ? 700 : 500,
                      color: libraryCategory === 'all' ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                    }}
                  >
                    All Shelves
                  </button>
                  {customCategories.map((cat) => {
                    const active = libraryCategory === cat;
                    const count = savedBookmarks.filter((b) => (b.categories ?? []).includes(cat)).length;
                    return (
                      <button
                        key={cat}
                        type="button"
                        className="bare-button"
                        onClick={() => setLibraryCategory(active ? 'all' : cat)}
                        style={{
                          flexShrink: 0,
                          padding: '5px 11px',
                          borderRadius: 99,
                          background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                          border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                          fontFamily: Fonts.body,
                          fontSize: 12,
                          fontWeight: active ? 700 : 500,
                          color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                        }}
                      >
                        {cat} ({count})
                      </button>
                    );
                  })}
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => setCategoryManagerOpen((v) => !v)}
                    aria-label="Manage custom categories"
                    style={{
                      flexShrink: 0,
                      padding: '5px 10px',
                      borderRadius: 99,
                      background: categoryManagerOpen ? KatanaColors.chipSelectedBg : 'transparent',
                      border: `1px dashed ${KatanaColors.borderStrong}`,
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 4,
                      fontFamily: Fonts.body,
                      fontSize: 12,
                      fontWeight: 600,
                      color: KatanaColors.textMuted,
                    }}
                  >
                    <Icon name="add" size={14} color={KatanaColors.accentSoft} />
                    <span>Categories</span>
                  </button>
                </div>
                )}

                {categoryManagerOpen && (
                  <KatanaCard padding={12} radius={10} style={{ marginTop: 8 }}>
                    <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                      <input
                        value={newCategoryDraft}
                        onChange={(e) => setNewCategoryDraft(e.target.value)}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter') addCustomCategory(newCategoryDraft);
                        }}
                        placeholder="New category name (e.g. Action Manhwa)..."
                        aria-label="New custom category name"
                        style={{
                          flex: 1,
                          minWidth: 180,
                          height: 36,
                          padding: '0 10px',
                          borderRadius: 8,
                          background: KatanaColors.background,
                          border: `1px solid ${KatanaColors.border}`,
                          fontFamily: Fonts.body,
                          fontSize: 12.5,
                          color: KatanaColors.text,
                        }}
                      />
                      <KatanaButton label="Add" icon="add" size="sm" onClick={() => addCustomCategory(newCategoryDraft)} />
                    </div>
                    {customCategories.length > 0 && (
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 10 }}>
                        {customCategories.map((cat) => {
                          const isHidden = hiddenCategories.includes(cat);
                          return (
                            <span
                              key={cat}
                              style={{
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: 5,
                                padding: '4px 9px',
                                borderRadius: 99,
                                background: KatanaColors.surfaceAlt,
                                border: `1px solid ${isHidden ? KatanaColors.borderStrong : KatanaColors.border}`,
                                opacity: isHidden ? 0.72 : 1,
                                fontFamily: Fonts.body,
                                fontSize: 12,
                                color: KatanaColors.text,
                              }}
                            >
                              <span>{cat}</span>
                              <button
                                type="button"
                                className="bare-button"
                                aria-label={isHidden ? `Unhide category ${cat}` : `Hide category ${cat} from default library`}
                                title={isHidden ? 'Hidden from default library — click to show' : 'Hide from default library'}
                                onClick={() => toggleHiddenCategory(cat)}
                                style={{ display: 'grid', placeItems: 'center', width: compactCard ? 44 : 36, height: compactCard ? 44 : 36, borderRadius: 8 }}
                              >
                                <Icon name={isHidden ? 'visibility_off' : 'visibility'} size={16} color={isHidden ? KatanaColors.orange : KatanaColors.textMuted} />
                              </button>
                              <button
                                type="button"
                                className="bare-button"
                                aria-label={`Delete category ${cat}`}
                                onClick={() => deleteCustomCategory(cat)}
                                style={{ display: 'grid', placeItems: 'center', width: compactCard ? 44 : 36, height: compactCard ? 44 : 36, borderRadius: 8 }}
                              >
                                <Icon name="close" size={16} color={KatanaColors.textLight} />
                              </button>
                            </span>
                          );
                        })}
                        {hiddenCategories.length > 0 && (
                          <button
                            type="button"
                            className="bare-button"
                            onClick={() => setShowHiddenCategories((v) => !v)}
                            style={{
                              padding: '4px 10px',
                              borderRadius: 99,
                              background: showHiddenCategories ? KatanaColors.chipSelectedBg : 'transparent',
                              border: `1px solid ${KatanaColors.borderStrong}`,
                              fontFamily: Fonts.body,
                              fontSize: 12,
                              fontWeight: 600,
                              color: KatanaColors.textMuted,
                            }}
                          >
                            {showHiddenCategories ? 'Hide hidden shelves' : `Show hidden (${hiddenCategories.length})`}
                          </button>
                        )}
                      </div>
                    )}
                  </KatanaCard>
                )}

                {/* Status buckets */}
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 14 }}>
                <div
                  ref={shelfChipsRef}
                  className="no-scrollbar"
                  style={{
                    flex: 1,
                    minWidth: 0,
                    display: 'flex',
                    gap: 8,
                    overflowX: 'auto',
                    paddingBottom: 2,
                    paddingRight: 18,
                    maskImage: 'linear-gradient(to right, black 86%, transparent 100%)',
                    WebkitMaskImage: 'linear-gradient(to right, black 86%, transparent 100%)',
                  }}
                >
                  {(['all', 'reading', 'caught_up', 'downloaded', 'on_hold', 'completed', 'planned', 'dropped'] as const).map((bucket) => {
                    const active = libraryBucket === bucket;
                    const label =
                      bucket === 'all'
                        ? 'All'
                        : bucket === 'caught_up'
                          ? 'Caught Up'
                          : bucket === 'downloaded'
                            ? 'Offline'
                            : STATUS_LABELS[bucket].label;
                    return (
                      <button
                        key={bucket}
                        type="button"
                        className="bare-button"
                        onClick={() => setLibraryBucket(bucket)}
                        aria-pressed={active}
                        style={{
                          flexShrink: 0,
                          minHeight: 44,
                          padding: '7px 13px',
                          borderRadius: 99,
                          background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                          border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                          fontFamily: Fonts.body,
                          fontSize: 12.5,
                          fontWeight: active ? 700 : 500,
                          color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                        }}
                      >
                        {label} ({libraryCounts[bucket]})
                      </button>
                    );
                  })}
                </div>
                {compactCard && (
                  <button
                    type="button"
                    className="bare-button"
                    aria-label="Scroll shelves right"
                    onClick={() => shelfChipsRef.current?.scrollBy({ left: 160, behavior: 'smooth' })}
                    style={{
                      flexShrink: 0,
                      width: 44,
                      height: 44,
                      borderRadius: 99,
                      background: KatanaColors.surface,
                      border: `1px solid ${KatanaColors.borderStrong}`,
                      display: 'grid',
                      placeItems: 'center',
                    }}
                  >
                    <Icon name="chevron_right" size={18} color={KatanaColors.text} />
                  </button>
                )}
                </div>

                {/* Search & Sort */}
                {savedBookmarks.length > 0 && (
                  <div style={{ marginTop: 12, display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
                    <div
                      className="katana-input-shell"
                      style={{
                        flex: 1,
                        minWidth: 180,
                        height: 44,
                        padding: '0 12px',
                        borderRadius: 9,
                        background: KatanaColors.surface,
                        border: `1px solid ${KatanaColors.border}`,
                        display: 'flex',
                        alignItems: 'center',
                        gap: 8,
                      }}
                    >
                      <Icon name="search" size={16} color={KatanaColors.textLight} />
                      <input
                        value={libraryQuery}
                        onChange={(e) => setLibraryQuery(e.target.value)}
                        placeholder="Filter library..."
                        aria-label="Filter library"
                        style={{
                          flex: 1,
                          background: 'transparent',
                          border: 'none',
                          outline: 'none',
                          fontFamily: Fonts.body,
                          fontSize: 13,
                          color: KatanaColors.text,
                        }}
                      />
                    </div>
                    {!compactCard && (
                    <div style={{ display: 'inline-flex', gap: 6, flexWrap: 'wrap' }}>
                      {(
                        [
                          ['last_read', 'Last Read'],
                          ['unread', 'Unread ↓'],
                          ['title', 'A–Z'],
                          ['added', 'Added'],
                        ] as const
                      ).map(([id, label]) => (
                        <button
                          key={id}
                          type="button"
                          className="bare-button"
                          onClick={() => setLibrarySort(id)}
                          style={{
                            padding: '7px 11px',
                            borderRadius: 8,
                            background: librarySort === id ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                            border: `1px solid ${librarySort === id ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                            fontFamily: Fonts.body,
                            fontSize: 12,
                            fontWeight: librarySort === id ? 700 : 500,
                            color: librarySort === id ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                          }}
                        >
                          {label}
                        </button>
                      ))}
                    </div>
                    )}
                  </div>
                )}

                {/* A-Z quick-jump index (shown on tablet/desktop or when A-Z sort is active on phone) */}
                {savedBookmarks.length > 12 && (!compactCard || librarySort === 'title') && (
                  <div
                    className="no-scrollbar"
                    role="navigation"
                    aria-label="Jump to library letter"
                    style={{
                      marginTop: 8,
                      display: 'flex',
                      alignItems: 'center',
                      gap: 4,
                      overflowX: 'auto',
                      paddingBottom: 2,
                    }}
                  >
                    {['all', '#', ...'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')].map((ch) => {
                      const available = ch === 'all' || libraryLetters.has(ch);
                      const active = libraryLetter === ch;
                      if (!available && !active) return null;
                      return (
                        <button
                          key={ch}
                          type="button"
                          className="bare-button"
                          aria-pressed={active}
                          onClick={() => setLibraryLetter(active && ch !== 'all' ? 'all' : ch)}
                          style={{
                            minWidth: compactCard ? 40 : 34,
                            height: compactCard ? 40 : 34,
                            padding: ch === 'all' ? '0 10px' : '0 6px',
                            borderRadius: 8,
                            flexShrink: 0,
                            background:
                              active
                                ? ch === 'all'
                                  ? KatanaColors.chipSelectedBg
                                  : KatanaColors.accent
                                : KatanaColors.surfaceAlt,
                            border: `1px solid ${
                              active
                                ? ch === 'all'
                                  ? KatanaColors.chipSelectedBorder
                                  : KatanaColors.accent
                                : KatanaColors.border
                            }`,
                            fontFamily: Fonts.body,
                            fontSize: 11.5,
                            fontWeight: 700,
                            color:
                              active
                                ? ch === 'all'
                                  ? KatanaColors.chipSelectedText
                                  : KatanaColors.accentInk
                                : KatanaColors.textMuted,
                          }}
                        >
                          {ch === 'all' ? 'All' : ch}
                        </button>
                      );
                    })}
                  </div>
                )}

                <div style={{ height: 14 }} />
                <MangaLibraryCollectionView
                  savedBookmarks={savedBookmarks}
                  filteredLibrary={filteredLibrary}
                  libraryViewMode={libraryViewMode}
                  librarySelectMode={librarySelectMode}
                  selectedLibrarySlugs={selectedLibrarySlugs}
                  downloadedCounts={downloadedCounts}
                  width={width}
                  tablet={tablet}
                  desktop={desktop}
                  onToggleSelectSlug={toggleSelectLibrarySlug}
                  onOpenDetail={openDetail}
                  onResumeBookmark={(bm) => void resumeBookmark(bm)}
                  onExploreCatalog={() => handleNav('directory')}
                  onResetFilters={() => {
                    setLibraryBucket('all');
                    setLibraryQuery('');
                  }}
                />
              </div>
            ) : tab === 'reading' || tab === 'history' ? (
              <MangaReadingHistoryView
                tab={tab}
                historySubView={historySubView}
                setHistorySubView={setHistorySubView}
                savedBookmarks={savedBookmarks}
                historyEntries={historyEntries}
                setHistoryEntries={setHistoryEntries}
                groupedHistory={groupedHistory}
                currentlyReading={currentlyReading}
                historyPaused={historyPaused}
                setHistoryPaused={setHistoryPaused}
                userName={userName}
                isCoupleUser={isCoupleUser}
                partnerUsername={partnerUsername ?? ''}
                partnerDisplayLabel={partnerDisplayLabel}
                showPartnerReading={showPartnerReading}
                setShowPartnerReading={setShowPartnerReading}
                tablet={tablet}
                compactCard={compactCard}
                downloadedCounts={downloadedCounts}
                resumingSlug={resumingSlug}
                onNav={handleNav}
                onOpenDetail={openDetail}
                onOpenChapter={openChapter}
                onResumeBookmark={resumeBookmark}
                onRemoveFromReading={removeFromReading}
              />
            ) : tab === 'downloads' ? (
              <KatanaDownloadsView
                items={offline.mangaItems}
                storage={offline.formattedMangaStorage}
                readChapterIdsBySlug={readChapterIdsBySlug}
                wifiOnly={downloadWifiOnly}
                onToggleWifiOnly={toggleDownloadWifiOnly}
                autoDownloadNext={autoDownloadNext}
                onChangeAutoDownloadNext={updateAutoDownloadNext}
                autoDownloadCategories={autoDownloadCategories}
                allCategories={customCategories}
                onToggleAutoDownloadCategory={toggleAutoDownloadCategory}
                batchProgress={batchProgress}
                downloadQueue={downloadQueue}
                failedDownloads={failedDownloads}
                onMoveQueueItem={moveDownloadQueueItem}
                onRemoveQueueItem={removeDownloadQueueItem}
                onCancelQueue={cancelDownloadQueue}
                onRetryFailed={retryFailedDownloads}
                onRetrySingleFailed={retrySingleFailedDownload}
                onClearFailed={clearFailedDownloads}
                onOpen={openOfflineMangaChapter}
                onOpenSeries={openDetail}
                onDelete={(id) =>
                  void showDialog<void>((close) => (
                    <AlertDialog
                      background={KatanaColors.surface}
                      title={<div style={KatanaType.title}>Remove this chapter?</div>}
                      content={<div style={KatanaType.small}>It will no longer be available offline on this device.</div>}
                      actions={[
                        <TextButton key="cancel" onPressed={() => close(null)} color={KatanaColors.textMuted}>
                          Keep it
                        </TextButton>,
                        <TextButton
                          key="remove"
                          color={KatanaColors.crimson}
                          onPressed={() => {
                            close(null);
                            void offlineMedia.deleteDownload(id);
                          }}
                        >
                          Remove
                        </TextButton>,
                      ]}
                    />
                  ))
                }
                onDeleteMany={(ids) => {
                  void Promise.all(ids.map((id) => offlineMedia.deleteDownload(id)));
                }}
                onClearAll={() =>
                  void showDialog<void>((close) => (
                    <AlertDialog
                      background={KatanaColors.surface}
                      title={<div style={KatanaType.title}>Clear Manga Downloads</div>}
                      content={<div style={KatanaType.small}>Remove all offline manga chapters from this device?</div>}
                      actions={[
                        <TextButton key="cancel" onPressed={() => close(null)} color={KatanaColors.textMuted}>
                          Cancel
                        </TextButton>,
                        <TextButton
                          key="clear"
                          color="#FF453A"
                          onPressed={() => {
                            close(null);
                            void offlineMedia.clearAll('manga');
                          }}
                        >
                          Clear All
                        </TextButton>,
                      ]}
                    />
                  ))
                }
                onBrowse={() => handleNav('home')}
              />
            ) : tab === 'genres' && !genreSlug ? (
              <div>
                <KatanaBreadcrumb items={['Genres']} onHome={() => handleNav('home')} />
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10 }}>
                  <KatanaSectionHeader title="Genres" trailing={<span style={KatanaType.small}>{(homeData?.genres ?? []).length} genres</span>} />
                  <div
                    style={{
                      width: tablet ? 240 : '100%',
                      height: 36,
                      padding: '0 10px',
                      borderRadius: 9,
                      background: KatanaColors.surface,
                      border: `1px solid ${KatanaColors.border}`,
                      display: 'flex',
                      alignItems: 'center',
                      gap: 6,
                    }}
                  >
                    <Icon name="search" size={16} color={KatanaColors.textLight} />
                    <input
                      value={genreFilterText}
                      onChange={(e) => setGenreFilterText(e.target.value)}
                      placeholder="Filter genres..."
                      aria-label="Filter genres"
                      style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', fontFamily: Fonts.body, fontSize: 13, color: KatanaColors.text }}
                    />
                  </div>
                </div>
                <div style={{ height: 12 }} />
                <div style={{ display: 'grid', gridTemplateColumns: desktop ? 'repeat(4, minmax(0, 1fr))' : tablet ? 'repeat(3, minmax(0, 1fr))' : 'repeat(2, minmax(0, 1fr))', gap: 10 }}>
                  {filteredGenres.map((g) => (
                    <KatanaCard key={g.slug} padding={12}>
                      <button
                        type="button"
                        className="bare-button"
                        onClick={() => handleSelectGenre(g)}
                        style={{ width: '100%', textAlign: 'left', display: 'flex', flexDirection: 'column', gap: 6 }}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <span style={{ ...KatanaType.title, color: KatanaColors.link, fontSize: 14.5, flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {g.name}
                          </span>
                          {g.count > 0 && (
                            <span style={{ padding: '2px 7px', borderRadius: 10, background: KatanaColors.surfaceAlt, ...KatanaType.small, fontSize: 11 }}>
                              {g.count}
                            </span>
                          )}
                        </div>
                        {g.description && <div className="clamp-2" style={{ ...KatanaType.small, fontSize: 12 }}>{g.description}</div>}
                      </button>
                    </KatanaCard>
                  ))}
                </div>
              </div>
            ) : tab !== 'home' ? (
              <div>
                <KatanaBreadcrumb
                  items={[
                    catalogMode === 'search'
                      ? 'Search'
                      : catalogMode === 'genre'
                        ? 'Genres'
                        : 'Catalog',
                  ]}
                  onHome={() => handleNav('home')}
                />

                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10 }}>
                  <KatanaSectionHeader
                    title={
                      catalogMode === 'search'
                        ? `Results for "${searchQuery}"`
                        : catalogMode === 'genre'
                          ? genreTitle || genreSlug
                          : catalogMode === 'latest'
                            ? 'Latest Updates'
                            : catalogMode === 'new'
                              ? 'New Releases'
                              : 'Browse Catalog'
                    }
                    badge={catTotalResults != null ? `${catTotalResults} series` : undefined}
                  />
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                    {(catalogMode === 'directory' || catalogMode === 'search') && (
                      <div
                        role="group"
                        aria-label="Catalog source"
                        className="no-scrollbar"
                        style={{
                          display: 'inline-flex',
                          padding: 3,
                          borderRadius: 99,
                          background: KatanaColors.surfaceAlt,
                          border: `1px solid ${KatanaColors.border}`,
                          maxWidth: '100%',
                          overflowX: 'auto',
                        }}
                      >
                        {(['all', 'mangakatana', 'mangadex', 'comick', 'bato'] as const).map((src) => {
                          const label = src === 'all' ? 'Everything' : getSourceBadgeInfo(src).choice;
                          const active = catalogSource === src;
                          const tip =
                            src === 'all'
                              ? 'Search every source at once · closest title matches first'
                              : getSourceBadgeInfo(src).tooltip;
                          return (
                            <button
                              key={src}
                              type="button"
                              className="bare-button"
                              aria-pressed={active}
                              title={tip}
                              onClick={() => setCatalogSource(src)}
                              style={{
                                minHeight: 44,
                                padding: '0 12px',
                                borderRadius: 99,
                                display: 'inline-flex',
                                alignItems: 'center',
                                whiteSpace: 'nowrap',
                                flexShrink: 0,
                                background: active ? KatanaColors.chipSelectedBg : 'transparent',
                                fontFamily: Fonts.body,
                                fontSize: 12,
                                fontWeight: active ? 700 : 500,
                                color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                              }}
                            >
                              {compactCard && src === 'all' ? 'All' : label}
                            </button>
                          );
                        })}
                      </div>
                    )}
                    {(catalogMode === 'directory' || catalogMode === 'genre' || catalogMode === 'search') && (
                      <button
                        type="button"
                        className="bare-button"
                        onClick={() => setFilterOpen((o) => !o)}
                        style={{
                          minHeight: 44,
                          padding: '0 14px',
                          borderRadius: 99,
                          background: filterOpen || activeFilterCount > 0 ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                          border: `1px solid ${filterOpen || activeFilterCount > 0 ? KatanaColors.chipSelectedBorder : KatanaColors.borderStrong}`,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 6,
                          fontFamily: Fonts.body,
                          fontSize: 12.5,
                          fontWeight: 700,
                          color: filterOpen || activeFilterCount > 0 ? KatanaColors.chipSelectedText : KatanaColors.text,
                        }}
                      >
                        <Icon name="tune" size={15} color={filterOpen || activeFilterCount > 0 ? KatanaColors.accentSoft : KatanaColors.textMuted} />
                        <span>Filters{activeFilterCount > 0 ? ` (${activeFilterCount})` : ''}</span>
                      </button>
                    )}
                    <div style={{ display: 'inline-flex', padding: 3, borderRadius: 10, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}` }}>
                      {(['grid', 'list'] as const).map((mode) => {
                        const active = effectiveCatView === mode;
                        return (
                          <button
                            key={mode}
                            type="button"
                            className="bare-button"
                            aria-label={mode === 'grid' ? 'Grid view' : 'List view'}
                            onClick={() => setCatViewMode(mode)}
                            style={{
                              width: 40,
                              height: 40,
                              borderRadius: 8,
                              background: active ? KatanaColors.chipSelectedBg : 'transparent',
                              border: active ? `1px solid ${KatanaColors.chipSelectedBorder}` : '1px solid transparent',
                              display: 'grid',
                              placeItems: 'center',
                            }}
                          >
                            <Icon name={mode === 'grid' ? 'grid_view' : 'view_agenda'} size={17} color={active ? KatanaColors.chipSelectedText : KatanaColors.textMuted} />
                          </button>
                        );
                      })}
                    </div>
                  </div>
                </div>

                {(catalogMode === 'directory' || catalogMode === 'search') && (
                  <div
                    style={{
                      marginTop: 6,
                      padding: '6px 10px',
                      borderRadius: 8,
                      background: withAlpha(KatanaColors.surfaceAlt, 0.72),
                      border: `1px solid ${KatanaColors.border}`,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      flexWrap: 'wrap',
                      gap: 6,
                    }}
                  >
                    <span style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.textMuted }}>
                      {catalogSource === 'all' ? (
                        <>
                          <strong style={{ color: KatanaColors.text }}>Searching every source at once.</strong> Closest
                          title match first, official releases above fan uploads.
                        </>
                      ) : (
                        (() => {
                          const info = getSourceBadgeInfo(catalogSource);
                          return (
                            <>{info.signals.specialty}.</>
                          );
                        })()
                      )}
                    </span>
                    <span
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 4,
                        fontFamily: Fonts.body,
                        fontSize: 11,
                        fontWeight: 700,
                        color: KatanaColors.green,
                      }}
                    >
                      <Icon name="verified" size={13} color={KatanaColors.green} />
                      <span>Official releases first</span>
                    </span>
                  </div>
                )}

                {/* Desktop inline filter drawer */}
                {filterOpen && desktop && (catalogMode === 'directory' || catalogMode === 'genre' || catalogMode === 'search') && (
                  <KatanaCard padding={16} style={{ marginTop: 12 }}>
                    {filterPanelBody}
                    {activeFilterCount > 0 && (
                      <div style={{ marginTop: 12, display: 'flex', justifyContent: 'flex-end' }}>
                        <KatanaButton label="Clear all filters" icon="restart_alt" size="sm" filled={false} color={KatanaColors.textMuted} onClick={clearCatalogFilters} />
                      </div>
                    )}
                  </KatanaCard>
                )}

                {/* Phone & Tablet modal filter sheet (keeps results cover-first) */}
                {filterOpen && !desktop && (catalogMode === 'directory' || catalogMode === 'genre' || catalogMode === 'search') && (
                  <div
                    role="dialog"
                    aria-modal="true"
                    aria-label="Catalog filters"
                    style={{
                      position: 'fixed',
                      inset: 0,
                      zIndex: 80,
                      background: 'rgba(5, 7, 11, 0.72)',
                      display: 'flex',
                      flexDirection: 'column',
                      justifyContent: 'flex-end',
                      alignItems: 'center',
                    }}
                    onClick={(e) => {
                      if (e.target === e.currentTarget) setFilterOpen(false);
                    }}
                  >
                    <div
                      ref={filterSheetRef}
                      style={{
                        width: '100%',
                        maxWidth: 720,
                        maxHeight: '82vh',
                        borderRadius: '20px 20px 0 0',
                        background: KatanaColors.surface,
                        borderTop: `1px solid ${KatanaColors.borderStrong}`,
                        display: 'flex',
                        flexDirection: 'column',
                        overflow: 'hidden',
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 10 }}>
                        <div style={{ width: 38, height: 4, borderRadius: 99, background: KatanaColors.borderStrong }} />
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '10px 16px 12px', borderBottom: `1px solid ${KatanaColors.border}` }}>
                        <div>
                          <span style={{ ...KatanaType.section, fontSize: 16 }}>Filters</span>
                          <span style={{ ...KatanaType.small, marginLeft: 8, fontSize: 11.5 }}>Updates live</span>
                        </div>
                        <button type="button" className="bare-button" aria-label="Close filters" onClick={() => setFilterOpen(false)} style={{ width: 40, height: 40, display: 'grid', placeItems: 'center' }}>
                          <Icon name="close" size={20} color={KatanaColors.textMuted} />
                        </button>
                      </div>
                      <div style={{ flex: 1, overflowY: 'auto', padding: 16 }}>{filterPanelBody}</div>
                      <div
                        style={{
                          padding: '12px 16px calc(12px + var(--safe-bottom, env(safe-area-inset-bottom, 0px)))',
                          borderTop: `1px solid ${KatanaColors.border}`,
                          background: KatanaColors.headerDark,
                          display: 'flex',
                          gap: 10,
                          alignItems: 'center',
                        }}
                      >
                        {activeFilterCount > 0 && (
                          <KatanaButton label="Reset" size="sm" filled={false} color={KatanaColors.textMuted} onClick={clearCatalogFilters} />
                        )}
                        <div style={{ flex: 1 }}>
                          <KatanaButton
                            label={
                              catTotalResults != null
                                ? `Done · ${catTotalResults} ${catTotalResults === 1 ? 'result' : 'results'}`
                                : `Done · ${catItems.length} on this page`
                            }
                            icon="check"
                            onClick={() => setFilterOpen(false)}
                          />
                        </div>
                      </div>
                    </div>
                  </div>
                )}

                {/* Saved filter preset quick-apply row */}
                {filterPresets.length > 0 && !filterOpen && (catalogMode === 'directory' || catalogMode === 'genre' || catalogMode === 'search') && (
                  <div style={{ marginTop: 10, display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center' }}>
                    <span style={{ ...KatanaType.small, fontSize: 11.5, fontWeight: 700, color: KatanaColors.textLight }}>Presets:</span>
                    {filterPresets.map((preset) => (
                      <button
                        key={preset.id}
                        type="button"
                        className="bare-button"
                        onClick={() => applyFilterPreset(preset)}
                        style={{
                          minHeight: 44,
                          padding: '0 12px',
                          borderRadius: 99,
                          background: KatanaColors.surfaceAlt,
                          border: `1px solid ${KatanaColors.borderStrong}`,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 5,
                          fontFamily: Fonts.body,
                          fontSize: 12,
                          fontWeight: 600,
                          color: KatanaColors.text,
                        }}
                      >
                        <Icon name="bookmarks" size={14} color={KatanaColors.accent} />
                        <span>{preset.name}</span>
                      </button>
                    ))}
                  </div>
                )}

                {/* Removable active filter chips summary */}
                {activeFilterCount > 0 && !filterOpen && (
                  <div style={{ marginTop: 10, display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center' }}>
                    {statusFilter !== 'all' && (
                      <button
                        type="button"
                        className="bare-button"
                        aria-label={`Remove status filter ${statusFilter}`}
                        onClick={() => updateMangaUrl({ status: null, page: '1' }, { replace: true })}
                        style={{
                          minHeight: 44,
                          padding: '0 12px',
                          borderRadius: 99,
                          background: KatanaColors.surfaceAlt,
                          border: `1px solid ${KatanaColors.borderStrong}`,
                          color: KatanaColors.text,
                          fontSize: 12,
                          fontWeight: 600,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 5,
                        }}
                      >
                        <span>{statusFilter === 'ongoing' ? 'Ongoing' : 'Completed'}</span>
                        <Icon name="close" size={14} color={KatanaColors.textMuted} />
                      </button>
                    )}
                    {demographicFilter !== 'all' && (
                      <button
                        type="button"
                        className="bare-button"
                        aria-label={`Remove demographic filter ${demographicFilter}`}
                        onClick={() => updateMangaUrl({ demo: null, page: '1' }, { replace: true })}
                        style={{
                          minHeight: 44,
                          padding: '0 12px',
                          borderRadius: 99,
                          background: KatanaColors.surfaceAlt,
                          border: `1px solid ${KatanaColors.borderStrong}`,
                          color: KatanaColors.text,
                          fontSize: 12,
                          fontWeight: 600,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 5,
                        }}
                      >
                        <span>{demographicFilter}</span>
                        <Icon name="close" size={14} color={KatanaColors.textMuted} />
                      </button>
                    )}
                    {languageFilter !== 'all' && (
                      <button
                        type="button"
                        className="bare-button"
                        aria-label={`Remove language filter ${languageFilter}`}
                        onClick={() => updateMangaUrl({ lang: null, page: '1' }, { replace: true })}
                        style={{
                          minHeight: 44,
                          padding: '0 12px',
                          borderRadius: 99,
                          background: KatanaColors.surfaceAlt,
                          border: `1px solid ${KatanaColors.borderStrong}`,
                          color: KatanaColors.text,
                          fontSize: 12,
                          fontWeight: 600,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 5,
                        }}
                      >
                        <span>Lang: {languageFilter.toUpperCase()}</span>
                        <Icon name="close" size={14} color={KatanaColors.textMuted} />
                      </button>
                    )}
                    {authorFilter.trim() && (
                      <button
                        type="button"
                        className="bare-button"
                        aria-label={`Remove author filter ${authorFilter.trim()}`}
                        onClick={() => {
                          setAuthorDraft('');
                          updateMangaUrl({ author: null, page: '1' }, { replace: true });
                        }}
                        style={{
                          minHeight: 44,
                          padding: '0 12px',
                          borderRadius: 99,
                          background: KatanaColors.surfaceAlt,
                          border: `1px solid ${KatanaColors.borderStrong}`,
                          color: KatanaColors.text,
                          fontSize: 12,
                          fontWeight: 600,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 5,
                        }}
                      >
                        <span>Author: {authorFilter.trim()}</span>
                        <Icon name="close" size={14} color={KatanaColors.textMuted} />
                      </button>
                    )}
                    {includeGenres.map((s) => (
                      <button
                        key={`inc-${s}`}
                        type="button"
                        className="bare-button"
                        aria-label={`Remove included genre ${s}`}
                        onClick={() => toggleIncludeGenre(s)}
                        style={{
                          minHeight: 44,
                          padding: '0 12px',
                          borderRadius: 99,
                          background: withAlpha(KatanaColors.green, 0.15),
                          border: `1px solid ${withAlpha(KatanaColors.green, 0.4)}`,
                          color: KatanaColors.green,
                          fontSize: 12,
                          fontWeight: 600,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 5,
                        }}
                      >
                        <span>+ {s}</span>
                        <Icon name="close" size={14} color={KatanaColors.green} />
                      </button>
                    ))}
                    {excludeGenres.map((s) => (
                      <button
                        key={`exc-${s}`}
                        type="button"
                        className="bare-button"
                        aria-label={`Remove excluded genre ${s}`}
                        onClick={() => toggleExcludeGenre(s)}
                        style={{
                          minHeight: 44,
                          padding: '0 12px',
                          borderRadius: 99,
                          background: withAlpha(KatanaColors.crimson, 0.15),
                          border: `1px solid ${withAlpha(KatanaColors.crimson, 0.4)}`,
                          color: KatanaColors.crimson,
                          fontSize: 12,
                          fontWeight: 600,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 5,
                        }}
                      >
                        <span>− {s}</span>
                        <Icon name="close" size={14} color={KatanaColors.crimson} />
                      </button>
                    ))}
                    {minChapters !== '1' && (
                      <button
                        type="button"
                        className="bare-button"
                        aria-label={`Remove minimum chapters filter ${minChapters}`}
                        onClick={() => updateMangaUrl({ minCh: null, page: '1' }, { replace: true })}
                        style={{
                          minHeight: 44,
                          padding: '0 12px',
                          borderRadius: 99,
                          background: KatanaColors.surfaceAlt,
                          border: `1px solid ${KatanaColors.borderStrong}`,
                          color: KatanaColors.textMuted,
                          fontSize: 12,
                          fontWeight: 600,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 5,
                        }}
                      >
                        <span>{minChapters}+ ch</span>
                        <Icon name="close" size={14} color={KatanaColors.textMuted} />
                      </button>
                    )}
                    <button
                      type="button"
                      className="bare-button"
                      onClick={clearCatalogFilters}
                      style={{ ...KatanaType.link, minHeight: 44, padding: '0 10px', fontSize: 12.5, display: 'inline-flex', alignItems: 'center' }}
                    >
                      Clear all
                    </button>
                  </div>
                )}

                <div style={{ height: 14 }} />
                {catalogSource === 'all' && (catalogMode === 'search' || catalogMode === 'directory') && (
                  <div
                    role="status"
                    aria-label="Multi-source search progress"
                    style={{
                      marginBottom: 12,
                      padding: '8px 12px',
                      borderRadius: 10,
                      background: KatanaColors.surface,
                      border: `1px solid ${KatanaColors.border}`,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      flexWrap: 'wrap',
                      gap: 8,
                    }}
                  >
                    <span style={{ ...KatanaType.small, fontSize: 11.5, fontWeight: 700, color: KatanaColors.textMuted }}>
                      PROGRESSIVE 4-SOURCE STREAM:
                    </span>
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                      {(
                        [
                          ['mangakatana', 'MangaKatana', KatanaColors.accent],
                          ['mangadex', 'MangaDex', KatanaColors.teal],
                          ['comick', 'ComicK', KatanaColors.link],
                          ['bato', 'Bato.to', KatanaColors.green],
                        ] as const
                      ).map(([sKey, sLabel, sColor]) => {
                        const st = multiSourceStream[sKey];
                        const statusText =
                          st.status === 'loading'
                            ? 'Searching…'
                            : st.status === 'error'
                              ? 'Unreachable'
                              : `${st.count} ${st.count === 1 ? 'hit' : 'hits'}`;
                        return (
                          <button
                            key={sKey}
                            type="button"
                            className="bare-button"
                            onClick={() => setCatalogSource(sKey)}
                            title={st.error || `Filter to ${sLabel}`}
                            style={{
                              minHeight: 36,
                              padding: '3px 10px',
                              borderRadius: 99,
                              background: KatanaColors.surfaceAlt,
                              border: `1px solid ${
                                st.status === 'error'
                                  ? withAlpha(KatanaColors.crimson, 0.45)
                                  : st.status === 'ok'
                                    ? withAlpha(sColor, 0.45)
                                    : KatanaColors.border
                              }`,
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: 5,
                              fontFamily: Fonts.body,
                              fontSize: 11.5,
                              fontWeight: 600,
                              color:
                                st.status === 'error'
                                  ? KatanaColors.crimson
                                  : st.status === 'ok'
                                    ? KatanaColors.text
                                    : KatanaColors.textMuted,
                            }}
                          >
                            <span
                              style={{
                                width: 7,
                                height: 7,
                                borderRadius: 99,
                                background:
                                  st.status === 'loading'
                                    ? KatanaColors.orange
                                    : st.status === 'error'
                                      ? KatanaColors.crimson
                                      : st.status === 'ok'
                                        ? sColor
                                        : KatanaColors.textLight,
                              }}
                            />
                            <span>{sLabel}:</span>
                            <strong>{statusText}</strong>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                )}
                {catError && <KatanaErrorBanner message={catError} onRetry={() => setCatRefreshTick((n) => n + 1)} />}

                {catLoading ? (
                  effectiveCatView === 'grid' ? (
                    <KatanaSkeletonGrid count={getKatanaGridColumns(width) * 2} columns={getKatanaGridColumns(width)} />
                  ) : (
                    <KatanaSkeletonList count={4} />
                  )
                ) : catItems.length === 0 ? (
                  <KatanaEmptyState
                    icon="search_off"
                    title="No titles found"
                    subtitle={
                      activeFilterCount > 0
                        ? 'Try removing one or more filters to widen the catalog.'
                        : 'Try another search term or browse popular genres.'
                    }
                    actionLabel={activeFilterCount > 0 ? 'Clear Filters' : 'Back to Home'}
                    actionIcon={activeFilterCount > 0 ? 'restart_alt' : 'home'}
                    onAction={() => (activeFilterCount > 0 ? clearCatalogFilters() : handleNav('home'))}
                  />
                ) : catalogSource === 'all' && catalogMode === 'search' ? (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 22 }}>
                    {(
                      [
                        { key: 'mangakatana' as const, label: 'MangaKatana', items: katanaSourceItems, accent: KatanaColors.accent },
                        { key: 'mangadex' as const, label: 'MangaDex', items: mangadexSourceItems, accent: KatanaColors.teal },
                        { key: 'comick' as const, label: 'ComicK', items: comickSourceItems, accent: KatanaColors.link },
                        { key: 'bato' as const, label: 'Bato.to', items: batoSourceItems, accent: KatanaColors.green },
                      ]
                    ).map((group) => {
                      const srcState = multiSourceStream[group.key];
                      const badgeText =
                        srcState.status === 'loading'
                          ? 'Searching…'
                          : srcState.status === 'error'
                            ? 'Unreachable'
                            : `${group.items.length} ${group.items.length === 1 ? 'match' : 'matches'}`;
                      return (
                      <section key={group.key} aria-label={`${group.label} search results`}>
                        <KatanaSectionHeader
                          title={group.label}
                          badge={badgeText}
                          trailing={
                            <button
                              type="button"
                              className="bare-button"
                              onClick={() => setCatalogSource(group.key)}
                              style={{
                                minHeight: 44,
                                padding: '0 10px',
                                borderRadius: 99,
                                background: KatanaColors.surfaceAlt,
                                border: `1px solid ${KatanaColors.borderStrong}`,
                                fontFamily: Fonts.body,
                                fontSize: 11.5,
                                fontWeight: 700,
                                color: group.accent,
                              }}
                            >
                              Only {group.label}
                            </button>
                          }
                        />
                        <div style={{ height: 10 }} />
                        {group.items.length === 0 ? (
                          <div
                            style={{
                              padding: '12px 14px',
                              borderRadius: 10,
                              background: KatanaColors.surface,
                              border: `1px solid ${KatanaColors.border}`,
                              ...KatanaType.small,
                            }}
                          >
                            {srcState.status === 'loading'
                              ? `Searching ${group.label}…`
                              : srcState.status === 'error'
                                ? `${group.label} could not be reached for this query.`
                                : `No matching titles on ${group.label} for this query.`}
                          </div>
                        ) : effectiveCatView === 'grid' ? (
                          <div
                            style={{
                              display: 'grid',
                              gridTemplateColumns: `repeat(${getKatanaGridColumns(width)}, minmax(0, 1fr))`,
                              gap: compactCard ? 10 : 14,
                            }}
                          >
                            {group.items.map((m) => (
                              <KatanaPosterCard
                                key={`${group.key}-${m.slug}`}
                                manga={m}
                                unreadCount={unreadBySlug[m.slug]}
                                downloadedCount={downloadedCounts[m.slug]}
                                onSelect={() => openDetail(m.slug)}
                              />
                            ))}
                          </div>
                        ) : (
                          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                            {group.items.map((m) => (
                              <KatanaItemCard
                                key={`${group.key}-${m.slug}`}
                                manga={m}
                                compact={compactCard}
                                unreadCount={unreadBySlug[m.slug]}
                                downloadedCount={downloadedCounts[m.slug]}
                                onSelectManga={openDetail}
                                onSelectGenre={handleSelectGenre}
                                onOpenChapter={openChapter}
                              />
                            ))}
                          </div>
                        )}
                      </section>
                      );
                    })}
                    <div style={{ marginTop: 4 }}>
                      <KatanaPagination
                        page={catPage}
                        hasPrev={catPage > 1}
                        hasNext={catHasNext}
                        totalPages={catTotalPages}
                        totalResults={catTotalResults}
                        onPageChange={(p) => updateMangaUrl({ page: String(p) })}
                      />
                    </div>
                  </div>
                ) : (
                  <>
                    {effectiveCatView === 'grid' ? (
                      <div
                        style={{
                          display: 'grid',
                          gridTemplateColumns: `repeat(${getKatanaGridColumns(width)}, minmax(0, 1fr))`,
                          gap: compactCard ? 10 : 14,
                        }}
                      >
                        {catItems.map((m) => (
                          <KatanaPosterCard
                            key={m.slug}
                            manga={m}
                            unreadCount={unreadBySlug[m.slug]}
                            downloadedCount={downloadedCounts[m.slug]}
                            onSelect={() => openDetail(m.slug)}
                          />
                        ))}
                      </div>
                    ) : (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                        {catItems.map((m) => (
                          <KatanaItemCard
                            key={m.slug}
                            manga={m}
                            compact={compactCard}
                            unreadCount={unreadBySlug[m.slug]}
                            downloadedCount={downloadedCounts[m.slug]}
                            onSelectManga={openDetail}
                            onSelectGenre={handleSelectGenre}
                            onOpenChapter={openChapter}
                          />
                        ))}
                      </div>
                    )}
                    <div style={{ marginTop: 18 }}>
                      <KatanaPagination
                        page={catPage}
                        hasPrev={catPage > 1}
                        hasNext={catHasNext}
                        totalPages={catTotalPages}
                        totalResults={catTotalResults}
                        onPageChange={(p) => updateMangaUrl({ page: String(p) })}
                      />
                    </div>
                  </>
                )}
              </div>
            ) : homeLoading ? (
              desktop ? <KatanaSkeletonGrid count={8} columns={4} /> : <KatanaSkeletonList count={4} />
            ) : null}
          </div>
        </div>
      )}

      {width < KATANA_BREAKPOINTS.tablet && !readerParams && (
        <KatanaBottomBar
          active={tab}
          readingCount={myCurrentlyReading.length}
          downloadsCount={offline.mangaItems.length}
          onSelectNav={handleNav}
        />
      )}

      {readerParams && <MangaReaderView params={readerParams} onClose={closeReader} />}
    </div>
  );
}
