import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
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
import { MangaHome } from './MangaHome';
import { MangaReaderView, type MangaReaderParams } from './MangaReaderPage';
import {
  KatanaBottomBar,
  KatanaBreadcrumb,
  KatanaButton,
  KatanaCard,
  KatanaCompactCard,
  KatanaCoverImage,
  KatanaEmptyState,
  KatanaErrorBanner,
  KatanaHeader,
  KatanaItemCard,
  KatanaPagination,
  KatanaPosterCard,
  KatanaSectionHeader,
  type KatanaNavKey,
} from './MangaUi';
import {
  chapterDisplayTitle,
  clearKatanaReadingProgress,
  fetchKatanaByType,
  fetchKatanaCatalog,
  fetchKatanaChapterPages,
  fetchKatanaDetail,
  fetchKatanaHome,
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
  completed: { label: 'Completed', icon: 'check_circle', color: KatanaColors.green },
  planned: { label: 'Plan to Read', icon: 'schedule', color: KatanaColors.link },
  dropped: { label: 'Dropped', icon: 'pause_circle', color: KatanaColors.textLight },
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

export function MangaPage() {
  const { width } = useViewport();
  const { currentUser, isCoupleUser, partnerUsername } = useAuth();
  const navigate = useNavigate();
  const offline = useOfflineMedia();

  const [tab, setTab] = useState<KatanaNavKey>('home');
  const [catalogMode, setCatalogMode] = useState<'directory' | 'latest' | 'new' | 'genre' | 'search'>('directory');
  const [genreSlug, setGenreSlug] = useState('');
  const [genreTitle, setGenreTitle] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [searchBy, setSearchBy] = useState<'m_name' | 'author'>('m_name');
  const [detailSlug, setDetailSlug] = useState<string | null>(null);
  const [readerParams, setReaderParams] = useState<MangaReaderParams | null>(null);
  const [showPartnerReading, setShowPartnerReading] = useState(false);
  const [resumingSlug, setResumingSlug] = useState<string | null>(null);

  // Home data
  const [homeData, setHomeData] = useState<KatanaHomeData | null>(null);
  const [homeLoading, setHomeLoading] = useState(true);
  const [homeRefreshTick, setHomeRefreshTick] = useState(0);
  const [typeFilter, setTypeFilter] = useState<'all' | 'manga' | 'manhwa' | 'manhua'>('all');
  const [typeItems, setTypeItems] = useState<KatanaManga[]>([]);
  const [typePage, setTypePage] = useState(1);
  const [typeHasNext, setTypeHasNext] = useState(false);
  const [typeLoading, setTypeLoading] = useState(false);

  // Catalog & advanced filter state
  const [catItems, setCatItems] = useState<KatanaManga[]>([]);
  const [catPage, setCatPage] = useState(1);
  const [catHasNext, setCatHasNext] = useState(false);
  const [catLoading, setCatLoading] = useState(false);
  const [catError, setCatError] = useState<string | undefined>(undefined);
  const [catRefreshTick, setCatRefreshTick] = useState(0);
  const [catViewMode, setCatViewMode] = useState<'grid' | 'list'>(() => (width >= KATANA_BREAKPOINTS.tablet ? 'grid' : 'list'));
  const [filterOpen, setFilterOpen] = useState(false);
  const [includeGenres, setIncludeGenres] = useState<string[]>([]);
  const [excludeGenres, setExcludeGenres] = useState<string[]>([]);
  const [genreMode, setGenreMode] = useState<'and' | 'or'>('and');
  const [minChapters, setMinChapters] = useState<string>('1');
  const [orderBy, setOrderBy] = useState<string>('latest');

  // Genres directory search
  const [genreFilterText, setGenreFilterText] = useState('');

  // Library filter/sort state
  const [libraryBucket, setLibraryBucket] = useState<'all' | KatanaLibraryStatus>('all');
  const [libraryQuery, setLibraryQuery] = useState('');
  const [librarySort, setLibrarySort] = useState<'recent' | 'title' | 'progress'>('recent');

  // Detail data & chapter controls
  const [detail, setDetail] = useState<KatanaManga | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [chapterSortAsc, setChapterSortAsc] = useState(false);
  const [chapterSearch, setChapterSearch] = useState('');
  const [chapterWindow, setChapterWindow] = useState(40);
  const [downloadingChapterIds, setDownloadingChapterIds] = useState<Set<string>>(() => new Set());

  const userName = currentUser ?? '';
  const bookmarks = useSource(() => watchKatanaBookmarks(userName), [userName], []);
  const partnerBookmarks = useSource(
    () => (isCoupleUser && partnerUsername ? watchKatanaBookmarks(partnerUsername) : null),
    [isCoupleUser, partnerUsername],
    [],
  );

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
      setTypeLoading(false);
    });
    return () => {
      alive = false;
    };
  }, [typeFilter, typePage]);

  useEffect(() => {
    const isCatalogTab = ['latest', 'directory', 'newManga'].includes(tab) || (tab === 'genres' && genreSlug !== '') || catalogMode === 'search';
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
    }).then((res) => {
      if (!alive) return;
      setCatItems(res.items);
      setCatHasNext(res.hasNext);
      setCatError(res.error);
      setCatLoading(false);
    });
    return () => {
      alive = false;
    };
  }, [tab, catalogMode, genreSlug, catPage, searchQuery, searchBy, includeGenres, excludeGenres, genreMode, minChapters, orderBy, catRefreshTick]);

  useEffect(() => {
    if (!detailSlug) return;
    let alive = true;
    setDetailLoading(true);
    setChapterSearch('');
    setChapterWindow(40);
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
    setDetailSlug(null);
    setTab(next);
    setCatPage(1);
    if (next === 'latest') setCatalogMode('latest');
    else if (next === 'directory') setCatalogMode('directory');
    else if (next === 'newManga') setCatalogMode('new');
    else if (next === 'genres') {
      setGenreSlug('');
      setGenreTitle('');
    }
  };

  const handleSelectGenre = (g: KatanaGenre) => {
    setDetailSlug(null);
    setGenreSlug(g.slug);
    setGenreTitle(g.name);
    setCatalogMode('genre');
    setTab('genres');
    setCatPage(1);
  };

  const activeFilterCount =
    includeGenres.length + excludeGenres.length + (minChapters !== '1' ? 1 : 0) + (orderBy !== 'latest' ? 1 : 0);

  const clearCatalogFilters = () => {
    setIncludeGenres([]);
    setExcludeGenres([]);
    setGenreMode('and');
    setMinChapters('1');
    setOrderBy('latest');
    setCatPage(1);
  };

  const cycleGenreFilter = (slug: string) => {
    setCatPage(1);
    if (includeGenres.includes(slug)) {
      setIncludeGenres((prev) => prev.filter((s) => s !== slug));
      setExcludeGenres((prev) => [...prev, slug]);
    } else if (excludeGenres.includes(slug)) {
      setExcludeGenres((prev) => prev.filter((s) => s !== slug));
    } else {
      setIncludeGenres((prev) => [...prev, slug]);
    }
  };

  const currentlyReading = useMemo(
    () => (showPartnerReading ? partnerBookmarks : bookmarks).filter((b) => b.lastReadChapterId),
    [bookmarks, partnerBookmarks, showPartnerReading],
  );
  const savedBookmarks = useMemo(() => bookmarks.filter((b) => b.bookmarked), [bookmarks]);

  const libraryCounts = useMemo(() => {
    const counts: Record<'all' | KatanaLibraryStatus, number> = {
      all: savedBookmarks.length,
      reading: 0,
      completed: 0,
      planned: 0,
      dropped: 0,
    };
    for (const bm of savedBookmarks) {
      counts[resolveLibraryStatus(bm)] += 1;
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
      if (libraryBucket !== 'all' && resolveLibraryStatus(bm) !== libraryBucket) return false;
      if (q && !bm.title.toLowerCase().includes(q)) return false;
      return true;
    });
    if (librarySort === 'title') list.sort((a, b) => a.title.localeCompare(b.title));
    else if (librarySort === 'progress') list.sort((a, b) => (b.readChapterIds?.length ?? 0) - (a.readChapterIds?.length ?? 0));
    else list.sort((a, b) => b.addedAt.getTime() - a.addedAt.getTime());
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
      setDetailSlug(bm.slug);
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
        setDetailSlug(bm.slug);
      }
    } catch {
      showSnackBar('Could not resume chapter — opening details');
      setDetailSlug(bm.slug);
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

  const downloadChapter = useCallback(async (manga: KatanaManga, chapter: KatanaChapter) => {
    const offlineId = OfflineIds.mangaChapterId(manga.slug, chapter.id);
    if (offlineMedia.isDownloaded(offlineId)) {
      showSnackBar(`${chapterDisplayTitle(chapter)} is already saved offline`);
      return;
    }
    setDownloadingChapterIds((prev) => new Set(prev).add(chapter.id));
    try {
      const pages = await fetchKatanaChapterPages(manga.slug, chapter.id);
      if (pages.length === 0) {
        showSnackBar(`Could not fetch pages for ${chapterDisplayTitle(chapter)}`);
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
      showSnackBar(`Saved ${chapterDisplayTitle(chapter)} for offline reading`);
    } catch {
      showSnackBar(`Download failed for ${chapterDisplayTitle(chapter)}`);
    } finally {
      setDownloadingChapterIds((prev) => {
        const next = new Set(prev);
        next.delete(chapter.id);
        return next;
      });
    }
  }, []);

  const downloadNextUnread = useCallback(
    async (manga: KatanaManga, readIds: Set<string>, count = 3) => {
      const oldestFirst = [...manga.chapters].reverse();
      const targets = oldestFirst
        .filter((c) => !readIds.has(c.id) && !offlineMedia.isDownloaded(OfflineIds.mangaChapterId(manga.slug, c.id)))
        .slice(0, count);
      if (targets.length === 0) {
        showSnackBar('No new unread chapters to download');
        return;
      }
      showSnackBar(`Downloading ${targets.length} ${targets.length === 1 ? 'chapter' : 'chapters'}…`);
      for (const ch of targets) {
        await downloadChapter(manga, ch);
      }
    },
    [downloadChapter],
  );

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
          setDetailSlug(null);
          setSearchQuery(q);
          setSearchBy(by);
          setCatalogMode('search');
          setTab('directory');
          setCatPage(1);
        }}
        onSelectManga={(slug) => setDetailSlug(slug)}
        onSelectGenre={handleSelectGenre}
      />

      {isHome ? (
        <div ref={homeScrollRef} style={{ flex: 1, overflowY: 'auto' }}>
          <MangaHome
            width={width}
            data={homeData}
            currentlyReading={bookmarks.filter((b) => b.lastReadChapterId)}
            type={typeFilter}
            typeItems={typeItems}
            typeLoading={typeLoading}
            typePage={typePage}
            typeHasNext={typeHasNext}
            onSelectType={(t) => {
              setTypeFilter(t);
              setTypePage(1);
            }}
            onTypePage={setTypePage}
            onSelectManga={(slug) => setDetailSlug(slug)}
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
                <div style={{ padding: 56, display: 'grid', placeItems: 'center', gap: 12 }}>
                  <div className="spin" style={{ width: 32, height: 32, borderRadius: '50%', border: `3px solid ${KatanaColors.accent}`, borderRightColor: 'transparent' }} />
                  <span style={KatanaType.body}>Loading series details…</span>
                </div>
              ) : !detail ? (
                <KatanaEmptyState
                  icon="error_outline"
                  title="Could not load this title"
                  subtitle="The manga details could not be reached right now."
                  actionLabel="Back to Home"
                  actionIcon="arrow_back"
                  onAction={() => setDetailSlug(null)}
                />
              ) : (
                (() => {
                  const detailBm = bookmarks.find((b) => b.slug === detail.slug);
                  const isBookmarked = Boolean(detailBm?.bookmarked);
                  const hasReadingProgress = Boolean(detailBm?.lastReadChapterId);
                  const currentStatus = detailBm ? resolveLibraryStatus(detailBm) : undefined;
                  const readSet = new Set(detailBm?.readChapterIds ?? []);
                  const readCount = detail.chapters.filter((c) => readSet.has(c.id)).length;
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

                  return (
                    <div>
                      <KatanaBreadcrumb
                        items={['Manga', detail.title]}
                        onHome={() => {
                          setDetailSlug(null);
                          setTab('home');
                        }}
                      />

                      <KatanaCard padding={tablet ? 20 : 14}>
                        <div style={{ display: 'flex', gap: desktop ? 22 : 14, flexWrap: tablet ? 'nowrap' : 'wrap', alignItems: 'flex-start' }}>
                          <div
                            style={{
                              position: 'relative',
                              width: desktop ? 200 : tablet ? 160 : 120,
                              height: desktop ? 290 : tablet ? 232 : 174,
                              borderRadius: 10,
                              border: `1px solid ${KatanaColors.borderStrong}`,
                              overflow: 'hidden',
                              flexShrink: 0,
                              background: KatanaColors.surfaceAlt,
                            }}
                          >
                            <KatanaCoverImage url={detail.coverUrl} iconSize={34} />
                          </div>

                          <div style={{ flex: 1, minWidth: 220 }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', marginBottom: 6 }}>
                              <span
                                style={{
                                  padding: '2px 9px',
                                  borderRadius: 99,
                                  background: withAlpha(detail.status === 'completed' ? KatanaColors.green : KatanaColors.accent, 0.16),
                                  fontFamily: Fonts.body,
                                  fontSize: 11.5,
                                  fontWeight: 700,
                                  color: detail.status === 'completed' ? KatanaColors.green : KatanaColors.accentSoft,
                                }}
                              >
                                {detail.status === 'completed' ? 'Completed' : 'Ongoing'}
                              </span>
                              <span style={KatanaType.small}>{detail.chapters.length} chapters</span>
                              {detail.updateText && <span style={KatanaType.small}>· Updated {detail.updateText}</span>}
                            </div>

                            <h1 style={{ ...KatanaType.display, fontSize: tablet ? 28 : 22, margin: 0 }}>{detail.title}</h1>

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
                                  <span style={{ ...KatanaType.small, color: KatanaColors.accentSoft, fontWeight: 700 }}>
                                    {readCount} / {detail.chapters.length} ({readPct}%)
                                  </span>
                                </div>
                                <div style={{ height: 6, borderRadius: 99, background: KatanaColors.surfaceAlt, overflow: 'hidden' }}>
                                  <div style={{ width: `${readPct}%`, height: '100%', background: KatanaColors.accent, borderRadius: 99 }} />
                                </div>
                              </div>
                            )}

                            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 14 }}>
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
                              <KatanaButton
                                label={isBookmarked ? 'In Library' : 'Add to Library'}
                                icon={isBookmarked ? 'bookmark' : 'bookmark_border'}
                                filled={false}
                                color={isBookmarked ? KatanaColors.green : KatanaColors.accentSoft}
                                onClick={() => void setKatanaBookmark(detail, userName, !isBookmarked)}
                              />
                              {detail.chapters.length > 0 && (
                                <KatanaButton
                                  label="Download Next 3"
                                  icon="download"
                                  filled={false}
                                  color={KatanaColors.link}
                                  onClick={() => void downloadNextUnread(detail, readSet, 3)}
                                />
                              )}
                              {hasReadingProgress && (
                                <KatanaButton
                                  label="Reset Progress"
                                  icon="close"
                                  filled={false}
                                  color={KatanaColors.textMuted}
                                  onClick={() => void removeFromReading(detail.slug, detail.title)}
                                />
                              )}
                            </div>

                            {/* Library status selector */}
                            {userName && (
                              <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 6, marginTop: 12 }}>
                                <span style={{ ...KatanaType.small, marginRight: 4 }}>Shelf:</span>
                                {(['reading', 'completed', 'planned', 'dropped'] as const).map((st) => {
                                  const meta = STATUS_LABELS[st];
                                  const active = isBookmarked && currentStatus === st;
                                  return (
                                    <button
                                      key={st}
                                      type="button"
                                      className="bare-button"
                                      onClick={() => {
                                        void setKatanaLibraryStatus(detail, userName, st);
                                        showSnackBar(`Moved to ${meta.label}`);
                                      }}
                                      style={{
                                        padding: '4px 10px',
                                        borderRadius: 99,
                                        background: active ? withAlpha(meta.color, 0.18) : KatanaColors.surfaceAlt,
                                        border: `1px solid ${active ? meta.color : KatanaColors.border}`,
                                        display: 'inline-flex',
                                        alignItems: 'center',
                                        gap: 4,
                                        fontFamily: Fonts.body,
                                        fontSize: 12,
                                        fontWeight: active ? 700 : 500,
                                        color: active ? meta.color : KatanaColors.textMuted,
                                      }}
                                    >
                                      <Icon name={meta.icon} size={13} color={active ? meta.color : KatanaColors.textLight} />
                                      <span>{meta.label}</span>
                                    </button>
                                  );
                                })}
                              </div>
                            )}
                          </div>
                        </div>
                      </KatanaCard>

                      {detail.summary && (
                        <KatanaCard padding={16} style={{ marginTop: 14 }}>
                          <KatanaSectionHeader title="Synopsis" />
                          <p style={{ ...KatanaType.body, marginTop: 10, marginBottom: 0 }}>{detail.summary}</p>
                        </KatanaCard>
                      )}

                      <KatanaCard padding={16} style={{ marginTop: 14 }}>
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10 }}>
                          <KatanaSectionHeader
                            title={`Chapters (${detail.chapters.length})`}
                            badge={readCount > 0 ? `${readCount} read` : undefined}
                          />
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
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
                              <Icon name="swap_vert" size={15} color={KatanaColors.accentSoft} />
                              <span>{chapterSortAsc ? 'Oldest first' : 'Newest first'}</span>
                            </button>
                            {userName && detail.chapters.length > 0 && (
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
                                  background: isLastRead ? withAlpha(KatanaColors.accent, 0.1) : KatanaColors.surfaceAlt,
                                  border: `1px solid ${isLastRead ? withAlpha(KatanaColors.accent, 0.45) : KatanaColors.border}`,
                                }}
                              >
                                <button
                                  type="button"
                                  className="bare-button"
                                  onClick={() => openChapter(detail, c.id)}
                                  style={{
                                    flex: 1,
                                    minWidth: 0,
                                    display: 'flex',
                                    alignItems: 'center',
                                    gap: 8,
                                    textAlign: 'left',
                                  }}
                                >
                                  <Icon
                                    name={isLastRead ? 'play_circle' : isRead ? 'check_circle' : 'radio_button_unchecked'}
                                    size={17}
                                    color={isLastRead ? KatanaColors.accent : isRead ? KatanaColors.green : KatanaColors.textLight}
                                  />
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

                                {userName && (
                                  <button
                                    type="button"
                                    className="bare-button"
                                    title={isRead ? 'Mark unread' : 'Mark read'}
                                    aria-label={isRead ? `Mark ${chapterDisplayTitle(c)} unread` : `Mark ${chapterDisplayTitle(c)} read`}
                                    onClick={() => void markKatanaChaptersRead(detail, userName, [c.id], !isRead)}
                                    style={{ width: 32, height: 32, borderRadius: 7, display: 'grid', placeItems: 'center', flexShrink: 0 }}
                                  >
                                    <Icon name={isRead ? 'visibility_off' : 'done'} size={17} color={KatanaColors.textLight} />
                                  </button>
                                )}

                                <button
                                  type="button"
                                  className="bare-button"
                                  title={isOffline ? 'Saved offline' : 'Download chapter'}
                                  aria-label={isOffline ? `${chapterDisplayTitle(c)} saved offline` : `Download ${chapterDisplayTitle(c)}`}
                                  onClick={() => void downloadChapter(detail, c)}
                                  style={{ width: 32, height: 32, borderRadius: 7, display: 'grid', placeItems: 'center', flexShrink: 0 }}
                                >
                                  <Icon
                                    name={isOffline ? 'download_done' : isDownloading ? 'hourglass_top' : 'download'}
                                    size={18}
                                    color={isOffline ? KatanaColors.green : isDownloading ? KatanaColors.accent : KatanaColors.textMuted}
                                  />
                                </button>
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
                              color={KatanaColors.accentSoft}
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

                      {similarToDetail.length > 0 && (
                        <div style={{ marginTop: 18 }}>
                          <KatanaSectionHeader title="More Like This" />
                          <div style={{ height: 10 }} />
                          <div className="no-scrollbar" style={{ overflowX: 'auto', display: 'flex', gap: 12, paddingBottom: 4 }}>
                            {similarToDetail.map((m) => (
                              <KatanaCompactCard
                                key={m.slug}
                                manga={m}
                                width={tablet ? 124 : 108}
                                onSelect={() => setDetailSlug(m.slug)}
                                onOpenChapter={openChapter}
                              />
                            ))}
                          </div>
                        </div>
                      )}
                    </div>
                  );
                })()
              )
            ) : tab === 'bookmarks' ? (
              <div>
                <KatanaBreadcrumb items={['Library']} onHome={() => setTab('home')} />
                <KatanaSectionHeader title="Library" badge={String(savedBookmarks.length)} />

                {/* Reading Stats Bar */}
                <div
                  style={{
                    marginTop: 12,
                    display: 'grid',
                    gridTemplateColumns: tablet ? 'repeat(4, minmax(0, 1fr))' : 'repeat(2, minmax(0, 1fr))',
                    gap: 10,
                  }}
                >
                  {[
                    { label: 'In Library', value: savedBookmarks.length, icon: 'bookmarks', color: KatanaColors.accent },
                    { label: 'Reading', value: libraryCounts.reading, icon: 'auto_stories', color: KatanaColors.link },
                    { label: 'Completed', value: libraryCounts.completed, icon: 'check_circle', color: KatanaColors.green },
                    { label: 'Chapters Read', value: totalChaptersRead, icon: 'menu_book', color: KatanaColors.teal },
                  ].map((stat) => (
                    <KatanaCard key={stat.label} padding={12}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <Icon name={stat.icon} size={18} color={stat.color} />
                        <span style={KatanaType.small}>{stat.label}</span>
                      </div>
                      <div style={{ ...KatanaType.heading, fontSize: 22, marginTop: 4 }}>{stat.value}</div>
                    </KatanaCard>
                  ))}
                </div>

                {/* Status buckets */}
                <div className="no-scrollbar" style={{ marginTop: 14, display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 2 }}>
                  {(['all', 'reading', 'completed', 'planned', 'dropped'] as const).map((bucket) => {
                    const active = libraryBucket === bucket;
                    const label = bucket === 'all' ? 'All' : STATUS_LABELS[bucket].label;
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
                          background: active ? KatanaColors.accent : KatanaColors.surfaceAlt,
                          border: `1px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                          fontFamily: Fonts.body,
                          fontSize: 12.5,
                          fontWeight: 700,
                          color: active ? KatanaColors.accentInk : KatanaColors.textMuted,
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
                    <div style={{ display: 'inline-flex', gap: 6 }}>
                      {(
                        [
                          ['recent', 'Recent'],
                          ['title', 'A–Z'],
                          ['progress', 'Progress'],
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
                            background: librarySort === id ? withAlpha(KatanaColors.accent, 0.16) : KatanaColors.surfaceAlt,
                            border: `1px solid ${librarySort === id ? KatanaColors.accent : KatanaColors.border}`,
                            fontFamily: Fonts.body,
                            fontSize: 12,
                            fontWeight: 600,
                            color: librarySort === id ? KatanaColors.accentSoft : KatanaColors.textMuted,
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
                        ? 'Bookmark any manga, manhwa, or manhua to organize your shelves and track progress.'
                        : 'Try switching shelves or clearing your search text.'
                    }
                    actionLabel={savedBookmarks.length === 0 ? 'Explore Catalog' : 'Show All'}
                    actionIcon={savedBookmarks.length === 0 ? 'explore' : 'refresh'}
                    onAction={() => {
                      if (savedBookmarks.length === 0) handleNav('home');
                      else {
                        setLibraryBucket('all');
                        setLibraryQuery('');
                      }
                    }}
                  />
                ) : (
                  <div style={{ display: 'grid', gridTemplateColumns: desktop ? 'repeat(3, minmax(0, 1fr))' : tablet ? 'repeat(2, minmax(0, 1fr))' : '1fr', gap: 12 }}>
                    {filteredLibrary.map((bm) => {
                      const st = resolveLibraryStatus(bm);
                      const meta = STATUS_LABELS[st];
                      return (
                        <KatanaCard key={bm.slug} padding={12}>
                          <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
                            <button
                              type="button"
                              className="bare-button"
                              aria-label={`Open ${bm.title}`}
                              onClick={() => setDetailSlug(bm.slug)}
                              style={{ position: 'relative', width: 68, height: 98, borderRadius: 8, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}
                            >
                              <KatanaCoverImage url={bm.coverUrl} iconSize={22} />
                            </button>
                            <div style={{ flex: 1, minWidth: 0 }}>
                              <button
                                type="button"
                                className="bare-button"
                                onClick={() => setDetailSlug(bm.slug)}
                                style={{ textAlign: 'left', width: '100%' }}
                              >
                                <div className="clamp-2" style={KatanaType.title}>{bm.title}</div>
                              </button>
                              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
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
                                  {meta.label}
                                </span>
                                {bm.readChapterIds.length > 0 && (
                                  <span style={KatanaType.small}>{bm.readChapterIds.length} ch read</span>
                                )}
                              </div>
                              {bm.lastReadChapterTitle && (
                                <div style={{ ...KatanaType.small, color: KatanaColors.accentSoft, marginTop: 6 }}>
                                  {bm.lastReadChapterTitle}
                                  {bm.latestChapterTitle ? ` · Latest: ${bm.latestChapterTitle}` : ''}
                                </div>
                              )}
                              <div style={{ marginTop: 8, display: 'flex', gap: 6 }}>
                                <KatanaButton
                                  label={bm.lastReadChapterId ? 'Resume' : 'Read'}
                                  icon="play_arrow"
                                  size="sm"
                                  onClick={() => void resumeBookmark(bm)}
                                />
                              </div>
                            </div>
                          </div>
                        </KatanaCard>
                      );
                    })}
                  </div>
                )}
              </div>
            ) : tab === 'reading' ? (
              <div>
                <KatanaBreadcrumb items={['Currently Reading']} onHome={() => setTab('home')} />
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
                              color: active ? KatanaColors.accentInk : KatanaColors.textMuted,
                              fontFamily: Fonts.body,
                              fontSize: 12.5,
                              fontWeight: 700,
                            }}
                          >
                            {label}
                          </button>
                        );
                      })}
                    </div>
                  )}
                </div>
                <div style={{ height: 12 }} />
                {currentlyReading.length === 0 ? (
                  <KatanaEmptyState
                    icon="auto_stories"
                    title="Nothing in progress yet"
                    subtitle="Start any chapter and MangaCelestia will remember your exact page here."
                    actionLabel="Browse Home"
                    actionIcon="home"
                    onAction={() => handleNav('home')}
                  />
                ) : (
                  <div style={{ display: 'grid', gridTemplateColumns: tablet ? 'repeat(2, minmax(0, 1fr))' : '1fr', gap: 10 }}>
                    {currentlyReading.map((bm) => (
                      <KatanaCard key={bm.slug} padding={12}>
                        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                          <button
                            type="button"
                            className="bare-button"
                            onClick={() => setDetailSlug(bm.slug)}
                            style={{ display: 'flex', gap: 12, alignItems: 'center', flex: 1, minWidth: 0, textAlign: 'left' }}
                          >
                            <div style={{ position: 'relative', width: 56, height: 80, borderRadius: 8, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                              <KatanaCoverImage url={bm.coverUrl} iconSize={20} />
                            </div>
                            <div style={{ flex: 1, minWidth: 0 }}>
                              <div className="clamp-2" style={KatanaType.title}>{bm.title}</div>
                              <div style={{ ...KatanaType.small, color: KatanaColors.accentSoft, marginTop: 4 }}>
                                {bm.lastReadChapterTitle} · Page {bm.lastReadPage || 1}
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
                    ))}
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
                        <TextButton key="cancel" onPressed={() => close(null)} color={KatanaColors.textMuted}>Cancel</TextButton>,
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
                <KatanaBreadcrumb items={['Genres']} onHome={() => setTab('home')} />
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
                            <span style={{ padding: '2px 7px', borderRadius: 10, background: withAlpha(KatanaColors.accent, 0.14), ...KatanaType.accent, fontSize: 11 }}>
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
                      ? `Search: "${searchQuery}"`
                      : catalogMode === 'genre'
                        ? genreTitle || genreSlug
                        : catalogMode === 'latest'
                          ? 'Latest Updates'
                          : catalogMode === 'new'
                            ? 'New Releases'
                            : 'Browse Catalog',
                  ]}
                  onHome={() => setTab('home')}
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
                  />
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                    {(catalogMode === 'directory' || catalogMode === 'genre') && (
                      <button
                        type="button"
                        className="bare-button"
                        onClick={() => setFilterOpen((o) => !o)}
                        style={{
                          padding: '6px 12px',
                          borderRadius: 99,
                          background: filterOpen || activeFilterCount > 0 ? withAlpha(KatanaColors.accent, 0.16) : KatanaColors.surfaceAlt,
                          border: `1px solid ${filterOpen || activeFilterCount > 0 ? KatanaColors.accent : KatanaColors.borderStrong}`,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 6,
                          fontFamily: Fonts.body,
                          fontSize: 12.5,
                          fontWeight: 700,
                          color: filterOpen || activeFilterCount > 0 ? KatanaColors.accentSoft : KatanaColors.text,
                        }}
                      >
                        <Icon name="tune" size={15} color={filterOpen || activeFilterCount > 0 ? KatanaColors.accent : KatanaColors.textMuted} />
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
                                background: active ? KatanaColors.accent : 'transparent',
                                display: 'grid',
                                placeItems: 'center',
                              }}
                            >
                              <Icon name={mode === 'grid' ? 'grid_view' : 'view_agenda'} size={16} color={active ? KatanaColors.accentInk : KatanaColors.textMuted} />
                            </button>
                          );
                        })}
                      </div>
                    )}
                  </div>
                </div>

                {/* Expandable Advanced Filter Drawer */}
                {filterOpen && (catalogMode === 'directory' || catalogMode === 'genre') && (
                  <KatanaCard padding={14} style={{ marginTop: 12 }}>
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 16, alignItems: 'flex-start' }}>
                      <div>
                        <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Sort by</div>
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                          {ORDER_OPTIONS.map((opt) => (
                            <button
                              key={opt.id}
                              type="button"
                              className="bare-button"
                              onClick={() => {
                                setOrderBy(opt.id);
                                setCatPage(1);
                              }}
                              style={{
                                padding: '5px 10px',
                                borderRadius: 7,
                                background: orderBy === opt.id ? KatanaColors.accent : KatanaColors.surfaceAlt,
                                border: `1px solid ${orderBy === opt.id ? KatanaColors.accent : KatanaColors.border}`,
                                fontFamily: Fonts.body,
                                fontSize: 12,
                                fontWeight: 700,
                                color: orderBy === opt.id ? KatanaColors.accentInk : KatanaColors.textMuted,
                              }}
                            >
                              {opt.label}
                            </button>
                          ))}
                        </div>
                      </div>

                      <div>
                        <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Min chapters</div>
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                          {MIN_CHAPTER_OPTIONS.map((opt) => (
                            <button
                              key={opt.id}
                              type="button"
                              className="bare-button"
                              onClick={() => {
                                setMinChapters(opt.id);
                                setCatPage(1);
                              }}
                              style={{
                                padding: '5px 10px',
                                borderRadius: 7,
                                background: minChapters === opt.id ? KatanaColors.accent : KatanaColors.surfaceAlt,
                                border: `1px solid ${minChapters === opt.id ? KatanaColors.accent : KatanaColors.border}`,
                                fontFamily: Fonts.body,
                                fontSize: 12,
                                fontWeight: 700,
                                color: minChapters === opt.id ? KatanaColors.accentInk : KatanaColors.textMuted,
                              }}
                            >
                              {opt.label}
                            </button>
                          ))}
                        </div>
                      </div>

                      <div>
                        <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Genre match</div>
                        <div style={{ display: 'flex', gap: 6 }}>
                          {(['and', 'or'] as const).map((gm) => (
                            <button
                              key={gm}
                              type="button"
                              className="bare-button"
                              onClick={() => {
                                setGenreMode(gm);
                                setCatPage(1);
                              }}
                              style={{
                                padding: '5px 10px',
                                borderRadius: 7,
                                background: genreMode === gm ? KatanaColors.link : KatanaColors.surfaceAlt,
                                border: `1px solid ${genreMode === gm ? KatanaColors.link : KatanaColors.border}`,
                                fontFamily: Fonts.body,
                                fontSize: 12,
                                fontWeight: 700,
                                color: genreMode === gm ? KatanaColors.accentInk : KatanaColors.textMuted,
                              }}
                            >
                              {gm === 'and' ? 'Match All' : 'Match Any'}
                            </button>
                          ))}
                        </div>
                      </div>
                    </div>

                    {(homeData?.genres ?? []).length > 0 && (
                      <div style={{ marginTop: 12 }}>
                        <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>
                          Tags (tap once to include, twice to exclude)
                        </div>
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                          {(homeData?.genres ?? []).map((g) => {
                            const inc = includeGenres.includes(g.slug);
                            const exc = excludeGenres.includes(g.slug);
                            return (
                              <button
                                key={g.slug}
                                type="button"
                                className="bare-button"
                                onClick={() => cycleGenreFilter(g.slug)}
                                style={{
                                  padding: '4px 10px',
                                  borderRadius: 7,
                                  background: inc
                                    ? withAlpha(KatanaColors.green, 0.18)
                                    : exc
                                      ? withAlpha(KatanaColors.crimson, 0.18)
                                      : KatanaColors.surfaceAlt,
                                  border: `1px solid ${inc ? KatanaColors.green : exc ? KatanaColors.crimson : KatanaColors.border}`,
                                  fontFamily: Fonts.body,
                                  fontSize: 12,
                                  fontWeight: 600,
                                  color: inc ? KatanaColors.green : exc ? KatanaColors.crimson : KatanaColors.textMuted,
                                }}
                              >
                                {inc ? '+ ' : exc ? '− ' : ''}
                                {g.name}
                              </button>
                            );
                          })}
                        </div>
                      </div>
                    )}

                    {activeFilterCount > 0 && (
                      <div style={{ marginTop: 12, display: 'flex', justifyContent: 'flex-end' }}>
                        <KatanaButton label="Clear all filters" icon="restart_alt" size="sm" filled={false} color={KatanaColors.textMuted} onClick={clearCatalogFilters} />
                      </div>
                    )}
                  </KatanaCard>
                )}

                {/* Active filter chips summary */}
                {activeFilterCount > 0 && !filterOpen && (
                  <div style={{ marginTop: 10, display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center' }}>
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

                <div style={{ height: 12 }} />
                {catError && <KatanaErrorBanner message={catError} onRetry={() => setCatRefreshTick((n) => n + 1)} />}

                {catLoading ? (
                  <div style={{ padding: 48, display: 'grid', placeItems: 'center', gap: 10 }}>
                    <div className="spin" style={{ width: 32, height: 32, borderRadius: '50%', border: `3px solid ${KatanaColors.accent}`, borderRightColor: 'transparent' }} />
                    <span style={KatanaType.body}>Loading catalog…</span>
                  </div>
                ) : catItems.length === 0 ? (
                  <KatanaEmptyState
                    icon="search_off"
                    title="No titles found"
                    subtitle={
                      activeFilterCount > 0
                        ? 'Try relaxing one of your active genre or chapter filters.'
                        : 'Try a different keyword or browse from the home catalog.'
                    }
                    actionLabel={activeFilterCount > 0 ? 'Clear Filters' : 'Back to Home'}
                    actionIcon={activeFilterCount > 0 ? 'restart_alt' : 'home'}
                    onAction={() => (activeFilterCount > 0 ? clearCatalogFilters() : handleNav('home'))}
                  />
                ) : (
                  <>
                    {effectiveCatView === 'grid' ? (
                      <div style={{ display: 'grid', gridTemplateColumns: desktop ? 'repeat(5, minmax(0, 1fr))' : 'repeat(3, minmax(0, 1fr))', gap: 12 }}>
                        {catItems.map((m) => (
                          <KatanaPosterCard
                            key={m.slug}
                            manga={m}
                            onSelect={() => setDetailSlug(m.slug)}
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
                            onSelectManga={(slug) => setDetailSlug(slug)}
                            onSelectGenre={handleSelectGenre}
                            onOpenChapter={openChapter}
                          />
                        ))}
                      </div>
                    )}
                    <div style={{ height: 14 }} />
                    <KatanaPagination page={catPage} hasPrev={catPage > 1} hasNext={catHasNext} onPageChange={setCatPage} />
                  </>
                )}
              </div>
            ) : homeLoading && !homeData ? (
              <div style={{ padding: 56, display: 'grid', placeItems: 'center', gap: 12 }}>
                <div className="spin" style={{ width: 32, height: 32, borderRadius: '50%', border: `3px solid ${KatanaColors.accent}`, borderRightColor: 'transparent' }} />
                <span style={KatanaType.body}>Loading MangaCelestia…</span>
              </div>
            ) : null}
          </div>
        </div>
      )}

      {!desktop && (
        <KatanaBottomBar
          active={tab}
          readingCount={bookmarks.filter((b) => b.lastReadChapterId).length}
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
                      <KatanaCoverImage url={head.coverUrl} iconSize={18} />
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
