// Faithful port of animex_watch_page_config.dart (the AnimeXWatchPage statics),
// animex_embed_policy.dart and animex_videasy_progress.dart.
import type { MediaItem } from '../cinema/cinemaTypes';
import { isWatchedItem } from '../cinema/tmdbService';
import { mediaIsMovie, skipVisibleAt, type AniListDetail, type AniListEpisode, type AniSkipTime, type EpisodeSlots } from './animexData';
import { mediaResumeSeconds, type AnimexHistoryEntry } from './animexStores';

export interface AnimeServerOption {
  name: string;
  tag: string;
  available: boolean;
  supportsAudioSelection: boolean;
  supportsSeek: boolean;
  supportsResume: boolean;
  urlBuilder: (episode: number, audio: string) => string;
}

export function serverUrlFor(s: AnimeServerOption, episode: number, audio: string, startSeconds?: number | null): string {
  const url = s.urlBuilder(episode, audio);
  if (!s.supportsResume || startSeconds == null || startSeconds <= 0) return url;
  const u = new URL(url);
  u.searchParams.set('start', `${startSeconds}`);
  return u.toString();
}

function server(o: Partial<AnimeServerOption> & Pick<AnimeServerOption, 'name' | 'urlBuilder'>): AnimeServerOption {
  return { available: true, supportsAudioSelection: true, supportsSeek: false, supportsResume: false, tag: '', ...o };
}

export function resolveResume({
  item,
  saved,
  local,
  requestedEpisode,
}: {
  item: MediaItem;
  saved?: MediaItem | null;
  local?: AnimexHistoryEntry | null;
  requestedEpisode?: number | null;
}): { episode: number; seconds?: number } {
  const progress = saved ?? item;
  const accountIsAuthoritative =
    saved != null &&
    (saved.progressUpdatedAt != null || saved.currentEpisode != null || saved.currentTimestamp != null || isWatchedItem(saved));
  const isMovie = mediaIsMovie(progress);
  const cur = progress.currentEpisode ?? 0;
  const completedEpisode =
    !isMovie &&
    (progress.durationSeconds ?? 0) > 0 &&
    (progress.currentTimestamp ?? 0) >= progress.durationSeconds! * 0.95 &&
    cur > 0 &&
    cur < (progress.episodeCount ?? 0);
  const fromProgress = isWatchedItem(progress) ? 1 : completedEpisode ? cur + 1 : progress.currentEpisode;
  const episode = requestedEpisode ?? fromProgress ?? (accountIsAuthoritative ? 1 : local?.episode) ?? 1;
  const sameEpisode = isMovie || progress.currentEpisode === episode;
  return { episode: episode > 0 ? episode : 1, seconds: sameEpisode ? mediaResumeSeconds(progress) : undefined };
}

export function skipGuidanceVisible(time: AniSkipTime | undefined, observedPosition: number | undefined, supportsSeek: boolean) {
  if (!time) return false;
  return !supportsSeek || observedPosition == null || skipVisibleAt(time, observedPosition);
}

export function nextUp(o: { isFilm: boolean; selectedEpisode: number; episodeCount: number; hasNextSeason: boolean }) {
  if (!o.isFilm && o.selectedEpisode < o.episodeCount) return { token: `EP ${o.selectedEpisode + 1}`, isSeason: false };
  if (o.hasNextSeason) return { token: '', isSeason: true };
  return null;
}

export function isProviderErrorPage(body: string): boolean {
  const lower = body.toLowerCase();
  return (
    lower.includes('error code: <span>410</span>') ||
    lower.includes('error - megaplay') ||
    lower.includes('no playable stream sources') ||
    lower.includes('no playable stream') ||
    lower.includes('no video sources found') ||
    lower.includes('stream not found') ||
    lower.includes('could not resolve stream') ||
    lower.includes('tryembed_sandbox_blocked') ||
    lower.includes('leech block engaged') ||
    lower.includes('leech protection engaged') ||
    lower.includes('403 forbidden') ||
    lower.includes('this page could not be found') ||
    lower.includes("coudn't find this episode") ||
    lower.includes("couldn't find this episode") ||
    (lower.includes('410') && lower.includes('copyright violation'))
  );
}

export function normalizeServerName(name?: string | null): string {
  if (name == null) return '';
  switch (name) {
    case 'Server 1':
      return 'Everglow';
    case 'Server 2':
      return 'VidLink';
    case 'Server 3':
    case 'Megavid':
    case 'Yume':
    case 'Mega Play':
    case 'MegaPlay':
      return 'Everglow';
    case 'Anixo':
      return 'AniXo';
    default:
      return name;
  }
}

export const resolveMappingsMalId = (detailMalId: number | undefined, routeMalId: number) =>
  detailMalId != null && detailMalId > 0 ? detailMalId : routeMalId;

export function resolveProgressSeason(o: { isMovie: boolean; title: string; episode: number; episodeSlots: EpisodeSlots }) {
  if (o.isMovie) return undefined;
  const slot = o.episodeSlots.get(o.episode);
  if (slot && slot.season > 0) return slot.season;
  const m = /season\s+(\d+)/i.exec(o.title);
  if (m) {
    const parsed = Number.parseInt(m[1] ?? '', 10);
    if (parsed > 0) return parsed;
  }
  return 1;
}

export function mapPlayerEpisodeToMal(o: { tmdbSeason: number; tmdbEpisode: number; episodeSlots: EpisodeSlots; episodeCount: number }) {
  if (o.tmdbSeason <= 0 || o.tmdbEpisode <= 0 || o.episodeCount <= 0) return undefined;
  if (o.episodeSlots.size) {
    for (const [mal, slot] of o.episodeSlots) {
      if (slot.season === o.tmdbSeason && slot.episode === o.tmdbEpisode) {
        return mal >= 1 && mal <= o.episodeCount ? mal : undefined;
      }
    }
    return undefined;
  }
  if (o.tmdbSeason !== 1) return undefined;
  if (o.tmdbEpisode < 1 || o.tmdbEpisode > o.episodeCount) return undefined;
  return o.tmdbEpisode;
}

export const PROXY_ANIME_BASE = 'https://everglow-stream.khentplaysmoba.workers.dev/proxyAnime';

export const everglowProxyUrl = (o: { anilistId: number; malId: number; episode: number; audio: string }) =>
  `${PROXY_ANIME_BASE}?source=everglow&anilistId=${o.anilistId}&malId=${o.malId}&ep=${o.episode}&audio=${o.audio}`;

export function defaultServerIndex(servers: AnimeServerOption[], rememberedServer?: string | null): number {
  const remembered = normalizeServerName(rememberedServer);
  if (remembered) {
    const at = servers.findIndex((s) => s.available && s.name === remembered);
    if (at !== -1) return at;
  }
  const tracked = servers.findIndex((s) => s.available && s.name === 'Everglow');
  if (tracked !== -1) return tracked;
  const first = servers.findIndex((s) => s.available);
  return first === -1 ? 0 : first;
}

export function pickTmdbFallbackId(o: { results: MediaItem[]; title: string; year: string; isMovie: boolean }) {
  const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, '');
  const want = norm(o.title);
  if (!want) return undefined;
  const wantKind = o.isMovie ? 'movie' : 'tv';
  const wantYear = o.year.trim();
  for (const r of o.results) {
    if (r.tmdbId <= 0) continue;
    if (r.mediaType.trim().toLowerCase() !== wantKind) continue;
    if (norm(r.title) !== want) continue;
    const gotYear = r.year.trim();
    if (wantYear && gotYear && gotYear !== wantYear) continue;
    return r.tmdbId;
  }
  return undefined;
}

export function buildServers({
  anilistId,
  malId,
  tmdbId,
  episodeSlots = new Map(),
  isMovie = false,
}: {
  anilistId?: number;
  malId?: number;
  tmdbId?: number;
  episodeSlots?: EpisodeSlots;
  isMovie?: boolean;
}): AnimeServerOption[] {
  const hasAni = anilistId != null && anilistId > 0;
  const mal = malId ?? 0;
  const tmdb = tmdbId ?? 0;
  const aniId = hasAni ? anilistId : 0;
  const hasSource = hasAni || mal > 0;
  const slotOf = (ep: number) => {
    const slot = episodeSlots.get(ep);
    return { season: slot?.season ?? 1, episode: slot?.episode ?? ep };
  };
  return [
    server({
      name: 'Everglow',
      tag: 'Ad-free',
      urlBuilder: (ep, audio) => everglowProxyUrl({ anilistId: aniId, malId: mal, episode: ep, audio }),
      available: hasSource,
      supportsSeek: true,
      supportsResume: true,
    }),
    server({
      name: 'CineSrc',
      tag: 'Ad-free',
      urlBuilder: (ep) => {
        if (isMovie) return `https://everglow-1c6db.web.app/embed.html?tmdbId=${tmdb}&type=movie`;
        const s = slotOf(ep);
        return `https://everglow-1c6db.web.app/embed.html?tmdbId=${tmdb}&type=tv&s=${s.season}&e=${s.episode}`;
      },
      available: tmdb > 0,
      supportsAudioSelection: false,
      supportsResume: true,
    }),
    server({
      name: 'TryEmbed',
      tag: 'Embed',
      urlBuilder: (ep, audio) =>
        hasAni
          ? `https://tryembed.us.cc/embed/anime/${aniId}/${ep}/${audio}`
          : `https://tryembed.us.cc/embed/anime/${mal}/${ep}/${audio}?type=mal`,
      available: hasSource,
    }),
    server({
      name: 'VidCore',
      tag: 'Embed',
      urlBuilder: (ep) => {
        if (isMovie) return `https://vidcore.org/embed/movie/${tmdb}`;
        const s = slotOf(ep);
        return `https://vidcore.org/embed/tv/${tmdb}/${s.season}/${s.episode}`;
      },
      available: tmdb > 0,
      supportsAudioSelection: false,
    }),
    server({
      name: 'Rive',
      tag: 'Embed',
      urlBuilder: (ep) => {
        if (isMovie) return `https://rivestream.us/embed?type=movie&id=${tmdb}`;
        const s = slotOf(ep);
        return `https://rivestream.us/embed?type=tv&id=${tmdb}&season=${s.season}&episode=${s.episode}`;
      },
      available: tmdb > 0,
      supportsAudioSelection: false,
    }),
    server({
      name: 'Fmov',
      tag: 'Embed',
      urlBuilder: (ep) => {
        if (isMovie) return `https://fmov.my/embed/movie/${tmdb}`;
        const s = slotOf(ep);
        return `https://fmov.my/embed/anime/${tmdb}/${s.season}/${s.episode}`;
      },
      available: tmdb > 0,
      supportsAudioSelection: false,
    }),
  ];
}

type AniZipEpisode = Record<string, unknown>;

export function buildEpisodeList({
  detail,
  fallbackEpisodeCount,
  aniZipEpisodes = new Map(),
}: {
  detail?: AniListDetail | null;
  fallbackEpisodeCount?: number;
  aniZipEpisodes?: Map<number, AniZipEpisode>;
}): AniListEpisode[] {
  const detailMap = new Map((detail?.episodes ?? []).map((e) => [e.number, e]));
  const count = detail?.episodeCount ?? fallbackEpisodeCount ?? 0;
  const candidates = [count];
  if (count <= 0 && detailMap.size) candidates.push(Math.max(...detailMap.keys()));
  if (count <= 0 && aniZipEpisodes.size) candidates.push(Math.max(...aniZipEpisodes.keys()));
  const maxNum = candidates.reduce((a, b) => (a > b ? a : b), 0);
  const str = (v: unknown) => (typeof v === 'string' ? v : undefined);
  return Array.from({ length: maxNum > 0 ? maxNum : 12 }, (_, index) => {
    const number = index + 1;
    const base = detailMap.get(number);
    const az = aniZipEpisodes.get(number);
    const titles = az?.title && typeof az.title === 'object' ? (az.title as Record<string, unknown>) : undefined;
    const azEnglish = str(titles?.en);
    const azJat = str(titles?.['x-jat']);
    const azJapanese = str(titles?.ja);
    const baseTitle = base?.title;
    const title = azEnglish
      ? azEnglish
      : baseTitle && !baseTitle.toLowerCase().startsWith(`episode ${number}`)
        ? baseTitle
        : (azJat ?? baseTitle ?? `Episode ${number}`);
    const rawAir = az?.airDate ?? az?.airdate;
    const azImage = str(az?.image);
    const rawDuration = az?.runtime ?? az?.length;
    const overview = str(az?.overview);
    const parsedAir = typeof rawAir === 'string' ? new Date(rawAir) : undefined;
    return {
      number,
      title,
      titleRomaji: base?.titleRomaji ?? azJat ?? azJapanese,
      synopsis: base?.synopsis ? base.synopsis : overview ? overview : str(az?.summary),
      airedAt: base?.airedAt ?? (parsedAir && !Number.isNaN(parsedAir.getTime()) ? parsedAir : undefined),
      duration: base?.duration ?? (typeof rawDuration === 'number' ? Math.trunc(rawDuration) : undefined) ?? detail?.duration,
      thumbnail: azImage ? azImage : base?.thumbnail,
    };
  });
}

// ---------- animex_embed_policy.dart ----------

const UNSANDBOXED = ['megaplay.buzz', 'megaplays.se', 'megaplay.su', 'anixo.buzz', 'tryembed.us.cc'];
const ORIGIN_REFERRER = [...UNSANDBOXED.slice(0, 4), 'megavid.buzz', 'tryembed.us.cc'];
const hostMatches = (host: string, apex: string) => host === apex || host.endsWith(`.${apex}`);
function hostOf(url: string): string {
  try {
    return new URL(url).host.toLowerCase();
  } catch {
    return '';
  }
}
export const EmbedPolicy = {
  sandboxAllowed: (url: string) => !UNSANDBOXED.some((apex) => hostMatches(hostOf(url), apex)),
  referrerFor: (url: string, fallback: string) =>
    ORIGIN_REFERRER.some((apex) => hostMatches(hostOf(url), apex)) ? 'strict-origin-when-cross-origin' : fallback,
};

// ---------- animex_videasy_progress.dart ----------

export interface VideasyProgress {
  positionSeconds: number;
  durationSeconds: number;
  episode?: number;
}

const VIDEASY_ORIGINS = new Set(['https://player.videasy.to', 'https://player.videasy.net']);
const isNum = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v);

export function parseVideasyProgress(origin: string, data: string): VideasyProgress | null {
  if (!VIDEASY_ORIGINS.has(origin)) return null;
  try {
    const json = JSON.parse(data) as Record<string, unknown>;
    if (!json || typeof json !== 'object') return null;
    const position = json.timestamp;
    const duration = json.duration;
    if (!isNum(position) || position < 0 || !isNum(duration) || duration <= 0 || position > duration) return null;
    return { positionSeconds: position, durationSeconds: duration, episode: isNum(json.episode) ? Math.trunc(json.episode) : undefined };
  } catch {
    return null;
  }
}

export const ANIMEX_PROXY_ORIGIN = 'https://everglow-stream.khentplaysmoba.workers.dev';

export function isAnimeXProxyPlayerUrl(url: string): boolean {
  try {
    const u = new URL(url);
    const source = u.searchParams.get('source');
    return (
      u.protocol === 'https:' &&
      !!u.host &&
      !u.username &&
      !u.password &&
      u.origin === ANIMEX_PROXY_ORIGIN &&
      u.pathname === '/proxyAnime' &&
      (source === 'megavid' || source === 'megaplay' || source === 'everglow' || source === 'yumezone')
    );
  } catch {
    return false;
  }
}

export function animeXPlayerMessageOriginAllowed(frameUrl: string, origin: string): boolean {
  let u: URL;
  try {
    u = new URL(frameUrl);
  } catch {
    return false;
  }
  if (!['http:', 'https:'].includes(u.protocol) || !u.host || u.username || u.password) return false;
  if (VIDEASY_ORIGINS.has(u.origin)) return VIDEASY_ORIGINS.has(origin);
  return origin === u.origin;
}

const decode = (data: unknown): unknown => {
  if (typeof data !== 'string') return data;
  try {
    return JSON.parse(data);
  } catch {
    return data;
  }
};

export function parseAnimeXProgress(origin: string, frameUrl: string, data: unknown): VideasyProgress | null {
  if (origin !== ANIMEX_PROXY_ORIGIN || !isAnimeXProxyPlayerUrl(frameUrl)) return null;
  const d = decode(data) as Record<string, unknown> | null;
  if (!d || typeof d !== 'object' || d.type !== 'animex-progress') return null;
  const { position, duration, episode } = d;
  const expected = Number.parseInt(new URL(frameUrl).searchParams.get('ep') ?? '', 10);
  if (
    !isNum(position) ||
    position < 0 ||
    !isNum(duration) ||
    duration <= 0 ||
    position > duration ||
    !isNum(episode) ||
    episode <= 0 ||
    episode !== expected
  ) {
    return null;
  }
  return { positionSeconds: position, durationSeconds: duration, episode: Math.trunc(episode) };
}

export function parseEverglowEmbedScrollDelta(data: unknown): number | null {
  const d = decode(data) as Record<string, unknown> | null;
  if (!d || typeof d !== 'object' || d.type !== 'everglow-embed-scroll') return null;
  if (!isNum(d.deltaY)) return null;
  const mode = isNum(d.deltaMode) ? Math.trunc(d.deltaMode) : 0;
  const dy = d.deltaY * (mode === 1 ? 40 : mode === 2 ? 600 : 1);
  return dy === 0 || !Number.isFinite(dy) ? null : dy;
}
