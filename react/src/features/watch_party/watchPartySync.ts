import { doc, getDoc } from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { ConnectivityService } from '../../core/network/connectivity';
import { NetworkQualityService } from '../../core/network/networkQuality';
import { auth, db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { Prefs } from '../../core/system/prefs';
import { fetchMediaDetails } from '../cinema/tmdbService';
import type { WatchPartyRoom } from './watchPartyService';

const FUNCTIONS_BASE = 'https://us-central1-everglow-1c6db.cloudfunctions.net';
const PROXY_CINEMA_ORIGIN = 'https://everglow-stream.khentplaysmoba.workers.dev';
const CUSTOM_SERVERS_PREF = 'watch_party_custom_servers';

export interface WatchPartyServer {
  id: string;
  name: string;
  type: 'everglow' | 'embed' | 'hls';
  host: string;
  urlTemplate?: string;
  isRecommended?: boolean;
  isCustom?: boolean;
}

export const BUILTIN_WATCH_PARTY_SERVERS: WatchPartyServer[] = [
  {
    id: 'everglow-hls',
    name: 'Everglow Sync (HLS)',
    type: 'hls',
    host: 'everglow',
    isRecommended: true,
  },
  {
    id: 'everglow-embed',
    name: 'Everglow Embed (CineSrc)',
    type: 'embed',
    host: 'everglow-embed',
  },
];

export interface WatchPartySubtitle {
  url: string;
  label: string;
}

export interface WatchPartyStream {
  src: string;
  subtitles: WatchPartySubtitle[];
  title: string;
}

export class WatchPartyClock {
  private static readonly MAX_OFFSET_MS = 5 * 60 * 1000;
  private static readonly MAX_SAMPLE_AGE_MS = 10 * 60 * 1000;
  private static readonly PENDING_EPSILON_MS = 100;

  private offsetMs = 0;
  private sampledAtMs: number | null = null;

  get offset(): number {
    return this.offsetMs;
  }

  get serverNowMs(): number {
    return Date.now() + this.offsetMs;
  }

  observe(serverDate: Date | undefined, receivedAtMs = Date.now()): void {
    if (!serverDate) return;
    const sample = serverDate.getTime() - receivedAtMs;
    if (Math.abs(sample) <= WatchPartyClock.PENDING_EPSILON_MS) return;
    const stale =
      this.sampledAtMs == null ||
      receivedAtMs - this.sampledAtMs > WatchPartyClock.MAX_SAMPLE_AGE_MS;
    if (stale || sample > this.offsetMs) {
      this.offsetMs = Math.max(
        -WatchPartyClock.MAX_OFFSET_MS,
        Math.min(WatchPartyClock.MAX_OFFSET_MS, sample),
      );
    }
    this.sampledAtMs = receivedAtMs;
  }

  expectedPosition(room: WatchPartyRoom): number {
    const base = Number.isFinite(room.currentTime) ? Math.max(0, room.currentTime) : 0;
    if (room.state !== 'playing') return base;
    const anchor = room.positionAt ?? room.updatedAt;
    if (!anchor) return base;
    const elapsedSec = Math.max(0, (this.serverNowMs - anchor.getTime()) / 1000);
    return base + elapsedSec;
  }
}

export interface CinesrcEvent {
  name: 'ready' | 'play' | 'pause' | 'timeupdate' | 'seeking' | 'seeked' | 'ended' | 'response';
  currentTime?: number;
  command?: string;
  result?: boolean | number;
}

const CINESRC_EVENTS = new Set([
  'ready',
  'play',
  'pause',
  'timeupdate',
  'seeking',
  'seeked',
  'ended',
  'response',
]);

export function parseCinesrcEvent(raw: unknown): CinesrcEvent | null {
  if (!raw || typeof raw !== 'object') return null;
  const map = raw as Record<string, unknown>;
  const type = map.type;
  if (typeof type !== 'string' || !type.startsWith('cinesrc:')) return null;
  const name = type.slice('cinesrc:'.length);
  if (!CINESRC_EVENTS.has(name)) return null;
  const time = map.currentTime;
  const currentTime = typeof time === 'number' && Number.isFinite(time) && time >= 0 ? time : undefined;
  const command = typeof map.command === 'string' ? map.command : undefined;
  const result = typeof map.result === 'boolean' || typeof map.result === 'number' ? map.result : undefined;
  return { name: name as CinesrcEvent['name'], currentTime, command, result };
}

export function cinesrcCommand(command: string, args: unknown[] = []): Record<string, unknown> {
  return { type: 'cinesrc:command', command, args };
}

export function isUserSeek(expectedSeconds: number, reportedSeconds: number, thresholdSeconds = 2.0): boolean {
  return Math.abs(reportedSeconds - expectedSeconds) > thresholdSeconds;
}

export function loadCustomServers(): WatchPartyServer[] {
  const raw = Prefs.getString(CUSTOM_SERVERS_PREF);
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter((x): x is Record<string, unknown> => Boolean(x && typeof x === 'object'))
      .map((x) => ({
        id: String(x.id ?? `custom-${Date.now()}`),
        name: String(x.name ?? 'Custom Server'),
        type: x.type === 'hls' ? 'hls' : 'embed',
        host: String(x.host ?? 'custom'),
        urlTemplate: typeof x.urlTemplate === 'string' ? x.urlTemplate : undefined,
        isCustom: true,
      }));
  } catch {
    return [];
  }
}

export function saveCustomServer(server: Omit<WatchPartyServer, 'isCustom'>): WatchPartyServer[] {
  const list = [...loadCustomServers().filter((s) => s.id !== server.id), { ...server, isCustom: true }];
  Prefs.set(CUSTOM_SERVERS_PREF, JSON.stringify(list));
  return list;
}

export function removeCustomServer(id: string): WatchPartyServer[] {
  const list = loadCustomServers().filter((s) => s.id !== id);
  Prefs.set(CUSTOM_SERVERS_PREF, JSON.stringify(list));
  return list;
}

export async function loadWatchPartyServers(): Promise<WatchPartyServer[]> {
  const custom = loadCustomServers();
  if (AgentMode.demo || !ConnectivityService.isOnline) {
    return [...BUILTIN_WATCH_PARTY_SERVERS, ...custom];
  }
  try {
    const snap = await getDoc(doc(db, 'config', 'watch_party_servers'));
    const data = snap.data();
    const rawList = Array.isArray(data?.servers) ? data.servers : [];
    const shared: WatchPartyServer[] = rawList
      .filter((x): x is Record<string, unknown> => Boolean(x && typeof x === 'object'))
      .map((x) => ({
        id: String(x.id ?? x.name ?? 'shared'),
        name: String(x.name ?? 'Shared Server'),
        type: x.type === 'hls' ? 'hls' : 'embed',
        host: String(x.host ?? 'shared'),
        urlTemplate: typeof x.urlTemplate === 'string' ? x.urlTemplate : undefined,
        isRecommended: Boolean(x.isRecommended),
      }));
    const seen = new Set(BUILTIN_WATCH_PARTY_SERVERS.map((s) => s.id));
    const uniqueShared = shared.filter((s) => !seen.has(s.id));
    return [...BUILTIN_WATCH_PARTY_SERVERS, ...uniqueShared, ...custom];
  } catch (e) {
    Logger.e('WatchPartyServerService: failed to load shared servers', e);
    return [...BUILTIN_WATCH_PARTY_SERVERS, ...custom];
  }
}

export async function authorizeWatchStreamUrl(url: string): Promise<string> {
  const endpoint = `${FUNCTIONS_BASE}/proxyWatchStream`;
  if (!url.startsWith(endpoint)) return url;
  const parsed = new URL(url);
  const target = parsed.searchParams.get('url');
  if (!target) throw new Error('Missing upstream stream URL');
  const token = await auth.currentUser?.getIdToken();
  if (!token) throw new Error('Please sign in again to play this stream');
  const referer = parsed.searchParams.get('referer');
  const resp = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ url: target, ...(referer ? { referer } : {}) }),
    signal: AbortSignal.timeout(NetworkQualityService.timeoutMs(15000)),
  });
  if (!resp.ok) throw new Error('Stream authorization failed');
  const decoded = (await resp.json()) as { url?: string };
  return decoded.url || url;
}

export async function resolveWatchPartyStream(room: WatchPartyRoom, signal?: AbortSignal): Promise<WatchPartyStream> {
  if (!ConnectivityService.isOnline) {
    throw new Error('Offline — cannot resolve stream');
  }
  const params = new URLSearchParams({ format: 'json' });
  if (room.isAnime) {
    const malId = room.malId ?? room.tmdbId;
    if (malId <= 0) throw new Error('Anime room has no MAL id');
    params.set('source', 'everglow');
    params.set('malId', String(malId));
    params.set('ep', String(room.mediaType === 'movie' ? 1 : (room.episode ?? 1)));
    params.set('audio', 'sub');
  } else {
    if (room.tmdbId <= 0) throw new Error('Cinema room has no TMDB id');
    params.set('source', 'cinema');
    params.set('type', room.mediaType);
    params.set('tmdbId', String(room.tmdbId));
    params.set('s', String(room.season ?? 1));
    params.set('e', String(room.episode ?? 1));
    if (room.title) params.set('title', room.title);
    const details = await Promise.race([
      fetchMediaDetails(room.tmdbId, room.mediaType).catch(() => null),
      new Promise<null>((resolve) => window.setTimeout(() => resolve(null), 1200)),
    ]);
    const origLang =
      typeof details?.original_language === 'string'
        ? details.original_language.trim().toLowerCase()
        : '';
    if (/^[a-z]{2,3}$/.test(origLang)) params.set('lang', origLang);
  }
  if (signal?.aborted) throw new DOMException('Aborted', 'AbortError');
  const ctrl = new AbortController();
  const timer = window.setTimeout(() => ctrl.abort(), NetworkQualityService.timeoutMs(22000));
  const onAbort = () => ctrl.abort();
  signal?.addEventListener('abort', onAbort, { once: true });
  const url = `${PROXY_CINEMA_ORIGIN}/proxyAnime?${params.toString()}`;
  let resp: Response;
  try {
    resp = await fetch(url, { signal: ctrl.signal });
  } finally {
    window.clearTimeout(timer);
    signal?.removeEventListener('abort', onAbort);
  }
  if (!resp.ok) {
    let detail = `Stream resolver returned ${resp.status}`;
    try {
      const body = (await resp.json()) as { error?: string };
      if (body.error) detail = body.error;
    } catch {
      // ignore non-JSON body
    }
    throw new Error(detail);
  }
  const json = (await resp.json()) as Record<string, unknown>;
  const src = typeof json.src === 'string' ? json.src : '';
  if (!src.startsWith('https://')) {
    throw new Error('No direct HLS stream available for this title');
  }
  const subsRaw = Array.isArray(json.tracks)
    ? json.tracks
    : Array.isArray(json.subtitles)
      ? json.subtitles
      : [];
  const subtitles: WatchPartySubtitle[] = subsRaw
    .filter((s): s is Record<string, unknown> => {
      if (!s || typeof s !== 'object') return false;
      const rec = s as Record<string, unknown>;
      return typeof rec.url === 'string' || typeof rec.file === 'string';
    })
    .map((s) => ({
      url: String(s.url ?? s.file),
      label: String(s.label ?? 'Subtitles'),
    }));
  const authorizedSrc = await authorizeWatchStreamUrl(src);
  return {
    src: authorizedSrc,
    subtitles,
    title: typeof json.title === 'string' && json.title ? json.title : room.title,
  };
}
