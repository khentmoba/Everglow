// Port of lib/core/services/presence_service.dart and
// lib/core/models/presence_status.dart.
import { addDoc, collection, doc, onSnapshot, serverTimestamp, setDoc, Timestamp } from 'firebase/firestore';
import { AgentMode } from '../agent/agentMode';
import { Logger } from '../system/logger';
import { just, type Source } from '../utils/liveSource';
import { db } from './firebase';

export type PresenceStatus = {
  uid: string;
  username: string;
  isOnlineRaw: boolean;
  lastSeen: Date | null;
  isDoodlingRaw: boolean;
  lastDoodleAt: Date | null;
};

const ONLINE_THRESHOLD_MS = 4 * 60_000;
const DOODLE_THRESHOLD_MS = 15_000;
const DOODLE_TOUCH_MS = 15_000;
const HEARTBEAT_INTERVAL_MS = 180_000;

export const emptyPresence = (uid: string): PresenceStatus => ({
  uid,
  username: '',
  isOnlineRaw: false,
  lastSeen: null,
  isDoodlingRaw: false,
  lastDoodleAt: null,
});

export const isOnlineAt = (s: PresenceStatus, now: number) =>
  s.isOnlineRaw && s.lastSeen != null && now - s.lastSeen.getTime() <= ONLINE_THRESHOLD_MS;
export const isActivelyDoodlingAt = (s: PresenceStatus, now: number) =>
  s.isDoodlingRaw && s.lastDoodleAt != null && now - s.lastDoodleAt.getTime() <= DOODLE_THRESHOLD_MS;

const toDate = (v: unknown) => (v instanceof Timestamp ? v.toDate() : v instanceof Date ? v : null);

let heartbeatTimer = 0;
let currentUid: string | null = null;
let currentUsername: string | null = null;
let activeSessionId: string | null = null;
let sessionGen = 0;
let doodlingUid: string | null = null;
let doodleIdleTimer = 0;

function clearTimers() {
  clearInterval(heartbeatTimer);
  heartbeatTimer = 0;
  clearTimeout(doodleIdleTimer);
  doodleIdleTimer = 0;
  doodlingUid = null;
}

async function createSession(uid: string, username: string, gen: number): Promise<void> {
  try {
    const ref = await addDoc(collection(db, 'presence_sessions'), {
      uid,
      username,
      startedAt: serverTimestamp(),
      lastSeenAt: serverTimestamp(),
      endedAt: null,
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    if (gen !== sessionGen) {
      await setDoc(
        doc(db, 'presence_sessions', ref.id),
        {
          endedAt: serverTimestamp(),
          isActive: false,
          lastSeenAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      ).catch((err) => Logger.e('PresenceService stale session close failed', err));
      return;
    }
    activeSessionId = ref.id;
  } catch (e) {
    Logger.e('PresenceService _createSession failed', e);
    if (gen === sessionGen) activeSessionId = null;
  }
}

async function touchSession(): Promise<void> {
  const sid = activeSessionId;
  if (!sid) return;
  try {
    await setDoc(
      doc(db, 'presence_sessions', sid),
      { lastSeenAt: serverTimestamp(), updatedAt: serverTimestamp() },
      { merge: true },
    );
  } catch (e) {
    Logger.e('PresenceService _touchSession failed', e);
  }
}

async function closeSession(): Promise<void> {
  const sid = activeSessionId;
  activeSessionId = null;
  if (!sid) return;
  try {
    await setDoc(
      doc(db, 'presence_sessions', sid),
      {
        endedAt: serverTimestamp(),
        isActive: false,
        lastSeenAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
  } catch (e) {
    Logger.e('PresenceService _closeSession failed', e);
  }
}

export const presenceService = {
  // ci:unbounded-stream — onSnapshot listens to a single doc(db, 'presence', uid); collection() is only used for addDoc.
  watchPresence(uid: string): Source<PresenceStatus> {
    if (AgentMode.demo) return just(emptyPresence(uid));
    return (l) =>
      onSnapshot(
        doc(db, 'presence', uid),
        (snap) => {
          const data = snap.data();
          if (!data) return l.data(emptyPresence(uid));
          l.data({
            uid,
            username: typeof data.username === 'string' ? data.username : '',
            isOnlineRaw: data.isOnline === true,
            lastSeen: toDate(data.lastSeen),
            isDoodlingRaw: data.isDoodling === true,
            lastDoodleAt: toDate(data.lastDoodleAt),
          });
        },
        (e) => {
          Logger.e('PresenceService watchPresence error', e);
          l.data(emptyPresence(uid));
        },
      );
  },

  startHeartbeat(uid: string, username: string): void {
    if (!uid || AgentMode.demo) return;
    if (currentUid === uid && heartbeatTimer !== 0) return;
    if (currentUid != null && currentUid !== uid && activeSessionId != null) {
      void closeSession();
    }
    clearTimers();
    sessionGen += 1;
    const gen = sessionGen;
    currentUid = uid;
    currentUsername = username;

    void presenceService.setOnline(uid, username);
    if (activeSessionId == null) void createSession(uid, username, gen);
    else void touchSession();

    heartbeatTimer = window.setInterval(() => {
      if (!currentUid || (typeof document !== 'undefined' && document.hidden)) return;
      void presenceService.setOnline(currentUid, currentUsername ?? '');
      void touchSession();
    }, HEARTBEAT_INTERVAL_MS);
  },

  async stopHeartbeat(): Promise<void> {
    const uid = currentUid;
    sessionGen += 1;
    clearTimers();
    currentUid = null;
    currentUsername = null;
    if (uid) {
      await closeSession();
      await presenceService.setOffline(uid);
    } else if (activeSessionId != null) {
      await closeSession();
    }
  },

  async setOnline(uid: string, username: string): Promise<void> {
    if (!uid || AgentMode.demo) return;
    try {
      await setDoc(
        doc(db, 'presence', uid),
        {
          isOnline: true,
          lastSeen: serverTimestamp(),
          username,
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
    } catch (e) {
      Logger.e(`PresenceService.setOnline FAILED for ${uid} (${username})`, e);
    }
  },

  async setOffline(uid: string): Promise<void> {
    if (!uid || AgentMode.demo) return;
    if (currentUid === uid) clearTimers();
    try {
      await setDoc(
        doc(db, 'presence', uid),
        {
          isOnline: false,
          isDoodling: false,
          lastSeen: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
    } catch (e) {
      Logger.e(`PresenceService.setOffline FAILED for ${uid}`, e);
    }
  },

  async markDoodling(uid: string): Promise<void> {
    if (uid === '' || AgentMode.demo) return;
    doodlingUid = uid;
    try {
      await setDoc(
        doc(db, 'presence', uid),
        {
          isOnline: true,
          isDoodling: true,
          lastSeen: serverTimestamp(),
          lastDoodleAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
    } catch (e) {
      Logger.e('PresenceService markDoodling error', e);
    }
    clearTimeout(doodleIdleTimer);
    doodleIdleTimer = window.setTimeout(() => void presenceService.clearDoodling(uid), DOODLE_TOUCH_MS);
  },

  async clearDoodling(uid: string): Promise<void> {
    if (uid === '' || AgentMode.demo) return;
    clearTimeout(doodleIdleTimer);
    if (doodlingUid !== uid) return;
    doodlingUid = null;
    try {
      await setDoc(doc(db, 'presence', uid), { isDoodling: false, updatedAt: serverTimestamp() }, { merge: true });
    } catch (e) {
      Logger.e('PresenceService clearDoodling error', e);
    }
  },
};
