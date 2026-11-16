// lib/features/xp: UserProgress and XpService.watchProgress.
import { doc, onSnapshot, type DocumentData, type DocumentSnapshot, type Timestamp } from 'firebase/firestore';
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
