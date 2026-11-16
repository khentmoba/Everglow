// The parts of lib/core/services/presence_service.dart and
// lib/core/models/presence_status.dart the canvas needs (doodle presence).
import { doc, onSnapshot, serverTimestamp, setDoc, Timestamp } from 'firebase/firestore';
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

let doodlingUid: string | null = null;
let doodleIdleTimer = 0;

export const presenceService = {
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
