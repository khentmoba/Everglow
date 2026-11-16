import {
  collection,
  deleteDoc,
  doc,
  getDocs,
  limit,
  onSnapshot,
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
import { Changes, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';
import { catalogKeyOf, TmdbImages, type MediaItem } from './cinemaTypes';
import { agentTmdbResponse } from './tmdbAgentCatalogue';

const TMDB_BASE = 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyTmdb';

const demoWatchlist = new Map<string, MediaItem[]>();
const demoWatchlistChanges = new Changes<Record<string, MediaItem[]>>(() => {
  const out: Record<string, MediaItem[]> = {};
  for (const [u, list] of demoWatchlist.entries()) out[u] = list;
  return out;
});

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

async function tmdbJson(pathWithQuery: string): Promise<Record<string, unknown> | null> {
  const url = `${TMDB_BASE}${pathWithQuery.startsWith('/') ? '' : '/'}${pathWithQuery}`;
  if (AgentMode.demo) {
    return agentTmdbResponse(url);
  }
  const user = auth.currentUser;
  if (!user) return null;
  try {
    const token = await user.getIdToken();
    const resp = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(12000),
    });
    if (!resp.ok) return null;
    return (await resp.json()) as Record<string, unknown>;
  } catch (e) {
    Logger.w(`TMDB fetch failed (${pathWithQuery}): ${String(e)}`);
    return null;
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
  const raw = Array.isArray(data?.results) ? (data.results as Record<string, unknown>[]) : [];
  return {
    results: raw.map((r) => mapResult(r, mt)),
    totalPages: Number(data?.total_pages ?? 1) || 1,
  };
}

export async function searchMulti(queryStr: string, page = 1): Promise<{ results: MediaItem[]; totalPages: number }> {
  const q = queryStr.trim();
  if (!q) return { results: [], totalPages: 1 };
  const data = await tmdbJson(`/search/multi?query=${encodeURIComponent(q)}&include_adult=false&page=${page}`);
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
    return (l) =>
      demoWatchlistChanges.source({
        data: (all) => l.data(all[userName] ?? []),
      });
  }
  const q = query(collection(db, 'watch_list'), where('userName', '==', userName), limit(500));
  return withFirestoreTimeout(
    snapshots<QuerySnapshot<DocumentData>, MediaItem[]>(
      (next, error) => onSnapshot(q, next, error),
      (s) =>
        s.docs
          .map((d) => fromFirestoreDoc(d.data(), d.id))
          .sort((a, b) => b.addedAt.getTime() - a.addedAt.getTime()),
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
      demoWatchlist.set(userName, prev.filter((x) => catalogKeyOf(x) !== key));
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
  item: Pick<MediaItem, 'tmdbId' | 'title' | 'mediaType' | 'posterPath' | 'backdropPath' | 'year' | 'isAnime' | 'source'>,
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
  if (AgentMode.demo) {
    const key = catalogKeyOf(item);
    const prev = demoWatchlist.get(userName) ?? [];
    const idx = prev.findIndex((x) => catalogKeyOf(x) === key);
    const updated: MediaItem = {
      ...(idx >= 0 ? prev[idx] : { ...item, id: key, genres: [], synopsis: '', airingStatus: '', format: '', studio: '', remindMe: false, addedAt: new Date(), userName }),
      status: opts.status ?? 'watching-self',
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
    return (
      Number(data.tmdbId ?? 0) === item.tmdbId &&
      String(data.mediaType ?? 'movie').toLowerCase() === item.mediaType.toLowerCase()
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
    status: opts.status ?? 'watching-self',
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
