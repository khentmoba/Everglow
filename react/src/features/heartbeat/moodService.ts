// lib/features/heartbeat/data: UserMood and MoodService, plus MoodController.
import {
  addDoc,
  collection,
  doc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  where,
  type DocumentData,
  type QuerySnapshot,
  type Timestamp,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { ValueNotifier } from '../../core/system/store';
import { Changes, snapshots, withFirestoreTimeout, withGetTimeout, type Source } from '../../core/utils/liveSource';

export const HeartNeeds = {
  hug: 'Could use a hug',
  talk: 'Want to talk',
  company: 'Keep me company',
  quiet: 'Need some quiet',
} as const;
export type HeartNeed = keyof typeof HeartNeeds;

export type UserMood = {
  id: string | null;
  need: HeartNeed | null;
  acknowledgedBy: string | null;
  username: string;
  moodScore: number;
  moodEmoji: string;
  timestamp: Date;
};

export const isCurrentAt = (m: UserMood, now: Date) =>
  m.timestamp.getFullYear() === now.getFullYear() &&
  m.timestamp.getMonth() === now.getMonth() &&
  m.timestamp.getDate() === now.getDate();

function fromFirestore(data: Record<string, unknown>, id: string): UserMood {
  const need = data.need as string | undefined;
  return {
    id,
    need: need && need in HeartNeeds ? (need as HeartNeed) : null,
    acknowledgedBy: (data.acknowledgedBy as string | undefined) ?? null,
    username: (data.username as string | undefined) ?? '',
    moodScore: (data.moodScore as number | undefined) ?? 3,
    moodEmoji: (data.moodEmoji as string | undefined) ?? '💖',
    timestamp: (data.timestamp as Timestamp | undefined)?.toDate() ?? new Date(),
  };
}

const pad = (n: number, w = 2) => String(n).padStart(w, '0');
const dateKeyFor = (d: Date) => `${pad(d.getFullYear(), 4)}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

class MoodService {
  private demoMoods = new Map<string, UserMood>();
  private demoChanges = new Map<string, Changes<UserMood>>();

  private demoMood(username: string): UserMood {
    return (
      this.demoMoods.get(username) ?? {
        id: `demo_${username}`,
        username,
        moodScore: AgentFixtures.demoMood.moodScore,
        moodEmoji: AgentFixtures.demoMood.moodEmoji,
        need: username === 'clairjassen' ? 'company' : null,
        acknowledgedBy: null,
        timestamp: new Date(),
      }
    );
  }

  private changes(username: string): Changes<UserMood> {
    let c = this.demoChanges.get(username);
    if (!c) {
      c = new Changes(() => this.demoMood(username));
      this.demoChanges.set(username, c);
    }
    return c;
  }

  private emitAll() {
    for (const c of this.demoChanges.values()) c.emit();
  }

  async submitMood(o: { username: string; score: number; emoji: string; need?: HeartNeed | null }): Promise<void> {
    if (AgentMode.isActive.value) {
      this.demoMoods.set(o.username, {
        id: `demo_${o.username}`,
        username: o.username,
        moodScore: o.score,
        moodEmoji: o.emoji,
        need: o.need ?? null,
        acknowledgedBy: null,
        timestamp: new Date(),
      });
      this.emitAll();
      return;
    }
    await addDoc(collection(db, 'moods'), {
      username: o.username,
      uid: o.username,
      date: dateKeyFor(new Date()),
      moodScore: o.score,
      moodEmoji: o.emoji,
      ...(o.need ? { need: o.need } : {}),
      timestamp: serverTimestamp(),
    });
  }

  async acknowledge(mood: UserMood, username: string): Promise<void> {
    if (!isCurrentAt(mood, new Date()) || mood.need == null || mood.id == null) {
      throw new Error('This check-in has expired');
    }
    if (AgentMode.isActive.value) {
      this.demoMoods.set(mood.username, { ...mood, acknowledgedBy: username });
      this.emitAll();
      return;
    }
    try {
      await updateDoc(doc(db, 'moods', mood.id), { acknowledgedBy: username });
    } catch (e) {
      Logger.e('Could not acknowledge mood', e);
      throw e;
    }
  }

  async hasSubmittedToday(username: string): Promise<boolean> {
    if (AgentMode.demo) return true;
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const snap = await withGetTimeout(
      getDocs(
        query(
          collection(db, 'moods'),
          where('username', '==', username),
          where('timestamp', '>=', startOfDay),
          orderBy('timestamp', 'desc'),
          limit(1),
        ),
      ),
      'mood today check',
    );
    return !snap.empty;
  }

  async getLatestMood(username: string): Promise<UserMood | null> {
    if (AgentMode.demo) return this.demoMood(username);
    const snap = await withGetTimeout(
      getDocs(query(collection(db, 'moods'), where('username', '==', username), orderBy('timestamp', 'desc'), limit(1))),
      `latest mood ${username}`,
    );
    return snap.empty ? null : fromFirestore(snap.docs[0].data(), snap.docs[0].id);
  }

  watchLatestMood(username: string): Source<UserMood | null> {
    if (AgentMode.demo) return this.changes(username).source;
    const q = query(collection(db, 'moods'), where('username', '==', username), orderBy('timestamp', 'desc'), limit(1));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, UserMood | null>(
        (next, error) => onSnapshot(q, next, error),
        (s) => (s.empty ? null : fromFirestore(s.docs[0].data(), s.docs[0].id)),
      ),
      { label: `mood-${username}` },
    );
  }
}

export const moodService = new MoodService();

/** MoodController: today's check-in state for the signed-in person. */
export const moodController = {
  hasSubmittedToday: new ValueNotifier(false),
  isSaving: new ValueNotifier(false),
  selectedScore: new ValueNotifier<number | null>(null),
  saveError: new ValueNotifier<string | null>(null),
  async checkTodayStatus(username: string) {
    try {
      moodController.hasSubmittedToday.value = await moodService.hasSubmittedToday(username);
    } catch (e) {
      Logger.e('Mood checkTodayStatus failed', e);
    }
  },
  async submitMood(o: { username: string; score: number; emoji: string; uid?: string | null; need?: HeartNeed | null }) {
    if (moodController.isSaving.value || !o.username) return;
    moodController.isSaving.value = true;
    moodController.saveError.value = null;
    moodController.selectedScore.value = o.score;
    try {
      await moodService.submitMood(o);
      moodController.isSaving.value = false;
      moodController.hasSubmittedToday.value = true;
    } catch (e) {
      moodController.isSaving.value = false;
      moodController.saveError.value = 'Could not save your check-in. Please try again.';
      Logger.e('Could not save mood', e);
      moodController.selectedScore.value = null;
    }
  },
};
