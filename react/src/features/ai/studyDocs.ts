// Port of lib/features/ai/data/services/study_doc_service.dart and
// study_history_service.dart.
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  type DocumentSnapshot,
} from 'firebase/firestore';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';

export const kMaxStudyPdfBytes = 10 * 1024 * 1024;
export const kMaxStudyDocs = 3;

export type StudyDoc = { fileName: string; text: string; truncated: boolean };

export class StudyDocException extends Error {}

export function truncateStudyText(text: string, maxChars: number): { text: string; truncated: boolean } {
  const cleaned = text.trim();
  if (cleaned.length <= maxChars) return { text: cleaned, truncated: false };
  return { text: cleaned.slice(0, maxChars).trimEnd(), truncated: true };
}

export function buildSourcesBlock(docs: StudyDoc[]): string {
  let out = `Study sources (${docs.length}): ${docs.map((d) => `"${d.fileName}"`).join(', ')}.\n`;
  for (const d of docs) {
    out += `--- ${d.fileName} ---\n${d.text}\n`;
    if (d.truncated) out += '[Cut here to fit — this is the start of the PDF.]\n';
  }
  return `${out}Answer using ONLY these sources.`;
}

const summarize = 'Summarize this for us so we can study it — key points first, then details. Keep it warm and simple.';
const quiz =
  'Quiz us on this! Ask 5 multiple-choice questions based ONLY on the material above. ' +
  'Ask them all now with A–D options, wait for our answers, then correct us gently. ' +
  'After the friendly quiz, append a hidden fenced block named quiz-json with the same questions as JSON: ' +
  '[{"q":"question","options":["a","b","c","d"],"answer":0,"why":"one-line gentle explanation"}] ' +
  'where answer is the 0-based index of the correct option. JSON only inside the block, no commentary.';
const flashcards =
  'Make us flashcards from this — show each card as "Front: ..." then "Back: ..." lines, 10 cards max, based ONLY on the material above. ' +
  'After the friendly cards, append a hidden fenced block named flashcards-json with the same cards as JSON: ' +
  '[{"front":"...","back":"..."}]. JSON only inside the block, no commentary.';
const explain = 'Explain this simply, like we are seeing it for the first time. Use everyday examples.';
const quizPlain =
  'Quiz us on this! Ask 5 multiple-choice questions based ONLY on the material above. ' +
  'Ask them all now with A–D options, wait for our answers, then correct us gently. ' +
  'Plain text only — no hidden blocks.';
const flashcardsPlain =
  'Make us flashcards from this — show each card as "Front: ..." then "Back: ..." lines, 10 cards max, based ONLY on the material above. ' +
  'Plain text only — no hidden blocks.';

export const StudyPrompts = {
  chipsFor(canvasOn: boolean): [label: string, prompt: string][] {
    return [
      ['Summarize 📝', summarize],
      ['Quiz us ✍️', canvasOn ? quiz : quizPlain],
      ['Flashcards 🃏', canvasOn ? flashcards : flashcardsPlain],
      ['Explain simply 💡', explain],
    ];
  },
};

function pickPdfFile(): Promise<File | null> {
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.pdf,application/pdf';
    input.onchange = () => resolve(input.files?.[0] ?? null);
    input.oncancel = () => resolve(null);
    input.click();
  });
}

async function extractPdfText(bytes: ArrayBuffer): Promise<string> {
  const pdfjs = await import('pdfjs-dist');
  pdfjs.GlobalWorkerOptions.workerSrc = new URL('pdfjs-dist/build/pdf.worker.min.mjs', import.meta.url).toString();
  try {
    const task = pdfjs.getDocument({ data: new Uint8Array(bytes) });
    const pdf = await task.promise;
    let text = '';
    for (let p = 1; p <= pdf.numPages; p++) {
      const page = await pdf.getPage(p);
      const content = await page.getTextContent();
      let line = '';
      for (const item of content.items) {
        if (!('str' in item)) continue;
        line += item.str;
        if (item.hasEOL) {
          text += `${line}\n`;
          line = '';
        }
      }
      text += `${line}\n`;
    }
    await task.destroy();
    return text;
  } catch {
    throw new StudyDocException('That file is not a readable PDF.');
  }
}

export async function pickAndExtractPdf(): Promise<StudyDoc | null> {
  const file = await pickPdfFile();
  if (!file) return null;
  if (file.size > kMaxStudyPdfBytes) throw new StudyDocException('That PDF is over 10 MB — try a smaller one.');
  const text = await extractPdfText(await file.arrayBuffer());
  if (!text.trim()) {
    throw new StudyDocException('Motchi could not find any text in there — it may be scanned photos. Try a text-based PDF.');
  }
  return { fileName: file.name, text: text.trim(), truncated: false };
}

export type StudyTurn = { fromUser: boolean; text: string };

export type StudySession = {
  id: string;
  title: string;
  sourceNames: string[];
  sources: StudyDoc[];
  turns: StudyTurn[];
  messageCount: number;
  createdAt: Date;
  updatedAt: Date;
};

const kMaxStoredStudySourceChars = 500000;

function trimSourcesForStorage(sources: StudyDoc[]): StudyDoc[] {
  const total = sources.reduce((a, d) => a + d.text.length, 0);
  if (total <= kMaxStoredStudySourceChars || sources.length === 0) return sources;
  const share = Math.floor(kMaxStoredStudySourceChars / sources.length);
  return sources.map((d) =>
    d.text.length <= share ? d : { fileName: d.fileName, text: truncateStudyText(d.text, share).text, truncated: true },
  );
}

export function studySessionTitle(turns: StudyTurn[]): string {
  for (const t of turns) {
    if (!t.fromUser) continue;
    const oneLine = t.text.replace(/\s+/g, ' ').trim();
    if (!oneLine) continue;
    if (oneLine.length <= 60) return oneLine;
    return `${oneLine.slice(0, 60).trimEnd()}…`;
  }
  return 'Untitled study';
}

const sessionsRef = () => collection(doc(db, 'ai_memories', 'shared'), 'study_sessions');

function readTime(value: unknown): Date {
  if (value instanceof Timestamp) return value.toDate();
  if (typeof value === 'string') {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? new Date() : d;
  }
  return new Date();
}

function fromDoc(snap: DocumentSnapshot): StudySession {
  const data = (snap.data() ?? {}) as Record<string, unknown>;
  const sourcesJson = (data.sources as Record<string, unknown>[] | undefined) ?? [];
  const messagesJson = (data.messages as Record<string, unknown>[] | undefined) ?? [];
  const sourceNames =
    (data.sourceNames as unknown[] | undefined)?.map(String) ?? sourcesJson.map((s) => String(s?.fileName ?? 'PDF'));
  const title = typeof data.title === 'string' && data.title.trim() ? data.title : 'Untitled study';
  return {
    id: snap.id,
    title,
    sourceNames,
    sources: sourcesJson.map((s) => ({
      fileName: typeof s?.fileName === 'string' ? s.fileName : 'PDF',
      text: typeof s?.text === 'string' ? s.text : '',
      truncated: s?.truncated === true,
    })),
    turns: messagesJson.map((m) => ({
      fromUser: m?.role !== 'assistant',
      text: typeof m?.content === 'string' ? m.content : '',
    })),
    messageCount: typeof data.messageCount === 'number' ? Math.trunc(data.messageCount) : messagesJson.length,
    createdAt: readTime(data.createdAt),
    updatedAt: readTime(data.updatedAt ?? data.createdAt),
  };
}

export const studyHistory = {
  async saveSession(sessionId: string | null, sources: StudyDoc[], turns: StudyTurn[]): Promise<string | null> {
    if (sources.length === 0 && turns.length === 0) return sessionId;
    const title =
      turns.length === 0
        ? `${sources.length} source${sources.length === 1 ? '' : 's'} — ${sources[0].fileName}`
        : studySessionTitle(turns);
    const storedTurns = turns.length > 60 ? turns.slice(turns.length - 60) : turns;
    const payload: Record<string, unknown> = {
      title,
      sourceNames: sources.map((d) => d.fileName),
      sources: trimSourcesForStorage(sources).map((d) => ({ fileName: d.fileName, text: d.text, truncated: d.truncated })),
      messages: storedTurns.map((t) => ({ role: t.fromUser ? 'user' : 'assistant', content: t.text })),
      messageCount: storedTurns.length,
      updatedAt: serverTimestamp(),
    };
    try {
      if (sessionId == null) {
        payload.createdAt = serverTimestamp();
        return (await addDoc(sessionsRef(), payload)).id;
      }
      await setDoc(doc(sessionsRef(), sessionId), payload, { merge: true });
      return sessionId;
    } catch (e) {
      Logger.e('[StudyHistory] save failed', e);
      return sessionId;
    }
  },

  async listSessions(max = 30): Promise<StudySession[]> {
    try {
      const snap = await getDocs(query(sessionsRef(), orderBy('updatedAt', 'desc'), limit(max)));
      return snap.docs.map(fromDoc);
    } catch {
      try {
        const snap = await getDocs(query(sessionsRef(), orderBy('createdAt', 'desc'), limit(max)));
        return snap.docs.map(fromDoc).sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
      } catch (e2) {
        Logger.e('[StudyHistory] list failed', e2);
        return [];
      }
    }
  },

  async loadSession(sessionId: string): Promise<StudySession | null> {
    try {
      const snap = await getDoc(doc(sessionsRef(), sessionId));
      if (!snap.exists()) return null;
      return fromDoc(snap);
    } catch (e) {
      Logger.e('[StudyHistory] load failed', e);
      return null;
    }
  },

  async deleteSession(sessionId: string): Promise<void> {
    try {
      await deleteDoc(doc(sessionsRef(), sessionId));
    } catch (e) {
      Logger.e('[StudyHistory] delete failed', e);
      throw e;
    }
  },
};
