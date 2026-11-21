import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  limit as fbLimit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  type DocumentData,
  type DocumentSnapshot,
  type QuerySnapshot,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type MilestoneCategory } from '../../core/agent/fixtures';
import { auth, db, loadStorage } from '../../core/services/firebase';
import { probeSystemHealth, type SystemStatus } from '../../core/system/healthService';
import { Logger } from '../../core/system/logger';
import { Prefs } from '../../core/system/prefs';
import { just, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';
import type { HiddenNote } from './letterboxService';
import type { Milestone } from './milestoneService';

export interface GuardianWhisper {
  id: string;
  content: string;
  category: string;
  createdAt?: Date;
}

export interface TonightFeature {
  title: string;
  mediaType: string;
  posterPath?: string;
  note?: string;
  setBy?: string;
  active: boolean;
}

export interface MemberAccount {
  id: string;
  username: string;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: string | null;
  approvedAt: string | null;
  approvedBy: string | null;
}

let demoAccounts: MemberAccount[] = [
  {
    id: 'mika_chan',
    username: 'mika_chan',
    status: 'pending',
    createdAt: new Date(Date.now() - 18 * 60_000).toISOString(),
    approvedAt: null,
    approvedBy: null,
  },
  {
    id: 'sora99',
    username: 'sora99',
    status: 'pending',
    createdAt: new Date(Date.now() - 2 * 3600_000).toISOString(),
    approvedAt: null,
    approvedBy: null,
  },
  {
    id: 'kenji',
    username: 'kenji',
    status: 'approved',
    createdAt: new Date(Date.now() - 3 * 86400_000).toISOString(),
    approvedAt: new Date(Date.now() - 2 * 86400_000).toISOString(),
    approvedBy: 'khentsgdz',
  },
];

function manageAccountsUrls(): string[] {
  const host = window.location.hostname;
  const isLocal = host === 'localhost' || host === '127.0.0.1' || host === '0.0.0.0';
  return [
    ...(isLocal ? [] : ['/api/manageAccounts']),
    'https://us-central1-everglow-1c6db.cloudfunctions.net/manageAccounts',
  ];
}

const DEMO_WHISPERS: GuardianWhisper[] = [
  { id: 'w1', content: 'You are doing amazing today, my love', category: 'whisper', createdAt: new Date() },
  { id: 'w2', content: 'Check the Letterbox… something secret is waiting', category: 'whisper', createdAt: new Date() },
];

export const creatorService = {
  watchHiddenNotes(max = 50): Source<HiddenNote[]> {
    if (AgentMode.demo) return just(AgentFixtures.demoNotes());
    const q = query(collection(db, 'notes'), orderBy('unlockDate', 'desc'), fbLimit(max));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, HiddenNote[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) =>
          s.docs.map((d) => {
            const data = d.data();
            return {
              id: d.id,
              title: String(data.title ?? ''),
              content: String(data.content ?? ''),
              unlockDate: (data.unlockDate as Timestamp | undefined)?.toDate() ?? new Date(),
              isRead: Boolean(data.isRead),
            };
          }),
      ),
      { label: 'creator-notes' },
    );
  },

  async saveHiddenNote(opts: { title: string; content: string; unlockDate: Date }): Promise<void> {
    if (AgentMode.demo) return;
    await addDoc(collection(db, 'notes'), {
      title: opts.title.trim(),
      content: opts.content.trim(),
      unlockDate: Timestamp.fromDate(opts.unlockDate),
      isRead: false,
      createdAt: serverTimestamp(),
    });
  },

  async updateHiddenNote(opts: { id: string; title: string; content: string; unlockDate: Date }): Promise<void> {
    if (AgentMode.demo) return;
    await updateDoc(doc(db, 'notes', opts.id), {
      title: opts.title.trim(),
      content: opts.content.trim(),
      unlockDate: Timestamp.fromDate(opts.unlockDate),
    });
  },

  async deleteHiddenNote(id: string): Promise<void> {
    if (AgentMode.demo) return;
    await deleteDoc(doc(db, 'notes', id));
  },

  watchMilestones(max = 50): Source<Milestone[]> {
    if (AgentMode.demo) return just(AgentFixtures.demoMilestones());
    const q = query(collection(db, 'milestones'), orderBy('date', 'desc'), fbLimit(max));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, Milestone[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) =>
          s.docs.map((d) => {
            const data = d.data();
            const rawCat = data.category;
            const category: MilestoneCategory =
              rawCat === 'firstDate' || rawCat === 'anniversary' || rawCat === 'trip' || rawCat === 'memory'
                ? rawCat
                : 'other';
            const urls = Array.isArray(data.imageUrls)
              ? data.imageUrls.filter((u): u is string => typeof u === 'string' && u.length > 0)
              : [];
            return {
              id: d.id,
              title: String(data.title ?? ''),
              description: String(data.description ?? ''),
              date: (data.date as Timestamp | undefined)?.toDate() ?? new Date(),
              imageUrls: urls,
              category,
              author: typeof data.author === 'string' ? data.author : '',
            };
          }),
      ),
      { label: 'creator-milestones' },
    );
  },

  async uploadMilestoneImage(file: File, userId: string): Promise<string | null> {
    if (AgentMode.demo) return null;
    try {
      const { storage, mod } = await loadStorage();
      const safeName = `${Date.now()}_${file.name.replace(/[^a-zA-Z0-9._-]/g, '_')}`;
      const storageRef = mod.ref(storage, `milestones/${userId}/${safeName}`);
      const snap = await mod.uploadBytes(storageRef, file, { contentType: file.type || 'image/jpeg' });
      return await mod.getDownloadURL(snap.ref);
    } catch (e) {
      Logger.e('CreatorService: milestone image upload failed', e);
      return null;
    }
  },

  async saveMilestone(opts: {
    title: string;
    description: string;
    date: Date;
    category: MilestoneCategory;
    imageUrls: string[];
    author?: string;
  }): Promise<void> {
    if (AgentMode.demo) return;
    await addDoc(collection(db, 'milestones'), {
      title: opts.title.trim(),
      description: opts.description.trim(),
      date: Timestamp.fromDate(opts.date),
      category: opts.category,
      imageUrls: opts.imageUrls,
      ...(opts.author ? { author: opts.author } : {}),
      createdAt: serverTimestamp(),
    });
  },

  async updateMilestone(opts: {
    id: string;
    title: string;
    description: string;
    date: Date;
    category: MilestoneCategory;
    imageUrls: string[];
    author?: string;
  }): Promise<void> {
    if (AgentMode.demo) return;
    await updateDoc(doc(db, 'milestones', opts.id), {
      title: opts.title.trim(),
      description: opts.description.trim(),
      date: Timestamp.fromDate(opts.date),
      category: opts.category,
      imageUrls: opts.imageUrls,
      ...(opts.author ? { author: opts.author } : {}),
    });
  },

  async deleteMilestone(id: string): Promise<void> {
    if (AgentMode.demo) return;
    await deleteDoc(doc(db, 'milestones', id));
  },

  watchGuardianWhispers(max = 12): Source<GuardianWhisper[]> {
    if (AgentMode.demo) return just(DEMO_WHISPERS);
    const q = query(collection(db, 'guardian_messages'), where('category', '==', 'whisper'), fbLimit(max));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, GuardianWhisper[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) =>
          s.docs.map((d) => {
            const data = d.data();
            return {
              id: d.id,
              content: String(data.content ?? ''),
              category: String(data.category ?? 'whisper'),
              createdAt: (data.createdAt as Timestamp | undefined)?.toDate(),
            };
          }),
      ),
      { label: 'creator-whispers' },
    );
  },

  async sendGuardianWhisper(content: string): Promise<void> {
    const trimmed = content.trim();
    if (!trimmed || AgentMode.demo) return;
    await addDoc(collection(db, 'guardian_messages'), {
      content: trimmed,
      category: 'whisper',
      createdAt: serverTimestamp(),
    });
  },

  async deleteGuardianWhisper(id: string): Promise<void> {
    if (AgentMode.demo) return;
    await deleteDoc(doc(db, 'guardian_messages', id));
  },

  async sendLoveBurst(message: string, author: string): Promise<void> {
    const trimmed = message.trim();
    if (!trimmed || AgentMode.demo) return;
    await addDoc(collection(db, 'starlight_jar'), {
      content: trimmed,
      author,
      timestamp: serverTimestamp(),
      category: 'surprise',
      tags: ['surprise', 'love_burst', 'creator'],
      likes: 0,
      opened: false,
      openedAt: null,
    });
  },

  async createTeaserCountdown(opts: {
    title: string;
    date: Date;
    description?: string;
    createdBy: string;
  }): Promise<void> {
    if (!opts.title.trim() || AgentMode.demo) return;
    await addDoc(collection(db, 'calendar_events'), {
      title: opts.title.trim(),
      description: (opts.description?.trim() || 'Surprise countdown for Clair').trim(),
      date: Timestamp.fromDate(opts.date),
      type: 'date_night',
      createdBy: opts.createdBy,
      recurring: 'none',
      attendees: ['khentsgdz', 'clairjassen'],
      isAllDay: true,
      createdAt: serverTimestamp(),
    });
  },

  watchTonightFeature(): Source<TonightFeature | null> {
    if (AgentMode.demo) {
      return just({
        title: 'Past Lives',
        mediaType: 'movie',
        note: 'Movie night with matcha & blankets',
        setBy: 'khentsgdz',
        active: true,
      });
    }
    const ref = doc(db, 'our_cinema', 'tonight_feature');
    return withFirestoreTimeout(
      snapshots<DocumentSnapshot<DocumentData>, TonightFeature | null>(
        (next, error) => onSnapshot(ref, next, error),
        (snap) => {
          if (!snap.exists()) return null;
          const d = snap.data();
          return {
            title: String(d.title ?? ''),
            mediaType: String(d.mediaType ?? 'movie'),
            posterPath: typeof d.posterPath === 'string' ? d.posterPath : undefined,
            note: typeof d.note === 'string' ? d.note : undefined,
            setBy: typeof d.setBy === 'string' ? d.setBy : undefined,
            active: Boolean(d.active),
          };
        },
      ),
      { label: 'creator-tonight-feature' },
    );
  },

  async setTonightFeature(opts: {
    title: string;
    mediaType: string;
    note?: string;
    setBy: string;
  }): Promise<void> {
    if (!opts.title.trim() || AgentMode.demo) return;
    await setDoc(
      doc(db, 'our_cinema', 'tonight_feature'),
      {
        title: opts.title.trim(),
        mediaType: opts.mediaType,
        note: (opts.note ?? '').trim(),
        setBy: opts.setBy,
        active: true,
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
  },

  async clearTonightFeature(): Promise<void> {
    if (AgentMode.demo) return;
    await setDoc(
      doc(db, 'our_cinema', 'tonight_feature'),
      { active: false, updatedAt: serverTimestamp() },
      { merge: true },
    );
  },

  fetchHealthStatus(): Promise<SystemStatus> {
    return probeSystemHealth();
  },

  async fetchMotchiStats(): Promise<Record<string, unknown> | null> {
    if (AgentMode.demo) {
      return { totalMessages: 412, memoriesCount: 28, model: 'Motchi (demo)' };
    }
    try {
      const token = await auth.currentUser?.getIdToken();
      if (!token) return null;
      const resp = await fetch('https://us-central1-everglow-1c6db.cloudfunctions.net/motchiStats', {
        headers: { Authorization: `Bearer ${token}` },
        signal: AbortSignal.timeout(10000),
      });
      if (!resp.ok) return null;
      const decoded = (await resp.json()) as unknown;
      return decoded && typeof decoded === 'object' ? (decoded as Record<string, unknown>) : null;
    } catch (e) {
      Logger.e('CreatorService: motchiStats fetch failed', e);
      return null;
    }
  },

  clearLocalCaches(): void {
    Prefs.remove('letterbox_notes_cache_v1');
    Prefs.remove('cinema_home_cache_v1');
  },

  async listMemberAccounts(): Promise<MemberAccount[]> {
    if (AgentMode.demo) {
      return [...demoAccounts];
    }
    const token = await auth.currentUser?.getIdToken();
    if (!token) throw new Error('Sign in required');
    let lastError = 'Could not load accounts';
    for (const url of manageAccountsUrls()) {
      try {
        const resp = await fetch(url, {
          headers: { Authorization: `Bearer ${token}` },
          signal: AbortSignal.timeout(10_000),
        });
        if (!resp.ok) {
          const data = (await resp.json().catch(() => ({}))) as { error?: string };
          lastError = data.error || `HTTP ${resp.status}`;
          if (resp.status === 401 || resp.status === 403) throw new Error(lastError);
          continue;
        }
        const data = (await resp.json()) as { accounts?: MemberAccount[] };
        return Array.isArray(data.accounts) ? data.accounts : [];
      } catch (e) {
        if (e instanceof Error && /required|access/i.test(e.message)) throw e;
        Logger.e(`CreatorService: listMemberAccounts ${url} failed`, e);
        lastError = e instanceof Error ? e.message : String(e);
      }
    }
    throw new Error(lastError);
  },

  async updateMemberAccount(
    username: string,
    action: 'approve' | 'reject' | 'revoke' | 'delete',
  ): Promise<void> {
    if (AgentMode.demo) {
      const key = username.toLowerCase();
      if (action === 'delete') {
        demoAccounts = demoAccounts.filter((a) => a.id !== key);
      } else {
        const nextStatus: MemberAccount['status'] =
          action === 'approve' ? 'approved' : action === 'reject' ? 'rejected' : 'pending';
        demoAccounts = demoAccounts.map((a) =>
          a.id === key
            ? {
                ...a,
                status: nextStatus,
                approvedAt: action === 'approve' ? new Date().toISOString() : a.approvedAt,
                approvedBy: action === 'approve' ? 'khentsgdz' : a.approvedBy,
              }
            : a,
        );
      }
      return;
    }
    const token = await auth.currentUser?.getIdToken();
    if (!token) throw new Error('Sign in required');
    let lastError = 'Could not update account';
    for (const url of manageAccountsUrls()) {
      try {
        const resp = await fetch(url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({ action, username }),
          signal: AbortSignal.timeout(10_000),
        });
        if (resp.ok) return;
        const data = (await resp.json().catch(() => ({}))) as { error?: string };
        lastError = data.error || `HTTP ${resp.status}`;
        if (resp.status === 400 || resp.status === 401 || resp.status === 403 || resp.status === 404) {
          throw new Error(lastError);
        }
      } catch (e) {
        if (e instanceof Error && !/fetch|network|abort/i.test(e.message)) throw e;
        Logger.e(`CreatorService: updateMemberAccount ${url} failed`, e);
        lastError = e instanceof Error ? e.message : String(e);
      }
    }
    throw new Error(lastError);
  },
};
