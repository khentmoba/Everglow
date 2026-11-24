// Port of lib/features/cinema/presentation/screens/cinema_screen.dart and tabs/*.dart.
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { withAlpha } from '../../core/theme/colors';
import { AppBreakpoint } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import { TvMediaNavHeader } from '../../shared/widgets/shelf/TvMediaNavHeader';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { Logger } from '../../core/system/logger';
import { CinemaHomeCache } from './cinemaHomeCache';
import { CinemaSearchTab } from './CinemaSearchTab';
import { CinemaBrowseTab } from './CinemaBrowseTab';
import { CinemaDownloadsTab } from './CinemaDownloadsTab';
import { CinemaLibraryTab } from './CinemaLibraryTab';
import { CinemaWatchTogetherTab } from '../watch_party/CinemaWatchTogetherTab';
import { CinemaEpisodeDrawer } from './CinemaEpisodeDrawer';
import { showCinemaPlaybackSheet } from './CinemaPlaybackSheet';
import { CinemaHomeSkeleton } from './CinemaHomeSkeleton';
import { NetflixColors, TOP_TEN_COUNTRY_LABEL, catalogKeyOf, resumeSecondsOf, type MediaItem } from './cinemaTypes';
import {
  MediaSectionMenuButton,
  NetflixBillboard,
  NetflixBottomNav,
  NetflixCinemaTopBar,
  NetflixRow,
  cinemaMobileNavItems,
  cinemaNavLinks,
} from './NetflixUi';
import {
  clearWatchProgress,
  discoverMedia,
  fetchPopularTVShows,
  fetchTrending,
  fetchTrendingByCountry,
  fetchUpcoming,
  saveToWatchList,
  saveWatchProgress,
  setListMembership,
  watchCinemaWatchlist,
} from './tmdbService';

interface DiscoveryShelf {
  title: string;
  type: 'movie' | 'tv';
  genre?: number;
  language?: string;
  reason: string;
}

const DISCOVERY_SHELVES: DiscoveryShelf[] = [
  { title: 'Top-Rated Movies', type: 'movie', reason: 'Loved by critics and viewers' },
  { title: 'Top-Rated Series', type: 'tv', reason: 'The best of the small screen' },
  { title: 'Action & Adventure', type: 'movie', genre: 28, reason: 'Big set pieces, bigger stakes' },
  { title: 'Need a Laugh?', type: 'movie', genre: 35, reason: 'Short of time, long on smiles' },
  { title: 'Romance', type: 'movie', genre: 10749, reason: 'For a slow evening together' },
  { title: 'Edge-of-Your-Seat Thrillers', type: 'movie', genre: 53, reason: 'Lights off, heart rate up' },
  { title: 'Sci-Fi Escapes', type: 'movie', genre: 878, reason: 'Other worlds, familiar feelings' },
  { title: 'Drama', type: 'movie', genre: 18, reason: 'Serious stories, big feelings' },
];

/** "1h 4m left": the honest counterpart to the tile's progress hairline. */
function remainingLabelOf(m: MediaItem): string | null {
  const pos = m.currentTimestamp ?? 0;
  const dur = m.durationSeconds ?? 0;
  if (pos <= 0 || dur <= 0 || pos >= dur) return null;
  const left = Math.max(1, Math.round((dur - pos) / 60));
  const hours = Math.floor(left / 60);
  return hours > 0 ? `${hours}h ${left % 60}m left` : `${left}m left`;
}

export function CinemaPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const [params, setSearchParams] = useSearchParams();
  const { width, height } = useViewport();

  const selectedBrowseId = params.get('browse');
  const currentTab = selectedBrowseId ? 2 : Math.max(0, Math.min(5, Number(params.get('tab') ?? 0) || 0));

  const [browseSeed, setBrowseSeed] = useState(selectedBrowseId ? 1 : 0);
  const [scrolled, setScrolled] = useState(false);

  const userName = auth.currentUser ?? '';
  const isCoupleUser = auth.isCoupleUser;
  const isCinemaOnlyUser = auth.isCinemaOnlyUser;
  const isDesktop = width >= AppBreakpoint.tablet;
  // An 820px iPad is not a phone: it gets the top bar and wider rails.
  const isTablet = !isDesktop && width >= 700;
  const isWide = isDesktop || isTablet;

  const watchlist = useSource(() => watchCinemaWatchlist(userName), [userName], []);
  const watchingList = useMemo(
    () =>
      watchlist
        .filter((m) => !m.isAnime && m.status.toLowerCase().includes('watching'))
        .sort((a, b) => (b.progressUpdatedAt ?? b.addedAt).getTime() - (a.progressUpdatedAt ?? a.addedAt).getTime()),
    [watchlist],
  );
  const savedList = useMemo(() => watchlist.filter((m) => !m.isAnime && m.status.toLowerCase() === 'to-watch'), [watchlist]);

  // The warm session cache fills the rails at once (`_applyCachedRows`).
  const [cached] = useState(() => CinemaHomeCache.read() ?? {});
  const [isLoadingHome, setIsLoadingHome] = useState(true);
  const [trendingGlobal, setTrendingGlobal] = useState<MediaItem[]>(cached.trendingGlobal ?? []);
  const [topTenToday, setTopTenToday] = useState<MediaItem[]>(cached.topTenToday ?? []);
  const [popularTV, setPopularTV] = useState<MediaItem[]>(cached.popularTVShows ?? []);
  const [newlyReleased, setNewlyReleased] = useState<MediaItem[]>(cached.newlyReleased ?? []);
  const [discoveryRows, setDiscoveryRows] = useState<Record<string, MediaItem[]>>(() =>
    Object.fromEntries(DISCOVERY_SHELVES.map((shelf) => [shelf.title, cached[shelf.title] ?? []])),
  );
  const [drawerItem, setDrawerItem] = useState<MediaItem | null>(null);
  const [drawerSeq, setDrawerSeq] = useState(0);
  const homeRequest = useRef(0);

  const loadHome = useCallback(async () => {
    const request = ++homeRequest.current;
    setIsLoadingHome(true);
    const year = new Date().getFullYear();
    const live: Record<string, MediaItem[]> = {};
    // `_loadRow`: a rail only changes when the fetch brings visible titles.
    const loadRow = async (key: string, fetch: Promise<MediaItem[]>, apply: (items: MediaItem[]) => void) => {
      try {
        const items = await fetch;
        if (request !== homeRequest.current) return;
        const visible = items.filter((m) => !m.isAnime);
        if (visible.length === 0) return;
        live[key] = visible;
        apply(visible);
      } catch (e) {
        Logger.e('Cinema: home rail fetch failed', e);
      }
    };
    await Promise.all([
      loadRow('trendingGlobal', fetchTrending('all', 'week'), setTrendingGlobal),
      loadRow('topTenToday', fetchTrendingByCountry('PH'), setTopTenToday),
      loadRow('popularTVShows', fetchPopularTVShows(), setPopularTV),
      loadRow(
        'newlyReleased',
        fetchUpcoming('PH').then((items) => items.filter((m) => !m.year || Number(m.year) >= year - 1)),
        setNewlyReleased,
      ),
    ]);
    if (request !== homeRequest.current) return;
    setIsLoadingHome(false);

    const BATCH_SIZE = 4;
    for (let i = 0; i < DISCOVERY_SHELVES.length; i += BATCH_SIZE) {
      if (request !== homeRequest.current) return;
      const slice = DISCOVERY_SHELVES.slice(i, i + BATCH_SIZE);
      const batchUpdates: Record<string, MediaItem[]> = {};
      await Promise.all(
        slice.map((shelf) =>
          loadRow(
            shelf.title,
            discoverMedia({
              mediaType: shelf.type,
              sortBy: shelf.genre == null ? 'vote_average.desc' : 'popularity.desc',
              withGenres: shelf.genre == null ? undefined : [shelf.genre],
              withOriginalLanguage: shelf.language,
              voteCountGte: shelf.genre == null ? 1000 : 100,
            }).then((r) => r.results),
            (items) => {
              batchUpdates[shelf.title] = items;
            },
          ),
        ),
      );
      if (request !== homeRequest.current) return;
      if (Object.keys(batchUpdates).length > 0) {
        setDiscoveryRows((rows) => ({ ...rows, ...batchUpdates }));
      }
    }
    if (request !== homeRequest.current) return;
    CinemaHomeCache.save(live);
  }, []);

  // Home rails load the first time Home is shown (initState / `_switchTab(0)`),
  // or not at all while the cache is under ten minutes old.
  const checkFreshness = useRef(currentTab === 0);
  useEffect(() => {
    if (currentTab !== 0 || homeRequest.current !== 0) return;
    const fresh = checkFreshness.current && CinemaHomeCache.isFresh(10 * 60 * 1000);
    checkFreshness.current = false;
    if (fresh) setIsLoadingHome(false);
    else void loadHome();
  }, [currentTab, loadHome]);

  // Each tab keeps its own place; returning to Home lands where you left it.
  const scrollRef = useRef<HTMLDivElement>(null);
  const tabScroll = useRef<Record<number, number>>({});
  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollTop = tabScroll.current[currentTab] ?? 0;
  }, [currentTab, selectedBrowseId]);

  const tabHistory = useRef<number[]>([]);
  const handleNavSelect = useCallback(
    (tab: number, browseOptionId?: string) => {
      const clamped = Math.max(0, Math.min(5, tab));
      if (clamped !== currentTab) tabHistory.current = [...tabHistory.current.slice(-8), currentTab];
      if (browseOptionId) setBrowseSeed((n) => n + 1);
      const next = new URLSearchParams(params);
      if (browseOptionId) {
        next.set('browse', browseOptionId);
        next.delete('tab');
      } else {
        next.delete('browse');
        if (clamped === 0) next.delete('tab');
        else next.set('tab', String(clamped));
      }
      if (next.toString() !== params.toString()) {
        setSearchParams(next);
      }
    },
    [currentTab, params, setSearchParams],
  );

  const launchPlayer = (item: MediaItem, season?: number, episode?: number, opts?: { restart?: boolean }) => {
    const resume = opts?.restart ? 0 : resumeSecondsOf(item);
    const qs = new URLSearchParams({
      type: item.mediaType,
      title: item.title,
      anime: 'false',
    });
    if (item.mediaType === 'tv') {
      qs.set('season', String(season ?? item.currentSeason ?? 1));
      qs.set('episode', String(episode ?? item.currentEpisode ?? 1));
    }
    if (resume != null && resume > 0) qs.set('start', String(resume));
    navigate(`/cinema/video/${item.tmdbId}?${qs.toString()}`);
  };

  // Tapping a Continue Watching tile resumes; the sheet lives behind the tile's ⋯.
  const handleContinueTap = (item: MediaItem) => launchPlayer(item);

  const handleContinueOptions = async (item: MediaItem) => {
    const action = await showCinemaPlaybackSheet(item);
    if (!action) return;
    if (action === 'resume') launchPlayer(item);
    else if (action === 'restart') launchPlayer(item, undefined, undefined, { restart: true });
    else if (action === 'episodes') setDrawerItem(item);
    else if (action === 'finished') void saveToWatchList(item, 'watched-self', userName);
    else if (action === 'remove') {
      const snapshot = watchlist.find((w) => catalogKeyOf(w) === catalogKeyOf(item));
      void clearWatchProgress(item, userName);
      // Removing progress is one tap, so it carries an Undo.
      showSnackBar('Removed from Continue Watching', {
        action: snapshot
          ? {
              label: 'Undo',
              onPressed: () =>
                void saveWatchProgress(item, userName, {
                  season: snapshot.currentSeason,
                  episode: snapshot.currentEpisode,
                  timestamp: snapshot.currentTimestamp,
                  durationSeconds: snapshot.durationSeconds,
                  status: snapshot.status,
                }),
            }
          : undefined,
      });
    }
  };

  // `_showMediaDetails`: the drawer opens with the saved status and progress.
  const withSavedProgress = (item: MediaItem): MediaItem => {
    const saved = watchlist.find((w) => catalogKeyOf(w) === catalogKeyOf(item));
    if (!saved) return item;
    return {
      ...item,
      id: saved.id,
      status: saved.status,
      userName: saved.userName,
      currentSeason: saved.currentSeason,
      currentEpisode: saved.currentEpisode,
      currentTimestamp: saved.currentTimestamp,
      durationSeconds: saved.durationSeconds,
      progressUpdatedAt: saved.progressUpdatedAt,
    };
  };
  // Back means back: the tab you came from, then Home, then out of Cinema.
  const handleBack = () => {
    const previous = tabHistory.current.pop();
    if (selectedBrowseId) {
      handleNavSelect(2);
      return;
    }
    if (previous != null && previous !== currentTab) {
      handleNavSelect(previous);
      return;
    }
    if (currentTab !== 0) {
      handleNavSelect(0);
      return;
    }
    if (isCoupleUser) void navigate('/dashboard');
    else void navigate('/');
  };

  const handleLogout = async () => {
    await auth.logout();
    navigate('/');
  };

  const links = cinemaNavLinks(isCinemaOnlyUser);
  const inList = (m: MediaItem) => watchlist.some((w) => catalogKeyOf(w) === catalogKeyOf(m));
  const rankOf = (m: MediaItem) => {
    const i = topTenToday.findIndex((t) => catalogKeyOf(t) === catalogKeyOf(m));
    return i >= 0 && i < 10 ? i + 1 : null;
  };
  const progressOf = (m: MediaItem) => {
    const pos = m.currentTimestamp ?? 0;
    const dur = m.durationSeconds ?? 0;
    if (pos <= 0 || dur <= 0) return null;
    return Math.min(1, Math.max(0, pos / dur));
  };

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: NetflixColors.background,
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
      }}
    >
      <TvMediaNavHeader currentRoute="/cinema" onLogout={() => void handleLogout()} />
      {isWide && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, zIndex: 20 }}>
          <NetflixCinemaTopBar
            currentIndex={currentTab}
            currentBrowseId={selectedBrowseId ?? (currentTab === 2 ? 'collection-movies' : null)}
            links={links}
            scrolled={scrolled}
            userName={userName}
            showAnime={isCinemaOnlyUser}
            onSelect={handleNavSelect}
            onAnimeTap={() => navigate('/anime')}
            onDashboardTap={isCoupleUser ? () => navigate('/dashboard') : undefined}
            onLogout={() => void handleLogout()}
          />
        </div>
      )}

      {!isWide && (
        <>
          <div
            style={{
              position: 'fixed',
              top: 'calc(10px + env(safe-area-inset-top, 0px))',
              left: 'calc(12px + env(safe-area-inset-left, 0px))',
              zIndex: 25,
            }}
          >
            <button
              type="button"
              className="bare-button"
              aria-label={isCoupleUser ? (currentTab === 0 && !selectedBrowseId ? 'Exit Cinema' : 'Back to Home') : 'Logout'}
              onClick={isCoupleUser ? handleBack : () => void handleLogout()}
              style={{
                // Readable over posters: the surface does the separating, not opacity.
                background: scrolled ? withAlpha(NetflixColors.background, 0.86) : NetflixColors.surface,
                transition: 'background 200ms ease',
                width: 48,
                height: 48,
                borderRadius: '50%',
                border: `1px solid ${NetflixColors.hairline}`,
                boxShadow: '0 4px 12px rgba(0,0,0,0.45)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon
                name={isCoupleUser ? 'arrow_back' : 'logout'}
                size={22}
                color="#FFFFFF"
              />
            </button>
          </div>
          {isCinemaOnlyUser && (
            <div
              style={{
                position: 'fixed',
                top: 'calc(10px + env(safe-area-inset-top, 0px))',
                right: 'calc(12px + env(safe-area-inset-right, 0px))',
                zIndex: 25,
              }}
            >
              <MediaSectionMenuButton currentRoute="/cinema" />
            </div>
          )}
        </>
      )}

      <div
        ref={scrollRef}
        className="no-scrollbar"
        onScroll={(e) => {
          setScrolled(e.currentTarget.scrollTop > 60);
          tabScroll.current[currentTab] = e.currentTarget.scrollTop;
        }}
        style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden' }}
      >
        {currentTab === 0 && (
          <HomeTab
            isDesktop={isDesktop}
            viewportHeight={height}
            viewportWidth={width}
            isLoading={isLoadingHome}
            trendingGlobal={trendingGlobal}
            topTenToday={topTenToday}
            popularTV={popularTV}
            newlyReleased={newlyReleased}
            discoveryRows={discoveryRows}
            watchingList={watchingList}
            savedList={savedList}
            onRefresh={loadHome}
            onTapItem={setDrawerItem}
            onTapContinue={handleContinueTap}
            onContinueOptions={(item) => void handleContinueOptions(item)}
            onPlay={(item) => launchPlayer(item)}
            onRestart={(item) => launchPlayer(item, undefined, undefined, { restart: true })}
            onToggleList={(item, add) => void setListMembership(item, userName, add)}
            isInList={inList}
            rankOf={rankOf}
            progressOf={progressOf}
            onExploreBrowse={() => handleNavSelect(2)}
          />
        )}
        {currentTab === 1 && (
          <CinemaSearchTab
            width={width}
            height={height}
            trendingGlobal={trendingGlobal}
            onMediaTap={setDrawerItem}
            onBrowse={() => handleNavSelect(2)}
          />
        )}
        {currentTab === 2 && (
          <CinemaBrowseTab
            key={`browse-${selectedBrowseId ?? 'none'}-${browseSeed}`}
            width={width}
            initialOptionId={selectedBrowseId}
            onMediaTap={setDrawerItem}
          />
        )}
        {currentTab === 3 && (
          <CinemaLibraryTab
            width={width}
            watchlist={watchlist}
            onMediaTap={setDrawerItem}
            onSwitchTab={handleNavSelect}
          />
        )}
        {currentTab === 4 && (
          <CinemaWatchTogetherTab
            isDesktop={isDesktop}
            width={width}
            watchlist={watchlist}
            onMediaTap={setDrawerItem}
            onSwitchTab={handleNavSelect}
          />
        )}
        {currentTab === 5 && <CinemaDownloadsTab width={width} onBrowseCinema={() => handleNavSelect(0)} />}
        <div style={{ height: 100 }} />
      </div>

      {!isWide && (
        <NetflixBottomNav
          currentIndex={currentTab}
          currentBrowseId={selectedBrowseId ?? (currentTab === 2 ? 'collection-movies' : null)}
          items={cinemaMobileNavItems(isCinemaOnlyUser)}
          onSelect={handleNavSelect}
          onAnimeTap={() => navigate('/anime')}
        />
      )}

      {drawerItem && (
        <CinemaEpisodeDrawer
          key={`${drawerItem.mediaType}:${drawerItem.tmdbId}:${drawerSeq}`}
          item={withSavedProgress(drawerItem)}
          topTenItems={topTenToday}
          onClose={() => setDrawerItem(null)}
          onShowItem={(it) => {
            setDrawerSeq((n) => n + 1);
            setDrawerItem(it);
          }}
        />
      )}
    </div>
  );
}

function HomeTab({
  isDesktop,
  viewportHeight,
  viewportWidth,
  isLoading,
  trendingGlobal,
  topTenToday,
  popularTV,
  newlyReleased,
  discoveryRows,
  watchingList,
  savedList,
  onRefresh,
  onTapItem,
  onTapContinue,
  onContinueOptions,
  onPlay,
  onRestart,
  onToggleList,
  isInList,
  rankOf,
  progressOf,
  onExploreBrowse,
}: {
  isDesktop: boolean;
  viewportHeight: number;
  viewportWidth: number;
  isLoading: boolean;
  trendingGlobal: MediaItem[];
  topTenToday: MediaItem[];
  popularTV: MediaItem[];
  newlyReleased: MediaItem[];
  discoveryRows: Record<string, MediaItem[]>;
  watchingList: MediaItem[];
  savedList: MediaItem[];
  onRefresh: () => void;
  onTapItem: (m: MediaItem) => void;
  onTapContinue: (m: MediaItem) => void;
  onContinueOptions: (m: MediaItem) => void;
  onPlay: (m: MediaItem) => void;
  onRestart: (m: MediaItem) => void;
  onToggleList: (m: MediaItem, add: boolean) => void;
  isInList: (m: MediaItem) => boolean;
  rankOf: (m: MediaItem) => number | null;
  progressOf: (m: MediaItem) => number | null;
  onExploreBrowse: () => void;
}) {
  const emptyCatalogue =
    !isLoading && trendingGlobal.length === 0 && topTenToday.length === 0 && newlyReleased.length === 0 && popularTV.length === 0;
  // Under this many posters a rail is not a recommendation, it is a stub.
  const MIN_RAIL_SHOWN = 4;
  // A full row is this many posters, whichever pool they came from.
  const MIN_RAIL = 6;
  // One rail is a row, not a dump: the pool behind it feeds the rails below.
  const RAIL_MAX = 8;
  // The billboard has already shown these five, so no rail repeats them.
  const heroTitles = trendingGlobal.slice(0, 5);
  const seen = new Set<string>(
    [...watchingList, ...savedList, ...heroTitles].map((m) => catalogKeyOf(m)),
  );
  const railSignatures = new Set<string>();
  // Two rails of memory: a row that copies the one two screens up reads as a
  // repeat just as much as an adjacent clone.
  const recentRails: string[][] = [];
  // The rail directly above may share nothing much; a rail three up may share
  // some, because a small catalogue cannot fill ten rows without repeating.
  const overlapsTooMuch = (keys: string[]) => {
    if (keys.length === 0) return false;
    return recentRails.some((rail, i) => {
      const limit = i === 0 ? 0.5 : 0.75;
      const shared = keys.filter((k) => rail.includes(k)).length;
      return shared / Math.min(keys.length, rail.length) >= limit;
    });
  };
  // Everything the page has fetched, so a shelf with a small pool can still be
  // a full row of titles that are not already on screen.
  const fallbackPool = [...trendingGlobal, ...topTenToday, ...popularTV, ...newlyReleased, ...Object.values(discoveryRows).flat()];
  const seenRow = (items: MediaItem[]) => {
    // A rail keeps its own titles first. It may borrow from the far end of its
    // pool to reach a usable length, but never enough to look like the rail
    // directly above it, which is what made two rows carry the same posters.
    // 1. the rail's own titles that are not on screen yet,
    // 2. fresh titles from anywhere else the page has fetched,
    // 3. and only then, repeat from its own pool: never from a rail above.
    // A rail also avoids the two rows directly above it, so no shelf is a copy
    // of its neighbour even when the catalogue is small.
    const recentKeys = new Set(recentRails.flat());
    const fresh = (m: MediaItem) => !seen.has(catalogKeyOf(m)) && !recentKeys.has(catalogKeyOf(m));
    const keep = items.filter(fresh);
    for (const m of fallbackPool) {
      if (keep.length >= MIN_RAIL) break;
      if (!fresh(m)) continue;
      if (keep.some((k) => catalogKeyOf(k) === catalogKeyOf(m))) continue;
      keep.push(m);
    }
    if (keep.length < MIN_RAIL_SHOWN) {
      for (const m of items) {
        if (recentKeys.has(catalogKeyOf(m))) continue;
        if (keep.some((k) => catalogKeyOf(k) === catalogKeyOf(m))) continue;
        keep.push(m);
      }
    }
    // One rail is a row, not a dump: the rest of the pool stays available for
    // the rails below it instead of being marked as already seen.
    const shown = keep.slice(0, RAIL_MAX);
    const keys = shown.map((m) => catalogKeyOf(m));
    // Two adjacent rows carrying the same posters is worse than one row fewer.
    if (keys.length < MIN_RAIL_SHOWN || overlapsTooMuch(keys)) return [];
    // A rail identical to one already on screen is not a second recommendation.
    const signature = [...keys].sort().join('|');
    if (railSignatures.has(signature)) return [];
    railSignatures.add(signature);
    recentRails.unshift(keys);
    if (recentRails.length > 3) recentRails.pop();
    for (const m of shown) seen.add(catalogKeyOf(m));
    return shown;
  };
  const becauseOf = watchingList[0];
  const becauseGenre = becauseOf?.genres?.[0];
  const becauseItems =
    becauseOf && becauseGenre
      ? trendingGlobal
          .filter((m) => m.genres?.includes(becauseGenre) && catalogKeyOf(m) !== catalogKeyOf(becauseOf))
          .slice(0, 12)
      : [];
  const rowProps = {
    isDesktop,
    onTapItem,
    onPlayItem: onPlay,
    onRestartItem: onRestart,
    onToggleListItem: onToggleList,
    isInList,
    progress: progressOf,
  };

  return (
    <div>
      {isLoading && trendingGlobal.length === 0 ? (
        <CinemaHomeSkeleton isDesktop={isDesktop} viewportHeight={viewportHeight} viewportWidth={viewportWidth} />
      ) : (
        <NetflixBillboard
          items={trendingGlobal.slice(0, 5)}
          isDesktop={isDesktop}
          viewportHeight={viewportHeight}
          rankOf={rankOf}
          resumeOf={(m) => {
            const saved = watchingList.find((w) => catalogKeyOf(w) === catalogKeyOf(m));
            return saved?.currentTimestamp && saved.currentTimestamp > 0 ? saved.currentTimestamp : null;
          }}
          inListOf={isInList}
          onToggleList={onToggleList}
          onPlay={onPlay}
          onInfo={onTapItem}
        />
      )}

      {watchingList.length > 0 && (
        <NetflixRow
          title="Continue Watching"
          reason="Pick up where you left off"
          items={watchingList.slice(0, 10)}
          {...rowProps}
          onTapItem={onTapContinue}
          onOptionsItem={onContinueOptions}
          progressLabel={remainingLabelOf}
        />
      )}
      {savedList.length > 0 && (
        <NetflixRow
          title="Saved for later"
          reason="Not started yet — the rest of your list lives in My List"
          items={savedList.slice(0, 10)}
          {...rowProps}
        />
      )}

      {emptyCatalogue && (
        <div style={{ padding: 'calc(76px + env(safe-area-inset-top, 0px)) 24px 24px', textAlign: 'center' }}>
          <div style={{ ...AppTypography.outfitWhite, color: NetflixColors.textSecondary }}>The catalogue could not load.</div>
          <button
            type="button"
            className="bare-button"
            onClick={onRefresh}
            style={{
              marginTop: 10,
              padding: '8px 16px',
              borderRadius: 8,
              background: NetflixColors.surfaceElevated,
              ...AppTypography.outfitBold,
              color: NetflixColors.textPrimary,
            }}
          >
            Try again
          </button>
        </div>
      )}

      {becauseItems.length >= 4 && (
        <NetflixRow
          title={`Because you watched ${becauseOf?.title ?? ''}`}
          reason="Same mood, different story"
          items={seenRow(becauseItems)}
          {...rowProps}
        />
      )}
      <NetflixRow title="Trending Now" reason="What everyone is watching this week" items={seenRow(trendingGlobal)} {...rowProps} />
      <NetflixRow
        title={`Top 10 in ${TOP_TEN_COUNTRY_LABEL}`}
        reason="Today's most-watched"
        items={topTenToday.slice(0, 10)}
        ranked
        rankOf={rankOf}
        {...rowProps}
      />
      <NetflixRow title="Coming Soon" reason="New on Everglow Cinema" items={seenRow(newlyReleased)} {...rowProps} />
      <NetflixRow title="Popular Series" reason="Most-watched series right now" items={seenRow(popularTV)} {...rowProps} />
      {Object.entries(discoveryRows).map(([title, items]) => (
        <NetflixRow key={title} title={title} reason={DISCOVERY_SHELVES.find((d) => d.title === title)?.reason} items={seenRow(items)} {...rowProps} />
      ))}

      <div style={{ padding: 16 }}>
        <button
          type="button"
          className="bare-button"
          onClick={onExploreBrowse}
          style={{
            height: 48,
            padding: '0 16px',
            display: 'inline-flex',
            alignItems: 'center',
            gap: 8,
            ...AppTypography.outfitBold,
            color: NetflixColors.textPrimary,
          }}
        >
          <Icon name="explore" variant="outlined" size={20} color={NetflixColors.textPrimary} />
          <span>Explore more in Browse</span>
        </button>
      </div>
    </div>
  );
}
