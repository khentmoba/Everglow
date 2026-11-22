// Port of lib/features/cinema/presentation/widgets/episode_drawer.dart with
// `cinemaVariant: true` (and its cinema_* sections): the title details that
// open over Cinema, shown the way cinema_screen._showMediaDetails shows it.
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { useNavigate } from 'react-router';
import { AgentMode } from '../../core/agent/agentMode';
import { useAuth } from '../../core/services/auth';
import { auth as firebaseAuth } from '../../core/services/firebase';
import { OfflineIds, useOfflineMedia } from '../../core/services/offlineMedia';
import { useValue } from '../../core/system/store';
import { Logger } from '../../core/system/logger';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppSpacing } from '../../core/theme/layout';
import { Align, boxShadow, insetBorder, lineHeight, linear, mixedLineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { TextButton } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { LinearProgress } from '../../shared/widgets/LinearProgress';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { fetchAniListDetails, type AniListDetail } from '../anime/animeService';
import { cinemaPreferences } from './cinemaPreferences';
import { NetflixColors, TmdbImages, TOP_TEN_COUNTRY_LABEL, type MediaItem } from './cinemaTypes';
import {
  cleanStalePartnerStatus,
  fetchCredits,
  fetchMediaDetails,
  fetchReviews,
  fetchSeasonEpisodes,
  fetchSimilar,
  fetchTrailerKey,
  isAnimeByTmdbId,
  removeFromWatchList,
  resolveStatusOwner,
  saveToWatchList,
  type CinemaReview,
} from './tmdbService';
import { TrailerPlayer } from './TrailerPlayer';

const WHITE = '#FFFFFF';
const DISCORD_ENDPOINT = 'https://us-central1-everglow-1c6db.cloudfunctions.net/notifyDiscordWatch';
const PARTNER_STATUSES = new Set([
  'watching-khent',
  'watching-clair',
  'watching-both',
  'watched-khent',
  'watched-clair',
  'watched-both',
]);

type Cast = { name: string; character: string; profilePath: string };
type Season = { season_number?: number; name?: string; episode_count?: number };
type Episode = { season?: number; number?: number; name?: string; overview: string; still?: string; runtime?: number };

export function topTenRankFor(topTen: MediaItem[], item: MediaItem): number | null {
  const i = topTen.findIndex((r) => r.tmdbId === item.tmdbId && r.mediaType === item.mediaType);
  return i >= 0 && i < 10 ? i + 1 : null;
}

export function cleanTitle(title: string): string {
  return title.replace(/\s+(Season\s+\d+(\s+Part\s+\d+)?|\d+(st|nd|rd|th)\s+Season)$/i, '');
}

const isMovieItem = (m: MediaItem) => m.mediaType.trim().toLowerCase() !== 'tv' || m.format.trim().toLowerCase() === 'movie';
const WATCHED = new Set(['watched', 'watched-khent', 'watched-clair', 'watched-both', 'watched-self']);
const WATCHING = new Set(['watching', 'watching-khent', 'watching-clair', 'watching-both', 'watching-self']);
const seriesCompleted = (m: MediaItem) =>
  !isMovieItem(m) &&
  m.episodeCount != null &&
  m.episodeCount > 1 &&
  m.currentEpisode != null &&
  m.currentEpisode >= m.episodeCount;
const isWatched = (m: MediaItem) => WATCHED.has(m.status.trim().toLowerCase()) || seriesCompleted(m);

/** MediaItem.resolveCoupleStatus. */
function resolveCoupleStatus(m: MediaItem): string {
  const partners = m.userName
    .split(',')
    .map((u) => u.trim())
    .filter(Boolean);
  const s = m.status;
  if (s === 'watched-both' || s === 'watching-both' || s === 'to-watch') return s;
  if (s === 'watched-self' && partners.length > 1) return 'watched-both';
  if (s === 'watching-self' && partners.length > 1) return 'watching-both';
  if (partners.length !== 1) return s;
  const who = partners[0] === 'khentsgdz' ? 'khent' : partners[0] === 'clairjassen' ? 'clair' : null;
  if (!who) return s;
  if (isWatched(m)) return `watched-${who}`;
  if (!seriesCompleted(m) && WATCHING.has(s.trim().toLowerCase())) return `watching-${who}`;
  return s;
}

function useWidth() {
  const [size, setSize] = useState({ w: window.innerWidth, h: window.innerHeight });
  useEffect(() => {
    const on = () => setSize({ w: window.innerWidth, h: window.innerHeight });
    window.addEventListener('resize', on);
    return () => window.removeEventListener('resize', on);
  }, []);
  return size;
}

const snack = (msg: string) => showSnackBar(msg, { background: NetflixColors.surfaceElevated });

export function CinemaEpisodeDrawer({
  item,
  topTenItems,
  onClose,
  onShowItem,
}: {
  item: MediaItem;
  topTenItems: MediaItem[];
  onClose: () => void;
  /** `_showSimilarItem`: closes this drawer and opens another title. */
  onShowItem: (item: MediaItem) => void;
}) {
  const auth = useAuth();
  const navigate = useNavigate();
  const { w: screenW, h: screenH } = useWidth();
  const isMobile = screenW < 720;
  const isCouple = auth.isCoupleUser;
  const prefs = useValue(cinemaPreferences);
  useEffect(() => cinemaPreferences.setUser(auth.currentUser), [auth.currentUser]);
  const topTenRank = topTenRankFor(topTenItems, item);

  const isAnimeSourced = item.isAnime || item.source === 'jikan' || item.source === 'anilist';
  const [details, setDetails] = useState<Record<string, unknown> | null>(null);
  const [aniDetail, setAniDetail] = useState<AniListDetail | null>(null);
  const [seasons, setSeasons] = useState<Season[]>([]);
  const [selectedSeason, setSelectedSeason] = useState<number | null>(null);
  const [episodes, setEpisodes] = useState<Episode[]>([]);
  const [loadingEpisodes, setLoadingEpisodes] = useState(false);
  const [cast, setCast] = useState<Cast[]>([]);
  const [loadingCast, setLoadingCast] = useState(true);
  const [reviews, setReviews] = useState<CinemaReview[]>([]);
  const [loadingReviews, setLoadingReviews] = useState(true);
  const [similar, setSimilar] = useState<MediaItem[]>([]);
  const [loadingSimilar, setLoadingSimilar] = useState(true);
  const [extraTab, setExtraTab] = useState(0);
  const requested = useRef(new Set<number>());
  const [status, setStatusState] = useState(() => resolveCoupleStatus(item));
  const statusRef = useRef(status);
  const setStatus = (v: string) => {
    statusRef.current = v;
    setStatusState(v);
  };
  const statusQueue = useRef<Promise<void>>(Promise.resolve());
  const [trailerKey, setTrailerKey] = useState<string | null>(null);
  const [muted, setMuted] = useState(true);
  const [sharing, setSharing] = useState(false);
  const alive = useRef(true);
  const selectedRef = useRef<number | null>(null);
  selectedRef.current = selectedSeason;

  const isFilm = (() => {
    if (isMovieItem(item)) return true;
    if (!isAnimeSourced) return false;
    const format = aniDetail?.format ?? item.format;
    const count = aniDetail ? (aniDetail.episodeCount ?? item.episodeCount) : item.episodeCount;
    return format.trim().toLowerCase() === 'movie' || (count === 1 && (aniDetail?.duration ?? 0) >= 60);
  })();
  const malId = aniDetail?.malId ?? item.tmdbId;
  const genreNames: string[] = isAnimeSourced
    ? (aniDetail?.genres ?? [])
    : Array.isArray(details?.genres)
      ? (details.genres as Array<{ name?: string }>).map((g) => String(g?.name ?? '')).filter(Boolean)
      : [];

  const loadEpisodes = async (seasonNumber: number) => {
    if (isMovieItem(item)) {
      setLoadingEpisodes(false);
      setEpisodes([]);
      return;
    }
    setLoadingEpisodes(true);
    setEpisodes([]);
    const eps = await fetchSeasonEpisodes(item.tmdbId, seasonNumber);
    if (!alive.current || selectedRef.current !== seasonNumber) return;
    setEpisodes(
      eps.map((e) => ({
        season: e.seasonNumber,
        number: e.episodeNumber,
        name: e.name,
        overview: e.overview,
        still: e.stillPath || undefined,
        runtime: e.runtime,
      })),
    );
    setLoadingEpisodes(false);
  };

  const selectSeason = (sn: number) => {
    selectedRef.current = sn;
    setSelectedSeason(sn);
    void loadEpisodes(sn);
  };

  // initState: details, trailer, and the first extra tab.
  useEffect(() => {
    alive.current = true;
    void (async () => {
      try {
        if (isAnimeSourced) {
          const d = await fetchAniListDetails({ anilistId: item.anilistId, malId: item.tmdbId });
          if (!alive.current) return;
          if (!d) {
            setDetails({});
            return;
          }
          setAniDetail(d);
          setDetails({
            overview: d.synopsis,
            vote_average: d.averageScore,
            _posterUrl: d.coverImageUrl,
            _backdropUrl: d.bannerImageUrl || d.coverImageUrl,
            _duration: d.duration,
          });
          const film =
            d.format.trim().toLowerCase() === 'movie' || ((d.episodeCount ?? item.episodeCount) === 1 && (d.duration ?? 0) >= 60);
          if (film || isMovieItem(item)) return;
          const count = d.episodeCount && d.episodeCount > 0 ? d.episodeCount : 12;
          setSeasons([{ season_number: 1, name: 'Episodes', episode_count: count }]);
          setSelectedSeason(1);
          const byNum = new Map(d.episodes.map((e) => [e.number, e]));
          setEpisodes(
            Array.from({ length: count }, (_, i) => {
              const e = byNum.get(i + 1);
              return {
                number: i + 1,
                name: e?.title || `Episode ${i + 1}`,
                overview: e?.synopsis ?? '',
                still: e?.thumbnail || d.coverImageUrl || item.posterPath,
              };
            }),
          );
          return;
        }
        const d = await fetchMediaDetails(item.tmdbId, item.mediaType);
        if (!alive.current) return;
        setDetails(d);
        if (item.mediaType === 'tv' && d) {
          const list = (Array.isArray(d.seasons) ? d.seasons : []) as Season[];
          setSeasons(list);
          if (list.length) {
            const first = list.find((s) => s.season_number != null && s.season_number > 0) ?? list[0];
            const chosen = list.find((s) => s.season_number === item.currentSeason) ?? first;
            if (chosen.season_number != null) selectSeason(chosen.season_number);
          }
        }
      } catch {
        // Details show without extra metadata.
      }
    })();
    void (async () => {
      try {
        let key: string | null;
        if (isAnimeSourced) {
          const d = await fetchAniListDetails({ anilistId: item.anilistId, malId: item.tmdbId });
          key = d?.trailerYoutubeId ?? null;
        } else {
          key = await fetchTrailerKey(item.tmdbId, item.mediaType);
        }
        if (alive.current) setTrailerKey(key);
      } catch {
        /* no trailer */
      }
    })();
    requestExtraTab(0);
    return () => {
      alive.current = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function requestExtraTab(index: number) {
    if (requested.current.has(index)) return;
    requested.current.add(index);
    if (index === 0) {
      void (async () => {
        let list: Cast[] = [];
        if (isAnimeSourced) {
          const d = await fetchAniListDetails({ anilistId: item.anilistId, malId: item.tmdbId });
          list = (d?.characters ?? [])
            .filter((c) => c.voiceActorName)
            .map((c) => ({ name: c.voiceActorName!, character: c.name, profilePath: c.voiceActorImageUrl ?? '' }));
        } else {
          list = await fetchCredits(item.tmdbId, item.mediaType);
        }
        if (!alive.current) return;
        setCast(list);
        setLoadingCast(false);
      })();
    } else if (index === 1) {
      window.setTimeout(() => {
        if (!alive.current) return;
        void (isAnimeSourced ? Promise.resolve([]) : fetchReviews(item.tmdbId, item.mediaType))
          .catch(() => [] as CinemaReview[])
          .then((r) => {
            if (!alive.current) return;
            setReviews(r);
            setLoadingReviews(false);
          });
      }, 4000);
    } else {
      void (async () => {
        let list: MediaItem[] = [];
        if (isAnimeSourced) {
          const d = await fetchAniListDetails({ anilistId: item.anilistId, malId: item.tmdbId });
          const seen = new Set<number>();
          const base = { id: '', backdropPath: '', year: '', status: 'to-watch', isAnime: true, userName: '', source: 'jikan' };
          for (const r of [...(d?.seasons ?? []), ...(d?.recommendations ?? [])]) {
            if (r.id === 0 || seen.has(r.id)) continue;
            seen.add(r.id);
            const format = 'format' in r ? r.format : '';
            list.push({
              ...base,
              tmdbId: r.malId ?? r.id,
              anilistId: r.id,
              title: r.title,
              mediaType: format === 'MOVIE' ? 'movie' : 'tv',
              posterPath: r.coverImageUrl,
              addedAt: new Date(),
              synopsis: '',
              airingStatus: '',
              format,
              studio: '',
              genres: [],
              remindMe: false,
            });
          }
        } else {
          list = await fetchSimilar(item.tmdbId, item.mediaType);
        }
        if (!alive.current) return;
        setSimilar(list);
        setLoadingSimilar(false);
      })();
    }
  }

  const selectExtraTab = (i: number) => {
    if (extraTab === i) return;
    setExtraTab(i);
    requestExtraTab(i);
  };

  const resolvePoster = (): MediaItem => {
    if (item.posterPath) return item;
    const poster = isAnimeSourced
      ? (details?._posterUrl as string | undefined)
      : typeof details?.poster_path === 'string' && details.poster_path
        ? TmdbImages.posterFor(details.poster_path)
        : undefined;
    const backdrop = isAnimeSourced
      ? (details?._backdropUrl as string | undefined)
      : typeof details?.backdrop_path === 'string' && details.backdrop_path
        ? TmdbImages.backdropOf(details.backdrop_path)
        : undefined;
    if (!poster && !backdrop) return item;
    return { ...item, posterPath: poster ?? item.posterPath, backdropPath: backdrop ?? item.backdropPath };
  };

  // _EpisodeDrawerStateCore2._doUpdateStatus, queued so taps apply in order.
  const doUpdateStatus = async (next: string, userName: string, partner: string | null, couple: boolean) => {
    if (!alive.current) return;
    if (!userName) {
      snack('Please sign in to manage your watchlist');
      return;
    }
    const previous = statusRef.current;
    if (!couple && previous !== next && PARTNER_STATUSES.has(next)) {
      Logger.w(`[Status] Blocked partner-specific status '${next}' for non-couple user ${userName}`);
      snack('This status is only available to Khent & Clair');
      return;
    }
    const isBoth = (s: string) => s === 'watched-both' || s === 'watching-both';
    if (previous === next) {
      setStatus('');
      snack('Removed from watchlist');
      try {
        let owner = resolveStatusOwner(previous) ?? userName;
        if (!resolveStatusOwner(previous) && !isBoth(previous)) {
          const itemOwner = item.userName.trim();
          if (itemOwner === 'khentsgdz' || itemOwner === 'clairjassen') owner = itemOwner;
        }
        await removeFromWatchList(item, owner);
        if (isBoth(previous) && partner) {
          try {
            await removeFromWatchList(item, partner);
          } catch (e) {
            Logger.e('[Status] Failed to remove from partner', e);
          }
        }
      } catch (e) {
        Logger.e('Failed to remove from watchlist', e);
        if (alive.current) {
          setStatus(previous);
          snack('Failed to remove — please try again');
        }
      }
      return;
    }
    setStatus(next);
    snack('Watchlist updated');
    try {
      let detectedAnime: boolean | null = null;
      if (!item.isAnime) {
        try {
          detectedAnime = await isAnimeByTmdbId(item.tmdbId, item.mediaType);
        } catch {
          /* keep going */
        }
      }
      const resolved = resolvePoster();
      const owner = resolveStatusOwner(next);
      await saveToWatchList(resolved, next, userName, { isAnimeOverride: detectedAnime, statusOwner: owner });
      if (isBoth(next) && partner) {
        try {
          await saveToWatchList(resolved, next, partner, { isAnimeOverride: detectedAnime });
        } catch (e) {
          Logger.e('[Status] Failed to save Both status to partner', e);
        }
      }
      if (owner != null && owner !== userName) await cleanStalePartnerStatus(item, userName, next);
    } catch (e) {
      Logger.e('Failed to update watchlist status', e);
      if (alive.current) {
        setStatus(previous);
        snack('Failed to update — please try again');
      }
    }
  };

  const updateStatus = (next: string) => {
    const userName = auth.currentUser ?? '';
    const partner = auth.partnerUsername;
    const couple = auth.isCoupleUser;
    const run = statusQueue.current.then(() => doUpdateStatus(next, userName, partner, couple));
    statusQueue.current = run.catch(() => {});
  };

  const inWatchlist = status !== '';
  const liked = status.startsWith('watched');

  const shareToDiscord = async (season?: number | null) => {
    if (sharing) return;
    setSharing(true);
    try {
      const idToken = await firebaseAuth.currentUser?.getIdToken();
      if (!idToken || AgentMode.demo) {
        Logger.e('[EpisodeDrawer] Discord share failed: no ID token');
        snack('Discord share failed — cinema still works');
        return;
      }
      let posterPath = item.posterPath;
      if (!posterPath) {
        posterPath =
          typeof details?.poster_path === 'string' && details.poster_path
            ? TmdbImages.posterFor(details.poster_path)
            : String(details?._posterUrl ?? '');
      }
      const body: Record<string, unknown> = { title: item.title, posterPath, mediaType: item.mediaType };
      if (season != null) body.season = season;
      const resp = await fetch(DISCORD_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${idToken}` },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(15000),
      });
      if (resp.ok) snack('Shared to #watch-party');
      else {
        Logger.e(`[EpisodeDrawer] Discord share failed for "${item.title}"`);
        snack('Discord share failed — cinema still works');
      }
    } catch (e) {
      Logger.e('[EpisodeDrawer] Discord share failed', e);
      snack('Discord share failed — cinema still works');
    } finally {
      if (alive.current) setSharing(false);
    }
  };

  const posterParam = item.posterPath ? `&poster=${encodeURIComponent(item.posterPath)}` : '';
  const malIdParam = isAnimeSourced ? `&malId=${malId}` : '';
  const playId = isAnimeSourced ? malId : item.tmdbId;
  const playMovie = () =>
    navigate(
      `/cinema/video/${playId}?type=movie&title=${encodeURIComponent(item.title)}&anime=${isAnimeSourced}${malIdParam}${posterParam}`,
    );
  const playEpisode = (season: number, episode: number) => {
    const watchedParam = !isAnimeSourced && isWatched(item) ? '&watched=true' : '';
    const duration = item.durationSeconds ?? 0;
    const completedParam =
      !isAnimeSourced &&
      season === item.currentSeason &&
      episode === item.currentEpisode &&
      duration > 0 &&
      (item.currentTimestamp ?? 0) / duration >= 0.95
        ? '&completed=true'
        : '';
    navigate(
      `/cinema/video/${playId}?type=tv&title=${encodeURIComponent(cleanTitle(item.title))}&season=${season}&episode=${episode}&anime=${isAnimeSourced}${watchedParam}${completedParam}${malIdParam}${posterParam}`,
    );
  };

  // build()
  const ratingNum = typeof details?.vote_average === 'number' ? details.vote_average : null;
  const rating = ratingNum != null ? Number(ratingNum.toFixed(1)) : null;
  const releaseDate = isAnimeSourced ? item.year : String((isFilm ? details?.release_date : details?.first_air_date) ?? '');
  const year = releaseDate ? releaseDate.split('-')[0] : item.year;
  const episodeRunTimes = Array.isArray(details?.episode_run_time) ? (details.episode_run_time as unknown[]) : null;
  const runtime = isAnimeSourced
    ? details?._duration
    : (details?.runtime ?? (episodeRunTimes?.length ? episodeRunTimes[0] : null));
  let backdropUrl: string;
  if (isAnimeSourced) {
    const ani = details?._backdropUrl as string | undefined;
    backdropUrl = ani || item.backdropPath || item.posterPath;
  } else {
    backdropUrl =
      details?.backdrop_path != null
        ? TmdbImages.backdropOf(String(details.backdrop_path))
        : item.backdropPath || item.posterPath;
  }
  const isUnreleased = (() => {
    if (!releaseDate) return false;
    const parsed = new Date(releaseDate);
    if (Number.isNaN(parsed.getTime())) return false;
    const now = new Date();
    return parsed.getTime() > new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  })();
  const hasProgress =
    (item.currentTimestamp ?? 0) > 0 ||
    (item.currentSeason != null && item.currentEpisode != null && (item.currentSeason > 1 || item.currentEpisode > 1));

  const certification = (() => {
    const d = details;
    if (d == null) return isAnimeSourced ? '13+' : null;
    const pick = (results: unknown[]) => {
      const rows = results.filter((r): r is Record<string, unknown> => !!r && typeof r === 'object');
      if (!rows.length) return null;
      for (const iso of ['PH', 'US', 'GB']) {
        const r = rows.find((x) => String(x.iso_3166_1 ?? '') === iso);
        if (r) return r;
      }
      return rows[0];
    };
    if (isFilm) {
      const results = (d.release_dates as { results?: unknown[] } | undefined)?.results;
      if (Array.isArray(results)) {
        const dates = pick(results)?.release_dates;
        for (const r of Array.isArray(dates) ? dates : []) {
          const cert = String((r as Record<string, unknown>)?.certification ?? '').trim();
          if (cert) return cert;
        }
      }
    } else {
      const results = (d.content_ratings as { results?: unknown[] } | undefined)?.results;
      if (Array.isArray(results)) {
        const r = String(pick(results)?.rating ?? '').trim();
        if (r) return r;
      }
    }
    return isAnimeSourced ? '13+' : '16+';
  })();

  const has = (g: string) => genreNames.includes(g);
  const advisory =
    has('Action') || has('Crime') || has('Thriller')
      ? 'violence, language'
      : has('Romance') || has('Drama')
        ? 'romantic themes, language'
        : has('Horror') || has('Mystery')
          ? 'fear, violence'
          : has('Comedy')
            ? 'humor, suggestive dialogue'
            : has('Animation')
              ? 'fantasy action, mild language'
              : 'general themes';
  const moodTags = (() => {
    const tags: string[] = [];
    if (has('Romance')) tags.push('Emotional', 'Romantic');
    if (has('Drama') && !tags.includes('Emotional')) tags.push('Emotional');
    if (has('Comedy')) tags.push('Witty');
    if (has('Action') || has('Adventure')) tags.push('Exciting');
    if (has('Thriller') || has('Mystery')) tags.push('Suspenseful');
    if (has('Sci-Fi') || has('Fantasy')) tags.push('Imaginative');
    if (!tags.length) return genreNames.length ? genreNames.slice(0, 2).join(', ') : 'Emotional, Compelling';
    return [...new Set(tags)].slice(0, 3).join(', ');
  })();

  const studio = isAnimeSourced ? (aniDetail?.studios[0] ?? item.studio) : '';
  const format = isAnimeSourced ? (aniDetail?.format ?? item.format) : '';
  const airing = isAnimeSourced ? (aniDetail?.airingStatus ?? item.airingStatus) : '';
  const overview = (typeof details?.overview === 'string' ? details.overview : null) ?? item.synopsis;
  const episodesCountStr = isFilm
    ? ''
    : details?.number_of_episodes != null
      ? `${String(details.number_of_episodes)} Episodes`
      : seasons.length > 1
        ? `${seasons.length} Seasons`
        : episodes.length
          ? `${episodes.length} Episodes`
          : item.episodeCount != null
            ? `${item.episodeCount} Episodes`
            : '';
  const runtimeStr = isFilm && runtime != null ? `${String(runtime)}m` : '';

  const content = (
    <div className="no-scrollbar" style={{ height: '100%', overflowY: 'auto', overscrollBehavior: 'contain' }}>
      <Hero
        backdropUrl={backdropUrl}
        trailerKey={trailerKey}
        muted={muted}
        isMobile={isMobile}
        title={item.title}
        playLabel={hasProgress ? 'Resume' : 'Play'}
        onPlay={isFilm ? playMovie : () => playEpisode(item.currentSeason ?? 1, item.currentEpisode ?? 1)}
        inWatchlist={inWatchlist}
        onToggleWatchlist={() => updateStatus(inWatchlist ? '' : 'to-watch')}
        liked={liked}
        onRate={() => updateStatus(liked ? '' : 'watched-self')}
        isUnreleased={isUnreleased}
        onRemindMe={() => updateStatus('to-watch')}
        onShareDiscord={isCouple ? () => void shareToDiscord(selectedSeason) : undefined}
        onToggleMute={() => setMuted((m) => !m)}
        downloadAction={isFilm ? <MovieDownloadAction item={item} /> : null}
        onClose={onClose}
      />
      <div className="drawer-fade-in">
        <div style={{ padding: '18px 24px 16px' }}>
          {screenW >= 680 ? (
            <div style={{ display: 'flex', alignItems: 'flex-start' }}>
              <div style={{ flex: '62 1 0', minWidth: 0 }}>
                <LeftColumn />
              </div>
              <div style={{ width: 32, flexShrink: 0 }} />
              <div style={{ flex: '38 1 0', minWidth: 0 }}>
                <RightColumn />
              </div>
            </div>
          ) : (
            <>
              <LeftColumn />
              <div style={{ height: 20 }} />
              <RightColumn />
            </>
          )}
          <div style={{ height: 20 }} />
          <div
            style={{
              ...AppTypography.outfitHeading,
              fontSize: 11,
              lineHeight: lineHeight(11),
              letterSpacing: 1.2,
              color: NetflixColors.textSecondary,
            }}
          >
            Status
          </div>
          <div style={{ height: 8 }} />
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {(isCouple
              ? ([
                  ['Want to Watch', 'to-watch', 'bookmark', NetflixColors.accent],
                  ['Khent Watching', 'watching-khent', 'play_circle_filled', AppColors.cinemaOrange],
                  ['Clair Watching', 'watching-clair', 'play_circle_filled', NetflixColors.accent],
                  ['Both Watching', 'watching-both', 'people', AppColors.cinemaAmber],
                  ['Khent Watched', 'watched-khent', 'person', AppColors.cinemaBlue],
                  ['Clair Watched', 'watched-clair', 'favorite', NetflixColors.accent],
                  ['Both Watched', 'watched-both', 'people', AppColors.cinemaGreen],
                ] as const)
              : ([
                  ['Want to Watch', 'to-watch', 'bookmark', NetflixColors.accent],
                  ['Currently Watching', 'watching-self', 'play_circle_filled', AppColors.cinemaOrange],
                  ['Watched', 'watched-self', 'check_circle', AppColors.cinemaGreen],
                ] as const)
            ).map(([label, value, icon, color]) => (
              <StatusChip
                key={value}
                label={label}
                icon={icon}
                activeColor={color}
                selected={status === value}
                onTap={() => updateStatus(value)}
              />
            ))}
          </div>
        </div>
      </div>
      {isCouple && (
        <div style={{ padding: `0 ${AppSpacing.lg}px` }}>
          <TextButton
            icon={<Icon name="auto_awesome" size={18} color={AppColors.deepRose} />}
            style={{ width: '100%' }}
            onPressed={() => {
              onClose();
              navigate('/motchi', {
                state: `Would we both like "${item.title}"? This is the ${item.mediaType} with TMDB id ${item.tmdbId}. Use our individual preferences and avoid spoilers.`,
              });
            }}
          >
            Would we like this? Ask Motchi
          </TextButton>
        </div>
      )}
      {!isFilm && (
        <EpisodeList
          episodes={episodes}
          seasons={seasons}
          selectedSeason={selectedSeason}
          loading={loadingEpisodes}
          hideSpoilers={!(item.isAnime && !isMovieItem(item)) && prefs.hideSpoilers}
          currentSeason={item.isAnime ? undefined : item.currentSeason}
          currentEpisode={item.isAnime ? undefined : item.currentEpisode}
          position={item.isAnime ? 0 : (item.currentTimestamp ?? 0)}
          duration={item.isAnime ? 0 : (item.durationSeconds ?? 0)}
          allWatched={!item.isAnime && isWatched(item)}
          onPlay={playEpisode}
          onSeasonChanged={selectSeason}
        />
      )}
      <ExtraTabs selected={extraTab} onSelect={selectExtraTab} isAnimeSourced={isAnimeSourced} />
      {extraTab === 1 ? (
        <Reviews reviews={reviews} loading={loadingReviews} />
      ) : extraTab === 2 ? (
        <SimilarGrid similar={similar} loading={loadingSimilar} onTap={onShowItem} />
      ) : (
        <CastRow cast={cast} loading={loadingCast} isAnimeSourced={isAnimeSourced} />
      )}
      <div style={{ height: 60 }} />
    </div>
  );

  function LeftColumn() {
    const meta: CSSProperties = {
      ...AppTypography.outfitWhite,
      fontSize: 14,
      lineHeight: lineHeight(14),
      fontWeight: 500,
      color: withAlpha(WHITE, 0.85),
    };
    return (
      <div>
        <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', columnGap: 8, rowGap: 6 }}>
          {rating != null && rating > 0 && (
            <span
              style={{ ...AppTypography.outfitHeading, fontSize: 14, lineHeight: lineHeight(14), color: NetflixColors.match }}
            >
              {Math.round(rating * 10)}% Match
            </span>
          )}
          {year && <span style={meta}>{year}</span>}
          {episodesCountStr ? <span style={meta}>{episodesCountStr}</span> : runtimeStr && <span style={meta}>{runtimeStr}</span>}
          <QualityBox label="HD" />
          <QualityBox label="CC" />
        </div>
        <div style={{ height: 10 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', columnGap: 8, rowGap: 6 }}>
          {certification != null && (
            <span
              style={{
                padding: '2px 6px',
                border: `1px solid ${withAlpha(WHITE, 0.7)}`,
                borderRadius: 3,
                ...AppTypography.outfitHeading,
                fontSize: 11,
                lineHeight: lineHeight(11),
                letterSpacing: 0.5,
                color: WHITE,
              }}
            >
              {certification}
            </span>
          )}
          <span
            style={{ ...AppTypography.outfitWhite, fontSize: 12.5, lineHeight: lineHeight(12.5), color: withAlpha(WHITE, 0.75) }}
          >
            {advisory}
          </span>
        </div>
        {topTenRank != null && (
          <div style={{ marginTop: 12, display: 'flex', alignItems: 'center' }}>
            <div
              style={{
                padding: '2px 5px',
                borderRadius: 3,
                background: NetflixColors.accent,
                textAlign: 'center',
                ...AppTypography.outfitWhite,
                fontSize: 8.5,
                fontWeight: 900,
                lineHeight: lineHeight(8.5, 0.95),
                color: WHITE,
              }}
            >
              TOP
              <br />
              10
            </div>
            <div style={{ width: 8 }} />
            <span style={{ ...AppTypography.outfitBold, fontSize: 14, lineHeight: lineHeight(14), color: WHITE }}>
              #{topTenRank} in {TOP_TEN_COUNTRY_LABEL} Today
            </span>
          </div>
        )}
        {overview && (
          <div
            style={{
              marginTop: 14,
              ...AppTypography.outfitWhite,
              fontSize: 14.5,
              lineHeight: lineHeight(14.5, 1.55),
              color: withAlpha(NetflixColors.textPrimary, 0.9),
            }}
          >
            {overview}
          </div>
        )}
        {isAnimeSourced && (studio || format || airing) && (
          <div style={{ marginTop: 14, display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {studio && <AnimeFactChip label={studio} icon="movie_creation_outlined" />}
            {format && <AnimeFactChip label={format} icon="tv" />}
            {airing && <AnimeFactChip label={airing} icon="fiber_manual_record" />}
            {aniDetail?.nextAiringAt != null && (
              <AiringCountdown at={aniDetail.nextAiringAt} episode={aniDetail.nextAiringEpisode} />
            )}
          </div>
        )}
      </div>
    );
  }

  function RightColumn() {
    const castNames = cast
      .slice(0, 4)
      .map((c) => c.name)
      .filter(Boolean);
    // RichText: no inherited bodyMedium height, so Outfit's own 1.26 line.
    const line = (label: string, value: ReactNode, bottom: number) => (
      <div style={{ paddingBottom: bottom, ...AppTypography.outfitWhite, fontSize: 13, lineHeight: lineHeight(13, 1.26) }}>
        <span style={{ lineHeight: 'inherit', color: NetflixColors.textMuted }}>{label}</span>
        {value}
      </div>
    );
    return (
      <div>
        {castNames.length > 0 &&
          line(
            'Cast: ',
            <>
              <span style={{ lineHeight: 'inherit', color: WHITE }}>{castNames.join(', ')}</span>
              <span style={{ lineHeight: 'inherit', color: withAlpha(WHITE, 0.6), fontStyle: 'italic' }}>, more</span>
            </>,
            10,
          )}
        {genreNames.length > 0 && line('Genres: ', <span style={{ lineHeight: 'inherit', color: WHITE }}>{genreNames.join(', ')}</span>, 10)}
        {line(`This ${isFilm ? 'Movie' : 'Show'} Is: `, <span style={{ lineHeight: 'inherit', color: WHITE }}>{moodTags}</span>, 16)}
      </div>
    );
  }

  return (
    <div className="drawer-root" style={{ position: 'fixed', inset: 0, zIndex: 1100 }}>
      <div className="drawer-barrier" aria-hidden onClick={onClose} style={{ position: 'absolute', inset: 0 }} />
      <div className="drawer-slide" style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
        {isMobile ? (
          <div
            role="dialog"
            aria-label={item.title}
            style={{ height: '100%', background: NetflixColors.surface, pointerEvents: 'auto' }}
          >
            {content}
          </div>
        ) : (
          <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <div
              role="dialog"
              aria-label={item.title}
              style={{
                pointerEvents: 'auto',
                margin: '28px 20px',
                width: 'calc(100% - 40px)',
                maxWidth: 880,
                height: Math.max(0, screenH - 56),
                boxSizing: 'border-box',
                background: NetflixColors.surface,
                borderRadius: 14,
                border: `1px solid ${withAlpha(WHITE, 0.1)}`,
                boxShadow: boxShadow([{ color: withAlpha('#000000', 0.85), blur: 48, offset: [0, 12] }]),
                overflow: 'hidden',
              }}
            >
              {content}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function Hero({
  backdropUrl,
  trailerKey,
  muted,
  isMobile,
  title,
  playLabel,
  onPlay,
  inWatchlist,
  onToggleWatchlist,
  liked,
  onRate,
  isUnreleased,
  onRemindMe,
  onShareDiscord,
  onToggleMute,
  downloadAction,
  onClose,
}: {
  backdropUrl: string;
  trailerKey: string | null;
  muted: boolean;
  isMobile: boolean;
  title: string;
  playLabel: string;
  onPlay: () => void;
  inWatchlist: boolean;
  onToggleWatchlist: () => void;
  liked: boolean;
  onRate: () => void;
  isUnreleased: boolean;
  onRemindMe: () => void;
  onShareDiscord?: () => void;
  onToggleMute: () => void;
  downloadAction: ReactNode;
  onClose: () => void;
}) {
  const [imgState, setImgState] = useState<'loading' | 'ok' | 'error'>('loading');
  const height = isMobile ? 280 : 440;
  const placeholder = (loading: boolean) => (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        background: linear([NetflixColors.surfaceElevated, NetflixColors.surface], {
          begin: Align.topLeft,
          end: Align.bottomRight,
        }),
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      {loading ? (
        <CircularProgress size={30} strokeWidth={2} color={NetflixColors.accent} />
      ) : (
        <Icon name="movie_creation_outlined" size={46} color={NetflixColors.textMuted} />
      )}
    </div>
  );
  return (
    <div style={{ position: 'relative', height, overflow: 'hidden' }}>
      {trailerKey ? (
        <div style={{ position: 'absolute', inset: 0 }}>
          <TrailerPlayer key={trailerKey} videoKey={trailerKey} muted={muted} />
        </div>
      ) : backdropUrl ? (
        <>
          {imgState !== 'ok' && placeholder(imgState === 'loading')}
          <img
            src={backdropUrl}
            alt=""
            onLoad={() => setImgState('ok')}
            onError={() => setImgState('error')}
            style={{
              position: 'absolute',
              inset: 0,
              width: '100%',
              height: '100%',
              objectFit: 'cover',
              opacity: imgState === 'ok' ? 1 : 0,
            }}
          />
        </>
      ) : (
        placeholder(false)
      )}
      <div
        aria-hidden
        style={{
          position: 'absolute',
          inset: 0,
          pointerEvents: 'none',
          background: [
            linear([withAlpha('#000000', 0.55), 'transparent'], { stops: [0, 0.5] }),
            linear(
              [
                'transparent',
                withAlpha(NetflixColors.surface, 0.35),
                withAlpha(NetflixColors.surface, 0.85),
                NetflixColors.surface,
              ],
              {
                begin: Align.topCenter,
                end: Align.bottomCenter,
                stops: [0, 0.45, 0.78, 1],
              },
            ),
            linear([withAlpha('#000000', 0.65), 'transparent'], {
              begin: Align.topCenter,
              end: Align.bottomCenter,
              stops: [0, 0.35],
            }),
          ].join(', '),
        }}
      />
      <button
        type="button"
        className="bare-button"
        aria-label="Close"
        onClick={onClose}
        style={{
          position: 'absolute',
          top: 10,
          right: 16,
          width: 36,
          height: 36,
          borderRadius: '50%',
          boxSizing: 'border-box',
          background: '#181818CC',
          border: `1px solid ${withAlpha(WHITE, 0.2)}`,
          boxShadow: boxShadow([{ color: withAlpha('#000000', 0.5), blur: 10 }]),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name="close" size={20} color={WHITE} />
      </button>
      {trailerKey && (
        <div style={{ position: 'absolute', bottom: 24, right: 20 }}>
          <Tooltip message={muted ? 'Unmute' : 'Mute'}>
            <button
              type="button"
              className="bare-button"
              aria-label={muted ? 'Unmute' : 'Mute'}
              onClick={onToggleMute}
              style={{
                width: 38,
                height: 38,
                borderRadius: '50%',
                boxSizing: 'border-box',
                background: '#18181899',
                border: `1px solid ${withAlpha(WHITE, 0.25)}`,
                boxShadow: boxShadow([{ color: withAlpha('#000000', 0.4), blur: 10 }]),
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name={muted ? 'volume_off' : 'volume_up'} size={20} color={WHITE} />
            </button>
          </Tooltip>
        </div>
      )}
      <div style={{ position: 'absolute', left: 24, right: 76, bottom: 20 }}>
        <div
          className="clamp-2"
          style={{
            ...AppTypography.outfitBold,
            fontSize: isMobile ? 26 : 38,
            lineHeight: lineHeight(isMobile ? 26 : 38, 1.1),
            color: WHITE,
            textShadow: `0 2px ${(2 * (16 * 0.57735 + 0.5)).toFixed(2)}px ${withAlpha('#000000', 0.8)}`,
          }}
        >
          {cleanTitle(title)}
        </div>
        <div style={{ height: 14 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 10 }}>
          <button
            type="button"
            className="bare-button"
            onClick={onPlay}
            style={{
              padding: `10px ${isMobile ? 18 : 24}px`,
              borderRadius: 6,
              background: WHITE,
              boxShadow: boxShadow([{ color: withAlpha('#000000', 0.4), blur: 12, offset: [0, 4] }]),
              display: 'flex',
              alignItems: 'center',
              gap: 8,
            }}
          >
            <Icon name="play_arrow" size={26} color="#000000" />
            <span
              style={{
                ...AppTypography.outfitBold,
                fontSize: 15.5,
                fontWeight: 700,
                lineHeight: lineHeight(15.5),
                letterSpacing: 0.2,
                color: '#000000',
              }}
            >
              {playLabel}
            </span>
          </button>
          {isUnreleased && <CircleAction icon="notifications_none" tooltip="Remind Me" onTap={onRemindMe} />}
          <CircleAction
            icon={inWatchlist ? 'check' : 'add'}
            tooltip={inWatchlist ? 'In Watchlist' : 'Add to Watchlist'}
            onTap={onToggleWatchlist}
            activeColor={inWatchlist ? NetflixColors.accent : undefined}
          />
          <CircleAction
            icon={liked ? 'thumb_up_alt' : 'thumb_up_off_alt'}
            tooltip={liked ? 'Rated' : 'Rate'}
            onTap={onRate}
            activeColor={liked ? NetflixColors.accent : undefined}
          />
          {onShareDiscord && <CircleAction icon="share" tooltip="Share to #watch-party" onTap={onShareDiscord} />}
          {downloadAction}
        </div>
      </div>
    </div>
  );
}

function CircleAction({
  icon,
  tooltip,
  onTap,
  activeColor,
}: {
  icon: string;
  tooltip: string;
  onTap: () => void;
  activeColor?: string;
}) {
  const [hovered, setHovered] = useState(false);
  return (
    <Tooltip message={tooltip}>
      <button
        type="button"
        className="bare-button"
        aria-label={tooltip}
        onClick={onTap}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          width: 40,
          height: 40,
          borderRadius: '50%',
          background: hovered ? withAlpha(WHITE, 0.25) : withAlpha('#000000', 0.5),
          ...insetBorder(activeColor ?? (hovered ? WHITE : withAlpha(WHITE, 0.4)), 1.5),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name={icon} size={20} color={activeColor ?? WHITE} />
      </button>
    </Tooltip>
  );
}

function MovieDownloadAction({ item }: { item: MediaItem }) {
  const offline = useOfflineMedia();
  const id = OfflineIds.cinemaMovieId(item.tmdbId);
  const circle: CSSProperties = {
    width: 40,
    height: 40,
    borderRadius: '50%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  };
  if (offline.isDownloaded(id)) {
    return (
      <Tooltip message="Downloaded for offline viewing">
        <div style={{ ...circle, background: withAlpha(NetflixColors.accent, 0.2), ...insetBorder(NetflixColors.accent, 1.5) }}>
          <Icon name="offline_pin" size={20} color={NetflixColors.accent} />
        </div>
      </Tooltip>
    );
  }
  if (offline.isDownloading(id)) {
    return (
      <div style={circle}>
        <CircularProgress size={20} strokeWidth={2} color={NetflixColors.accent} />
      </div>
    );
  }
  return (
    <Tooltip message="Download movie for offline">
      <button
        type="button"
        className="bare-button"
        aria-label="Download movie for offline"
        onClick={() => {
          showSnackBar(`Downloading ${item.title}...`);
          void offline.startDownloadMedia({
            id,
            type: 'movie',
            mediaId: String(item.tmdbId),
            title: item.title,
            subtitle: 'Movie',
            coverUrl: item.posterPath,
            durationSeconds: item.durationSeconds,
          });
        }}
        style={{ ...circle, background: withAlpha('#000000', 0.5), ...insetBorder(withAlpha(WHITE, 0.4), 1.5) }}
      >
        <Icon name="download_for_offline_outlined" size={20} color={WHITE} />
      </button>
    </Tooltip>
  );
}

function QualityBox({ label }: { label: string }) {
  return (
    <span
      style={{
        padding: '1.5px 5px',
        border: `1px solid ${withAlpha(WHITE, 0.6)}`,
        borderRadius: 3,
        ...AppTypography.outfitBold,
        fontSize: 10,
        lineHeight: lineHeight(10),
        letterSpacing: 0.5,
        color: WHITE,
      }}
    >
      {label}
    </span>
  );
}

function AnimeFactChip({ label, icon }: { label: string; icon: string }) {
  return (
    <div
      style={{
        padding: '6px 11px',
        borderRadius: 999,
        background: withAlpha(AppColors.blushGold, 0.08),
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.3)}`,
        display: 'flex',
        alignItems: 'center',
        gap: 5,
      }}
    >
      <Icon name={icon} size={12} color={AppColors.blushGold} />
      <span
        style={{
          ...AppTypography.outfitHeading,
          fontSize: 10.5,
          lineHeight: lineHeight(10.5),
          letterSpacing: 0.5,
          color: AppColors.blushGold,
        }}
      >
        {label}
      </span>
    </div>
  );
}

function AiringCountdown({ at, episode }: { at: number; episode?: number }) {
  const [, tick] = useState(0);
  useEffect(() => {
    const t = window.setInterval(() => tick((n) => n + 1), 60000);
    return () => window.clearInterval(t);
  }, []);
  const diff = at - Math.floor(Date.now() / 1000);
  const d = Math.floor(diff / 86400);
  const h = Math.floor((diff % 86400) / 3600);
  const m = Math.floor((diff % 3600) / 60);
  const left = diff <= 0 ? 'Airing now' : d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`;
  return (
    <div
      style={{
        padding: '5px 10px',
        borderRadius: 20,
        background: withAlpha(NetflixColors.accent, 0.12),
        border: `1px solid ${withAlpha(NetflixColors.accent, 0.45)}`,
        display: 'flex',
        alignItems: 'center',
        gap: 5,
      }}
    >
      <Icon name="timer_outlined" size={11} color={NetflixColors.accent} />
      <span
        style={{
          ...AppTypography.outfitHeading,
          fontSize: 10,
          lineHeight: lineHeight(10),
          letterSpacing: 0.4,
          color: NetflixColors.accent,
        }}
      >
        {episode != null ? `Ep ${episode} in ${left}` : `Next in ${left}`}
      </span>
    </div>
  );
}

function StatusChip({
  label,
  icon,
  activeColor,
  selected,
  onTap,
}: {
  label: string;
  icon: string;
  activeColor: string;
  selected: boolean;
  onTap: () => void;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-pressed={selected}
      onClick={onTap}
      style={{
        padding: '10px 15px',
        borderRadius: 8,
        background: selected ? withAlpha(activeColor, 0.16) : NetflixColors.surfaceElevated,
        border: `1px solid ${selected ? withAlpha(activeColor, 0.75) : NetflixColors.hairline}`,
        transition: 'background 220ms ease-in-out, border-color 220ms ease-in-out',
        display: 'flex',
        alignItems: 'center',
        gap: 7,
      }}
    >
      <Icon name={icon} size={15} color={selected ? activeColor : NetflixColors.textSecondary} />
      <span
        style={{
          ...AppTypography.outfitHeading,
          fontSize: 12.5,
          lineHeight: lineHeight(12.5),
          color: selected ? WHITE : NetflixColors.textSecondary,
        }}
      >
        {label}
      </span>
    </button>
  );
}

function Spinner({ vertical, size }: { vertical: number; size: number }) {
  return (
    <div style={{ padding: `${vertical}px 0`, display: 'flex', justifyContent: 'center' }}>
      <CircularProgress size={size} strokeWidth={2} color={NetflixColors.accent} />
    </div>
  );
}

function EmptyLine({ text }: { text: string }) {
  return (
    <div
      style={{
        padding: '10px 20px',
        ...AppTypography.outfitWhite,
        fontSize: 13,
        lineHeight: lineHeight(13),
        color: NetflixColors.textMuted,
      }}
    >
      {text}
    </div>
  );
}

function ExtraTabs({
  selected,
  onSelect,
  isAnimeSourced,
}: {
  selected: number;
  onSelect: (i: number) => void;
  isAnimeSourced: boolean;
}) {
  const labels = [isAnimeSourced ? 'Voice Cast' : 'Cast', 'Reviews', 'Motchi says… 🐱'];
  return (
    <div style={{ padding: '30px 20px 12px', display: 'flex', gap: 8 }}>
      {labels.map((label, i) => {
        const on = selected === i;
        return (
          <button
            key={label}
            type="button"
            className="bare-button"
            aria-pressed={on}
            onClick={() => onSelect(i)}
            style={{
              flex: '1 1 0',
              minWidth: 0,
              padding: '10px 0',
              borderRadius: 8,
              background: on ? NetflixColors.accent : NetflixColors.surfaceElevated,
              border: `1px solid ${on ? NetflixColors.accent : NetflixColors.hairline}`,
              transition: 'background 220ms ease-in-out, border-color 220ms ease-in-out',
              ...AppTypography.outfitHeading,
              fontSize: 12.5,
              lineHeight: i === 2 ? mixedLineHeight(12.5) : lineHeight(12.5),
              color: on ? WHITE : NetflixColors.textSecondary,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {label}
          </button>
        );
      })}
    </div>
  );
}

function CastRow({ cast, loading, isAnimeSourced }: { cast: Cast[]; loading: boolean; isAnimeSourced: boolean }) {
  if (loading) return <Spinner vertical={32} size={24} />;
  if (!cast.length) return <EmptyLine text="No cast info available" />;
  return (
    <div className="no-scrollbar" style={{ height: 228, display: 'flex', gap: 18, padding: '0 20px', overflowX: 'auto' }}>
      {cast.map((m, i) => {
        const primary = isAnimeSourced && m.character ? m.character : m.name;
        const secondary = isAnimeSourced && m.character ? m.name : m.character;
        return (
          <div key={i} style={{ width: 128, flexShrink: 0, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <div
              style={{
                width: 112,
                height: 112,
                borderRadius: '50%',
                overflow: 'hidden',
                background: NetflixColors.surfaceElevated,
                border: `1px solid ${NetflixColors.hairline}`,
                boxSizing: 'border-box',
              }}
            >
              <PhotoOrInitial url={m.profilePath} label={primary} size={42} background={NetflixColors.surfaceElevated} />
            </div>
            <div
              className="clamp-2"
              style={{
                marginTop: 10,
                textAlign: 'center',
                ...AppTypography.outfitBold,
                fontSize: 15.5,
                lineHeight: lineHeight(15.5, 1.18),
              }}
            >
              {primary}
            </div>
            {secondary && (
              <div
                className="clamp-2"
                style={{
                  marginTop: 3,
                  textAlign: 'center',
                  ...AppTypography.outfitWhite,
                  fontSize: 12.5,
                  lineHeight: lineHeight(12.5, 1.2),
                  color: NetflixColors.textSecondary,
                }}
              >
                {secondary}
              </div>
            )}
          </div>
        );
      })}
      <div style={{ flex: '0 0 2px' }} />
    </div>
  );
}

function PhotoOrInitial({ url, label, size, background }: { url: string; label: string; size: number; background: string }) {
  const [failed, setFailed] = useState(false);
  if (url && !failed) {
    return (
      <img
        src={url}
        alt=""
        onError={() => setFailed(true)}
        style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
      />
    );
  }
  return (
    <div
      style={{
        width: '100%',
        height: '100%',
        background,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        ...AppTypography.cormorantBold,
        fontSize: size,
        color: NetflixColors.textSecondary,
      }}
    >
      {label ? label[0].toUpperCase() : '?'}
    </div>
  );
}

function Reviews({ reviews, loading }: { reviews: CinemaReview[]; loading: boolean }) {
  if (loading) return <Spinner vertical={28} size={22} />;
  if (!reviews.length) return <EmptyLine text="No reviews yet" />;
  return (
    <div style={{ padding: '0 20px' }}>
      {reviews.map((r, i) => {
        const preview = r.content.length > 340 ? `${r.content.slice(0, 340)}…` : r.content;
        const filled = Math.min(10, Math.max(0, r.rating ?? 0)) / 2;
        return (
          <div
            key={r.id || i}
            style={{
              marginBottom: 14,
              padding: 16,
              borderRadius: 12,
              background: NetflixColors.surfaceElevated,
              border: `1px solid ${NetflixColors.hairline}`,
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center' }}>
              <div
                style={{
                  width: 44,
                  height: 44,
                  borderRadius: '50%',
                  overflow: 'hidden',
                  flexShrink: 0,
                  boxSizing: 'border-box',
                  background: NetflixColors.surface,
                  border: `1px solid ${NetflixColors.hairline}`,
                }}
              >
                <PhotoOrInitial url={r.avatar} label={r.author} size={26} background={NetflixColors.surface} />
              </div>
              <div style={{ width: 12 }} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div
                  style={{
                    ...AppTypography.outfitHeading,
                    fontSize: 14.5,
                    lineHeight: lineHeight(14.5),
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                  }}
                >
                  {r.author}
                </div>
                <div style={{ height: 3 }} />
                <div style={{ display: 'flex' }}>
                  {[0, 1, 2, 3, 4].map((s) => {
                    const full = s + 1 <= Math.floor(filled);
                    const partial = !full && s < Math.ceil(filled);
                    return (
                      <Icon
                        key={s}
                        name={partial ? 'star_half' : 'star'}
                        size={13}
                        color={full || partial ? NetflixColors.gold : withAlpha(NetflixColors.textMuted, 0.4)}
                      />
                    );
                  })}
                </div>
              </div>
            </div>
            <div style={{ height: 12 }} />
            {preview && (
              <div
                style={{
                  ...AppTypography.outfitWhite,
                  fontSize: 13.5,
                  lineHeight: lineHeight(13.5, 1.55),
                  color: NetflixColors.textSecondary,
                  whiteSpace: 'pre-wrap',
                }}
              >
                {preview}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

function SimilarGrid({ similar, loading, onTap }: { similar: MediaItem[]; loading: boolean; onTap: (m: MediaItem) => void }) {
  const ref = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setWidth(el.clientWidth));
    ro.observe(el);
    setWidth(el.clientWidth);
    return () => ro.disconnect();
  }, [loading, similar.length]);
  if (loading) return <Spinner vertical={28} size={22} />;
  if (!similar.length) return <EmptyLine text="No similar titles found" />;
  const wide = width >= 600;
  return (
    <div style={{ padding: '12px 20px' }}>
      <div
        ref={ref}
        style={{ display: 'grid', gridTemplateColumns: `repeat(${wide ? 3 : 2}, minmax(0, 1fr))`, columnGap: 12, rowGap: 14 }}
      >
        {similar.slice(0, wide ? 9 : 6).map((m) => (
          <SimilarCard key={`${m.mediaType}:${m.tmdbId}`} item={m} onTap={() => onTap(m)} />
        ))}
      </div>
    </div>
  );
}

function SimilarCard({ item, onTap }: { item: MediaItem; onTap: () => void }) {
  const [hovered, setHovered] = useState(false);
  const match = item.score != null && item.score > 0 ? Math.round(item.score * 10) : 90 + (item.tmdbId % 9);
  const image = TmdbImages.backdropOf(item.backdropPath, true) || TmdbImages.posterFor(item.posterPath);
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onTap}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display: 'block',
        textAlign: 'left',
        alignSelf: 'start',
        borderRadius: 8,
        overflow: 'hidden',
        background: NetflixColors.surfaceElevated,
        border: `1px solid ${withAlpha(WHITE, hovered ? 0.3 : 0.08)}`,
        boxShadow: boxShadow([{ color: withAlpha('#000000', 0.35), blur: hovered ? 14 : 8, offset: [0, 4] }]),
        transition: 'border-color 180ms, box-shadow 180ms',
      }}
    >
      <div style={{ position: 'relative', aspectRatio: '16 / 9', background: NetflixColors.surface }}>
        {image && (
          <img
            src={image}
            alt=""
            onError={(e) => (e.currentTarget.style.visibility = 'hidden')}
            style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }}
          />
        )}
        <span
          style={{
            position: 'absolute',
            right: 8,
            top: 8,
            padding: '2px 6px',
            borderRadius: 4,
            background: withAlpha('#000000', 0.7),
            ...AppTypography.outfitBold,
            fontSize: 10,
            lineHeight: lineHeight(10),
            color: WHITE,
          }}
        >
          {item.year || (item.mediaType === 'movie' ? 'Movie' : 'TV')}
        </span>
      </div>
      <div style={{ padding: '10px 10px 12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <span style={{ ...AppTypography.outfitBold, fontSize: 12, lineHeight: lineHeight(12), color: NetflixColors.match }}>
              {match}% Match
            </span>
            <div style={{ width: 6 }} />
            <span
              style={{
                padding: '1px 4px',
                border: `1px solid ${withAlpha(WHITE, 0.5)}`,
                borderRadius: 2,
                ...AppTypography.outfitBold,
                fontSize: 9,
                lineHeight: lineHeight(9),
                color: WHITE,
              }}
            >
              {item.isAnime ? '13+' : '16+'}
            </span>
          </div>
          <div
            style={{
              width: 26,
              height: 26,
              boxSizing: 'border-box',
              borderRadius: '50%',
              border: `1px solid ${withAlpha(WHITE, 0.4)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="add" size={16} color={WHITE} />
          </div>
        </div>
        <div style={{ height: 6 }} />
        <div
          style={{
            ...AppTypography.outfitBold,
            fontSize: 13,
            lineHeight: lineHeight(13),
            color: WHITE,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {item.title}
        </div>
        {item.synopsis && (
          <div
            className="clamp-2"
            style={{
              marginTop: 4,
              ...AppTypography.outfitWhite,
              fontSize: 11.5,
              lineHeight: lineHeight(11.5, 1.35),
              color: NetflixColors.textSecondary,
            }}
          >
            {item.synopsis}
          </div>
        )}
      </div>
    </button>
  );
}

/** episode_list_section.dart `shouldRevealEpisodeDetails`. */
function shouldReveal(
  season: number,
  episode: number,
  o: { currentSeason?: number; currentEpisode?: number; position: number; duration: number; allWatched: boolean },
): boolean {
  if (o.allWatched) return true;
  if (o.currentSeason == null || o.currentEpisode == null) return false;
  if (season < o.currentSeason) return true;
  if (season > o.currentSeason || episode > o.currentEpisode) return false;
  if (episode < o.currentEpisode) return true;
  return o.duration > 0 && o.position / o.duration >= 0.95;
}

function proxyIfBlocked(url: string): string {
  try {
    const host = new URL(url).host;
    if (host.endsWith('.crunchyroll.com') || host.endsWith('.funimation.com')) {
      return `https://us-central1-everglow-1c6db.cloudfunctions.net/proxyAnimeImage?url=${encodeURIComponent(url)}`;
    }
  } catch {
    /* keep the url */
  }
  return url;
}

function EpisodeList({
  episodes,
  seasons,
  selectedSeason,
  loading,
  hideSpoilers,
  currentSeason,
  currentEpisode,
  position,
  duration,
  allWatched,
  onPlay,
  onSeasonChanged,
}: {
  episodes: Episode[];
  seasons: Season[];
  selectedSeason: number | null;
  loading: boolean;
  hideSpoilers: boolean;
  currentSeason?: number;
  currentEpisode?: number;
  position: number;
  duration: number;
  allWatched: boolean;
  onPlay: (season: number, episode: number) => void;
  onSeasonChanged: (sn: number) => void;
}) {
  const options = seasons.filter((s) => typeof s.season_number === 'number');
  const label = (s: Season) =>
    `${s.name ?? `Season ${s.season_number}`}${s.episode_count != null ? ` (${s.episode_count} Episodes)` : ''}`;
  const current = options.find((s) => s.season_number === selectedSeason);
  return (
    <div>
      <div style={{ padding: '0 20px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ ...AppTypography.outfitBold, fontSize: 22, lineHeight: lineHeight(22), color: WHITE }}>Episodes</span>
        {seasons.length > 0 && (
          <div
            style={{
              position: 'relative',
              padding: '6px 14px',
              borderRadius: 6,
              background: NetflixColors.surfaceElevated,
              border: `1px solid ${withAlpha(WHITE, 0.18)}`,
              display: 'flex',
              alignItems: 'center',
              // isDense DropdownButton: a 24px row.
              minHeight: 24 + 12 + 2,
              boxSizing: 'border-box',
            }}
          >
            <span style={{ ...AppTypography.outfitBold, fontSize: 13, lineHeight: lineHeight(13), color: WHITE }}>
              {current ? label(current) : ''}
            </span>
            <Icon name="arrow_drop_down" size={22} color={WHITE} />
            <select
              aria-label="Season"
              value={selectedSeason ?? ''}
              onChange={(e) => onSeasonChanged(Number(e.target.value))}
              style={{ position: 'absolute', inset: 0, opacity: 0, cursor: 'pointer' }}
            >
              {options.map((s) => (
                <option key={s.season_number} value={s.season_number}>
                  {label(s)}
                </option>
              ))}
            </select>
          </div>
        )}
      </div>
      {loading ? (
        <div style={{ padding: 32, display: 'flex', justifyContent: 'center' }}>
          <CircularProgress size={36} strokeWidth={2} color={NetflixColors.accent} />
        </div>
      ) : episodes.length === 0 ? (
        <div
          style={{
            padding: '12px 20px',
            ...AppTypography.outfitWhite,
            fontSize: 13,
            lineHeight: lineHeight(13),
            color: AppColors.mutedPurple,
          }}
        >
          No episodes for this season
        </div>
      ) : (
        episodes.map((ep, index) => {
          const season = ep.season ?? selectedSeason ?? 1;
          const num = ep.number ?? index + 1;
          const still = ep.still
            ? ep.still.startsWith('http://') || ep.still.startsWith('https://')
              ? ep.still.includes('image.tmdb.org')
                ? TmdbImages.stillFor(ep.still)
                : proxyIfBlocked(ep.still)
              : TmdbImages.stillFor(ep.still)
            : '';
          const reveal =
            hideSpoilers && shouldReveal(season, num, { currentSeason, currentEpisode, position, duration, allWatched });
          const isCurrent = currentSeason === season && currentEpisode === num;
          const progress =
            isCurrent && duration > 0
              ? Math.min(1, Math.max(0, position / duration))
              : allWatched ||
                  (currentSeason != null &&
                    currentEpisode != null &&
                    (season < currentSeason || (season === currentSeason && num < currentEpisode)))
                ? 1
                : 0;
          return (
            <EpisodeRow
              key={`${season}/${num}`}
              num={num}
              name={ep.name ?? `Episode ${num}`}
              overview={ep.overview}
              still={still}
              duration={ep.runtime && ep.runtime > 0 ? `${ep.runtime}m` : ''}
              progress={progress}
              hideSpoilers={hideSpoilers}
              revealedByProgress={reveal}
              onTap={() => onPlay(season, num)}
            />
          );
        })
      )}
    </div>
  );
}

function EpisodeRow({
  num,
  name,
  overview,
  still,
  duration,
  progress,
  hideSpoilers,
  revealedByProgress,
  onTap,
}: {
  num: number;
  name: string;
  overview: string;
  still: string;
  duration: string;
  progress: number;
  hideSpoilers: boolean;
  revealedByProgress: boolean;
  onTap: () => void;
}) {
  const [hovered, setHovered] = useState(false);
  const [revealed, setRevealed] = useState(false);
  const [failed, setFailed] = useState(false);
  const expanded = revealed || revealedByProgress;
  const hidden = hideSpoilers && !expanded;
  return (
    <div
      role="button"
      tabIndex={0}
      onClick={onTap}
      onKeyDown={(e) => e.key === 'Enter' && onTap()}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        cursor: 'pointer',
        padding: '14px 20px',
        background: hovered ? withAlpha(WHITE, 0.07) : 'transparent',
        borderBottom: `1px solid ${withAlpha(WHITE, 0.08)}`,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <div
        style={{
          width: 32,
          flexShrink: 0,
          textAlign: 'center',
          ...AppTypography.outfitWhite,
          fontSize: 18,
          fontWeight: 700,
          lineHeight: lineHeight(18),
          color: withAlpha(WHITE, 0.65),
        }}
      >
        {num}
      </div>
      <div style={{ width: 14, flexShrink: 0 }} />
      <div
        style={{
          position: 'relative',
          width: 130,
          height: 74,
          flexShrink: 0,
          borderRadius: 6,
          overflow: 'hidden',
          background: NetflixColors.surface,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {still && !failed ? (
          <img
            src={still}
            alt=""
            onError={() => setFailed(true)}
            style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }}
          />
        ) : (
          !still && <Icon name="movie_creation_outlined" size={28} color={withAlpha(WHITE, 0.38)} />
        )}
        {hovered && (
          <div
            style={{
              position: 'relative',
              width: 32,
              height: 32,
              borderRadius: '50%',
              background: withAlpha('#000000', 0.6),
              ...insetBorder(WHITE, 1.5),
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="play_arrow" size={20} color={WHITE} />
          </div>
        )}
        {progress > 0 && (
          <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0 }}>
            <LinearProgress value={progress} height={3.5} color={NetflixColors.accent} background={withAlpha(WHITE, 0.24)} />
          </div>
        )}
      </div>
      <div style={{ width: 16, flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <div
            style={{
              flex: 1,
              minWidth: 0,
              ...AppTypography.outfitBold,
              fontSize: 14.5,
              lineHeight: lineHeight(14.5),
              color: WHITE,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {hidden ? `Episode ${num}` : name}
          </div>
          {duration && (
            <span
              style={{
                marginLeft: 8,
                ...AppTypography.outfitWhite,
                fontSize: 13,
                lineHeight: lineHeight(13),
                color: withAlpha(WHITE, 0.75),
              }}
            >
              {duration}
            </span>
          )}
        </div>
        <div style={{ height: 5 }} />
        {hidden ? (
          <span
            role="button"
            onClick={(e) => {
              e.stopPropagation();
              setRevealed(true);
            }}
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 12,
              fontWeight: 600,
              lineHeight: lineHeight(12),
              color: NetflixColors.accent,
            }}
          >
            Reveal details
          </span>
        ) : (
          overview && (
            <div
              className={expanded ? 'clamp-4' : 'clamp-2'}
              style={{
                ...AppTypography.outfitWhite,
                fontSize: 12.5,
                lineHeight: lineHeight(12.5, 1.4),
                color: NetflixColors.textSecondary,
              }}
            >
              {overview}
            </div>
          )
        )}
      </div>
    </div>
  );
}
