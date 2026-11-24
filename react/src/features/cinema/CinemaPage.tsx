// Port of lib/features/cinema/presentation/screens/cinema_screen.dart and tabs/*.dart.
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppBreakpoint } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
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
  { title: 'Stories That Stay With You', type: 'movie', genre: 18, reason: 'Quiet films that linger' },
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

  const handleNavSelect = useCallback(
    (tab: number, browseOptionId?: string) => {
      const clamped = Math.max(0, Math.min(5, tab));
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
    [params, setSearchParams],
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
    else if (action === 'remove') void clearWatchProgress(item, userName);
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
  // Back means back: leave a tab for Home first, then leave Cinema.
  const handleBack = () => {
    if (currentTab !== 0 || selectedBrowseId) {
      handleNavSelect(0);
      return;
    }
    if (isCoupleUser) void navigate('/dashboard');
    else void navigate('/');
  };

  // Removing progress is one tap, so it carries an Undo for the rest of the session.
  const removeProgress = (item: MediaItem) => {
    const snapshot = watchlist.find((w) => catalogKeyOf(w) === catalogKeyOf(item));
    void clearWatchProgress(item, userName);
    showSnackBar(`Removed from Continue Watching`, {
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
            aria-hidden
            style={{
              position: 'fixed',
              top: 0,
              left: 0,
              width: 260,
              height: 220,
              zIndex: 24,
              pointerEvents: 'none',
              background: 'radial-gradient(circle 140px at 34px 34px, rgba(8,8,8,0.6) 0%, rgba(8,8,8,0.3) 45%, rgba(8,8,8,0) 100%)',
            }}
          />
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
              aria-label={isCoupleUser ? 'Back' : 'Logout'}
              onClick={isCoupleUser ? handleBack : () => void handleLogout()}
              style={{
                width: 48,
                height: 48,
                borderRadius: '50%',
                background: NetflixColors.surface,
                border: `1px solid ${NetflixColors.hairline}`,
                boxShadow: '0 4px 12px rgba(0,0,0,0.45)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name={isCoupleUser ? 'arrow_back' : 'logout'} size={22} color="#FFFFFF" />
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
        className="no-scrollbar"
        onScroll={(e) => setScrolled(e.currentTarget.scrollTop > 20)}
        style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden' }}
      >
        {currentTab === 0 && (
          <HomeTab
            isDesktop={isDesktop}
            viewportHeight={height}
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
          <CinemaSearchTab width={width} height={height} trendingGlobal={trendingGlobal} onMediaTap={setDrawerItem} />
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
            onRemoveProgress={removeProgress}
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
  // One title, one rail: a poster that already appeared above stays there.
  const seen = new Set<string>();
  const seenRow = (items: MediaItem[]) =>
    items.filter((m) => {
      const key = catalogKeyOf(m);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
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
        <div
          style={{
            height: isDesktop ? 560 : Math.max(380, Math.min(540, Math.round(viewportHeight * 0.58))),
            background: NetflixColors.surface,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <CircularProgress size={28} strokeWidth={2.5} color={NetflixColors.accent} />
        </div>
      ) : (
        <NetflixBillboard
          items={trendingGlobal.slice(0, 5)}
          isDesktop={isDesktop}
          viewportHeight={viewportHeight}
          rankOf={rankOf}
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
      {savedList.length > 0 && <NetflixRow title="My List" items={savedList.slice(0, 10)} {...rowProps} />}

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
          items={becauseItems}
          {...rowProps}
        />
      )}
      <NetflixRow title="Trending Now" reason="What everyone is watching this week" items={seenRow(trendingGlobal)} {...rowProps} />
      <NetflixRow
        title={`Top 10 in ${TOP_TEN_COUNTRY_LABEL}`}
        reason="Today's most-watched"
        items={seenRow(topTenToday).slice(0, 10)}
        ranked
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
