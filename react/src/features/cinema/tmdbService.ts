import {
  collection,
  deleteDoc,
  doc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  type DocumentData,
  type QuerySnapshot,
  type Timestamp,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { auth, db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { Changes, snapshots, withFirestoreTimeout, withGetTimeout, type Source } from '../../core/utils/liveSource';
import { catalogKeyOf, TmdbImages, type MediaItem } from './cinemaTypes';
import { agentTmdbResponse } from './tmdbAgentCatalogue';

const TMDB_BASE = 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyTmdb';

const demoWatchlist = new Map<string, MediaItem[]>();
const demoWatchlistChanges = new Changes<Record<string, MediaItem[]>>(() => {
  const out: Record<string, MediaItem[]> = {};
  for (const [u, list] of demoWatchlist.entries()) out[u] = list;
  return out;
});

function ensureDemoWatchlist(userName: string): MediaItem[] {
  const existing = demoWatchlist.get(userName);
  if (existing) return existing;
  const seeded: MediaItem[] = [
    {
      id: 'demo_anime_watching',
      tmdbId: 21,
      anilistId: 21,
      title: 'Demo Anime Adventure',
      mediaType: 'tv',
      posterPath: '/images/demo/poster-3.jpg',
      backdropPath: '/images/demo/poster-3.jpg',
      year: '2026',
      status: 'watching-self',
      isAnime: true,
      userName,
      addedAt: new Date(2026, 1, 15),
      progressUpdatedAt: new Date(2026, 1, 18),
      source: 'jikan',
      synopsis: 'A fictional ongoing anime demo entry.',
      airingStatus: 'RELEASING',
      format: 'TV',
      studio: 'Demo Studio',
      genres: ['Adventure', 'Fantasy'],
      episodeCount: 12,
      currentEpisode: 5,
      currentTimestamp: 425,
      durationSeconds: 1440,
      remindMe: false,
    },
    {
      id: 'demo_anime_watched',
      tmdbId: 16498,
      anilistId: 16498,
      title: 'Demo Finished Quest',
      mediaType: 'tv',
      posterPath: '/images/demo/poster-4.jpg',
      backdropPath: '/images/demo/poster-4.jpg',
      year: '2025',
      status: 'watched-self',
      isAnime: true,
      userName,
      addedAt: new Date(2026, 1, 10),
      progressUpdatedAt: new Date(2026, 1, 17),
      source: 'jikan',
      synopsis: 'A fictional completed anime demo entry.',
      airingStatus: 'FINISHED',
      format: 'TV',
      studio: 'Demo Studio',
      genres: ['Action'],
      episodeCount: 25,
      currentEpisode: 25,
      currentTimestamp: 1400,
      durationSeconds: 1440,
      remindMe: false,
    },
  ];
  demoWatchlist.set(userName, seeded);
  return seeded;
}

function detectAnime(item: Record<string, unknown>): boolean {
  const lang = String(item.original_language ?? '').toLowerCase();
  const genres = Array.isArray(item.genre_ids)
    ? item.genre_ids.map(Number)
    : Array.isArray(item.genres)
      ? item.genres.map((g) => Number((g as Record<string, unknown>)?.id ?? 0))
      : [];
  return lang === 'ja' && genres.includes(16);
}

function mapResult(item: Record<string, unknown>, forcedType?: string): MediaItem {
  const mediaType = forcedType ?? String(item.media_type ?? 'movie');
  const title =
    mediaType === 'movie'
      ? String(item.title ?? item.name ?? 'Unknown Title')
      : String(item.name ?? item.title ?? 'Unknown Title');
  const poster = typeof item.poster_path === 'string' ? item.poster_path : '';
  const backdrop = typeof item.backdrop_path === 'string' ? item.backdrop_path : '';
  const releaseDate = String(item.release_date ?? item.first_air_date ?? '');
  return {
    id: '',
    tmdbId: Number(item.id ?? 0) || 0,
    title,
    mediaType,
    posterPath: poster ? `${TmdbImages.poster}${poster}` : '',
    backdropPath: backdrop ? `${TmdbImages.backdrop}${backdrop}` : '',
    year: releaseDate.length >= 4 ? releaseDate.slice(0, 4) : '',
    status: '',
    isAnime: detectAnime(item),
    userName: '',
    addedAt: new Date(),
    source: 'tmdb',
    synopsis: String(item.overview ?? ''),
    airingStatus: '',
    format: '',
    studio: '',
    genres: Array.isArray(item.genres)
      ? item.genres.map((g) => String((g as Record<string, unknown>)?.name ?? '')).filter(Boolean)
      : [],
    score: typeof item.vote_average === 'number' ? item.vote_average : undefined,
    remindMe: false,
  };
}

function fromFirestoreDoc(data: Record<string, unknown>, id: string): MediaItem {
  const poster = String(data.posterPath ?? '');
  const backdrop = String(data.backdropPath ?? '');
  const tsAdded = data.addedAt as Timestamp | undefined;
  const tsProg = data.progressUpdatedAt as Timestamp | undefined;
  const tsRated = data.ratedAt as Timestamp | undefined;
  return {
    id,
    tmdbId: Number(data.tmdbId ?? 0) || 0,
    title: String(data.title ?? 'Unknown Title'),
    mediaType: String(data.mediaType ?? 'movie'),
    posterPath: poster,
    backdropPath: backdrop,
    year: String(data.year ?? ''),
    status: String(data.status ?? ''),
    isAnime: Boolean(data.isAnime),
    userName: String(data.userName ?? ''),
    addedAt: tsAdded?.toDate ? tsAdded.toDate() : new Date(),
    source: String(data.source ?? 'tmdb'),
    anilistId: typeof data.anilistId === 'number' ? data.anilistId : undefined,
    synopsis: String(data.synopsis ?? ''),
    episodeCount: typeof data.episodeCount === 'number' ? data.episodeCount : undefined,
    airingStatus: String(data.airingStatus ?? ''),
    format: String(data.format ?? ''),
    studio: String(data.studio ?? ''),
    genres: Array.isArray(data.genres) ? data.genres.map(String) : [],
    score: typeof data.score === 'number' ? data.score : undefined,
    userRating: typeof data.userRating === 'number' ? data.userRating : undefined,
    ratedAt: tsRated?.toDate ? tsRated.toDate() : undefined,
    currentSeason: typeof data.currentSeason === 'number' ? data.currentSeason : undefined,
    currentEpisode: typeof data.currentEpisode === 'number' ? data.currentEpisode : undefined,
    currentTimestamp: typeof data.currentTimestamp === 'number' ? data.currentTimestamp : undefined,
    durationSeconds: typeof data.durationSeconds === 'number' ? data.durationSeconds : undefined,
    progressUpdatedAt: tsProg?.toDate ? tsProg.toDate() : undefined,
    remindMe: Boolean(data.remindMe),
    trailerYoutubeId: typeof data.trailerYoutubeId === 'string' ? data.trailerYoutubeId : undefined,
  };
}

const TMDB_CACHE_TTL_MS = 5 * 60 * 1000;
const TMDB_CACHE_MAX = 120;
const tmdbCache = new Map<string, { data: Record<string, unknown>; ts: number }>();
const tmdbInFlight = new Map<string, Promise<Record<string, unknown> | null>>();

function getCachedTmdb(key: string): Record<string, unknown> | null {
  const entry = tmdbCache.get(key);
  if (!entry) return null;
  if (Date.now() - entry.ts > TMDB_CACHE_TTL_MS) {
    tmdbCache.delete(key);
    return null;
  }
  return entry.data;
}

function setCachedTmdb(key: string, data: Record<string, unknown>): void {
  tmdbCache.delete(key);
  tmdbCache.set(key, { data, ts: Date.now() });
  if (tmdbCache.size > TMDB_CACHE_MAX) {
    const oldest = tmdbCache.keys().next().value;
    if (oldest !== undefined) tmdbCache.delete(oldest);
  }
}

async function tmdbJson(pathWithQuery: string): Promise<Record<string, unknown> | null> {
  const normalizedPath = pathWithQuery.startsWith('/') ? pathWithQuery : `/${pathWithQuery}`;
  const url = `${TMDB_BASE}${normalizedPath}`;
  if (AgentMode.demo) {
    return agentTmdbResponse(url);
  }
  const cached = getCachedTmdb(normalizedPath);
  if (cached) return cached;
  const pending = tmdbInFlight.get(normalizedPath);
  if (pending) return pending;

  const task = (async (): Promise<Record<string, unknown> | null> => {
    await auth.authStateReady();
    const user = auth.currentUser;
    if (!user) return null;
    try {
      const token = await user.getIdToken();
      const resp = await fetch(url, {
        headers: { Authorization: `Bearer ${token}` },
        signal: AbortSignal.timeout(12000),
      });
      if (!resp.ok) return null;
      const data = (await resp.json()) as Record<string, unknown>;
      setCachedTmdb(normalizedPath, data);
      return data;
    } catch (e) {
      Logger.w(`TMDB fetch failed (${pathWithQuery}): ${String(e)}`);
      return null;
    }
  })();

  tmdbInFlight.set(normalizedPath, task);
  try {
    return await task;
  } finally {
    tmdbInFlight.delete(normalizedPath);
  }
}

export async function fetchTrending(region = 'all', timeWindow = 'week'): Promise<MediaItem[]> {
  const data = await tmdbJson(`/trending/${region}/${timeWindow}`);
  const results = Array.isArray(data?.results) ? (data.results as Record<string, unknown>[]) : [];
  return results.map((r) => mapResult(r));
}

export async function fetchTrendingByCountry(countryCode: string): Promise<MediaItem[]> {
  const data = await tmdbJson(`/trending/all/day?region=${encodeURIComponent(countryCode)}`);
  const results = Array.isArray(data?.results) ? (data.results as Record<string, unknown>[]) : [];
  return results.map((r) => mapResult(r));
}

export async function fetchPopularTVShows(page = 1): Promise<MediaItem[]> {
  const data = await tmdbJson(`/tv/popular?page=${page}`);
  const results = Array.isArray(data?.results) ? (data.results as Record<string, unknown>[]) : [];
  return results.map((r) => mapResult(r, 'tv'));
}

export async function fetchUpcoming(region = 'PH', page = 1): Promise<MediaItem[]> {
  const data = await tmdbJson(`/movie/upcoming?region=${encodeURIComponent(region)}&page=${page}`);
  const results = Array.isArray(data?.results) ? (data.results as Record<string, unknown>[]) : [];
  return results.map((r) => mapResult(r, 'movie'));
}

export async function discoverMedia(opts: {
  mediaType?: 'movie' | 'tv';
  sortBy?: string;
  withGenres?: number[];
  withoutGenres?: number[];
  withOriginalLanguage?: string;
  yearGte?: number;
  yearLte?: number;
  voteAverageGte?: number;
  voteCountGte?: number;
  page?: number;
  /** Throw instead of returning an empty page when the request fails. */
  failOnError?: boolean;
}): Promise<{ results: MediaItem[]; totalPages: number }> {
  const mt = opts.mediaType ?? 'movie';
  const params = new URLSearchParams({
    include_adult: 'false',
    page: String(opts.page ?? 1),
    sort_by: opts.sortBy ?? 'popularity.desc',
  });
  if (opts.withGenres?.length) params.set('with_genres', opts.withGenres.join(','));
  if (opts.withoutGenres?.length) params.set('without_genres', opts.withoutGenres.join(','));
  if (opts.withOriginalLanguage) params.set('with_original_language', opts.withOriginalLanguage);
  if (opts.yearGte) {
    params.set(mt === 'movie' ? 'primary_release_date.gte' : 'first_air_date.gte', `${opts.yearGte}-01-01`);
  }
  if (opts.yearLte) {
    params.set(mt === 'movie' ? 'primary_release_date.lte' : 'first_air_date.lte', `${opts.yearLte}-12-31`);
  }
  if (opts.voteAverageGte) params.set('vote_average.gte', String(opts.voteAverageGte));
  if (opts.voteCountGte) params.set('vote_count.gte', String(opts.voteCountGte));

  const data = await tmdbJson(`/discover/${mt}?${params.toString()}`);
  if (data == null && opts.failOnError) throw new Error(`TMDB discover failed (${mt})`);
  const raw = Array.isArray(data?.results) ? (data.results as Record<string, unknown>[]) : [];
  return {
    results: raw.map((r) => mapResult(r, mt)),
    totalPages: Number(data?.total_pages ?? 1) || 1,
  };
}

export async function searchMulti(
  queryStr: string,
  page = 1,
  { failOnError = false }: { failOnError?: boolean } = {},
): Promise<{ results: MediaItem[]; totalPages: number }> {
  const q = queryStr.trim();
  if (!q) return { results: [], totalPages: 1 };
  const data = await tmdbJson(`/search/multi?query=${encodeURIComponent(q)}&include_adult=false&page=${page}`);
  if (data == null && failOnError) throw new Error('TMDB search failed');
  const raw = Array.isArray(data?.results) ? (data.results as Record<string, unknown>[]) : [];
  const filtered = raw.filter((r) => r.media_type === 'movie' || r.media_type === 'tv' || AgentMode.demo);
  return {
    results: filtered.map((r) => mapResult(r)),
    totalPages: Number(data?.total_pages ?? 1) || 1,
  };
}

export async function fetchMediaDetails(tmdbId: number, mediaType: string): Promise<Record<string, unknown> | null> {
  return tmdbJson(`/${mediaType}/${tmdbId}?append_to_response=videos,release_dates,content_ratings`);
}

export interface CastMember {
  id: number;
  name: string;
  character: string;
  profilePath: string;
}

export async function fetchCredits(tmdbId: number, mediaType: string): Promise<CastMember[]> {
  const data = await tmdbJson(`/${mediaType}/${tmdbId}/credits`);
  const cast = Array.isArray(data?.cast) ? (data.cast as Record<string, unknown>[]) : [];
  return cast.slice(0, 15).map((c) => ({
    id: Number(c.id ?? 0),
    name: String(c.name ?? 'Unknown'),
    character: String(c.character ?? ''),
    profilePath: typeof c.profile_path === 'string' && c.profile_path ? `${TmdbImages.profile}${c.profile_path}` : '',
  }));
}

export async function fetchSimilar(tmdbId: number, mediaType: string): Promise<MediaItem[]> {
  const data = await tmdbJson(`/${mediaType}/${tmdbId}/similar`);
  const raw = Array.isArray(data?.results) ? (data.results as Record<string, unknown>[]) : [];
  return raw.map((r) => mapResult(r, mediaType));
}

export interface TvEpisode {
  id: number;
  episodeNumber: number;
  seasonNumber: number;
  name: string;
  overview: string;
  stillPath: string;
  runtime?: number;
  airDate?: string;
  /** The raw `still_path` (TmdbImages rebases it). */
  stillRaw?: string;
}

export async function fetchSeasonEpisodes(tmdbId: number, seasonNumber: number): Promise<TvEpisode[]> {
  const data = await tmdbJson(`/tv/${tmdbId}/season/${seasonNumber}`);
  const raw = Array.isArray(data?.episodes) ? (data.episodes as Record<string, unknown>[]) : [];
  return raw.map((e) => ({
    id: Number(e.id ?? 0),
    episodeNumber: Number(e.episode_number ?? 1),
    seasonNumber: Number(e.season_number ?? seasonNumber),
    name: String(e.name ?? `Episode ${e.episode_number ?? 1}`),
    overview: String(e.overview ?? ''),
    stillPath: typeof e.still_path === 'string' && e.still_path ? `${TmdbImages.backdrop}${e.still_path}` : '',
    runtime: typeof e.runtime === 'number' ? e.runtime : undefined,
    airDate: typeof e.air_date === 'string' ? e.air_date : undefined,
    stillRaw: typeof e.still_path === 'string' ? e.still_path : undefined,
  }));
}

export function watchCinemaWatchlist(userName: string): Source<MediaItem[]> {
  if (!userName) {
    return (l) => {
      queueMicrotask(() => l.data([]));
      return () => {};
    };
  }
  if (AgentMode.demo) {
    ensureDemoWatchlist(userName);
    return (l) =>
      demoWatchlistChanges.source({
        data: (all) => l.data(all[userName] ?? []),
      });
  }
  const q = query(collection(db, 'watch_list'), where('userName', '==', userName), limit(500));
  return withFirestoreTimeout(
    snapshots<QuerySnapshot<DocumentData>, MediaItem[]>(
      (next, error) => onSnapshot(q, next, error),
      (s) => s.docs.map((d) => fromFirestoreDoc(d.data(), d.id)).sort((a, b) => b.addedAt.getTime() - a.addedAt.getTime()),
    ),
    { label: `cinema-watchlist-${userName}` },
  );
}

export async function setListMembership(item: MediaItem, userName: string, add: boolean): Promise<void> {
  const key = catalogKeyOf(item);
  if (AgentMode.demo) {
    const prev = demoWatchlist.get(userName) ?? [];
    if (add) {
      if (!prev.some((x) => catalogKeyOf(x) === key)) {
        demoWatchlist.set(userName, [{ ...item, status: 'to-watch', userName, addedAt: new Date() }, ...prev]);
      }
    } else {
      demoWatchlist.set(
        userName,
        prev.filter((x) => catalogKeyOf(x) !== key),
      );
    }
    demoWatchlistChanges.emit();
    return;
  }

  const snap = await getDocs(query(collection(db, 'watch_list'), where('userName', '==', userName), limit(500)));
  const existing = snap.docs.find((d) => {
    const data = d.data();
    return (
      Number(data.tmdbId ?? 0) === item.tmdbId &&
      String(data.source ?? 'tmdb') === (item.source || 'tmdb') &&
      String(data.mediaType ?? 'movie').toLowerCase() === item.mediaType.toLowerCase()
    );
  });

  if (add) {
    if (existing) {
      await updateDoc(existing.ref, { status: 'to-watch', title: item.title, posterPath: item.posterPath });
    } else {
      const ref = doc(collection(db, 'watch_list'));
      await setDoc(ref, {
        tmdbId: item.tmdbId,
        title: item.title,
        mediaType: item.mediaType,
        posterPath: item.posterPath,
        backdropPath: item.backdropPath,
        year: item.year,
        status: 'to-watch',
        isAnime: item.isAnime,
        userName,
        source: item.source || 'tmdb',
        genres: item.genres,
        score: item.score ?? null,
        addedAt: serverTimestamp(),
      });
    }
  } else if (existing) {
    await deleteDoc(existing.ref);
  }
}

export async function saveWatchProgress(
  item: Pick<
    MediaItem,
    'tmdbId' | 'title' | 'mediaType' | 'posterPath' | 'backdropPath' | 'year' | 'isAnime' | 'source' | 'anilistId' | 'episodeCount' | 'format'
  >,
  userName: string,
  opts: {
    season?: number;
    episode?: number;
    timestamp?: number;
    durationSeconds?: number;
    status?: string;
  },
): Promise<void> {
  if (!userName) return;
  const isMovie = item.mediaType.trim().toLowerCase() !== 'tv' || (item.format ?? '').trim().toLowerCase() === 'movie';
  const finale = !isMovie && item.episodeCount != null && item.episodeCount > 1 && opts.episode != null && opts.episode >= item.episodeCount;
  const effectiveStatus =
    finale && (opts.status == null || opts.status.toLowerCase().includes('watching'))
      ? 'watched-self'
      : (opts.status ?? 'watching-self');

  if (AgentMode.demo) {
    const key = catalogKeyOf(item);
    const prev = demoWatchlist.get(userName) ?? [];
    const idx = prev.findIndex((x) => catalogKeyOf(x) === key);
    const updated: MediaItem = {
      ...(idx >= 0
        ? prev[idx]
        : {
            ...item,
            id: key,
            genres: [],
            synopsis: '',
            airingStatus: '',
            format: item.format ?? '',
            studio: '',
            remindMe: false,
            addedAt: new Date(),
            userName,
          }),
      status: effectiveStatus,
      currentSeason: opts.season,
      currentEpisode: opts.episode,
      currentTimestamp: opts.timestamp,
      durationSeconds: opts.durationSeconds,
      progressUpdatedAt: new Date(),
    };
    const next = [...prev];
    if (idx >= 0) next[idx] = updated;
    else next.unshift(updated);
    demoWatchlist.set(userName, next);
    demoWatchlistChanges.emit();
    return;
  }

  const snap = await getDocs(query(collection(db, 'watch_list'), where('userName', '==', userName), limit(500)));
  const existing = snap.docs.find((d) => {
    const data = d.data();
    if (item.isAnime && (item.anilistId ?? 0) > 0 && data.anilistId === item.anilistId) return true;
    return (
      Number(data.tmdbId ?? 0) === item.tmdbId && String(data.mediaType ?? 'movie').toLowerCase() === item.mediaType.toLowerCase()
    );
  });
  const payload = {
    tmdbId: item.tmdbId,
    title: item.title,
    mediaType: item.mediaType,
    posterPath: item.posterPath,
    backdropPath: item.backdropPath,
    year: item.year,
    isAnime: item.isAnime,
    userName,
    source: item.source || 'tmdb',
    status: effectiveStatus,
    ...(item.anilistId != null ? { anilistId: item.anilistId } : {}),
    ...(item.episodeCount != null ? { episodeCount: item.episodeCount } : {}),
    ...(item.format ? { format: item.format } : {}),
    ...(opts.season != null ? { currentSeason: opts.season } : {}),
    ...(opts.episode != null ? { currentEpisode: opts.episode } : {}),
    ...(opts.timestamp != null ? { currentTimestamp: opts.timestamp } : {}),
    ...(opts.durationSeconds != null ? { durationSeconds: opts.durationSeconds } : {}),
    progressUpdatedAt: serverTimestamp(),
  };
  if (existing) {
    await updateDoc(existing.ref, payload);
  } else {
    const ref = doc(collection(db, 'watch_list'));
    await setDoc(ref, { ...payload, addedAt: serverTimestamp() });
  }
}

export async function clearWatchProgress(item: MediaItem, userName: string): Promise<void> {
  if (!userName) return;
  if (AgentMode.demo) {
    const key = catalogKeyOf(item);
    demoWatchlist.set(
      userName,
      (demoWatchlist.get(userName) ?? []).map((x) =>
        catalogKeyOf(x) === key ? { ...x, status: 'to-watch', currentTimestamp: undefined, durationSeconds: undefined } : x,
      ),
    );
    demoWatchlistChanges.emit();
    return;
  }
  if (item.id) {
    await updateDoc(doc(db, 'watch_list', item.id), {
      status: 'to-watch',
      currentTimestamp: null,
      durationSeconds: null,
      progressUpdatedAt: null,
    });
  }
}

const WATCHED = new Set(['watched', 'watched-khent', 'watched-clair', 'watched-both', 'watched-self']);
const WATCHING = new Set(['watching', 'watching-khent', 'watching-clair', 'watching-both', 'watching-self', 'watching-together']);

export function isSeriesCompleted(
  item: Pick<MediaItem, 'mediaType' | 'format' | 'episodeCount' | 'currentEpisode'>,
): boolean {
  const isMovie = item.mediaType.trim().toLowerCase() !== 'tv' || item.format.trim().toLowerCase() === 'movie';
  if (isMovie || item.episodeCount == null || item.episodeCount <= 1 || item.currentEpisode == null) return false;
  return item.currentEpisode >= item.episodeCount;
}

/** `MediaItem.isWatched`: a watched status, or a series whose last episode is reached. */
export function isWatchedItem(item: MediaItem): boolean {
  if (WATCHED.has(item.status.trim().toLowerCase())) return true;
  return isSeriesCompleted(item);
}

/** `MediaItem.isCurrentlyWatching`: actively watching and not yet completed. */
export function isCurrentlyWatchingItem(item: MediaItem): boolean {
  if (isWatchedItem(item)) return false;
  const s = item.status.trim().toLowerCase();
  return WATCHING.has(s) || s.includes('watching');
}

/** `getWatchListFromThisDay`: titles added on today's date in earlier years (none in agent mode). */
export async function getWatchListFromThisDay(): Promise<MediaItem[]> {
  if (AgentMode.isActive.value) return [];
  const now = new Date();
  const md = `${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
  try {
    const col = collection(db, 'watch_list');
    let snap = await withGetTimeout(getDocs(query(col, where('monthDay', '==', md), limit(200))), 'watchlist on-this-day');
    if (snap.empty) {
      snap = await withGetTimeout(getDocs(query(col, orderBy('addedAt', 'desc'), limit(500))), 'watchlist on-this-day fallback');
    }
    const seen = new Set<string>();
    const out: MediaItem[] = [];
    for (const d of snap.docs) {
      const item = fromFirestoreDoc(d.data(), d.id);
      const key = catalogKeyOf(item);
      if (
        item.addedAt.getMonth() === now.getMonth() &&
        item.addedAt.getDate() === now.getDate() &&
        item.addedAt.getFullYear() !== now.getFullYear() &&
        !seen.has(key)
      ) {
        seen.add(key);
        out.push(item);
      }
    }
    return out;
  } catch (e) {
    Logger.e('Error getting on-this-day watchlist items', e);
    return [];
  }
}

export interface CinemaReview {
  id: string;
  author: string;
  content: string;
  rating?: number;
  avatar: string;
}

export async function fetchReviews(tmdbId: number, mediaType: string): Promise<CinemaReview[]> {
  const data = await tmdbJson(`/${mediaType}/${tmdbId}/reviews`);
  const raw = Array.isArray(data?.results) ? (data.results as Record<string, unknown>[]) : [];
  return raw.slice(0, 8).map((r) => {
    const details = (r.author_details ?? {}) as Record<string, unknown>;
    return {
      id: String(r.id ?? ''),
      author: String(r.author ?? 'Anonymous'),
      content: String(r.content ?? ''),
      rating: typeof details.rating === 'number' ? details.rating : undefined,
      avatar: typeof details.avatar_path === 'string' ? `${TmdbImages.profile}${details.avatar_path}` : '',
    };
  });
}

const trailerCache = new Map<string, string | null>();

/** TMDBTrailerService.fetchTrailerKey: official YouTube trailer, then any trailer, then any YouTube video. */
export async function fetchTrailerKey(tmdbId: number, mediaType: string): Promise<string | null> {
  const cacheKey = `${mediaType}_${tmdbId}`;
  if (trailerCache.has(cacheKey)) return trailerCache.get(cacheKey)!;
  const data = await tmdbJson(`/${mediaType}/${tmdbId}/videos`);
  if (data == null) return null;
  const results = Array.isArray(data.results) ? (data.results as Record<string, unknown>[]) : [];
  const trailer =
    results.find((v) => v.site === 'YouTube' && v.type === 'Trailer' && v.official === true) ??
    results.find((v) => v.site === 'YouTube' && v.type === 'Trailer') ??
    results.find((v) => v.site === 'YouTube');
  const key = typeof trailer?.key === 'string' ? trailer.key : null;
  if (trailerCache.size >= 80 && !trailerCache.has(cacheKey)) trailerCache.delete(trailerCache.keys().next().value!);
  trailerCache.set(cacheKey, key);
  return key;
}

export async function isAnimeByTmdbId(tmdbId: number, mediaType: string): Promise<boolean> {
  const details = await fetchMediaDetails(tmdbId, mediaType);
  return details != null && detectAnime(details);
}

const COUPLE_USERS = new Set(['khentsgdz', 'clairjassen']);
const COUPLE_STATUSES = new Set(['watching-khent', 'watching-clair', 'watching-both', 'watched-khent', 'watched-clair', 'watched-both']);

/** TMDBWatchlistService.resolveStatusOwner: partner statuses live on that partner's doc. */
export function resolveStatusOwner(status: string): string | null {
  if (status === 'watched-clair' || status === 'watching-clair') return 'clairjassen';
  if (status === 'watched-khent' || status === 'watching-khent') return 'khentsgdz';
  return null;
}

function toSelfStatus(status: string): string {
  if (status === 'watched-clair' || status === 'watched-khent') return 'watched-self';
  if (status === 'watching-clair' || status === 'watching-khent') return 'watching-self';
  return status;
}

const catalogIdOf = (item: MediaItem) => (item.tmdbId > 0 ? item.tmdbId : (item.anilistId ?? 0));

async function findCatalogDoc(item: MediaItem, userName: string) {
  const id = catalogIdOf(item);
  const snap = await getDocs(query(collection(db, 'watch_list'), where('tmdbId', '==', id), where('userName', '==', userName), limit(20)));
  const mt = (v: unknown) => (String(v ?? 'movie').trim().toLowerCase() === 'tv' ? 'tv' : 'movie');
  return snap.docs.find((d) => {
    const data = d.data();
    return data.tmdbId === id && (data.source ?? 'tmdb') === item.source && mt(data.mediaType) === mt(item.mediaType);
  });
}

function demoUpsert(item: MediaItem, userName: string, status: string | null) {
  const key = catalogKeyOf(item);
  const prev = demoWatchlist.get(userName) ?? [];
  const rest = prev.filter((x) => catalogKeyOf(x) !== key);
  const old = prev.find((x) => catalogKeyOf(x) === key);
  demoWatchlist.set(userName, status == null ? rest : [{ ...(old ?? item), status, userName, addedAt: new Date() }, ...rest]);
  demoWatchlistChanges.emit();
}

/** TMDBWatchlistService.saveToWatchList. */
export async function saveToWatchList(
  item: MediaItem,
  status: string,
  userName: string,
  opts: { isAnimeOverride?: boolean | null; statusOwner?: string | null } = {},
): Promise<void> {
  if (!userName) return;
  const isCoupleOwner = COUPLE_USERS.has(userName);
  if (!isCoupleOwner && COUPLE_STATUSES.has(status)) return;
  if (opts.statusOwner != null && (!isCoupleOwner || !COUPLE_USERS.has(opts.statusOwner))) return;
  const owner = opts.statusOwner ?? userName;
  const effectiveStatus = toSelfStatus(status);
  if (AgentMode.demo) {
    demoUpsert(item, owner, effectiveStatus);
    return;
  }
  const isAnime = opts.isAnimeOverride ?? item.isAnime;
  const existing = await findCatalogDoc(item, owner);
  if (existing) {
    await updateDoc(existing.ref, {
      status: effectiveStatus,
      isAnime,
      addedAt: serverTimestamp(),
      backdropPath: item.backdropPath,
      title: item.title,
      year: item.year,
      mediaType: item.mediaType,
      source: item.source,
      ...(item.posterPath ? { posterPath: item.posterPath } : {}),
    });
  } else {
    await setDoc(doc(collection(db, 'watch_list')), {
      tmdbId: catalogIdOf(item),
      title: item.title,
      mediaType: item.mediaType,
      posterPath: item.posterPath,
      backdropPath: item.backdropPath,
      year: item.year,
      status: effectiveStatus,
      isAnime,
      userName: owner,
      source: item.source || 'tmdb',
      ...(item.anilistId != null ? { anilistId: item.anilistId } : {}),
      synopsis: item.synopsis,
      genres: item.genres,
      ...(item.score != null ? { score: item.score } : {}),
      addedAt: serverTimestamp(),
    });
  }
}

/** TMDBWatchlistService.removeFromWatchList. */
export async function removeFromWatchList(item: MediaItem, userName: string): Promise<void> {
  if (!userName) return;
  if (AgentMode.demo) {
    demoUpsert(item, userName, null);
    return;
  }
  const existing = await findCatalogDoc(item, userName);
  if (existing) await deleteDoc(existing.ref);
}

/** TMDBWatchlistService.cleanStalePartnerStatus: drop the opposite watching/watched status left on the viewer's doc. */
export async function cleanStalePartnerStatus(item: MediaItem, userName: string, newStatus: string): Promise<void> {
  if (AgentMode.demo) return;
  const companion: Record<string, string> = {
    'watched-clair': 'watching-clair',
    'watched-khent': 'watching-khent',
    'watching-clair': 'watched-clair',
    'watching-khent': 'watched-khent',
  };
  try {
    const existing = await findCatalogDoc(item, userName);
    const stale = companion[newStatus];
    if (existing && stale && existing.data().status === stale) await updateDoc(existing.ref, { status: 'to-watch' });
  } catch (e) {
    Logger.e('[WatchList] Error cleaning stale partner status', e);
  }
}

const imdbIds = new Map<string, string>();

/** TMDBDetailsService.fetchImdbId. */
export async function fetchImdbId(id: number, mediaType: string): Promise<string | null> {
  if (id <= 0) return null;
  const key = `${mediaType}:${id}`;
  const known = imdbIds.get(key);
  if (known != null) return known || null;
  let value = '';
  try {
    if (mediaType === 'movie') {
      const d = await fetchMediaDetails(id, mediaType);
      if (typeof d?.imdb_id === 'string') value = d.imdb_id;
    } else {
      const d = await tmdbJson(`/${mediaType}/${id}/external_ids`);
      if (typeof d?.imdb_id === 'string') value = d.imdb_id;
    }
  } catch (e) {
    Logger.e(`TMDB IMDB id lookup failed for ${key}`, e);
    return null;
  }
  imdbIds.set(key, value);
  return value || null;
}

const sameCatalogDoc = (data: Record<string, unknown>, id: number, source: string, mediaType: string) => {
  const mt = (v: unknown) => (String(v ?? 'movie').trim().toLowerCase() === 'tv' ? 'tv' : 'movie');
  return data.tmdbId === id && (data.source ?? 'tmdb') === source && mt(data.mediaType) === mt(mediaType);
};

async function catalogDocFor(id: number, userName: string, source: string, mediaType: string) {
  const snap = await withGetTimeout(
    getDocs(query(collection(db, 'watch_list'), where('tmdbId', '==', id), where('userName', '==', userName), limit(20))),
    'watch progress lookup',
  );
  return snap.docs.find((d) => sameCatalogDoc(d.data(), id, source, mediaType));
}

/** TMDBWatchlistService.getSavedProgress (TMDB titles; none in agent mode). */
export async function getSavedProgress(
  catalogId: number,
  userName: string,
  opts: { source: string; mediaType: string },
): Promise<MediaItem | null> {
  if (AgentMode.demo || !userName || catalogId <= 0) return null;
  try {
    const d = await catalogDocFor(catalogId, userName, opts.source, opts.mediaType);
    return d ? fromFirestoreDoc(d.data(), d.id) : null;
  } catch (e) {
    Logger.e('Error reading saved watch progress', e);
    return null;
  }
}

/** TMDBWatchlistService.updateProgress: the player's first save for this episode. */
export async function updateProgress(
  item: MediaItem,
  userName: string,
  opts: { season?: number; episode?: number; timestamp?: number; durationSeconds?: number; status?: string },
): Promise<void> {
  if (!userName) return;
  if (AgentMode.demo) {
    await saveWatchProgress(item, userName, opts);
    return;
  }
  try {
    const id = catalogIdOf(item);
    if (id <= 0) return;
    const existing = item.tmdbId > 0 ? await catalogDocFor(item.tmdbId, userName, item.source, item.mediaType) : undefined;
    let status = opts.status == null ? null : toSelfStatus(opts.status);
    const isMovie = item.mediaType.trim().toLowerCase() !== 'tv' || item.format.trim().toLowerCase() === 'movie';
    const finale = !isMovie && item.episodeCount != null && item.episodeCount > 1 && opts.episode != null && opts.episode >= item.episodeCount;
    if (finale && (status == null || status.startsWith('watching'))) status = 'watched-self';
    const data: Record<string, unknown> = {
      currentSeason: opts.season ?? null,
      currentEpisode: opts.episode ?? null,
      currentTimestamp: opts.timestamp ?? null,
      durationSeconds: opts.durationSeconds ?? null,
      progressUpdatedAt: serverTimestamp(),
    };
    if (status != null) data.status = status;
    if (item.episodeCount != null) data.episodeCount = item.episodeCount;
    if (existing) {
      const old = existing.data();
      if (item.posterPath && !old.posterPath) data.posterPath = item.posterPath;
      if (item.title && !old.title) data.title = item.title;
      await updateDoc(existing.ref, data);
    } else {
      await setDoc(doc(collection(db, 'watch_list')), {
        tmdbId: id,
        title: item.title,
        mediaType: item.mediaType,
        posterPath: item.posterPath,
        backdropPath: item.backdropPath,
        year: item.year,
        isAnime: item.isAnime,
        userName,
        source: item.source || 'tmdb',
        ...data,
        status: status ?? 'watching-self',
        addedAt: serverTimestamp(),
      });
    }
  } catch (e) {
    Logger.e('Error updating watch progress', e);
  }
}

/** TMDBWatchlistService.heartbeatProgress: moves the saved spot without touching the status. */
export async function heartbeatProgress(
  catalogId: number,
  userName: string,
  opts: { source: string; mediaType: string; season?: number; episode?: number; timestamp?: number; durationSeconds?: number },
): Promise<void> {
  if (AgentMode.demo || !userName) return;
  try {
    const existing = await catalogDocFor(catalogId, userName, opts.source, opts.mediaType);
    if (!existing) return;
    const data: Record<string, unknown> = { progressUpdatedAt: serverTimestamp() };
    if (opts.season != null) data.currentSeason = opts.season;
    if (opts.episode != null) data.currentEpisode = opts.episode;
    if (opts.timestamp != null) data.currentTimestamp = opts.timestamp;
    if (opts.durationSeconds != null) data.durationSeconds = opts.durationSeconds;
    await updateDoc(existing.ref, data);
  } catch (e) {
    Logger.e('Error heartbeating progress', e);
  }
}

export async function migrateWatchListOwnership(): Promise<number> {
  if (AgentMode.demo) return 0;
  try {
    const snap = await withGetTimeout(
      getDocs(query(collection(db, 'watch_list'), limit(500))),
      'watchlist ownership migration scan',
    );
    let migrated = 0;
    for (const d of snap.docs) {
      const data = d.data();
      if (typeof data.userName === 'string' && data.userName !== '') continue;
      const status = typeof data.status === 'string' ? data.status : 'to-watch';
      const owner = resolveStatusOwner(status) ?? 'khentsgdz';
      await updateDoc(d.ref, { userName: owner });
      migrated++;
    }
    if (migrated > 0) Logger.i(`Migrated ${migrated} legacy watch_list items to user-scoped ownership.`);
    return migrated;
  } catch (e) {
    Logger.e('Watchlist migration error', e);
    return 0;
  }
}
