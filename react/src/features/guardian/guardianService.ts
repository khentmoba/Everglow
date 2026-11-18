// Port of lib/features/guardian/data/services/guardian_service.dart.
import { collection, getDocs, limit, query, serverTimestamp, writeBatch, doc, type Timestamp } from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type GuardianMessageFixture } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { withGetTimeout } from '../../core/utils/liveSource';

export type GuardianMessage = GuardianMessageFixture;

const CACHE_TTL_MS = 15 * 60 * 1000;
const MAX_CACHED = 200;
const MAX_INIT_ATTEMPTS = 3;

const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

class GuardianService {
  private cachedMessages: GuardianMessage[] = [];
  private byCategory = new Map<string, GuardianMessage[]>();
  private lastFetch: number | null = null;
  private inflight: Promise<void> | null = null;
  private lastPickedId: string | null = null;

  get messages(): GuardianMessage[] {
    return this.cachedMessages;
  }

  async initialize(): Promise<void> {
    if (this.inflight) return this.inflight;
    if (AgentMode.demo) {
      this.cachedMessages = AgentFixtures.demoGuardianMessages();
      this.rebuildIndex();
      return;
    }
    if (this.cachedMessages.length > 0 && this.lastFetch != null && Date.now() - this.lastFetch < CACHE_TTL_MS) {
      return;
    }
    this.inflight = this.initializeWithRetry().finally(() => {
      this.inflight = null;
    });
    return this.inflight;
  }

  private async initializeWithRetry(): Promise<void> {
    for (let attempt = 1; attempt <= MAX_INIT_ATTEMPTS; attempt++) {
      await this.initializeOnce(attempt);
      if (this.cachedMessages.length > 0) return;
      if (attempt < MAX_INIT_ATTEMPTS) await delay(attempt * 2000);
    }
  }

  private async initializeOnce(attempt: number): Promise<void> {
    try {
      const q = query(collection(db, 'guardian_messages'), limit(MAX_CACHED));
      let snap = await withGetTimeout(getDocs(q), 'guardian messages init');
      if (snap.empty) {
        await this.seedMessages();
        snap = await withGetTimeout(getDocs(q), 'guardian messages reload after seed');
      }
      this.cachedMessages = snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          content: String(data.content ?? ''),
          category: String(data.category ?? 'idle'),
          createdAt: (data.createdAt as Timestamp | undefined)?.toDate() ?? new Date(),
        };
      });
      this.rebuildIndex();
      this.lastFetch = Date.now();
    } catch (e) {
      if (attempt < MAX_INIT_ATTEMPTS) {
        Logger.w(`Guardian messages init attempt ${attempt}/${MAX_INIT_ATTEMPTS} slow or failed, retrying... ${String(e)}`);
      } else {
        Logger.e(`Error initializing guardian messages after ${MAX_INIT_ATTEMPTS} attempts`, e);
      }
    }
  }

  private rebuildIndex(): void {
    this.byCategory.clear();
    for (const m of this.cachedMessages) {
      const list = this.byCategory.get(m.category) ?? [];
      list.push(m);
      this.byCategory.set(m.category, list);
    }
  }

  getRandomMessage(category?: string): GuardianMessage | null {
    const pool = category ? (this.byCategory.get(category) ?? []) : this.cachedMessages;
    if (pool.length === 0) return null;
    if (pool.length === 1) return pool[0];
    let picked = pool[Math.floor(Math.random() * pool.length)];
    if (picked.id === this.lastPickedId) {
      picked = pool[Math.floor(Math.random() * pool.length)];
    }
    this.lastPickedId = picked.id;
    return picked;
  }

  async seedMessages(): Promise<void> {
    try {
      const resp = await fetch('/data/guardian_messages_seed.json');
      if (!resp.ok) return;
      const data = (await resp.json()) as Array<{ content?: unknown; category?: unknown }>;
      if (!Array.isArray(data) || data.length === 0) return;
      const col = collection(db, 'guardian_messages');
      const chunkSize = 400;
      for (let i = 0; i < data.length; i += chunkSize) {
        const batch = writeBatch(db);
        const end = Math.min(i + chunkSize, data.length);
        for (let j = i; j < end; j++) {
          const item = data[j];
          const content = typeof item?.content === 'string' ? item.content.trim() : '';
          if (!content) continue;
          batch.set(doc(col), {
            content,
            category: typeof item.category === 'string' ? item.category : 'idle',
            createdAt: serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (e) {
      Logger.e('Error seeding guardian messages', e);
    }
  }
}

export const guardianService = new GuardianService();
