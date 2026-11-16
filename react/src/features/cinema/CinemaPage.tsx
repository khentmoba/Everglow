// Port of lib/features/cinema/presentation/screens/cinema_screen.dart and tabs/*.dart.
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { AgentMode } from '../../core/agent/agentMode';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppBreakpoint } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import {
  BROWSE_GROUP_META,
  CINEMA_BROWSE_OPTIONS,
  type BrowseCategoryGroup,
  type BrowseCategoryOption,
} from './cinemaBrowseConfig';
import { NetflixColors, TOP_TEN_COUNTRY_LABEL, catalogKeyOf, resumeSecondsOf, type MediaItem } from './cinemaTypes';
import {
  EpisodeDrawerModal,
  MediaSectionMenuButton,
  NetflixBillboard,
  NetflixBottomNav,
  NetflixCinemaTopBar,
  NetflixPosterCard,
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
  searchMulti,
  setListMembership,
  watchCinemaWatchlist,
} from './tmdbService';

interface DiscoveryShelf {
  title: string;
  type: 'movie' | 'tv';
  genre?: number;
  language?: string;
}

const DISCOVERY_SHELVES: DiscoveryShelf[] = [
  { title: 'Top-Rated Movies', type: 'movie' },
  { title: 'Top-Rated Series', type: 'tv' },
  { title: 'Action & Adventure', type: 'movie', genre: 28 },
  { title: 'Need a Laugh?', type: 'movie', genre: 35 },
  { title: 'Romance', type: 'movie', genre: 10749 },
  { title: 'Edge-of-Your-Seat Thrillers', type: 'movie', genre: 53 },
  { title: 'Sci-Fi Escapes', type: 'movie', genre: 878 },
  { title: 'Korean Dramas', type: 'tv', genre: 18, language: 'ko' },
];

export function CinemaPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const { width, height } = useViewport();

  const initialBrowse = params.get('browse');
  const initialTab = initialBrowse ? 2 : Math.max(0, Math.min(5, Number(params.get('tab') ?? 0) || 0));

  const [currentTab, setCurrentTab] = useState(initialTab);
  const [selectedBrowseId, setSelectedBrowseId] = useState<string | null>(initialBrowse);
  const [scrolled, setScrolled] = useState(false);

  const userName = auth.currentUser ?? '';
  const isCoupleUser = auth.isCoupleUser && !AgentMode.isActive.value ? true : auth.isCoupleUser;
  const isCinemaOnlyUser = auth.isCinemaOnlyUser;
  const isDesktop = width >= AppBreakpoint.tablet;

  const watchlist = useSource(() => watchCinemaWatchlist(userName), [userName], []);
  const watchingList = useMemo(
    () =>
      watchlist
        .filter((m) => !m.isAnime && m.status.toLowerCase().includes('watching'))
        .sort((a, b) => (b.progressUpdatedAt ?? b.addedAt).getTime() - (a.progressUpdatedAt ?? a.addedAt).getTime()),
    [watchlist],
  );
  const savedList = useMemo(
    () => watchlist.filter((m) => !m.isAnime && m.status.toLowerCase() === 'to-watch'),
    [watchlist],
  );

  const [isLoadingHome, setIsLoadingHome] = useState(true);
  const [trendingGlobal, setTrendingGlobal] = useState<MediaItem[]>([]);
  const [topTenToday, setTopTenToday] = useState<MediaItem[]>([]);
  const [popularTV, setPopularTV] = useState<MediaItem[]>([]);
  const [newlyReleased, setNewlyReleased] = useState<MediaItem[]>([]);
  const [discoveryRows, setDiscoveryRows] = useState<Record<string, MediaItem[]>>({});
  const [drawerItem, setDrawerItem] = useState<MediaItem | null>(null);

  const loadHome = useCallback(async () => {
    setIsLoadingHome(true);
    const year = new Date().getFullYear();
    const [tGlobal, tPh, tvPop, upc] = await Promise.all([
      fetchTrending('all', 'week'),
      fetchTrendingByCountry('PH'),
      fetchPopularTVShows(),
      fetchUpcoming('PH'),
    ]);
    setTrendingGlobal(tGlobal.filter((m) => !m.isAnime));
    setTopTenToday(tPh.filter((m) => !m.isAnime));
    setPopularTV(tvPop.filter((m) => !m.isAnime));
    setNewlyReleased(
      upc.filter((m) => !m.isAnime && (!m.year || Number(m.year) >= year - 1)),
    );
    setIsLoadingHome(false);

    const disc = await Promise.all(
      DISCOVERY_SHELVES.map(async (shelf) => {
        const res = await discoverMedia({
          mediaType: shelf.type,
          sortBy: shelf.genre == null ? 'vote_average.desc' : 'popularity.desc',
          withGenres: shelf.genre == null ? undefined : [shelf.genre],
          withOriginalLanguage: shelf.language,
          voteCountGte: shelf.genre == null ? 1000 : 100,
        });
        return [shelf.title, res.results.filter((m) => !m.isAnime)] as const;
      }),
    );
    const map: Record<string, MediaItem[]> = {};
    for (const [k, v] of disc) map[k] = v;
    setDiscoveryRows(map);
  }, []);

  useEffect(() => {
    void loadHome();
  }, [loadHome]);

  const handleNavSelect = (tab: number, browseOptionId?: string) => {
    if (browseOptionId) setSelectedBrowseId(browseOptionId);
    setCurrentTab(tab);
  };

  const launchPlayer = (item: MediaItem, season?: number, episode?: number) => {
    const resume = resumeSecondsOf(item);
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

  const watchlistKeys = useMemo(() => new Set(watchlist.map((w) => catalogKeyOf(w))), [watchlist]);

  const handleToggleList = async (item: MediaItem, add: boolean) => {
    if (!userName) return;
    try {
      await setListMembership(item, userName, add);
    } catch {
      showSnackBar(`Could not update "${item.title}" in your list.`);
    }
  };

  const handleLogout = async () => {
    await auth.logout();
    navigate('/');
  };

  const links = cinemaNavLinks(isCinemaOnlyUser);

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
      {isDesktop && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, zIndex: 20 }}>
          <NetflixCinemaTopBar
            currentIndex={currentTab}
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

      {!isDesktop && (
        <>
          <div style={{ position: 'fixed', top: 10, left: 12, zIndex: 25 }}>
            <button
              type="button"
              className="bare-button"
              aria-label={isCoupleUser ? 'Dashboard' : 'Logout'}
              onClick={isCoupleUser ? () => navigate('/dashboard') : () => void handleLogout()}
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
            <div style={{ position: 'fixed', top: 10, right: 12, zIndex: 25 }}>
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
            onPlay={(item) => launchPlayer(item)}
            onExploreBrowse={() => setCurrentTab(2)}
          />
        )}
        {currentTab === 1 && (
          <SearchTab
            isDesktop={isDesktop}
            width={width}
            trendingGlobal={trendingGlobal}
            onTapItem={setDrawerItem}
          />
        )}
        {currentTab === 2 && (
          <BrowseTab
            isDesktop={isDesktop}
            width={width}
            selectedId={selectedBrowseId}
            onSelectId={setSelectedBrowseId}
            onTapItem={setDrawerItem}
          />
        )}
        {currentTab === 3 && (
          <LibraryTab
            isDesktop={isDesktop}
            width={width}
            watchlist={watchlist.filter((m) => !m.isAnime)}
            onTapItem={setDrawerItem}
            onRemoveProgress={(item) => void clearWatchProgress(item, userName)}
          />
        )}
        {currentTab === 4 && (
          <div style={{ padding: isDesktop ? '90px 48px' : '84px 16px', textAlign: 'center' }}>
            <Icon name="favorite" size={44} color={AppColors.deepRose} />
            <div style={{ height: 12 }} />
            <div style={{ ...AppTypography.cormorantBold, fontSize: 28, color: '#FFFFFF' }}>Watch Together</div>
            <div style={{ height: 8 }} />
            <div style={{ ...AppTypography.outfitMedium, color: NetflixColors.textSecondary, fontSize: 13.5 }}>
              Open the synchronized Watch Party room to press play together.
            </div>
            <div style={{ height: 18 }} />
            <button
              type="button"
              className="bare-button"
              onClick={() => navigate('/watch-party')}
              style={{
                padding: '12px 24px',
                borderRadius: 999,
                background: AppColors.deepRose,
                ...AppTypography.outfitBold,
                color: '#FFFFFF',
              }}
            >
              Open Watch Party Room
            </button>
          </div>
        )}
        {currentTab === 5 && (
          <div style={{ padding: isDesktop ? '90px 48px' : '84px 16px', textAlign: 'center' }}>
            <Icon name="download_for_offline" size={44} color={NetflixColors.textSecondary} />
            <div style={{ height: 12 }} />
            <div style={{ ...AppTypography.outfitHeading, fontSize: 18, color: '#FFFFFF' }}>No Offline Downloads</div>
            <div style={{ height: 6 }} />
            <div style={{ ...AppTypography.outfitMedium, fontSize: 13, color: NetflixColors.textMuted }}>
              Offline file downloads are only cached locally in supported browsers.
            </div>
          </div>
        )}
        <div style={{ height: 100 }} />
      </div>

      {!isDesktop && (
        <NetflixBottomNav
          currentIndex={currentTab}
          items={cinemaMobileNavItems(isCinemaOnlyUser)}
          onSelect={handleNavSelect}
          onAnimeTap={() => navigate('/anime')}
        />
      )}

      {drawerItem && (
        <EpisodeDrawerModal
          item={drawerItem}
          inList={watchlistKeys.has(catalogKeyOf(drawerItem))}
          onClose={() => setDrawerItem(null)}
          onPlay={(it, s, e) => {
            setDrawerItem(null);
            launchPlayer(it, s, e);
          }}
          onToggleList={(it, add) => void handleToggleList(it, add)}
          onSelectItem={setDrawerItem}
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
  onPlay,
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
  onPlay: (m: MediaItem) => void;
  onExploreBrowse: () => void;
}) {
  const emptyCatalogue =
    !isLoading &&
    trendingGlobal.length === 0 &&
    topTenToday.length === 0 &&
    newlyReleased.length === 0 &&
    popularTV.length === 0;

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
          onPlay={onPlay}
          onInfo={onTapItem}
        />
      )}

      {watchingList.length > 0 && (
        <NetflixRow title="Continue Watching" items={watchingList.slice(0, 10)} isDesktop={isDesktop} onTapItem={onTapItem} />
      )}
      {savedList.length > 0 && (
        <NetflixRow title="Your picks" items={savedList.slice(0, 10)} isDesktop={isDesktop} onTapItem={onTapItem} />
      )}

      {emptyCatalogue && (
        <div style={{ padding: 24, textAlign: 'center' }}>
          <div style={{ ...AppTypography.outfitWhite, color: NetflixColors.textSecondary }}>
            The catalogue could not load.
          </div>
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
              color: '#FFFFFF',
            }}
          >
            Try again
          </button>
        </div>
      )}

      <NetflixRow title="Trending Now" items={trendingGlobal} isDesktop={isDesktop} onTapItem={onTapItem} />
      <NetflixRow title={`Top 10 in ${TOP_TEN_COUNTRY_LABEL}`} items={topTenToday.slice(0, 10)} ranked isDesktop={isDesktop} onTapItem={onTapItem} />
      <NetflixRow title="Coming Soon" items={newlyReleased} isDesktop={isDesktop} onTapItem={onTapItem} />
      <NetflixRow title="Popular Series" items={popularTV} isDesktop={isDesktop} onTapItem={onTapItem} />
      {Object.entries(discoveryRows).map(([title, items]) => (
        <NetflixRow key={title} title={title} items={items} isDesktop={isDesktop} onTapItem={onTapItem} />
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

function SearchTab({
  isDesktop,
  width,
  trendingGlobal,
  onTapItem,
}: {
  isDesktop: boolean;
  width: number;
  trendingGlobal: MediaItem[];
  onTapItem: (m: MediaItem) => void;
}) {
  const [queryStr, setQueryStr] = useState('');
  const [results, setResults] = useState<MediaItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [typeFilter, setTypeFilter] = useState<'all' | 'movie' | 'tv'>('all');
  const hPad = isDesktop ? 48 : 16;
  const cols = isDesktop ? 6 : width >= AppBreakpoint.mobile ? 5 : 3;

  useEffect(() => {
    const q = queryStr.trim();
    if (!q) {
      setResults([]);
      return;
    }
    setLoading(true);
    const timer = window.setTimeout(() => {
      void searchMulti(q).then((r) => {
        setResults(r.results);
        setLoading(false);
      });
    }, 300);
    return () => clearTimeout(timer);
  }, [queryStr]);

  const list = (queryStr.trim() ? results : trendingGlobal).filter((m) =>
    typeFilter === 'all' ? true : m.mediaType === typeFilter,
  );

  return (
    <div style={{ padding: `${isDesktop ? 76 : 68}px ${hPad}px 24px` }}>
      <h2 style={{ margin: '0 0 12px', ...AppTypography.outfitHeading, fontSize: isDesktop ? 22 : 20, color: '#FFFFFF' }}>
        Search
      </h2>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          background: NetflixColors.surfaceElevated,
          borderRadius: 8,
          padding: '0 14px',
          height: 46,
        }}
      >
        <Icon name="search" size={20} color={NetflixColors.textMuted} />
        <input
          value={queryStr}
          onChange={(e) => setQueryStr(e.target.value)}
          placeholder="Search movies & TV shows…"
          style={{
            flex: 1,
            background: 'transparent',
            border: 'none',
            outline: 'none',
            color: '#FFFFFF',
            ...AppTypography.outfitMedium,
            fontSize: 14,
          }}
        />
        {queryStr && (
          <button type="button" className="bare-button" onClick={() => setQueryStr('')}>
            <Icon name="close" size={18} color={NetflixColors.textMuted} />
          </button>
        )}
      </div>

      <div style={{ display: 'flex', gap: 8, padding: '12px 0' }}>
        {(['all', 'movie', 'tv'] as const).map((t) => (
          <button
            key={t}
            type="button"
            className="bare-button"
            onClick={() => setTypeFilter(t)}
            style={{
              padding: '6px 12px',
              borderRadius: 999,
              background: typeFilter === t ? NetflixColors.accent : NetflixColors.surfaceElevated,
              ...AppTypography.outfitBold,
              fontSize: 12,
              color: '#FFFFFF',
            }}
          >
            {t === 'all' ? 'All' : t === 'movie' ? 'Movies' : 'TV Shows'}
          </button>
        ))}
      </div>

      {loading ? (
        <div style={{ padding: 36, display: 'flex', justifyContent: 'center' }}>
          <CircularProgress size={26} strokeWidth={2.5} color={NetflixColors.accent} />
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: 10 }}>
          {list.map((m) => (
            <NetflixPosterCard key={`${m.mediaType}:${m.tmdbId}`} item={m} compact onTap={() => onTapItem(m)} />
          ))}
        </div>
      )}
    </div>
  );
}

function BrowseTab({
  isDesktop,
  width,
  selectedId,
  onSelectId,
  onTapItem,
}: {
  isDesktop: boolean;
  width: number;
  selectedId: string | null;
  onSelectId: (id: string) => void;
  onTapItem: (m: MediaItem) => void;
}) {
  const [results, setResults] = useState<MediaItem[]>([]);
  const [loading, setLoading] = useState(false);
  const hPad = isDesktop ? 48 : 16;
  const cols = isDesktop ? 6 : width >= AppBreakpoint.mobile ? 5 : 3;

  const runBrowse = useCallback(async (opt: BrowseCategoryOption) => {
    setLoading(true);
    const res = await discoverMedia({
      mediaType: opt.mediaType,
      sortBy: opt.sortBy ?? 'popularity.desc',
      withGenres: opt.genreId != null ? [opt.genreId] : undefined,
      withoutGenres: opt.withoutGenres,
      withOriginalLanguage: opt.withOriginalLanguage,
      yearGte: opt.yearGte,
      yearLte: opt.yearLte,
      voteAverageGte: opt.voteAverageGte,
      voteCountGte: opt.voteCountGte,
    });
    setResults(res.results.filter((m) => !m.isAnime));
    setLoading(false);
  }, []);

  useEffect(() => {
    const id = selectedId ?? 'collection-movies';
    const opt = CINEMA_BROWSE_OPTIONS.find((o) => o.id === id) ?? CINEMA_BROWSE_OPTIONS[0];
    void runBrowse(opt);
  }, [selectedId, runBrowse]);

  const groups: BrowseCategoryGroup[] = ['collection', 'genre', 'decade', 'language', 'sort'];

  return (
    <div style={{ paddingTop: isDesktop ? 76 : 68 }}>
      <div style={{ padding: `0 ${hPad}px 4px` }}>
        <h2 style={{ margin: 0, ...AppTypography.outfitHeading, fontSize: isDesktop ? 22 : 20, color: '#FFFFFF' }}>
          Browse
        </h2>
      </div>
      {groups.map((g) => {
        const opts = CINEMA_BROWSE_OPTIONS.filter((o) => o.group === g);
        return (
          <div key={g} style={{ padding: '14px 0 6px' }}>
            <div style={{ padding: `0 ${hPad}px 10px`, ...AppTypography.outfitHeading, fontSize: isDesktop ? 16 : 15, color: NetflixColors.textSecondary }}>
              {BROWSE_GROUP_META[g].title}
            </div>
            <div className="no-scrollbar" style={{ display: 'flex', gap: 8, padding: `0 ${hPad}px`, overflowX: 'auto' }}>
              {opts.map((opt) => {
                const selected = (selectedId ?? 'collection-movies') === opt.id;
                return (
                  <button
                    key={opt.id}
                    type="button"
                    className="bare-button"
                    onClick={() => onSelectId(opt.id)}
                    style={{
                      height: 38,
                      padding: '0 14px',
                      borderRadius: 999,
                      background: selected ? NetflixColors.accent : NetflixColors.surfaceElevated,
                      border: `1px solid ${selected ? NetflixColors.accent : NetflixColors.hairline}`,
                      ...AppTypography.outfitBold,
                      fontSize: 12.5,
                      color: '#FFFFFF',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {opt.label}
                  </button>
                );
              })}
            </div>
          </div>
        );
      })}
      <div style={{ padding: `18px ${hPad}px 12px`, ...AppTypography.outfitWhite, fontSize: 13, color: NetflixColors.textMuted }}>
        {loading ? 'Loading titles…' : `${results.length} titles`}
      </div>
      {loading ? (
        <div style={{ padding: 36, display: 'flex', justifyContent: 'center' }}>
          <CircularProgress size={26} strokeWidth={2.5} color={NetflixColors.accent} />
        </div>
      ) : (
        <div style={{ padding: `0 ${hPad}px`, display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: 10 }}>
          {results.map((item) => (
            <NetflixPosterCard key={`${item.mediaType}:${item.tmdbId}`} item={item} compact onTap={() => onTapItem(item)} />
          ))}
        </div>
      )}
    </div>
  );
}

function LibraryTab({
  isDesktop,
  width,
  watchlist,
  onTapItem,
  onRemoveProgress,
}: {
  isDesktop: boolean;
  width: number;
  watchlist: MediaItem[];
  onTapItem: (m: MediaItem) => void;
  onRemoveProgress: (m: MediaItem) => void;
}) {
  const [filter, setFilter] = useState<'all' | 'watching' | 'toWatch' | 'watched'>('all');
  const hPad = isDesktop ? 48 : 16;
  const cols = isDesktop ? 6 : width >= AppBreakpoint.mobile ? 5 : 3;

  const visible = watchlist.filter((m) => {
    const s = m.status.toLowerCase();
    if (filter === 'watching') return s.includes('watching');
    if (filter === 'toWatch') return s === 'to-watch';
    if (filter === 'watched') return s.includes('watched');
    return true;
  });

  return (
    <div style={{ padding: `${isDesktop ? 76 : 68}px ${hPad}px 24px` }}>
      <h2 style={{ margin: '0 0 12px', ...AppTypography.outfitHeading, fontSize: isDesktop ? 22 : 20, color: '#FFFFFF' }}>
        My List
      </h2>
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {([
          ['all', 'All'],
          ['watching', 'Watching'],
          ['toWatch', 'To Watch'],
          ['watched', 'Watched'],
        ] as const).map(([id, label]) => (
          <button
            key={id}
            type="button"
            className="bare-button"
            onClick={() => setFilter(id)}
            style={{
              padding: '6px 14px',
              borderRadius: 999,
              background: filter === id ? NetflixColors.accent : NetflixColors.surfaceElevated,
              ...AppTypography.outfitBold,
              fontSize: 12.5,
              color: '#FFFFFF',
            }}
          >
            {label}
          </button>
        ))}
      </div>
      {visible.length === 0 ? (
        <div style={{ padding: 48, textAlign: 'center', color: withAlpha(AppColors.petalWhite, 0.55) }}>
          No titles saved in this list yet.
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: 10 }}>
          {visible.map((m) => (
            <div key={m.id || `${m.mediaType}:${m.tmdbId}`} style={{ position: 'relative' }}>
              <NetflixPosterCard item={m} compact onTap={() => onTapItem(m)} />
              {m.status.toLowerCase().includes('watching') && (
                <button
                  type="button"
                  className="bare-button"
                  title="Remove from Continue Watching"
                  onClick={() => onRemoveProgress(m)}
                  style={{
                    position: 'absolute',
                    top: 6,
                    right: 6,
                    width: 24,
                    height: 24,
                    borderRadius: '50%',
                    background: 'rgba(0,0,0,0.75)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <Icon name="close" size={14} color="#FFFFFF" />
                </button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
