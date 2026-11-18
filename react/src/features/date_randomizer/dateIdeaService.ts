// Port of lib/features/date_randomizer/data/services/date_idea_service.dart
// and ai_date_idea_generator.dart.
import { collection, doc, getDocs, limit, query, serverTimestamp, writeBatch } from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type DateIdeaFixture } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { withGetTimeout } from '../../core/utils/liveSource';
import { quickAsk } from '../ai/aiService';

export type DateIdea = DateIdeaFixture;

class DateIdeaService {
  private cachedIdeas: DateIdea[] = [];
  private inflight: Promise<void> | null = null;

  async initialize(max = 50): Promise<void> {
    if (AgentMode.demo) {
      this.cachedIdeas = AgentFixtures.demoDateIdeas();
      return;
    }
    if (this.cachedIdeas.length > 0) return;
    if (this.inflight) return this.inflight;
    this.inflight = this.loadIdeas(max).finally(() => {
      this.inflight = null;
    });
    return this.inflight;
  }

  private async loadIdeas(max: number): Promise<void> {
    try {
      const q = query(collection(db, 'date_ideas'), limit(max));
      let snap = await withGetTimeout(getDocs(q), 'date ideas load');
      if (snap.empty) {
        await this.seedIdeas();
        snap = await withGetTimeout(getDocs(q), 'date ideas reload after seed');
      }
      this.cachedIdeas = snap.docs
        .map((d) => ({ id: d.id, title: String(d.data().title ?? '').trim() }))
        .filter((i) => i.title !== '');
    } catch (e) {
      Logger.e('Error loading date ideas', e);
    }
  }

  private async seedIdeas(): Promise<void> {
    try {
      const resp = await fetch('/data/date_ideas_seed.json');
      if (!resp.ok) return;
      const data = (await resp.json()) as Array<{ title?: unknown }>;
      if (!Array.isArray(data) || data.length === 0) return;
      const col = collection(db, 'date_ideas');
      for (let i = 0; i < data.length; i += 400) {
        const batch = writeBatch(db);
        const end = Math.min(i + 400, data.length);
        for (let j = i; j < end; j++) {
          const rawTitle = data[j]?.title;
          const title = typeof rawTitle === 'string' ? rawTitle.trim() : '';
          if (!title) continue;
          batch.set(doc(col), { title, createdAt: serverTimestamp() });
        }
        await batch.commit();
      }
    } catch (e) {
      Logger.e('Error seeding date ideas', e);
    }
  }

  getRandomIdea(): DateIdea | null {
    const pool = AgentMode.demo
      ? AgentFixtures.demoDateIdeas()
      : this.cachedIdeas.length > 0
        ? this.cachedIdeas
        : AgentFixtures.demoDateIdeas();
    return pool[Math.floor(Math.random() * pool.length)] ?? null;
  }

  async generateAiIdea(): Promise<DateIdea | null> {
    if (AgentMode.demo) return null;
    try {
      const reply = await quickAsk(
        'Generate ONE unique, romantic date idea title (short, 3-7 words). Be creative and personal.\n\nRespond with ONLY the title — no quotes, no explanation, no extra text.',
        'You are a creative date planner. Generate unique, romantic date idea titles. Respond with ONLY the title text — no quotes, no markdown, no other text.',
      );
      const title = reply.replace(/["']/g, '').trim();
      if (!title) return null;
      return { id: `ai_${Date.now()}`, title };
    } catch (e) {
      Logger.w(`AI date idea failed: ${String(e)}`);
      return null;
    }
  }
}

export const dateIdeaService = new DateIdeaService();
