import {
  collection,
  doc,
  documentId,
  limit,
  onSnapshot,
  query,
  where,
  type DocumentData,
  type DocumentSnapshot,
  type QuerySnapshot,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { auth, db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { just, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export const LASTFM_USER_KHENT = 'khentsgdz';
export const LASTFM_USER_CLAIR = 'clairjassen';
export const DEFAULT_SHOWDOWN_ARTIST = 'Ethel Cain';

const LASTFM_PROXY_URL = 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyLastfm';
const FUNCTIONS_BASE_URL = 'https://us-central1-everglow-1c6db.cloudfunctions.net';

export interface MusicStatus {
  username: string;
  trackName: string;
  artistName: string;
  albumName: string;
  imageUrl: string | null;
  isPlaying: boolean;
  spotifyUrl: string;
  timestamp: Date | null;
  spotifyTrackId?: string | null;
}

export interface TopMusicTrack {
  rank: number;
  trackName: string;
  artistName: string;
  playCount: number;
  imageUrl: string | null;
  spotifyUrl: string;
  mbid?: string | null;
}

export interface ShowdownTrack {
  trackName: string;
  khentPlays: number;
  clairPlays: number;
  imageUrl: string | null;
  spotifyUrl: string;
}

export interface ArtistSuggestion {
  name: string;
  listeners: number;
  imageUrl: string | null;
}

export interface SpotifyLinkState {
  isLinked: boolean;
  spotifyUserId: string | null;
  displayName: string | null;
}

export function emptyMusicStatus(username: string): MusicStatus {
  return {
    username,
    trackName: '',
    artistName: '',
    albumName: '',
    imageUrl: null,
    isPlaying: false,
    spotifyUrl: 'https://open.spotify.com',
    timestamp: null,
  };
}

function pickLastfmImageUrl(images: unknown): string | null {
  if (!Array.isArray(images)) return null;
  const preferred = ['extralarge', 'large', 'medium', 'small'];
  for (const size of preferred) {
    const match = images.find((img) => img && typeof img === 'object' && (img as Record<string, unknown>).size === size);
    const url = match && typeof match === 'object' ? String((match as Record<string, unknown>)['#text'] ?? '').trim() : '';
    if (url && !url.includes('2a96cbd8b46e442fc41c2b86b821562f')) return url;
  }
  return null;
}

function asArray<T>(node: unknown): T[] {
  if (Array.isArray(node)) return node as T[];
  if (node && typeof node === 'object') return [node as T];
  return [];
}

function parseMusicStatusFromMap(d: Record<string, unknown>, fallbackUser: string): MusicStatus {
  const username = String(d.username ?? fallbackUser);
  const trackName = String(d.trackName ?? '');
  const artistName = String(d.artistName ?? '');
  const albumName = String(d.albumName ?? '');
  const rawTs = d.timestamp;
  let timestamp: Date | null = null;
  if (typeof rawTs === 'string') {
    const parsed = new Date(rawTs);
    if (!Number.isNaN(parsed.getTime())) timestamp = parsed;
  }
  return {
    username,
    trackName,
    artistName,
    albumName,
    imageUrl: typeof d.imageUrl === 'string' && d.imageUrl ? d.imageUrl : null,
    isPlaying: d.isPlaying === true,
    spotifyUrl: String(d.spotifyUrl ?? 'https://open.spotify.com'),
    timestamp,
    spotifyTrackId: typeof d.spotifyTrackId === 'string' ? d.spotifyTrackId : null,
  };
}

function parseRecentTrackJson(track: Record<string, unknown>, username: string): MusicStatus {
  const name = String(track.name ?? '');
  const rawArtist = track.artist;
  const artist =
    rawArtist && typeof rawArtist === 'object'
      ? String((rawArtist as Record<string, unknown>)['#text'] ?? '')
      : String(rawArtist ?? '');
  const rawAlbum = track.album;
  const album =
    rawAlbum && typeof rawAlbum === 'object'
      ? String((rawAlbum as Record<string, unknown>)['#text'] ?? '')
      : String(rawAlbum ?? '');
  const attr = track['@attr'] as Record<string, unknown> | undefined;
  const isPlaying = attr?.nowplaying === 'true';
  let timestamp: Date | null = null;
  const dateObj = track.date as Record<string, unknown> | undefined;
  if (dateObj?.uts != null) {
    const uts = Number(dateObj.uts);
    if (!Number.isNaN(uts) && uts > 0) timestamp = new Date(uts * 1000);
  }
  return {
    username,
    trackName: name,
    artistName: artist,
    albumName: album,
    imageUrl: pickLastfmImageUrl(track.image),
    isPlaying,
    spotifyUrl: `https://open.spotify.com/search/${encodeURIComponent(`${artist} ${name}`)}`,
    timestamp,
  };
}

async function getIdToken(): Promise<string | null> {
  if (AgentMode.isActive.value && AgentMode.useDemoData.value) return null;
  const user = auth.currentUser;
  if (!user) return null;
  try {
    return await user.getIdToken();
  } catch {
    return null;
  }
}

async function fetchLastfmJson(params: Record<string, string>): Promise<Record<string, unknown> | null> {
  const token = await getIdToken();
  if (!token) return null;
  try {
    const qs = new URLSearchParams({ ...params, format: 'json' });
    const resp = await fetch(`${LASTFM_PROXY_URL}?${qs.toString()}`, {
      headers: { Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(12000),
    });
    if (!resp.ok) return null;
    return (await resp.json()) as Record<string, unknown>;
  } catch (e) {
    Logger.w(`Last.fm proxy fetch failed: ${String(e)}`);
    return null;
  }
}

export function musicStatusSource(): Source<Record<string, MusicStatus>> {
  if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
    return just({
      [LASTFM_USER_KHENT]: emptyMusicStatus(LASTFM_USER_KHENT),
      [LASTFM_USER_CLAIR]: emptyMusicStatus(LASTFM_USER_CLAIR),
    });
  }

  const q = query(
    collection(db, 'music_status'),
    where(documentId(), 'in', [LASTFM_USER_KHENT, LASTFM_USER_CLAIR]),
    limit(10),
  );
  return withFirestoreTimeout(
    snapshots<QuerySnapshot<DocumentData>, Record<string, MusicStatus>>(
      (next, error) => onSnapshot(q, next, error),
      (snap) => {
        const out: Record<string, MusicStatus> = {
          [LASTFM_USER_KHENT]: emptyMusicStatus(LASTFM_USER_KHENT),
          [LASTFM_USER_CLAIR]: emptyMusicStatus(LASTFM_USER_CLAIR),
        };
        for (const d of snap.docs) {
          out[d.id] = parseMusicStatusFromMap(d.data() as Record<string, unknown>, d.id);
        }
        return out;
      },
    ),
    { label: 'music-status' },
  );
}

export function spotifyTokenSource(uid: string | null): Source<SpotifyLinkState> {
  const empty: SpotifyLinkState = { isLinked: false, spotifyUserId: null, displayName: null };
  if (!uid || (AgentMode.isActive.value && AgentMode.useDemoData.value)) {
    return just(empty);
  }
  const ref = doc(db, 'spotify_tokens', uid);
  return withFirestoreTimeout(
    snapshots<DocumentSnapshot<DocumentData>, SpotifyLinkState>(
      (next, error) => onSnapshot(ref, next, error),
      (snap) => {
        if (!snap.exists()) return empty;
        const d = snap.data() as Record<string, unknown>;
        return {
          isLinked: true,
          spotifyUserId: typeof d.spotifyUserId === 'string' ? d.spotifyUserId : null,
          displayName: typeof d.displayName === 'string' ? d.displayName : null,
        };
      },
    ),
    { label: 'spotify-token' },
  );
}

export async function disconnectSpotify(): Promise<void> {
  const token = await getIdToken();
  if (!token) return;
  await fetch(`${FUNCTIONS_BASE_URL}/spotifyDisconnect`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  });
}

export interface MusicStatsData {
  topTracks: TopMusicTrack[];
  recentTracks: MusicStatus[];
  clairTopTracks: TopMusicTrack[];
  clairRecentTracks: MusicStatus[];
  khentTotalPlays: number;
  clairTotalPlays: number;
}

export async function fetchMusicStats(): Promise<MusicStatsData> {
  const empty: MusicStatsData = {
    topTracks: [],
    recentTracks: [],
    clairTopTracks: [],
    clairRecentTracks: [],
    khentTotalPlays: 0,
    clairTotalPlays: 0,
  };
  const token = await getIdToken();
  if (!token) return empty;

  const parseTop = (data: Record<string, unknown> | null): TopMusicTrack[] => {
    const raw = asArray<Record<string, unknown>>((data?.toptracks as Record<string, unknown> | undefined)?.track);
    return raw
      .map((t, i) => {
        const artistObj = t.artist as Record<string, unknown> | string | undefined;
        const artistName = typeof artistObj === 'object' ? String(artistObj?.name ?? '') : String(artistObj ?? '');
        const trackName = String(t.name ?? '');
        return {
          rank: i + 1,
          trackName,
          artistName,
          playCount: Number(t.playcount ?? 0) || 0,
          imageUrl: pickLastfmImageUrl(t.image),
          spotifyUrl: `https://open.spotify.com/search/${encodeURIComponent(`${artistName} ${trackName}`)}`,
          mbid: typeof t.mbid === 'string' ? t.mbid : null,
        };
      })
      .sort((a, b) => b.playCount - a.playCount)
      .map((t, i) => ({ ...t, rank: i + 1 }));
  };

  const parseRecent = (data: Record<string, unknown> | null, user: string): MusicStatus[] => {
    const raw = asArray<Record<string, unknown>>((data?.recenttracks as Record<string, unknown> | undefined)?.track);
    return raw.slice(0, 5).map((t) => parseRecentTrackJson(t, user));
  };

  const parseUserTotal = (data: Record<string, unknown> | null): number => {
    const u = data?.user as Record<string, unknown> | undefined;
    return Number(u?.playcount ?? 0) || 0;
  };

  const [kTop, kRec, cTop, cRec, kInfo, cInfo] = await Promise.all([
    fetchLastfmJson({ method: 'user.gettoptracks', user: LASTFM_USER_KHENT, period: 'overall', limit: '10', page: '1' }),
    fetchLastfmJson({ method: 'user.getrecenttracks', user: LASTFM_USER_KHENT, limit: '5' }),
    fetchLastfmJson({ method: 'user.gettoptracks', user: LASTFM_USER_CLAIR, period: 'overall', limit: '10', page: '1' }),
    fetchLastfmJson({ method: 'user.getrecenttracks', user: LASTFM_USER_CLAIR, limit: '5' }),
    fetchLastfmJson({ method: 'user.getinfo', user: LASTFM_USER_KHENT }),
    fetchLastfmJson({ method: 'user.getinfo', user: LASTFM_USER_CLAIR }),
  ]);

  return {
    topTracks: parseTop(kTop),
    recentTracks: parseRecent(kRec, LASTFM_USER_KHENT),
    clairTopTracks: parseTop(cTop),
    clairRecentTracks: parseRecent(cRec, LASTFM_USER_CLAIR),
    khentTotalPlays: parseUserTotal(kInfo),
    clairTotalPlays: parseUserTotal(cInfo),
  };
}

export async function fetchArtistShowdown(artist: string): Promise<{
  khentTotal: number;
  clairTotal: number;
  tracks: ShowdownTrack[];
}> {
  const token = await getIdToken();
  if (!token || !artist.trim()) {
    return { khentTotal: 0, clairTotal: 0, tracks: [] };
  }

  const fetchUserArtistCounts = async (user: string): Promise<Map<string, { name: string; count: number; image: string | null }>> => {
    const out = new Map<string, { name: string; count: number; image: string | null }>();
    const targetLower = artist.trim().toLowerCase();
    for (let page = 1; page <= 2; page++) {
      const data = await fetchLastfmJson({
        method: 'user.gettoptracks',
        user,
        period: 'overall',
        limit: '200',
        page: String(page),
      });
      const raw = asArray<Record<string, unknown>>((data?.toptracks as Record<string, unknown> | undefined)?.track);
      if (raw.length === 0) break;
      for (const t of raw) {
        const artistObj = t.artist as Record<string, unknown> | string | undefined;
        const aName = (typeof artistObj === 'object' ? String(artistObj?.name ?? '') : String(artistObj ?? '')).trim().toLowerCase();
        if (aName !== targetLower) continue;
        const trackName = String(t.name ?? '').trim();
        const key = trackName.toLowerCase();
        const count = Number(t.playcount ?? 0) || 0;
        const prev = out.get(key);
        out.set(key, {
          name: trackName,
          count: Math.max(prev?.count ?? 0, count),
          image: prev?.image ?? pickLastfmImageUrl(t.image),
        });
      }
      if (raw.length < 200) break;
    }
    return out;
  };

  const [kMap, cMap] = await Promise.all([
    fetchUserArtistCounts(LASTFM_USER_KHENT),
    fetchUserArtistCounts(LASTFM_USER_CLAIR),
  ]);

  const keys = new Set([...kMap.keys(), ...cMap.keys()]);
  const tracks: ShowdownTrack[] = [];
  let khentTotal = 0;
  let clairTotal = 0;
  for (const key of keys) {
    const k = kMap.get(key);
    const c = cMap.get(key);
    const kp = k?.count ?? 0;
    const cp = c?.count ?? 0;
    khentTotal += kp;
    clairTotal += cp;
    const trackName = k?.name ?? c?.name ?? key;
    tracks.push({
      trackName,
      khentPlays: kp,
      clairPlays: cp,
      imageUrl: k?.image ?? c?.image ?? null,
      spotifyUrl: `https://open.spotify.com/search/${encodeURIComponent(`${artist} ${trackName}`)}`,
    });
  }
  tracks.sort((a, b) => b.khentPlays + b.clairPlays - (a.khentPlays + a.clairPlays));
  return { khentTotal, clairTotal, tracks };
}

export async function searchLastfmArtists(queryStr: string): Promise<ArtistSuggestion[]> {
  const data = await fetchLastfmJson({
    method: 'artist.search',
    artist: queryStr.trim(),
    limit: '6',
  });
  const matches = (data?.results as Record<string, unknown> | undefined)?.artistmatches as Record<string, unknown> | undefined;
  const list = asArray<Record<string, unknown>>(matches?.artist);
  return list
    .map((a) => ({
      name: String(a.name ?? ''),
      listeners: Number(a.listeners ?? 0) || 0,
      imageUrl: pickLastfmImageUrl(a.image),
    }))
    .filter((a) => a.name.length > 0);
}
