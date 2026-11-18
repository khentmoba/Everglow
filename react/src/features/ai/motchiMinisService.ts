// Port of lib/features/ai/data/services/motchi_minis_service.dart and domain/models/mini_game.dart.
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  Timestamp,
  type QuerySnapshot,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { just, snapshots, type Source } from '../../core/utils/liveSource';

export type MiniGame = { id: string; title: string; html: string; createdBy: string; createdAt: Date | null };

const SHELF_LIMIT = 50;
const str = (v: unknown) => (typeof v === 'string' ? v : '');

function parseTimestamp(v: unknown): Date | null {
  if (v instanceof Timestamp) return v.toDate();
  if (typeof v === 'number') return new Date(v);
  if (typeof v === 'string') {
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

export const motchiMinisService = {
  watchMinis(): Source<MiniGame[]> {
    if (AgentMode.demo) return just([]);
    return snapshots<QuerySnapshot, MiniGame[]>(
      (next, error) =>
        onSnapshot(query(collection(db, 'motchi_games'), orderBy('createdAt', 'desc'), limit(SHELF_LIMIT)), next, error),
      (snap) =>
        snap.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            title: str(data.title),
            html: str(data.html),
            createdBy: str(data.createdBy),
            createdAt: parseTimestamp(data.createdAt),
          };
        }),
    );
  },

  async saveMini({ title, html, createdBy }: { title: string; html: string; createdBy: string }): Promise<boolean> {
    const clean = title.trim() === '' ? 'Motchi Mini' : title.trim();
    if (html.trim() === '') return false;
    if (AgentMode.demo) return true;
    try {
      await addDoc(collection(db, 'motchi_games'), {
        title: clean.length > 80 ? `${clean.slice(0, 80)}…` : clean,
        html,
        createdBy,
        createdAt: serverTimestamp(),
      });
      return true;
    } catch (e) {
      Logger.e('Error saving mini game', e);
      return false;
    }
  },

  async deleteMini(id: string): Promise<void> {
    if (AgentMode.demo) return;
    try {
      await deleteDoc(doc(db, 'motchi_games', id));
    } catch (e) {
      Logger.e('Error deleting mini game', e);
    }
  },
};
