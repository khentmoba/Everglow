import { AppColors } from '../../core/theme/colors';

export const NetflixColors = {
  background: '#080808',
  surface: '#141414',
  surfaceElevated: '#202020',
  accent: AppColors.cinemaRed,
  gold: AppColors.blushGold,
  textPrimary: '#FFFFFF',
  textSecondary: '#B3B3B3',
  textMuted: '#888888',
  match: AppColors.cinemaMatch,
  hoverScrim: 'rgba(0, 0, 0, 0.3)',
  hairline: 'rgba(255, 255, 255, 0.14)',
} as const;

export const TOP_TEN_COUNTRY_LABEL = 'the Philippines';

export interface MediaItem {
  id: string;
  tmdbId: number;
  title: string;
  mediaType: string;
  posterPath: string;
  backdropPath: string;
  year: string;
  status: string;
  isAnime: boolean;
  userName: string;
  addedAt: Date;
  source: string;
  anilistId?: number;
  synopsis: string;
  episodeCount?: number;
  airingStatus: string;
  format: string;
  studio: string;
  genres: string[];
  score?: number;
  userRating?: number;
  ratedAt?: Date;
  currentSeason?: number;
  currentEpisode?: number;
  currentTimestamp?: number;
  durationSeconds?: number;
  progressUpdatedAt?: Date;
  remindMe: boolean;
  trailerYoutubeId?: string;
}

export function catalogKeyOf(item: Pick<MediaItem, 'tmdbId' | 'anilistId' | 'mediaType' | 'source'>): string {
  const cid = item.tmdbId > 0 ? item.tmdbId : (item.anilistId ?? 0);
  const mt = item.mediaType.trim().toLowerCase() === 'tv' ? 'tv' : 'movie';
  return `${item.source || 'tmdb'}:${mt}:${cid}`;
}

export function resumeSecondsOf(item: MediaItem): number | null {
  const pos = item.currentTimestamp ?? 0;
  if (pos <= 0) return null;
  const dur = item.durationSeconds ?? 0;
  if (dur > 0 && pos / dur >= 0.95) return null;
  return pos;
}

export const TmdbImages = {
  poster: 'https://image.tmdb.org/t/p/w500',
  posterCard: 'https://image.tmdb.org/t/p/w342',
  backdrop: 'https://image.tmdb.org/t/p/w780',
  backdropHero: 'https://image.tmdb.org/t/p/w1280',
  profile: 'https://image.tmdb.org/t/p/w185',
  cardFor(raw: string): string {
    const t = raw.trim();
    if (!t) return '';
    if (t.startsWith('http') || t.startsWith('/')) {
      return t.replace('/t/p/w500/', '/t/p/w342/');
    }
    return `${this.posterCard}${t.startsWith('/') ? '' : '/'}${t}`;
  },
  /** Flutter TmdbImages._resolve: rebases TMDB URLs and raw paths onto `base`. */
  resolve(path: string | null | undefined, base: string): string {
    const t = (path ?? '').trim();
    if (!t || ['null', 'undefined', 'false', 'none', 'nan'].includes(t.toLowerCase()) || /\s/.test(t)) return '';
    if (t.startsWith('assets/')) return t;
    const m = /^https?:\/\/image\.tmdb\.org\/t\/p\/[^/]+(\/.+)$/.exec(t);
    if (m) return `${base}${m[1]}`;
    if (t.startsWith('http')) return t;
    return `${base}${t.startsWith('/') ? t : `/${t}`}`;
  },
  posterFor(path?: string | null): string {
    return this.resolve(path, this.poster);
  },
  stillFor(path?: string | null): string {
    return this.resolve(path, 'https://image.tmdb.org/t/p/w300');
  },
  backdropOf(path?: string | null, large = false): string {
    return this.resolve(path, large ? this.backdropHero : this.backdrop);
  },
  backdropFor(raw: string): string {
    const t = raw.trim();
    if (!t) return '';
    if (t.startsWith('http') || t.startsWith('/')) return t;
    return `${this.backdrop}${t.startsWith('/') ? '' : '/'}${t}`;
  },
};
