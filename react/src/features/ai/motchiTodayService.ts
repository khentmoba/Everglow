// Port of lib/features/ai/data/services/motchi_today_service.dart.
import { collection, doc, getDocs, limit, orderBy, query, where } from 'firebase/firestore';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { memoryFactFromJson, type MemoryFact, type Mood } from './memory';

export type TodaySnapshot = {
  date: Date;
  moods: Mood[];
  activities: string[];
  watchlist: string[];
  starlight: string[];
  memories: MemoryFact[];
};

const str = (v: unknown) => (typeof v === 'string' ? v : null);
const pad = (n: number, w = 2) => String(n).padStart(w, '0');
export const isoDay = (d: Date) => `${pad(d.getFullYear(), 4)}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

export async function fetchToday(now = new Date()): Promise<TodaySnapshot> {
  try {
    const [moods, activity, cinema, stars, memories] = await Promise.all([
      getDocs(query(collection(db, 'moods'), where('date', '==', isoDay(now)))),
      getDocs(query(collection(db, 'recent_activity'), orderBy('timestamp', 'desc'), limit(5))),
      getDocs(query(collection(db, 'our_cinema'), limit(5))),
      getDocs(query(collection(db, 'starlight_jar'), orderBy('timestamp', 'desc'), limit(3))),
      getDocs(query(collection(doc(db, 'ai_memories', 'shared'), 'facts'), orderBy('createdAt', 'desc'), limit(300))),
    ]);
    return {
      date: now,
      moods: moods.docs.map((d) => ({ uid: str(d.data().uid) ?? 'someone', mood: str(d.data().mood) ?? 'okay' })),
      activities: activity.docs.map((d) => str(d.data().activity) ?? str(d.data().description) ?? '').filter((v) => v !== ''),
      watchlist: cinema.docs.map((d) => str(d.data().title) ?? '').filter((v) => v !== ''),
      starlight: stars.docs.map((d) => str(d.data().content) ?? '').filter((v) => v !== ''),
      memories: memories.docs.map((d) => memoryFactFromJson({ ...d.data() }, d.id)).filter((f) => f.fact !== ''),
    };
  } catch (e) {
    Logger.w(`[MotchiTodayService] Failed to fetch recap: ${e}`);
    return { date: now, moods: [], activities: [], watchlist: [], starlight: [], memories: [] };
  }
}
