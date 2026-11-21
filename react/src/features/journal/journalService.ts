// Port of lib/features/journal/data/services/journal_service.dart + models/journal_entry.dart.
import {
  addDoc,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  setDoc,
  startAfter,
  Timestamp,
  updateDoc,
  where,
  type DocumentData,
  type DocumentSnapshot,
  type QueryDocumentSnapshot,
  type QuerySnapshot,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { Prefs } from '../../core/system/prefs';
import { just, snapshots, withFirestoreTimeout, withGetTimeout, type Source } from '../../core/utils/liveSource';

export type JournalCategory = 'daily' | 'gratitude' | 'memory' | 'letter' | 'dream' | 'idea';
export type JournalMood = 'happy' | 'calm' | 'loved' | 'excited' | 'tired' | 'sad' | 'stressed' | 'neutral';

export const JOURNAL_CATEGORIES: { id: JournalCategory; displayName: string; emoji: string }[] = [
  { id: 'daily', displayName: 'Daily', emoji: '📔' },
  { id: 'gratitude', displayName: 'Gratitude', emoji: '🙏' },
  { id: 'memory', displayName: 'Memory', emoji: '📸' },
  { id: 'letter', displayName: 'Letter', emoji: '💌' },
  { id: 'dream', displayName: 'Dream', emoji: '🌙' },
  { id: 'idea', displayName: 'Idea', emoji: '💡' },
];

export const JOURNAL_MOODS: { id: JournalMood; emoji: string }[] = [
  { id: 'happy', emoji: '😊' },
  { id: 'calm', emoji: '😌' },
  { id: 'loved', emoji: '🥰' },
  { id: 'excited', emoji: '🤩' },
  { id: 'tired', emoji: '😴' },
  { id: 'sad', emoji: '😢' },
  { id: 'stressed', emoji: '😣' },
  { id: 'neutral', emoji: '😐' },
];

export const categoryInfo = (c: JournalCategory) => JOURNAL_CATEGORIES.find((x) => x.id === c)!;
export const moodEmoji = (m: JournalMood) => JOURNAL_MOODS.find((x) => x.id === m)!.emoji;

export type JournalEntry = {
  id: string;
  bucketItemId?: string;
  calendarEventId?: string;
  photoIds: string[];
  perspectives: Record<string, string>;
  title: string;
  content: string;
  author: string;
  createdAt: Date;
  updatedAt: Date;
  category: JournalCategory;
  mood: JournalMood | null;
  tags: string[];
  isPinned: boolean;
  isLocked: boolean;
  coverColor?: string;
  wordCount: number;
  isSyncing: boolean;
};

export class JournalEditConflict extends Error {
  constructor() {
    super('JournalEditConflict');
  }
}

export type JournalPage = {
  items: JournalEntry[];
  nextCursor: QueryDocumentSnapshot<DocumentData> | null;
};

export const isLong = (e: JournalEntry) => e.wordCount > 200;
export const preview = (e: JournalEntry) => (e.content.length > 120 ? `${e.content.slice(0, 120)}…` : e.content);

export function countWords(text: string): number {
  const trimmed = text.trim();
  if (trimmed === '') return 0;
  return trimmed.split(/\s+/).filter((w) => w !== '').length;
}

function monthDay(d: Date): string {
  return `${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function parseMood(v: unknown): JournalMood | null {
  return JOURNAL_MOODS.find((m) => m.id === v)?.id ?? null;
}

function parseCategory(v: unknown): JournalCategory {
  return JOURNAL_CATEGORIES.find((c) => c.id === v)?.id ?? 'daily';
}

function parseTs(v: unknown): Date {
  if (v instanceof Timestamp) return v.toDate();
  if (v && typeof (v as Timestamp).toDate === 'function') return (v as Timestamp).toDate();
  if (typeof v === 'number') return new Date(v);
  if (typeof v === 'string') {
    const d = new Date(v);
    if (!Number.isNaN(d.getTime())) return d;
  }
  return new Date();
}

export function entryFromMap(data: DocumentData, id: string, isSyncing = false): JournalEntry {
  const content = typeof data.content === 'string' ? data.content : '';
  const perspectives: Record<string, string> = {};
  if (data.perspectives && typeof data.perspectives === 'object') {
    for (const [k, v] of Object.entries(data.perspectives as Record<string, unknown>)) perspectives[k] = String(v);
  }
  return {
    id,
    bucketItemId: typeof data.bucketItemId === 'string' ? data.bucketItemId : undefined,
    calendarEventId: typeof data.calendarEventId === 'string' ? data.calendarEventId : undefined,
    photoIds: Array.isArray(data.photoIds) ? data.photoIds.filter((p): p is string => typeof p === 'string').slice(0, 20) : [],
    perspectives,
    title: typeof data.title === 'string' ? data.title : '',
    content,
    author: typeof data.author === 'string' ? data.author : '',
    createdAt: parseTs(data.createdAt),
    updatedAt: parseTs(data.updatedAt ?? data.createdAt),
    category: parseCategory(data.category),
    mood: parseMood(data.mood),
    tags: Array.isArray(data.tags) ? data.tags.map(String) : [],
    isPinned: data.isPinned === true,
    isLocked: data.isLocked === true,
    coverColor: typeof data.coverColor === 'string' ? data.coverColor : undefined,
    wordCount: typeof data.wordCount === 'number' ? data.wordCount : countWords(content),
    isSyncing,
  };
}

const fromDoc = (d: DocumentSnapshot<DocumentData>) => entryFromMap(d.data() ?? {}, d.id);

export function toFirestore(e: JournalEntry): DocumentData {
  return {
    ...(e.bucketItemId != null ? { bucketItemId: e.bucketItemId } : {}),
    ...(e.calendarEventId != null ? { calendarEventId: e.calendarEventId } : {}),
    photoIds: e.photoIds,
    perspectives: e.perspectives,
    title: e.title,
    content: e.content,
    author: e.author.toLowerCase(),
    createdAt: Timestamp.fromDate(e.createdAt),
    updatedAt: Timestamp.fromDate(e.updatedAt),
    category: e.category,
    ...(e.mood != null ? { mood: e.mood } : {}),
    tags: e.tags,
    isPinned: e.isPinned,
    isLocked: e.isLocked,
    ...(e.coverColor != null ? { coverColor: e.coverColor } : {}),
    wordCount: e.wordCount,
    monthDay: monthDay(e.createdAt),
    searchKey: `${e.title.toLowerCase()} ${e.content.toLowerCase().slice(0, 500)}`.toLowerCase(),
  };
}

function toCacheJson(e: JournalEntry) {
  return { ...toFirestore(e), createdAt: e.createdAt.toISOString(), updatedAt: e.updatedAt.toISOString(), id: e.id };
}

export function newEntry(
  fields: Partial<JournalEntry> & Pick<JournalEntry, 'id' | 'title' | 'content' | 'author' | 'createdAt' | 'updatedAt'>,
): JournalEntry {
  return {
    photoIds: [],
    perspectives: {},
    category: 'daily',
    mood: null,
    tags: [],
    isPinned: false,
    isLocked: false,
    wordCount: 0,
    isSyncing: false,
    ...fields,
  };
}

const demoEntries = (() => {
  let cached: JournalEntry[] | null = null;
  return () =>
    (cached ??= AgentFixtures.demoJournalEntries().map((f) =>
      newEntry({
        ...f,
        category: parseCategory(f.category),
        mood: parseMood(f.mood),
      }),
    ));
})();

const isDemo = () => AgentMode.demo;
const COLLECTION = 'journal_entries';
const PREVIEW_CACHE_KEY = 'journal_preview_cache_v1';
const sameStrings = (a: string[], b: string[]) => a.length === b.length && a.every((v, i) => v === b[i]);

class JournalService {
  private demoMemories = new Map<string, JournalEntry>();
  private demoListeners = new Set<() => void>();
  private cachedPreviewList: JournalEntry[] = [];

  constructor() {
    this.loadPreviewCache();
    if (typeof window !== 'undefined') {
      window.addEventListener('everglow:logout', () => {
        this.cachedPreviewList = [];
      });
    }
  }

  get cachedPreview() {
    return this.cachedPreviewList;
  }

  loadPreviewCache(): JournalEntry[] {
    if (this.cachedPreviewList.length > 0) return this.cachedPreviewList;
    try {
      const raw = Prefs.getString(PREVIEW_CACHE_KEY);
      if (!raw) return this.cachedPreviewList;
      const decoded: unknown = JSON.parse(raw);
      if (!Array.isArray(decoded)) return this.cachedPreviewList;
      const entries: JournalEntry[] = [];
      for (const item of decoded) {
        if (!item || typeof item !== 'object') continue;
        try {
          entries.push(entryFromMap(item as DocumentData, String((item as { id?: unknown }).id ?? '')));
        } catch (e) {
          Logger.w(`Journal: skipping malformed cached entry: ${e}`);
        }
      }
      if (entries.length > 0 && this.cachedPreviewList.length === 0) this.cachedPreviewList = entries;
    } catch (e) {
      Logger.w(`Journal: failed to load preview cache: ${e}`);
    }
    return this.cachedPreviewList;
  }

  private savePreviewCache(entries: JournalEntry[]) {
    try {
      Prefs.set(PREVIEW_CACHE_KEY, JSON.stringify(entries.map(toCacheJson)));
    } catch (e) {
      Logger.w(`Journal: failed to save preview cache: ${e}`);
    }
  }

  private emitDemo() {
    for (const l of this.demoListeners) l();
  }

  private demoEntry(id: string): JournalEntry {
    const entry = this.demoMemories.get(id) ?? demoEntries().find((e) => e.id === id);
    if (!entry) throw new Error(`No demo entry ${id}`);
    return entry;
  }

  watchEntry(initial: JournalEntry): Source<JournalEntry | null> {
    if (AgentMode.isActive.value) {
      return (l) => {
        let live = true;
        const push = () => live && l.data(this.demoMemories.get(initial.id) ?? initial);
        queueMicrotask(push);
        this.demoListeners.add(push);
        return () => {
          live = false;
          this.demoListeners.delete(push);
        };
      };
    }
    return snapshots<DocumentSnapshot<DocumentData>, JournalEntry | null>(
      (next, error) => onSnapshot(doc(db, COLLECTION, initial.id), next, error),
      (d) => (d.exists() ? fromDoc(d) : null),
    );
  }

  async memoryForSource(opts: {
    title: string;
    author: string;
    date: Date;
    bucketItemId?: string;
    calendarEventId?: string;
    photoId?: string;
  }): Promise<JournalEntry> {
    const { title, author, date, bucketItemId, calendarEventId, photoId } = opts;
    const source =
      bucketItemId != null ? `bucket_${bucketItemId}` : calendarEventId != null ? `event_${calendarEventId}` : `photo_${photoId}`;
    const id = `memory_${source}`;
    if (photoId != null && !AgentMode.isActive.value) {
      const linked = await withGetTimeout(
        getDocs(query(collection(db, COLLECTION), where('photoIds', 'array-contains', photoId), limit(1))),
        'photo memory lookup',
      );
      if (!linked.empty) return fromDoc(linked.docs[0]);
    }
    const now = new Date();
    const entry = newEntry({
      id,
      title,
      content: '',
      author,
      createdAt: date > now ? now : date,
      updatedAt: now,
      category: 'memory',
      bucketItemId,
      calendarEventId,
      photoIds: photoId == null ? [] : [photoId],
    });
    if (AgentMode.isActive.value) {
      if (!this.demoMemories.has(id)) this.demoMemories.set(id, entry);
      return this.demoMemories.get(id)!;
    }
    try {
      const ref = doc(db, COLLECTION, id);
      return await runTransaction(db, async (tx) => {
        const current = await tx.get(ref);
        if (current.exists()) {
          const saved = fromDoc(current);
          if (calendarEventId != null && saved.calendarEventId == null) {
            tx.update(ref, { calendarEventId });
            return entryFromMap({ ...toFirestore(saved), calendarEventId }, id);
          }
          return saved;
        }
        tx.set(ref, toFirestore(entry));
        return entry;
      });
    } catch (e) {
      Logger.e('Could not open shared memory', e);
      throw e;
    }
  }

  async savePerspective(id: string, username: string, words: string): Promise<void> {
    if (!['khentsgdz', 'clairjassen'].includes(username) || words.length > 1000) {
      throw new Error('Invalid memory contribution');
    }
    if (AgentMode.isActive.value) {
      const entry = this.demoEntry(id);
      this.demoMemories.set(id, { ...entry, perspectives: { ...entry.perspectives, [username]: words.trim() } });
      this.emitDemo();
      return;
    }
    try {
      await updateDoc(doc(db, COLLECTION, id), { [`perspectives.${username}`]: words.trim(), updatedAt: Timestamp.now() });
    } catch (e) {
      Logger.e('Could not save memory contribution', e);
      throw e;
    }
  }

  async setMemoryPhotos(id: string, photoIds: string[]): Promise<void> {
    if (photoIds.length > 20) throw new Error('Up to 20 photos per memory');
    const unique = [...new Set(photoIds)];
    if (AgentMode.isActive.value) {
      this.demoMemories.set(id, { ...this.demoEntry(id), photoIds: unique });
      this.emitDemo();
      return;
    }
    try {
      await updateDoc(doc(db, COLLECTION, id), { photoIds: unique, updatedAt: Timestamp.now() });
    } catch (e) {
      Logger.e('Could not link memory photos', e);
      throw e;
    }
  }

  async addMemoryPhoto(id: string, photoId: string): Promise<void> {
    if (AgentMode.isActive.value) {
      return this.setMemoryPhotos(id, [...new Set([...this.demoEntry(id).photoIds, photoId])]);
    }
    try {
      const ref = doc(db, COLLECTION, id);
      await runTransaction(db, async (tx) => {
        const current = await tx.get(ref);
        if (!current.exists()) throw new Error('Memory no longer exists');
        const photos = [...new Set([...fromDoc(current).photoIds, photoId])];
        if (photos.length > 20) throw new Error('Memory already has 20 photos');
        tx.update(ref, { photoIds: photos, updatedAt: Timestamp.now() });
      });
    } catch (e) {
      Logger.e('Could not add memory photo', e);
      throw e;
    }
  }

  watchAll(): Source<JournalEntry[]> {
    if (isDemo()) return just(demoEntries());
    const subscribe = () =>
      snapshots<QuerySnapshot<DocumentData>, JournalEntry[]>(
        (next, error) =>
          onSnapshot(
            query(collection(db, COLLECTION), orderBy('createdAt', 'desc'), limit(100)),
            { includeMetadataChanges: true },
            next,
            error,
          ),
        (snap) => {
          const out: JournalEntry[] = [];
          for (const d of snap.docs) {
            try {
              out.push(entryFromMap(d.data(), d.id, d.metadata.hasPendingWrites));
            } catch (e) {
              Logger.e(`Journal: skipping malformed entry ${d.id}`, e);
            }
          }
          return out;
        },
      );
    return withFirestoreTimeout(subscribe(), { resubscribe: subscribe, label: 'journal-all', maxAttempts: 3 });
  }

  async fetchOlderThan(date: Date, max = 20): Promise<JournalPage> {
    if (isDemo()) return { items: [], nextCursor: null };
    const snap = await withGetTimeout(
      getDocs(query(collection(db, COLLECTION), orderBy('createdAt', 'desc'), startAfter(Timestamp.fromDate(date)), limit(max))),
      'journal older entries',
    );
    return { items: snap.docs.map(fromDoc), nextCursor: snap.docs.length < max ? null : snap.docs[snap.docs.length - 1] };
  }

  async fetchPage(cursor: QueryDocumentSnapshot<DocumentData> | null, max = 20): Promise<JournalPage> {
    if (isDemo()) return { items: demoEntries().slice(0, max), nextCursor: null };
    const base = query(collection(db, COLLECTION), orderBy('createdAt', 'desc'));
    const snap = await withGetTimeout(
      getDocs(cursor ? query(base, startAfter(cursor), limit(max)) : query(base, limit(max))),
      'firestore page',
    );
    return { items: snap.docs.map(fromDoc), nextCursor: snap.docs.length < max ? null : snap.docs[snap.docs.length - 1] };
  }

  watchPreview(max = 12): Source<JournalEntry[]> {
    if (isDemo()) return just(demoEntries().slice(0, max));
    const subscribe = () =>
      snapshots<QuerySnapshot<DocumentData>, JournalEntry[]>(
        (next, error) => onSnapshot(query(collection(db, COLLECTION), orderBy('createdAt', 'desc'), limit(max)), next, error),
        (snap) => {
          const entries = snap.docs.map(fromDoc);
          if (entries.length > 0) {
            this.cachedPreviewList = entries;
            this.savePreviewCache(entries);
          }
          return entries;
        },
      );
    const cachedFirst: Source<JournalEntry[]> = (l) => {
      let live = true;
      const cached = this.cachedPreviewList;
      if (cached.length > 0) queueMicrotask(() => live && l.data(cached));
      const unsub = subscribe()(l);
      return () => {
        live = false;
        unsub();
      };
    };
    return withFirestoreTimeout(cachedFirst, { resubscribe: subscribe, label: 'journal-preview', maxAttempts: 3 });
  }

  private matches(q: string) {
    return (e: JournalEntry) =>
      e.title.toLowerCase().includes(q) ||
      e.content.toLowerCase().includes(q) ||
      e.tags.some((t) => t.toLowerCase().includes(q)) ||
      e.category.includes(q);
  }

  async search(term: string): Promise<JournalEntry[]> {
    const q = term.toLowerCase().trim();
    if (isDemo()) return demoEntries().filter(this.matches(q));
    if (q === '') return [];
    const out: JournalEntry[] = [];
    let cursor: QueryDocumentSnapshot<DocumentData> | null = null;
    do {
      const page: JournalPage = await this.fetchPage(cursor, 80);
      out.push(...page.items.filter(this.matches(q)));
      cursor = page.nextCursor;
    } while (cursor);
    return out;
  }

  async getOnThisDay(): Promise<JournalEntry[]> {
    if (isDemo()) return [];
    const now = new Date();
    try {
      const snap = await withGetTimeout(
        getDocs(query(collection(db, COLLECTION), where('monthDay', '==', monthDay(now)), limit(50))),
        'journal on-this-day',
      );
      const entries = snap.docs.map(fromDoc).filter((e) => e.createdAt.getFullYear() !== now.getFullYear());
      if (entries.length > 0) return entries;
      const fallback = await withGetTimeout(
        getDocs(query(collection(db, COLLECTION), orderBy('createdAt', 'desc'), limit(200))),
        'journal on-this-day fallback',
      );
      return fallback.docs
        .map(fromDoc)
        .filter(
          (e) =>
            e.createdAt.getMonth() === now.getMonth() &&
            e.createdAt.getDate() === now.getDate() &&
            e.createdAt.getFullYear() !== now.getFullYear(),
        );
    } catch (e) {
      Logger.e('journal onThisDay error', e);
      return [];
    }
  }

  newEntryId(): string {
    return isDemo() ? `demo-${Date.now()}000` : doc(collection(db, COLLECTION)).id;
  }

  async add(entry: JournalEntry, id?: string): Promise<void> {
    if (isDemo()) {
      Logger.i(`Agent session simulated journal add: ${entry.title}`);
      return;
    }
    try {
      if (id == null) await addDoc(collection(db, COLLECTION), toFirestore(entry));
      else await setDoc(doc(db, COLLECTION, id), toFirestore(entry));
      Logger.i(`Journal added: ${entry.title}`);
    } catch (e) {
      Logger.e('Error adding journal', e);
      throw e;
    }
  }

  async get(id: string): Promise<JournalEntry> {
    const snapshot = await getDoc(doc(db, COLLECTION, id));
    const data = snapshot.data();
    if (!snapshot.exists() || data == null) throw new Error(`Journal entry ${id} no longer exists`);
    return entryFromMap(data, id);
  }

  async update(entry: JournalEntry, original: JournalEntry): Promise<void> {
    if (isDemo()) {
      Logger.i(`Agent session simulated journal update: ${entry.id}`);
      return;
    }
    const changes: DocumentData = {};
    if (entry.title !== original.title) changes.title = entry.title;
    if (entry.content !== original.content) changes.content = entry.content;
    if (entry.createdAt.getTime() !== original.createdAt.getTime()) {
      changes.createdAt = Timestamp.fromDate(entry.createdAt);
      changes.monthDay = monthDay(entry.createdAt);
    }
    if (entry.category !== original.category) changes.category = entry.category;
    if (entry.mood !== original.mood) changes.mood = entry.mood ?? deleteField();
    if (!sameStrings(entry.tags, original.tags)) changes.tags = entry.tags;
    if (entry.isPinned !== original.isPinned) changes.isPinned = entry.isPinned;
    if (entry.isLocked !== original.isLocked) changes.isLocked = entry.isLocked;
    if (entry.coverColor !== original.coverColor) changes.coverColor = entry.coverColor ?? deleteField();
    if (entry.wordCount !== original.wordCount || entry.content !== original.content) changes.wordCount = entry.wordCount;
    if (Object.keys(changes).length === 0) return;

    try {
      const ref = doc(db, COLLECTION, entry.id);
      await runTransaction(db, async (tx) => {
        const snapshot = await tx.get(ref);
        const data = snapshot.data();
        if (!snapshot.exists() || data == null) throw new Error(`Journal entry ${entry.id} no longer exists`);
        const currentTitle = typeof data.title === 'string' ? data.title : '';
        const currentContent = typeof data.content === 'string' ? data.content : '';
        if ('title' in changes && currentTitle !== original.title) throw new JournalEditConflict();
        if ('content' in changes && currentContent !== original.content) throw new JournalEditConflict();
        const patch: DocumentData = { ...changes, updatedAt: Timestamp.fromDate(entry.updatedAt) };
        if ('title' in changes || 'content' in changes) {
          const title: string = changes.title ?? currentTitle;
          const content: string = changes.content ?? currentContent;
          patch.searchKey = `${title} ${content.slice(0, 500)}`.toLowerCase();
        }
        tx.update(ref, patch);
      });
      Logger.i(`Journal updated: ${entry.id}`);
    } catch (e) {
      Logger.e('Error updating journal', e);
      throw e;
    }
  }

  async delete(id: string): Promise<void> {
    if (isDemo()) {
      Logger.i(`Agent session simulated journal delete: ${id}`);
      return;
    }
    try {
      await deleteDoc(doc(db, COLLECTION, id));
      Logger.i(`Journal deleted: ${id}`);
    } catch (e) {
      Logger.e('Error deleting journal', e);
      throw e;
    }
  }

  async togglePin(id: string, pinned: boolean): Promise<void> {
    if (isDemo()) {
      Logger.i(`Agent session simulated toggle pin: ${id} -> ${pinned}`);
      return;
    }
    try {
      await updateDoc(doc(db, COLLECTION, id), { isPinned: pinned, updatedAt: Timestamp.now() });
    } catch (e) {
      Logger.e('Error toggling pin', e);
      throw e;
    }
  }

  async toggleLock(id: string, locked: boolean): Promise<void> {
    if (isDemo()) {
      Logger.i(`Agent session simulated toggle lock: ${id} -> ${locked}`);
      return;
    }
    try {
      await updateDoc(doc(db, COLLECTION, id), { isLocked: locked, updatedAt: Timestamp.now() });
      Logger.i(`Journal lock toggled: ${id} -> ${locked}`);
    } catch (e) {
      Logger.e('Error toggling lock', e);
      throw e;
    }
  }
}

export const journalService = new JournalService();
