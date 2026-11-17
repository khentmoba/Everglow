// Port of lib/features/ai/data/services/ai_memory_repo.dart.
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  Timestamp,
  updateDoc,
  where,
} from 'firebase/firestore';
import { auth, db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { memoryFactFromJson, parseFactStructure, type MemoryFact } from './memory';

const factsRef = () => collection(doc(db, 'ai_memories', 'shared'), 'facts');
const normalize = (s: string) =>
  s
    .toLowerCase()
    .replace(/[^\w\s]/g, '')
    .trim();

export class AIMemoryRepository {
  private memories: string[] = [];
  private factList: MemoryFact[] = [];
  private loaded = false;

  get all(): string[] {
    return [...this.memories];
  }
  get facts(): MemoryFact[] {
    return [...this.factList];
  }
  get isLoaded(): boolean {
    return this.loaded;
  }

  async load(): Promise<void> {
    if (this.loaded) return;
    try {
      const snap = await getDocs(query(factsRef(), orderBy('createdAt', 'desc'), limit(150)));
      this.memories = snap.docs.map((d) => d.data().fact).filter((f): f is string => typeof f === 'string' && f !== '');
      this.factList = snap.docs.map((d) => memoryFactFromJson({ ...d.data() }, d.id)).filter((f) => f.fact !== '');
    } catch (e) {
      Logger.d(`Failed to load memories: ${e}`);
    }
    this.loaded = true;
  }

  private get uid(): string {
    return auth.currentUser?.uid ?? 'unknown';
  }

  async save(fact: string, category = 'fact'): Promise<void> {
    const clean = fact.trim();
    if (clean === '') return;
    try {
      await addDoc(factsRef(), {
        fact: clean,
        category,
        addedBy: this.uid,
        createdAt: serverTimestamp(),
        confidence: 1.0,
        accessCount: 0,
        lastAccessed: null,
      });
      this.memories.unshift(clean);
      this.factList.unshift(memoryFactFromJson({ fact: clean, category, source: this.uid }));
    } catch (e) {
      Logger.d(`Failed to save memory: ${e}`);
    }
  }

  async delete(factId: string): Promise<void> {
    try {
      if (factId === '') {
        const snap = await getDocs(query(factsRef(), where('fact', '==', factId), limit(1)));
        for (const d of snap.docs) {
          await deleteDoc(d.ref);
          this.memories = this.memories.filter((m) => m !== factId);
          this.factList = this.factList.filter((f) => f.fact !== factId);
        }
        return;
      }
      await deleteDoc(doc(factsRef(), factId));
      const removed = new Set(this.factList.filter((f) => f.id === factId).map((f) => f.fact));
      const index = this.memories.findIndex((m) => removed.has(m));
      if (index >= 0) this.memories.splice(index, 1);
      this.factList = this.factList.filter((f) => f.id !== factId);
    } catch (e) {
      Logger.d(`Failed to delete memory: ${e}`);
    }
  }

  async setPinned(factId: string, pinned: boolean): Promise<void> {
    if (factId === '') return;
    try {
      await updateDoc(doc(factsRef(), factId), { pinned });
      this.factList = this.factList.map((f) => (f.id === factId ? { ...f, pinned } : f));
    } catch (e) {
      Logger.d(`Failed to pin memory: ${e}`);
    }
  }

  async saveStructured({
    fact,
    category = 'fact',
    subject,
    relation,
    object,
    occurredAt,
  }: {
    fact: string;
    category?: string;
    subject?: string | null;
    relation?: string | null;
    object?: string | null;
    occurredAt?: Date | null;
  }): Promise<void> {
    const clean = fact.trim();
    if (clean === '') return;
    try {
      const [s, r, o] = parseFactStructure(fact);
      const fields = { subject: subject ?? s, relation: relation ?? r, object: object ?? o };
      await addDoc(factsRef(), {
        fact: clean,
        category,
        ...fields,
        ...(occurredAt ? { occurredAt: Timestamp.fromDate(occurredAt) } : {}),
        addedBy: this.uid,
        createdAt: serverTimestamp(),
        confidence: 1.0,
        accessCount: 0,
        lastAccessed: null,
        pinned: false,
        source: this.uid,
      });
      this.memories.unshift(clean);
      this.factList.unshift({
        ...memoryFactFromJson({ fact: clean, category, source: this.uid }),
        ...fields,
        occurredAt: occurredAt ?? null,
      });
    } catch (e) {
      Logger.d(`Failed to save structured memory: ${e}`);
    }
  }

  isDuplicate(fact: string): boolean {
    const n = normalize(fact);
    return this.memories.some((existing) => {
      const e = normalize(existing);
      return n === e || e.includes(n) || n.includes(e);
    });
  }

  reset(): void {
    this.memories = [];
    this.factList = [];
    this.loaded = false;
  }
}
