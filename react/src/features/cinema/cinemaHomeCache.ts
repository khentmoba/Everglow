// Port of lib/features/cinema/data/services/cinema_home_cache.dart: the last home
// rails, kept for this session and in the same shared_preferences key, so Cinema
// opens with posters instead of skeletons.
import { Logger } from '../../core/system/logger';
import { Prefs } from '../../core/system/prefs';
import type { MediaItem } from './cinemaTypes';

const PREFS_KEY = 'cinema_home_rows_v1';
export type HomeRows = Record<string, MediaItem[]>;

let session: HomeRows | null = null;
let savedAt: number | null = null;

const toJson = (m: MediaItem) => ({
  tmdbId: m.tmdbId,
  title: m.title,
  mediaType: m.mediaType,
  posterPath: m.posterPath,
  backdropPath: m.backdropPath,
  year: m.year,
  isAnime: m.isAnime,
  source: m.source,
  ...(m.anilistId != null ? { anilistId: m.anilistId } : {}),
  synopsis: m.synopsis,
  ...(m.episodeCount != null ? { episodeCount: m.episodeCount } : {}),
  airingStatus: m.airingStatus,
  format: m.format,
  studio: m.studio,
  ...(m.genres.length ? { genres: m.genres } : {}),
  ...(m.score != null ? { score: m.score } : {}),
  ...(m.userRating != null ? { userRating: m.userRating } : {}),
  ...(m.ratedAt ? { ratedAt: m.ratedAt.getTime() } : {}),
  ...(m.trailerYoutubeId ? { trailerYoutubeId: m.trailerYoutubeId } : {}),
  addedAt: m.addedAt.getTime(),
});

function fromJson(j: Record<string, unknown>): MediaItem {
  const num = (v: unknown) => (typeof v === 'number' ? v : undefined);
  const str = (v: unknown, d = '') => (typeof v === 'string' ? v : d);
  return {
    id: '',
    tmdbId: Math.trunc(num(j.tmdbId) ?? 0),
    title: str(j.title),
    mediaType: str(j.mediaType, 'tv'),
    posterPath: str(j.posterPath),
    backdropPath: str(j.backdropPath),
    year: str(j.year),
    status: '',
    isAnime: j.isAnime === true,
    userName: '',
    addedAt: new Date(Math.trunc(num(j.addedAt) ?? 0)),
    source: str(j.source, 'jikan'),
    anilistId: num(j.anilistId),
    synopsis: str(j.synopsis),
    episodeCount: num(j.episodeCount),
    airingStatus: str(j.airingStatus),
    format: str(j.format),
    studio: str(j.studio),
    genres: Array.isArray(j.genres) ? j.genres.filter((g): g is string => typeof g === 'string') : [],
    score: num(j.score),
    userRating: num(j.userRating),
    ratedAt: typeof j.ratedAt === 'number' ? new Date(j.ratedAt) : undefined,
    remindMe: false,
    trailerYoutubeId: typeof j.trailerYoutubeId === 'string' ? j.trailerYoutubeId : undefined,
  };
}

export const CinemaHomeCache = {
  get session(): HomeRows | null {
    return session;
  },

  isFresh(windowMs: number): boolean {
    if (!session || savedAt == null) return false;
    return Date.now() - savedAt < windowMs;
  },

  read(): HomeRows | null {
    if (session) return session;
    try {
      const raw = Prefs.getString(PREFS_KEY);
      if (!raw) return null;
      const decoded = JSON.parse(raw) as unknown;
      if (!decoded || typeof decoded !== 'object') return null;
      const d = decoded as Record<string, unknown>;
      const rowsJson = (d.rows && typeof d.rows === 'object' ? d.rows : d) as Record<string, unknown>;
      const rows: HomeRows = {};
      for (const [key, value] of Object.entries(rowsJson)) {
        if (!Array.isArray(value)) continue;
        rows[key] = value.filter((v) => v && typeof v === 'object').map((v) => fromJson(v as Record<string, unknown>));
      }
      if (typeof d.savedAt === 'number') savedAt = d.savedAt;
      session ??= rows;
      return session;
    } catch (e) {
      Logger.e('Cinema: home cache read failed', e);
      return null;
    }
  },

  save(liveRows: HomeRows): void {
    try {
      const merged: HomeRows = { ...(CinemaHomeCache.read() ?? {}) };
      for (const [k, v] of Object.entries(liveRows)) if (v.length) merged[k] = v;
      if (Object.keys(merged).length === 0) return;
      session = merged;
      savedAt = Date.now();
      Prefs.set(
        PREFS_KEY,
        JSON.stringify({
          savedAt,
          rows: Object.fromEntries(Object.entries(merged).map(([k, v]) => [k, v.map(toJson)])),
        }),
      );
    } catch (e) {
      Logger.e('Cinema: home cache save failed', e);
    }
  },
};
