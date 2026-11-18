// Port of lib/features/play_zone/table_tennis/data: TTRoom, TTMultiplayerService and TTBridgeService.
import {
  collection,
  deleteDoc,
  doc,
  getDocs,
  limit,
  onSnapshot,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  type DocumentData,
  type DocumentSnapshot,
} from 'firebase/firestore';
import { db } from '../../../core/services/firebase';
import { Logger } from '../../../core/system/logger';
import { snapshots, withFirestoreTimeout, withGetTimeout, type Source } from '../../../core/utils/liveSource';

export type TTRoomStatus = 'waiting' | 'playing' | 'finished' | 'abandoned';
export type BallState = { x: number; y: number; vx: number; vy: number };
export type TTRoom = {
  id: string;
  hostUid: string;
  guestUid: string | null;
  hostSide: string;
  status: TTRoomStatus;
  hostPaddleY: number;
  guestPaddleY: number;
  ball: BallState;
  hostScore: number;
  guestScore: number;
  lastTick: number;
  updatedAt: Timestamp;
};

const COLLECTION = 'tt_rooms';
const ID_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const roomDoc = (id: string) => doc(db, COLLECTION, id);
const num = (v: unknown, fallback: number) => (typeof v === 'number' ? v : fallback);
const int = (v: unknown) => (typeof v === 'number' && Number.isInteger(v) ? v : 0);
const zeroBall = (): BallState => ({ x: 0, y: 0, vx: 0, vy: 0 });

function statusFrom(s: unknown): TTRoomStatus {
  return s === 'playing' || s === 'finished' || s === 'abandoned' ? s : 'waiting';
}

export function ballFromMap(m: Record<string, unknown> | null | undefined): BallState {
  if (!m) return zeroBall();
  return { x: num(m.x, 0), y: num(m.y, 0), vx: num(m.vx, 0), vy: num(m.vy, 0) };
}

export function roomFromDoc(id: string, data: DocumentData | undefined): TTRoom {
  const d = data ?? {};
  const ball = d.ball && typeof d.ball === 'object' && !Array.isArray(d.ball) ? (d.ball as Record<string, unknown>) : null;
  return {
    id,
    hostUid: typeof d.hostUid === 'string' ? d.hostUid : '',
    guestUid: typeof d.guestUid === 'string' ? d.guestUid : null,
    hostSide: typeof d.hostSide === 'string' ? d.hostSide : 'near',
    status: statusFrom(d.status),
    hostPaddleY: num(d.hostPaddleY, 0.5),
    guestPaddleY: num(d.guestPaddleY, 0.5),
    ball: ballFromMap(ball),
    hostScore: int(d.hostScore),
    guestScore: int(d.guestScore),
    lastTick: int(d.lastTick),
    updatedAt: d.updatedAt instanceof Timestamp ? d.updatedAt : Timestamp.now(),
  };
}

function generateId() {
  const values = crypto.getRandomValues(new Uint32Array(8));
  return Array.from(values, (v) => ID_CHARS[v % ID_CHARS.length]).join('');
}

export const ttService = {
  async createRoom(hostUid: string): Promise<TTRoom> {
    const room: TTRoom = {
      id: generateId(),
      hostUid,
      guestUid: null,
      hostSide: Date.now() % 2 === 0 ? 'near' : 'far',
      status: 'waiting',
      hostPaddleY: 0.5,
      guestPaddleY: 0.5,
      ball: zeroBall(),
      hostScore: 0,
      guestScore: 0,
      lastTick: 0,
      updatedAt: Timestamp.now(),
    };
    const { id, ...fields } = room;
    await setDoc(roomDoc(id), fields);
    return room;
  },

  async findOpenRoom(myUid: string): Promise<TTRoom | null> {
    const snap = await withGetTimeout(
      getDocs(query(collection(db, COLLECTION), where('status', '==', 'waiting'), where('hostUid', '!=', myUid), limit(1))),
      'table tennis open room',
    );
    if (snap.empty) return null;
    const d = snap.docs[0];
    return roomFromDoc(d.id, d.data());
  },

  joinRoom(roomId: string, guestUid: string): Promise<TTRoom> {
    const ref = roomDoc(roomId);
    return runTransaction(db, async (txn) => {
      const result = await txn.get(ref);
      if (!result.exists()) throw new Error('Bad state: Room not found');
      const current = roomFromDoc(result.id, result.data());
      if (current.guestUid != null) throw new Error('Bad state: Room already has a guest');
      if (current.status !== 'waiting') throw new Error('Bad state: Match already in progress');
      if (current.hostUid === guestUid) throw new Error('Bad state: You cannot join your own room');
      const lastTick = current.lastTick + 1;
      txn.update(ref, { guestUid, status: 'playing', lastTick, updatedAt: serverTimestamp() });
      return { ...current, guestUid, status: 'playing' as const, lastTick, updatedAt: Timestamp.now() };
    });
  },

  watchRoom(roomId: string): Source<TTRoom> {
    const ref = roomDoc(roomId);
    return withFirestoreTimeout(
      snapshots<DocumentSnapshot<DocumentData>, TTRoom>(
        (next, error) => onSnapshot(ref, next, error),
        (s) => roomFromDoc(s.id, s.data()),
      ),
      { label: `tt-room-${roomId}` },
    );
  },

  /** Tick-guarded write: skipped unless the room is playing and this tick is newer. */
  async guardedUpdate(roomId: string, localTick: number, fields: Record<string, unknown>, label: string) {
    const ref = roomDoc(roomId);
    try {
      await runTransaction(db, async (txn) => {
        const snap = await txn.get(ref);
        if (!snap.exists() || snap.data()?.status !== 'playing') return;
        if (localTick < int(snap.data()?.lastTick) + 1) return;
        txn.update(ref, { ...fields, lastTick: localTick, updatedAt: serverTimestamp() });
      });
    } catch (e) {
      Logger.e(`${label} failed`, e);
    }
  },

  endMatch(roomId: string) {
    return updateDoc(roomDoc(roomId), { status: 'finished', updatedAt: serverTimestamp() });
  },

  deleteRoom(roomId: string) {
    return deleteDoc(roomDoc(roomId));
  },
};

/** TTMultiplayerState: the latest values the game iframe reported. */
export const ttLocalState = {
  localPaddleY: -1,
  latestBall: null as BallState | null,
  latestHostScore: 0,
  latestGuestScore: 0,
};

export function handleTTMessage(event: MessageEvent) {
  const map = event.data as Record<string, unknown> | null;
  if (!map || typeof map !== 'object' || Array.isArray(map)) return;
  switch (map.type) {
    case 'LOCAL_PADDLE':
      ttLocalState.localPaddleY = num(map.y, 0.5);
      break;
    case 'LOCAL_BALL':
      ttLocalState.latestBall = ballFromMap(map);
      break;
    case 'LOCAL_SCORE':
      ttLocalState.latestHostScore = int(map.hostScore);
      ttLocalState.latestGuestScore = int(map.guestScore);
      break;
  }
}

export const findTTIframe = () => document.querySelector<HTMLIFrameElement>('iframe[data-everglow-tt="1"]');

function post(iframe: HTMLIFrameElement, type: string, data: Record<string, unknown>) {
  try {
    iframe.contentWindow?.postMessage({ type, ...data }, '*');
  } catch (e) {
    Logger.w(`[TTBridgeService] Failed to post message to iframe: ${String(e)}`);
  }
}

/** TTBridgeService: Firestore room <-> game iframe, newest-only writes every 200ms. */
export class TTBridge {
  private roomId: string | null = null;
  private isHost = false;
  private localTick = 0;
  private lastState = '';
  private generation = 0;
  private running = false;
  private unsub: (() => void) | null = null;
  private timer = 0;
  private pending: (() => Promise<void>) | null = null;
  private writing = false;

  connect(roomId: string, isHost: boolean) {
    clearInterval(this.timer);
    this.unsub?.();
    this.pending = null;
    ++this.generation;
    this.roomId = roomId;
    this.isHost = isHost;
    this.localTick = 0;
    this.running = true;
    this.lastState = '';

    const iframe = findTTIframe();
    if (iframe) post(iframe, 'START_MP', { isHost, side: isHost ? 'near' : 'far' });

    this.unsub = ttService.watchRoom(roomId)({
      data: (room) => {
        if (!this.running || this.roomId !== roomId) return;
        this.localTick = Math.max(this.localTick, room.lastTick);
        const f = findTTIframe();
        if (!f) return;
        post(f, 'REMOTE_PADDLE', { y: isHost ? room.guestPaddleY : room.hostPaddleY });
        if (!isHost) post(f, 'REMOTE_BALL', { ...room.ball });
        post(f, 'REMOTE_SCORE', { hostScore: room.hostScore, guestScore: room.guestScore });
      },
    });
    this.timer = window.setInterval(() => this.sendState(), 200);
  }

  private sendState() {
    const roomId = this.roomId;
    const paddle = ttLocalState.localPaddleY;
    if (!this.running || roomId == null || paddle < 0) return;
    const ball = ttLocalState.latestBall ?? zeroBall();
    const hostScore = ttLocalState.latestHostScore;
    const guestScore = ttLocalState.latestGuestScore;
    const signature = this.isHost
      ? `${paddle}|${ball.x}|${ball.y}|${ball.vx}|${ball.vy}|${hostScore}|${guestScore}`
      : `${paddle}`;
    if (this.lastState === signature) return;
    this.lastState = signature;
    const generation = this.generation;
    const host = this.isHost;
    this.add(async () => {
      if (!this.running || generation !== this.generation) return;
      const tick = ++this.localTick;
      if (host) {
        await ttService.guardedUpdate(
          roomId,
          tick,
          { hostPaddleY: paddle, ball: { ...ball }, hostScore, guestScore, status: 'playing' },
          'writeHostState',
        );
      } else {
        await ttService.guardedUpdate(roomId, tick, { guestPaddleY: paddle }, 'writeGuestPaddle');
      }
    });
  }

  /** LatestValueWriter: one write at a time; only the newest waiting write runs next. */
  private add(save: () => Promise<void>) {
    this.pending = save;
    if (this.writing) return;
    this.writing = true;
    void (async () => {
      while (this.pending) {
        const next = this.pending;
        this.pending = null;
        try {
          await next();
        } catch (e) {
          Logger.e('Table tennis sync failed', e);
        }
      }
      this.writing = false;
    })();
  }

  disconnect() {
    this.running = false;
    this.unsub?.();
    this.unsub = null;
    clearInterval(this.timer);
    ++this.generation;
    this.pending = null;
    if (this.roomId != null && this.isHost) {
      ttService.endMatch(this.roomId).catch((e) => Logger.e('Table tennis endMatch failed', e));
    }
    this.roomId = null;
  }
}
