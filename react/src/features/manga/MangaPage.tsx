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
  KatanaCompactCard,
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
  clearKatanaReadingProgress,
  estimateUnreadCount,
  fetchKatanaByType,
  fetchKatanaCatalog,
  fetchKatanaChapterPages,
  fetchKatanaDetail,
  fetchKatanaHome,
  formatCompactNumber,
  formatKatanaTime,
  isBookmarkCaughtUp,
  markKatanaChaptersRead,
  proxyKatanaImageUrl,
  resolveLibraryStatus,
  setKatanaBookmark,
  setKatanaLibraryStatus,
  watchKatanaBookmarks,
  type KatanaBookmark,
  type KatanaChapter,
  type KatanaGenre,
  type KatanaHomeData,
  type KatanaLibraryStatus,
  type KatanaManga,
} from './katanaService';
import { KATANA_BREAKPOINTS, KatanaColors, KatanaType } from './katanaTokens';
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
  { id: 'numc', label: 'Most Chapters' },
  { id: 'new', label: 'Newest Added' },
  { id: 'az', label: 'Title A–Z' },
] as const;

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

const VALID_TABS = new Set<KatanaNavKey>(['home', 'latest', 'directory', 'newManga', 'genres', 'reading', 'downloads', 'bookmarks']);
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
  const { slug: routeSlug } = useParams<{ slug?: string }>();
  const [searchParams] = useSearchParams();
  const offline = useOfflineMedia();

  // URL-driven navigation state so Back/Forward, refresh, and deep links work.
  const detailSlug = routeSlug ? decodeURIComponent(routeSlug) : null;
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
  const searchBy: 'm_name' | 'author' = searchParams.get('by') === 'author' ? 'author' : 'm_name';
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
      navigate(`/manga/series/${encodeURIComponent(slug)}`);
    },
    [navigate],
  );

  const closeDetail = useCallback(() => {
    if (location.key !== 'default') navigate(-1);
    else navigate('/manga');
  }, [location.key, navigate]);

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
  const [catViewMode, setCatViewMode] = useState<'grid' | 'list'>(() => (width >= KATANA_BREAKPOINTS.tablet ? 'grid' : 'list'));
  const [filterOpen, setFilterOpen] = useState(false);
  const [authorDraft, setAuthorDraft] = useState(authorFilter);

  useEffect(() => {
    setAuthorDraft(authorFilter);
  }, [authorFilter]);

  // Genres directory search
  const [genreFilterText, setGenreFilterText] = useState('');

  // Library filter/sort/display/bulk-select state
  const [libraryBucket, setLibraryBucket] = useState<'all' | 'caught_up' | KatanaLibraryStatus>('all');
  const [libraryQuery, setLibraryQuery] = useState('');
  const [librarySort, setLibrarySort] = useState<'last_read' | 'unread' | 'title' | 'added'>('last_read');
  const [libraryViewMode, setLibraryViewMode] = useState<'list' | 'grid' | 'compact'>('list');
  const [librarySelectMode, setLibrarySelectMode] = useState(false);
  const [selectedLibrarySlugs, setSelectedLibrarySlugs] = useState<Set<string>>(() => new Set());

  // Detail data & chapter controls
  const [detail, setDetail] = useState<KatanaManga | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [chapterSortAsc, setChapterSortAsc] = useState(false);
  const [chapterSearch, setChapterSearch] = useState('');
  const [chapterWindow, setChapterWindow] = useState(40);
  const [downloadingChapterIds, setDownloadingChapterIds] = useState<Set<string>>(() => new Set());
  const [batchProgress, setBatchProgress] = useState<{ done: number; total: number } | null>(null);
  const [selectMode, setSelectMode] = useState(false);
  const [selectedChapterIds, setSelectedChapterIds] = useState<Set<string>>(() => new Set());
  const [detailOverflowOpen, setDetailOverflowOpen] = useState(false);
  const [statusMenuOpen, setStatusMenuOpen] = useState(false);

  const userName = currentUser ?? '';
  const bookmarks = useSource(() => watchKatanaBookmarks(userName), [userName], []);
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
          { slug: bm.slug, title: bm.title, coverUrl: bm.coverUrl, status: 'ongoing' },
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

  const unreadBySlug = useMemo(() => {
    const map: Record<string, number> = {};
    for (const bm of bookmarks) {
      map[bm.slug] = estimateUnreadCount(bm);
    }
    return map;
  }, [bookmarks]);

  const libraryCounts = useMemo(() => {
    const counts: Record<'all' | 'caught_up' | KatanaLibraryStatus, number> = {
      all: savedBookmarks.length,
      reading: 0,
      caught_up: 0,
      on_hold: 0,
      completed: 0,
      planned: 0,
      dropped: 0,
    };
    for (const bm of savedBookmarks) {
      counts[resolveLibraryStatus(bm)] += 1;
      if (isBookmarkCaughtUp(bm)) counts.caught_up += 1;
    }
    return counts;
  }, [savedBookmarks]);

  const totalChaptersRead = useMemo(
    () => bookmarks.reduce((acc, b) => acc + (b.readChapterIds?.length ?? 0), 0),
    [bookmarks],
  );

  const filteredLibrary = useMemo(() => {
    const q = libraryQuery.trim().toLowerCase();
    const list = savedBookmarks.filter((bm) => {
      if (libraryBucket === 'caught_up') {
        if (!isBookmarkCaughtUp(bm)) return false;
      } else if (libraryBucket !== 'all' && resolveLibraryStatus(bm) !== libraryBucket) {
        return false;
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
  }, [savedBookmarks, libraryBucket, libraryQuery, librarySort]);

  const openChapter = (manga: KatanaManga, chapterId: string, initialPage = 1) => {
    const bm = bookmarks.find((b) => b.slug === manga.slug);
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
  };

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

  const downloadChapter = useCallback(async (manga: KatanaManga, chapter: KatanaChapter, silent = false) => {
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
  }, []);

  const downloadBatchChapters = useCallback(
    async (manga: KatanaManga, chapters: KatanaChapter[]) => {
      const targets = chapters.filter((c) => !offlineMedia.isDownloaded(OfflineIds.mangaChapterId(manga.slug, c.id)));
      if (targets.length === 0) {
        showSnackBar('Selected chapters are already saved offline');
        return;
      }
      setBatchProgress({ done: 0, total: targets.length });
      for (let i = 0; i < targets.length; i++) {
        await downloadChapter(manga, targets[i], true);
        setBatchProgress({ done: i + 1, total: targets.length });
      }
      setBatchProgress(null);
      showSnackBar(`Saved ${targets.length} ${targets.length === 1 ? 'chapter' : 'chapters'} offline`);
    },
    [downloadChapter],
  );

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

  const similarToDetail = useMemo(() => {
    if (!detail || !homeData) return [];
    const genreSet = new Set(detail.genres.map((g) => g.slug));
    const pool = new Map<string, KatanaManga>();
    for (const m of [...homeData.hot, ...homeData.latest]) {
      if (m.slug !== detail.slug && !pool.has(m.slug)) pool.set(m.slug, m);
    }
    return [...pool.values()]
      .sort((a, b) => {
        const as = a.genres.filter((g) => genreSet.has(g.slug)).length;
        const bs = b.genres.filter((g) => genreSet.has(g.slug)).length;
        return bs - as;
      })
      .slice(0, 6);
  }, [detail, homeData]);

  const effectiveCatView = compactCard ? 'list' : catViewMode;
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
                    borderRadius: 7,
                    overflow: 'hidden',
                    background: inc
                      ? withAlpha(KatanaColors.green, 0.16)
                      : exc
                        ? withAlpha(KatanaColors.crimson, 0.16)
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
                      padding: '5px 8px',
                      fontFamily: Fonts.body,
                      fontSize: 12,
                      fontWeight: 600,
                      color: inc ? KatanaColors.green : exc ? KatanaColors.crimson : KatanaColors.textMuted,
                    }}
                  >
                    {inc ? '+ ' : ''}
                    {g.name}
                  </button>
                  <button
                    type="button"
                    className="bare-button"
                    aria-pressed={exc}
                    aria-label={`${exc ? 'Remove exclude' : 'Exclude'} ${g.name}`}
                    title={exc ? `Remove ${g.name} exclusion` : `Exclude ${g.name}`}
                    onClick={() => toggleExcludeGenre(g.slug)}
                    style={{
                      width: 24,
                      height: 26,
                      display: 'grid',
                      placeItems: 'center',
                      borderLeft: `1px solid ${inc ? withAlpha(KatanaColors.green, 0.35) : exc ? withAlpha(KatanaColors.crimson, 0.35) : KatanaColors.border}`,
                      color: exc ? KatanaColors.crimson : KatanaColors.textLight,
                      fontFamily: Fonts.body,
                      fontSize: 13,
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
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: KatanaColors.background, color: KatanaColors.text }}>
      <TvMediaNavHeader currentRoute="/manga" />
      <KatanaHeader
        active={tab}
        width={width}
        userName={userName}
        showBack={isCoupleUser}
        genres={homeData?.genres ?? []}
        onBack={() => navigate('/dashboard')}
        onSelectNav={handleNav}
        onSubmitSearch={(q, by) => {
          setFilterOpen(false);
          updateMangaUrl({ tab: 'directory', mode: 'search', q, by: by === 'author' ? 'author' : null }, { clearAll: true });
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
            onViewAllReading={() => handleNav('reading')}
            onRetryHome={() => setHomeRefreshTick((n) => n + 1)}
          />
        </div>
      ) : (
        <div style={{ flex: 1, overflowY: 'auto', padding: '16px 16px 40px' }}>
          <div style={{ maxWidth: 1240, margin: '0 auto' }}>
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

                  return (
                    <div>
                      <KatanaBreadcrumb items={['Manga', detail.title]} onHome={() => handleNav('home')} />

                      <KatanaCard padding={tablet ? 20 : 14}>
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
                                {detail.status === 'completed' ? 'Completed' : 'Ongoing'}
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
                                <span style={KatanaType.small}>{formatCompactNumber(detail.follows)} readers</span>
                              )}
                              {detail.demographic && (
                                <span style={{ ...KatanaType.small, color: KatanaColors.textMuted }}>· {detail.demographic}</span>
                              )}
                              <span style={KatanaType.small}>· {detail.chapters.length} ch</span>
                              {detail.updateText && <span style={KatanaType.small}>· {detail.updateText}</span>}
                            </div>

                            <h1 style={{ ...KatanaType.display, fontSize: tablet ? 28 : 21, margin: 0 }}>{detail.title}</h1>

                            {(detail.authors.length > 0 || detail.artists.length > 0) && (
                              <div style={{ ...KatanaType.body, fontSize: 13.5, marginTop: 6, color: KatanaColors.link, fontWeight: 600 }}>
                                {[...detail.authors, ...detail.artists].join(', ')}
                              </div>
                            )}

                            {detail.altNames.length > 0 && (
                              <div style={{ ...KatanaType.small, marginTop: 4 }}>
                                Also known as: {detail.altNames.join(' · ')}
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

                            {/* Action bar: compact single-CTA + icon row on phone; clean row on tablet/desktop */}
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
                              <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap', position: 'relative' }}>
                                <KatanaButton
                                  label={isBookmarked ? 'In Library' : 'Library'}
                                  icon={isBookmarked ? 'bookmark' : 'bookmark_border'}
                                  size="sm"
                                  filled={false}
                                  color={isBookmarked ? KatanaColors.green : KatanaColors.text}
                                  onClick={() => void setKatanaBookmark(detail, userName, !isBookmarked)}
                                />
                                {userName && (
                                  <div style={{ position: 'relative' }}>
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
                                        height: 34,
                                        padding: '0 10px',
                                        borderRadius: 8,
                                        background: statusMenuOpen || isBookmarked ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                        border: `1px solid ${statusMenuOpen || isBookmarked ? KatanaColors.chipSelectedBorder : KatanaColors.borderStrong}`,
                                        display: 'inline-flex',
                                        alignItems: 'center',
                                        gap: 5,
                                        fontFamily: Fonts.body,
                                        fontSize: 12,
                                        fontWeight: 600,
                                        color: KatanaColors.text,
                                      }}
                                    >
                                      <Icon
                                        name={currentStatus ? STATUS_LABELS[currentStatus].icon : 'shelves'}
                                        size={15}
                                        color={currentStatus ? STATUS_LABELS[currentStatus].color : KatanaColors.textMuted}
                                      />
                                      <span>{isBookmarked && currentStatus ? STATUS_LABELS[currentStatus].label : 'Status'}</span>
                                      <Icon name="expand_more" size={15} color={KatanaColors.textMuted} />
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
                                      </div>
                                    )}
                                  </div>
                                )}
                                {detail.chapters.length > 0 && (
                                  <button
                                    type="button"
                                    className="bare-button"
                                    aria-label="Download next 3 unread chapters"
                                    title="Download next 3 unread chapters"
                                    disabled={batchProgress != null}
                                    onClick={() => void downloadNextUnread(detail, readSet, 3)}
                                    style={{
                                      height: 34,
                                      padding: compactCard ? '0 10px' : '0 12px',
                                      borderRadius: 8,
                                      background: KatanaColors.surfaceAlt,
                                      border: `1px solid ${KatanaColors.borderStrong}`,
                                      display: 'inline-flex',
                                      alignItems: 'center',
                                      gap: 5,
                                      fontFamily: Fonts.body,
                                      fontSize: 12,
                                      fontWeight: 600,
                                      color: KatanaColors.link,
                                      opacity: batchProgress != null ? 0.6 : 1,
                                    }}
                                  >
                                    <Icon name="download" size={16} color={KatanaColors.link} />
                                    {!compactCard && <span>{batchProgress ? `Saving ${batchProgress.done}/${batchProgress.total}` : 'Download 3'}</span>}
                                  </button>
                                )}
                                <button
                                  type="button"
                                  className="bare-button"
                                  aria-label="Share series link"
                                  title="Copy series link"
                                  onClick={() => void shareSeriesLink(detail)}
                                  style={{
                                    width: 34,
                                    height: 34,
                                    borderRadius: 8,
                                    background: KatanaColors.surfaceAlt,
                                    border: `1px solid ${KatanaColors.borderStrong}`,
                                    display: 'grid',
                                    placeItems: 'center',
                                  }}
                                >
                                  <Icon name="share" size={16} color={KatanaColors.textMuted} />
                                </button>
                                {(hasReadingProgress || unreadCount > 0) && (
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
                                        width: 34,
                                        height: 34,
                                        borderRadius: 8,
                                        background: detailOverflowOpen ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                                        border: `1px solid ${KatanaColors.borderStrong}`,
                                        display: 'grid',
                                        placeItems: 'center',
                                      }}
                                    >
                                      <Icon name="more_horiz" size={18} color={KatanaColors.textMuted} />
                                    </button>
                                    {detailOverflowOpen && (
                                      <div
                                        style={{
                                          position: 'absolute',
                                          right: 0,
                                          top: 40,
                                          minWidth: 210,
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
                                )}
                              </div>
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
                      </KatanaCard>

                      <div style={{ height: 16 }} />

                      <div
                        style={{
                          display: desktop ? 'flex' : 'block',
                          alignItems: 'flex-start',
                          gap: 18,
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
                                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
                                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontFamily: Fonts.body, fontSize: 12.5, fontWeight: 700, color: KatanaColors.text }}>
                                    <Icon name="downloading" size={16} color={KatanaColors.link} />
                                    Downloading chapters for offline reading…
                                  </span>
                                  <span style={{ ...KatanaType.small, color: KatanaColors.link, fontWeight: 700 }}>
                                    {batchProgress.done} / {batchProgress.total}
                                  </span>
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
                          {visibleChapters.map((c) => {
                            const isRead = readSet.has(c.id);
                            const isLastRead = detailBm?.lastReadChapterId === c.id;
                            const isChecked = selectedChapterIds.has(c.id);
                            const offlineId = OfflineIds.mangaChapterId(detail.slug, c.id);
                            const isOffline = offlineMedia.isDownloaded(offlineId);
                            const isDownloading = downloadingChapterIds.has(c.id);

                            return (
                              <div
                                key={c.id}
                                style={{
                                  display: 'flex',
                                  alignItems: 'center',
                                  gap: 8,
                                  padding: '8px 10px',
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
                                  {c.updateAt && (
                                    <span style={{ ...KatanaType.small, fontSize: 11.5, whiteSpace: 'nowrap', flexShrink: 0 }}>
                                      {formatKatanaTime(c.updateAt)}
                                    </span>
                                  )}
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
                                </button>

                                {!selectMode && userName && (
                                  <>
                                    <button
                                      type="button"
                                      className="bare-button"
                                      title="Mark this and all previous chapters read"
                                      aria-label={`Mark ${chapterDisplayTitle(c)} and previous chapters read`}
                                      onClick={() => {
                                        const idxInNewest = detail.chapters.findIndex((ch) => ch.id === c.id);
                                        if (idxInNewest < 0) return;
                                        const prevIds = detail.chapters.slice(idxInNewest).map((ch) => ch.id);
                                        void markKatanaChaptersRead(detail, userName, prevIds, true);
                                        showSnackBar(`Marked ${prevIds.length} chapters read up to ${chapterDisplayTitle(c)}`);
                                      }}
                                      style={{ width: 40, height: 40, borderRadius: 8, display: 'grid', placeItems: 'center', flexShrink: 0 }}
                                    >
                                      <Icon name="done_all" size={18} color={KatanaColors.textLight} />
                                    </button>
                                    <button
                                      type="button"
                                      className="bare-button"
                                      title={isRead ? 'Mark unread' : 'Mark read'}
                                      aria-label={isRead ? `Mark ${chapterDisplayTitle(c)} unread` : `Mark ${chapterDisplayTitle(c)} read`}
                                      onClick={() => void markKatanaChaptersRead(detail, userName, [c.id], !isRead)}
                                      style={{ width: 40, height: 40, borderRadius: 8, display: 'grid', placeItems: 'center', flexShrink: 0 }}
                                    >
                                      <Icon name={isRead ? 'visibility_off' : 'done'} size={18} color={KatanaColors.textLight} />
                                    </button>
                                  </>
                                )}

                                {!selectMode && (
                                  <button
                                    type="button"
                                    className="bare-button"
                                    title={isOffline ? 'Saved offline' : 'Download chapter'}
                                    aria-label={isOffline ? `${chapterDisplayTitle(c)} saved offline` : `Download ${chapterDisplayTitle(c)}`}
                                    onClick={() => void downloadChapter(detail, c)}
                                    style={{ width: 40, height: 40, borderRadius: 8, display: 'grid', placeItems: 'center', flexShrink: 0 }}
                                  >
                                    <Icon
                                      name={isOffline ? 'download_done' : isDownloading ? 'hourglass_top' : 'download'}
                                      size={19}
                                      color={isOffline ? KatanaColors.green : isDownloading ? KatanaColors.accent : KatanaColors.textMuted}
                                    />
                                  </button>
                                )}
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

                        {similarToDetail.length > 0 && (
                          <aside style={{ width: desktop ? 340 : '100%', flexShrink: 0, marginTop: desktop ? 0 : 18 }}>
                            {desktop ? (
                              <KatanaCard padding={14}>
                                <KatanaSectionHeader title="More Like This" />
                                <div style={{ height: 10 }} />
                                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                                  {similarToDetail.map((m) => (
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
                                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 3 }}>
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
                            ) : (
                              <div>
                                <KatanaSectionHeader title="More Like This" />
                                <div style={{ height: 10 }} />
                                <div className="no-scrollbar" style={{ overflowX: 'auto', display: 'flex', gap: 14, paddingBottom: 4 }}>
                                  {similarToDetail.map((m) => (
                                    <KatanaCompactCard
                                      key={m.slug}
                                      manga={m}
                                      width={tablet ? 150 : 120}
                                      onSelect={() => openDetail(m.slug)}
                                      onOpenChapter={openChapter}
                                    />
                                  ))}
                                </div>
                              </div>
                            )}
                          </aside>
                        )}
                      </div>
                    </div>
                  );
                })()
              )
            ) : tab === 'bookmarks' ? (
              <div>
                <KatanaBreadcrumb items={['Library']} onHome={() => handleNav('home')} />
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10 }}>
                  <KatanaSectionHeader title="My Library" badge={String(savedBookmarks.length)} />
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

                {/* Reading Stats Summary */}
                <div
                  style={{
                    marginTop: 12,
                    display: 'grid',
                    gridTemplateColumns: tablet ? 'repeat(4, minmax(0, 1fr))' : 'repeat(2, minmax(0, 1fr))',
                    gap: 10,
                  }}
                >
                  {[
                    { label: 'Saved Series', value: String(savedBookmarks.length), icon: 'bookmarks', color: KatanaColors.text },
                    { label: 'Reading', value: String(libraryCounts.reading), icon: 'auto_stories', color: KatanaColors.accent },
                    { label: 'Completed', value: String(libraryCounts.completed), icon: 'check_circle', color: KatanaColors.green },
                    { label: 'Chapters Read', value: String(totalChaptersRead), icon: 'menu_book', color: KatanaColors.link },
                  ].map((s) => (
                    <KatanaCard key={s.label} padding={12}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <Icon name={s.icon} size={18} color={s.color} />
                        <span style={KatanaType.small}>{s.label}</span>
                      </div>
                      <div style={{ fontFamily: Fonts.display, fontSize: 22, fontWeight: 700, color: KatanaColors.text, marginTop: 4 }}>
                        {s.value}
                      </div>
                    </KatanaCard>
                  ))}
                </div>

                {/* Status buckets */}
                <div className="no-scrollbar" style={{ marginTop: 14, display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 2 }}>
                  {(['all', 'reading', 'caught_up', 'on_hold', 'completed', 'planned', 'dropped'] as const).map((bucket) => {
                    const active = libraryBucket === bucket;
                    const label =
                      bucket === 'all' ? 'All' : bucket === 'caught_up' ? 'Caught Up' : STATUS_LABELS[bucket].label;
                    return (
                      <button
                        key={bucket}
                        type="button"
                        className="bare-button"
                        onClick={() => setLibraryBucket(bucket)}
                        style={{
                          flexShrink: 0,
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
                      gridTemplateColumns: `repeat(${
                        libraryViewMode === 'compact'
                          ? width >= 1120 ? 6 : width >= 800 ? 5 : width >= 540 ? 4 : 3
                          : width >= 1120 ? 5 : width >= 800 ? 4 : width >= 540 ? 3 : 2
                      }, minmax(0, 1fr))`,
                      gap: libraryViewMode === 'compact' ? 10 : 14,
                    }}
                  >
                    {filteredLibrary.map((bm) => {
                      const unread = estimateUnreadCount(bm);
                      const dlCount = downloadedCounts[bm.slug] ?? 0;
                      const selected = selectedLibrarySlugs.has(bm.slug);
                      return (
                        <button
                          key={bm.slug}
                          type="button"
                          className="bare-button"
                          onClick={() => (librarySelectMode ? toggleSelectLibrarySlug(bm.slug) : openDetail(bm.slug))}
                          style={{
                            borderRadius: 11,
                            overflow: 'hidden',
                            background: KatanaColors.surface,
                            border: `2px solid ${selected ? KatanaColors.accent : KatanaColors.border}`,
                            textAlign: 'left',
                            display: 'flex',
                            flexDirection: 'column',
                          }}
                        >
                          <div style={{ position: 'relative', width: '100%', aspectRatio: '2 / 3', background: KatanaColors.surfaceAlt }}>
                            <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={24} />
                            <KatanaCoverBadges unreadCount={unread} downloadedCount={dlCount} />
                            {librarySelectMode && (
                              <span
                                style={{
                                  position: 'absolute',
                                  top: 6,
                                  left: 6,
                                  width: 24,
                                  height: 24,
                                  borderRadius: 6,
                                  background: selected ? KatanaColors.accent : 'rgba(11, 13, 18, 0.78)',
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
                                  padding: '22px 8px 8px',
                                  background: 'linear-gradient(to top, rgba(11, 13, 18, 0.94), transparent)',
                                }}
                              >
                                <div className="clamp-2" style={{ fontFamily: Fonts.body, fontSize: 12.5, fontWeight: 700, color: '#FFFFFF', lineHeight: 1.2 }}>
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
                      );
                    })}
                  </div>
                )}
              </div>
            ) : tab === 'reading' ? (
              <div>
                <KatanaBreadcrumb items={['Currently Reading']} onHome={() => handleNav('home')} />
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
                  <KatanaSectionHeader title="Currently Reading" badge={String(currentlyReading.length)} />
                  {isCoupleUser && partnerUsername && (
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
                  )}
                </div>
                <div style={{ height: 14 }} />
                {currentlyReading.length === 0 ? (
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
                onOpen={openOfflineMangaChapter}
                onDelete={(id) => void offlineMedia.deleteDownload(id)}
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
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
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
                    {!compactCard && (
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
                                width: 30,
                                height: 26,
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
                    )}
                  </div>
                </div>

                {/* Desktop/Tablet inline filter drawer */}
                {filterOpen && !compactCard && (catalogMode === 'directory' || catalogMode === 'genre' || catalogMode === 'search') && (
                  <KatanaCard padding={16} style={{ marginTop: 12 }}>
                    {filterPanelBody}
                    {activeFilterCount > 0 && (
                      <div style={{ marginTop: 12, display: 'flex', justifyContent: 'flex-end' }}>
                        <KatanaButton label="Clear all filters" icon="restart_alt" size="sm" filled={false} color={KatanaColors.textMuted} onClick={clearCatalogFilters} />
                      </div>
                    )}
                  </KatanaCard>
                )}

                {/* Phone filter bottom sheet */}
                {filterOpen && compactCard && (catalogMode === 'directory' || catalogMode === 'genre' || catalogMode === 'search') && (
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
                    }}
                    onClick={(e) => {
                      if (e.target === e.currentTarget) setFilterOpen(false);
                    }}
                  >
                    <div
                      style={{
                        maxHeight: '82vh',
                        borderRadius: '18px 18px 0 0',
                        background: KatanaColors.surface,
                        borderTop: `1px solid ${KatanaColors.borderStrong}`,
                        display: 'flex',
                        flexDirection: 'column',
                        overflow: 'hidden',
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 16px', borderBottom: `1px solid ${KatanaColors.border}` }}>
                        <span style={{ ...KatanaType.section, fontSize: 16 }}>Filters</span>
                        <button type="button" className="bare-button" aria-label="Close filters" onClick={() => setFilterOpen(false)}>
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
                                ? `Show ${catTotalResults} ${catTotalResults === 1 ? 'result' : 'results'}`
                                : `Show ${catItems.length} on this page`
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
                    <KatanaSkeletonGrid
                      count={width >= 1120 ? 12 : width >= 800 ? 10 : 8}
                      columns={width >= 1120 ? 6 : width >= 880 ? 5 : width >= KATANA_BREAKPOINTS.tablet ? 4 : 3}
                    />
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
                          gridTemplateColumns: `repeat(${width >= 1120 ? 6 : width >= 880 ? 5 : width >= KATANA_BREAKPOINTS.tablet ? 4 : 3}, minmax(0, 1fr))`,
                          gap: 14,
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

      {!desktop && !readerParams && (
        <KatanaBottomBar
          active={tab}
          readingCount={myCurrentlyReading.length}
          downloadsCount={offline.mangaItems.length}
          onSelectNav={handleNav}
        />
      )}

      {readerParams && <MangaReaderView params={readerParams} onClose={() => setReaderParams(null)} />}
    </div>
  );
}

function KatanaDownloadsView({
  items,
  storage,
  onOpen,
  onDelete,
  onClearAll,
  onBrowse,
}: {
  items: OfflineMediaItem[];
  storage: string;
  onOpen: (item: OfflineMediaItem) => void;
  onDelete: (id: string) => void;
  onClearAll: () => void;
  onBrowse: () => void;
}) {
  const groups = new Map<string, OfflineMediaItem[]>();
  for (const it of items) {
    const list = groups.get(it.mediaId) ?? [];
    list.push(it);
    groups.set(it.mediaId, list);
  }

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
        <KatanaSectionHeader title="Downloads" badge={items.length > 0 ? String(items.length) : undefined} />
        {items.length > 0 && (
          <button
            type="button"
            className="bare-button"
            onClick={onClearAll}
            style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '6px 10px' }}
          >
            <Icon name="delete_sweep" variant="outlined" size={18} color={KatanaColors.textLight} />
            <span style={KatanaType.small}>Clear All</span>
          </button>
        )}
      </div>
      <div style={{ height: 14 }} />
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
          <KatanaCard padding={14} style={{ marginBottom: 16 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <Icon name="storage" size={18} color={KatanaColors.accent} />
                <span style={KatanaType.small}>Offline storage used</span>
              </div>
              <span style={{ ...KatanaType.title, fontSize: 14 }}>{storage}</span>
            </div>
          </KatanaCard>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {[...groups.values()].map((chapters) => {
              const head = chapters[0];
              return (
                <KatanaCard key={head.mediaId} padding={0} style={{ overflow: 'hidden' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 12, borderBottom: `1px solid ${KatanaColors.border}` }}>
                    <div style={{ position: 'relative', width: 46, height: 66, borderRadius: 6, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                      <KatanaCoverImage url={head.coverUrl} title={head.title} iconSize={18} />
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={KatanaType.title}>{head.title}</div>
                      <div style={KatanaType.small}>
                        {chapters.length} {chapters.length === 1 ? 'chapter' : 'chapters'} offline
                      </div>
                    </div>
                  </div>
                  {chapters.map((ch, idx) => (
                    <div
                      key={ch.id}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 10,
                        padding: '10px 12px',
                        borderTop: idx > 0 ? `1px solid ${KatanaColors.border}` : undefined,
                      }}
                    >
                      <button
                        type="button"
                        className="bare-button"
                        onClick={() => onOpen(ch)}
                        style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 10, textAlign: 'left' }}
                      >
                        <Icon name="menu_book" size={18} color={KatanaColors.accentSoft} />
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div style={{ ...KatanaType.title, fontSize: 13.5 }}>{ch.subtitle || `Chapter ${ch.chapterId ?? ''}`}</div>
                          <div style={KatanaType.small}>{formattedSize(ch)}</div>
                        </div>
                      </button>
                      <button
                        type="button"
                        className="bare-button"
                        aria-label={`Delete ${ch.subtitle || ch.title}`}
                        onClick={() => onDelete(ch.id)}
                        style={{ width: 32, height: 32, display: 'grid', placeItems: 'center' }}
                      >
                        <Icon name="delete_outline" size={18} color={KatanaColors.textLight} />
                      </button>
                    </div>
                  ))}
                </KatanaCard>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}
