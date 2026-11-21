import {
  addDoc,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  type DocumentData,
  type QuerySnapshot,
  type Timestamp,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { auth, db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { Changes, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';
import type { MediaRef, WatchPartyChatMessage, WatchPartyRoom } from './watchPartyService';

export interface CommunityWatchPartyRoom extends WatchPartyRoom {
  isCommunity: true;
  hasPassword: boolean;
}

const unlockedRooms = new Set<string>();

export function markCommunityRoomUnlocked(roomId: string): void {
  unlockedRooms.add(roomId);
}

export function isCommunityRoomUnlocked(roomId: string): boolean {
  return unlockedRooms.has(roomId);
}

function communityAccessUrls(): string[] {
  const direct = 'https://us-central1-everglow-1c6db.cloudfunctions.net/communityWatchPartyAccess';
  if (typeof window !== 'undefined' && /^https?:/i.test(window.location.protocol)) {
    const host = window.location.hostname;
    const isLocal = host === 'localhost' || host === '127.0.0.1' || host === '0.0.0.0';
    return isLocal ? [direct] : ['/api/communityWatchPartyAccess', direct];
  }
  return [direct];
}

const demoCommunityRooms = new Map<string, CommunityWatchPartyRoom>();
const demoCommunityPasswords = new Map<string, string>();
const demoCommunityChanges = new Changes<CommunityWatchPartyRoom[]>(() =>
  [...demoCommunityRooms.values()].sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime()),
);

const demoCommunityChat = new Map<string, WatchPartyChatMessage[]>();
const demoCommunityChatChanges = new Changes<Record<string, WatchPartyChatMessage[]>>(() => {
  const out: Record<string, WatchPartyChatMessage[]> = {};
  for (const [id, list] of demoCommunityChat.entries()) out[id] = list;
  return out;
});

function seedDemoCommunityRooms() {
  if (demoCommunityRooms.size > 0) return;
  const now = new Date();
  const seeded: CommunityWatchPartyRoom[] = [
    {
      id: 'hub_open_anime',
      name: 'Open Anime Watch Party',
      hostUid: 'demo_octagram',
      hostName: 'octagram',
      partnerUid: '',
      partnerName: '',
      mediaType: 'tv',
      tmdbId: 21,
      malId: 21,
      isAnime: true,
      season: 1,
      episode: 1,
      episodeCount: 1000,
      title: 'Demo Anime Night',
      posterPath: 'assets/images/demo/poster-3.jpg',
      serverType: 'hls',
      serverName: 'Everglow Server',
      serverHost: 'everglow',
      captionsOn: true,
      proxyEnabled: false,
      state: 'paused',
      currentTime: 0,
      positionAt: now,
      updatedAt: now,
      updatedBy: 'demo_octagram',
      createdAt: now,
      active: true,
      isCommunity: true,
      hasPassword: false,
    },
    {
      id: 'hub_locked_movie',
      name: 'Friday Movie Night',
      hostUid: 'demo_breyan',
      hostName: 'breyan',
      partnerUid: '',
      partnerName: '',
      mediaType: 'movie',
      tmdbId: 550,
      isAnime: false,
      title: 'Demo Movie Night',
      posterPath: 'assets/images/demo/poster-1.jpg',
      serverType: 'hls',
      serverName: 'Everglow Server',
      serverHost: 'everglow',
      captionsOn: true,
      proxyEnabled: false,
      state: 'paused',
      currentTime: 0,
      positionAt: new Date(now.getTime() - 4 * 60_000),
      updatedAt: new Date(now.getTime() - 4 * 60_000),
      updatedBy: 'demo_breyan',
      createdAt: new Date(now.getTime() - 30 * 60_000),
      active: true,
      isCommunity: true,
      hasPassword: true,
    },
  ];
  for (const r of seeded) demoCommunityRooms.set(r.id, r);
  demoCommunityPasswords.set('hub_locked_movie', '1234');
}

function fromFirestoreCommunityRoom(data: Record<string, unknown>, id: string): CommunityWatchPartyRoom {
  const toDate = (v: unknown, fallback = new Date()): Date => {
    if (v && typeof (v as Timestamp).toDate === 'function') return (v as Timestamp).toDate();
    if (typeof v === 'string') {
      const d = new Date(v);
      if (!Number.isNaN(d.getTime())) return d;
    }
    return fallback;
  };
  return {
    id,
    name: String(data.name ?? 'Watch Party'),
    hostUid: String(data.hostUid ?? ''),
    hostName: String(data.hostName ?? 'Host'),
    partnerUid: '',
    partnerName: '',
    mediaType: String(data.mediaType ?? 'movie') === 'tv' ? 'tv' : 'movie',
    tmdbId: Number(data.tmdbId ?? 0) || 0,
    malId: typeof data.malId === 'number' ? data.malId : undefined,
    isAnime: data.isAnime === true,
    season: typeof data.season === 'number' ? data.season : undefined,
    episode: typeof data.episode === 'number' ? data.episode : undefined,
    episodeCount: typeof data.episodeCount === 'number' ? data.episodeCount : undefined,
    title: String(data.title ?? ''),
    posterPath: String(data.posterPath ?? ''),
    serverType: data.serverType === 'embed' ? 'embed' : 'hls',
    serverName: 'Everglow Server',
    serverHost: 'everglow',
    streamUrl: undefined,
    subtitleUrl: undefined,
    captionsOn: data.captionsOn !== false,
    proxyEnabled: false,
    state: data.state === 'playing' ? 'playing' : data.state === 'buffering' ? 'buffering' : 'paused',
    currentTime: Number(data.currentTime ?? 0) || 0,
    positionAt: data.positionAt ? toDate(data.positionAt) : undefined,
    updatedAt: toDate(data.updatedAt),
    updatedBy: String(data.updatedBy ?? ''),
    createdAt: toDate(data.createdAt),
    active: data.active === true,
    isCommunity: true,
    hasPassword: data.hasPassword === true,
  };
}

export function communityRoomsStream(): Source<CommunityWatchPartyRoom[]> {
  if (AgentMode.demo) {
    seedDemoCommunityRooms();
    return demoCommunityChanges.source;
  }
  const q = query(collection(db, 'community_watch_rooms'), orderBy('updatedAt', 'desc'), limit(30));
  return withFirestoreTimeout(
    snapshots<QuerySnapshot<DocumentData>, CommunityWatchPartyRoom[]>(
      (next, error) => onSnapshot(q, next, error),
      (snap) => snap.docs.map((d) => fromFirestoreCommunityRoom(d.data(), d.id)),
    ),
    { label: 'community-watch-rooms' },
  );
}

export function communityRoomStream(roomId: string): Source<CommunityWatchPartyRoom | null> {
  if (!roomId) {
    return (l) => {
      queueMicrotask(() => l.data(null));
      return () => {};
    };
  }
  if (AgentMode.demo) {
    seedDemoCommunityRooms();
    return (l) =>
      demoCommunityChanges.source({
        data: (list) => l.data(list.find((r) => r.id === roomId) ?? null),
      });
  }
  const ref = doc(db, 'community_watch_rooms', roomId);
  return withFirestoreTimeout(
    snapshots<DocumentData, CommunityWatchPartyRoom | null>(
      (next, error) => onSnapshot(ref, (snap) => next(snap), error),
      (snap) => (snap.exists() ? fromFirestoreCommunityRoom(snap.data(), snap.id) : null),
    ),
    { label: `community-watch-room-${roomId}` },
  );
}

export async function checkCommunityRoomMembership(roomId: string, uid: string): Promise<boolean> {
  if (!roomId || !uid) return false;
  if (isCommunityRoomUnlocked(roomId)) return true;
  if (AgentMode.demo) return false;
  try {
    const snap = await getDoc(doc(db, 'community_watch_rooms', roomId, 'members', uid));
    if (snap.exists()) {
      markCommunityRoomUnlocked(roomId);
      return true;
    }
  } catch (e) {
    Logger.e(`CommunityWatchParty: checkMembership failed for ${roomId}`, e);
  }
  return false;
}

export async function unlockCommunityWatchPartyRoom(
  roomId: string,
  candidatePassword: string,
): Promise<{ ok: boolean; error?: string }> {
  if (AgentMode.demo) {
    seedDemoCommunityRooms();
    const expected = demoCommunityPasswords.get(roomId);
    if (!expected || expected === candidatePassword.trim()) {
      markCommunityRoomUnlocked(roomId);
      return { ok: true };
    }
    return { ok: false, error: 'Incorrect room password.' };
  }
  const token = await auth.currentUser?.getIdToken();
  if (!token) return { ok: false, error: 'Sign in required.' };
  let lastError = 'Could not verify room password.';
  for (const url of communityAccessUrls()) {
    try {
      const resp = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ action: 'unlockRoom', roomId, password: candidatePassword.trim() }),
        signal: AbortSignal.timeout(10_000),
      });
      const data = (await resp.json().catch(() => ({}))) as { ok?: boolean; error?: string };
      if (resp.ok && data.ok === true) {
        markCommunityRoomUnlocked(roomId);
        return { ok: true };
      }
      lastError = data.error || `HTTP ${resp.status}`;
      if (resp.status === 400 || resp.status === 401 || resp.status === 403 || resp.status === 404 || resp.status === 429) {
        return { ok: false, error: lastError };
      }
    } catch (e) {
      Logger.e(`CommunityWatchParty: unlockRoom ${url} failed`, e);
      lastError = 'Could not reach server. Try again.';
    }
  }
  return { ok: false, error: lastError };
}

export async function createCommunityWatchPartyRoom(opts: {
  hostUid: string;
  hostName: string;
  name: string;
  password?: string;
  media?: MediaRef;
}): Promise<CommunityWatchPartyRoom> {
  const now = new Date();
  const cleanName = opts.name.trim().slice(0, 80) || 'Watch Party';
  const cleanPassword = (opts.password ?? '').trim();
  const hasPassword = cleanPassword.length > 0;
  const m = opts.media;

  const room: CommunityWatchPartyRoom = {
    id: `hub_${now.getTime()}`,
    name: cleanName,
    hostUid: opts.hostUid,
    hostName: opts.hostName,
    partnerUid: '',
    partnerName: '',
    mediaType: m?.mediaType === 'tv' ? 'tv' : 'movie',
    tmdbId: m?.tmdbId ?? 0,
    malId: m?.malId,
    isAnime: m?.isAnime ?? false,
    season: m?.season,
    episode: m?.episode,
    episodeCount: m?.episodeCount,
    title: m?.title ?? '',
    posterPath: m?.posterPath ?? '',
    serverType: 'hls',
    serverName: 'Everglow Server',
    serverHost: 'everglow',
    captionsOn: true,
    proxyEnabled: false,
    state: 'paused',
    currentTime: 0,
    positionAt: now,
    updatedAt: now,
    updatedBy: opts.hostUid,
    createdAt: now,
    active: true,
    isCommunity: true,
    hasPassword,
  };

  if (AgentMode.demo) {
    demoCommunityRooms.set(room.id, room);
    if (hasPassword) demoCommunityPasswords.set(room.id, cleanPassword);
    markCommunityRoomUnlocked(room.id);
    demoCommunityChanges.emit();
    return room;
  }

  const token = await auth.currentUser?.getIdToken();
  if (!token) throw new Error('Sign in required to host a room.');
  let lastError = 'Could not create watch party room.';
  for (const url of communityAccessUrls()) {
    try {
      const resp = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          action: 'createRoom',
          name: cleanName,
          password: cleanPassword,
          media: m ?? null,
        }),
        signal: AbortSignal.timeout(10_000),
      });
      const data = (await resp.json().catch(() => ({}))) as { roomId?: string; error?: string };
      if (resp.ok && data.roomId) {
        const saved: CommunityWatchPartyRoom = { ...room, id: data.roomId };
        markCommunityRoomUnlocked(saved.id);
        return saved;
      }
      lastError = data.error || `HTTP ${resp.status}`;
      if (resp.status === 400 || resp.status === 401 || resp.status === 403 || resp.status === 429) {
        throw new Error(lastError);
      }
    } catch (e) {
      if (e instanceof Error && !/fetch|network|abort/i.test(e.message)) throw e;
      Logger.e(`CommunityWatchParty: createRoom ${url} failed`, e);
      lastError = e instanceof Error ? e.message : String(e);
    }
  }
  throw new Error(lastError);
}

export async function updateCommunityWatchPartyRoom(
  roomId: string,
  patch: Record<string, unknown>,
): Promise<void> {
  const safePatch: Record<string, unknown> = {
    ...patch,
    serverHost: 'everglow',
    serverName: 'Everglow Server',
  };
  if ('serverType' in patch && patch.serverType !== undefined) {
    safePatch.serverType = patch.serverType === 'embed' ? 'embed' : 'hls';
  } else {
    delete safePatch.serverType;
  }
  if (AgentMode.demo) {
    const cur = demoCommunityRooms.get(roomId);
    if (cur) {
      demoCommunityRooms.set(roomId, { ...cur, ...safePatch, updatedAt: new Date() } as CommunityWatchPartyRoom);
      demoCommunityChanges.emit();
    }
    return;
  }
  await updateDoc(doc(db, 'community_watch_rooms', roomId), {
    ...safePatch,
    updatedAt: serverTimestamp(),
    ...(safePatch.state != null || safePatch.currentTime != null ? { positionAt: serverTimestamp() } : {}),
  });
}

export async function updateCommunityRoomMedia(
  roomId: string,
  media: MediaRef,
  updatedBy: string,
): Promise<void> {
  if (AgentMode.demo) {
    const cur = demoCommunityRooms.get(roomId);
    if (!cur) return;
    const now = new Date();
    demoCommunityRooms.set(roomId, {
      ...cur,
      mediaType: media.mediaType === 'tv' ? 'tv' : 'movie',
      tmdbId: media.tmdbId,
      malId: media.malId,
      isAnime: media.isAnime,
      season: media.season,
      episode: media.episode,
      episodeCount: media.episodeCount,
      title: media.title,
      posterPath: media.posterPath,
      serverType: 'hls',
      serverName: 'Everglow Server',
      serverHost: 'everglow',
      state: 'paused',
      currentTime: 0,
      positionAt: now,
      updatedAt: now,
      updatedBy,
      active: true,
    });
    demoCommunityChanges.emit();
    return;
  }
  try {
    await updateDoc(doc(db, 'community_watch_rooms', roomId), {
      mediaType: media.mediaType === 'tv' ? 'tv' : 'movie',
      tmdbId: media.tmdbId,
      malId: media.malId ?? deleteField(),
      season: media.season ?? deleteField(),
      episode: media.episode ?? deleteField(),
      episodeCount: media.episodeCount ?? deleteField(),
      isAnime: media.isAnime,
      title: media.title,
      posterPath: media.posterPath,
      serverType: 'hls',
      serverName: 'Everglow Server',
      serverHost: 'everglow',
      state: 'paused',
      currentTime: 0,
      positionAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      updatedBy,
      active: true,
    });
  } catch (e) {
    Logger.e(`CommunityWatchParty: updateMedia failed for ${roomId}`, e);
  }
}

export async function deleteCommunityWatchPartyRoom(roomId: string): Promise<void> {
  if (AgentMode.demo) {
    demoCommunityRooms.delete(roomId);
    demoCommunityChanges.emit();
    return;
  }
  await deleteDoc(doc(db, 'community_watch_rooms', roomId));
}

export function communityRoomChatStream(roomId: string): Source<WatchPartyChatMessage[]> {
  if (!roomId) {
    return (l) => {
      queueMicrotask(() => l.data([]));
      return () => {};
    };
  }
  if (AgentMode.demo) {
    return (l) =>
      demoCommunityChatChanges.source({
        data: (all) => l.data(all[roomId] ?? []),
      });
  }
  const q = query(collection(db, 'community_watch_rooms', roomId, 'messages'), orderBy('timestamp', 'desc'), limit(200));
  return withFirestoreTimeout(
    snapshots<QuerySnapshot<DocumentData>, WatchPartyChatMessage[]>(
      (next, error) => onSnapshot(q, next, error),
      (snap) =>
        snap.docs
          .map((d) => {
            const data = d.data();
            const ts = data.timestamp as Timestamp | undefined;
            return {
              id: d.id,
              senderUid: String(data.senderUid ?? ''),
              senderName: String(data.senderName ?? 'member'),
              text: String(data.text ?? ''),
              timestamp: ts?.toDate ? ts.toDate() : new Date(),
            };
          })
          .reverse(),
    ),
    { label: `community-watch-chat-${roomId}` },
  );
}

export async function sendCommunityRoomChatMessage(
  roomId: string,
  senderUid: string,
  senderName: string,
  text: string,
): Promise<void> {
  const trimmed = text.trim();
  if (!trimmed || !roomId || !senderUid || !senderName) return;
  if (AgentMode.demo) {
    const prev = demoCommunityChat.get(roomId) ?? [];
    demoCommunityChat.set(roomId, [
      ...prev,
      { id: `cmsg_${Date.now()}`, senderUid, senderName, text: trimmed, timestamp: new Date() },
    ]);
    demoCommunityChatChanges.emit();
    return;
  }
  await addDoc(collection(db, 'community_watch_rooms', roomId, 'messages'), {
    senderUid,
    senderName,
    text: trimmed,
    timestamp: serverTimestamp(),
  });
}
