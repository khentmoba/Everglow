// Ports of the services the Listen Along popup uses:
// data/services/spotify_resolve_service.dart, the album part of
// music_sync_service.dart (fetchTrackAlbum), and spotify_player_service_web.dart.
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { resolvedSpotifyUrl } from './jukeboxPure';
import { FUNCTIONS_BASE_URL, fetchLastfmJson, getIdToken, pickLastfmImageUrl, type MusicStatus } from './jukeboxService';

export { resolvedSpotifyUrl };
export const hasSpotifyTrack = (s: MusicStatus) => !!s.spotifyTrackId;
const validAlbum = (album: string) => album !== '' && album !== 'No Album';

// ---- SpotifyResolveService ----

function applyResolved(s: MusicStatus, data: unknown): MusicStatus {
  if (!data || typeof data !== 'object') return s;
  const d = data as Record<string, unknown>;
  const id = typeof d.trackId === 'string' ? d.trackId : '';
  if (!id) return s;
  const resolvedAlbum = typeof d.albumName === 'string' ? d.albumName.trim() : '';
  const current = validAlbum(s.albumName);
  const str = (v: unknown) => (typeof v === 'string' ? v : null);
  return {
    ...s,
    spotifyTrackId: id,
    spotifyEmbedUrl: str(d.embedUrl) ?? s.spotifyEmbedUrl,
    previewUrl: str(d.previewUrl) ?? s.previewUrl,
    spotifyUrl: str(d.spotifyUrl) ?? s.spotifyUrl,
    imageUrl: s.imageUrl ?? str(d.imageUrl),
    albumName: current ? s.albumName : resolvedAlbum,
  };
}

export async function resolveSpotify(status: MusicStatus): Promise<MusicStatus> {
  if ((hasSpotifyTrack(status) && validAlbum(status.albumName)) || status.trackName === 'Silent Night') return status;
  if (!status.artistName || !status.trackName) return status;
  try {
    const token = await getIdToken();
    if (!token) return status;
    const qs = new URLSearchParams({ artist: status.artistName, track: status.trackName }).toString();
    const get = (url: string) =>
      fetch(url, { headers: { Authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(10000) });
    const res = await get(`${FUNCTIONS_BASE_URL}/proxySpotifySearch?${qs}`);
    if (res.status !== 200) {
      if (['localhost', '127.0.0.1', '0.0.0.0'].includes(window.location.hostname)) return status;
      const res2 = await get(`/api/proxySpotifySearch?${qs}`);
      if (res2.status !== 200) return status;
      return applyResolved(status, await res2.json());
    }
    return applyResolved(status, await res.json());
  } catch (e) {
    Logger.w(`SpotifyResolve error: ${String(e)}`);
    return status;
  }
}

// ---- MusicSyncService.fetchTrackAlbum ----

const normalizeForMatch = (v: string) => v.toLowerCase().replace(/[^\p{L}\p{N}]/gu, '');

function normalizeTrackBase(title: string): string {
  let base = title.replace(/\s*[([]\s*(?:feat\.?|ft\.?|featuring|with)\b[^\])]*[\])]/gi, '');
  base = base.replace(/(?:^|[\s–—:-]+)(?:feat\.?|ft\.?|featuring)\b.*$/i, '');
  const withMatch = /^(.*\S)\s+with\b(.*)$/i.exec(base);
  if (withMatch && withMatch[1].trim().split(/\s+/).length >= 2) base = withMatch[1];
  return normalizeForMatch(base);
}

const splitArtists = (v: string) =>
  v
    .split(/\s*(?:&|,|;|\/|\+|×|\bx\b|\band\b|\bfeat\.?\b|\bft\.?\b|\bfeaturing\b|\bwith\b|\bvs\.?\b)+\s*/i)
    .map(normalizeForMatch)
    .filter((p) => p.length >= 2);

function artistMatches(a: string, b: string): boolean {
  const na = normalizeForMatch(a);
  const nb = normalizeForMatch(b);
  if (!na || !nb) return false;
  if (na === nb) return true;
  for (const x of splitArtists(a))
    for (const y of splitArtists(b)) {
      if (x === y) return true;
      if (x.length >= 4 && y.includes(x)) return true;
      if (y.length >= 4 && x.includes(y)) return true;
    }
  return (na.length >= 4 && nb.includes(na)) || (nb.length >= 4 && na.includes(nb));
}

function matchesTrack(candidateTrack: unknown, candidateArtist: unknown, track: string, artist: string | null): boolean {
  if (typeof candidateTrack !== 'string') return false;
  if (normalizeTrackBase(candidateTrack) !== normalizeTrackBase(track)) return false;
  if (artist == null) return true;
  return typeof candidateArtist === 'string' && artistMatches(artist, candidateArtist);
}

type TrackMeta = { artworkUrl: string | null; albumName: string | null };
const nonEmpty = (v: unknown) => (typeof v === 'string' && v.trim() ? v.trim() : null);

async function lastfmMeta(artist: string, track: string): Promise<TrackMeta | null> {
  const data = await fetchLastfmJson({ method: 'track.getinfo', artist, track });
  const node = data?.track as Record<string, unknown> | undefined;
  if (!node || typeof node !== 'object') return null;
  const a = node.artist;
  const name = a && typeof a === 'object' ? (a as Record<string, unknown>).name : a;
  if (!matchesTrack(node.name, name, track, artist)) return null;
  const album = node.album as Record<string, unknown> | undefined;
  if (!album || typeof album !== 'object') return null;
  const meta = { artworkUrl: pickLastfmImageUrl(album.image), albumName: nonEmpty(album.title) };
  return meta.artworkUrl != null || meta.albumName != null ? meta : null;
}

async function searchItunes(term: string): Promise<Record<string, unknown>[]> {
  const query = new URLSearchParams({ term, entity: 'song', media: 'music', limit: '10' }).toString();
  const url = `${FUNCTIONS_BASE_URL}/proxyCatalog?${new URLSearchParams({ base: 'itunes', path: `search?${query}` })}`;
  try {
    const token = auth.currentUser ? await auth.currentUser.getIdToken().catch(() => null) : null;
    const res = await fetch(url, {
      headers: { Accept: 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      signal: AbortSignal.timeout(8000),
    });
    if (res.status !== 200) return [];
    const results = ((await res.json()) as Record<string, unknown>)?.results;
    return Array.isArray(results) ? results.filter((r) => r && typeof r === 'object') : [];
  } catch (e) {
    Logger.e(`Jukebox Service Exception (iTunes, ${term})`, e);
    return [];
  }
}

async function itunesMeta(artist: string, track: string): Promise<TrackMeta | null> {
  const pick = (rs: Record<string, unknown>[], a: string | null) =>
    rs.find((r) => matchesTrack(r.trackName, r.artistName, track, a)) ?? null;
  let selected = pick(await searchItunes(`${artist} ${track}`), artist);
  if (!selected) selected = pick(await searchItunes(track), /[^\x00-\x7F]/.test(artist) ? null : artist);
  if (!selected) return null;
  const art = nonEmpty(selected.artworkUrl100);
  const meta = {
    artworkUrl: art ? art.replace('/100x100bb.jpg', '/600x600bb.jpg') : null,
    albumName: nonEmpty(selected.collectionName),
  };
  return meta.artworkUrl != null || meta.albumName != null ? meta : null;
}

async function spotifyMeta(artist: string, track: string): Promise<TrackMeta | null> {
  const token = await getIdToken();
  if (!token) return null;
  try {
    const qs = new URLSearchParams({ artist, track }).toString();
    const res = await fetch(`${FUNCTIONS_BASE_URL}/proxySpotifySearch?${qs}`, {
      headers: { Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(15000),
    });
    if (res.status !== 200) return null;
    const d = (await res.json()) as Record<string, unknown>;
    if (!d || !matchesTrack(d.trackName, d.artistName, track, artist)) return null;
    const meta = { artworkUrl: nonEmpty(d.imageUrl), albumName: nonEmpty(d.albumName) };
    return meta.artworkUrl != null || meta.albumName != null ? meta : null;
  } catch (e) {
    Logger.e(`Jukebox Service Exception (Spotify, ${artist} - ${track})`, e);
    return null;
  }
}

/** MusicSyncService.fetchTrackMetadata(...).albumName: Last.fm, then iTunes, then Spotify. */
export async function fetchTrackAlbum(artist: string, track: string): Promise<string | null> {
  const lf = await lastfmMeta(artist, track);
  if (lf?.artworkUrl != null && lf.albumName) return lf.albumName;
  const it = await itunesMeta(artist, track);
  if (it != null) {
    const album = lf?.albumName || it.albumName;
    if ((lf?.artworkUrl ?? it.artworkUrl) != null && album) return album;
  }
  const sp = await spotifyMeta(artist, track);
  if (sp != null) return lf?.albumName || it?.albumName || sp.albumName;
  if (it != null) return lf?.albumName || it.albumName;
  return lf?.albumName ?? null;
}

// ---- SpotifyPlayerService (web) ----

const TOKEN_REFRESH_BUFFER_MS = 60_000;

async function storedAccessToken(): Promise<{ token: string; expiresAt: number } | null> {
  const uid = auth.currentUser?.uid;
  if (!uid) return null;
  try {
    const snap = await getDoc(doc(db, 'spotify_tokens', uid));
    const data = snap.data();
    const t = data?.access_token;
    const rawExpires = data?.expires_at;
    const expiresAt = typeof rawExpires === 'number' ? rawExpires : 0;
    if (typeof t !== 'string' || !t) return null;
    if (expiresAt <= Date.now() + TOKEN_REFRESH_BUFFER_MS) return null;
    return { token: t, expiresAt };
  } catch (e) {
    Logger.e('Spotify stored token read failed', e);
    return null;
  }
}

type SpotifyPlayer = {
  addListener: (event: string, cb: (arg: Record<string, string>) => void) => void;
  connect: () => Promise<boolean>;
  _options?: { getOAuthToken: (cb: (t: string) => void) => void };
};
type SpotifyWindow = Window & {
  Spotify?: {
    Player: new (o: { name: string; getOAuthToken: (cb: (t: string) => void) => void; volume: number }) => SpotifyPlayer;
  };
  onSpotifyWebPlaybackSDKReady?: () => void;
};

let deviceId: string | null = null;
let connected = false;
let initialization: Promise<void> | null = null;
let currentToken = '';
let currentTokenExpiresAt = 0;
let tokenRefreshTimer: number | null = null;

if (typeof window !== 'undefined') {
  window.addEventListener('everglow:logout', () => {
    if (tokenRefreshTimer != null) {
      window.clearInterval(tokenRefreshTimer);
      tokenRefreshTimer = null;
    }
    const w = window as SpotifyWindow & { _everglowSpotifyPlayer?: SpotifyPlayer & { disconnect?: () => void } };
    try {
      w._everglowSpotifyPlayer?.disconnect?.();
    } catch {
      // ignore disconnect errors during logout
    }
    delete w._everglowSpotifyPlayer;
    deviceId = null;
    connected = false;
    initialization = null;
    currentToken = '';
    currentTokenExpiresAt = 0;
  });
}

function loadSdk(): Promise<void> {
  const w = window as SpotifyWindow;
  if (w.Spotify?.Player) return Promise.resolve();
  return new Promise((resolve, reject) => {
    let settled = false;
    let script = document.querySelector<HTMLScriptElement>('script[data-spotify-sdk]');
    const cleanup = () => {
      window.clearTimeout(pollTimer);
      window.clearTimeout(failTimer);
    };
    const done = () => {
      if (settled) return;
      settled = true;
      cleanup();
      resolve();
    };
    const fail = (err: Error) => {
      if (settled) return;
      settled = true;
      cleanup();
      script?.remove();
      reject(err);
    };
    w.onSpotifyWebPlaybackSDKReady = done;
    if (!script) {
      script = document.createElement('script');
      script.src = 'https://sdk.scdn.co/spotify-player.js';
      script.setAttribute('data-spotify-sdk', '1');
      script.onerror = () => fail(new Error('Spotify SDK failed to load'));
      document.head.appendChild(script);
    } else {
      script.addEventListener('error', () => fail(new Error('Spotify SDK failed to load')), { once: true });
    }
    const pollTimer = window.setTimeout(() => {
      if (w.Spotify?.Player) done();
    }, 900);
    const failTimer = window.setTimeout(() => fail(new Error('Spotify SDK failed to load')), 12000);
  });
}

async function refreshAccessToken(): Promise<string | null> {
  const user = auth.currentUser;
  if (!user) return null;
  try {
    const idToken = await user.getIdToken();
    const resp = await fetch('/api/spotifyRefresh', {
      method: 'POST',
      headers: { Authorization: `Bearer ${idToken}` },
      signal: AbortSignal.timeout(10_000),
    });
    if (resp.ok) {
      const data = (await resp.json()) as { access_token?: unknown; expires_in?: unknown };
      if (typeof data.access_token === 'string' && data.access_token) {
        const expiresInMs = typeof data.expires_in === 'number' && data.expires_in > 0 ? data.expires_in * 1000 : 3600_000;
        currentToken = data.access_token;
        currentTokenExpiresAt = Date.now() + expiresInMs;
        return currentToken;
      }
    }
  } catch (e) {
    Logger.w(`Spotify token refresh failed: ${String(e)}`);
  }
  return null;
}

async function getFreshAccessToken(forceRefresh = false): Promise<string | null> {
  if (!forceRefresh && currentToken && currentTokenExpiresAt > Date.now() + TOKEN_REFRESH_BUFFER_MS) {
    return currentToken;
  }
  if (!forceRefresh) {
    const stored = await storedAccessToken();
    if (stored) {
      currentToken = stored.token;
      currentTokenExpiresAt = stored.expiresAt;
      return currentToken;
    }
  }
  return refreshAccessToken();
}

function armTokenRefresh() {
  if (tokenRefreshTimer != null) window.clearInterval(tokenRefreshTimer);
  tokenRefreshTimer = window.setInterval(
    async () => {
      if (!auth.currentUser) {
        if (tokenRefreshTimer != null) {
          window.clearInterval(tokenRefreshTimer);
          tokenRefreshTimer = null;
        }
        connected = false;
        currentToken = '';
        currentTokenExpiresAt = 0;
        return;
      }
      if (!connected) return;
      await refreshAccessToken();
    },
    50 * 60 * 1000,
  );
}

async function initPlayer(): Promise<void> {
  try {
    await loadSdk();
  } catch (e) {
    Logger.e('Spotify SDK initialization failed', e);
    return;
  }
  const token = await getFreshAccessToken();
  if (!token) return;
  const w = window as SpotifyWindow & { _everglowSpotifyPlayer?: SpotifyPlayer };
  if (w._everglowSpotifyPlayer) {
    if (deviceId != null) connected = true;
    armTokenRefresh();
    return;
  }
  const player = new w.Spotify!.Player({
    name: 'Everglow Jukebox',
    getOAuthToken: (cb) => {
      void getFreshAccessToken().then((fresh) => {
        if (fresh) cb(fresh);
      });
    },
    volume: 0.8,
  });
  w._everglowSpotifyPlayer = player;
  player.addListener('ready', ({ device_id }) => {
    deviceId = device_id;
    connected = true;
    Logger.d(`Spotify device ready: ${deviceId}`);
  });
  player.addListener('not_ready', () => (connected = false));
  player.addListener('initialization_error', ({ message }) => Logger.w(`Spotify error: ${message}`));
  void player.connect().catch((e) => Logger.e('Spotify connect failed', e));
  armTokenRefresh();
}

function initSpotifyPlayer(): Promise<void> {
  if (connected) return Promise.resolve();
  return (initialization ??= initPlayer().finally(() => (initialization = null)));
}

async function spotifyPutWithRetry(url: string, body: Record<string, unknown>, initialToken: string): Promise<Response> {
  const send = (token: string) =>
    fetch(url, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(10_000),
    });
  const resp = await send(initialToken);
  if (resp.status !== 401) return resp;
  const fresh = await getFreshAccessToken(true);
  if (!fresh) return resp;
  return send(fresh);
}

/** Plays the track on this tab's Spotify device, moving playback here first. */
export async function playInEverglow(trackId: string): Promise<void> {
  await initSpotifyPlayer();
  for (let i = 0; i < 20 && deviceId == null; i++) await new Promise((r) => setTimeout(r, 300));
  if (deviceId == null) return;
  const token = await getFreshAccessToken();
  if (!token) return;
  try {
    const transferResp = await spotifyPutWithRetry('https://api.spotify.com/v1/me/player', { device_ids: [deviceId], play: false }, token);
    if (!transferResp.ok) {
      Logger.w(`Spotify transfer failed: HTTP ${transferResp.status}`);
      return;
    }
    await new Promise((r) => setTimeout(r, 400));
    const playToken = (await getFreshAccessToken()) ?? token;
    const playResp = await spotifyPutWithRetry(
      `https://api.spotify.com/v1/me/player/play?device_id=${encodeURIComponent(deviceId)}`,
      { uris: [`spotify:track:${trackId}`] },
      playToken,
    );
    if (!playResp.ok) {
      Logger.w(`Spotify play failed: HTTP ${playResp.status}`);
    }
  } catch (e) {
    Logger.w(`Spotify play failed: ${String(e)}`);
  }
}
