import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { useSource } from '../../core/utils/liveSource';
import { catalogKeyOf, type MediaItem } from '../cinema/cinemaTypes';
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
import { AnimeXMotchiFloatingTrigger, AnimeXMotchiSidebar } from './AnimeXMotchi';
import { AnimeXWatchPage } from './AnimeXWatchPage';
import type { AIMessage } from '../ai/motchiDomain';

export function AnimePage() {
  const { width, height } = useViewport();
  const { currentUser, isCoupleUser, isCinemaOnlyUser } = useAuth();
  const navigate = useNavigate();
  const scrollerRef = useRef<HTMLDivElement | null>(null);

  const [page, setPage] = useState<AnimexPageKind>('home');
  const [watchItem, setWatchItem] = useState<{ item: MediaItem; episode?: number } | null>(null);
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
    return library
      .filter(
        (it) =>
          it.currentEpisode != null ||
          it.currentTimestamp != null ||
          it.status === 'watching-self' ||
          it.status === 'watching-together',
      )
      .map((it) => {
        const dur = it.durationSeconds ?? 0;
        const pos = it.currentTimestamp ?? 0;
        const progress = dur > 0 && pos > 0 ? Math.min(1, pos / dur) : undefined;
        return {
          key: catalogKeyOf(it),
          tmdbId: it.tmdbId,
          anilistId: it.anilistId,
          title: it.title,
          posterUrl: it.posterPath || it.backdropPath,
          episode: it.currentEpisode ?? 1,
          audio: 'sub' as const,
          progress,
          updatedAt: it.progressUpdatedAt ?? it.addedAt,
          savedItem: it,
        };
      })
      .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
  }, [library]);

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

  const openWatch = (item: MediaItem, episode?: number) => {
    setWatchItem({ item, episode });
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
    playlists: store.playlists,
    onWatch: openWatch,
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
                  closeDetail: () => {
                    setWatchItem(null);
                    setDmcaOpen(false);
                    setMotchiOpen(false);
                  },
                  openWatch,
                  savedAnime,
                  goHome: () => goTo('home'),
                  openDmca: navActions.onOpenDmca,
                }}
              />
            ) : (
              <div style={{ height: '100%', overflowY: 'auto' }}>
                <AnimeXDmcaPage onBack={() => setDmcaOpen(false)} />
              </div>
            )}
          </div>
        )}
        {isCoupleUser && watchItem && !motchiOpen && (
          <div style={{ position: 'absolute', bottom: 20, right: 18 }}>
            <AnimeXMotchiFloatingTrigger onTap={() => setMotchiOpen(true)} />
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
