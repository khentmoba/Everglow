import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useLocation, useNavigate, useParams, useSearchParams } from 'react-router';
import { useRememberedScroll } from '../../core/router/scrollMemory';
import { displayNameFor, useAuth } from '../../core/services/auth';
import { formattedSize, OfflineIds, offlineMedia, useOfflineMedia, type OfflineMediaItem } from '../../core/services/offlineMedia';
import { useViewport } from '../../core/system/viewport';
import { withAlpha } from '../../core/theme/colors';
import { Fonts } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { AlertDialog, TextButton, showDialog } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { TvMediaNavHeader } from '../../shared/widgets/shelf/TvMediaNavHeader';
import { MangaHome, type MangaType } from './MangaHome';
import { MangaReaderView, type MangaReaderParams } from './MangaReaderPage';
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
  chapterDisplayTitle,
  checkKatanaChapterAlerts,
  clearKatanaHistory,
  clearKatanaReadingProgress,
  estimateUnreadCount,
  exportKatanaLibraryJson,
  exportKatanaLibraryMalXml,
  fetchKatanaByType,
  fetchKatanaCatalog,
  fetchKatanaChapterPages,
  fetchKatanaDetail,
  fetchKatanaHome,
  formatCompactNumber,
  formatKatanaTime,
  importKatanaLibraryJson,
  importKatanaLibraryMalXml,
  isBookmarkCaughtUp,
  isKatanaHistoryPaused,
  loadKatanaAlertPrefs,
  loadKatanaUserPrefs,
  loadKatanaAutoDownloadCount,
  loadKatanaCustomCategories,
  setKatanaHistoryPaused,
  loadKatanaHiddenCategories,
  loadKatanaHistory,
  lookupMalManga,
  markKatanaAlertSeen,
  markKatanaChaptersRead,
  proxyKatanaImageUrl,
  recordKatanaHistory,
  removeKatanaHistoryEntry,
  resolveLibraryStatus,
  saveKatanaAlertPrefs,
  saveKatanaAutoDownloadCount,
  saveKatanaCustomCategories,
  saveKatanaHiddenCategories,
  saveKatanaTrackerData,
  saveKatanaUserPrefs,
  searchMangaDexCatalog,
  setKatanaBookmark,
  setKatanaBookmarkCategories,
  setKatanaLibraryStatus,
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
  getSeriesVisualAccent,
  KATANA_BREAKPOINTS,
  KATANA_THEME_VARS,
  KatanaColors,
  KatanaType,
  loadKatanaThemeMode,
  saveKatanaThemeMode,
  type KatanaThemeMode,
} from './katanaTokens';
import { clearResumeAnchor } from './readerSettings';

const STATUS_LABELS: Record<KatanaLibraryStatus, { label: string; icon: string; color: string }> = {
  reading: { label: 'Reading', icon: 'auto_stories', color: KatanaColors.accent },
  on_hold: { label: 'On Hold', icon: 'pause_circle_outline', color: KatanaColors.orange },
  completed: { label: 'Completed', icon: 'check_circle', color: KatanaColors.green },
  planned: { label: 'Plan to Read', icon: 'schedule', color: KatanaColors.link },
  dropped: { label: 'Dropped', icon: 'cancel', color: KatanaColors.textLight },
};

const ORDER_OPTIONS = [
  { id: 'latest', label: 'Latest Updated' },
  { id: 'popular', label: 'Most Followed' },
  { id: 'rating', label: 'Top Rated' },
  { id: 'numc', label: 'Most Chapters' },
  { id: 'new', label: 'Newest Added' },
  { id: 'az', label: 'Title A–Z' },
] as const;

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

function supportsNetworkConnectionApi(): boolean {
  if (typeof navigator === 'undefined') return false;
  const nav = navigator as Navigator & { connection?: { type?: string; saveData?: boolean } };
  return Boolean(nav.connection);
}

function isOnMeteredCellular(): boolean {
  const nav = navigator as Navigator & { connection?: { type?: string; saveData?: boolean } };
  return nav.connection?.type === 'cellular' || nav.connection?.saveData === true;
}

function extractTrackerId(input: string, kind: 'anilist' | 'mal'): string {
  const trimmed = input.trim();
  if (!trimmed) return '';
  if (/^\d+$/.test(trimmed)) return trimmed;
  const re = kind === 'anilist' ? /anilist\.co\/manga\/(\d+)/i : /myanimelist\.net\/manga\/(\d+)/i;
  const m = re.exec(trimmed);
  return m ? m[1] : trimmed.replace(/[^0-9]/g, '');
}

const MIN_CHAPTER_OPTIONS = [
  { id: '1', label: 'Any length' },
  { id: '10', label: '10+ ch' },
  { id: '50', label: '50+ ch' },
  { id: '100', label: '100+ ch' },
] as const;

const STATUS_FILTER_OPTIONS = [
  { id: 'all', label: 'Any status' },
  { id: 'ongoing', label: 'Ongoing' },
  { id: 'completed', label: 'Completed' },
] as const;

const DEMOGRAPHIC_OPTIONS = [
  { id: 'all', label: 'All' },
  { id: 'shounen', label: 'Shounen' },
  { id: 'seinen', label: 'Seinen' },
  { id: 'shoujo', label: 'Shoujo' },
  { id: 'josei', label: 'Josei' },
] as const;

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
      navigate(qs ? `/manga?${qs}` : '/manga', { replace: opts?.replace ?? false });
    },
    [navigate, searchParams],
  );

  const openDetail = useCallback(
    (slug: string) => {
      if (!slug) return;
      navigate(`/manga/series/${encodeURIComponent(slug)}${preservedQuery}`);
    },
    [navigate, preservedQuery],
  );

  const closeDetail = useCallback(() => {
    if (location.key !== 'default') navigate(-1);
    else navigate(`/manga${preservedQuery}`);
  }, [location.key, navigate, preservedQuery]);

  const [readerParams, setReaderParams] = useState<MangaReaderParams | null>(null);
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
  const filterSheetRef = useRef<HTMLDivElement>(null);
  const libraryToolsSheetRef = useRef<HTMLDivElement>(null);
  const detailActionsRef = useRef<HTMLDivElement>(null);
  const shelfChipsRef = useRef<HTMLDivElement>(null);

  const userName = currentUser ?? '';
  const syncedCategories = useSource(() => watchKatanaCustomCategories(userName), [userName], localCategories);
  const syncedRecentSearches = useSource(() => watchKatanaRecentSearches(userName), [userName], []);
  const syncedHistory = useSource(() => watchKatanaHistory(userName), [userName], []);
  const syncedUserPrefs = useSource(() => watchKatanaUserPrefs(userName), [userName], null);
  useEffect(() => {
    if (syncedHistory.length > 0) setHistoryEntries(syncedHistory);
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
      showSnackBar(`Synced with MAL #${snap.malId}${snap.score ? ` (★ ${snap.score})` : ''}`);
    } finally {
      setTrackerSyncing(false);
    }
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
    showSnackBar(next ? `Chapter alerts enabled for ${manga.title}` : `Chapter alerts muted for ${manga.title}`);
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

  // Check alert-enabled series against latest home catalog updates and dispatch real browser notifications when permitted.
  useEffect(() => {
    if (!userName || !homeData || bookmarks.length === 0) return;
    const catalog = [...homeData.latest, ...homeData.hot, ...homeData.hotUpdates];
    checkKatanaChapterAlerts(userName, bookmarks, catalog);
  }, [userName, homeData, bookmarks]);
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
    fetchKatanaHome().then((d) => {
      if (!alive) return;
      setHomeData(d);
      setHomeLoading(false);
    });
    return () => {
      alive = false;
    };
  }, [homeRefreshTick]);

  useEffect(() => {
    if (typeFilter === 'all') return;
    let alive = true;
    setTypeLoading(true);
    fetchKatanaByType(typeFilter, typePage).then((res) => {
      if (!alive) return;
      setTypeItems(res.items);
      setTypeHasNext(res.hasNext);
      setTypeTotalPages(res.totalPages);
      setTypeTotalResults(res.totalResults);
      setTypeLoading(false);
    });
    return () => {
      alive = false;
    };
  }, [typeFilter, typePage]);

  useEffect(() => {
    if (detailSlug) return;
    const isCatalogTab =
      ['latest', 'directory', 'newManga'].includes(tab) || (tab === 'genres' && genreSlug !== '') || catalogMode === 'search';
    if (!isCatalogTab) return;
    let alive = true;
    setCatLoading(true);
    setCatError(undefined);
    if (catalogSource === 'mangadex' && (catalogMode === 'search' || catalogMode === 'directory')) {
      searchMangaDexCatalog({
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
    authorFilter,
    catRefreshTick,
  ]);

  useEffect(() => {
    if (!detailSlug) return;
    let alive = true;
    setDetailLoading(true);
    setChapterSearch('');
    setChapterWindow(40);
    setSelectMode(false);
    setSelectedChapterIds(new Set());
    setDetailOverflowOpen(false);
    fetchKatanaDetail(detailSlug).then((d) => {
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
  }, [detailSlug]);

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
    (authorFilter.trim() ? 1 : 0);

  const clearCatalogFilters = () => {
    updateMangaUrl(
      { inc: null, exc: null, gm: null, minCh: null, order: null, status: null, demo: null, author: null, page: '1' },
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
      });
      const targetUrl = `/manga/series/${encodeURIComponent(manga.slug)}/${encodeURIComponent(chapterId)}${preservedQuery}`;
      if (`${location.pathname}${location.search}` !== targetUrl) {
        navigate(targetUrl);
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
      };
    });
  }, [activeRouteChapterId, detail, detailSlug]);

  const closeReader = useCallback(() => {
    setReaderParams(null);
    if (activeRouteChapterId && detailSlug) {
      if (location.key !== 'default') navigate(-1);
      else navigate(`/manga/series/${encodeURIComponent(detailSlug)}${preservedQuery}`, { replace: true });
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

  const downloadChapter = useCallback(
    async (manga: KatanaManga, chapter: KatanaChapter, silent = false) => {
      if (downloadWifiOnly && isOnMeteredCellular()) {
        if (!silent) showSnackBar('Wi-Fi-only downloads is on. Turn it off in Downloads to use mobile data.');
        return;
      }
      const offlineId = OfflineIds.mangaChapterId(manga.slug, chapter.id);
      if (offlineMedia.isDownloaded(offlineId)) {
        if (!silent) showSnackBar(`${chapterDisplayTitle(chapter)} is already saved offline`);
        return;
      }
      setDownloadingChapterIds((prev) => new Set(prev).add(chapter.id));
      try {
        const pages = await fetchKatanaChapterPages(manga.slug, chapter.id);
        if (pages.length === 0) {
          if (!silent) showSnackBar(`Could not fetch pages for ${chapterDisplayTitle(chapter)}`);
          return;
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
      } catch {
        if (!silent) showSnackBar(`Download failed for ${chapterDisplayTitle(chapter)}`);
      } finally {
        setDownloadingChapterIds((prev) => {
          const next = new Set(prev);
          next.delete(chapter.id);
          return next;
        });
      }
    },
    [downloadWifiOnly],
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
      while (downloadQueueRef.current.length > 0) {
        if (downloadCancelRef.current) break;
        const [nextItem, ...rest] = downloadQueueRef.current;
        downloadQueueRef.current = rest;
        setDownloadQueue(rest);
        savePendingDownloadQueue([nextItem, ...rest]);
        setBatchProgress({ done: saved, total: saved + 1 + rest.length, currentTitle: chapterDisplayTitle(nextItem.chapter) });
        await downloadChapter(nextItem.manga, nextItem.chapter, true);
        saved += 1;
        savePendingDownloadQueue(downloadQueueRef.current);
        setBatchProgress({
          done: saved,
          total: saved + downloadQueueRef.current.length,
          currentTitle: downloadQueueRef.current[0] ? chapterDisplayTitle(downloadQueueRef.current[0].chapter) : undefined,
        });
      }
      const wasCancelled = downloadCancelRef.current;
      downloadCancelRef.current = false;
      downloadQueueRef.current = [];
      setDownloadQueue([]);
      savePendingDownloadQueue([]);
      setBatchProgress(null);
      showSnackBar(
        wasCancelled
          ? `Stopped after saving ${saved} of ${total} chapters`
          : `Saved ${saved} ${saved === 1 ? 'chapter' : 'chapters'} offline`,
      );
    },
    [downloadChapter],
  );

  const downloadBatchChapters = useCallback(
    async (manga: KatanaManga, chapters: KatanaChapter[]) => {
      if (downloadWifiOnly && isOnMeteredCellular()) {
        showSnackBar('Wi-Fi-only downloads is on. Turn it off in Downloads to use mobile data.');
        return;
      }
      const targets = chapters.filter((c) => !offlineMedia.isDownloaded(OfflineIds.mangaChapterId(manga.slug, c.id)));
      if (targets.length === 0) {
        showSnackBar('Selected chapters are already saved offline');
        return;
      }
      await runDownloadQueue(targets.map((chapter) => ({ manga, chapter })));
    },
    [downloadWifiOnly, runDownloadQueue],
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
    return [...pool.values()]
      .map((m) => {
        const sameAuthor = m.authors.some((a) => authorSet.has(a.toLowerCase()));
        const relatedTitle = titleStem.length >= 5 && m.title.toLowerCase().includes(titleStem);
        const sharedGenres = m.genres.filter((g) => genreSet.has(g.slug)).length;
        const relation = sameAuthor ? 'Same Author' : relatedTitle ? 'Related Series' : sharedGenres > 0 ? `${sharedGenres} shared` : '';
        const score = (sameAuthor ? 10 : 0) + (relatedTitle ? 8 : 0) + sharedGenres * 2 + (m.rating ? m.rating / 5 : 0);
        return { manga: m, relation, score };
      })
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

  const filterPanelBody = (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 16, alignItems: 'flex-start' }}>
        <div>
          <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Sort by</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {ORDER_OPTIONS.map((opt) => {
              const active = orderBy === opt.id;
              return (
                <button
                  key={opt.id}
                  type="button"
                  className="bare-button"
                  onClick={() => updateMangaUrl({ order: opt.id === 'latest' ? null : opt.id, page: '1' }, { replace: true })}
                  style={{
                    padding: '5px 10px',
                    borderRadius: 7,
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: active ? 700 : 500,
                    color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                  }}
                >
                  {opt.label}
                </button>
              );
            })}
          </div>
        </div>

        <div>
          <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Status</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {STATUS_FILTER_OPTIONS.map((opt) => {
              const active = statusFilter === opt.id;
              return (
                <button
                  key={opt.id}
                  type="button"
                  className="bare-button"
                  onClick={() => updateMangaUrl({ status: opt.id === 'all' ? null : opt.id, page: '1' }, { replace: true })}
                  style={{
                    padding: '5px 10px',
                    borderRadius: 7,
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: active ? 700 : 500,
                    color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                  }}
                >
                  {opt.label}
                </button>
              );
            })}
          </div>
        </div>

        <div>
          <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Demographic</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {DEMOGRAPHIC_OPTIONS.map((opt) => {
              const active = demographicFilter === opt.id;
              return (
                <button
                  key={opt.id}
                  type="button"
                  className="bare-button"
                  onClick={() => updateMangaUrl({ demo: opt.id === 'all' ? null : opt.id, page: '1' }, { replace: true })}
                  style={{
                    padding: '5px 10px',
                    borderRadius: 7,
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: active ? 700 : 500,
                    color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                  }}
                >
                  {opt.label}
                </button>
              );
            })}
          </div>
        </div>

        <div>
          <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Min chapters</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {MIN_CHAPTER_OPTIONS.map((opt) => {
              const active = minChapters === opt.id;
              return (
                <button
                  key={opt.id}
                  type="button"
                  className="bare-button"
                  onClick={() => updateMangaUrl({ minCh: opt.id === '1' ? null : opt.id, page: '1' }, { replace: true })}
                  style={{
                    padding: '5px 10px',
                    borderRadius: 7,
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: active ? 700 : 500,
                    color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                  }}
                >
                  {opt.label}
                </button>
              );
            })}
          </div>
        </div>

        <div>
          <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Genre match</div>
          <div style={{ display: 'flex', gap: 6 }}>
            {(['and', 'or'] as const).map((gm) => {
              const active = genreMode === gm;
              return (
                <button
                  key={gm}
                  type="button"
                  className="bare-button"
                  onClick={() => updateMangaUrl({ gm: gm === 'and' ? null : gm, page: '1' }, { replace: true })}
                  style={{
                    padding: '5px 10px',
                    borderRadius: 7,
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: active ? 700 : 500,
                    color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                  }}
                >
                  {gm === 'and' ? 'Match All' : 'Match Any'}
                </button>
              );
            })}
          </div>
        </div>
      </div>

      <div>
        <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Author filter</div>
        <div style={{ display: 'flex', gap: 8, maxWidth: 340 }}>
          <input
            value={authorDraft}
            onChange={(e) => setAuthorDraft(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                updateMangaUrl({ author: authorDraft.trim() || null, page: '1' }, { replace: true });
              }
            }}
            placeholder="Filter by author name..."
            aria-label="Filter by author"
            style={{
              flex: 1,
              height: 34,
              padding: '0 10px',
              borderRadius: 8,
              background: KatanaColors.background,
              border: `1px solid ${KatanaColors.border}`,
              fontFamily: Fonts.body,
              fontSize: 12.5,
              color: KatanaColors.text,
              outline: 'none',
            }}
          />
          <KatanaButton
            label="Apply"
            size="sm"
            filled={false}
            color={KatanaColors.text}
            onClick={() => updateMangaUrl({ author: authorDraft.trim() || null, page: '1' }, { replace: true })}
          />
        </div>
      </div>

      {(homeData?.genres ?? []).length > 0 && (
        <div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 6, marginBottom: 8 }}>
            <span style={{ ...KatanaType.small, fontWeight: 700 }}>Genres & Tags</span>
            <span style={{ ...KatanaType.small, fontSize: 11.5 }}>
              Tap genre to <span style={{ color: KatanaColors.green, fontWeight: 700 }}>+ Include</span>, or{' '}
              <span style={{ color: KatanaColors.crimson, fontWeight: 700 }}>−</span> to exclude
            </span>
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {(homeData?.genres ?? []).map((g) => {
              const inc = includeGenres.includes(g.slug);
              const exc = excludeGenres.includes(g.slug);
              return (
                <div
                  key={g.slug}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    borderRadius: 9,
                    overflow: 'hidden',
                    background: inc
                      ? withAlpha(KatanaColors.green, 0.18)
                      : exc
                        ? withAlpha(KatanaColors.crimson, 0.18)
                        : KatanaColors.surfaceAlt,
                    border: `1px solid ${inc ? KatanaColors.green : exc ? KatanaColors.crimson : KatanaColors.border}`,
                  }}
                >
                  <button
                    type="button"
                    className="bare-button"
                    aria-pressed={inc}
                    aria-label={`${inc ? 'Remove include' : 'Include'} ${g.name}`}
                    onClick={() => toggleIncludeGenre(g.slug)}
                    style={{
                      minHeight: 36,
                      padding: '0 11px',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 4,
                      fontFamily: Fonts.body,
                      fontSize: 12.5,
                      fontWeight: inc || exc ? 700 : 600,
                      textDecoration: exc ? 'line-through' : 'none',
                      color: inc ? KatanaColors.green : exc ? KatanaColors.crimson : KatanaColors.textMuted,
                    }}
                  >
                    {inc && <Icon name="add" size={14} color={KatanaColors.green} />}
                    <span>{g.name}</span>
                  </button>
                  <button
                    type="button"
                    className="bare-button"
                    aria-pressed={exc}
                    aria-label={`${exc ? 'Remove exclude' : 'Exclude'} ${g.name}`}
                    title={exc ? `Remove ${g.name} exclusion` : `Exclude ${g.name}`}
                    onClick={() => toggleExcludeGenre(g.slug)}
                    style={{
                      width: 36,
                      height: 36,
                      display: 'grid',
                      placeItems: 'center',
                      borderLeft: `1px solid ${inc ? withAlpha(KatanaColors.green, 0.35) : exc ? withAlpha(KatanaColors.crimson, 0.35) : KatanaColors.border}`,
                      background: exc ? withAlpha(KatanaColors.crimson, 0.22) : 'transparent',
                      color: exc ? KatanaColors.crimson : KatanaColors.textLight,
                      fontFamily: Fonts.body,
                      fontSize: 15,
                      fontWeight: 700,
                    }}
                  >
                    −
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );

  return (
    <div
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
            data={homeData}
            currentlyReading={myCurrentlyReading}
            libraryBookmarks={savedBookmarks}
            extraCatalog={catItems}
            downloadedCounts={downloadedCounts}
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
        <div style={{ flex: 1, overflowY: 'auto', padding: '16px 16px 40px' }}>
          <div style={{ maxWidth: 1380, margin: '0 auto' }}>
            {detailSlug ? (
              detailLoading ? (
                <KatanaSkeletonList count={3} />
              ) : !detail ? (
                <KatanaEmptyState
                  icon="error_outline"
                  title="Could not load this title"
                  subtitle="The manga details could not be reached right now."
                  actionLabel="Back to Home"
                  actionIcon="arrow_back"
                  onAction={closeDetail}
                />
              ) : (
                (() => {
                  const detailBm = bookmarks.find((b) => b.slug === detail.slug);
                  const isBookmarked = Boolean(detailBm?.bookmarked);
                  const hasReadingProgress = Boolean(detailBm?.lastReadChapterId);
                  const currentStatus = detailBm ? resolveLibraryStatus(detailBm) : undefined;
                  const readSet = new Set(detailBm?.readChapterIds ?? []);
                  const readCount = detail.chapters.filter((c) => readSet.has(c.id)).length;
                  const unreadCount = Math.max(0, detail.chapters.length - readCount);
                  const readPct = detail.chapters.length > 0 ? Math.round((readCount / detail.chapters.length) * 100) : 0;

                  const orderedChapters = chapterSortAsc ? [...detail.chapters].reverse() : detail.chapters;
                  const q = chapterSearch.trim().toLowerCase();
                  const filteredChapters = q
                    ? orderedChapters.filter(
                        (c) =>
                          chapterDisplayTitle(c).toLowerCase().includes(q) ||
                          c.num.toLowerCase().includes(q) ||
                          c.id.toLowerCase().includes(q),
                      )
                    : orderedChapters;
                  const visibleChapters = filteredChapters.slice(0, chapterWindow);

                  const toggleSelectChapter = (id: string) => {
                    setSelectedChapterIds((prev) => {
                      const next = new Set(prev);
                      if (next.has(id)) next.delete(id);
                      else next.add(id);
                      return next;
                    });
                  };

                  const seriesAccent = getSeriesVisualAccent(detail.title, detail.genres.map((g) => g.name));
                  const alertsEnabled = detailBm?.notifyOnUpdate !== false;

                  return (
                    <div>
                      <KatanaBreadcrumb items={['Manga', detail.title]} onHome={() => handleNav('home')} />

                      <KatanaCard
                        padding={tablet ? 20 : 14}
                        style={{
                          position: 'relative',
                          overflow: 'hidden',
                          backgroundImage: `radial-gradient(ellipse 70% 55% at 15% 0%, ${withAlpha(seriesAccent.accent, themeMode === 'dark' ? 0.16 : 0.12)}, transparent 70%)`,
                        }}
                      >
                        <div style={{ display: 'flex', gap: desktop ? 22 : 14, flexWrap: tablet ? 'nowrap' : 'wrap', alignItems: 'flex-start' }}>
                          <div
                            style={{
                              position: 'relative',
                              width: desktop ? 200 : tablet ? 160 : 112,
                              height: desktop ? 290 : tablet ? 232 : 162,
                              borderRadius: 10,
                              border: `1px solid ${KatanaColors.borderStrong}`,
                              overflow: 'hidden',
                              flexShrink: 0,
                              background: KatanaColors.surfaceAlt,
                            }}
                          >
                            <KatanaCoverImage url={detail.coverUrl} title={detail.title} iconSize={34} />
                            <KatanaCoverBadges unreadCount={isBookmarked ? unreadCount : undefined} downloadedCount={downloadedCounts[detail.slug]} />
                          </div>

                          <div style={{ flex: 1, minWidth: 200 }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', marginBottom: 6 }}>
                              <span
                                style={{
                                  padding: '2px 9px',
                                  borderRadius: 99,
                                  background: withAlpha(detail.status === 'completed' ? KatanaColors.green : KatanaColors.teal, 0.16),
                                  fontFamily: Fonts.body,
                                  fontSize: 11.5,
                                  fontWeight: 700,
                                  color: detail.status === 'completed' ? KatanaColors.green : KatanaColors.teal,
                                }}
                              >
                                {detail.status === 'completed' ? 'Finished Publishing' : 'Ongoing'}
                              </span>
                              {detail.rating != null && (
                                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}>
                                  <Icon name="star" size={14} color={KatanaColors.accent} />
                                  <span style={{ fontFamily: Fonts.body, fontSize: 12.5, fontWeight: 700, color: KatanaColors.text }}>
                                    {detail.rating.toFixed(1)}
                                  </span>
                                </span>
                              )}
                              {detail.follows != null && detail.follows > 0 && (
                                <span
                                  style={{
                                    padding: '2px 8px',
                                    borderRadius: 99,
                                    background: KatanaColors.surfaceAlt,
                                    border: `1px solid ${KatanaColors.border}`,
                                    ...KatanaType.small,
                                    fontSize: 12,
                                  }}
                                >
                                  {formatCompactNumber(detail.follows)} readers
                                </span>
                              )}
                              {detail.demographic && (
                                <span
                                  style={{
                                    padding: '2px 8px',
                                    borderRadius: 99,
                                    background: KatanaColors.surfaceAlt,
                                    border: `1px solid ${KatanaColors.border}`,
                                    ...KatanaType.small,
                                    fontSize: 12,
                                    color: KatanaColors.textMuted,
                                  }}
                                >
                                  {detail.demographic}
                                </span>
                              )}
                              <span
                                style={{
                                  padding: '2px 8px',
                                  borderRadius: 99,
                                  background: KatanaColors.surfaceAlt,
                                  border: `1px solid ${KatanaColors.border}`,
                                  ...KatanaType.small,
                                  fontSize: 12,
                                }}
                              >
                                {detail.chapters.length} ch
                              </span>
                              {detail.updateText && (
                                <span style={{ ...KatanaType.small, fontSize: 12 }}>{detail.updateText}</span>
                              )}
                            </div>

                            <h1 style={{ ...KatanaType.display, fontSize: tablet ? 28 : 21, margin: 0 }}>{detail.title}</h1>

                            {(detail.authors.length > 0 || detail.artists.length > 0) && (
                              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px 12px', marginTop: 6 }}>
                                {detail.authors.length > 0 && (
                                  <span style={{ ...KatanaType.body, fontSize: 13.5, color: KatanaColors.link, fontWeight: 600 }}>
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

                            {detail.altNames.length > 0 && (
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
                              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 10 }}>
                                {detail.genres.map((g) => (
                                  <button
                                    key={g.slug}
                                    type="button"
                                    className="bare-button"
                                    onClick={() => handleSelectGenre(g)}
                                    style={{
                                      padding: '4px 10px',
                                      borderRadius: 7,
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

                            {detail.chapters.length > 0 && (
                              <div style={{ marginTop: 12, maxWidth: 360 }}>
                                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
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

                            {/* Action bar: primary CTA + single compact equal-height secondary row on phone */}
                            <div style={{ marginTop: 14, display: 'flex', flexDirection: compactCard ? 'column' : 'row', gap: 8, alignItems: compactCard ? 'stretch' : 'center', flexWrap: 'wrap' }}>
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
                                  gap: compactCard ? 6 : 6,
                                  alignItems: 'center',
                                  flexWrap: compactCard ? 'nowrap' : 'wrap',
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
                                    height: 38,
                                    padding: compactCard ? '0 10px' : '0 12px',
                                    borderRadius: 8,
                                    background: isBookmarked ? withAlpha(KatanaColors.green, 0.14) : KatanaColors.surfaceAlt,
                                    border: `1px solid ${isBookmarked ? withAlpha(KatanaColors.green, 0.5) : KatanaColors.borderStrong}`,
                                    display: 'inline-flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                    gap: 4,
                                    fontFamily: Fonts.body,
                                    fontSize: compactCard ? 11.5 : 12,
                                    fontWeight: 700,
                                    color: isBookmarked ? KatanaColors.green : KatanaColors.text,
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
                                        height: 38,
                                        padding: compactCard ? '0 8px' : '0 12px',
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
                                          ? compactCard
                                            ? STATUS_LABELS[currentStatus].label
                                            : `Shelf: ${STATUS_LABELS[currentStatus].label}`
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
                                {!compactCard && detail.chapters.length > 0 && (
                                  <button
                                    type="button"
                                    className="bare-button"
                                    aria-label="Download next 3 unread chapters"
                                    title="Download next 3 unread chapters"
                                    disabled={batchProgress != null}
                                    onClick={() => void downloadNextUnread(detail, readSet, 3)}
                                    style={{
                                      height: 38,
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
                                      color: KatanaColors.link,
                                      flexShrink: 0,
                                      opacity: batchProgress != null ? 0.6 : 1,
                                    }}
                                  >
                                    <Icon name="download" size={16} color={KatanaColors.link} />
                                    <span>{batchProgress ? `Saving ${batchProgress.done}/${batchProgress.total}` : 'Download 3'}</span>
                                  </button>
                                )}
                                {!compactCard && userName && (
                                  <button
                                    type="button"
                                    className="bare-button"
                                    aria-label={alertsEnabled ? 'Mute new chapter alerts' : 'Enable new chapter alerts'}
                                    aria-pressed={alertsEnabled}
                                    title={alertsEnabled ? 'Chapter alerts: On (tap to mute)' : 'Chapter alerts: Off (tap to enable)'}
                                    onClick={() => void toggleSeriesAlerts(detail, alertsEnabled)}
                                    style={{
                                      width: 38,
                                      height: 38,
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
                                {!compactCard && (
                                  <button
                                    type="button"
                                    className="bare-button"
                                    aria-label="Share series link"
                                    title="Copy series link"
                                    onClick={() => void shareSeriesLink(detail)}
                                    style={{
                                      width: 38,
                                      height: 38,
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
                                        setTrackerMalDraft(detailBm?.malId ?? '');
                                        setTrackerNoteDraft(detailBm?.trackerNote ?? '');
                                      }
                                      setTrackerOpen((v) => !v);
                                    }}
                                    style={{
                                      minHeight: 38,
                                      padding: '0 11px',
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
                                    <span>{detailBm?.userScore ? `${detailBm.userScore}/10` : 'Track'}</span>
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
                                      width: compactCard ? 36 : 38,
                                      height: 38,
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
                                      {compactCard && (
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
                                          <Icon name="downloading" size={16} color={KatanaColors.link} />
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
                                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
                                  {detail.chapters.length > 0 && (
                                    <button
                                      type="button"
                                      className="bare-button"
                                      aria-label="Download next 3 unread chapters"
                                      disabled={batchProgress != null}
                                      onClick={() => void downloadNextUnread(detail, readSet, 3)}
                                      style={{
                                        flex: 1,
                                        minHeight: 38,
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
                                        color: KatanaColors.link,
                                        whiteSpace: 'nowrap',
                                        opacity: batchProgress != null ? 0.6 : 1,
                                      }}
                                    >
                                      <Icon name="download" size={15} color={KatanaColors.link} />
                                      <span>{batchProgress ? `Saving ${batchProgress.done}/${batchProgress.total}` : 'Download 3'}</span>
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
                                        minHeight: 38,
                                        padding: '0 10px',
                                        borderRadius: 8,
                                        background: alertsEnabled && isBookmarked ? withAlpha(KatanaColors.accent, 0.16) : KatanaColors.surfaceAlt,
                                        border: `1px solid ${alertsEnabled && isBookmarked ? withAlpha(KatanaColors.accent, 0.5) : KatanaColors.borderStrong}`,
                                        display: 'inline-flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        gap: 5,
                                        fontFamily: Fonts.body,
                                        fontSize: 12,
                                        fontWeight: 600,
                                        color: alertsEnabled && isBookmarked ? KatanaColors.accentSoft : KatanaColors.textMuted,
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

                          {desktop && detail.summary && (
                            <div
                              style={{
                                width: 340,
                                flexShrink: 0,
                                borderLeft: `1px solid ${KatanaColors.border}`,
                                paddingLeft: 20,
                                alignSelf: 'stretch',
                                display: 'flex',
                                flexDirection: 'column',
                                gap: 8,
                              }}
                            >
                              <div style={{ ...KatanaType.title, fontSize: 14, color: KatanaColors.textMuted, letterSpacing: 0.3 }}>
                                SYNOPSIS
                              </div>
                              <p style={{ ...KatanaType.body, margin: 0, fontSize: 13.5 }}>{detail.summary}</p>
                            </div>
                          )}
                        </div>

                        {!desktop && detail.summary && (
                          <div style={{ marginTop: 16, paddingTop: 14, borderTop: `1px solid ${KatanaColors.border}` }}>
                            <div style={{ ...KatanaType.title, fontSize: 15, marginBottom: 6 }}>Synopsis</div>
                            <p style={{ ...KatanaType.body, margin: 0 }}>{detail.summary}</p>
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
                                <span style={{ ...KatanaType.small, fontSize: 11.5 }}>
                                  Synced across your Everglow devices · Live MAL lookup is read-only (no third-party login required).
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
                                  style={{ width: 28, height: 28, borderRadius: 7, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}`, display: 'grid', placeItems: 'center' }}
                                >
                                  <Icon name="remove" size={15} color={KatanaColors.textMuted} />
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
                                  style={{ width: 28, height: 28, borderRadius: 7, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}`, display: 'grid', placeItems: 'center' }}
                                >
                                  <Icon name="add" size={15} color={KatanaColors.textMuted} />
                                </button>
                              </div>
                            </div>

                            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5, alignItems: 'center' }}>
                              <span style={{ ...KatanaType.small, marginRight: 4 }}>Score:</span>
                              {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((n) => {
                                const active = detailBm?.userScore === n;
                                return (
                                  <button
                                    key={n}
                                    type="button"
                                    className="bare-button"
                                    onClick={() => void saveKatanaTrackerData(detail, userName, { userScore: active ? null : n })}
                                    style={{
                                      minWidth: 32,
                                      height: 32,
                                      borderRadius: 7,
                                      background: active ? KatanaColors.accent : KatanaColors.surfaceAlt,
                                      border: `1px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                                      fontFamily: Fonts.body,
                                      fontSize: 12.5,
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
                                  placeholder="AniList ID — link-only (e.g. 105398)"
                                  aria-label="AniList ID (link-only)"
                                  style={{
                                    flex: 1,
                                    minWidth: 0,
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
                                {detailBm?.anilistId && (
                                  <a
                                    href={`https://anilist.co/manga/${encodeURIComponent(detailBm.anilistId)}`}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    aria-label="Open on AniList"
                                    title="Open on AniList"
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
                            </div>

                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
                              <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                                <KatanaButton
                                  label={trackerSyncing ? 'Syncing MAL…' : detailBm?.malId ? 'Sync MAL Now' : 'Auto-Match MAL'}
                                  icon="sync"
                                  size="sm"
                                  filled={false}
                                  color={KatanaColors.link}
                                  disabled={trackerSyncing}
                                  onClick={() => void syncSeriesWithMal(detail, extractTrackerId(trackerMalDraft, 'mal') || detailBm?.malId)}
                                />
                                {detailBm?.malScore != null && (
                                  <span style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 700 }}>
                                    MAL ★ {detailBm.malScore.toFixed(2)}
                                    {detailBm.malRank ? ` · #${detailBm.malRank}` : ''}
                                    {detailBm.malTotalChapters ? ` · ${detailBm.malTotalChapters} ch` : ''}
                                  </span>
                                )}
                              </div>
                              {detailBm?.lastSyncedAt && (
                                <span style={{ ...KatanaType.small, fontSize: 11.5 }}>
                                  Synced {formatKatanaTime(detailBm.lastSyncedAt)}
                                  {detailBm.malTotalChapters != null && readCount > 0
                                    ? ` · Local ${readCount}/${detailBm.malTotalChapters} ch`
                                    : ''}
                                </span>
                              )}
                            </div>

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
                                  const mal = extractTrackerId(trackerMalDraft, 'mal');
                                  void saveKatanaTrackerData(detail, userName, {
                                    anilistId: al || null,
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
                      </KatanaCard>

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
                                    <Icon name="downloading" size={16} color={KatanaColors.link} />
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
                                        padding: '3px 8px',
                                        borderRadius: 6,
                                        background: withAlpha(KatanaColors.crimson, 0.14),
                                        border: `1px solid ${withAlpha(KatanaColors.crimson, 0.4)}`,
                                        fontFamily: Fonts.body,
                                        fontSize: 11.5,
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
                          <KatanaSectionHeader title="Chapters" badge={String(detail.chapters.length)} />
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                            {detail.chapters.length > 0 && (
                              <button
                                type="button"
                                className="bare-button"
                                onClick={() => void handleLoadPreview(detail)}
                                aria-expanded={previewPages?.slug === detail.slug}
                                style={{
                                  minHeight: 34,
                                  padding: '6px 10px',
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
                                <span>Jump to {detailBm.lastReadChapterTitle || 'last read'}</span>
                              </button>
                            )}
                            <button
                              type="button"
                              className="bare-button"
                              onClick={() => setChapterSortAsc((v) => !v)}
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
                                color: KatanaColors.text,
                              }}
                            >
                              <Icon name="swap_vert" size={15} color={KatanaColors.textMuted} />
                              <span>{chapterSortAsc ? 'Oldest first' : 'Newest first'}</span>
                            </button>
                            {detail.chapters.length >= 10 && (
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
                            {detail.chapters.length > 0 && (
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
                            {userName && detail.chapters.length > 0 && !selectMode && (
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
                                  label="Unread"
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
                                label="Download"
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
                              height: 38,
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
                                      style={{ width: 38, height: 38, display: 'grid', placeItems: 'center', flexShrink: 0 }}
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
                                      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                                        <span
                                          className="ellipsis"
                                          style={{
                                            ...KatanaType.title,
                                            fontSize: 13.5,
                                            color: isRead && !isLastRead ? KatanaColors.textMuted : KatanaColors.text,
                                            flex: 1,
                                            minWidth: 0,
                                          }}
                                        >
                                          {chapterDisplayTitle(c)}
                                        </span>
                                        {c.isNew && (
                                          <span
                                            style={{
                                              padding: '1px 6px',
                                              borderRadius: 4,
                                              background: KatanaColors.crimson,
                                              color: '#FFFFFF',
                                              fontFamily: Fonts.body,
                                              fontSize: 10,
                                              fontWeight: 800,
                                              flexShrink: 0,
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
                                              fontSize: 10,
                                              fontWeight: 800,
                                              flexShrink: 0,
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
                                              fontSize: 10,
                                              fontWeight: 800,
                                              flexShrink: 0,
                                            }}
                                          >
                                            LAST READ
                                          </span>
                                        )}
                                      </div>
                                      {compactCard && (c.updateAt || isOffline || true) && (
                                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 2, flexWrap: 'wrap' }}>
                                          {c.updateAt && (
                                            <span style={{ ...KatanaType.small, fontSize: 11.5 }}>{formatKatanaTime(c.updateAt)}</span>
                                          )}
                                          <span style={{ ...KatanaType.small, fontSize: 10.5, color: KatanaColors.textLight }}>
                                            {c.updateAt ? '· MangaKatana' : 'MangaKatana'}
                                          </span>
                                          {isOffline && (
                                            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, fontFamily: Fonts.body, fontSize: 11, fontWeight: 600, color: KatanaColors.green }}>
                                              <Icon name="download_done" size={13} color={KatanaColors.green} />
                                              Offline
                                            </span>
                                          )}
                                        </div>
                                      )}
                                    </div>
                                    {!compactCard && (
                                      <span style={{ ...KatanaType.small, fontSize: 11.5, whiteSpace: 'nowrap', flexShrink: 0 }}>
                                        {c.updateAt ? `${formatKatanaTime(c.updateAt)} · MangaKatana` : 'MangaKatana'}
                                      </span>
                                    )}
                                  </button>

                                  {!selectMode && compactCard && (
                                    <button
                                      type="button"
                                      className="bare-button"
                                      aria-label={`Actions for ${chapterDisplayTitle(c)}`}
                                      aria-expanded={isMenuOpen}
                                      onClick={() => setChapterActionMenuId((cur) => (cur === c.id ? null : c.id))}
                                      style={{
                                        width: 38,
                                        height: 38,
                                        borderRadius: 8,
                                        background: isMenuOpen ? KatanaColors.chipSelectedBg : 'transparent',
                                        display: 'grid',
                                        placeItems: 'center',
                                        flexShrink: 0,
                                      }}
                                    >
                                      <Icon name="more_vert" size={19} color={isMenuOpen ? KatanaColors.accentSoft : KatanaColors.textMuted} />
                                    </button>
                                  )}

                                  {!selectMode && !compactCard && userName && (
                                    <>
                                      <button
                                        type="button"
                                        className="bare-button"
                                        title={isRead ? 'Mark unread' : 'Mark read'}
                                        aria-label={isRead ? `Mark ${chapterDisplayTitle(c)} unread` : `Mark ${chapterDisplayTitle(c)} read`}
                                        onClick={() => void markKatanaChaptersRead(detail, userName, [c.id], !isRead)}
                                        style={{
                                          padding: '5px 9px',
                                          borderRadius: 7,
                                          background: KatanaColors.background,
                                          border: `1px solid ${KatanaColors.border}`,
                                          display: 'inline-flex',
                                          alignItems: 'center',
                                          gap: 4,
                                          fontFamily: Fonts.body,
                                          fontSize: 11.5,
                                          fontWeight: 600,
                                          color: isRead ? KatanaColors.textMuted : KatanaColors.text,
                                          flexShrink: 0,
                                        }}
                                      >
                                        <Icon name={isRead ? 'visibility_off' : 'check'} size={14} color={isRead ? KatanaColors.textLight : KatanaColors.green} />
                                        <span>{isRead ? 'Unread' : 'Read'}</span>
                                      </button>
                                      <button
                                        type="button"
                                        className="bare-button"
                                        title="More chapter actions"
                                        aria-label={`More actions for ${chapterDisplayTitle(c)}`}
                                        aria-expanded={isMenuOpen}
                                        onClick={() => setChapterActionMenuId(isMenuOpen ? null : c.id)}
                                        style={{
                                          width: 36,
                                          height: 36,
                                          borderRadius: 8,
                                          background: isMenuOpen ? KatanaColors.chipSelectedBg : 'transparent',
                                          display: 'grid',
                                          placeItems: 'center',
                                          flexShrink: 0,
                                        }}
                                      >
                                        <Icon name="more_vert" size={18} color={isMenuOpen ? KatanaColors.accentSoft : KatanaColors.textLight} />
                                      </button>
                                    </>
                                  )}

                                  {!selectMode && !compactCard && (
                                    <button
                                      type="button"
                                      className="bare-button"
                                      disabled={isDownloading}
                                      title={isOffline ? 'Saved offline' : isDownloading ? 'Downloading chapter…' : 'Download chapter'}
                                      aria-label={
                                        isOffline
                                          ? `${chapterDisplayTitle(c)} saved offline`
                                          : isDownloading
                                            ? `Downloading ${chapterDisplayTitle(c)}`
                                            : `Download ${chapterDisplayTitle(c)}`
                                      }
                                      onClick={() => void downloadChapter(detail, c)}
                                      style={{
                                        width: 40,
                                        height: 40,
                                        borderRadius: 8,
                                        display: 'grid',
                                        placeItems: 'center',
                                        flexShrink: 0,
                                        opacity: isDownloading ? 0.7 : 1,
                                      }}
                                    >
                                      <Icon
                                        name={isOffline ? 'download_done' : isDownloading ? 'hourglass_top' : 'download'}
                                        size={19}
                                        color={isOffline ? KatanaColors.green : isDownloading ? KatanaColors.accent : KatanaColors.textMuted}
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
                          <aside style={{ width: desktop ? 340 : 240, flexShrink: 0 }}>
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
                  <KatanaSectionHeader title="My Library" badge={String(savedBookmarks.length)} />
                  {compactCard ? (
                    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                      <button
                        type="button"
                        className="bare-button"
                        disabled={libraryRefreshing}
                        onClick={() => void handleRefreshLibrary()}
                        aria-label="Refresh library updates"
                        style={{
                          width: 36,
                          height: 36,
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
                          height: 36,
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
                                width: 30,
                                height: 26,
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
                        <button type="button" className="bare-button" aria-label="Close library tools" onClick={() => setLibraryToolsOpen(false)} style={{ width: 36, height: 36, display: 'grid', placeItems: 'center' }}>
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
                                  height: 38,
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
                        <div style={{ ...KatanaType.title, fontSize: 13.5 }}>Library Backup & Tracker Export</div>
                        <div style={{ ...KatanaType.small, marginTop: 2 }}>
                          Export your shelves, ratings, and reading progress as JSON or MyAnimeList / AniList XML.
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
                            URL.revokeObjectURL(url);
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
                            URL.revokeObjectURL(url);
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
                        <div style={{ ...KatanaType.title, fontSize: 13 }}>Chapter Alert Controls</div>
                        <div style={{ ...KatanaType.small, marginTop: 2 }}>
                          Reduce notification noise with daily summaries or quiet hours (10 PM–8 AM).
                        </div>
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
                                minHeight: 34,
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
                            showSnackBar(next.quietHours ? 'Quiet hours enabled (10 PM–8 AM)' : 'Quiet hours turned off');
                          }}
                          style={{
                            minHeight: 34,
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
                            minHeight: 34,
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
                            minHeight: 34,
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
                  const estHours = Math.max(1, Math.round((totalChaptersRead * 4) / 60));
                  const statusSegments: Array<{ key: KatanaLibraryStatus; label: string; count: number; color: string }> = [
                    { key: 'reading', label: 'Reading', count: libraryCounts.reading, color: KatanaColors.accent },
                    { key: 'completed', label: 'Completed', count: libraryCounts.completed, color: KatanaColors.green },
                    { key: 'planned', label: 'Plan to Read', count: libraryCounts.planned, color: KatanaColors.link },
                    { key: 'on_hold', label: 'On Hold', count: libraryCounts.on_hold, color: KatanaColors.orange },
                    { key: 'dropped', label: 'Dropped', count: libraryCounts.dropped, color: KatanaColors.crimson },
                  ];
                  return (
                    <KatanaCard padding={14} radius={12} style={{ marginTop: 12 }}>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
                        <span style={{ ...KatanaType.title, fontSize: 14 }}>Reading Statistics</span>
                        <span style={{ ...KatanaType.small, fontSize: 11.5 }}>{historyEntries.length} recent chapters logged</span>
                      </div>
                      <div style={{ display: 'grid', gridTemplateColumns: compactCard ? 'repeat(2, minmax(0, 1fr))' : 'repeat(4, minmax(0, 1fr))', gap: 8, marginBottom: 12 }}>
                        {[
                          { label: 'Chapters Read', value: String(totalChaptersRead), color: KatanaColors.accent },
                          { label: 'Est. Time', value: `~${estHours}h`, color: KatanaColors.link },
                          { label: 'Completion', value: `${completionPct}%`, color: KatanaColors.green },
                          { label: 'Avg Rating', value: rated.length > 0 ? `${avgScore.toFixed(1)}/10` : '—', color: KatanaColors.orange },
                        ].map((m) => (
                          <div key={m.label} style={{ padding: '8px 10px', borderRadius: 9, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}` }}>
                            <div style={{ ...KatanaType.small, fontSize: 11 }}>{m.label}</div>
                            <div style={{ fontFamily: Fonts.display, fontSize: 18, fontWeight: 800, color: m.color, marginTop: 2 }}>{m.value}</div>
                          </div>
                        ))}
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
                <div style={{ position: 'relative', marginTop: 14 }}>
                <div
                  ref={shelfChipsRef}
                  className="no-scrollbar"
                  style={{
                    display: 'flex',
                    gap: 8,
                    overflowX: 'auto',
                    paddingBottom: 2,
                    paddingRight: 40,
                    maskImage: 'linear-gradient(to right, black 84%, transparent 100%)',
                    WebkitMaskImage: 'linear-gradient(to right, black 84%, transparent 100%)',
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
                            ? 'Downloaded'
                            : STATUS_LABELS[bucket].label;
                    return (
                      <button
                        key={bucket}
                        type="button"
                        className="bare-button"
                        onClick={() => setLibraryBucket(bucket)}
                        style={{
                          flexShrink: 0,
                          minHeight: compactCard ? 40 : 34,
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
                      position: 'absolute',
                      right: 0,
                      top: '50%',
                      transform: 'translateY(-50%)',
                      width: 32,
                      height: 32,
                      borderRadius: 99,
                      background: KatanaColors.surface,
                      border: `1px solid ${KatanaColors.borderStrong}`,
                      display: 'grid',
                      placeItems: 'center',
                      boxShadow: '0 2px 8px rgba(0,0,0,0.35)',
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
                        height: 38,
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
                {savedBookmarks.length > 0 && (!compactCard || librarySort === 'title') && (
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
                            background: active ? KatanaColors.accent : KatanaColors.surfaceAlt,
                            border: `1px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                            fontFamily: Fonts.body,
                            fontSize: 11.5,
                            fontWeight: 700,
                            color: active ? KatanaColors.accentInk : KatanaColors.textMuted,
                          }}
                        >
                          {ch === 'all' ? 'A–Z' : ch}
                        </button>
                      );
                    })}
                  </div>
                )}

                <div style={{ height: 14 }} />
                {filteredLibrary.length === 0 ? (
                  <KatanaEmptyState
                    icon="bookmarks"
                    title={savedBookmarks.length === 0 ? 'Your library is empty' : 'No titles match this filter'}
                    subtitle={
                      savedBookmarks.length === 0
                        ? 'Add manga, manhwa, or manhua from any detail page to track reading progress and organize shelves.'
                        : 'Try switching shelves or clearing your search.'
                    }
                    actionLabel={savedBookmarks.length === 0 ? 'Explore Catalog' : 'Show All'}
                    actionIcon={savedBookmarks.length === 0 ? 'explore' : 'restart_alt'}
                    onAction={() => {
                      if (savedBookmarks.length === 0) handleNav('directory');
                      else {
                        setLibraryBucket('all');
                        setLibraryQuery('');
                      }
                    }}
                  />
                ) : libraryViewMode === 'list' ? (
                  <div style={{ display: 'grid', gridTemplateColumns: desktop ? 'repeat(3, minmax(0, 1fr))' : tablet ? 'repeat(2, minmax(0, 1fr))' : '1fr', gap: 12 }}>
                    {filteredLibrary.map((bm) => {
                      const st = resolveLibraryStatus(bm);
                      const meta = STATUS_LABELS[st];
                      const unread = estimateUnreadCount(bm);
                      const dlCount = downloadedCounts[bm.slug] ?? 0;
                      const caughtUp = isBookmarkCaughtUp(bm);
                      const selected = selectedLibrarySlugs.has(bm.slug);
                      const actionLabel =
                        st === 'completed'
                          ? 'Re-read'
                          : caughtUp || !bm.lastReadChapterId
                            ? 'Read'
                            : 'Resume';
                      return (
                        <KatanaCard
                          key={bm.slug}
                          padding={12}
                          style={selected ? { borderColor: KatanaColors.accent, background: withAlpha(KatanaColors.accent, 0.06) } : undefined}
                        >
                          <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
                            {librarySelectMode && (
                              <button
                                type="button"
                                className="bare-button"
                                aria-label={`Select ${bm.title}`}
                                onClick={() => toggleSelectLibrarySlug(bm.slug)}
                                style={{ width: 32, height: 32, display: 'grid', placeItems: 'center', flexShrink: 0, marginTop: 2 }}
                              >
                                <Icon
                                  name={selected ? 'check_box' : 'check_box_outline_blank'}
                                  size={20}
                                  color={selected ? KatanaColors.accent : KatanaColors.textLight}
                                />
                              </button>
                            )}
                            <button
                              type="button"
                              className="bare-button"
                              aria-label={`Open ${bm.title}`}
                              onClick={() => (librarySelectMode ? toggleSelectLibrarySlug(bm.slug) : openDetail(bm.slug))}
                              style={{ position: 'relative', width: 72, height: 104, borderRadius: 8, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}
                            >
                              <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={22} />
                              <KatanaCoverBadges unreadCount={unread} downloadedCount={dlCount} />
                            </button>
                            <div style={{ flex: 1, minWidth: 0 }}>
                              <button
                                type="button"
                                className="bare-button"
                                onClick={() => (librarySelectMode ? toggleSelectLibrarySlug(bm.slug) : openDetail(bm.slug))}
                                style={{ textAlign: 'left', width: '100%' }}
                              >
                                <div className="clamp-2" style={KatanaType.title}>{bm.title}</div>
                              </button>
                              <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap', marginTop: 6 }}>
                                <span
                                  style={{
                                    padding: '2px 8px',
                                    borderRadius: 99,
                                    background: withAlpha(meta.color, 0.16),
                                    fontFamily: Fonts.body,
                                    fontSize: 11,
                                    fontWeight: 700,
                                    color: meta.color,
                                  }}
                                >
                                  {caughtUp ? 'Caught Up' : meta.label}
                                </span>
                                {bm.readChapterIds.length > 0 && (
                                  <span style={KatanaType.small}>{bm.readChapterIds.length} ch read</span>
                                )}
                              </div>
                              {bm.lastReadChapterTitle && (
                                <div style={{ ...KatanaType.small, color: KatanaColors.link, marginTop: 6 }}>
                                  {bm.lastReadChapterTitle}
                                  {bm.latestChapterTitle ? ` · Latest: ${bm.latestChapterTitle}` : ''}
                                </div>
                              )}
                              {!librarySelectMode && (
                                <div style={{ marginTop: 8, display: 'flex', gap: 6 }}>
                                  <KatanaButton
                                    label={actionLabel}
                                    icon="play_arrow"
                                    size="sm"
                                    onClick={() => void resumeBookmark(bm)}
                                  />
                                </div>
                              )}
                            </div>
                          </div>
                        </KatanaCard>
                      );
                    })}
                  </div>
                ) : (
                  <div
                    style={{
                      display: 'grid',
                      gridTemplateColumns: `repeat(${getKatanaGridColumns(width, libraryViewMode === 'compact')}, minmax(0, 1fr))`,
                      gap: libraryViewMode === 'compact' ? 10 : 14,
                    }}
                  >
                    {filteredLibrary.map((bm) => {
                      const unread = estimateUnreadCount(bm);
                      const dlCount = downloadedCounts[bm.slug] ?? 0;
                      const selected = selectedLibrarySlugs.has(bm.slug);
                      return (
                        <div
                          key={bm.slug}
                          style={{
                            position: 'relative',
                            borderRadius: 11,
                            overflow: 'hidden',
                            background: KatanaColors.surface,
                            border: `2px solid ${selected ? KatanaColors.accent : KatanaColors.border}`,
                            display: 'flex',
                            flexDirection: 'column',
                          }}
                        >
                          <button
                            type="button"
                            className="bare-button"
                            onClick={() => (librarySelectMode ? toggleSelectLibrarySlug(bm.slug) : openDetail(bm.slug))}
                            style={{
                              textAlign: 'left',
                              display: 'flex',
                              flexDirection: 'column',
                              flex: 1,
                              width: '100%',
                            }}
                          >
                            <div style={{ position: 'relative', width: '100%', aspectRatio: '2 / 3', background: KatanaColors.surfaceAlt }}>
                              <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={24} />
                              <KatanaCoverBadges unreadCount={unread} downloadedCount={dlCount} />
                              {bm.userScore != null && !librarySelectMode && (
                                <span
                                  style={{
                                    position: 'absolute',
                                    top: 6,
                                    left: 6,
                                    padding: '2px 6px',
                                    borderRadius: 6,
                                    background: withAlpha(KatanaColors.background, 0.86),
                                    border: `1px solid ${withAlpha(KatanaColors.accent, 0.55)}`,
                                    fontFamily: Fonts.body,
                                    fontSize: 10.5,
                                    fontWeight: 800,
                                    color: KatanaColors.accentSoft,
                                  }}
                                >
                                  ★ {bm.userScore}
                                </span>
                              )}
                              {librarySelectMode && (
                                <span
                                  style={{
                                    position: 'absolute',
                                    top: 6,
                                    left: 6,
                                    width: 24,
                                    height: 24,
                                    borderRadius: 6,
                                    background: selected ? KatanaColors.accent : withAlpha(KatanaColors.background, 0.78),
                                    display: 'grid',
                                    placeItems: 'center',
                                  }}
                                >
                                  <Icon
                                    name={selected ? 'check' : 'check_box_outline_blank'}
                                    size={16}
                                    color={selected ? KatanaColors.accentInk : KatanaColors.text}
                                  />
                                </span>
                              )}
                              {libraryViewMode === 'compact' && (
                                <div
                                  style={{
                                    position: 'absolute',
                                    inset: 'auto 0 0 0',
                                    padding: '22px 44px 8px 8px',
                                    background: `linear-gradient(to top, ${withAlpha(KatanaColors.background, 0.94)}, transparent)`,
                                  }}
                                >
                                  <div className="clamp-2" style={{ fontFamily: Fonts.body, fontSize: 12.5, fontWeight: 700, color: KatanaColors.text, lineHeight: 1.2 }}>
                                    {bm.title}
                                  </div>
                                </div>
                              )}
                            </div>
                            {libraryViewMode === 'grid' && (
                              <div style={{ padding: '8px 9px 10px' }}>
                                <div className="clamp-2" style={{ fontFamily: Fonts.body, fontSize: 13, fontWeight: 600, color: KatanaColors.text, lineHeight: 1.25 }}>
                                  {bm.title}
                                </div>
                                <div className="ellipsis" style={{ ...KatanaType.small, fontSize: 11.5, marginTop: 3 }}>
                                  {bm.lastReadChapterTitle || STATUS_LABELS[resolveLibraryStatus(bm)].label}
                                </div>
                              </div>
                            )}
                          </button>
                          {!librarySelectMode && (
                            <button
                              type="button"
                              className="bare-button"
                              aria-label={`Resume ${bm.title}`}
                              title={bm.lastReadChapterTitle ? `Resume ${bm.lastReadChapterTitle}` : `Start ${bm.title}`}
                              onClick={(e) => {
                                e.stopPropagation();
                                void resumeBookmark(bm);
                              }}
                              style={{
                                position: 'absolute',
                                right: 7,
                                bottom: libraryViewMode === 'grid' ? 54 : 7,
                                width: 34,
                                height: 34,
                                borderRadius: 99,
                                background: KatanaColors.accent,
                                boxShadow: '0 4px 12px rgba(0,0,0,0.55)',
                                display: 'grid',
                                placeItems: 'center',
                              }}
                            >
                              <Icon name="play_arrow" size={19} color={KatanaColors.accentInk} />
                            </button>
                          )}
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            ) : tab === 'reading' || tab === 'history' ? (
              <div>
                <KatanaBreadcrumb items={[tab === 'history' ? 'History' : 'Currently Reading']} onHome={() => handleNav('home')} />
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                    <KatanaSectionHeader
                      title={
                        tab === 'history'
                          ? historySubView === 'updates'
                            ? 'Chapter Updates Inbox'
                            : 'Reading History'
                          : 'Currently Reading'
                      }
                      badge={String(
                        tab === 'history'
                          ? historySubView === 'updates'
                            ? savedBookmarks.filter((b) => estimateUnreadCount(b) > 0).length
                            : historyEntries.length
                          : currentlyReading.length,
                      )}
                    />
                    <div style={{ display: 'inline-flex', gap: 4, padding: 3, borderRadius: 99, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}` }}>
                      {(
                        [
                          ['reading', 'Reading'],
                          ['history', 'History'],
                          ['updates', `Updates (${savedBookmarks.filter((b) => estimateUnreadCount(b) > 0).length})`],
                        ] as const
                      ).map(([k, lbl]) => {
                        const active =
                          k === 'reading'
                            ? tab === 'reading'
                            : k === 'history'
                              ? tab === 'history' && historySubView === 'history'
                              : tab === 'history' && historySubView === 'updates';
                        return (
                          <button
                            key={k}
                            type="button"
                            className="bare-button"
                            onClick={() => {
                              if (k === 'reading') {
                                handleNav('reading');
                              } else if (k === 'history') {
                                setHistorySubView('history');
                                if (tab !== 'history') handleNav('history');
                              } else {
                                setHistorySubView('updates');
                                if (tab !== 'history') handleNav('history');
                              }
                            }}
                            style={{
                              minHeight: 34,
                              padding: '4px 12px',
                              borderRadius: 99,
                              background: active ? KatanaColors.accent : 'transparent',
                              fontFamily: Fonts.body,
                              fontSize: 12.5,
                              fontWeight: 700,
                              color: active ? KatanaColors.accentInk : KatanaColors.textMuted,
                            }}
                          >
                            {lbl}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                  {tab === 'history' && historySubView === 'history' ? (
                    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                      <button
                        type="button"
                        className="bare-button"
                        aria-pressed={historyPaused}
                        onClick={() => {
                          const next = !historyPaused;
                          setHistoryPaused(next);
                          setKatanaHistoryPaused(userName, next);
                          showSnackBar(next ? 'History paused (Incognito mode)' : 'History recording resumed');
                        }}
                        style={{
                          minHeight: 34,
                          padding: '5px 11px',
                          borderRadius: 99,
                          background: historyPaused ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                          border: `1px solid ${historyPaused ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 5,
                          fontFamily: Fonts.body,
                          fontSize: 12,
                          fontWeight: 700,
                          color: historyPaused ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                        }}
                      >
                        <Icon name={historyPaused ? 'visibility_off' : 'history_toggle_off'} size={15} color={historyPaused ? KatanaColors.accent : KatanaColors.textMuted} />
                        <span>{historyPaused ? 'History Paused' : 'Pause History'}</span>
                      </button>
                      {historyEntries.length > 0 && (
                        <KatanaButton
                          label="Clear History"
                          icon="delete_sweep"
                          size="sm"
                          filled={false}
                          color={KatanaColors.textMuted}
                          onClick={() =>
                            void showDialog<void>((close) => (
                              <AlertDialog
                                background={KatanaColors.surface}
                                title={<div style={KatanaType.title}>Clear Reading History</div>}
                                content={<div style={KatanaType.small}>Remove all entries from your reading history? Your saved library bookmarks stay intact.</div>}
                                actions={[
                                  <TextButton key="cancel" onPressed={() => close(null)} color={KatanaColors.textMuted}>
                                    Cancel
                                  </TextButton>,
                                  <TextButton
                                    key="clear"
                                    color="#FF453A"
                                    onPressed={() => {
                                      close(null);
                                      clearKatanaHistory(userName);
                                      setHistoryEntries([]);
                                      showSnackBar('Cleared reading history');
                                    }}
                                  >
                                    Clear History
                                  </TextButton>,
                                ]}
                              />
                            ))
                          }
                        />
                      )}
                    </div>
                  ) : tab === 'reading' && isCoupleUser && partnerUsername ? (
                    <div style={{ display: 'inline-flex', gap: 4, padding: 3, borderRadius: 99, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}` }}>
                      {[false, true].map((partner) => {
                        const active = showPartnerReading === partner;
                        const label = partner ? partnerDisplayLabel : 'Mine';
                        return (
                          <button
                            key={label}
                            type="button"
                            className="bare-button"
                            onClick={() => setShowPartnerReading(partner)}
                            style={{
                              padding: '5px 12px',
                              borderRadius: 99,
                              background: active ? KatanaColors.accent : 'transparent',
                              fontFamily: Fonts.body,
                              fontSize: 12.5,
                              fontWeight: 700,
                              color: active ? KatanaColors.accentInk : KatanaColors.textMuted,
                            }}
                          >
                            {label}
                          </button>
                        );
                      })}
                    </div>
                  ) : null}
                </div>
                <div style={{ height: 14 }} />
                {tab === 'history' && historySubView === 'updates' ? (
                  (() => {
                    const updatedSeries = savedBookmarks
                      .filter((b) => estimateUnreadCount(b) > 0)
                      .sort((a, b) => estimateUnreadCount(b) - estimateUnreadCount(a) || (b.lastReadAt?.getTime() ?? b.addedAt.getTime()) - (a.lastReadAt?.getTime() ?? a.addedAt.getTime()));
                    if (updatedSeries.length === 0) {
                      return (
                        <KatanaEmptyState
                          icon="notifications_none"
                          title="You're all caught up"
                          subtitle="New chapters for your followed series will appear here as soon as they drop."
                          actionLabel="Browse Manga"
                          actionIcon="home"
                          onAction={() => handleNav('home')}
                        />
                      );
                    }
                    return (
                      <div style={{ display: 'grid', gridTemplateColumns: tablet ? 'repeat(2, minmax(0, 1fr))' : '1fr', gap: 10 }}>
                        {updatedSeries.map((bm) => {
                          const unread = estimateUnreadCount(bm);
                          return (
                            <KatanaCard key={bm.slug} padding={compactCard ? 9 : 11}>
                              <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
                                <button
                                  type="button"
                                  className="bare-button"
                                  onClick={() => openDetail(bm.slug)}
                                  style={{ display: 'flex', alignItems: 'center', gap: 10, flex: 1, minWidth: 0, textAlign: 'left', overflow: 'hidden' }}
                                >
                                  <div style={{ position: 'relative', width: 46, height: 66, borderRadius: 7, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                                    <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={18} />
                                  </div>
                                  <div style={{ flex: 1, minWidth: 0 }}>
                                    <div className="ellipsis" style={{ ...KatanaType.title, fontSize: compactCard ? 13.5 : 14.5 }}>{bm.title}</div>
                                    <div className="ellipsis" style={{ ...KatanaType.accent, fontSize: 12, marginTop: 2 }}>
                                      {unread} new {unread === 1 ? 'chapter' : 'chapters'}
                                      {bm.latestChapterTitle ? ` · ${bm.latestChapterTitle}` : ''}
                                    </div>
                                    <div className="ellipsis" style={{ ...KatanaType.small, fontSize: 11, marginTop: 2 }}>
                                      {bm.lastReadChapterTitle ? `Last read: ${bm.lastReadChapterTitle}` : 'Not started yet'}
                                    </div>
                                  </div>
                                </button>
                                <KatanaButton
                                  label="Read"
                                  icon="play_arrow"
                                  size="sm"
                                  onClick={() => void resumeBookmark(bm)}
                                />
                              </div>
                            </KatanaCard>
                          );
                        })}
                      </div>
                    );
                  })()
                ) : tab === 'history' ? (
                  historyEntries.length === 0 ? (
                    <KatanaEmptyState
                      icon="history"
                      title="No reading history yet"
                      subtitle="Every chapter you open appears here in chronological order so you can jump right back in."
                      actionLabel="Browse Manga"
                      actionIcon="home"
                      onAction={() => handleNav('home')}
                    />
                  ) : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                      {groupedHistory.map((group) => (
                        <section key={group.label} aria-label={`${group.label} reading history`}>
                          <div style={{ ...KatanaType.small, fontWeight: 700, color: KatanaColors.textMuted, marginBottom: 8, textTransform: 'uppercase', letterSpacing: 0.6 }}>
                            {group.label} ({group.items.length})
                          </div>
                          <div style={{ display: 'grid', gridTemplateColumns: tablet ? 'repeat(2, minmax(0, 1fr))' : '1fr', gap: 10 }}>
                            {group.items.map((entry) => (
                              <KatanaCard key={`${entry.slug}-${entry.chapterId}-${entry.readAt}`} padding={compactCard ? 8 : 10}>
                                <div style={{ display: 'flex', alignItems: 'center', gap: compactCard ? 8 : 12, minWidth: 0 }}>
                                  <button
                                    type="button"
                                    className="bare-button"
                                    onClick={() => openDetail(entry.slug)}
                                    style={{ display: 'flex', alignItems: 'center', gap: compactCard ? 9 : 12, flex: 1, minWidth: 0, textAlign: 'left', overflow: 'hidden' }}
                                  >
                                    <div style={{ position: 'relative', width: compactCard ? 42 : 48, height: compactCard ? 60 : 68, borderRadius: 7, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                                      <KatanaCoverImage url={entry.coverUrl} title={entry.title} iconSize={18} />
                                    </div>
                                    <div style={{ flex: 1, minWidth: 0 }}>
                                      <div className="ellipsis" style={{ ...KatanaType.title, fontSize: compactCard ? 13.5 : 14.5 }}>{entry.title}</div>
                                      <div className="ellipsis" style={{ ...KatanaType.accent, fontSize: 12, marginTop: 2 }}>{entry.chapterTitle}</div>
                                      <div className="ellipsis" style={{ ...KatanaType.small, fontSize: 11, marginTop: 2 }}>
                                        {formatKatanaTime(new Date(entry.readAt))}
                                        {entry.page && entry.page > 1 ? ` · Page ${entry.page}` : ''}
                                      </div>
                                    </div>
                                  </button>
                                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, flexShrink: 0 }}>
                                    <KatanaButton
                                      label="Read"
                                      icon="play_arrow"
                                      size="sm"
                                      onClick={() => {
                                        void (async () => {
                                          const loaded = await fetchKatanaDetail(entry.slug);
                                          if (loaded && loaded.chapters.length > 0) {
                                            openChapter(loaded, entry.chapterId, entry.page || 1);
                                          } else {
                                            openDetail(entry.slug);
                                          }
                                        })();
                                      }}
                                    />
                                    <button
                                      type="button"
                                      className="bare-button"
                                      aria-label={`Remove ${entry.title} ${entry.chapterTitle} from history`}
                                      onClick={() => setHistoryEntries(removeKatanaHistoryEntry(userName, entry.slug, entry.chapterId))}
                                      style={{ width: 36, height: 36, borderRadius: 8, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}`, display: 'grid', placeItems: 'center', flexShrink: 0 }}
                                    >
                                      <Icon name="close" size={16} color={KatanaColors.textMuted} />
                                    </button>
                                  </div>
                                </div>
                              </KatanaCard>
                            ))}
                          </div>
                        </section>
                      ))}
                    </div>
                  )
                ) : currentlyReading.length === 0 ? (
                  <KatanaEmptyState
                    icon="auto_stories"
                    title={showPartnerReading ? `${partnerDisplayLabel} isn't reading anything right now` : 'Nothing in progress'}
                    subtitle="Open any chapter to track your place automatically across devices."
                    actionLabel="Browse Manga"
                    actionIcon="home"
                    onAction={() => handleNav('home')}
                  />
                ) : (
                  <div style={{ display: 'grid', gridTemplateColumns: tablet ? 'repeat(2, minmax(0, 1fr))' : '1fr', gap: 12 }}>
                    {currentlyReading.map((bm) => {
                      const unread = estimateUnreadCount(bm);
                      const dlCount = downloadedCounts[bm.slug] ?? 0;
                      const caughtUp = isBookmarkCaughtUp(bm);
                      return (
                        <KatanaCard key={bm.slug} padding={12}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                            <button
                              type="button"
                              className="bare-button"
                              onClick={() => openDetail(bm.slug)}
                              style={{ display: 'flex', alignItems: 'center', gap: 12, flex: 1, minWidth: 0, textAlign: 'left' }}
                            >
                              <div style={{ position: 'relative', width: 58, height: 84, borderRadius: 8, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                                <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={20} />
                                <KatanaCoverBadges unreadCount={unread} downloadedCount={dlCount} />
                              </div>
                              <div style={{ flex: 1, minWidth: 0 }}>
                                <div className="clamp-2" style={KatanaType.title}>{bm.title}</div>
                                <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap', marginTop: 4 }}>
                                  <span style={{ ...KatanaType.small, color: KatanaColors.link }}>
                                    {bm.lastReadChapterTitle} · Page {bm.lastReadPage || 1}
                                  </span>
                                  {caughtUp && (
                                    <span style={{ padding: '1px 6px', borderRadius: 4, background: withAlpha(KatanaColors.green, 0.16), color: KatanaColors.green, fontSize: 10.5, fontWeight: 700 }}>
                                      Caught Up
                                    </span>
                                  )}
                                </div>
                              </div>
                            </button>
                            <button
                              type="button"
                              className="bare-button"
                              aria-label={`Resume ${bm.title}`}
                              onClick={() => void resumeBookmark(bm)}
                              style={{
                                width: 38,
                                height: 38,
                                borderRadius: '50%',
                                background: KatanaColors.accent,
                                display: 'grid',
                                placeItems: 'center',
                                flexShrink: 0,
                              }}
                            >
                              <Icon name={resumingSlug === bm.slug ? 'hourglass_top' : 'play_arrow'} size={20} color={KatanaColors.accentInk} />
                            </button>
                            {!showPartnerReading && (
                              <button
                                type="button"
                                className="bare-button"
                                aria-label={`Remove ${bm.title} from reading`}
                                title="Remove from Currently Reading"
                                onClick={() => void removeFromReading(bm.slug, bm.title)}
                                style={{
                                  width: 38,
                                  height: 38,
                                  borderRadius: '50%',
                                  background: KatanaColors.surfaceAlt,
                                  border: `1px solid ${KatanaColors.border}`,
                                  display: 'grid',
                                  placeItems: 'center',
                                  flexShrink: 0,
                                }}
                              >
                                <Icon name="close" size={18} color={KatanaColors.textMuted} />
                              </button>
                            )}
                          </div>
                        </KatanaCard>
                      );
                    })}
                  </div>
                )}
              </div>
            ) : tab === 'downloads' ? (
              <KatanaDownloadsView
                items={offline.mangaItems}
                storage={offline.formattedMangaStorage}
                wifiOnly={downloadWifiOnly}
                onToggleWifiOnly={toggleDownloadWifiOnly}
                autoDownloadNext={autoDownloadNext}
                onChangeAutoDownloadNext={updateAutoDownloadNext}
                autoDownloadCategories={autoDownloadCategories}
                allCategories={customCategories}
                onToggleAutoDownloadCategory={toggleAutoDownloadCategory}
                batchProgress={batchProgress}
                downloadQueue={downloadQueue}
                onMoveQueueItem={moveDownloadQueueItem}
                onRemoveQueueItem={removeDownloadQueueItem}
                onCancelQueue={cancelDownloadQueue}
                onOpen={openOfflineMangaChapter}
                onOpenSeries={openDetail}
                onDelete={(id) => void offlineMedia.deleteDownload(id)}
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
                    badge={catTotalResults != null ? String(catTotalResults) : undefined}
                  />
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                    {(catalogMode === 'directory' || catalogMode === 'search') && (
                      <div
                        role="group"
                        aria-label="Catalog source"
                        style={{
                          display: 'inline-flex',
                          padding: 3,
                          borderRadius: 99,
                          background: KatanaColors.surfaceAlt,
                          border: `1px solid ${KatanaColors.border}`,
                        }}
                      >
                        {(
                          [
                            ['mangakatana', 'MangaKatana'],
                            ['mangadex', 'MangaDex'],
                          ] as const
                        ).map(([src, label]) => {
                          const active = catalogSource === src;
                          return (
                            <button
                              key={src}
                              type="button"
                              className="bare-button"
                              aria-pressed={active}
                              onClick={() => setCatalogSource(src)}
                              style={{
                                padding: '4px 10px',
                                borderRadius: 99,
                                background: active ? KatanaColors.chipSelectedBg : 'transparent',
                                fontFamily: Fonts.body,
                                fontSize: 11.5,
                                fontWeight: active ? 700 : 500,
                                color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                              }}
                            >
                              {label}
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
                          padding: '6px 12px',
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
                    <div style={{ display: 'inline-flex', padding: 3, borderRadius: 8, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}` }}>
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
                              width: 32,
                              height: 28,
                              borderRadius: 6,
                              background: active ? KatanaColors.chipSelectedBg : 'transparent',
                              border: active ? `1px solid ${KatanaColors.chipSelectedBorder}` : '1px solid transparent',
                              display: 'grid',
                              placeItems: 'center',
                            }}
                          >
                            <Icon name={mode === 'grid' ? 'grid_view' : 'view_agenda'} size={16} color={active ? KatanaColors.chipSelectedText : KatanaColors.textMuted} />
                          </button>
                        );
                      })}
                    </div>
                  </div>
                </div>

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
                        <button type="button" className="bare-button" aria-label="Close filters" onClick={() => setFilterOpen(false)} style={{ width: 36, height: 36, display: 'grid', placeItems: 'center' }}>
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

                {/* Active filter chips summary */}
                {activeFilterCount > 0 && !filterOpen && (
                  <div style={{ marginTop: 10, display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center' }}>
                    {statusFilter !== 'all' && (
                      <span style={{ padding: '3px 9px', borderRadius: 99, background: KatanaColors.surfaceAlt, color: KatanaColors.text, fontSize: 12, fontWeight: 600 }}>
                        {statusFilter === 'ongoing' ? 'Ongoing' : 'Completed'}
                      </span>
                    )}
                    {demographicFilter !== 'all' && (
                      <span style={{ padding: '3px 9px', borderRadius: 99, background: KatanaColors.surfaceAlt, color: KatanaColors.text, fontSize: 12, fontWeight: 600 }}>
                        {demographicFilter}
                      </span>
                    )}
                    {authorFilter.trim() && (
                      <span style={{ padding: '3px 9px', borderRadius: 99, background: KatanaColors.surfaceAlt, color: KatanaColors.text, fontSize: 12, fontWeight: 600 }}>
                        Author: {authorFilter.trim()}
                      </span>
                    )}
                    {includeGenres.map((s) => (
                      <span key={`inc-${s}`} style={{ padding: '3px 9px', borderRadius: 99, background: withAlpha(KatanaColors.green, 0.15), color: KatanaColors.green, fontSize: 12, fontWeight: 600 }}>
                        + {s}
                      </span>
                    ))}
                    {excludeGenres.map((s) => (
                      <span key={`exc-${s}`} style={{ padding: '3px 9px', borderRadius: 99, background: withAlpha(KatanaColors.crimson, 0.15), color: KatanaColors.crimson, fontSize: 12, fontWeight: 600 }}>
                        − {s}
                      </span>
                    ))}
                    {minChapters !== '1' && (
                      <span style={{ padding: '3px 9px', borderRadius: 99, background: KatanaColors.surfaceAlt, color: KatanaColors.textMuted, fontSize: 12, fontWeight: 600 }}>
                        {minChapters}+ ch
                      </span>
                    )}
                    <button type="button" className="bare-button" onClick={clearCatalogFilters} style={{ ...KatanaType.link, fontSize: 12 }}>
                      Clear all
                    </button>
                  </div>
                )}

                <div style={{ height: 14 }} />
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
                            onOpenChapter={openChapter}
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

function KatanaDownloadsView({
  items,
  storage,
  wifiOnly,
  onToggleWifiOnly,
  autoDownloadNext,
  onChangeAutoDownloadNext,
  autoDownloadCategories,
  allCategories,
  onToggleAutoDownloadCategory,
  batchProgress,
  downloadQueue,
  onMoveQueueItem,
  onRemoveQueueItem,
  onCancelQueue,
  onOpen,
  onOpenSeries,
  onDelete,
  onDeleteMany,
  onClearAll,
  onBrowse,
}: {
  items: OfflineMediaItem[];
  storage: string;
  wifiOnly: boolean;
  onToggleWifiOnly: () => void;
  autoDownloadNext: number;
  onChangeAutoDownloadNext: (count: number) => void;
  autoDownloadCategories: string[];
  allCategories: string[];
  onToggleAutoDownloadCategory: (category: string) => void;
  batchProgress: { done: number; total: number; currentTitle?: string } | null;
  downloadQueue: Array<{ manga: KatanaManga; chapter: KatanaChapter }>;
  onMoveQueueItem: (index: number, delta: -1 | 1) => void;
  onRemoveQueueItem: (index: number) => void;
  onCancelQueue: () => void;
  onOpen: (item: OfflineMediaItem) => void;
  onOpenSeries: (slug: string) => void;
  onDelete: (id: string) => void;
  onDeleteMany: (ids: string[]) => void;
  onClearAll: () => void;
  onBrowse: () => void;
}) {
  const [sortBy, setSortBy] = useState<'recent' | 'title' | 'chapters'>('recent');
  const [dlSelectMode, setDlSelectMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(() => new Set());
  const [quotaInfo, setQuotaInfo] = useState<{ usage: number; quota: number } | null>(null);

  useEffect(() => {
    let active = true;
    if (typeof navigator !== 'undefined' && navigator.storage?.estimate) {
      navigator.storage
        .estimate()
        .then((est) => {
          if (active && typeof est.usage === 'number' && typeof est.quota === 'number' && est.quota > 0) {
            setQuotaInfo({ usage: est.usage, quota: est.quota });
          }
        })
        .catch(() => {});
    }
    return () => {
      active = false;
    };
  }, [items.length]);

  const grouped = useMemo(() => {
    const groups = new Map<string, OfflineMediaItem[]>();
    for (const it of items) {
      const list = groups.get(it.mediaId) ?? [];
      list.push(it);
      groups.set(it.mediaId, list);
    }
    const entries = [...groups.values()];
    if (sortBy === 'title') {
      entries.sort((a, b) => a[0].title.localeCompare(b[0].title));
    } else if (sortBy === 'chapters') {
      entries.sort((a, b) => b.length - a.length || a[0].title.localeCompare(b[0].title));
    }
    return entries;
  }, [items, sortBy]);

  const toggleSelect = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10 }}>
        <KatanaSectionHeader title="Downloads" badge={items.length > 0 ? String(items.length) : undefined} />
        {items.length > 0 && (
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
            <button
              type="button"
              className="bare-button"
              onClick={() => {
                setDlSelectMode((v) => !v);
                setSelectedIds(new Set());
              }}
              style={{
                padding: '6px 11px',
                borderRadius: 8,
                background: dlSelectMode ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                border: `1px solid ${dlSelectMode ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 5,
                fontFamily: Fonts.body,
                fontSize: 12,
                fontWeight: 700,
                color: dlSelectMode ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
              }}
            >
              <Icon name="checklist" size={16} color={dlSelectMode ? KatanaColors.accentSoft : KatanaColors.textMuted} />
              <span>{dlSelectMode ? 'Done' : 'Select'}</span>
            </button>
            <button
              type="button"
              className="bare-button"
              onClick={onClearAll}
              style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '6px 10px' }}
            >
              <Icon name="delete_sweep" variant="outlined" size={18} color={KatanaColors.textLight} />
              <span style={KatanaType.small}>Clear All</span>
            </button>
          </div>
        )}
      </div>
      <div style={{ height: 14 }} />
      <KatanaCard padding={12} radius={10} style={{ marginBottom: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10 }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <Icon name="wifi" size={18} color={wifiOnly ? KatanaColors.green : KatanaColors.textMuted} />
              <span style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 600 }}>
                Wi-Fi only — {wifiOnly ? 'On' : 'Off'}
              </span>
            </div>
            {!supportsNetworkConnectionApi() && (
              <span style={{ ...KatanaType.small, fontSize: 11, color: KatanaColors.textLight }}>
                Your browser (e.g. iOS Safari) does not expose Wi-Fi vs. cellular status to web apps; this setting applies automatically on supported browsers.
              </span>
            )}
          </div>
          <button
            type="button"
            role="switch"
            aria-checked={wifiOnly}
            aria-label={`Download over Wi-Fi only: ${wifiOnly ? 'On' : 'Off'}`}
            className="bare-button"
            onClick={onToggleWifiOnly}
            style={{
              width: 48,
              height: 28,
              borderRadius: 99,
              padding: 3,
              background: wifiOnly ? KatanaColors.green : KatanaColors.switchOff,
              border: `1px solid ${wifiOnly ? KatanaColors.green : KatanaColors.borderStrong}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: wifiOnly ? 'flex-end' : 'flex-start',
              transition: 'background 160ms ease',
            }}
          >
            <span
              style={{
                width: 20,
                height: 20,
                borderRadius: 99,
                background: '#FFFFFF',
                boxShadow: '0 1px 3px rgba(0,0,0,0.35)',
              }}
            />
          </button>
        </div>
        <div
          style={{
            marginTop: 10,
            paddingTop: 10,
            borderTop: `1px solid ${KatanaColors.border}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            flexWrap: 'wrap',
            gap: 8,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Icon name="downloading" size={18} color={autoDownloadNext > 0 ? KatanaColors.link : KatanaColors.textMuted} />
            <span style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 600 }}>
              Auto-download next unread
            </span>
          </div>
          <div style={{ display: 'inline-flex', gap: 5 }}>
            {[0, 1, 3, 5].map((n) => {
              const active = autoDownloadNext === n;
              return (
                <button
                  key={n}
                  type="button"
                  className="bare-button"
                  aria-pressed={active}
                  onClick={() => onChangeAutoDownloadNext(n)}
                  style={{
                    minHeight: 34,
                    padding: '4px 10px',
                    borderRadius: 8,
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: active ? 700 : 500,
                    color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                  }}
                >
                  {n === 0 ? 'Off' : `${n} ch`}
                </button>
              );
            })}
          </div>
        </div>
        {autoDownloadNext > 0 && allCategories.length > 0 && (
          <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 6 }}>
            <span style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.textMuted }}>
              Categories ({autoDownloadCategories.length === 0 ? 'All followed' : `${autoDownloadCategories.length} selected`}):
            </span>
            {allCategories.map((cat) => {
              const active = autoDownloadCategories.includes(cat);
              return (
                <button
                  key={cat}
                  type="button"
                  className="bare-button"
                  aria-pressed={active}
                  onClick={() => onToggleAutoDownloadCategory(cat)}
                  style={{
                    minHeight: 30,
                    padding: '3px 9px',
                    borderRadius: 99,
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 11.5,
                    fontWeight: active ? 700 : 500,
                    color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                  }}
                >
                  {cat}
                </button>
              );
            })}
          </div>
        )}
        {batchProgress && (
          <div style={{ marginTop: 10, paddingTop: 10, borderTop: `1px solid ${KatanaColors.border}` }}>
            {downloadQueue.length > 0 && (
              <div style={{ marginBottom: 10, display: 'flex', flexDirection: 'column', gap: 4 }}>
                <div style={{ ...KatanaType.small, fontSize: 11.5, fontWeight: 700, color: KatanaColors.textMuted }}>
                  Up Next ({downloadQueue.length}) — reorder or remove
                </div>
                {downloadQueue.slice(0, 6).map((q, idx) => (
                  <div
                    key={`${q.manga.slug}-${q.chapter.id}`}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 6,
                      padding: '4px 8px',
                      borderRadius: 7,
                      background: KatanaColors.surfaceAlt,
                      border: `1px solid ${KatanaColors.border}`,
                    }}
                  >
                    <span className="ellipsis" style={{ flex: 1, minWidth: 0, ...KatanaType.small, color: KatanaColors.text }}>
                      {q.manga.title} · {chapterDisplayTitle(q.chapter)}
                    </span>
                    <button
                      type="button"
                      className="bare-button"
                      aria-label={`Move ${chapterDisplayTitle(q.chapter)} up`}
                      disabled={idx === 0}
                      onClick={() => onMoveQueueItem(idx, -1)}
                      style={{ width: 40, height: 40, display: 'grid', placeItems: 'center', opacity: idx === 0 ? 0.35 : 1 }}
                    >
                      <Icon name="arrow_upward" size={16} color={KatanaColors.textMuted} />
                    </button>
                    <button
                      type="button"
                      className="bare-button"
                      aria-label={`Move ${chapterDisplayTitle(q.chapter)} down`}
                      disabled={idx === downloadQueue.length - 1}
                      onClick={() => onMoveQueueItem(idx, 1)}
                      style={{ width: 40, height: 40, display: 'grid', placeItems: 'center', opacity: idx === downloadQueue.length - 1 ? 0.35 : 1 }}
                    >
                      <Icon name="arrow_downward" size={16} color={KatanaColors.textMuted} />
                    </button>
                    <button
                      type="button"
                      className="bare-button"
                      aria-label={`Remove ${chapterDisplayTitle(q.chapter)} from queue`}
                      onClick={() => onRemoveQueueItem(idx)}
                      style={{ width: 40, height: 40, display: 'grid', placeItems: 'center' }}
                    >
                      <Icon name="close" size={16} color={KatanaColors.crimson} />
                    </button>
                  </div>
                ))}
              </div>
            )}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginBottom: 6 }}>
              <span className="ellipsis" style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 700 }}>
                Queue: {batchProgress.currentTitle || 'Downloading…'} ({batchProgress.done}/{batchProgress.total})
              </span>
              <button
                type="button"
                className="bare-button"
                onClick={onCancelQueue}
                style={{
                  padding: '4px 10px',
                  borderRadius: 6,
                  background: withAlpha(KatanaColors.crimson, 0.14),
                  border: `1px solid ${withAlpha(KatanaColors.crimson, 0.4)}`,
                  fontFamily: Fonts.body,
                  fontSize: 11.5,
                  fontWeight: 700,
                  color: KatanaColors.crimson,
                }}
              >
                Cancel Queue
              </button>
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
      </KatanaCard>
      {items.length === 0 ? (
        <KatanaEmptyState
          icon="download_done"
          title="No offline chapters yet"
          subtitle="Download chapters from any manga detail page or reader to read without a connection."
          actionLabel="Browse Manga"
          actionIcon="home"
          onAction={onBrowse}
        />
      ) : (
        <>
          <KatanaCard padding={12} style={{ marginBottom: 12 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <Icon name="storage" size={18} color={KatanaColors.accent} />
                <span style={KatanaType.small}>
                  Offline storage used: <strong style={{ color: KatanaColors.text }}>{storage}</strong>
                  {quotaInfo
                    ? ` of ${quotaInfo.quota >= 1e9 ? `${(quotaInfo.quota / 1e9).toFixed(1)} GB` : `${Math.max(1, Math.round(quotaInfo.quota / 1e6))} MB`} device budget`
                    : ''}
                </span>
              </div>
              <div style={{ display: 'inline-flex', gap: 6 }}>
                {(
                  [
                    ['recent', 'Recent'],
                    ['title', 'A–Z'],
                    ['chapters', 'Most ch'],
                  ] as const
                ).map(([id, label]) => (
                  <button
                    key={id}
                    type="button"
                    className="bare-button"
                    onClick={() => setSortBy(id)}
                    style={{
                      padding: '5px 10px',
                      borderRadius: 7,
                      background: sortBy === id ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                      border: `1px solid ${sortBy === id ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                      fontFamily: Fonts.body,
                      fontSize: 12,
                      fontWeight: sortBy === id ? 700 : 500,
                      color: sortBy === id ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                    }}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </div>
            {quotaInfo && (
              <div style={{ marginTop: 8 }}>
                <div style={{ height: 5, borderRadius: 99, background: KatanaColors.surfaceAlt, overflow: 'hidden' }}>
                  <div
                    style={{
                      width: `${Math.min(100, Math.max(2, Math.round((quotaInfo.usage / Math.max(1, quotaInfo.quota)) * 100)))}%`,
                      height: '100%',
                      background: KatanaColors.accent,
                      borderRadius: 99,
                    }}
                  />
                </div>
              </div>
            )}
            <div style={{ ...KatanaType.small, fontSize: 11, marginTop: 6 }}>
              Pending downloads save automatically and resume next time you open Manga Celestia.
            </div>
          </KatanaCard>

          {dlSelectMode && (
            <KatanaCard padding={10} radius={10} style={{ marginBottom: 12 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
                <span style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 700 }}>
                  {selectedIds.size} selected
                </span>
                <div style={{ display: 'inline-flex', gap: 8 }}>
                  <KatanaButton
                    label="Select all"
                    size="sm"
                    filled={false}
                    color={KatanaColors.textMuted}
                    onClick={() => setSelectedIds(new Set(items.map((i) => i.id)))}
                  />
                  <KatanaButton
                    label={`Delete (${selectedIds.size})`}
                    icon="delete_outline"
                    size="sm"
                    filled={false}
                    color={KatanaColors.crimson}
                    onClick={() => {
                      if (selectedIds.size === 0) return;
                      onDeleteMany([...selectedIds]);
                      setSelectedIds(new Set());
                      setDlSelectMode(false);
                    }}
                  />
                </div>
              </div>
            </KatanaCard>
          )}

          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {grouped.map((chapters) => {
              const head = chapters[0];
              return (
                <KatanaCard key={head.mediaId} padding={0} style={{ overflow: 'hidden' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 12, borderBottom: `1px solid ${KatanaColors.border}` }}>
                    <div
                      onClick={() => onOpenSeries(head.mediaId)}
                      role="link"
                      tabIndex={0}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault();
                          onOpenSeries(head.mediaId);
                        }
                      }}
                      style={{ display: 'flex', alignItems: 'center', gap: 12, flex: 1, minWidth: 0, textAlign: 'left', cursor: 'pointer' }}
                    >
                      <div style={{ position: 'relative', width: 46, height: 66, borderRadius: 6, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                        <KatanaCoverImage url={head.coverUrl} title={head.title} iconSize={18} />
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div className="ellipsis" style={KatanaType.title}>{head.title}</div>
                        <div style={KatanaType.small}>
                          {chapters.length} {chapters.length === 1 ? 'chapter' : 'chapters'} offline
                        </div>
                      </div>
                    </div>
                    <KatanaButton label="Resume" icon="play_arrow" size="sm" onClick={() => onOpen(head)} />
                  </div>
                  {chapters.map((ch, idx) => {
                    const checked = selectedIds.has(ch.id);
                    return (
                      <div
                        key={ch.id}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: 10,
                          padding: '10px 12px',
                          borderTop: idx > 0 ? `1px solid ${KatanaColors.border}` : undefined,
                          background: checked ? withAlpha(KatanaColors.accent, 0.08) : 'transparent',
                        }}
                      >
                        {dlSelectMode && (
                          <button
                            type="button"
                            className="bare-button"
                            aria-label={`Select ${ch.subtitle || ch.title}`}
                            onClick={() => toggleSelect(ch.id)}
                            style={{ width: 34, height: 34, display: 'grid', placeItems: 'center', flexShrink: 0 }}
                          >
                            <Icon name={checked ? 'check_box' : 'check_box_outline_blank'} size={20} color={checked ? KatanaColors.accent : KatanaColors.textLight} />
                          </button>
                        )}
                        <button
                          type="button"
                          className="bare-button"
                          onClick={() => (dlSelectMode ? toggleSelect(ch.id) : onOpen(ch))}
                          style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 10, textAlign: 'left' }}
                        >
                          <Icon name="menu_book" size={18} color={KatanaColors.accentSoft} />
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div style={{ ...KatanaType.title, fontSize: 13.5 }}>{ch.subtitle || `Chapter ${ch.chapterId ?? ''}`}</div>
                            <div style={KatanaType.small}>{formattedSize(ch)}</div>
                          </div>
                        </button>
                        {!dlSelectMode && (
                          <button
                            type="button"
                            className="bare-button"
                            aria-label={`Delete ${ch.subtitle || ch.title}`}
                            onClick={() => onDelete(ch.id)}
                            style={{ width: 36, height: 36, display: 'grid', placeItems: 'center' }}
                          >
                            <Icon name="delete_outline" size={18} color={KatanaColors.textLight} />
                          </button>
                        )}
                      </div>
                    );
                  })}
                </KatanaCard>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}
