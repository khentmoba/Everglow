import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { useSource } from '../../core/utils/liveSource';
import { catalogKeyOf, resumeSecondsOf, type MediaItem } from '../cinema/cinemaTypes';
import { isCurrentlyWatchingItem, isWatchedItem } from '../cinema/tmdbService';
import {
  AnimeXBrowsePage,
  AnimeXDmcaPage,
  AnimeXDownloadsPage,
  AnimeXHistoryPage,
  AnimeXHomePage,
  AnimeXMyListPage,
  AnimeXPlaylistsPage,
  AnimeXSchedulePage,
  AnimeXSearchPage,
  AnimeXSeasonalPage,
  type AnimeNavActions,
} from './AnimePages';
import {
  animexStoreActions,
  animexStoreSource,
  clearAnimeWatchProgress,
  loadAnimexStoreForUser,
  toggleAnimeList,
  watchAnimeWatchlist,
  type AnimexHistoryEntry,
  type AnimexPageKind,
} from './animeService';
import { AnimexStores, useAnimexStores } from './animexStores';
import { AnimeXTokens } from './animeTokens';
import { AnimeXMobileBottomNav, AnimeXTopHeader } from './AnimeUi';
import { showAnimexTrailer } from './AnimeXPlayerFrame';
import { AnimeXMotchiSidebar } from './AnimeXMotchi';
import { AnimeXWatchPage } from './AnimeXWatchPage';
import { TvMediaNavHeader } from '../../shared/widgets/shelf/TvMediaNavHeader';
import type { AIMessage } from '../ai/motchiDomain';

export function AnimePage() {
  const { width, height } = useViewport();
  const { currentUser, isCoupleUser, isCinemaOnlyUser } = useAuth();
  const navigate = useNavigate();
  const scrollerRef = useRef<HTMLDivElement | null>(null);

  const [page, setPage] = useState<AnimexPageKind>('home');
  const [watchItem, setWatchItem] = useState<{ item: MediaItem; episode?: number; focus?: 'info' } | null>(null);
  const [dmcaOpen, setDmcaOpen] = useState(false);
  const [browsePreset, setBrowsePreset] = useState<{
    sort?: string;
    status?: string;
    season?: string;
    year?: number;
    genre?: string;
  } | null>(null);
  const [motchiOpen, setMotchiOpen] = useState(false);
  const [motchiMessages, setMotchiMessages] = useState<AIMessage[]>([]);
  const [params] = useSearchParams();
  const stores = useAnimexStores();

  const userName = currentUser ?? '';
  useEffect(() => {
    loadAnimexStoreForUser(userName);
    AnimexStores.load(userName || null);
  }, [userName]);

  const store = useSource(() => animexStoreSource, [], {
    titleJapanese: false,
    hideSpoilers: true,
    autoNext: true,
    skipIntro: true,
    playlists: [],
  });

  const library = useSource(() => watchAnimeWatchlist(userName), [userName], []);

  const history: AnimexHistoryEntry[] = useMemo(() => {
    const sorted = [...library]
      .filter((it) => it.currentEpisode != null || it.currentTimestamp != null || isCurrentlyWatchingItem(it))
      .sort((a, b) => (b.progressUpdatedAt ?? b.addedAt).getTime() - (a.progressUpdatedAt ?? a.addedAt).getTime());

    const seen = new Set<string>();
    const out: AnimexHistoryEntry[] = [];
    for (const it of sorted) {
      const dedupeKey =
        it.anilistId != null && it.anilistId > 0
          ? `anilist:${it.anilistId}`
          : it.tmdbId > 0
            ? `${it.source}:${it.mediaType}:${it.tmdbId}`
            : `title:${it.title.trim().toLowerCase()}`;
      if (seen.has(dedupeKey)) continue;
      seen.add(dedupeKey);

      const isMovie = it.mediaType.trim().toLowerCase() !== 'tv' || it.format.trim().toLowerCase() === 'movie';
      const totalEpisodes = isMovie ? 1 : (it.episodeCount ?? 0);
      const episode = it.currentEpisode ?? 1;
      const dur = it.durationSeconds ?? 0;
      const pos = it.currentTimestamp ?? 0;
      const progress =
        dur > 0 && pos > 0
          ? Math.min(1, pos / dur)
          : totalEpisodes > 1 && episode > 0
            ? Math.min(1, Math.max(0, (episode - 1) / totalEpisodes))
            : undefined;
      out.push({
        key: catalogKeyOf(it),
        tmdbId: it.tmdbId,
        anilistId: it.anilistId,
        title: it.title,
        posterUrl: it.posterPath || it.backdropPath,
        episode,
        totalEpisodes,
        audio: 'sub',
        progress,
        resumeSeconds: resumeSecondsOf(it) ?? undefined,
        isMovie,
        updatedAt: it.progressUpdatedAt ?? it.addedAt,
        savedItem: it,
      });
    }
    return out;
  }, [library]);

  const continueWatching = useMemo(
    () =>
      history.filter((entry) => {
        const saved = entry.savedItem;
        if (!saved) return false;
        return !isWatchedItem(saved) && isCurrentlyWatchingItem(saved);
      }),
    [history],
  );

  const savedAnime = (item: MediaItem): MediaItem | undefined => {
    for (const saved of library) {
      if (item.anilistId != null && saved.anilistId != null) {
        if (item.anilistId === saved.anilistId) return saved;
      } else if (item.source === saved.source && item.tmdbId > 0 && item.tmdbId === saved.tmdbId) {
        return saved;
      }
    }
    return undefined;
  };

  const initialKey = ['id', 'anilistId', 'malId', 'tmdbId', 'ep'].map((k) => params.get(k) ?? '').join('|');
  useEffect(() => {
    const int = (k: string) => {
      const v = params.get(k);
      if (v == null || !/^[-+]?\d+$/.test(v.trim())) return undefined;
      return Number.parseInt(v, 10);
    };
    const anilistId = int('id') ?? int('anilistId');
    const malId = int('malId');
    const tmdbId = int('tmdbId');
    const type = params.get('type') ?? undefined;
    const format = params.get('format') ?? undefined;
    const source = params.get('source') ?? (tmdbId != null && tmdbId > 0 && (malId == null || malId <= 0) ? 'tmdb' : 'jikan');
    const isMovie = type?.toLowerCase() === 'movie' || format?.toUpperCase() === 'MOVIE';
    const resolvedTmdbId = source === 'tmdb' ? (tmdbId ?? 0) : (malId ?? tmdbId ?? 0);
    if (anilistId == null && resolvedTmdbId <= 0) return;
    openWatch(
      {
        id: '',
        tmdbId: resolvedTmdbId,
        title: params.get('title') ?? '',
        mediaType: isMovie ? 'movie' : (type ?? 'tv'),
        posterPath: params.get('poster') ?? '',
        backdropPath: '',
        year: '',
        status: '',
        isAnime: true,
        userName: '',
        addedAt: new Date(),
        source,
        anilistId,
        synopsis: '',
        airingStatus: '',
        format: format ?? (isMovie ? 'MOVIE' : 'TV'),
        studio: '',
        genres: [],
        remindMe: false,
      },
      int('ep'),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initialKey]);

  const goTo = (next: AnimexPageKind) => {
    setPage(next);
    setWatchItem(null);
    setMotchiOpen(false);
    setDmcaOpen(false);
    scrollerRef.current?.scrollTo({ top: 0 });
  };

  const openWatch = (item: MediaItem, episode?: number, focus?: 'info') => {
    setWatchItem({ item, episode, focus });
    setMotchiMessages([]);
    setDmcaOpen(false);
    setMotchiOpen(false);
    scrollerRef.current?.scrollTo({ top: 0 });
  };

  const navActions: AnimeNavActions = {
    width,
    height,
    userName,
    titleJapanese: stores.titleJapanese,
    library,
    history,
    continueWatching,
    playlists: store.playlists,
    onWatch: openWatch,
    onInfo: (item) => openWatch(item, undefined, 'info'),
    onTrailer: (it) =>
      void showAnimexTrailer({ youtubeId: it.trailerYoutubeId, anilistId: it.anilistId, malId: it.tmdbId, title: it.title }),
    onNavigate: goTo,
    onPresetBrowse: (preset) => {
      setBrowsePreset(preset);
      goTo('browse');
    },
    onToggleLibrary: (item, add) => void toggleAnimeList(item, userName, add),
    onClearHistory: async (entries) => {
      for (const e of entries) {
        if (e.savedItem) await clearAnimeWatchProgress(e.savedItem, userName);
      }
    },
    onOpenDmca: () => {
      setDmcaOpen(true);
      setWatchItem(null);
      scrollerRef.current?.scrollTo({ top: 0 });
    },
    onOpenSearch: () => goTo('search'),
  };

  const isDesktop = width >= AnimeXTokens.desktopNavBreakpoint;
  const hasDetail = Boolean(watchItem || dmcaOpen);

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        background: AnimeXTokens.bg,
        color: AnimeXTokens.textPrimary,
      }}
    >
      <TvMediaNavHeader currentRoute="/anime" />
      {/* A watch screen owns the whole frame: two header bars meant two back
          buttons and 70px of the player's height. */}
      {!(watchItem && width < 600) && (
      <AnimeXTopHeader
        page={page}
        hasDetail={hasDetail}
        isDesktop={isDesktop}
        width={width}
        isCoupleUser={isCoupleUser}
        isCinemaOnlyUser={isCinemaOnlyUser}
        userName={userName}
        titleJapanese={stores.titleJapanese}
        onToggleJapanese={(jp) => {
          AnimexStores.setTitleJapanese(jp);
          animexStoreActions.setTitleJapanese(jp);
        }}
        onMotchiToggle={isCoupleUser && watchItem ? () => setMotchiOpen((o) => !o) : undefined}
        isMotchiOpen={motchiOpen}
        onGoBack={() => navigate(isCoupleUser ? '/dashboard' : '/cinema')}
        onNavigate={goTo}
        onSearch={() => goTo('search')}
      />
      )}

      <div style={{ flex: 1, minHeight: 0, position: 'relative' }}>
        <div
          ref={scrollerRef}
          style={{ position: 'absolute', inset: 0, overflowY: 'auto', visibility: hasDetail ? 'hidden' : undefined }}
        >
          {page === 'home' ? (
            <AnimeXHomePage nav={navActions} />
          ) : page === 'browse' ? (
            <AnimeXBrowsePage nav={navActions} initialPreset={browsePreset} />
          ) : page === 'schedule' ? (
            <AnimeXSchedulePage nav={navActions} />
          ) : page === 'search' ? (
            <AnimeXSearchPage nav={navActions} />
          ) : page === 'history' ? (
            <AnimeXHistoryPage nav={navActions} />
          ) : page === 'myList' ? (
            <AnimeXMyListPage nav={navActions} />
          ) : page === 'playlists' ? (
            <AnimeXPlaylistsPage nav={navActions} />
          ) : page === 'seasonal' ? (
            <AnimeXSeasonalPage nav={navActions} />
          ) : (
            <AnimeXDownloadsPage nav={navActions} />
          )}
        </div>
        {hasDetail && (
          <div style={{ position: 'absolute', inset: 0, background: AnimeXTokens.bg }}>
            {watchItem ? (
              <AnimeXWatchPage
                key={`watch-${watchItem.item.anilistId ?? watchItem.item.tmdbId}`}
                controller={{
                  watchItem: watchItem.item,
                  watchEpisode: watchItem.episode,
                  focus: watchItem.focus,
                  closeDetail: () => {
                    setWatchItem(null);
                    setDmcaOpen(false);
                    setMotchiOpen(false);
                  },
                  openWatch,
                  savedAnime,
                  goHome: () => goTo('home'),
                  openDmca: navActions.onOpenDmca,
                  onMotchi: isCoupleUser ? () => setMotchiOpen(true) : undefined,
                }}
              />
            ) : (
              <div style={{ height: '100%', overflowY: 'auto' }}>
                <AnimeXDmcaPage onBack={() => setDmcaOpen(false)} />
              </div>
            )}
          </div>
        )}
        {isCoupleUser && watchItem && (
          <AnimeXMotchiSidebar
            isOpen={motchiOpen}
            onClose={() => setMotchiOpen(false)}
            watchItem={watchItem.item}
            watchEpisode={watchItem.episode}
            messages={motchiMessages}
            onAddMessage={(m) => setMotchiMessages((prev) => [...prev, m])}
            onClear={() => setMotchiMessages([])}
          />
        )}
      </div>

      {!isDesktop && !hasDetail && (
        <AnimeXMobileBottomNav page={page} hasDetail={hasDetail} onNavigate={goTo} onSearch={() => goTo('search')} />
      )}
    </div>
  );
}
