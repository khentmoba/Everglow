import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
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
  AnimeXWatchPage,
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
import { AnimeXTokens, dmSansStyle } from './animeTokens';
import { AnimeXMobileBottomNav, AnimeXSecondaryButton, AnimeXTopHeader } from './AnimeUi';

export function AnimePage() {
  const { width, height } = useViewport();
  const { currentUser, isCoupleUser, isCinemaOnlyUser } = useAuth();
  const navigate = useNavigate();
  const scrollerRef = useRef<HTMLDivElement | null>(null);

  const [page, setPage] = useState<AnimexPageKind>('home');
  const [watchItem, setWatchItem] = useState<{ item: MediaItem; episode?: number } | null>(null);
  const [dmcaOpen, setDmcaOpen] = useState(false);
  const [browsePreset, setBrowsePreset] = useState<{ sort?: string; status?: string; season?: string; year?: number; genre?: string } | null>(null);
  const [trailerItem, setTrailerItem] = useState<MediaItem | null>(null);

  const userName = currentUser ?? '';
  useEffect(() => {
    loadAnimexStoreForUser(userName);
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
      .filter((it) => it.currentEpisode != null || it.currentTimestamp != null || it.status === 'watching-self' || it.status === 'watching-together')
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

  const goTo = (next: AnimexPageKind) => {
    setPage(next);
    setWatchItem(null);
    setDmcaOpen(false);
    scrollerRef.current?.scrollTo({ top: 0 });
  };

  const openWatch = (item: MediaItem, episode?: number) => {
    setWatchItem({ item, episode });
    setDmcaOpen(false);
    scrollerRef.current?.scrollTo({ top: 0 });
  };

  const navActions: AnimeNavActions = {
    width,
    height,
    userName,
    titleJapanese: store.titleJapanese,
    library,
    history,
    playlists: store.playlists,
    onWatch: openWatch,
    onTrailer: (it) => setTrailerItem(it),
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
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: AnimeXTokens.bg, color: AnimeXTokens.textPrimary }}>
      <AnimeXTopHeader
        page={page}
        hasDetail={hasDetail}
        isDesktop={isDesktop}
        width={width}
        isCoupleUser={isCoupleUser}
        isCinemaOnlyUser={isCinemaOnlyUser}
        userName={userName}
        titleJapanese={store.titleJapanese}
        onToggleJapanese={(jp) => animexStoreActions.setTitleJapanese(jp)}
        onGoBack={() => navigate(isCoupleUser ? '/dashboard' : '/cinema')}
        onNavigate={goTo}
        onSearch={() => goTo('search')}
      />

      <div
        ref={scrollerRef}
        style={{
          flex: 1,
          minHeight: 0,
          overflowY: 'auto',
        }}
      >
        {dmcaOpen ? (
          <AnimeXDmcaPage onBack={() => setDmcaOpen(false)} />
        ) : watchItem ? (
          <AnimeXWatchPage
            item={watchItem.item}
            initialEpisode={watchItem.episode}
            nav={navActions}
            onBack={() => setWatchItem(null)}
            onSelectItem={(it) => openWatch(it)}
          />
        ) : page === 'home' ? (
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

      {!isDesktop && (
        <AnimeXMobileBottomNav
          page={page}
          hasDetail={hasDetail}
          onNavigate={goTo}
          onSearch={() => goTo('search')}
        />
      )}

      {trailerItem && (
        <div
          onClick={() => setTrailerItem(null)}
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.84)', zIndex: 90, display: 'grid', placeItems: 'center', padding: 20 }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{ width: '100%', maxWidth: 820, background: AnimeXTokens.surfaceRaised, borderRadius: 16, overflow: 'hidden', border: `1px solid ${AnimeXTokens.glassBorder}` }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 16px' }}>
              <span style={dmSansStyle({ size: 15, weight: 700 })}>{trailerItem.title} — Trailer</span>
              <AnimeXSecondaryButton label="Close" onClick={() => setTrailerItem(null)} />
            </div>
            <div style={{ aspectRatio: '16 / 9', background: '#000' }}>
              {trailerItem.trailerYoutubeId ? (
                <iframe
                  src={`https://www.youtube.com/embed/${trailerItem.trailerYoutubeId}?autoplay=1`}
                  title={`${trailerItem.title} Trailer`}
                  allow="autoplay; fullscreen; encrypted-media"
                  allowFullScreen
                  style={{ width: '100%', height: '100%', border: 'none' }}
                />
              ) : (
                <div style={{ height: '100%', display: 'grid', placeItems: 'center', color: AnimeXTokens.textSecondary }}>
                  No trailer available
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
