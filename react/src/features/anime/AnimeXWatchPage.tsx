// Faithful port of animex_watch_page.dart (+ _sections, _widgets and the
// playlist / share sheets). State lives in one mutable object with a
// `setState` bump, the same shape as the Flutter State class.
import { useEffect, useReducer, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { useAuth } from '../../core/services/auth';
import { auth as firebaseAuth } from '../../core/services/firebase';
import { OfflineIds, offlineMedia } from '../../core/services/offlineMedia';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Logger } from '../../core/system/logger';
import { fetchAniZipMappings } from '../../shared/utils/catalogProxy';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { showModalBottomSheet } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import type { MediaItem } from '../cinema/cinemaTypes';
import { TmdbImages } from '../cinema/cinemaTypes';
import { PlayerMemoryService } from '../cinema/playerServices';
import { fetchMediaDetails, getSavedProgress, searchMulti, updateProgress } from '../cinema/tmdbService';
import { SheetDragHandle } from '../cinema/VideoPlayerWidgets';
import { startWatchParty } from '../watch_party/StartWatchParty';
import { useOpenWatchPartyRoom } from '../watch_party/WatchPartyPage';
import {
  fetchDetailsWithFallback,
  fetchSkipTimes,
  mapTmdbAnimeDetails,
  mediaIsMovie,
  mediaPosterUrl,
  type AniListDetail,
  type AniListEpisode,
  type AniListSeason,
  type AniSkipTimes,
  type EpisodeSlots,
} from './animexData';
import { AnimexStores, playlistItemMatches, useAnimexStores, type AnimexPlaylistItem } from './animexStores';
import {
  buildEpisodeList,
  buildServers,
  defaultServerIndex,
  isProviderErrorPage,
  mapPlayerEpisodeToMal,
  nextUp,
  normalizeServerName,
  pickTmdbFallbackId,
  resolveMappingsMalId,
  resolveProgressSeason,
  resolveResume,
  serverUrlFor,
  type AnimeServerOption,
  type VideasyProgress,
} from './animexWatchConfig';
import { AnimeXPlayerFrame, exitPlayerFullscreen, isPlayerFullscreenActive, showAnimexTrailer } from './AnimeXPlayerFrame';
import { DesktopEpisodesSidebar, MobileEpisodesSection, showEpisodeInfoSheet } from './AnimeXWatchEpisodes';
import { AgentMode } from '../../core/agent/agentMode';
import { AnimeXTokens, bebasStyle, dmSansStyle, interBodyStyle } from './animeTokens';
import { AnimeXFooter, AnimeXPosterRow, AnimeXPrimaryButton, AnimeXSectionHeader } from './AnimeUi';

const T = AnimeXTokens;
const WATCH_PAGE_MAX_WIDTH = 1400;
const PLAYER_MAX_HEIGHT = 560;
const PROBE_PROXY_URL = 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyFetchHtml';
const white = (a: number) => withAlpha('#FFFFFF', a);
const oneLine: CSSProperties = { overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' };
const ymd = (d: Date) => `${d.getFullYear()}-${`${d.getMonth() + 1}`.padStart(2, '0')}-${`${d.getDate()}`.padStart(2, '0')}`;
const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);

export interface AnimexWatchController {
  watchItem: MediaItem;
  watchEpisode?: number;
  /** Open on the about section (the hero's "More Info" button). */
  focus?: 'info';
  closeDetail: () => void;
  openWatch: (item: MediaItem, episode?: number) => void;
  savedAnime: (item: MediaItem) => MediaItem | undefined;
  goHome: () => void;
  openDmca: () => void;
  /** Couple-only companion, offered from the watch page's overflow menu. */
  onMotchi?: () => void;
}

function animeItem(fields: Partial<MediaItem> & Pick<MediaItem, 'tmdbId' | 'title' | 'mediaType' | 'posterPath'>): MediaItem {
  return {
    id: '',
    backdropPath: '',
    year: '',
    status: '',
    isAnime: true,
    userName: '',
    addedAt: new Date(),
    source: 'jikan',
    synopsis: '',
    airingStatus: '',
    format: '',
    studio: '',
    genres: [],
    remindMe: false,
    ...fields,
  };
}

const movieOrTv = (format: string) => (format.trim().toLowerCase() === 'movie' ? 'movie' : 'tv');

function seasonItem(s: AniListSeason, status = ''): MediaItem {
  return animeItem({
    tmdbId: s.malId ?? 0,
    title: s.title,
    mediaType: movieOrTv(s.format),
    posterPath: s.coverImageUrl,
    year: s.year != null && s.year > 0 ? `${s.year}` : '',
    status,
    anilistId: s.id,
    format: s.format,
    episodeCount: s.episodeCount,
  });
}

const watchingStatusFor = (u: string) =>
  u === 'khentsgdz' ? 'watching-khent' : u === 'clairjassen' ? 'watching-clair' : 'watching-self';
const watchedStatusFor = (u: string) =>
  u === 'khentsgdz' ? 'watched-khent' : u === 'clairjassen' ? 'watched-clair' : 'watched-self';

interface WatchState {
  skipTimes?: AniSkipTimes;
  startSeconds?: number;
  lastKnownPosition?: number;
  accountProgress?: MediaItem | null;
  playbackDuration?: number;
  lastWindowedMaxPlayerHeight?: number;
  ready: boolean;
  episodeChosen: boolean;
  playbackPosition?: number;
  detail?: AniListDetail | null;
  episodes: AniListEpisode[];
  selectedEpisode: number;
  playerEpisode: number;
  audio: string;
  serverIndex: number;
  progressThrottler?: number;
  hasUnsavedProgress: boolean;
  progressSave: Promise<void>;
  rememberedServer?: string;
  mappedAnilistId?: number;
  mappedTmdbId?: number;
  episodeSlots: EpisodeSlots;
  isFilm: boolean;
  servers: AnimeServerOption[];
  failedServerIndices: Set<number>;
  showErrorCard: boolean;
  probingServer: boolean;
  offlineBlobUrl?: string;
  mounted: boolean;
}

export function AnimeXWatchPage({ controller }: { controller: AnimexWatchController }) {
  const [, bump] = useReducer((x: number) => x + 1, 0);
  const stores = useAnimexStores();
  const auth = useAuth();
  const openRoom = useOpenWatchPartyRoom();
  const { width, height } = useViewport();
  const scrollRef = useRef<HTMLDivElement>(null);
  const episodesRef = useRef<HTMLDivElement>(null);
  const ctl = useRef(controller);
  ctl.current = controller;
  const owner = useRef(auth.currentUser ?? '');

  const item = useRef(controller.watchItem).current;
  const historyKey =
    item.source === 'tmdb' ? `animex-tmdb-${item.mediaType}-${item.tmdbId}` : `animex-${item.anilistId ?? item.tmdbId}`;

  const s = useRef<WatchState>(null as unknown as WatchState);
  if (s.current == null) {
    const episode = resolveResume({
      item,
      saved: controller.savedAnime(item),
      local: AnimexStores.findHistory(historyKey),
      requestedEpisode: controller.watchEpisode,
    }).episode;
    const init: WatchState = {
      ready: false,
      episodeChosen: false,
      episodes: [],
      selectedEpisode: episode,
      playerEpisode: episode,
      audio: 'sub',
      serverIndex: 0,
      hasUnsavedProgress: false,
      progressSave: Promise.resolve(),
      episodeSlots: new Map(),
      isFilm: mediaIsMovie(item),
      servers: [],
      failedServerIndices: new Set(),
      showErrorCard: false,
      probingServer: false,
      mounted: true,
    };
    s.current = init;
  }
  const st = s.current;
  const setState = (fn?: () => void) => {
    fn?.();
    if (st.mounted) bump();
  };

  // --- derived ---
  const malId = () => st.detail?.malId ?? (item.source === 'tmdb' ? 0 : item.tmdbId);
  const anilistId = item.anilistId;
  const memoryKey = () =>
    item.source === 'tmdb'
      ? PlayerMemoryService.cinemaKey({ id: item.tmdbId, mediaType: item.mediaType, isAnime: false })
      : PlayerMemoryService.animexKey({ anilistId, malId: malId() });
  const histKey = () => (item.source === 'tmdb' ? historyKey : `animex-${anilistId ?? malId()}`);
  const seasons = () => st.detail?.seasons ?? [];
  const nextSeason = (): AniListSeason | undefined => {
    const list = seasons();
    if (list.length <= 1) return undefined;
    const index = list.findIndex((x) => x.isCurrent);
    return index >= 0 && index < list.length - 1 ? list[index + 1] : undefined;
  };
  const activeEpisode = () => st.episodes.find((e) => e.number === st.selectedEpisode);
  const activeEpisodeTitle = () => {
    if (stores.hideSpoilers) return `Episode ${st.selectedEpisode}`;
    const t = activeEpisode()?.title;
    return t ? t : `Episode ${st.selectedEpisode}`;
  };
  const titleFor = (japanese: boolean) => {
    if (japanese) {
      const native = st.detail?.titleNative ?? '';
      if (native) return native;
    }
    const english = st.detail?.titleEnglish ?? '';
    return english ? english : item.title;
  };
  const displayTitle = titleFor(stores.titleJapanese);
  const currentUserName = () => (auth.currentUser === owner.current ? owner.current : '');
  const currentServer = () =>
    st.serverIndex >= 0 && st.serverIndex < st.servers.length ? st.servers[st.serverIndex] : undefined;
  const nextUpInfo = () =>
    nextUp({
      isFilm: st.isFilm,
      selectedEpisode: st.selectedEpisode,
      episodeCount: st.episodes.length,
      hasNextSeason: nextSeason() != null,
    });

  const playerUrl = () => {
    if (st.offlineBlobUrl) return st.offlineBlobUrl;
    if (!st.ready || !st.servers.length) return '';
    let current: AnimeServerOption | undefined;
    if (st.serverIndex >= 0 && st.serverIndex < st.servers.length && st.servers[st.serverIndex]!.available) {
      current = st.servers[st.serverIndex];
    } else {
      current = st.servers.find((x) => x.available);
    }
    if (!current) return '';
    return serverUrlFor(current, st.playerEpisode, st.audio, st.startSeconds);
  };

  const filmFor = (detail?: AniListDetail | null) => {
    if (mediaIsMovie(item)) return true;
    if (!detail) return false;
    if (detail.format === 'MOVIE') return true;
    const eps = detail.episodeCount ?? item.episodeCount ?? 0;
    return eps === 1 && (detail.duration ?? 0) >= 60;
  };

  const makeServers = (o: { mappedAnilistId?: number; mappedMalId?: number } = {}) =>
    buildServers({
      anilistId: anilistId ?? o.mappedAnilistId ?? st.mappedAnilistId,
      malId: o.mappedMalId ?? malId(),
      tmdbId: st.mappedTmdbId,
      episodeSlots: st.episodeSlots,
      isMovie: st.isFilm,
    });

  const makeEpisodes = (detail?: AniListDetail | null, aniZipEpisodes?: Map<number, Record<string, unknown>>) =>
    buildEpisodeList({ detail, fallbackEpisodeCount: item.episodeCount, aniZipEpisodes });

  // --- actions ---
  const checkOfflinePlayback = async () => {
    const animeId = item.anilistId ?? item.tmdbId;
    offlineMedia.init();
    let offlineItem = offlineMedia.getItem(OfflineIds.animeEpisodeId(animeId, st.playerEpisode));
    if (!offlineItem && item.tmdbId > 0)
      offlineItem = offlineMedia.getItem(OfflineIds.animeEpisodeId(item.tmdbId, st.playerEpisode));
    if (offlineItem && offlineItem.status === 'completed') {
      const url = await offlineMedia.getPlayableUrl(offlineItem);
      if (!st.mounted) {
        offlineMedia.revokeBlobUrl(url);
        return;
      }
      if (url) {
        const prev = st.offlineBlobUrl;
        setState(() => (st.offlineBlobUrl = url));
        if (prev && prev !== url) offlineMedia.revokeBlobUrl(prev);
        return;
      }
    }
    if (st.offlineBlobUrl) {
      const prev = st.offlineBlobUrl;
      setState(() => (st.offlineBlobUrl = undefined));
      offlineMedia.revokeBlobUrl(prev);
    }
  };

  const fetchSkips = async () => {
    const mal = malId();
    const episode = st.selectedEpisode;
    if (mal <= 0) return;
    const times = await fetchSkipTimes(mal, episode);
    if (!st.mounted || st.selectedEpisode !== episode) return;
    setState(() => (st.skipTimes = times ?? undefined));
  };

  const recordHistory = (episode: number) => {
    if (item.source === 'tmdb') return;
    AnimexStores.recordWatch({
      key: histKey(),
      anilistId,
      malId: malId(),
      title: item.title,
      coverUrl: mediaPosterUrl(item),
      episode,
      totalEpisodes: st.detail?.episodeCount ?? item.episodeCount ?? 0,
    });
  };

  const saveWatchProgress = (o: { episode?: number; positionSeconds?: number } = {}) => {
    const userName = currentUserName();
    if (!userName || (!st.hasUnsavedProgress && o.episode == null)) return;
    st.hasUnsavedProgress = false;
    const ep = o.episode ?? st.selectedEpisode;
    const pos = o.positionSeconds ?? st.lastKnownPosition;
    const duration = st.playbackDuration != null ? Math.round(st.playbackDuration) : undefined;
    const effectiveTmdbId =
      (st.accountProgress?.tmdbId ?? 0) > 0 ? st.accountProgress!.tmdbId : item.tmdbId > 0 ? item.tmdbId : (anilistId ?? 0);
    if (effectiveTmdbId <= 0) return;
    const mediaItem = animeItem({
      tmdbId: effectiveTmdbId,
      title: item.title,
      mediaType: item.mediaType || 'tv',
      posterPath: item.posterPath || mediaPosterUrl(item),
      backdropPath: item.backdropPath,
      year: item.year,
      status: watchingStatusFor(userName),
      userName,
      source: item.source || 'jikan',
      anilistId: anilistId ?? st.accountProgress?.anilistId,
      synopsis: item.synopsis,
      episodeCount: item.episodeCount ?? st.detail?.episodeCount,
      airingStatus: item.airingStatus,
      format: item.format,
      studio: item.studio,
      genres: item.genres,
    });
    const isMovie = mediaIsMovie(mediaItem);
    const total = mediaItem.episodeCount;
    const hitsFinale = !isMovie && total != null && total > 1 && ep >= total;
    const status = hitsFinale ? watchedStatusFor(userName) : watchingStatusFor(userName);
    const season = resolveProgressSeason({ isMovie, title: mediaItem.title, episode: ep, episodeSlots: st.episodeSlots });
    st.progressSave = st.progressSave.then(() =>
      updateProgress(mediaItem, userName, {
        season,
        episode: isMovie ? undefined : ep,
        timestamp: pos != null ? Math.round(pos) : undefined,
        durationSeconds: duration,
        status,
      }).catch((e) => Logger.e('AnimeX: progress save failed', e)),
    );
  };

  const scheduleProgressSave = () => {
    if (st.progressThrottler != null) return;
    st.progressThrottler = window.setTimeout(() => {
      st.progressThrottler = undefined;
      if (st.mounted && st.ready) saveWatchProgress();
    }, 15000);
  };
  const cancelThrottle = () => {
    window.clearTimeout(st.progressThrottler);
    st.progressThrottler = undefined;
  };

  const onPlayerProgress = (p: VideasyProgress) => {
    if (!st.mounted || !st.ready) return;
    if (p.episode != null && p.episode !== st.selectedEpisode) return;
    st.playbackPosition = p.positionSeconds;
    st.lastKnownPosition = p.positionSeconds;
    st.playbackDuration = p.durationSeconds;
    st.hasUnsavedProgress = true;
    scheduleProgressSave();
  };

  const fetchProbeBody = async (url: string): Promise<string | null> => {
    const get = async (u: string, ms: number) => {
      const ctrl = new AbortController();
      const timer = window.setTimeout(() => ctrl.abort(), ms);
      try {
        const headers: Record<string, string> = {};
        if (u.startsWith(PROBE_PROXY_URL)) {
          const token = await firebaseAuth.currentUser?.getIdToken().catch(() => null);
          if (token) headers.Authorization = `Bearer ${token}`;
        }
        const resp = await fetch(u, { signal: ctrl.signal, headers });
        if (resp.status !== 200) return 'no playable stream sources';
        return await resp.text();
      } finally {
        window.clearTimeout(timer);
      }
    };
    try {
      return await get(url, 14000);
    } catch {
      try {
        return await get(`${PROBE_PROXY_URL}?url=${encodeURIComponent(url)}`, 12000);
      } catch (e) {
        Logger.e(`AnimeX: server probe proxy fallback failed for ${url}`, e);
      }
      return null;
    }
  };

  const persistServer = (index: number) => {
    if (index < 0 || index >= st.servers.length) return;
    PlayerMemoryService.save(memoryKey(), { server: st.servers[index]!.name });
  };

  const handleContentError = () => {
    if (!st.mounted) return;
    const available = st.servers.map((x, i) => (x.available ? i : -1)).filter((i) => i >= 0);
    if (!available.length) return;
    st.failedServerIndices.add(st.serverIndex);
    const next = available.filter((i) => !st.failedServerIndices.has(i));
    if (!next.length) {
      setState(() => (st.showErrorCard = true));
      return;
    }
    const nextStart =
      st.playbackPosition != null
        ? Math.round(st.playbackPosition)
        : currentServer()?.supportsResume && st.playerEpisode === st.selectedEpisode
          ? st.startSeconds
          : undefined;
    setState(() => {
      st.serverIndex = next[0]!;
      st.startSeconds = nextStart;
      st.playbackPosition = undefined;
      st.playerEpisode = st.selectedEpisode;
      st.showErrorCard = false;
    });
    persistServer(next[0]!);
    void probeCurrentServer();
  };

  const handleRetry = async () => {
    st.failedServerIndices.clear();
    const preferred = st.servers.findIndex((x) => x.available);
    setState(() => {
      st.showErrorCard = false;
      st.serverIndex = preferred >= 0 ? preferred : st.serverIndex;
      st.startSeconds = st.playbackPosition != null ? Math.round(st.playbackPosition) : st.startSeconds;
    });
    await probeCurrentServer(false);
  };

  const probeCurrentServer = async (autoAdvance = true) => {
    const url = playerUrl();
    if (!url || st.probingServer || url.startsWith('blob:')) return;
    setState(() => (st.probingServer = true));
    try {
      const body = await fetchProbeBody(url);
      if (st.mounted && url === playerUrl() && body != null && isProviderErrorPage(body)) {
        if (autoAdvance) handleContentError();
        else setState(() => (st.showErrorCard = true));
      }
    } catch {
      // Network errors are ambiguous; leave the iframe up.
    } finally {
      if (st.mounted) setState(() => (st.probingServer = false));
    }
  };

  const selectServer = (index: number) => {
    if (!st.ready) return;
    const nextStart =
      st.playbackPosition != null
        ? Math.round(st.playbackPosition)
        : currentServer()?.supportsResume && st.playerEpisode === st.selectedEpisode
          ? st.startSeconds
          : undefined;
    setState(() => {
      st.serverIndex = index;
      st.startSeconds = nextStart;
      st.playbackPosition = undefined;
      st.playerEpisode = st.selectedEpisode;
      st.failedServerIndices.clear();
      st.showErrorCard = false;
    });
    persistServer(index);
    void probeCurrentServer(false);
  };

  const setAudio = (a: string) => {
    if (!st.ready || (a !== 'sub' && a !== 'dub') || a === st.audio) return;
    setState(() => {
      st.audio = a;
      st.startSeconds =
        st.playbackPosition != null
          ? Math.round(st.playbackPosition)
          : st.playerEpisode === st.selectedEpisode
            ? st.startSeconds
            : undefined;
      st.playbackPosition = undefined;
      st.playerEpisode = st.selectedEpisode;
    });
    PlayerMemoryService.save(memoryKey(), { audio: a });
    st.failedServerIndices.clear();
    st.showErrorCard = false;
    void probeCurrentServer();
  };

  const resetForNewEpisode = () => {
    st.failedServerIndices.clear();
    st.showErrorCard = false;
    st.skipTimes = undefined;
    st.startSeconds = undefined;
    st.playbackPosition = undefined;
    st.lastKnownPosition = undefined;
    st.playbackDuration = undefined;
    cancelThrottle();
    void checkOfflinePlayback();
  };

  const selectEpisode = (episode: number) => {
    st.episodeChosen = true;
    if (st.selectedEpisode === episode) return;
    setState(() => {
      st.selectedEpisode = episode;
      st.playerEpisode = episode;
    });
    resetForNewEpisode();
    recordHistory(episode);
    if (st.ready) saveWatchProgress({ episode, positionSeconds: 0 });
    void fetchSkips();
    // The player scrolls away on a phone; choosing an episode has to bring it
    // back, or she is listening to a screen she cannot see.
    scrollRef.current?.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const stepEpisode = (delta: number) => {
    const next = clamp(st.selectedEpisode + delta, 1, st.episodes.length);
    if (next !== st.selectedEpisode) selectEpisode(next);
  };

  const onPlayerEpisodeChanged = (tmdbSeason: number, tmdbEpisode: number) => {
    if (!st.mounted || !st.episodes.length) return;
    if (currentServer()?.name !== 'CineSrc') return;
    const mapped = mapPlayerEpisodeToMal({
      tmdbSeason,
      tmdbEpisode,
      episodeSlots: st.episodeSlots,
      episodeCount: st.episodes.length,
    });
    if (mapped == null || mapped === st.selectedEpisode) return;
    setState(() => (st.selectedEpisode = mapped));
    const loadedStart = st.startSeconds;
    resetForNewEpisode();
    st.startSeconds = loadedStart;
    recordHistory(mapped);
    saveWatchProgress({ episode: mapped, positionSeconds: 0 });
    void fetchSkips();
  };

  const openSeason = (season: AniListSeason) => {
    if (season.isCurrent) return;
    ctl.current.openWatch(seasonItem(season));
  };

  const openEpisodeInfo = (ep: AniListEpisode) => {
    if (!st.ready) return;
    showEpisodeInfoSheet({
      episode: ep,
      animeTitle: displayTitle,
      fallbackPoster: mediaPosterUrl(item),
      isPlaying: ep.number === st.selectedEpisode,
      hideSpoilers: AnimexStores.hideSpoilers && ep.number >= st.selectedEpisode,
      onPlay: () => selectEpisode(ep.number),
    });
  };

  const showEpisodes = () => {
    const wasFullscreen = isPlayerFullscreenActive();
    exitPlayerFullscreen();
    window.setTimeout(
      () => {
        const target = episodesRef.current;
        const scroller = scrollRef.current;
        if (!target || !scroller) return;
        const top = target.getBoundingClientRect().top - scroller.getBoundingClientRect().top + scroller.scrollTop;
        scroller.scrollTo({ top, behavior: 'smooth' });
      },
      wasFullscreen ? 350 : 0,
    );
  };

  const startAnimeWatchParty = async () => {
    const mal = malId();
    if (mal <= 0) return;
    await startWatchParty(
      {
        tmdbId: mal,
        malId: mal,
        mediaType: st.isFilm ? 'movie' : 'tv',
        isAnime: true,
        season: 1,
        episode: st.isFilm ? 1 : st.selectedEpisode,
        episodeCount: st.episodes.length ? st.episodes.length : undefined,
        title: displayTitle,
        posterPath: item.posterPath,
      },
      openRoom,
    );
  };

  // --- loading ---
  const searchTmdbFallback = async (detail?: AniListDetail | null): Promise<number | undefined> => {
    const candidates = [...(detail ? [detail.titleEnglish, detail.titleRomaji, detail.titleNative] : []), item.title];
    const isFilm = filmFor(detail);
    const seen = new Set<string>();
    for (const candidate of candidates) {
      const q = candidate.trim();
      if (!q || seen.has(q)) continue;
      seen.add(q);
      let results: MediaItem[];
      try {
        results = (await searchMulti(q)).results;
      } catch {
        return undefined;
      }
      if (!results.length) continue;
      const hit = pickTmdbFallbackId({ results, title: q, year: item.year, isMovie: isFilm });
      if (hit != null) return hit;
    }
    return undefined;
  };

  const load = async () => {
    if (item.source === 'tmdb') {
      const data = await fetchMediaDetails(item.tmdbId, item.mediaType);
      if (!st.mounted) return;
      const mapped = mapTmdbAnimeDetails(item, data ?? {});
      st.mappedTmdbId = item.tmdbId;
      st.episodeSlots = mapped.slots;
      st.isFilm = mediaIsMovie(item);
      setState(() => {
        st.detail = mapped.detail;
        st.episodes = makeEpisodes(mapped.detail);
        st.servers = makeServers();
        st.serverIndex = defaultServerIndex(st.servers, st.rememberedServer);
      });
      return;
    }
    const mal = malId();
    if (mal <= 0 && anilistId == null) return;
    const detail = await fetchDetailsWithFallback({ anilistId, malId: mal });
    let mappedAnilistId: number | undefined;
    let mappedTmdbId: number | undefined;
    const mappingsMalId = resolveMappingsMalId(detail?.malId, malId());
    let episodeSlots: EpisodeSlots = new Map();
    let aniZipEpisodes = new Map<number, Record<string, unknown>>();
    const toId = (raw: unknown) => {
      if (typeof raw === 'number' && raw > 0) return Math.trunc(raw);
      if (typeof raw === 'string' && raw) {
        const parsed = Number.parseInt(raw, 10);
        if (parsed > 0) return parsed;
      }
      return undefined;
    };
    try {
      let mappings = mappingsMalId > 0 ? await fetchAniZipMappings({ malId: mappingsMalId }) : null;
      mappings ??= await fetchAniZipMappings({ anilistId: anilistId ?? detail?.id ?? 0 });
      const mapped = mappings?.mappings as Record<string, unknown> | undefined;
      mappedAnilistId = toId(mapped?.anilist_id);
      mappedTmdbId = toId(mapped?.themoviedb_id);
      const rawEpisodes = mappings?.episodes as Record<string, unknown> | undefined;
      if (rawEpisodes && Object.keys(rawEpisodes).length) {
        const parsedMap = new Map<number, Record<string, unknown>>();
        const parsedSlots: EpisodeSlots = new Map();
        for (const [key, value] of Object.entries(rawEpisodes)) {
          if (!value || typeof value !== 'object' || Array.isArray(value)) continue;
          const n = Number.parseInt(key, 10);
          if (Number.isNaN(n)) continue;
          const v = value as Record<string, unknown>;
          parsedMap.set(n, v);
          const season = typeof v.seasonNumber === 'number' ? Math.trunc(v.seasonNumber) : undefined;
          const episodeNo = typeof v.episodeNumber === 'number' ? Math.trunc(v.episodeNumber) : undefined;
          if (season != null && season > 0 && episodeNo != null && episodeNo > 0)
            parsedSlots.set(n, { season, episode: episodeNo });
        }
        aniZipEpisodes = parsedMap;
        episodeSlots = parsedSlots;
      }
    } catch (e) {
      Logger.e(`AnimeX: aniZip mappings fetch failed for ${detail?.titleEnglish}`, e);
    }
    mappedTmdbId ??= await searchTmdbFallback(detail);
    st.mappedAnilistId = mappedAnilistId;
    st.mappedTmdbId = mappedTmdbId;
    st.episodeSlots = episodeSlots;
    st.isFilm = filmFor(detail);
    if (!st.mounted) return;
    const nextServers = makeServers({ mappedAnilistId, mappedMalId: mappingsMalId });
    setState(() => {
      st.detail = detail;
      st.episodes = makeEpisodes(detail, aniZipEpisodes);
      st.servers = nextServers;
      st.serverIndex = defaultServerIndex(nextServers, st.rememberedServer);
    });
  };

  const restoreMemory = async () => {
    const memory = PlayerMemoryService.load(memoryKey());
    let saved: MediaItem | null | undefined;
    if (currentUserName()) {
      saved = await getSavedProgress(item.tmdbId, owner.current, { source: item.source, mediaType: item.mediaType });
      saved ??= ctl.current.savedAnime(item);
    }
    if (!st.mounted || (auth.currentUser != null && !currentUserName())) return;
    st.accountProgress = saved;
    if (!st.episodeChosen) {
      const resume = resolveResume({
        item,
        saved,
        local: AnimexStores.findHistory(histKey()),
        requestedEpisode: ctl.current.watchEpisode,
      });
      st.selectedEpisode = resume.episode;
      st.playerEpisode = resume.episode;
      st.startSeconds = resume.seconds;
      st.hasUnsavedProgress = false;
      st.lastKnownPosition = resume.seconds;
      st.playbackPosition = undefined;
      st.playbackDuration = (saved ?? item).durationSeconds;
    }
    const audio = memory.audio ?? '';
    if ((audio === 'sub' || audio === 'dub') && audio !== st.audio) setState(() => (st.audio = audio));
    if (memory.server) {
      const normalized = normalizeServerName(memory.server);
      st.rememberedServer = normalized;
      const index = st.servers.findIndex((x) => x.available && x.name === normalized);
      if (index !== -1 && index !== st.serverIndex && st.mounted) setState(() => (st.serverIndex = index));
    }
  };

  const initialize = async () => {
    try {
      await Promise.all([load(), restoreMemory()]);
    } catch (e) {
      Logger.e('AnimeX: watch initialization failed', e);
    }
    if (!st.mounted) return;
    await checkOfflinePlayback();
    if (st.episodes.length) {
      const knownCount = st.detail?.episodeCount ?? item.episodeCount;
      const episode = knownCount != null && knownCount > 0 ? clamp(st.selectedEpisode, 1, knownCount) : st.selectedEpisode;
      if (episode > st.episodes.length) {
        const extra: AniListEpisode[] = [];
        for (let n = st.episodes.length + 1; n <= episode; n++) extra.push({ number: n });
        st.episodes = [...st.episodes, ...extra];
      }
      if (episode !== st.selectedEpisode) {
        st.startSeconds = undefined;
        st.playbackPosition = undefined;
      }
      st.selectedEpisode = episode;
      st.playerEpisode = episode;
    }
    setState(() => (st.ready = true));
    void fetchSkips();
    recordHistory(st.selectedEpisode);
    void probeCurrentServer();
  };

  const latest = useRef({ saveWatchProgress, cancelThrottle });
  latest.current = { saveWatchProgress, cancelThrottle };

  useEffect(() => {
    st.mounted = true;
    st.servers = makeServers();
    st.serverIndex = defaultServerIndex(st.servers);
    st.episodes = makeEpisodes(null);
    bump();
    void initialize();
    const onVisibility = () => {
      if (document.visibilityState === 'hidden') {
        latest.current.cancelThrottle();
        if (st.ready) latest.current.saveWatchProgress();
      }
    };
    document.addEventListener('visibilitychange', onVisibility);
    return () => {
      document.removeEventListener('visibilitychange', onVisibility);
      latest.current.cancelThrottle();
      if (st.ready) latest.current.saveWatchProgress();
      st.mounted = false;
      offlineMedia.revokeBlobUrl(st.offlineBlobUrl);
      st.offlineBlobUrl = undefined;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // --- layout ---
  const isDesktop = width >= 1200;
  const isCompactPage = width < 700;
  const phone = width < 600;
  // Reserve room for the title, servers, recovery strip and prefs: a desktop
  // player that eats the whole fold hides prev/next, which is the binge controls.
  const maxPlayerHeight = clamp(height - (width < 700 ? 280 : 350), 240, PLAYER_MAX_HEIGHT);
  if (!isPlayerFullscreenActive() || st.lastWindowedMaxPlayerHeight == null) st.lastWindowedMaxPlayerHeight = maxPlayerHeight;
  const contentWidth = clamp(width - 48, 0, WATCH_PAGE_MAX_WIDTH);
  const sidebarHeight = clamp(((contentWidth - 20 - 380) * 9) / 16, 0, maxPlayerHeight);
  const animeId = item.anilistId ?? item.tmdbId;
  const fallbackPoster = mediaPosterUrl(item);
  const detail = st.detail;
  const canWatchTogether = auth.isCoupleUser;

  const episodesProps = {
    episodes: st.episodes,
    selectedEpisode: st.selectedEpisode,
    airing: (st.detail?.airingStatus ?? '').toUpperCase() === 'RELEASING' || (st.detail?.nextAiringAt ?? 0) > 0,
    animeTitle: displayTitle,
    animeId,
    fallbackPoster,
    onSelectEpisode: selectEpisode,
    onShowInfo: openEpisodeInfo,
    seasons: seasons(),
    onSelectSeason: openSeason,
    nextSeason: nextSeason(),
  };

  const url = playerUrl();
  const next = nextUpInfo();

  // The recovery card is normally driven by a real failed probe. Agent sessions
  // can ask for it with &playerError=1 so a proof shot is reproducible.
  const forceContentError =
    AgentMode.isActive.value && new URLSearchParams(window.location.search).get('playerError') === '1';
  const contentError = st.showErrorCard || forceContentError;

  // One failure, one card. A dead probe and a source that never starts used to
  // say different things; they are the same problem to her.
  const errorCard = (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
        padding: '0 24px',
        boxSizing: 'border-box',
        background: '#08070D',
        textAlign: 'center',
      }}
    >
      <Icon name="warning_amber" size={28} color={T.accentText} />
      <div style={dmSansStyle({ size: 15.5, color: T.textPrimary, weight: 700 })}>This episode isn't playing</div>
      <div style={{ ...dmSansStyle({ size: 12.5, color: T.textSecondary, height: 1.45 }), maxWidth: 300 }}>
        No server answered just now.
      </div>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', justifyContent: 'center', marginTop: 6 }}>
        <AnimeXPrimaryButton label="Try another server" icon="swap_horiz" onClick={handleContentError} />
        {next && !next.isSeason && (
          <button
            type="button"
            className="bare-button"
            onClick={() => stepEpisode(1)}
            style={{
              minHeight: 40,
              padding: '0 14px',
              borderRadius: 999,
              border: `1px solid ${T.borderStrong}`,
              background: white(0.08),
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
            }}
          >
            <Icon name="skip_next" size={15} color={T.textPrimary} />
            <span style={dmSansStyle({ size: 12, color: T.textPrimary, weight: 700 })}>Episode {st.selectedEpisode + 1}</span>
          </button>
        )}
      </div>
    </div>
  );
  const player = !st.ready ? (
    <div style={{ position: 'relative', width: '100%', aspectRatio: '16 / 9' }}>
      {TmdbImages.backdropOf(item.backdropPath, true) && (
        <img
          src={TmdbImages.backdropOf(item.backdropPath, true)}
          alt=""
          style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', opacity: 0.3 }}
        />
      )}
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <CircularProgress size={36} strokeWidth={4} color={T.accent} />
      </div>
    </div>
  ) : contentError || !url ? (
    <div
      style={{
        position: 'relative',
        width: '100%',
        aspectRatio: '16 / 9',
        borderRadius: T.radiusLg,
        overflow: 'hidden',
        border: `1px solid ${T.border}`,
      }}
    >
      {errorCard}
    </div>
  ) : (
    <AnimeXPlayerFrame
      key={`player-${url}`}
      url={url}
      title={`${displayTitle} · Episode ${st.selectedEpisode}`}
      onContentError={handleContentError}
      onProgress={onPlayerProgress}
      skipTimes={stores.skipIntro ? st.skipTimes : null}
      nextToken={next?.token}
      nextIsSeason={next?.isSeason ?? false}
      autoAdvance={stores.autoNext}
      onAutoNextChanged={(v) => AnimexStores.setAutoNext(v)}
      onNextEpisode={() => {
        if (st.selectedEpisode < st.episodes.length) stepEpisode(1);
        else {
          const ns = nextSeason();
          if (ns) openSeason(ns);
        }
      }}
      onAudioChanged={setAudio}
      onShowEpisodes={showEpisodes}
      onPlayerEpisodeChanged={onPlayerEpisodeChanged}
    />
  );

  // A source that never starts must not be a silent dead end: after 9s with no
  // playback, say so and offer the two ways out. The clock is measured against
  // a mount time, so re-renders and server switches cannot reset it.
  const [slowStart, setSlowStart] = useState(false);
  const playerWatchRef = useRef(st.playbackPosition ?? 0);
  playerWatchRef.current = st.playbackPosition ?? 0;
  useEffect(() => {
    if (!st.ready || !url) return;
    const startedAt = Date.now();
    const timer = window.setInterval(() => {
      if (playerWatchRef.current > 0) {
        window.clearInterval(timer);
        setSlowStart(false);
        return;
      }
      if (Date.now() - startedAt >= 9000) {
        window.clearInterval(timer);
        setSlowStart(true);
      }
    }, 1000);
    return () => window.clearInterval(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [st.selectedEpisode, Boolean(st.ready)]);
  // Real playback clears the message for good, including when it starts late.
  const playingNow = (st.playbackPosition ?? 0) > 0;
  useEffect(() => {
    if (playingNow) setSlowStart(false);
  }, [playingNow]);
  // A centered box capped at maxHeight that keeps 16:9 (ConstrainedBox around AspectRatio).
  const playerBox = (
    <div style={{ display: 'flex', justifyContent: 'center' }}>
      <div
        style={{
          width: '100%',
          position: 'relative',
          // A phone is a theatre: the video runs edge to edge (no 24px gutters).
          maxWidth: phone ? undefined : (st.lastWindowedMaxPlayerHeight * 16) / 9,
        }}
      >
        {player}
        {slowStart && !contentError && <div style={{ position: 'absolute', inset: 0 }}>{errorCard}</div>}
      </div>
    </div>
  );

  const ep = activeEpisode();

  const failedNote = (() => {
    if (contentError || slowStart || !st.failedServerIndices.size) return '';
    const failed = [...st.failedServerIndices].filter((i) => i >= 0 && i < st.servers.length).map((i) => st.servers[i]!.name);
    if (!failed.length) return '';
    const names = failed.join(', ');
    const current = currentServer()?.name;
    return current == null
      ? `${names} didn't load for this episode.`
      : `${names} didn't load for this episode, so we switched to ${current}.`;
  })();

  const isLastEpisode = st.selectedEpisode >= st.episodes.length;
  const ns = nextSeason();
  const hasNextSeason = isLastEpisode && ns != null;

  const showServerSheet = () => {
    void showModalBottomSheet<void>((close) => (
      <div style={{ padding: '4px 16px 24px' }}>
        <SheetDragHandle />
        <div style={dmSansStyle({ size: 15, color: T.textPrimary, weight: 800 })}>Where to watch from</div>
        <div style={{ height: 4 }} />
        <div style={dmSansStyle({ size: 12, color: T.textSecondary })}>
          One free source is enough. If one stalls, pick another.
        </div>
        <div style={{ height: 14 }} />
        {st.servers.map((srv, i) => {
          const failed = st.failedServerIndices.has(i);
          const selected = st.serverIndex === i;
          return (
            <button
              key={srv.name}
              type="button"
              className="bare-button"
              disabled={!srv.available}
              onClick={() => {
                close(null);
                selectServer(i);
              }}
              style={{
                width: '100%',
                minHeight: 52,
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                padding: '0 12px',
                marginBottom: 8,
                borderRadius: T.radiusLg,
                background: selected ? withAlpha(T.accent, 0.16) : white(0.04),
                border: `1px solid ${selected ? withAlpha(T.accent, 0.45) : T.border}`,
                opacity: srv.available ? 1 : 0.5,
              }}
            >
              <Icon
                name={failed ? 'error_outline' : selected ? 'check_circle' : 'circle'}
                size={17}
                color={failed ? T.textMuted : selected ? T.accentText : T.textSecondary}
              />
              <span style={{ ...dmSansStyle({ size: 14, color: T.textPrimary, weight: 600 }), flex: 1, textAlign: 'left' }}>
                {srv.name}
              </span>
              <span style={dmSansStyle({ size: 11, color: T.textMuted, weight: 600 })}>
                {!srv.available ? 'Unavailable' : failed ? 'Failed' : srv.supportsAudioSelection ? 'Sub & Dub' : 'Sub'}
              </span>
            </button>
          );
        })}
      </div>
    ));
  };

  // Phone: player pinned while the episode list scrolls under it, then one
  // compact band of controls. The old layout stacked six bands (heading, meta,
  // server wall, audio, toggles, prev/next) before a single episode.
  const playerColumn = phone ? (
    <div>
      <div style={{ position: 'sticky', top: 0, zIndex: 20, background: T.bg }}>{playerBox}</div>
      <div style={{ padding: '10px 16px 0' }}>
        {st.ready && (
          <>
            <div style={{ ...dmSansStyle({ size: 17, color: T.textPrimary, weight: 700, height: 1.25 }), ...oneLine }}>
              {activeEpisodeTitle()}
            </div>
            <div style={{ height: 3 }} />
            <div style={{ ...dmSansStyle({ size: 12, color: T.textSecondary }), ...oneLine }}>
              {[
                ep?.duration != null && ep.duration > 0 ? `${ep.duration} min` : '',
                ep?.airedAt ? `Aired ${ymd(ep.airedAt)}` : '',
                seasons().length > 1 ? seasons().find((x) => x.isCurrent)?.label ?? seasons().find((x) => x.isCurrent)?.title ?? '' : '',
              ]
                .filter(Boolean)
                .join(' · ')}
            </div>
          </>
        )}
        <div style={{ height: 10 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 8 }}>
          {st.servers.length > 1 && (
            <button
              type="button"
              className="bare-button"
              onClick={showServerSheet}
              style={{
                flexShrink: 0,
                minHeight: 40,
                display: 'flex',
                alignItems: 'center',
                gap: 6,
                padding: '0 12px',
                borderRadius: T.radiusPill,
                background: white(0.05),
                border: `1px solid ${T.border}`,
              }}
            >
              <Icon name="dns" size={15} color={T.accentText} />
              <span style={dmSansStyle({ size: 12.5, color: T.textPrimary, weight: 700 })}>
                Server · {currentServer()?.name ?? 'none'}
              </span>
              <Icon name="keyboard_arrow_down" size={15} color={T.textSecondary} />
            </button>
          )}
          <PrefToggle label="Auto next" value={stores.autoNext} onChanged={(v) => AnimexStores.setAutoNext(v)} />
          <PrefToggle label="Skip intro" value={stores.skipIntro} onChanged={(v) => AnimexStores.setSkipIntro(v)} />
          <button
            type="button"
            className="bare-button"
            aria-label="Previous episode"
            disabled={st.selectedEpisode <= 1}
            onClick={() => stepEpisode(-1)}
            style={{
              flexShrink: 0,
              width: 44,
              height: 44,
              boxSizing: 'border-box',
              borderRadius: T.radiusPill,
              background: white(0.05),
              border: `1px solid ${T.border}`,
              display: 'grid',
              placeItems: 'center',
              opacity: st.selectedEpisode <= 1 ? 0.4 : 1,
            }}
          >
            <Icon name="skip_previous" size={18} color={T.textPrimary} />
          </button>
          <button
            type="button"
            className="bare-button"
            aria-label="Next episode"
            disabled={isLastEpisode && !hasNextSeason}
            onClick={() => (hasNextSeason ? openSeason(ns!) : stepEpisode(1))}
            style={{
              flexShrink: 0,
              width: 44,
              height: 44,
              boxSizing: 'border-box',
              borderRadius: T.radiusPill,
              background: withAlpha(T.accent, 0.16),
              border: `1px solid ${withAlpha(T.accent, 0.45)}`,
              display: 'grid',
              placeItems: 'center',
            }}
          >
            <Icon name="skip_next" size={18} color={T.accentText} />
          </button>
        </div>
        {failedNote && (
          <>
            <div style={{ height: 8 }} />
            <div style={dmSansStyle({ size: 12, color: T.textSecondary, height: 1.4 })}>{failedNote}</div>
          </>
        )}
      </div>
    </div>
  ) : (
    <div>
      {playerBox}
      {st.ready && (
        <>
          <div style={{ height: isCompactPage ? 8 : 12 }} />
          <div style={dmSansStyle({ size: 18, color: T.textPrimary, weight: 700, height: 1.25 })}>{activeEpisodeTitle()}</div>
          <div style={{ height: 4 }} />
          <div style={{ display: 'flex', alignItems: 'center', whiteSpace: 'pre' }}>
            {ep?.duration != null && ep.duration > 0 && (
              <span style={dmSansStyle({ size: 12, color: T.textSecondary })}>{ep.duration} min</span>
            )}
            {ep?.airedAt && (
              <>
                <span style={dmSansStyle({ size: 11, color: T.textMuted })}>{'  •  '}</span>
                <span style={dmSansStyle({ size: 12, color: T.textSecondary })}>{ymd(ep.airedAt)}</span>
              </>
            )}
          </div>
        </>
      )}
      <div style={{ height: isCompactPage ? 8 : 10 }} />
      <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 10 }}>
        <button
          type="button"
          className="bare-button"
          onClick={showServerSheet}
          style={{
            minHeight: 44,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 7,
            padding: '0 14px',
            boxSizing: 'border-box',
            borderRadius: T.radiusPill,
            background: white(0.05),
            border: `1px solid ${T.border}`,
          }}
        >
          <Icon name="dns" size={15} color={T.accentText} />
          <span style={dmSansStyle({ size: 12.5, color: T.textPrimary, weight: 700 })}>
            Server · {currentServer()?.name ?? 'none'}
          </span>
          <Icon name="keyboard_arrow_down" size={15} color={T.textSecondary} />
        </button>
        {[...st.failedServerIndices].some((i) => i === st.serverIndex) && (
          <span style={dmSansStyle({ size: 11.5, color: T.textMuted })}>last source didn't load</span>
        )}
      </div>
      {failedNote && (
        <>
          <div style={{ height: 10 }} />
          <div style={dmSansStyle({ size: 12, color: T.textSecondary })}>{failedNote}</div>
        </>
      )}
      {st.ready && (
        <>
          <div style={{ height: isCompactPage ? 8 : 12 }} />
          <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', justifyContent: 'space-between', gap: '8px 12px' }}>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              <PrefToggle label="Auto next" value={stores.autoNext} onChanged={(v) => AnimexStores.setAutoNext(v)} />
              <PrefToggle label="Skip intro" value={stores.skipIntro} onChanged={(v) => AnimexStores.setSkipIntro(v)} />
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
              <EpisodeStepButton label="Prev Episode" enabled={st.selectedEpisode > 1} onTap={() => stepEpisode(-1)} />
              <EpisodeStepButton
                label={hasNextSeason ? 'Next Season' : 'Next Episode'}
                icon={hasNextSeason ? 'skip_next' : undefined}
                enabled={!isLastEpisode || hasNextSeason}
                onTap={hasNextSeason ? () => openSeason(ns!) : () => stepEpisode(1)}
              />
            </div>
          </div>
        </>
      )}
    </div>
  );

  const pageBox: CSSProperties = { maxWidth: WATCH_PAGE_MAX_WIDTH, margin: '0 auto', padding: '0 24px' };
  const playerSection = isDesktop ? (
    <div style={{ ...pageBox, display: 'flex', alignItems: 'flex-start' }}>
      <div style={{ flex: 1, minWidth: 0 }}>{playerColumn}</div>
      <div style={{ width: 20, flexShrink: 0 }} />
      <div style={{ width: 380, height: sidebarHeight, flexShrink: 0 }}>
        {st.ready && <DesktopEpisodesSidebar {...episodesProps} />}
      </div>
    </div>
  ) : phone ? (
    <div>
      {playerColumn}
      {st.ready && (
        <>
          <div style={{ height: 22 }} />
          <div ref={episodesRef} style={{ padding: '0 16px' }}>
            <MobileEpisodesSection {...episodesProps} />
          </div>
        </>
      )}
    </div>
  ) : (
    <div style={pageBox}>
      {playerColumn}
      {st.ready && (
        <>
          <div style={{ height: 24 }} />
          <div ref={episodesRef}>
            <MobileEpisodesSection {...episodesProps} />
          </div>
        </>
      )}
    </div>
  );

  const seasonIds = new Set(seasons().map((x) => x.id));
  const seasonMalIds = new Set(seasons().flatMap((x) => (x.malId != null ? [x.malId] : [])));
  const relations = (detail?.relations ?? [])
    .filter((r) => !seasonIds.has(r.id) && (r.malId == null || !seasonMalIds.has(r.malId)))
    .map((r) =>
      animeItem({
        tmdbId: r.malId ?? 0,
        title: r.title,
        mediaType: movieOrTv(r.format),
        posterPath: r.coverImageUrl,
        anilistId: r.id,
        format: r.format,
      }),
    );
  const recs = (detail?.recommendations ?? []).map((r) =>
    animeItem({ tmdbId: r.malId ?? 0, title: r.title, mediaType: 'tv', posterPath: r.coverImageUrl, anilistId: r.id }),
  );
  const open = (it: MediaItem) => ctl.current.openWatch(it);
  const section = (icon: string, title: string, items: MediaItem[]) => (
    <>
      <div style={{ height: 32 }} />
      <div>
        <div style={{ padding: '0 24px' }}>
          <AnimeXSectionHeader icon={icon} title={title} />
        </div>
        <AnimeXPosterRow items={items} cardWidth={T.rowPosterWidthDesktop} onSelect={open} />
      </div>
    </>
  );
  const infoTitle = detail ? (stores.titleJapanese ? detail.titleNative || item.title : detail.titleEnglish || item.title) : '';
  const infoRef = useRef<HTMLDivElement>(null);

  // The hero's "More Info" opens this page: land on the about block, not on a
  // player she did not ask to start.
  useEffect(() => {
    if (ctl.current.focus !== 'info') return;
    const t = window.setTimeout(() => {
      const el = infoRef.current;
      const scroller = scrollRef.current;
      if (!el || !scroller) return;
      scroller.scrollTo({ top: Math.max(0, el.offsetTop - 12), behavior: 'smooth' });
    }, 600);
    return () => window.clearTimeout(t);
  }, []);

  const shareTitle = titleFor(AnimexStores.titleJapanese);
  const trailerAction =
    detail?.trailerYoutubeId != null
      ? () => void showAnimexTrailer({ youtubeId: detail.trailerYoutubeId!, anilistId, malId: malId(), title: displayTitle })
      : undefined;
  const moreActions = [
    trailerAction
      ? { icon: 'play_circle_outline', label: 'Play trailer', onTap: trailerAction }
      : null,
    { icon: 'bookmark_add', label: 'Save to a playlist', onTap: () => showPlaylistSheet(item) },
    canWatchTogether && malId() > 0
      ? { icon: 'favorite', label: 'Watch together', onTap: () => void startAnimeWatchParty() }
      : null,
    { icon: 'ios_share', label: 'Share', onTap: () => showShareSheet(shareTitle, detail?.siteUrl) },
    { icon: 'refresh', label: 'Retry this server', onTap: () => void handleRetry() },
    ctl.current.onMotchi
      ? { icon: 'pets', label: 'Chat with Motchi', onTap: () => ctl.current.onMotchi?.() }
      : null,
  ].filter(Boolean) as { icon: string; label: string; onTap: () => void }[];

  return (
    <div ref={scrollRef} style={{ height: '100%', overflowY: 'auto', overscrollBehavior: 'contain' }}>
      <div style={{ paddingBottom: 64, willChange: 'transform' }}>
        <TopBar
          title={displayTitle}
          subtitle={`Episode ${st.selectedEpisode}${activeEpisodeTitle() !== `Episode ${st.selectedEpisode}` ? ` • ${activeEpisodeTitle()}` : ''}`}
          onBack={() => ctl.current.closeDetail()}
          onTrailer={trailerAction}
          onBookmark={() => showPlaylistSheet(item)}
          onWatchTogether={canWatchTogether && malId() > 0 ? () => void startAnimeWatchParty() : undefined}
          onShare={() => showShareSheet(shareTitle, detail?.siteUrl)}
          overflowActions={phone ? moreActions : undefined}
        />
        <div style={{ height: phone ? 8 : 12 }} />
        {playerSection}
        <div style={{ height: phone ? 20 : 32 }} />
        {detail && (
          <div style={pageBox} ref={infoRef}>
            <div style={{ display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 10 }}>
              <div style={bebasStyle({ size: 30, color: T.textPrimary })}>{infoTitle}</div>
              {nextAiringChip(detail, Date.now())}
            </div>
            <div style={{ height: 8 }} />
            {detail.synopsis && <div style={{ ...interBodyStyle({ size: 13.5, height: 1.65 }), whiteSpace: 'pre-wrap' }}>{detail.synopsis}</div>}
            <div style={{ height: 16 }} />
            <div style={{ display: 'flex', flexWrap: 'wrap', columnGap: 24, rowGap: 12 }}>
              <InfoItem label="Studios" value={detail.studios.length ? detail.studios.slice(0, 2).join(', ') : '—'} />
              <InfoItem label="Airing" value={detail.airingStatus || '—'} />
              <InfoItem label="Duration" value={detail.duration != null ? `${detail.duration} min` : '—'} />
              <InfoItem label="Genres" value={detail.genres.length ? detail.genres.slice(0, 3).join(', ') : '—'} />
            </div>
          </div>
        )}
        {detail &&
          seasons().length > 1 &&
          section(
            'layers',
            'Seasons & Sequels',
            seasons().map((x) => seasonItem(x, x.isCurrent ? 'Playing' : '')),
          )}
        {detail && detail.relations.length > 0 && relations.length > 0 && section('link', 'Related', relations)}
        {detail && detail.relations.length > 0 && relations.length === 0 && <div style={{ height: 32 }} />}
        {detail && recs.length > 0 && section('auto_awesome', 'Recommended Anime', recs)}
        <div style={{ height: 32 }} />
        <AnimeXFooter onGoHome={() => ctl.current.goHome()} onOpenDmca={() => ctl.current.openDmca()} />
      </div>
    </div>
  );
}

// ---------- widgets ----------

function SquareButton({ icon, onTap, label }: { icon: string; onTap: () => void; label: string }) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={label}
      onClick={onTap}
      style={{
        width: 36,
        height: 36,
        flexShrink: 0,
        boxSizing: 'border-box',
        background: white(0.06),
        borderRadius: T.radiusSm,
        border: `1px solid ${T.border}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Icon name={icon} size={17} color={T.textPrimary} />
    </button>
  );
}

function PillButton({
  icon,
  iconSize,
  iconColor,
  label,
  onTap,
  background,
  border,
}: {
  icon: string;
  iconSize: number;
  iconColor: string;
  label: string;
  onTap: () => void;
  background: string;
  border: string;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onTap}
      style={{
        flexShrink: 0,
        padding: '7px 10px',
        background,
        borderRadius: T.radiusSm,
        border: `1px solid ${border}`,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <Icon name={icon} size={iconSize} color={iconColor} />
      <div style={{ width: 5 }} />
      <span style={dmSansStyle({ size: 11.5, color: T.textPrimary, weight: 600 })}>{label}</span>
    </button>
  );
}

function TopBar({
  title,
  subtitle,
  onBack,
  onTrailer,
  onBookmark,
  onWatchTogether,
  onShare,
  overflowActions,
}: {
  title: string;
  subtitle: string;
  onBack: () => void;
  onTrailer?: () => void;
  onBookmark: () => void;
  onWatchTogether?: () => void;
  onShare: () => void;
  /** Phone: one ⋯ button instead of four controls eating the title. */
  overflowActions?: { icon: string; label: string; onTap: () => void }[];
}) {
  const compact = Boolean(overflowActions?.length);
  return (
    <div style={{ padding: compact ? '8px 12px' : '10px 20px', display: 'flex', alignItems: 'center' }}>
      <button
        type="button"
        className="bare-button"
        aria-label="Back"
        onClick={onBack}
        style={{
          width: 44,
          height: 44,
          flexShrink: 0,
          boxSizing: 'border-box',
          background: 'rgba(10, 10, 15, 0.6)',
          borderRadius: T.radiusLg,
          border: `1px solid ${T.borderStrong}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name="arrow_back_ios_new" size={17} color="#FFFFFF" />
      </button>
      <div style={{ width: 12, flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ ...dmSansStyle({ size: 15, color: T.textPrimary, weight: 700 }), ...oneLine }}>{title}</div>
        <div style={{ ...dmSansStyle({ size: 11.5, color: T.textSecondary }), ...oneLine }}>{subtitle}</div>
      </div>
      <div style={{ width: 8, flexShrink: 0 }} />
      {compact ? (
        <button
          type="button"
          className="bare-button"
          aria-label="More actions"
          onClick={() =>
            void showModalBottomSheet<void>((close) => (
              <div style={{ padding: '4px 12px 20px' }}>
                <SheetDragHandle />
                {overflowActions!.map((a) => (
                  <button
                    key={a.label}
                    type="button"
                    className="bare-button"
                    onClick={() => {
                      close(null);
                      a.onTap();
                    }}
                    style={{
                      width: '100%',
                      minHeight: 52,
                      display: 'flex',
                      alignItems: 'center',
                      gap: 14,
                      padding: '0 8px',
                      borderBottom: `1px solid ${T.border}`,
                    }}
                  >
                    <Icon name={a.icon} size={19} color={T.textSecondary} />
                    <span style={dmSansStyle({ size: 14, color: T.textPrimary, weight: 600 })}>{a.label}</span>
                  </button>
                ))}
              </div>
            ))
          }
          style={{
            width: 44,
            height: 44,
            flexShrink: 0,
            boxSizing: 'border-box',
            borderRadius: T.radiusLg,
            border: `1px solid ${T.borderStrong}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="more_horiz" size={20} color={T.textPrimary} />
        </button>
      ) : (
        <>
          {onTrailer && (
            <PillButton
              icon="play_circle_outline"
              iconSize={15}
              iconColor={T.textPrimary}
              label="Trailer"
              onTap={onTrailer}
              background={white(0.06)}
              border={T.border}
            />
          )}
          <div style={{ width: 8, flexShrink: 0 }} />
          <SquareButton icon="bookmark_add_outlined" label="Save to playlist" onTap={onBookmark} />
          <div style={{ width: 8, flexShrink: 0 }} />
          {onWatchTogether && (
            <>
              <PillButton
                icon="favorite"
                iconSize={14}
                iconColor={AppColors.roseQuartz}
                label="Watch Together"
                onTap={onWatchTogether}
                background={withAlpha(AppColors.deepRose, 0.16)}
                border={withAlpha(AppColors.deepRose, 0.55)}
              />
              <div style={{ width: 8, flexShrink: 0 }} />
            </>
          )}
          <SquareButton icon="ios_share" label="Share" onTap={onShare} />
        </>
      )}
    </div>
  );
}


function PrefToggle({ label, value, onChanged }: { label: string; value: boolean; onChanged: (v: boolean) => void }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={value}
      className="bare-button"
      onClick={() => onChanged(!value)}
      style={{
        minHeight: 44,
        boxSizing: 'border-box',
        padding: '7px 12px',
        background: value ? withAlpha(T.accent, 0.18) : white(0.05),
        borderRadius: T.radiusSm,
        border: `1px solid ${value ? withAlpha(T.accent, 0.45) : T.border}`,
        display: 'flex',
        alignItems: 'center',
        transition: 'background-color 120ms, border-color 120ms',
      }}
    >
      <Icon name={value ? 'check' : 'remove'} size={13} color={value ? T.accentWarm : T.textSecondary} />
      <div style={{ width: 6 }} />
      <span
        style={{
          ...dmSansStyle({ size: 12, color: value ? T.accentWarm : T.textSecondary, weight: 600 }),
          whiteSpace: 'nowrap',
        }}
      >
        {label}
      </span>
    </button>
  );
}

/** "Next episode in 2d 4h" — the one next-air fact Anikura puts on this page. */
function nextAiringChip(detail: AniListDetail, now: number) {
  if (detail.airingStatus && !/RELEASING|AIRING/i.test(detail.airingStatus)) return null;
  if (!detail.nextAiringAt || !detail.nextAiringEpisode) return null;
  const ms = detail.nextAiringAt * 1000 - now;
  if (ms <= 0) return null;
  const mins = Math.floor(ms / 60000);
  const days = Math.floor(mins / 1440);
  const hours = Math.floor((mins % 1440) / 60);
  const left = days > 0 ? `${days}d ${hours}h` : hours > 0 ? `${hours}h ${mins % 60}m` : `${mins}m`;
  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        padding: '5px 10px',
        borderRadius: T.radiusPill ?? 999,
        background: withAlpha(T.accent, 0.16),
        border: `1px solid ${withAlpha(T.accent, 0.4)}`,
      }}
    >
      <Icon name="schedule" size={13} color={T.accentText} />
      <span style={dmSansStyle({ size: 11.5, color: T.accentText, weight: 700 })}>
        Episode {detail.nextAiringEpisode} in {left}
      </span>
    </div>
  );
}

function InfoItem({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ width: 150 }}>
      <div style={dmSansStyle({ size: 10.5, color: T.textMuted, weight: 700, letterSpacing: 0.08 })}>{label}</div>
      <div style={{ height: 4 }} />
      <div
        style={{
          ...dmSansStyle({ size: 13, color: T.textPrimary, weight: 600 }),
          display: '-webkit-box',
          WebkitLineClamp: 2,
          WebkitBoxOrient: 'vertical',
          overflow: 'hidden',
        }}
      >
        {value}
      </div>
    </div>
  );
}

function EpisodeStepButton({
  label,
  enabled,
  onTap,
  icon,
}: {
  label: string;
  enabled: boolean;
  onTap: () => void;
  icon?: string;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      disabled={!enabled}
      onClick={enabled ? onTap : undefined}
      style={{
        padding: '8px 14px',
        background: enabled ? white(0.06) : 'transparent',
        borderRadius: T.radiusMd,
        border: `1px solid ${enabled ? T.borderStrong : T.border}`,
        display: 'flex',
        alignItems: 'center',
        cursor: enabled ? 'pointer' : 'default',
      }}
    >
      {icon && (
        <>
          <Icon name={icon} size={15} color={enabled ? T.accentWarm : T.textMuted} />
          <div style={{ width: 6 }} />
        </>
      )}
      <span style={dmSansStyle({ size: 12, color: enabled ? (icon ? T.accentWarm : T.textPrimary) : T.textMuted, weight: 600 })}>
        {label}
      </span>
    </button>
  );
}

// ---------- sheets ----------

const sheetBox: CSSProperties = {
  background: T.surfaceRaised,
  borderRadius: '20px 20px 0 0',
  width: '100%',
  maxWidth: 640,
  maxHeight: 'calc(100dvh * 9 / 16)',
  margin: '0 auto',
  boxSizing: 'border-box',
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  paddingBottom: 'env(safe-area-inset-bottom, 0px)',
};

function SheetHandle() {
  return (
    <>
      <SheetDragHandle />
      <div style={{ height: 12, flexShrink: 0 }} />
      <div style={{ width: 36, height: 4, borderRadius: 2, background: T.textMuted, flexShrink: 0 }} />
    </>
  );
}

function ListTileRow({
  leading,
  title,
  trailing,
  onTap,
}: {
  leading: ReactNode;
  title: string;
  trailing?: ReactNode;
  onTap: () => void;
}) {
  return (
    <div
      onClick={onTap}
      style={{
        alignSelf: 'stretch',
        minHeight: 56,
        padding: '0 24px 0 16px',
        display: 'flex',
        alignItems: 'center',
        cursor: 'pointer',
        flexShrink: 0,
      }}
    >
      {leading}
      <div style={{ width: 16 }} />
      <div style={{ flex: 1, minWidth: 0, ...dmSansStyle({ size: 14, color: T.textPrimary, weight: 600 }) }}>{title}</div>
      {trailing && (
        <>
          <div style={{ width: 16 }} />
          {trailing}
        </>
      )}
    </div>
  );
}

function playlistEntry(item: MediaItem): AnimexPlaylistItem {
  return {
    source: item.source,
    anilistId: item.anilistId,
    malId: item.tmdbId,
    title: item.title,
    coverUrl: mediaPosterUrl(item),
    year: item.year,
    format: item.format,
  };
}

function PlaylistSheet({ item, close }: { item: MediaItem; close: () => void }) {
  useAnimexStores();
  const playlists = AnimexStores.playlists;
  return (
    <div style={sheetBox}>
      <SheetHandle />
      <div style={{ alignSelf: 'stretch', padding: '16px 20px 8px', display: 'flex', alignItems: 'center', flexShrink: 0 }}>
        <div style={{ flex: 1, ...dmSansStyle({ size: 16, color: T.textPrimary, weight: 700 }) }}>Save to Playlist</div>
        <AnimeXPrimaryButton
          label="New"
          icon="add"
          onClick={() => {
            const playlist = AnimexStores.createPlaylist(`Playlist ${playlists.length + 1}`, 'star');
            AnimexStores.addToPlaylist(playlist.id, playlistEntry(item));
            close();
          }}
        />
      </div>
      {playlists.length === 0 ? (
        <div style={{ padding: 24, ...dmSansStyle({ size: 13, color: T.textSecondary }) }}>No playlists yet</div>
      ) : (
        <div style={{ alignSelf: 'stretch', minHeight: 0, overflowY: 'auto' }}>
          {playlists.map((p) => {
            const has = p.items.some((i) => playlistItemMatches(i, item));
            return (
              <ListTileRow
                key={p.id}
                leading={<span style={{ fontSize: 20 }}>{p.emoji || '★'}</span>}
                title={p.name}
                trailing={
                  <Icon name={has ? 'check_circle' : 'radio_button_unchecked'} size={20} color={has ? T.success : T.textMuted} />
                }
                onTap={() => {
                  const entry = playlistEntry(item);
                  if (has) AnimexStores.removePlaylistEntry(p.id, entry);
                  else AnimexStores.addToPlaylist(p.id, entry);
                  close();
                }}
              />
            );
          })}
        </div>
      )}
      <div style={{ height: 8, flexShrink: 0 }} />
    </div>
  );
}

function showPlaylistSheet(item: MediaItem) {
  void showModalBottomSheet<void>((close) => <PlaylistSheet item={item} close={() => close(null)} />);
}

function showShareSheet(title: string, siteUrl?: string) {
  const url = siteUrl ?? 'https://everglow-1c6db.web.app/anime';
  const text = `Watching ${title} on Everglow`;
  const u = encodeURIComponent(url);
  const t = encodeURIComponent(text);
  const targets: [string, string, string][] = [
    ['Telegram', 'send', `https://t.me/share/url?url=${u}&text=${t}`],
    ['WhatsApp', 'chat_bubble_outline', `https://wa.me/?text=${t}%20${u}`],
    ['X / Twitter', 'alternate_email', `https://twitter.com/intent/tweet?url=${u}&text=${t}`],
    ['Reddit', 'forum_outlined', `https://reddit.com/submit?url=${u}&title=${t}`],
  ];
  void showModalBottomSheet<void>((close) => (
    <div style={sheetBox}>
      <SheetHandle />
      <div
        style={{
          alignSelf: 'stretch',
          padding: '16px 20px 8px',
          flexShrink: 0,
          ...dmSansStyle({ size: 16, color: T.textPrimary, weight: 700 }),
        }}
      >
        Share
      </div>
      <div style={{ alignSelf: 'stretch', minHeight: 0, overflowY: 'auto' }}>
        {targets.map(([label, icon, link]) => (
          <ListTileRow
            key={label}
            leading={<Icon name={icon} size={20} color={T.textPrimary} />}
            title={label}
            onTap={() => {
              window.open(link, '_blank', 'noopener');
              close(null);
            }}
          />
        ))}
      </div>
      <div style={{ height: 8, flexShrink: 0 }} />
    </div>
  ));
}
