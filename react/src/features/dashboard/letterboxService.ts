// Port of lib/features/dashboard/data/services/letterbox_service.dart + HiddenNote.
import {
  addDoc,
  collection,
  getDocs,
  doc,
  limit as fbLimit,
  onSnapshot,
  orderBy,
  query,
  updateDoc,
  type DocumentData,
  type QuerySnapshot,
  Timestamp,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type HiddenNoteFixture } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { Prefs } from '../../core/system/prefs';
import { just, snapshots, withFirestoreTimeout, withGetTimeout, type Source } from '../../core/utils/liveSource';

export type HiddenNote = HiddenNoteFixture;

export const isNoteUnlocked = (n: HiddenNote) => Date.now() >= n.unlockDate.getTime();

const CACHE_KEY = 'letterbox_notes_cache_v1';

class LetterboxService {
  cachedNotes: HiddenNote[] = [];

  constructor() {
    const raw = Prefs.getString(CACHE_KEY);
    if (raw) {
      try {
        const list = JSON.parse(raw) as Array<{
          id: string;
          title: string;
          content: string;
          unlockDate: string;
          isRead: boolean;
        }>;
        this.cachedNotes = list.map((n) => ({ ...n, unlockDate: new Date(n.unlockDate) }));
      } catch {
        // ignore corrupt cache
      }
    }
  }

  private saveCache(notes: HiddenNote[]) {
    this.cachedNotes = notes;
    try {
      Prefs.set(CACHE_KEY, JSON.stringify(notes.map((n) => ({ ...n, unlockDate: n.unlockDate.toISOString() }))));
    } catch {
      // ignore
    }
  }

  notesPreview(max = 10): Source<HiddenNote[]> {
    if (AgentMode.demo) {
      const notes = AgentFixtures.demoNotes();
      this.cachedNotes = notes;
      return just(notes);
    }
    const q = query(collection(db, 'notes'), orderBy('unlockDate', 'asc'), fbLimit(max));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, HiddenNote[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) => {
          const out: HiddenNote[] = s.docs.map((d) => {
            const data = d.data();
            return {
              id: d.id,
              title: String(data.title ?? ''),
              content: String(data.content ?? ''),
              unlockDate: (data.unlockDate as Timestamp | undefined)?.toDate() ?? new Date(),
              isRead: Boolean(data.isRead),
            };
          });
          if (out.length >= this.cachedNotes.length) this.saveCache(out);
          return out;
        },
      ),
      { label: 'letterbox-notes-preview' },
    );
  }

  notesAll(): Source<HiddenNote[]> {
    return this.notesPreview(200);
  }

  /** Seeds one sample note when the letterbox is empty (cache, disk and server all checked). */
  async ensureSeeded(): Promise<void> {
    if (AgentMode.isActive.value) return;
    try {
      if (this.cachedNotes.length > 0) return;
      await new Promise((r) => setTimeout(r, 4000));
      if (this.cachedNotes.length > 0) return;
      const existing = await withGetTimeout(getDocs(query(collection(db, 'notes'), fbLimit(1))), 'letterbox seed check');
      if (!existing.empty) return;
      await addDoc(collection(db, 'notes'), {
        title: 'My Favorite Number',
        content: '1111',
        unlockDate: Timestamp.fromDate(new Date()),
        isRead: false,
      });
      Logger.i('Letterbox: seeded initial sample note');
    } catch (e) {
      Logger.e('Letterbox ensureSeeded failed (likely permission)', e);
    }
  }

  async markAsRead(noteId: string): Promise<void> {
    if (this.cachedNotes.length > 0) {
      this.saveCache(this.cachedNotes.map((n) => (n.id === noteId ? { ...n, isRead: true } : n)));
    }
    if (AgentMode.isActive.value) return;
    try {
      await updateDoc(doc(db, 'notes', noteId), { isRead: true });
    } catch (e) {
      Logger.e(`Error marking note ${noteId} as read`, e);
    }
  }
}

export const letterboxService = new LetterboxService();
