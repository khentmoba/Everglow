// Port of lib/features/starlight_jar/data/services/starlight_service.dart.
import {
  addDoc,
  collection,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  type DocumentData,
  type QuerySnapshot,
  type Timestamp,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type StarNoteFixture } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { Changes, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export type StarNote = StarNoteFixture;

export const STAR_CATEGORIES = ['gratitude', 'memory', 'love', 'dream', 'milestone'] as const;

export const STAR_CATEGORY_INFO: Record<string, [string, string]> = {
  gratitude: ['✨', 'Gratitude'],
  memory: ['📸', 'Memory'],
  love: ['💖', 'Love Note'],
  dream: ['🌙', 'Dream'],
  milestone: ['🌸', 'Milestone'],
};

class StarlightService {
  private demoNotes: StarNote[] | null = null;
  private demoChanges = new Changes(() => this.demoNotes ?? AgentFixtures.demoStars());

  getStarNotes(): Source<StarNote[]> {
    if (AgentMode.demo) return this.demoChanges.source;
    const q = query(collection(db, 'starlight_jar'), orderBy('timestamp', 'desc'), limit(100));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, StarNote[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) =>
          s.docs.map((d) => {
            const data = d.data();
            return {
              id: d.id,
              content: String(data.content ?? ''),
              author: String(data.author ?? ''),
              timestamp: (data.timestamp as Timestamp | undefined)?.toDate() ?? new Date(),
              category: String(data.category ?? 'gratitude'),
              tags: Array.isArray(data.tags) ? data.tags.map(String) : [],
            };
          }),
      ),
      { label: 'starlight-jar' },
    );
  }

  async addStarNote(o: { content: string; author: string; category: string }): Promise<void> {
    if (AgentMode.demo) {
      const next: StarNote = {
        id: `demo_star_${Date.now()}`,
        content: o.content,
        author: o.author,
        timestamp: new Date(),
        category: o.category,
        tags: [],
      };
      this.demoNotes = [next, ...(this.demoNotes ?? AgentFixtures.demoStars())];
      this.demoChanges.emit();
      return;
    }
    await addDoc(collection(db, 'starlight_jar'), {
      content: o.content,
      author: o.author,
      category: o.category,
      tags: [],
      timestamp: serverTimestamp(),
    });
  }
}

export const starlightService = new StarlightService();
