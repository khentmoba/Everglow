import {
  addDoc,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
  type DocumentData,
  type QuerySnapshot,
  type Timestamp,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { Changes, snapshots, withFirestoreTimeout, withGetTimeout, type Source } from '../../core/utils/liveSource';

export interface WatchPartyRoom {
  id: string;
  name: string;
  hostUid: string;
  hostName: string;
  partnerUid: string;
  partnerName: string;
  mediaType: 'movie' | 'tv';
  tmdbId: number;
  malId?: number;
  isAnime: boolean;
  season?: number;
  episode?: number;
  episodeCount?: number;
  title: string;
  posterPath: string;
  serverType?: string;
  serverName?: string;
  serverHost?: string;
  streamUrl?: string;
  subtitleUrl?: string;
  captionsOn: boolean;
  proxyEnabled: boolean;
  state: 'playing' | 'paused' | 'buffering';
  currentTime: number;
  positionAt?: Date;
  updatedAt: Date;
  updatedBy: string;
  createdAt: Date;
  active: boolean;
}

/** `MediaRef`: the title a party plays. */
export interface MediaRef {
  tmdbId: number;
  malId?: number;
  mediaType: string;
  isAnime: boolean;
  season?: number;
  episode?: number;
  episodeCount?: number;
  title: string;
  posterPath: string;
}

export interface WatchPartyChatMessage {
  id: string;
  senderUid: string;
  senderName: string;
  text: string;
  timestamp: Date;
}

export function isRoomLive(room: WatchPartyRoom, staleMinutes = 15): boolean {
  return room.active && Date.now() - room.updatedAt.getTime() < staleMinutes * 60_000;
}

export function formatPartyTime(seconds: number): string {
  const sTotal = Math.max(0, Math.round(seconds));
  const h = Math.floor(sTotal / 3600);
  const m = Math.floor((sTotal % 3600) / 60);
  const s = sTotal % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
}

const demoRooms = new Map<string, WatchPartyRoom>();
const demoRoomChanges = new Changes<WatchPartyRoom[]>(() =>
  [...demoRooms.values()].sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime()),
);

const demoChat = new Map<string, WatchPartyChatMessage[]>();
const demoChatChanges = new Changes<Record<string, WatchPartyChatMessage[]>>(() => {
  const out: Record<string, WatchPartyChatMessage[]> = {};
  for (const [id, list] of demoChat.entries()) out[id] = list;
  return out;
});

function seedDemoRooms(myUid: string, partnerUid: string) {
  if (demoRooms.size > 0) return;
  const now = new Date();
  const list: WatchPartyRoom[] = [
    {
      id: 'demo_movie_night',
      name: 'Movie Night',
      hostUid: myUid,
      hostName: 'Khent',
      partnerUid,
      partnerName: 'Clair',
      mediaType: 'movie',
      tmdbId: 550,
      isAnime: false,
      title: 'Demo Movie Night',
      posterPath: 'assets/images/demo/poster-1.jpg',
      serverType: 'everglow',
      serverName: 'Everglow',
      serverHost: 'everglow',
      captionsOn: true,
      proxyEnabled: false,
      state: 'paused',
      currentTime: 0,
      positionAt: now,
      updatedAt: now,
      updatedBy: myUid,
      createdAt: now,
      active: true,
    },
    {
      id: 'demo_anime_night',
      name: 'Anime Night',
      hostUid: partnerUid,
      hostName: 'Clair',
      partnerUid: myUid,
      partnerName: 'Khent',
      mediaType: 'tv',
      tmdbId: 21,
      malId: 21,
      isAnime: true,
      season: 1,
      episode: 3,
      episodeCount: 1000,
      title: 'Demo Anime Night',
      posterPath: 'assets/images/demo/poster-3.jpg',
      serverType: 'everglow',
      serverName: 'Everglow',
      serverHost: 'everglow',
      captionsOn: true,
      proxyEnabled: false,
      state: 'paused',
      currentTime: 0,
      positionAt: new Date(now.getTime() - 2 * 3600_000),
      updatedAt: new Date(now.getTime() - 2 * 3600_000),
      updatedBy: partnerUid,
      createdAt: new Date(now.getTime() - 24 * 3600_000),
      active: false,
    },
  ];
  for (const r of list) demoRooms.set(r.id, r);
}

function fromFirestoreRoom(data: Record<string, unknown>, id: string): WatchPartyRoom {
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
    name: String(data.name ?? ''),
    hostUid: String(data.hostUid ?? ''),
    hostName: String(data.hostName ?? ''),
    partnerUid: String(data.partnerUid ?? ''),
    partnerName: String(data.partnerName ?? ''),
    mediaType: String(data.mediaType ?? 'movie') === 'tv' ? 'tv' : 'movie',
    tmdbId: Number(data.tmdbId ?? 0) || 0,
    malId: typeof data.malId === 'number' ? data.malId : undefined,
    isAnime: data.isAnime === true,
    season: typeof data.season === 'number' ? data.season : undefined,
    episode: typeof data.episode === 'number' ? data.episode : undefined,
    episodeCount: typeof data.episodeCount === 'number' ? data.episodeCount : undefined,
    title: String(data.title ?? ''),
    posterPath: String(data.posterPath ?? ''),
    serverType: typeof data.serverType === 'string' ? data.serverType : undefined,
    serverName: typeof data.serverName === 'string' ? data.serverName : undefined,
    serverHost: typeof data.serverHost === 'string' ? data.serverHost : undefined,
    streamUrl: typeof data.streamUrl === 'string' ? data.streamUrl : undefined,
    subtitleUrl: typeof data.subtitleUrl === 'string' ? data.subtitleUrl : undefined,
    captionsOn: data.captionsOn !== false,
    proxyEnabled: data.proxyEnabled === true,
    state: data.state === 'playing' ? 'playing' : data.state === 'buffering' ? 'buffering' : 'paused',
    currentTime: Number(data.currentTime ?? 0) || 0,
    positionAt: data.positionAt ? toDate(data.positionAt) : undefined,
    updatedAt: toDate(data.updatedAt),
    updatedBy: String(data.updatedBy ?? ''),
    createdAt: toDate(data.createdAt),
    active: data.active === true,
  };
}

export function roomsStream(uid: string): Source<WatchPartyRoom[]> {
  if (!uid) {
    return (l) => {
      queueMicrotask(() => l.data([]));
      return () => {};
    };
  }
  if (AgentMode.demo) {
    seedDemoRooms(uid, 'agent_demo_partner_uid');
    return demoRoomChanges.source;
  }

  return (l) => {
    const map = new Map<string, WatchPartyRoom>();
    const emit = () => {
      l.data([...map.values()].sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime()));
    };
    const hostQ = query(
      collection(db, 'watch_party_rooms'),
      where('hostUid', '==', uid),
      orderBy('updatedAt', 'desc'),
      limit(20),
    );
    const partQ = query(
      collection(db, 'watch_party_rooms'),
      where('partnerUid', '==', uid),
      orderBy('updatedAt', 'desc'),
      limit(20),
    );
    const u1 = onSnapshot(
      hostQ,
      (s) => {
        for (const d of s.docs) map.set(d.id, fromFirestoreRoom(d.data(), d.id));
        emit();
      },
      (e) => Logger.e('WatchParty host stream failed', e),
    );
    const u2 = onSnapshot(
      partQ,
      (s) => {
        for (const d of s.docs) map.set(d.id, fromFirestoreRoom(d.data(), d.id));
        emit();
      },
      (e) => Logger.e('WatchParty partner stream failed', e),
    );
    return () => {
      u1();
      u2();
    };
  };
}

/** `WatchPartyService.getRooms`: a one-off read of both room queries, newest first. */
export async function getWatchPartyRooms(uid: string): Promise<WatchPartyRoom[]> {
  if (!uid) return [];
  if (AgentMode.demo) {
    seedDemoRooms(uid, 'agent_demo_partner_uid');
    return [...demoRooms.values()].sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
  }
  const map = new Map<string, WatchPartyRoom>();
  for (const field of ['hostUid', 'partnerUid']) {
    const s = await withGetTimeout(
      getDocs(query(collection(db, 'watch_party_rooms'), where(field, '==', uid), orderBy('updatedAt', 'desc'), limit(20))),
      'watch party rooms',
    );
    for (const d of s.docs) map.set(d.id, fromFirestoreRoom(d.data(), d.id));
  }
  return [...map.values()].sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
}

export function roomStream(roomId: string): Source<WatchPartyRoom | null> {
  if (!roomId) {
    return (l) => {
      queueMicrotask(() => l.data(null));
      return () => {};
    };
  }
  if (AgentMode.demo) {
    return (l) =>
      demoRoomChanges.source({
        data: (list) => l.data(list.find((r) => r.id === roomId) ?? null),
      });
  }
  const ref = doc(db, 'watch_party_rooms', roomId);
  return withFirestoreTimeout(
    snapshots<DocumentData, WatchPartyRoom | null>(
      (next, error) => onSnapshot(ref, (snap) => next(snap), error),
      (snap) => (snap.exists() ? fromFirestoreRoom(snap.data(), snap.id) : null),
    ),
    { label: `watch-party-room-${roomId}` },
  );
}

export async function createWatchPartyRoom(opts: {
  hostUid: string;
  hostName: string;
  partnerUid: string;
  partnerName: string;
  name: string;
  media?: MediaRef;
}): Promise<WatchPartyRoom> {
  const now = new Date();
  const m = opts.media;
  const room: WatchPartyRoom = {
    id: `demo_${now.getTime()}`,
    name: opts.name.trim() || 'Our room',
    hostUid: opts.hostUid,
    hostName: opts.hostName,
    partnerUid: opts.partnerUid,
    partnerName: opts.partnerName,
    mediaType: m?.mediaType === 'tv' ? 'tv' : 'movie',
    tmdbId: m?.tmdbId ?? 0,
    malId: m?.malId,
    isAnime: m?.isAnime ?? false,
    season: m?.season,
    episode: m?.episode,
    episodeCount: m?.episodeCount,
    title: m?.title ?? '',
    posterPath: m?.posterPath ?? '',
    serverType: 'everglow',
    serverName: 'Everglow',
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
  };
  if (AgentMode.demo) {
    demoRooms.set(room.id, room);
    demoRoomChanges.emit();
    return room;
  }
  const ref = doc(collection(db, 'watch_party_rooms'));
  const saved = { ...room, id: ref.id };
  await setDoc(ref, {
    name: saved.name,
    hostUid: saved.hostUid,
    hostName: saved.hostName,
    partnerUid: saved.partnerUid,
    partnerName: saved.partnerName,
    mediaType: saved.mediaType,
    tmdbId: saved.tmdbId,
    ...(saved.malId != null ? { malId: saved.malId } : {}),
    isAnime: saved.isAnime,
    ...(saved.season != null ? { season: saved.season } : {}),
    ...(saved.episode != null ? { episode: saved.episode } : {}),
    ...(saved.episodeCount != null ? { episodeCount: saved.episodeCount } : {}),
    title: saved.title,
    posterPath: saved.posterPath,
    serverType: saved.serverType,
    serverName: saved.serverName,
    serverHost: saved.serverHost,
    captionsOn: saved.captionsOn,
    proxyEnabled: saved.proxyEnabled,
    state: saved.state,
    currentTime: saved.currentTime,
    updatedBy: saved.updatedBy,
    active: true,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    positionAt: serverTimestamp(),
  });
  return saved;
}

export async function updateWatchPartyRoom(roomId: string, patch: Record<string, unknown>): Promise<void> {
  if (AgentMode.demo) {
    const cur = demoRooms.get(roomId);
    if (cur) {
      demoRooms.set(roomId, { ...cur, ...patch, updatedAt: new Date() } as WatchPartyRoom);
      demoRoomChanges.emit();
    }
    return;
  }
  await updateDoc(doc(db, 'watch_party_rooms', roomId), {
    ...patch,
    updatedAt: serverTimestamp(),
  });
}

/** `WatchPartyService.updateMedia`: swap the room to a new title, paused at 0 on the Everglow server. */
export async function updateRoomMedia(roomId: string, media: MediaRef, updatedBy: string): Promise<void> {
  if (AgentMode.demo) {
    const cur = demoRooms.get(roomId);
    if (!cur) return;
    const now = new Date();
    demoRooms.set(roomId, {
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
      serverType: 'everglow',
      serverName: 'Everglow',
      serverHost: 'everglow',
      subtitleUrl: undefined,
      captionsOn: true,
      state: 'paused',
      currentTime: 0,
      positionAt: now,
      updatedAt: now,
      updatedBy,
      active: true,
    });
    demoRoomChanges.emit();
    return;
  }
  try {
    await updateDoc(doc(db, 'watch_party_rooms', roomId), {
      mediaType: media.mediaType,
      tmdbId: media.tmdbId,
      malId: media.malId ?? deleteField(),
      season: media.season ?? deleteField(),
      episode: media.episode ?? deleteField(),
      episodeCount: media.episodeCount ?? deleteField(),
      isAnime: media.isAnime,
      title: media.title,
      posterPath: media.posterPath,
      serverType: 'everglow',
      serverName: 'Everglow',
      serverHost: 'everglow',
      streamUrl: deleteField(),
      subtitleUrl: deleteField(),
      captionsOn: true,
      proxyEnabled: false,
      state: 'paused',
      currentTime: 0,
      positionAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      updatedBy,
      active: true,
    });
  } catch (e) {
    Logger.e(`WatchParty: updateMedia failed for ${roomId}`, e);
  }
}

export async function deleteWatchPartyRoom(roomId: string): Promise<void> {
  if (AgentMode.demo) {
    demoRooms.delete(roomId);
    demoRoomChanges.emit();
    return;
  }
  await deleteDoc(doc(db, 'watch_party_rooms', roomId));
}

/** `WatchPartyChatService.clearMessages`. */
export async function clearRoomChat(roomId: string): Promise<void> {
  if (!roomId) return;
  if (AgentMode.demo) {
    demoChat.delete(roomId);
    demoChatChanges.emit();
    return;
  }
  const messagesCol = collection(db, 'watch_party_chats', roomId, 'messages');
  while (true) {
    const snap = await withGetTimeout(getDocs(query(messagesCol, limit(450))), 'party chat clear scan');
    if (snap.empty) break;
    const batch = writeBatch(db);
    for (const d of snap.docs) batch.delete(d.ref);
    await batch.commit();
    if (snap.docs.length < 450) break;
  }
}

export function roomChatStream(roomId: string): Source<WatchPartyChatMessage[]> {
  if (!roomId) {
    return (l) => {
      queueMicrotask(() => l.data([]));
      return () => {};
    };
  }
  if (AgentMode.demo) {
    return (l) =>
      demoChatChanges.source({
        data: (all) => l.data(all[roomId] ?? []),
      });
  }
  const q = query(collection(db, 'watch_party_chats', roomId, 'messages'), orderBy('timestamp', 'desc'), limit(200));
  return withFirestoreTimeout(
    snapshots<QuerySnapshot<DocumentData>, WatchPartyChatMessage[]>(
      (next, error) => onSnapshot(q, next, error),
      (s) =>
        s.docs
          .map((d) => {
            const data = d.data();
            const ts = data.timestamp as Timestamp | undefined;
            return {
              id: d.id,
              senderUid: String(data.senderUid ?? ''),
              senderName: String(data.senderName ?? 'User'),
              text: String(data.text ?? ''),
              timestamp: ts?.toDate ? ts.toDate() : new Date(),
            };
          })
          .reverse(),
    ),
    { label: `watch-party-chat-${roomId}` },
  );
}

export async function sendRoomChatMessage(roomId: string, senderUid: string, senderName: string, text: string): Promise<void> {
  const trimmed = text.trim();
  if (!trimmed || !roomId) return;
  if (AgentMode.demo) {
    const prev = demoChat.get(roomId) ?? [];
    demoChat.set(roomId, [...prev, { id: `msg_${Date.now()}`, senderUid, senderName, text: trimmed, timestamp: new Date() }]);
    demoChatChanges.emit();
    return;
  }
  await addDoc(collection(db, 'watch_party_chats', roomId, 'messages'), {
    senderUid,
    senderName,
    text: trimmed,
    timestamp: serverTimestamp(),
  });
}
