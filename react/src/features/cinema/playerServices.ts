// Ports of the Cinema player services: cinema_video_sources.dart,
// video_source_url_builder.dart, video_source_service.dart,
// player_memory_service.dart, playback_progress_writer.dart,
// next_episode.dart / next_episode_service.dart and torrent_index_service.dart.
import { doc, getDoc } from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { Prefs } from '../../core/system/prefs';
import { ValueNotifier } from '../../core/system/store';
import { withGetTimeout } from '../../core/utils/liveSource';
import { catalogProxyGet } from '../../shared/utils/catalogProxy';
import { fetchImdbId, fetchMediaDetails, fetchSeasonEpisodes, type TvEpisode } from './tmdbService';

export interface VideoSourceConfig {
  id: string;
  name: string;
  shortName: string;
  desc: string;
  movieUrl: string;
  tvUrl: string;
  isRecommended: boolean;
  sandboxSafe: boolean;
}

const source = (
  s: Partial<VideoSourceConfig> & Pick<VideoSourceConfig, 'id' | 'name' | 'movieUrl' | 'tvUrl'>,
): VideoSourceConfig => ({
  shortName: s.name,
  desc: '',
  isRecommended: false,
  sandboxSafe: false,
  ...s,
});

export const PROXY_CINEMA_ORIGIN = 'https://everglow-stream.khentplaysmoba.workers.dev';
export const PROXY_CINEMA_BASE = `${PROXY_CINEMA_ORIGIN}/proxyAnime`;
export const WRAPPER_ORIGIN = 'https://everglow-1c6db.web.app';
export const WRAPPER_BASE = `${WRAPPER_ORIGIN}/embed.html`;

const cineSrc = source({
  id: 'flux-cinesrc',
  name: 'CineSrc',
  desc: 'No ads, high quality, sometimes unstable',
  movieUrl: 'https://cinesrc.st/embed/movie/',
  tvUrl: 'https://cinesrc.st/embed/tv/',
  isRecommended: true,
  sandboxSafe: true,
});
const everglowEmbed = source({
  id: 'everglow-embed',
  name: 'Everglow',
  desc: 'No ads — Everglow player',
  movieUrl: PROXY_CINEMA_BASE,
  tvUrl: PROXY_CINEMA_BASE,
  isRecommended: true,
  sandboxSafe: true,
});
const everglowShell = source({
  id: 'everglow-shell',
  name: 'Celestia',
  desc: 'No ads — our player',
  movieUrl: WRAPPER_BASE,
  tvUrl: WRAPPER_BASE,
  isRecommended: true,
  sandboxSafe: true,
});
const cinemaOnly = [everglowShell, everglowEmbed, cineSrc];
const cinemaIds = new Set(['everglow-shell', 'everglow-embed', 'flux-cinesrc']);
const selectableNoAdsIds = new Set(['everglow-shell', 'everglow-embed', 'flux-cinesrc', 'vidcore']);
const isSelectableNoAds = (p: VideoSourceConfig) => p.sandboxSafe || selectableNoAdsIds.has(p.id);

/** CinemaVideoSources.selectable. */
export function selectableSources(shared: VideoSourceConfig[], isAnime: boolean): VideoSourceConfig[] {
  if (isAnime) {
    const videasy = shared.filter((p) => p.id === 'videasy');
    const rest = shared.filter((p) => p.id !== 'videasy');
    return [...videasy, ...rest.filter(isSelectableNoAds), ...rest.filter((p) => !isSelectableNoAds(p))];
  }
  const byId = new Map<string, VideoSourceConfig>();
  for (const s of shared) byId.set(s.id, s);
  const merged: VideoSourceConfig[] = [];
  for (const flux of cinemaOnly) {
    merged.push(flux.id === 'everglow-embed' ? everglowEmbed : (byId.get(flux.id) ?? flux));
    byId.delete(flux.id);
  }
  const remaining = [...byId.values()];
  return [...merged, ...remaining.filter(isSelectableNoAds), ...remaining.filter((p) => !isSelectableNoAds(p))];
}

export function trustsCinesrcEpisodeEvent(providerId: string, origin: string): boolean {
  if (providerId === 'flux-cinesrc') return origin === 'https://cinesrc.st';
  if (providerId === 'everglow-shell') return origin === WRAPPER_ORIGIN;
  return providerId === 'everglow-embed';
}

export function trustsCinesrcProgressEvent(providerId: string, origin: string): boolean {
  if (providerId === 'flux-cinesrc') return origin === 'https://cinesrc.st';
  return (providerId === 'everglow-embed' || providerId === 'everglow-shell') && origin === WRAPPER_ORIGIN;
}

export const decodeMessage = (raw: unknown): unknown => {
  if (typeof raw !== 'string') return raw;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
};

/** CinemaVideoSources.parseEverglowHlsProgress → [position, duration]. */
export function parseEverglowHlsProgress(
  providerId: string,
  origin: string,
  raw: unknown,
  expectedEpisode?: number,
): [number, number] | null {
  if (providerId !== 'everglow-embed' || origin !== PROXY_CINEMA_ORIGIN) return null;
  const d = decodeMessage(raw) as Record<string, unknown> | null;
  if (!d || typeof d !== 'object' || d.type !== 'animex-progress') return null;
  const { position, duration, episode } = d;
  if (typeof position !== 'number' || !Number.isFinite(position) || position < 0) return null;
  if (typeof duration !== 'number' || !Number.isFinite(duration) || duration <= 0 || position > duration) return null;
  if (expectedEpisode != null && typeof episode === 'number' && Math.trunc(episode) !== expectedEpisode) return null;
  return [Math.round(position), Math.round(duration)];
}

interface UrlOpts {
  mediaType: string;
  id: string;
  season: number;
  episode: number;
  startSeconds?: number | null;
  title?: string;
}

function cinemaUrl(p: VideoSourceConfig, o: UrlOpts): string | null {
  if (!cinemaIds.has(p.id)) return null;
  if (p.id === 'everglow-embed') {
    const name = (o.title ?? '').trim();
    const titleParam = name ? `&title=${encodeURIComponent(name).replace(/%20/g, '+')}` : '';
    return o.mediaType === 'tv'
      ? `${PROXY_CINEMA_BASE}?source=cinema&type=tv&tmdbId=${o.id}&s=${o.season}&e=${o.episode}${titleParam}`
      : `${PROXY_CINEMA_BASE}?source=cinema&type=movie&tmdbId=${o.id}${titleParam}`;
  }
  if (p.id === 'everglow-shell') {
    return o.mediaType === 'tv'
      ? `${WRAPPER_BASE}?tmdbId=${o.id}&type=tv&s=${o.season}&e=${o.episode}`
      : `${WRAPPER_BASE}?tmdbId=${o.id}&type=movie`;
  }
  return o.mediaType === 'tv' ? `${p.tvUrl}${o.id}?s=${o.season}&e=${o.episode}` : `${p.movieUrl}${o.id}`;
}

const withStartSeconds = (url: string, start?: number | null) =>
  start == null || start <= 0 ? url : `${url}${url.includes('?') ? '&' : '?'}start=${start}`;

/** video_source_url_builder.dart buildVideoSourceUrl. */
export function buildVideoSourceUrl(p: VideoSourceConfig, o: UrlOpts): string {
  const c = cinemaUrl(p, o);
  if (c != null) return withStartSeconds(c, o.startSeconds);
  const movieBase = p.movieUrl;
  const tvBase = p.tvUrl;
  const isVideasy = movieBase.includes('videasy') || tvBase.includes('videasy');
  if (o.mediaType === 'tv') {
    if (tvBase.includes('multiembed.mov')) return `${tvBase}${o.id}&tmdb=1&s=${o.season}&e=${o.episode}`;
    if (p.id === 'vsembed' || (tvBase.includes('embed') && !tvBase.endsWith('/'))) {
      return `${tvBase}${o.id}?season=${o.season}&episode=${o.episode}`;
    }
    const base = `${tvBase}${tvBase.endsWith('/') ? '' : '/'}${o.id}/${o.season}/${o.episode}`;
    return withStartSeconds(isVideasy ? `${base}?autoplay=true&nextButton=true&episodeSelector=true` : base, o.startSeconds);
  }
  if (movieBase.includes('multiembed.mov')) return `${movieBase}${o.id}&tmdb=1`;
  const sep = movieBase.endsWith('/') || movieBase.includes('?') || movieBase.includes('=') ? '' : '/';
  const base = `${movieBase}${sep}${o.id}`;
  return withStartSeconds(isVideasy ? `${base}?autoplay=true` : base, o.startSeconds);
}

// --- VideoSourceService ---

const retiredIds = new Set(['videasy', 'movish', '111movies', 'multiembed', 'vidbolt', 'vidrock', 'vsembed', 'vidsrc']);
const serviceNoAdsIds = new Set(['everglow-embed', 'vidcore']);
const isServiceNoAds = (p: VideoSourceConfig) => p.sandboxSafe || serviceNoAdsIds.has(p.id);

const hardcodedDefaults: VideoSourceConfig[] = [
  source({
    id: 'everglow-embed',
    name: 'Everglow',
    desc: 'No ads — Everglow player',
    movieUrl: WRAPPER_BASE,
    tvUrl: WRAPPER_BASE,
    isRecommended: true,
    sandboxSafe: true,
  }),
  source({
    id: 'vidcore',
    name: 'VidCore',
    desc: 'Ad-free — sandbox safe',
    movieUrl: 'https://vidcore.org/embed/movie/',
    tvUrl: 'https://vidcore.org/embed/tv/',
    isRecommended: true,
    sandboxSafe: true,
  }),
  source({
    id: 'vidlink',
    name: 'VidLink',
    desc: 'Large library, may have ads',
    movieUrl: 'https://vidlink.pro/movie/',
    tvUrl: 'https://vidlink.pro/tv/',
  }),
];

function currentList(list: VideoSourceConfig[]): VideoSourceConfig[] {
  const kept: VideoSourceConfig[] = [];
  for (const p of list) {
    if (retiredIds.has(p.id)) continue;
    if (p.id === 'vidlink') {
      kept.push({
        ...p,
        desc: p.desc.toLowerCase().includes('no ads') ? 'Large library, may have ads' : p.desc,
        sandboxSafe: false,
      });
    } else if (p.id === 'vidcore' && !p.sandboxSafe) {
      kept.push({ ...p, sandboxSafe: true });
    } else {
      kept.push(p);
    }
  }
  return [...kept.filter(isServiceNoAds), ...kept.filter((p) => !isServiceNoAds(p))];
}

function fromFirestore(data: Record<string, unknown>): VideoSourceConfig {
  const str = (v: unknown, d = '') => (typeof v === 'string' ? v : d);
  const name = str(data.name);
  return {
    id: str(data.id),
    name,
    shortName: str(data.shortName, name),
    desc: str(data.desc),
    movieUrl: str(data.movieUrl),
    tvUrl: str(data.tvUrl),
    isRecommended: data.isRecommended === true,
    sandboxSafe: data.sandboxSafe === true,
  };
}

let loadedProviders: VideoSourceConfig[] | null = null;
let loadingProviders = false;
/** Bumps whenever the Firestore list lands, like ChangeNotifier.notifyListeners. */
export const videoSourcesRevision = new ValueNotifier(0);

async function fetchVideoSources() {
  if (loadingProviders) return;
  loadingProviders = true;
  try {
    if (!AgentMode.demo) {
      const snap = await withGetTimeout(getDoc(doc(db, 'config', 'video_sources')), 'video sources config');
      const raw = snap.exists() ? (snap.data().sources as unknown) : null;
      if (Array.isArray(raw) && raw.length) {
        loadedProviders = currentList(
          raw.filter((e) => e && typeof e === 'object').map((e) => fromFirestore(e as Record<string, unknown>)),
        );
        loadingProviders = false;
        videoSourcesRevision.value += 1;
        return;
      }
    }
  } catch (e) {
    Logger.e('[VideoSourceService] Firestore fetch failed', e);
  }
  loadedProviders ??= hardcodedDefaults;
  loadingProviders = false;
  videoSourcesRevision.value += 1;
}

export const VideoSourceService = {
  get providers(): VideoSourceConfig[] {
    if (loadedProviders) return currentList(loadedProviders);
    void fetchVideoSources();
    return currentList(hardcodedDefaults);
  },
  saveDefaultSourceId(id: string) {
    Prefs.set('video_source_default', id);
  },
  loadDefaultSourceId(): string | null {
    return Prefs.getString('video_source_default');
  },
};

// --- PlayerMemoryService ---

export interface PlayerMemory {
  providerId?: string;
  season?: number;
  episode?: number;
  positionSeconds?: number;
  server?: string;
  audio?: string;
  volume?: number;
}

const MEMORY_PREFIX = 'player_memory_v1/';
const MEMORY_GLOBAL = `${MEMORY_PREFIX}global`;

function memoryFromJson(j: Record<string, unknown>): PlayerMemory {
  const int = (v: unknown) => (typeof v === 'number' ? Math.trunc(v) : undefined);
  const s = (v: unknown) => (typeof v === 'string' ? v : undefined);
  return {
    providerId: s(j.providerId),
    season: int(j.season),
    episode: int(j.episode),
    positionSeconds: int(j.positionSeconds),
    server: s(j.server),
    audio: s(j.audio),
    volume: typeof j.volume === 'number' ? j.volume : undefined,
  };
}

function readMemory(key: string): PlayerMemory | null {
  const raw = Prefs.getString(key);
  if (!raw) return null;
  const json = JSON.parse(raw) as unknown;
  return json && typeof json === 'object' && !Array.isArray(json) ? memoryFromJson(json as Record<string, unknown>) : null;
}

export const PlayerMemoryService = {
  cinemaKey: (o: { id: number; mediaType: string; isAnime: boolean }) =>
    `${MEMORY_PREFIX}${o.isAnime ? 'mal' : 'tmdb'}/${o.id}/${o.mediaType}`,
  animexKey: (o: { anilistId?: number; malId: number }) => `${MEMORY_PREFIX}animex/${o.anilistId ?? o.malId}`,
  watchPartyKey: (roomId: string) => `${MEMORY_PREFIX}party/${roomId}`,

  load(key: string): PlayerMemory {
    try {
      const memory = readMemory(key);
      const global = Prefs.get(MEMORY_GLOBAL);
      const volume = typeof global === 'number' ? global : undefined;
      if (!memory) return { volume };
      return memory.volume != null ? memory : { ...memory, volume };
    } catch (e) {
      Logger.e(`PlayerMemory: load failed for ${key} (resume point lost)`, e);
      return {};
    }
  },

  save(key: string, patch: PlayerMemory & { clearPosition?: boolean }): void {
    try {
      let current: PlayerMemory = {};
      try {
        current = readMemory(key) ?? {};
      } catch {
        current = {};
      }
      const next: PlayerMemory = {
        providerId: patch.providerId ?? current.providerId,
        season: patch.season ?? current.season,
        episode: patch.episode ?? current.episode,
        positionSeconds: patch.clearPosition ? undefined : (patch.positionSeconds ?? current.positionSeconds),
        server: patch.server ?? current.server,
        audio: patch.audio ?? current.audio,
        volume: patch.volume ?? current.volume,
      };
      Prefs.set(key, JSON.stringify(Object.fromEntries(Object.entries(next).filter(([, v]) => v != null))));
      if (patch.volume != null) Prefs.set(MEMORY_GLOBAL, Math.min(1, Math.max(0, patch.volume)));
    } catch (e) {
      Logger.e(`PlayerMemory: save failed for ${key} (resume point not stored)`, e);
    }
  },
};

// --- PlaybackProgressWriter ---

export class PlaybackProgressWriter {
  private timer: ReturnType<typeof setTimeout> | null = null;
  private pending: (() => Promise<void>) | null = null;
  private writes: Promise<void> = Promise.resolve();

  schedule(write: () => Promise<void>) {
    this.pending = write;
    if (this.timer) return;
    this.timer = setTimeout(() => void this.flush(), 15000);
  }

  writeNow(write: () => Promise<void>): Promise<void> {
    void this.flush();
    this.writes = this.writes.then(write).catch((e: unknown) => Logger.e('Cinema: progress save failed', e));
    return this.writes;
  }

  flush(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
    const write = this.pending;
    this.pending = null;
    if (write) return this.writeNow(write);
    return this.writes;
  }
}

export const shouldAutoplayNext = (o: { enabled: boolean; positionSeconds: number; durationSeconds: number }) =>
  o.enabled && o.durationSeconds > 60 && o.positionSeconds >= o.durationSeconds;

// --- NextEpisodeService ---

export interface NextEpisode {
  season: number;
  episode: number;
  name?: string;
  overview?: string;
  stillPath?: string;
}

export const nextEpisodeLabel = (n: NextEpisode) => `S${n.season} E${n.episode}`;

const todayDate = () => {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
};

function hasAired(ep: TvEpisode, today: Date): boolean {
  if (!ep.airDate) return true;
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(ep.airDate);
  if (!m) return true;
  return new Date(+m[1], +m[2] - 1, +m[3]).getTime() <= today.getTime();
}

const toNext = (season: number, ep: TvEpisode): NextEpisode => ({
  season,
  episode: ep.episodeNumber,
  name: ep.name || undefined,
  overview: ep.overview || undefined,
  stillPath: ep.stillRaw,
});

export function nextInSeason(season: number, currentEpisode: number, episodes: TvEpisode[]): NextEpisode | null {
  const today = todayDate();
  const sorted = [...episodes].sort((a, b) => a.episodeNumber - b.episodeNumber);
  const i = sorted.findIndex((e) => e.episodeNumber === currentEpisode);
  if (i >= 0) {
    const next = sorted[i + 1];
    if (!next || !hasAired(next, today)) return null;
    return toNext(season, next);
  }
  const later = sorted.find((e) => e.episodeNumber > currentEpisode && hasAired(e, today));
  return later ? toNext(season, later) : null;
}

export function nextSeasonNumber(currentSeason: number, seasonNumbers: number[]): number | null {
  const filtered = seasonNumbers.filter((n) => n > 0);
  const pool = [...(filtered.length ? filtered : seasonNumbers)].sort((a, b) => a - b);
  return pool.find((n) => n > currentSeason) ?? null;
}

export function firstInSeason(season: number, episodes: TvEpisode[]): NextEpisode | null {
  const sorted = [...episodes].sort((a, b) => a.episodeNumber - b.episodeNumber);
  const first = sorted[0];
  if (!first || !hasAired(first, todayDate())) return null;
  return toNext(season, first);
}

export async function resolveNextEpisode(tmdbId: number, season: number, episode: number): Promise<NextEpisode | null> {
  const current = await fetchSeasonEpisodes(tmdbId, season);
  if (!current.length) return null;
  const same = nextInSeason(season, episode, current);
  if (same) return same;
  const details = await fetchMediaDetails(tmdbId, 'tv');
  if (!details) return null;
  const numbers = (Array.isArray(details.seasons) ? details.seasons : [])
    .map((s) => (s as Record<string, unknown> | null)?.season_number)
    .filter((n): n is number => typeof n === 'number' && Number.isInteger(n));
  const nextSeason = nextSeasonNumber(season, numbers);
  if (nextSeason == null) return null;
  return firstInSeason(nextSeason, await fetchSeasonEpisodes(tmdbId, nextSeason));
}

// --- TorrentIndexService ---

export interface TorrentCopy {
  infoHash: string;
  filename: string;
  quality: string;
  size: string;
  seeders: number;
  provider: string;
  magnet: string;
}

export interface TorrentSearch {
  copies: TorrentCopy[];
  reason?: string;
}

const MAX_COPIES = 12;
const fallbackTrackers = [
  'udp://tracker.opentrackr.org:1337/announce',
  'udp://open.stealth.si:80/announce',
  'udp://tracker.torrent.eu.org:451/announce',
];

const demoCopy = (n: string, file: string, quality: string, size: string, seeders: number): TorrentCopy => ({
  infoHash: `00000000000000000000000000000000000000${n}`,
  filename: file,
  quality,
  size,
  seeders,
  provider: 'Demo',
  magnet: `magnet:?xt=urn:btih:00000000000000000000000000000000000000${n}&dn=${file}`,
});

export const demoTorrentCopies: TorrentCopy[] = [
  demoCopy('a1', 'Moonlit.Cinema.2025.1080p.WEB-DL.mp4', '1080p', '2.04 GB', 1284),
  demoCopy('a2', 'Moonlit.Cinema.2025.720p.WEB-DL.mp4', '720p', '980.12 MB', 412),
  demoCopy('a3', 'Moonlit.Cinema.2025.2160p.HDR.mkv', '4K', '15.80 GB', 96),
];

export function magnetFor(hash: string, filename: string, trackers: string[] = []): string {
  const peers = trackers.length ? trackers : fallbackTrackers;
  const parts = [`xt=urn:btih:${hash.toLowerCase()}`];
  if (filename) parts.push(`dn=${encodeURIComponent(filename)}`);
  for (const t of peers.slice(0, 6)) parts.push(`tr=${encodeURIComponent(t)}`);
  return `magnet:?${parts.join('&')}`;
}

function torrentQuality(name: string): string {
  const label = name.split('\n').slice(1).join(' ').toLowerCase();
  if (label.includes('4k') || label.includes('2160')) return '4K';
  if (label.includes('1080')) return '1080p';
  if (label.includes('720')) return '720p';
  if (label.includes('480')) return '480p';
  for (const rip of ['remux', 'bluray', 'bdrip', 'webrip', 'web-dl']) {
    if (label.includes(rip)) return rip === 'bluray' ? 'BluRay' : rip;
  }
  return '';
}

const intAfter = (text: string, marker: string) => {
  const m = new RegExp(`${marker}\\s*(\\d+)`, 'u').exec(text);
  return m ? Number.parseInt(m[1], 10) || 0 : 0;
};

const valueAfter = (text: string, marker: string) => {
  const m = new RegExp(`${marker}\\s*([^\\n]+)`, 'u').exec(text);
  if (!m) return '';
  return m[1].trim().split('👤')[0].split('💾')[0].split('⚙️')[0].trim();
};

function filenameFrom(title: string, name: string): string {
  const lines = title.split('\n').map((l) => l.trim());
  const file = lines.find((l) => /\.(mkv|mp4|avi|mov|m4v|webm|ts)$/i.test(l));
  if (file) return file;
  const plain = lines.find((l) => l && intAfter(l, '👤') === 0);
  if (plain) return plain;
  return name.split('\n')[0].trim();
}

function trackersOf(sources: unknown): string[] {
  if (!Array.isArray(sources)) return [];
  const out: string[] = [];
  for (const s of sources) {
    const v = String(s);
    if (!v.startsWith('tracker:')) continue;
    const t = v.slice('tracker:'.length).trim();
    if (t.startsWith('http') || t.startsWith('udp')) out.push(t);
  }
  return out;
}

export function parseTorrentCopies(body: string): TorrentCopy[] {
  let decoded: unknown;
  try {
    decoded = JSON.parse(body);
  } catch (e) {
    Logger.e('[TorrentIndex] payload was not JSON', e);
    return [];
  }
  const streams = (decoded as Record<string, unknown> | null)?.streams;
  if (!Array.isArray(streams)) return [];
  const byHash = new Map<string, TorrentCopy>();
  for (const raw of streams) {
    if (!raw || typeof raw !== 'object') continue;
    const r = raw as Record<string, unknown>;
    const hash = String(r.infoHash ?? '').trim();
    if (!/^[a-fA-F0-9]{40}$/.test(hash)) continue;
    const name = String(r.name ?? '');
    const title = String(r.title ?? '');
    const hints = r.behaviorHints;
    const hintFile = hints && typeof hints === 'object' ? String((hints as Record<string, unknown>).filename ?? '') : '';
    const filename = hintFile || filenameFrom(title, name);
    const copy: TorrentCopy = {
      infoHash: hash.toLowerCase(),
      filename,
      quality: torrentQuality(name),
      size: valueAfter(title, '💾'),
      seeders: intAfter(title, '👤'),
      provider: valueAfter(title, '⚙️'),
      magnet: magnetFor(hash, filename, trackersOf(r.sources)),
    };
    const known = byHash.get(copy.infoHash);
    if (!known || copy.seeders > known.seeders) byHash.set(copy.infoHash, copy);
  }
  return [...byHash.values()].sort((a, b) => b.seeders - a.seeders).slice(0, MAX_COPIES);
}

export async function searchTorrents(o: {
  tmdbId: number;
  mediaType: string;
  season?: number;
  episode?: number;
}): Promise<TorrentSearch> {
  if (AgentMode.demo) return { copies: demoTorrentCopies };
  if (o.mediaType === 'tv' && (o.season == null || o.episode == null)) {
    return { copies: [], reason: 'Open an episode to download it.' };
  }
  const imdbId = await fetchImdbId(o.tmdbId, o.mediaType);
  if (!imdbId) return { copies: [], reason: 'No IMDB match for this title yet.' };
  const path = o.mediaType === 'tv' ? `stream/series/${imdbId}:${o.season}:${o.episode}.json` : `stream/movie/${imdbId}.json`;
  try {
    const resp = await catalogProxyGet('torrentio', path, { timeoutMs: 15000 });
    if (!resp.ok) {
      Logger.e(`[TorrentIndex] ${path} returned ${resp.status}`);
      return { copies: [], reason: "Couldn't reach the download index." };
    }
    const copies = parseTorrentCopies(await resp.text());
    return copies.length ? { copies } : { copies: [], reason: 'No copies found for this title.' };
  } catch (e) {
    Logger.e(`[TorrentIndex] ${path} failed`, e);
    return { copies: [], reason: "Couldn't reach the download index." };
  }
}
