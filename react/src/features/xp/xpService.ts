// lib/features/xp: UserProgress, XpService.watchProgress and the daily-capped awards.
import {
  doc,
  onSnapshot,
  runTransaction,
  serverTimestamp,
  type DocumentData,
  type DocumentSnapshot,
  type Timestamp,
} from 'firebase/firestore';
import { playSfx, Sfx } from '../../core/audio/audioService';
import { Logger } from '../../core/system/logger';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { just, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export type UserProgress = { uid: string; xpTotal: number; level: number; streak: number; lastActivity: Date };

export const XP_PER_LEVEL = 200;
export const levelForXp = (xp: number) => (xp <= 0 ? 1 : Math.floor(xp / XP_PER_LEVEL) + 1);
export const xpIntoLevel = (xp: number) => (xp <= 0 ? 0 : xp % XP_PER_LEVEL);
export const xpToNextLevel = (xp: number) => XP_PER_LEVEL - xpIntoLevel(xp);

function fromMap(uid: string, map: Record<string, unknown>): UserProgress {
  return {
    uid,
    xpTotal: Math.trunc(Number(map.xpTotal ?? 0)),
    level: Math.trunc(Number(map.level ?? 1)),
    streak: Math.trunc(Number(map.streak ?? 0)),
    lastActivity: (map.lastActivity as Timestamp | undefined)?.toDate() ?? new Date(),
  };
}

export const xpService = {
  watchProgress(uid: string): Source<UserProgress | null> {
    if (AgentMode.demo) return just(AgentFixtures.demoProgress(uid));
    const ref = doc(db, 'users', uid, 'progress', 'main');
    return withFirestoreTimeout(
      snapshots<DocumentSnapshot<DocumentData>, UserProgress | null>(
        (next, error) => onSnapshot(ref, next, error),
        (s) => (s.exists() ? fromMap(uid, s.data()) : null),
      ),
      { label: 'xp-progress' },
    );
  },
};

export type XpAward = { amount: number; dailyCap: number };
export const playAward: XpAward = { amount: 3, dailyCap: 20 };

const todayKey = (now = new Date()) =>
  `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

/** XPService.computeDailyAward: null once today's cap for this action is used up. */
export function computeDailyAward(data: Record<string, unknown>, action: string, award: XpAward, today: string) {
  const raw = data.dailyXp;
  const counters: Record<string, unknown> = raw && typeof raw === 'object' ? { ...(raw as Record<string, unknown>) } : {};
  const entry = counters[today];
  const todayCounts: Record<string, unknown> =
    entry && typeof entry === 'object' ? { ...(entry as Record<string, unknown>) } : {};
  const used = typeof todayCounts[action] === 'number' ? Math.trunc(todayCounts[action] as number) : 0;
  if (used >= award.dailyCap) return null;
  todayCounts[action] = used + 1;
  counters[today] = todayCounts;
  const newXp = (typeof data.xpTotal === 'number' ? Math.trunc(data.xpTotal) : 0) + award.amount;
  const newLevel = levelForXp(newXp);
  const storedLevel = typeof data.level === 'number' ? Math.trunc(data.level) : 1;
  return { counters, newXp, newLevel, leveledUp: newLevel > storedLevel };
}

let lastOp: Promise<unknown> = Promise.resolve();

/** XPService.awardDaily: one transaction per award, queued so awards never race each other. */
export function awardDaily(uid: string, action: string, award: XpAward): Promise<boolean> {
  if (AgentMode.demo) return Promise.resolve(false);
  const run = async () => {
    const ref = doc(db, 'users', uid, 'progress', 'main');
    try {
      const outcome = await Promise.race([
        runTransaction(db, async (txn) => {
          const snap = await txn.get(ref);
          const data = snap.exists() ? (snap.data() ?? {}) : {};
          const computed = computeDailyAward(data, action, award, todayKey());
          if (computed == null) return null;
          const fields = {
            xpTotal: computed.newXp,
            level: computed.newLevel,
            dailyXp: computed.counters,
            lastActivity: serverTimestamp(),
          };
          if (snap.exists()) txn.update(ref, fields);
          else txn.set(ref, { ...fields, streak: 1 });
          return computed;
        }),
        new Promise<'timeout'>((r) => setTimeout(() => r('timeout'), 8000)),
      ]);
      if (outcome === 'timeout') {
        Logger.w(`XP awardDaily timed out (${action})`);
        return false;
      }
      if (outcome == null) return false;
      void playSfx(outcome.leveledUp ? Sfx.levelUp : Sfx.sparkle);
      return true;
    } catch (e) {
      Logger.e(`XP awardDaily failed (${action})`, e);
      return false;
    }
  };
  const next = lastOp.then(run, run);
  lastOp = next;
  return next;
}
