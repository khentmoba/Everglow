// Port of lib/features/starlight_jar/data/services/starlight_service.dart and
// domain/models/star_note.dart.
import {
  addDoc,
  collection,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  where,
  type DocumentData,
  type QueryDocumentSnapshot,
  type QuerySnapshot,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type StarNoteFixture } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { just, snapshots, withFirestoreTimeout, withGetTimeout, type Source } from '../../core/utils/liveSource';

export type StarNote = StarNoteFixture;

export const STAR_CATEGORIES = ['gratitude', 'memory', 'love', 'dream', 'milestone', 'surprise'] as const;

export const STAR_CATEGORY_INFO: Record<string, [emoji: string, label: string]> = {
  gratitude: ['🙏', 'Gratitude'],
  memory: ['📸', 'Memory'],
  love: ['💕', 'Love'],
  dream: ['🌙', 'Dream'],
  milestone: ['🎉', 'Milestone'],
  surprise: ['✨', 'Surprise'],
};

const COLLECTION = 'starlight_jar';

const monthDay = (d: Date) => `${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

function parseTimestamp(value: unknown): Date {
  if (value && typeof (value as { toDate?: unknown }).toDate === 'function') return (value as { toDate: () => Date }).toDate();
  if (typeof value === 'number') return new Date(value);
  if (typeof value === 'string') {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? new Date() : d;
  }
  return new Date();
}

function fromDoc(d: QueryDocumentSnapshot<DocumentData>): StarNote {
  const data = d.data();
  return {
    id: d.id,
    content: String(data.content ?? ''),
    author: String(data.author ?? ''),
    timestamp: parseTimestamp(data.timestamp),
    category: String(data.category ?? 'gratitude'),
    tags: Array.isArray(data.tags) ? data.tags.map(String) : [],
  };
}

const demo = () => AgentMode.demo;

export const starlightService = {
  getStarNotes(): Source<StarNote[]> {
    if (demo()) return just(AgentFixtures.demoStars());
    const q = query(collection(db, COLLECTION), orderBy('timestamp', 'desc'), limit(40));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, StarNote[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) => s.docs.map(fromDoc),
      ),
      { label: 'starlight-jar' },
    );
  },

  /** Flutter ignores writes in agent mode; the jar keeps the dropped star on screen itself. */
  async addStar(content: string, author: string, category = 'gratitude', tags: string[] = []): Promise<void> {
    if (content.trim() === '') return;
    if (AgentMode.isActive.value) return;
    try {
      await addDoc(collection(db, COLLECTION), {
        content: content.trim(),
        author: author.toLowerCase(),
        timestamp: serverTimestamp(),
        category,
        tags,
        monthDay: monthDay(new Date()),
      });
      Logger.i('Dropped star into jar successfully');
    } catch (e) {
      Logger.e('Error adding star', e);
    }
  },

  async getRandomStarNote(): Promise<StarNote | null> {
    if (demo()) return AgentFixtures.demoStars()[0];
    try {
      const snapshot = await withGetTimeout(
        getDocs(query(collection(db, COLLECTION), orderBy('timestamp', 'desc'), limit(20))),
        'starlight random star',
      );
      if (snapshot.empty) return null;
      return fromDoc(snapshot.docs[Math.floor(Math.random() * snapshot.docs.length)]);
    } catch (e) {
      Logger.e('Error getting random star', e);
      return null;
    }
  },

  async getStarsFromThisDay(): Promise<StarNote[]> {
    if (demo()) return AgentFixtures.demoStars();
    const now = new Date();
    try {
      let snapshot = await withGetTimeout(
        getDocs(query(collection(db, COLLECTION), where('monthDay', '==', monthDay(now)), limit(100))),
        'starlight on-this-day',
      );
      if (snapshot.empty) {
        snapshot = await withGetTimeout(
          getDocs(query(collection(db, COLLECTION), orderBy('timestamp', 'desc'), limit(200))),
          'starlight on-this-day fallback',
        );
      }
      return snapshot.docs
        .map(fromDoc)
        .filter(
          (n) =>
            n.timestamp.getMonth() === now.getMonth() &&
            n.timestamp.getDate() === now.getDate() &&
            n.timestamp.getFullYear() !== now.getFullYear(),
        );
    } catch (e) {
      Logger.e('Error getting on-this-day stars', e);
      return [];
    }
  },
};
