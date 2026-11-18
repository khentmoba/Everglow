// Port of lib/features/academy/data: models, AcademyService, StudySetService,
// AcademySyncService and TriviaApiService.
import {
  collection,
  deleteDoc,
  doc,
  documentId,
  getCountFromServer,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
  type DocumentData,
  type DocumentSnapshot,
} from 'firebase/firestore';
import { auth, db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { Prefs } from '../../core/system/prefs';
import { just, snapshots, withGetTimeout, type Source } from '../../core/utils/liveSource';

export type AcademyQuestion = {
  id: string;
  questionText: string;
  options: string[];
  correctOptionIndex: number;
  category: string;
  explanation: string | null;
};

export type GameMatch = {
  matchId: string;
  hostId: string;
  participantId: string | null;
  hostUsername: string | null;
  participantUsername: string | null;
  hostScore: number;
  guestScore: number;
  status: string;
  currentQuestionId: string;
  questionIndex: number;
  questionIds: string[];
  category: string;
  createdAt: Date;
  winnerId: string | null;
  isReplenishing: boolean;
};

export type SoloStats = {
  lastCategory: string | null;
  lastScore: number;
  lastTotal: number;
  bestByCategory: Record<string, number>;
};

export const MATCH_LENGTH = 10;
const FUNCTIONS = 'https://us-central1-everglow-1c6db.cloudfunctions.net';

const str = (v: unknown, fallback = '') => (typeof v === 'string' ? v : fallback);
const nullableStr = (v: unknown) => (typeof v === 'string' ? v : null);
const int = (v: unknown) => (typeof v === 'number' ? Math.trunc(v) : 0);

/** Dart's `List.shuffle()`: the same in-place swap order. */
export function shuffle<T>(list: T[]): T[] {
  for (let n = list.length; n > 1;) {
    const pos = Math.floor(Math.random() * n);
    n -= 1;
    [list[n], list[pos]] = [list[pos], list[n]];
  }
  return list;
}

export function questionFromMap(map: DocumentData, docId: string): AcademyQuestion {
  const explanation = map.explanation;
  return {
    id: docId,
    questionText: str(map.questionText),
    options: Array.isArray(map.options) ? map.options.map((e: unknown) => String(e)) : [],
    correctOptionIndex: int(map.correctOptionIndex),
    category: str(map.category, 'engineering'),
    explanation: typeof explanation === 'string' && explanation ? explanation : null,
  };
}

function questionToMap(q: AcademyQuestion): DocumentData {
  return {
    id: q.id,
    questionText: q.questionText,
    options: q.options,
    correctOptionIndex: q.correctOptionIndex,
    category: q.category,
    ...(q.explanation ? { explanation: q.explanation } : {}),
  };
}

/** `AcademyQuestion.generateId`: sha256 of the question text, as hex. */
export async function generateQuestionId(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

function toDate(v: unknown): Date {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  if (typeof v === 'number') return new Date(v);
  return new Date();
}

export function matchFromMap(map: DocumentData, docId: string): GameMatch {
  return {
    matchId: docId,
    hostId: str(map.hostId),
    participantId: nullableStr(map.participantId),
    hostUsername: nullableStr(map.hostUsername),
    participantUsername: nullableStr(map.participantUsername),
    hostScore: int(map.hostScore ?? map.khentScore),
    guestScore: int(map.guestScore ?? map.clairScore),
    status: str(map.status, 'waiting'),
    currentQuestionId: str(map.currentQuestionId),
    questionIndex: int(map.questionIndex),
    questionIds: Array.isArray(map.questionIds) ? map.questionIds.map((e: unknown) => String(e)) : [],
    category: str(map.category, 'engineering'),
    createdAt: toDate(map.createdAt),
    winnerId: nullableStr(map.winnerId),
    isReplenishing: typeof map.isReplenishing === 'boolean' ? map.isReplenishing : false,
  };
}

function matchToMap(m: GameMatch): DocumentData {
  return {
    hostId: m.hostId,
    participantId: m.participantId,
    ...(m.hostUsername != null ? { hostUsername: m.hostUsername } : {}),
    ...(m.participantUsername != null ? { participantUsername: m.participantUsername } : {}),
    hostScore: m.hostScore,
    guestScore: m.guestScore,
    status: m.status,
    currentQuestionId: m.currentQuestionId,
    questionIndex: m.questionIndex,
    questionIds: m.questionIds,
    category: m.category,
    createdAt: Timestamp.fromDate(m.createdAt),
    winnerId: m.winnerId,
    isReplenishing: m.isReplenishing,
  };
}

const questionsRef = () => collection(db, 'academy_questions');
const matchesRef = () => collection(db, 'active_matches');

export const academyService = {
  async getQuestions(category: string, max = 10): Promise<AcademyQuestion[]> {
    const snap = await withGetTimeout(
      getDocs(query(questionsRef(), where('category', '==', category), limit(max * 3))),
      'academy questions',
    );
    const questions = shuffle(snap.docs.map((d) => questionFromMap(d.data(), d.id)));
    return questions.slice(0, max);
  },

  async getQuestionsExcluding(category: string, max = 10, excludeIds: Set<string> = new Set()): Promise<AcademyQuestion[]> {
    const snap = await withGetTimeout(
      getDocs(query(questionsRef(), where('category', '==', category), limit(max * 5))),
      'academy questions excluding seen',
    );
    const questions = shuffle(snap.docs.map((d) => questionFromMap(d.data(), d.id)));
    if (excludeIds.size === 0) return questions.slice(0, max);
    const fresh = questions.filter((q) => !excludeIds.has(q.id));
    if (fresh.length >= max) return fresh.slice(0, max);
    const rest = questions.filter((q) => excludeIds.has(q.id));
    return [...fresh, ...rest].slice(0, max);
  },

  async getQuestionsByIds(ids: string[]): Promise<AcademyQuestion[]> {
    if (ids.length === 0) return [];
    const found = new Map<string, AcademyQuestion>();
    for (let i = 0; i < ids.length; i += 10) {
      const chunk = ids.slice(i, i + 10);
      const snap = await withGetTimeout(
        getDocs(query(questionsRef(), where(documentId(), 'in', chunk))),
        'academy questions by id',
      );
      for (const d of snap.docs) found.set(d.id, questionFromMap(d.data(), d.id));
    }
    return ids.flatMap((id) => (found.has(id) ? [found.get(id)!] : []));
  },

  async seedQuestions(): Promise<void> {
    try {
      const data = (await (await fetch('/data/academy_questions_seed.json')).json()) as Array<Record<string, unknown>>;
      for (let i = 0; i < data.length; i += 500) {
        const batch = writeBatch(db);
        for (const q of data.slice(i, i + 500)) {
          const questionText = str(q.questionText);
          const id = await generateQuestionId(questionText);
          batch.set(
            doc(questionsRef(), id),
            {
              id,
              questionText,
              options: Array.isArray(q.options) ? q.options.map(String) : [],
              correctOptionIndex: q.correctOptionIndex ?? 0,
              category: q.category ?? 'general',
              createdAt: serverTimestamp(),
              source: 'local_seed',
            },
            { merge: true },
          );
        }
        await batch.commit();
      }
      Logger.i(`Successfully seeded ${data.length} questions to Firestore`);
    } catch (e) {
      Logger.e('Error seeding questions', e);
      throw e;
    }
  },

  async joinOrCreateMatch(userUid: string, username: string, category: string, questionIds?: string[]): Promise<GameMatch> {
    await cleanupStaleMatches(userUid);

    const waiting = await withGetTimeout(
      getDocs(query(matchesRef(), where('status', '==', 'waiting'), where('category', '==', category), limit(1))),
      'academy waiting match',
    );

    if (!waiting.empty) {
      const ref = waiting.docs[0].ref;
      return runTransaction(db, async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists()) throw new Error('Match no longer available');
        const match = matchFromMap(snap.data(), snap.id);
        if (match.status === 'waiting' && match.hostId !== userUid) {
          tx.update(ref, { status: 'active', participantId: userUid, participantUsername: username });
          return { ...match, status: 'active', participantId: userUid, participantUsername: username };
        }
        throw new Error('Match no longer available');
      });
    }

    const ids =
      questionIds && questionIds.length > 0
        ? questionIds.slice(0, MATCH_LENGTH)
        : (await academyService.getQuestions(category, MATCH_LENGTH)).map((q) => q.id);
    if (ids.length === 0) throw new Error('No questions found for category');

    const ref = doc(matchesRef());
    const match: GameMatch = {
      matchId: ref.id,
      hostId: userUid,
      participantId: null,
      hostUsername: username,
      participantUsername: null,
      hostScore: 0,
      guestScore: 0,
      status: 'waiting',
      currentQuestionId: ids[0],
      questionIndex: 0,
      questionIds: ids,
      category,
      createdAt: new Date(),
      winnerId: null,
      isReplenishing: false,
    };
    await setDoc(ref, matchToMap(match));
    return match;
  },

  async upgradeWaitingMatchQuestions(matchId: string, questionIds: string[]): Promise<boolean> {
    if (questionIds.length === 0) return false;
    try {
      return await runTransaction(db, async (tx) => {
        const ref = doc(matchesRef(), matchId);
        const snap = await tx.get(ref);
        if (!snap.exists()) return false;
        if (matchFromMap(snap.data(), snap.id).status !== 'waiting') return false;
        const ids = questionIds.slice(0, MATCH_LENGTH);
        tx.update(ref, { questionIds: ids, currentQuestionId: ids[0], questionIndex: 0 });
        return true;
      });
    } catch (e) {
      Logger.e('Error upgrading waiting match questions', e);
      return false;
    }
  },

  async cancelWaitingMatch(matchId: string): Promise<void> {
    try {
      const ref = doc(matchesRef(), matchId);
      const snap = await withGetTimeout(getDoc(ref), 'academy cancel match check');
      if (!snap.exists()) return;
      if (matchFromMap(snap.data(), snap.id).status === 'waiting') await deleteDoc(ref);
    } catch (e) {
      Logger.e('Error cancelling waiting match', e);
    }
  },

  submitAnswer(matchId: string, username: string, questionId: string): Promise<boolean> {
    const ref = doc(matchesRef(), matchId);
    return runTransaction(db, async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists()) return false;
      const match = matchFromMap(snap.data(), snap.id);
      if (match.status !== 'active' || match.currentQuestionId !== questionId) return false;

      const isHost = (match.hostUsername ?? match.hostId) === username;
      const nextIndex = match.questionIndex + 1;
      const isFinished = match.questionIds.length === 0 ? true : nextIndex >= match.questionIds.length;
      const nextQuestionId = isFinished ? '' : match.questionIds[nextIndex];
      const hostScore = match.hostScore + (isHost ? 10 : 0);
      const guestScore = match.guestScore + (!isHost ? 10 : 0);

      tx.update(ref, {
        hostScore,
        guestScore,
        questionIndex: nextIndex,
        currentQuestionId: nextQuestionId,
        status: isFinished ? 'finished' : 'active',
        winnerId: isFinished ? winner(hostScore, guestScore, match.hostUsername, match.participantUsername) : null,
      });
      return true;
    });
  },

  watchMatch(matchId: string): Source<GameMatch | null> {
    return snapshots<DocumentSnapshot, GameMatch | null>(
      (next, error) => onSnapshot(doc(matchesRef(), matchId), next, error),
      (snap) => (snap.exists() ? matchFromMap(snap.data(), snap.id) : null),
    );
  },
};

function winner(hostScore: number, guestScore: number, host: string | null, guest: string | null): string {
  if (hostScore > guestScore) return host ?? 'draw';
  if (guestScore > hostScore) return guest ?? 'draw';
  return 'draw';
}

async function cleanupStaleMatches(userUid: string): Promise<void> {
  const stale = Timestamp.fromDate(new Date(Date.now() - 30 * 60 * 1000));
  const snap = await withGetTimeout(
    getDocs(query(matchesRef(), where('createdAt', '<', stale), limit(50))),
    'academy stale match cleanup',
  );
  let batch = writeBatch(db);
  let pending = 0;
  for (const d of snap.docs) {
    if (d.data()?.hostId !== userUid) continue;
    batch.delete(d.ref);
    if (++pending >= 400) {
      await batch.commit();
      batch = writeBatch(db);
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
}

// --- StudySetService ---

const DEFAULT_COUNT = 10;
const MAX_SEEN_IDS = 100;
const progressRef = (uid: string) => doc(db, 'users', uid, 'progress', 'academy');

function soloStatsFromMap(map: DocumentData): SoloStats {
  const best: Record<string, number> = {};
  const raw = map.bestByCategory;
  if (raw && typeof raw === 'object') {
    for (const [k, v] of Object.entries(raw)) if (typeof v === 'number') best[k] = Math.trunc(v);
  }
  return {
    lastCategory: typeof map.lastCategory === 'string' ? map.lastCategory : null,
    lastScore: int(map.lastScore),
    lastTotal: int(map.lastTotal),
    bestByCategory: best,
  };
}

async function readSeenIds(): Promise<Set<string>> {
  try {
    const uid = auth.currentUser?.uid;
    if (!uid) return new Set();
    const snap = await withGetTimeout(getDoc(progressRef(uid)), 'academy seen ids read');
    const raw = snap.data()?.seenIds;
    if (!Array.isArray(raw)) return new Set();
    return new Set(raw.map(String));
  } catch (e) {
    Logger.e('Error reading seen ids', e);
    return new Set();
  }
}

async function recordSeen(ids: string[]): Promise<void> {
  try {
    const uid = auth.currentUser?.uid;
    if (!uid) return;
    const next = [...(await readSeenIds()), ...ids];
    const trimmed = next.length > MAX_SEEN_IDS ? next.slice(next.length - MAX_SEEN_IDS) : next;
    await setDoc(progressRef(uid), { seenIds: trimmed, updatedAt: serverTimestamp() }, { merge: true });
  } catch (e) {
    Logger.e('Error recording seen ids', e);
  }
}

async function generateViaMotchi(category: string, count: number, topic = ''): Promise<AcademyQuestion[]> {
  const token = (await auth.currentUser?.getIdToken()) ?? '';
  if (!token) throw new Error('Not signed in');
  const response = await fetch(`${FUNCTIONS}/generateStudySet`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ category, count, ...(topic.trim() ? { topic: topic.trim() } : {}) }),
    signal: AbortSignal.timeout(75_000),
  });
  const body = await response.text();
  if (response.status !== 200) throw new Error(`Study generator ${response.status}: ${body}`);
  const raw = (JSON.parse(body) as { questions?: unknown }).questions;
  if (!Array.isArray(raw) || raw.length === 0) throw new Error('Empty study set');
  return Promise.all(
    raw.map(async (item: Record<string, unknown>) => {
      const text = String(item.questionText ?? '');
      const explanation = String(item.explanation ?? '');
      return {
        id: await generateQuestionId(text),
        questionText: text,
        options: (item.options as unknown[]).map(String),
        correctOptionIndex: Math.trunc(item.correctOptionIndex as number),
        category,
        explanation: explanation ? explanation : null,
      };
    }),
  );
}

async function saveQuestions(questions: AcademyQuestion[], category: string, source: string): Promise<void> {
  if (questions.length === 0) return;
  let batch = writeBatch(db);
  let pending = 0;
  for (const q of questions) {
    batch.set(
      doc(questionsRef(), q.id),
      { ...questionToMap(q), id: q.id, category, createdAt: serverTimestamp(), source },
      { merge: true },
    );
    if (++pending >= 400) {
      await batch.commit();
      batch = writeBatch(db);
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
}

export const studySetService = {
  async buildSoloSet(category: string, topic = '', count = DEFAULT_COUNT): Promise<AcademyQuestion[]> {
    const seen = await readSeenIds();
    let fresh: AcademyQuestion[] = [];
    try {
      fresh = await generateViaMotchi(category, count, topic);
      await saveQuestions(fresh, category, 'motchi');
    } catch (e) {
      Logger.e('Motchi set failed, falling back to cache', e);
    }

    const freshUnseen = fresh.filter((q) => !seen.has(q.id));
    const useFresh = freshUnseen.length >= 5 ? freshUnseen : fresh;
    if (useFresh.length >= count) {
      const picked = useFresh.slice(0, count);
      await recordSeen(picked.map((q) => q.id));
      return picked;
    }
    const cached = await academyService.getQuestionsExcluding(category, count, new Set([...seen, ...useFresh.map((q) => q.id)]));
    const combined = [...useFresh, ...cached].slice(0, count);
    await recordSeen(combined.map((q) => q.id));
    return combined;
  },

  async buildMatchSet(category: string): Promise<string[]> {
    try {
      const fresh = await generateViaMotchi(category, MATCH_LENGTH);
      await saveQuestions(fresh, category, 'motchi');
      if (fresh.length >= 5) return fresh.slice(0, MATCH_LENGTH).map((q) => q.id);
    } catch (e) {
      Logger.e('Motchi match set failed, falling back to cache', e);
    }
    return (await academyService.getQuestions(category, MATCH_LENGTH)).map((q) => q.id);
  },

  async saveSoloResult(category: string, score: number, total: number): Promise<boolean> {
    try {
      const uid = auth.currentUser?.uid;
      if (!uid) return false;
      const ref = progressRef(uid);
      const snap = await withGetTimeout(getDoc(ref), 'academy progress read');
      const best = { ...((snap.data()?.bestByCategory as Record<string, unknown>) ?? {}) };
      const prev = typeof best[category] === 'number' ? Math.trunc(best[category] as number) : 0;
      const isBest = score > prev;
      await setDoc(
        ref,
        {
          bestByCategory: { ...best, [category]: isBest ? score : prev },
          lastCategory: category,
          lastScore: score,
          lastTotal: total,
          lastPlayedAt: serverTimestamp(),
        },
        { merge: true },
      );
      return isBest;
    } catch (e) {
      Logger.e('Error saving solo result', e);
      return false;
    }
  },

  watchSoloStats(): Source<SoloStats | null> {
    const uid = auth.currentUser?.uid;
    if (!uid) return just(null);
    return snapshots<DocumentSnapshot, SoloStats | null>(
      (next, error) => onSnapshot(progressRef(uid), next, error),
      (snap) => {
        if (!snap.exists()) return null;
        try {
          return soloStatsFromMap(snap.data() ?? {});
        } catch (e) {
          Logger.e('Error reading solo stats', e);
          return null;
        }
      },
    );
  },
};

// --- AcademySyncService + TriviaApiService (OpenTDB through proxyCatalog) ---

const TOKEN_KEY = 'opentdb_session_token';
const TOKEN_TIME_KEY = 'opentdb_token_timestamp';
let sessionToken: string | null = null;

async function opentdb(
  path: string,
  params: Record<string, string>,
  timeoutMs: number,
): Promise<{ status: number; body: string }> {
  const rawQuery = `?${new URLSearchParams(params).toString()}`;
  const url = `${FUNCTIONS}/proxyCatalog?${new URLSearchParams({ base: 'opentdb', path: `${path}${rawQuery}` }).toString()}`;
  const token = auth.currentUser ? await auth.currentUser.getIdToken().catch(() => null) : null;
  const resp = await fetch(url, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    signal: AbortSignal.timeout(timeoutMs),
  });
  return { status: resp.status, body: await resp.text() };
}

async function requestNewToken(): Promise<void> {
  const r = await opentdb('api_token.php', { command: 'request' }, 10_000);
  if (r.status !== 200) return;
  const data = JSON.parse(r.body);
  if (data.response_code === 0) {
    sessionToken = data.token;
    Prefs.set(TOKEN_KEY, sessionToken!);
    Prefs.set(TOKEN_TIME_KEY, Date.now());
  }
}

async function initSession(): Promise<void> {
  sessionToken = Prefs.getString(TOKEN_KEY);
  const stamp = Prefs.get(TOKEN_TIME_KEY);
  if (sessionToken == null || typeof stamp !== 'number' || Date.now() - stamp > 6 * 60 * 60 * 1000) await requestNewToken();
}

async function resetSession(): Promise<void> {
  if (sessionToken == null) return;
  const r = await opentdb('api_token.php', { command: 'reset', token: sessionToken }, 10_000);
  if (r.status === 200 && JSON.parse(r.body).response_code === 0) Prefs.set(TOKEN_TIME_KEY, Date.now());
}

function unescapeHtml(s: string): string {
  return new DOMParser().parseFromString(s, 'text/html').documentElement.textContent ?? s;
}

const API_CATEGORY: Record<string, string> = {
  18: 'engineering',
  19: 'engineering',
  22: 'tourism',
  23: 'tourism',
  12: 'music',
  9: 'general',
  32: 'cartoons',
  26: 'celebrities',
  11: 'film',
  10: 'books',
};

export function apiCategoryIds(category: string): number[] {
  const ids: Record<string, number[]> = {
    engineering: [18, 19],
    tourism: [22, 23],
    music: [12],
    general: [9],
    cartoons: [32],
    celebrities: [26],
    film: [11],
    books: [10],
  };
  return ids[category] ?? [9];
}

async function fetchTrivia(categoryId: number, amount = 50, retry = 0): Promise<AcademyQuestion[]> {
  if (sessionToken == null) await initSession();
  const r = await opentdb(
    'api.php',
    { amount: `${amount}`, category: `${categoryId}`, type: 'multiple', token: `${sessionToken}` },
    15_000,
  );
  if (r.status !== 200) throw new Error(`Failed to load trivia: ${r.status}`);
  const data = JSON.parse(r.body);
  const code = data.response_code as number;
  switch (code) {
    case 0:
      return Promise.all(
        (data.results as Array<Record<string, unknown>>).map(async (json) => {
          const questionText = unescapeHtml(json.question as string);
          const correct = unescapeHtml(json.correct_answer as string);
          const options = shuffle([...(json.incorrect_answers as string[]).map(unescapeHtml), correct]);
          return {
            id: await generateQuestionId(questionText),
            questionText,
            options,
            correctOptionIndex: options.indexOf(correct),
            category: API_CATEGORY[categoryId] ?? 'general',
            explanation: null,
          };
        }),
      );
    case 3:
      if (retry >= 3) throw new Error('OpenTDB session recovery failed after retries.');
      await requestNewToken();
      return fetchTrivia(categoryId, amount, retry + 1);
    case 4:
      if (retry >= 3) throw new Error('OpenTDB session recovery failed after retries.');
      await resetSession();
      return fetchTrivia(categoryId, amount, retry + 1);
    case 5:
      if (retry < 3) {
        await new Promise((r) => setTimeout(r, 5000 * (retry + 1)));
        return fetchTrivia(categoryId, amount, retry + 1);
      }
      throw new Error('OpenTDB Rate Limit exceeded after retries.');
    default:
      throw new Error(`OpenTDB API Error: Code ${code}`);
  }
}

export const academySyncService = {
  async triggerAutoFill(category: string, isHost = true, matchId?: string): Promise<void> {
    if (!isHost) return;
    const ids = apiCategoryIds(category);
    if (ids.length === 0) return;
    const apiCategoryId = shuffle([...ids])[0];
    const count = (
      await withGetTimeout(
        getCountFromServer(query(questionsRef(), where('category', '==', category))),
        'academy unused question count',
      )
    ).data().count;
    if (count >= 10) return;
    if (matchId) await updateDoc(doc(matchesRef(), matchId), { isReplenishing: true });
    try {
      const fresh = await fetchTrivia(apiCategoryId, 50);
      const batch = writeBatch(db);
      for (const q of fresh) {
        batch.set(
          doc(questionsRef(), q.id),
          { ...questionToMap(q), id: q.id, createdAt: serverTimestamp(), source: 'opentdb' },
          { merge: true },
        );
      }
      await batch.commit();
    } catch (e) {
      Logger.e('Error replenishing questions', e);
      throw e;
    }
    if (matchId) await updateDoc(doc(matchesRef(), matchId), { isReplenishing: false });
  },
};

export { displayNameFor } from '../../shared/utils/text';
