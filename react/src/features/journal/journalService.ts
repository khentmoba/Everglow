// Port of lib/features/journal/data/services/journal_service.dart + models/journal_entry.dart.
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  Timestamp,
  updateDoc,
  type DocumentData,
  type QueryDocumentSnapshot,
  type QuerySnapshot,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type JournalEntryFixture } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { AppColors } from '../../core/theme/colors';
import { Changes, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export type JournalCategory = 'daily' | 'gratitude' | 'memory' | 'letter' | 'dream' | 'idea';
export type JournalMood = 'happy' | 'calm' | 'loved' | 'excited' | 'tired' | 'sad' | 'stressed' | 'neutral';

export type JournalEntry = JournalEntryFixture & {
  isLocked?: boolean;
  perspectives?: Record<string, string>;
  photoIds?: string[];
  bucketItemId?: string;
  calendarEventId?: string;
  isSyncing?: boolean;
};

export const JOURNAL_CATEGORIES: { id: JournalCategory; label: string; emoji: string; color: string }[] = [
  { id: 'daily', label: 'Daily', emoji: '📔', color: AppColors.softLavender },
  { id: 'gratitude', label: 'Gratitude', emoji: '🙏', color: AppColors.blushGold },
  { id: 'memory', label: 'Memory', emoji: '📸', color: AppColors.auroraTeal },
  { id: 'letter', label: 'Letter', emoji: '💌', color: AppColors.deepRose },
  { id: 'dream', label: 'Dream', emoji: '🌙', color: AppColors.auroraLilac },
  { id: 'idea', label: 'Idea', emoji: '💡', color: AppColors.warmAmber },
];

export const JOURNAL_MOODS: { id: JournalMood; emoji: string; label: string }[] = [
  { id: 'happy', emoji: '😊', label: 'Happy' },
  { id: 'calm', emoji: '😌', label: 'Calm' },
  { id: 'loved', emoji: '🥰', label: 'Loved' },
  { id: 'excited', emoji: '🤩', label: 'Excited' },
  { id: 'tired', emoji: '😴', label: 'Tired' },
  { id: 'sad', emoji: '😢', label: 'Sad' },
  { id: 'stressed', emoji: '😣', label: 'Stressed' },
  { id: 'neutral', emoji: '😐', label: 'Neutral' },
];

export function journalCategoryMeta(cat: string) {
  return JOURNAL_CATEGORIES.find((c) => c.id === cat) ?? JOURNAL_CATEGORIES[0];
}

export function journalMoodEmoji(mood?: string): string | null {
  if (!mood) return null;
  return JOURNAL_MOODS.find((m) => m.id === mood)?.emoji ?? null;
}

export function journalAuthorHue(author: string): string {
  const lower = author.toLowerCase();
  if (lower === 'khentsgdz') return AppColors.auroraTeal;
  if (lower === 'clairjassen') return AppColors.auroraRose;
  return AppColors.softLavender;
}

export function journalAuthorName(author: string): string {
  const lower = author.toLowerCase();
  if (lower === 'khentsgdz') return 'Khent';
  if (lower === 'clairjassen') return 'Clair';
  return author ? author[0].toUpperCase() + author.slice(1) : 'Us';
}

export function journalDayKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function monthDay(d: Date): string {
  return `${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function parseTs(v: unknown): Date {
  if (v && typeof (v as Timestamp).toDate === 'function') return (v as Timestamp).toDate();
  if (typeof v === 'number') return new Date(v);
  if (typeof v === 'string') {
    const d = new Date(v);
    if (!Number.isNaN(d.getTime())) return d;
  }
  return new Date();
}

function mapDoc(d: QueryDocumentSnapshot<DocumentData>): JournalEntry {
  const data = d.data();
  const perspectives: Record<string, string> = {};
  if (data.perspectives && typeof data.perspectives === 'object') {
    for (const [k, v] of Object.entries(data.perspectives as Record<string, unknown>)) {
      if (typeof v === 'string') perspectives[k] = v;
    }
  }
  return {
    id: d.id,
    title: String(data.title ?? ''),
    content: String(data.content ?? ''),
    author: String(data.author ?? ''),
    createdAt: parseTs(data.createdAt),
    updatedAt: parseTs(data.updatedAt),
    category: String(data.category ?? 'daily'),
    mood: typeof data.mood === 'string' ? data.mood : '',
    tags: Array.isArray(data.tags) ? data.tags.map(String) : [],
    isPinned: Boolean(data.isPinned),
    isLocked: Boolean(data.isLocked),
    wordCount: Number(data.wordCount ?? 0),
    perspectives,
    photoIds: Array.isArray(data.photoIds) ? data.photoIds.map(String) : [],
    bucketItemId: typeof data.bucketItemId === 'string' ? data.bucketItemId : undefined,
    calendarEventId: typeof data.calendarEventId === 'string' ? data.calendarEventId : undefined,
    isSyncing: d.metadata?.hasPendingWrites ?? false,
  };
}

class JournalService {
  private demoEntries: JournalEntry[] | null = null;
  private demoChanges = new Changes(() => [...this.ensureDemo()]);

  private ensureDemo(): JournalEntry[] {
    if (!this.demoEntries) {
      this.demoEntries = AgentFixtures.demoJournalEntries().map((e) => ({
        ...e,
        isLocked: false,
        perspectives: {},
        photoIds: [],
      }));
    }
    return this.demoEntries;
  }

  watchAll(max = 100): Source<JournalEntry[]> {
    if (AgentMode.demo) {
      this.ensureDemo();
      return this.demoChanges.source;
    }
    const q = query(collection(db, 'journal_entries'), orderBy('createdAt', 'desc'), limit(max));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, JournalEntry[]>(
        (next, error) => onSnapshot(q, { includeMetadataChanges: true }, next, error),
        (s) => s.docs.map(mapDoc),
      ),
      { label: 'journal-all' },
    );
  }

  watchPreview(max = 12): Source<JournalEntry[]> {
    return this.watchAll(max);
  }

  async search(term: string): Promise<JournalEntry[]> {
    const q = term.trim().toLowerCase();
    if (!q) return [];
    const matches = (e: JournalEntry) =>
      e.title.toLowerCase().includes(q) ||
      e.content.toLowerCase().includes(q) ||
      e.tags.some((t) => t.toLowerCase().includes(q));
    if (AgentMode.demo) return this.ensureDemo().filter(matches);
    const snap = await getDocs(query(collection(db, 'journal_entries'), orderBy('createdAt', 'desc'), limit(150)));
    return snap.docs.map(mapDoc).filter(matches);
  }

  async addEntry(input: {
    title: string;
    content: string;
    author: string;
    category: JournalCategory;
    mood?: JournalMood;
    tags: string[];
    isPinned: boolean;
    isLocked: boolean;
    createdAt?: Date;
  }): Promise<void> {
    const now = input.createdAt ?? new Date();
    const words = input.content.trim() ? input.content.trim().split(/\s+/).length : 0;
    if (AgentMode.demo) {
      const next: JournalEntry = {
        id: `demo_journal_${Date.now()}`,
        title: input.title,
        content: input.content,
        author: input.author,
        createdAt: now,
        updatedAt: new Date(),
        category: input.category,
        mood: input.mood ?? '',
        tags: input.tags,
        isPinned: input.isPinned,
        isLocked: input.isLocked,
        wordCount: words,
        perspectives: {},
      };
      this.demoEntries = [next, ...this.ensureDemo()];
      this.demoChanges.emit();
      return;
    }
    const searchKey = `${input.title} ${input.content.slice(0, 500)}`.toLowerCase();
    await addDoc(collection(db, 'journal_entries'), {
      title: input.title,
      content: input.content,
      author: input.author,
      createdAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.now(),
      monthDay: monthDay(now),
      category: input.category,
      ...(input.mood ? { mood: input.mood } : {}),
      tags: input.tags,
      isPinned: input.isPinned,
      isLocked: input.isLocked,
      wordCount: words,
      searchKey,
    });
  }

  async updateEntry(
    id: string,
    patch: {
      title: string;
      content: string;
      category: JournalCategory;
      mood?: JournalMood;
      tags: string[];
      isPinned: boolean;
      isLocked: boolean;
    },
  ): Promise<void> {
    const words = patch.content.trim() ? patch.content.trim().split(/\s+/).length : 0;
    if (AgentMode.demo) {
      this.demoEntries = this.ensureDemo().map((e) =>
        e.id === id ? { ...e, ...patch, mood: patch.mood ?? '', wordCount: words, updatedAt: new Date() } : e,
      );
      this.demoChanges.emit();
      return;
    }
    await updateDoc(doc(db, 'journal_entries', id), {
      title: patch.title,
      content: patch.content,
      category: patch.category,
      ...(patch.mood ? { mood: patch.mood } : {}),
      tags: patch.tags,
      isPinned: patch.isPinned,
      isLocked: patch.isLocked,
      wordCount: words,
      updatedAt: Timestamp.now(),
      searchKey: `${patch.title} ${patch.content.slice(0, 500)}`.toLowerCase(),
    });
  }

  async deleteEntry(id: string): Promise<void> {
    if (AgentMode.demo) {
      this.demoEntries = this.ensureDemo().filter((e) => e.id !== id);
      this.demoChanges.emit();
      return;
    }
    await deleteDoc(doc(db, 'journal_entries', id));
  }

  async togglePin(id: string, isPinned: boolean): Promise<void> {
    if (AgentMode.demo) {
      this.demoEntries = this.ensureDemo().map((e) => (e.id === id ? { ...e, isPinned } : e));
      this.demoChanges.emit();
      return;
    }
    await updateDoc(doc(db, 'journal_entries', id), { isPinned, updatedAt: Timestamp.now() });
  }

  async toggleLock(id: string, isLocked: boolean): Promise<void> {
    if (AgentMode.demo) {
      this.demoEntries = this.ensureDemo().map((e) => (e.id === id ? { ...e, isLocked } : e));
      this.demoChanges.emit();
      return;
    }
    await updateDoc(doc(db, 'journal_entries', id), { isLocked, updatedAt: Timestamp.now() });
  }

  async savePerspective(id: string, username: string, words: string): Promise<void> {
    if (AgentMode.demo) {
      this.demoEntries = this.ensureDemo().map((e) =>
        e.id === id ? { ...e, perspectives: { ...(e.perspectives ?? {}), [username]: words.trim() } } : e,
      );
      this.demoChanges.emit();
      return;
    }
    await updateDoc(doc(db, 'journal_entries', id), {
      [`perspectives.${username}`]: words.trim(),
      updatedAt: Timestamp.now(),
    });
  }
}

export const journalService = new JournalService();
