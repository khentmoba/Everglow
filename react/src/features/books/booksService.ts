import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  type DocumentData,
  type DocumentSnapshot,
  type QuerySnapshot,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { auth, db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { Prefs } from '../../core/system/prefs';
import { Changes, just, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';
import {
  buildReadCandidates,
  isKhent,
  type BookItem,
  type BookSearchResult,
  type OurBooksItem,
} from './bookTypes';
import type { ReaderBookmark, ReaderHighlight, ReaderProgress } from './readerPrefs';

const CATALOG_PROXY = 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyCatalog';
const BOOK_TEXT_PROXY = 'https://everglow-1c6db.web.app/api/proxyBookText';
const OL_FIELDS = 'key,title,author_name,cover_i,cover_edition_key,first_publish_year,ia,subject,publisher,isbn,language,ratings_average,ratings_count';

let lastCatalogFailure = 0;
/** True when a catalogue call failed recently, so an empty result can show a retry instead of "no results". */
export const catalogFailedRecently = (withinMs = 20000): boolean => Date.now() - lastCatalogFailure < withinMs;
export const catalogFailureAt = (): number => lastCatalogFailure;

async function catalogGet(source: 'openlibrary' | 'gutendex' | 'archive', path: string, params?: Record<string, string>): Promise<Record<string, unknown> | null> {
  const user = auth.currentUser;
  const rawQuery = params && Object.keys(params).length ? `?${new URLSearchParams(params).toString()}` : '';
  const url = `${CATALOG_PROXY}?${new URLSearchParams({ base: source, path: `${path}${rawQuery}` }).toString()}`;
  try {
    const token = user ? await user.getIdToken().catch(() => null) : null;
    const headers: Record<string, string> = { Accept: 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) };
    const resp = await fetch(url, { headers, signal: AbortSignal.timeout(12000) });
    if (!resp.ok) {
      lastCatalogFailure = Date.now();
      return null;
    }
    const data = (await resp.json()) as Record<string, unknown>;
    lastCatalogFailure = 0;
    return data;
  } catch (e) {
    Logger.w(`Catalog proxy failed (${source}/${path}): ${String(e)}`);
    lastCatalogFailure = Date.now();
    return null;
  }
}

const GUTENDEX_LANG: Record<string, string> = { eng: 'en', spa: 'es', fre: 'fr', ger: 'de', chi: 'zh', jpn: 'ja' };

function mapOlDoc(d: Record<string, unknown>): BookSearchResult {
  const workKey = String(d.key ?? '');
  const title = String(d.title ?? '');
  const authors = Array.isArray(d.author_name) ? d.author_name.map(String) : [];
  const coverId = typeof d.cover_i === 'number' ? d.cover_i : 0;
  const coverOlid = typeof d.cover_edition_key === 'string' ? d.cover_edition_key : '';
  const coverUrl =
    coverId > 0
      ? `https://covers.openlibrary.org/b/id/${coverId}-M.jpg`
      : coverOlid
        ? `https://covers.openlibrary.org/b/olid/${coverOlid}-M.jpg`
        : '';
  const yr = Number(d.first_publish_year ?? 0);
  const year = yr >= 1400 && yr <= new Date().getFullYear() + 1 ? String(yr) : '';
  const iaList = Array.isArray(d.ia) ? d.ia.map(String) : [];
  const iaId = iaList[0] ?? '';
  const subjects = Array.isArray(d.subject) ? d.subject.slice(0, 8).map(String) : [];
  const pubs = Array.isArray(d.publisher) ? d.publisher.map(String) : [];
  const isbns = Array.isArray(d.isbn) ? d.isbn.map(String) : [];
  const langs = Array.isArray(d.language) ? d.language.map(String) : [];
  const ratingAvg = Number(d.ratings_average ?? 0);
  const ratingsCount = Number(d.ratings_count ?? 0);
  return {
    rating: ratingAvg > 0 ? ratingAvg : undefined,
    ratingsCount: ratingsCount > 0 ? ratingsCount : undefined,
    title,
    author: (() => {
      const raw = authors[0] ?? '';
      const parts = raw.split(',').map((s) => s.trim()).filter(Boolean);
      return parts.length === 2 ? `${parts[1]} ${parts[0]}` : raw;
    })(),
    coverUrl,
    year,
    language: langs[0] ?? '',
    publisher: pubs[0] ?? '',
    pageCount: 0,
    filetype: '',
    description: '',
    subjects,
    isbn: isbns[0] ?? '',
    isbn13: isbns.find((x) => x.length === 13) ?? '',
    categories: subjects.slice(0, 3),
    sourceLabel: iaId.startsWith('pg') ? 'Project Gutenberg' : iaId ? 'Internet Archive' : 'Open Library',
    workKey,
    iaId,
    gutenbergId: 0,
    downloadUrls: {},
    readCandidates: buildReadCandidates({ readSourceUrl: '', iaId, workKey }),
  };
}

function mapGutendexBook(b: Record<string, unknown>): BookSearchResult {
  const id = Number(b.id ?? 0);
  const title = String(b.title ?? '');
  const authors = Array.isArray(b.authors) ? (b.authors as { name?: string }[]).map((a) => String(a.name ?? '')).filter(Boolean) : [];
  const formats = (b.formats as Record<string, string> | undefined) ?? {};
  const coverUrl = formats['image/jpeg'] ?? '';
  const downloadUrls: Record<string, string> = {};
  if (formats['application/epub+zip']) downloadUrls.epub = formats['application/epub+zip'];
  const txt = formats['text/plain; charset=utf-8'] ?? formats['text/plain; charset=us-ascii'] ?? formats['text/plain'];
  if (txt) downloadUrls.txt = txt;
  const subjects = Array.isArray(b.subjects)
    ? b.subjects.map((x) => String(x).replace(/\s*--\s*/g, ' · ')).filter((x) => x.trim() !== '').slice(0, 8)
    : [];
  const downloads = Number(b.download_count ?? 0);
  return {
    ratingCount: downloads > 0 ? downloads : undefined,
    title,
    author: authors[0] ?? '',
    coverUrl,
    year: '',
    language: Array.isArray(b.languages) ? String(b.languages[0] ?? '') : '',
    publisher: 'Project Gutenberg',
    pageCount: 0,
    filetype: downloadUrls.epub ? 'epub' : downloadUrls.txt ? 'txt' : '',
    description: '',
    subjects,
    isbn: '',
    isbn13: '',
    categories: subjects.slice(0, 3),
    sourceLabel: 'Project Gutenberg',
    workKey: `pg:${id}`,
    iaId: `pg${id}`,
    gutenbergId: id,
    downloadUrls,
    readCandidates: buildReadCandidates({ readSourceUrl: txt ?? '', iaId: `pg${id}`, workKey: `pg:${id}` }),
  };
}

function demoBooks(limitCount: number): BookSearchResult[] {
  const docs = [
    { key: '/works/demo0', title: 'Frankenstein', author_name: ['Mary Shelley'], first_publish_year: 1818, ia: ['pg84'], subject: ['Gothic'] },
    { key: '/works/demo1', title: 'The Night Garden', author_name: ['A. Lane'], first_publish_year: 2019, ia: ['demo1'], subject: ['Fantasy', 'Adventure'] },
    { key: '/works/demo2', title: 'Letters to Tomorrow', author_name: ['M. Rivera'], first_publish_year: 2021, ia: ['demo2'], subject: ['Romance', 'Literary Fiction'] },
    { key: '/works/demo3', title: 'The Quiet Observatory', author_name: ['S. Okafor'], first_publish_year: 2020, ia: ['demo3'], subject: ['Science Fiction'] },
    { key: '/works/demo4', title: 'A Map of Small Things', author_name: ['J. Bell'], first_publish_year: 2018, ia: ['demo4'], subject: ['Memoir'] },
    { key: '/works/demo5', title: 'Winter Light', author_name: ['K. Adeyemi'], first_publish_year: 2022, ia: ['demo5'], subject: ['Mystery'] },
  ];
  const blurbs: Record<string, string> = {
    '/works/demo0': 'A young scientist discovers the cost of playing God, in a story that still haunts readers two centuries later.',
    '/works/demo1': 'A quiet novel about grief, greenhouses, and the people who grow things back from nothing.',
    '/works/demo2': 'Letters sent into the future carry a love that refuses to be left behind.',
    '/works/demo3': 'At the edge of the known sky, an observatory keeper listens for something that should not exist.',
    '/works/demo4': 'A tender map of ordinary things, and the lives tucked quietly inside them.',
    '/works/demo5': 'When the snows arrive, a small town remembers what it tried to forget.',
  };
  return docs.slice(0, limitCount).map((d) => ({ ...mapOlDoc(d), description: blurbs[d.key] ?? '' }));
}

// book_catalog_service.dart `_dedupeKey`.
function dedupeKey(r: BookSearchResult): string {
  const t = r.title.toLowerCase().trim().replace(/\s+/g, ' ');
  const a = r.author.toLowerCase().trim().replace(/\s+/g, ' ');
  return t ? `${t}|${a}` : '';
}

// `_merge`: first one wins its slot, later twins fill in what it lacks.
function mergeResults(results: BookSearchResult[]): BookSearchResult[] {
  const byKey = new Map<string, BookSearchResult>();
  for (const r of results) {
    const key = dedupeKey(r);
    if (!key) continue;
    const a = byKey.get(key);
    if (!a) {
      byKey.set(key, r);
      continue;
    }
    byKey.set(key, {
      ...a,
      isbn: a.isbn || r.isbn,
      isbn13: a.isbn13 || r.isbn13,
      categories: [...new Set([...a.categories, ...r.categories])],
      description: a.description || r.description,
      publisher: a.publisher || r.publisher,
      filetype: a.filetype || r.filetype,
      sizeMb: a.sizeMb ?? r.sizeMb,
      ratingCount: a.ratingCount ?? r.ratingCount,
      rating: a.rating ?? r.rating,
      ratingsCount: a.ratingsCount ?? r.ratingsCount,
      language: a.language || r.language,
      year: a.year || r.year,
      sourceLabel: a.sourceLabel || r.sourceLabel,
      gutenbergId: a.gutenbergId > 0 ? a.gutenbergId : r.gutenbergId,
      iaId: a.iaId || r.iaId,
      workKey: a.workKey || r.workKey,
      downloadUrls: { ...a.downloadUrls, ...r.downloadUrls },
      readCandidates: [...new Set([...a.readCandidates, ...r.readCandidates])],
    });
  }
  return [...byKey.values()];
}

function olDocs(data: Record<string, unknown> | null): BookSearchResult[] {
  return Array.isArray(data?.docs) ? (data.docs as Record<string, unknown>[]).filter((d) => typeof d.title === 'string' && d.title !== '').map(mapOlDoc) : [];
}

// BookCatalogService.mostPopular: Open Library "best" + Gutenberg's most
// downloaded, merged, then most downloaded first.
export async function fetchPopularBooks(limitCount = 12, offset = 0): Promise<BookSearchResult[]> {
  if (AgentMode.demo) return demoBooks(limitCount + offset).slice(offset);
  const [ol, gut] = await Promise.all([
    catalogGet('openlibrary', 'search.json', { subject: 'best', fields: OL_FIELDS, limit: String(Math.min(limitCount + offset, 100)), sort: 'trending' }),
    catalogGet('gutendex', 'books', { sort: 'popular' }),
  ]);
  const gutDocs = Array.isArray(gut?.results)
    ? (gut.results as Record<string, unknown>[]).slice(offset, offset + limitCount).map(mapGutendexBook).filter((x) => x.title)
    : [];
  const merged = mergeResults([...olDocs(ol), ...gutDocs]);
  merged.sort((a, b) => (b.ratingCount ?? 0) - (a.ratingCount ?? 0));
  return merged.slice(offset, offset + limitCount);
}

// OpenLibraryService.fetchRecent: trending works first published in the last
// six years, with covers; falls back to trending fiction.
export async function fetchRecentBooks(limitCount = 12, offset = 0): Promise<BookSearchResult[]> {
  if (AgentMode.demo) return demoBooks(limitCount + offset).slice(offset);
  const nowYear = new Date().getFullYear();
  const usable = (r: BookSearchResult) => r.coverUrl !== '' && r.workKey.endsWith('W');
  const data = await catalogGet('openlibrary', 'search.json', {
    q: `first_publish_year:[${nowYear - 6} TO ${nowYear}]`,
    sort: 'trending',
    fields: OL_FIELDS,
    limit: String(Math.min(Math.max(limitCount * 4 + offset, 1), 100)),
    ...(offset > 0 ? { offset: String(offset) } : {}),
  });
  const docs = Array.isArray(data?.docs)
    ? (data.docs as Record<string, unknown>[])
        .filter((d) => typeof d.title === 'string' && d.title !== '' && ((typeof d.key === 'string' && d.key !== '') || (Array.isArray(d.ia) && d.ia.length > 0)))
        .map(mapOlDoc)
    : [];
  const recent = docs.filter((r) => {
    const y = Number(r.year) || 0;
    return usable(r) && y >= 1500 && y <= nowYear + 1;
  });
  if (recent.length) return recent.slice(0, limitCount);
  const fiction = olDocs(await catalogGet('openlibrary', 'search.json', { subject: 'fiction', fields: OL_FIELDS, limit: String(limitCount * 2), sort: 'trending' }));
  const withCovers = fiction.filter(usable);
  if (withCovers.length) return withCovers.slice(0, limitCount);
  return olDocs(await catalogGet('openlibrary', 'search.json', { subject: 'fiction', fields: OL_FIELDS, limit: String(limitCount), sort: 'trending' }));
}

export async function fetchBooksBySubject(subject: string, limitCount = 24, offset = 0): Promise<BookSearchResult[]> {
  const data = await catalogGet('openlibrary', 'search.json', {
    subject,
    fields: OL_FIELDS,
    limit: String(limitCount),
    sort: 'trending',
    ...(offset > 0 ? { offset: String(offset) } : {}),
  });
  const docs = Array.isArray(data?.docs) ? (data.docs as Record<string, unknown>[]).map(mapOlDoc).filter((x) => x.title) : [];
  return docs;
}

export async function searchBooksCatalog(
  queryText: string,
  opts?: { filetype?: string; language?: string; title?: string; author?: string; isbn?: string; publisher?: string; offset?: number; limit?: number; sort?: 'relevant' | 'popular' | 'newest' },
): Promise<{ results: BookSearchResult[]; total: number }> {
  const q = queryText.trim();
  if (!q) return { results: [], total: 0 };
  if (AgentMode.demo) {
    const list = demoBooks(30).filter((r) => r.title.toLowerCase().includes(q.toLowerCase()) || r.author.toLowerCase().includes(q.toLowerCase()));
    return { results: list, total: list.length };
  }
  const lim = opts?.limit ?? 30;
  const off = opts?.offset ?? 0;
  const lang = opts?.language;
  const gutLang = lang ? GUTENDEX_LANG[lang] : undefined;
  const olSort = opts?.sort === 'newest' ? 'new' : opts?.sort === 'popular' ? 'rating' : undefined;

  const olParams: Record<string, string> = {
    q,
    fields: OL_FIELDS,
    limit: String(lim),
    ...(olSort ? { sort: olSort } : {}),
    ...(off > 0 ? { offset: String(off) } : {}),
    ...(lang ? { language: lang } : {}),
    ...(opts?.title ? { title: opts.title } : {}),
    ...(opts?.author ? { author: opts.author } : {}),
    ...(opts?.isbn ? { isbn: opts.isbn } : {}),
    ...(opts?.publisher ? { publisher: opts.publisher } : {}),
  };

  const [ol, gut] = await Promise.all([
    catalogGet('openlibrary', 'search.json', olParams),
    off === 0 ? catalogGet('gutendex', 'books', { search: q }) : Promise.resolve(null),
  ]);

  const olDocs = Array.isArray(ol?.docs) ? (ol.docs as Record<string, unknown>[]).map(mapOlDoc).filter((x) => x.title) : [];
  const gutRaw = Array.isArray(gut?.results) ? (gut.results as Record<string, unknown>[]) : [];
  const gutDocs = gutRaw
    .filter((b) => {
      if (!gutLang) return true;
      const langs = Array.isArray(b.languages) ? b.languages.map(String) : [];
      return langs.includes(gutLang);
    })
    .map(mapGutendexBook)
    .filter((x) => x.title);
  const total = Number(ol?.numFound ?? olDocs.length) + gutDocs.length;

  let merged = mergeResults([...olDocs, ...gutDocs]);
  if (opts?.filetype) {
    const format = opts.filetype.toLowerCase();
    merged = merged.filter((r) => Boolean(r.filetype) && r.filetype.toLowerCase() === format);
  }
  if (opts?.publisher) {
    const pub = opts.publisher.toLowerCase();
    merged = merged.filter((r) => r.publisher.toLowerCase().includes(pub));
  }
  if (opts?.isbn) {
    const isbn = opts.isbn.replace(/[^0-9Xx]/g, '');
    merged = merged.filter((r) => r.isbn.replace(/[^0-9Xx]/g, '').includes(isbn) || r.isbn13.replace(/[^0-9Xx]/g, '').includes(isbn));
  }
  return { results: merged, total };
}

/** Resolve a workKey from a deep link (e.g. /books/detail?workKey=pg:84) without router state. */
export async function resolveBookByWorkKey(workKey: string): Promise<BookSearchResult | null> {
  if (!workKey) return null;
  if (workKey.startsWith('pg:')) {
    const id = workKey.slice(3);
    const data = await catalogGet('gutendex', `books/${id}`);
    return data ? mapGutendexBook(data) : null;
  }
  if (workKey.startsWith('/works/')) {
    const data = await catalogGet('openlibrary', `${workKey.slice(1)}.json`);
    if (!data) return null;
    const coverId = Array.isArray(data.covers) ? Number(data.covers[0]) : 0;
    const desc = data.description;
    const subjects = Array.isArray(data.subjects) ? data.subjects.map(String).slice(0, 8) : [];
    const yr = Number(data.first_publish_year ?? 0);
    return {
      title: String(data.title ?? ''),
      author: '',
      coverUrl: coverId > 0 ? `https://covers.openlibrary.org/b/id/${coverId}-M.jpg` : '',
      year: yr >= 1400 && yr <= new Date().getFullYear() + 1 ? String(yr) : '',
      language: '',
      publisher: '',
      pageCount: 0,
      filetype: '',
      description: typeof desc === 'string' ? desc : String((desc as Record<string, unknown> | undefined)?.value ?? ''),
      subjects,
      isbn: '',
      isbn13: '',
      categories: subjects.slice(0, 3),
      sourceLabel: 'Open Library',
      workKey,
      iaId: '',
      gutenbergId: 0,
      downloadUrls: {},
      readCandidates: [],
    };
  }
  if (workKey.startsWith('ia:')) {
    const id = workKey.slice(3);
    const data = await catalogGet('archive', `metadata/${id}`);
    if (!data) return null;
    const meta = (data.metadata as Record<string, unknown> | undefined) ?? {};
    return {
      title: String(meta.title ?? id),
      author: String(meta.creator ?? ''),
      coverUrl: '',
      year: String(meta.year ?? ''),
      language: '',
      publisher: String(meta.publisher ?? ''),
      pageCount: 0,
      filetype: '',
      description: String(meta.description ?? ''),
      subjects: [],
      isbn: '',
      isbn13: '',
      categories: [],
      sourceLabel: 'Internet Archive',
      workKey,
      iaId: id,
      gutenbergId: 0,
      downloadUrls: {},
      readCandidates: buildReadCandidates({ readSourceUrl: '', iaId: id, workKey }),
    };
  }
  return null;
}

export async function fetchBookDetails(result: BookSearchResult): Promise<BookSearchResult> {
  if (result.workKey.startsWith('/works/')) {
    const clean = result.workKey.slice(1);
    const work = await catalogGet('openlibrary', `${clean}.json`);
    if (work) {
      const descRaw = work.description;
      const description =
        typeof descRaw === 'string'
          ? descRaw
          : typeof (descRaw as Record<string, unknown> | undefined)?.value === 'string'
            ? String((descRaw as Record<string, unknown>).value)
            : result.description;
      const subjects = Array.isArray(work.subjects) ? work.subjects.map(String).slice(0, 10) : result.subjects;
      return { ...result, description, subjects };
    }
  }
  if (result.iaId && !result.iaId.startsWith('pg')) {
    const meta = await catalogGet('archive', `metadata/${result.iaId}`);
    if (meta) {
      const m = (meta.metadata as Record<string, unknown> | undefined) ?? {};
      const files = Array.isArray(meta.files) ? (meta.files as Record<string, unknown>[]) : [];
      const downloadUrls: Record<string, string> = { ...result.downloadUrls };
      for (const f of files) {
        const name = String(f.name ?? '');
        const ext = name.split('.').pop()?.toLowerCase() ?? '';
        if (['epub', 'pdf', 'txt'].includes(ext) && !downloadUrls[ext]) {
          downloadUrls[ext] = `https://archive.org/download/${result.iaId}/${encodeURIComponent(name)}`;
        }
      }
      return {
        ...result,
        description: String(m.description ?? result.description),
        publisher: String(m.publisher ?? result.publisher),
        downloadUrls,
      };
    }
  }
  return result;
}

export async function fetchBookText(candidates: string[]): Promise<{ text: string; usedUrl: string; error?: string }> {
  if (!candidates.length) return { text: '', usedUrl: '', error: 'No read source URLs available.' };
  if (AgentMode.demo) {
    const demoText = [
      '*** START OF THE PROJECT GUTENBERG EBOOK FRANKENSTEIN ***',
      '',
      'CHAPTER I',
      'You will rejoice to hear that no disaster has accompanied the commencement of an enterprise which you have regarded with such evil forebodings.',
      '',
      'I arrived here yesterday, and my first task is to assure my dear sister of my welfare and increasing confidence in the success of my undertaking.',
      '',
      'CHAPTER II',
      'I am already far north of London, and as I walk in the streets of Petersburgh, I feel a cold northern breeze play upon my cheeks, which braces my nerves and fills me with delight.',
      '',
      'Do you understand this feeling? This breeze, which has travelled from the regions towards which I am advancing, gives me a foretaste of those icy climes.',
      '',
      '*** END OF THE PROJECT GUTENBERG EBOOK FRANKENSTEIN ***',
    ].join('\n');
    return { text: demoText, usedUrl: 'demo://frankenstein' };
  }
  try {
    const token = auth.currentUser ? await auth.currentUser.getIdToken().catch(() => '') : '';
    const resp = await fetch(BOOK_TEXT_PROXY, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({ urls: candidates }),
      signal: AbortSignal.timeout(20000),
    });
    if (resp.ok) {
      const data = (await resp.json()) as { text?: string; usedUrl?: string; error?: string };
      if (data.text) {
        const cacheKey = `book_text::${data.usedUrl ?? candidates[0]}`;
        Prefs.set(cacheKey, { text: data.text, usedUrl: data.usedUrl ?? candidates[0] });
        return { text: data.text, usedUrl: data.usedUrl ?? '' };
      }
      return { text: '', usedUrl: '', error: data.error || 'Proxy returned empty response.' };
    }
  } catch (e) {
    Logger.w(`proxyBookText failed: ${String(e)}`);
  }
  for (const url of candidates) {
    const cached = Prefs.get(`book_text::${url}`);
    if (cached && typeof cached === 'object' && typeof (cached as { text?: unknown }).text === 'string') {
      return { text: (cached as { text: string }).text, usedUrl: url };
    }
  }
  return { text: '', usedUrl: '', error: 'We couldn’t load the text right now.' };
}

// ---------- User Book Library & Our Books (Firestore + Agent Mode) ----------

const demoReadlist = new Map<string, BookItem[]>();
const demoFavorites = new Map<string, BookItem[]>();
const demoDownloads = new Map<string, BookItem[]>();
const demoBookChanges = new Changes<number>(() => Date.now());

let demoOurBooks: OurBooksItem[] = [
  {
    id: 'demo_book',
    workKey: '/works/demo',
    editionKey: '',
    iaId: '',
    title: 'A fictional reading adventure',
    author: '',
    coverUrl: '',
    year: '',
    subjects: [],
    addedBy: 'khentsgdz',
    addedAt: new Date(2026, 1, 14),
  },
];
const demoOurBooksChanges = new Changes<OurBooksItem[]>(() => [...demoOurBooks]);

function bookFromDoc(data: Record<string, unknown>, id: string): BookItem {
  const ts = data.addedAt as Timestamp | undefined;
  return {
    id,
    workKey: String(data.workKey ?? ''),
    editionKey: String(data.editionKey ?? ''),
    iaId: String(data.iaId ?? ''),
    title: String(data.title ?? ''),
    author: String(data.author ?? ''),
    coverUrl: String(data.coverUrl ?? ''),
    year: String(data.year ?? ''),
    publisher: String(data.publisher ?? ''),
    isbn: String(data.isbn ?? ''),
    pageCount: Number(data.pageCount ?? 0) || 0,
    subjects: Array.isArray(data.subjects) ? data.subjects.map(String) : [],
    status: String(data.status ?? ''),
    userName: String(data.userName ?? ''),
    addedAt: ts?.toDate ? ts.toDate() : new Date(),
    readSourceUrl: String(data.readSourceUrl ?? ''),
    readSourceLabel: String(data.readSourceLabel ?? ''),
  };
}

function watchUserBookCol(colName: string, userName: string, demoStore: Map<string, BookItem[]>): Source<BookItem[]> {
  if (!userName) {
    return (l) => {
      queueMicrotask(() => l.data([]));
      return () => {};
    };
  }
  if (AgentMode.demo) {
    return (l) =>
      demoBookChanges.source({
        data: () => l.data(demoStore.get(userName) ?? []),
      });
  }
  const q = query(collection(db, colName), where('userName', '==', userName), limit(500));
  return withFirestoreTimeout(
    snapshots<QuerySnapshot<DocumentData>, BookItem[]>(
      (next, err) => onSnapshot(q, next, err),
      (s) => s.docs.map((d) => bookFromDoc(d.data(), d.id)).sort((a, b) => b.addedAt.getTime() - a.addedAt.getTime()),
    ),
    { label: `${colName}-${userName}` },
  );
}

export const watchReadList = (u: string) => watchUserBookCol('read_list', u, demoReadlist);
export const watchBookFavorites = (u: string) => watchUserBookCol('book_favorites', u, demoFavorites);
export const watchBookDownloads = (u: string) => watchUserBookCol('book_download_history', u, demoDownloads);

export interface SyncedReaderState {
  progress: ReaderProgress | null;
  bookmarks: ReaderBookmark[];
  highlights: ReaderHighlight[];
}

const EMPTY_READER_STATE: SyncedReaderState = { progress: null, bookmarks: [], highlights: [] };
const READER_STATE_COL = 'reader_state';
const readerStateId = (userName: string, workKey: string) => `${encodeURIComponent(userName)}__${encodeURIComponent(workKey)}`;

function mapReaderState(data: Record<string, unknown> | undefined): SyncedReaderState {
  if (!data) return EMPTY_READER_STATE;
  return {
    progress: (data.progress as ReaderProgress) ?? null,
    bookmarks: Array.isArray(data.bookmarks) ? (data.bookmarks as ReaderBookmark[]) : [],
    highlights: Array.isArray(data.highlights) ? (data.highlights as ReaderHighlight[]) : [],
  };
}

/** Reading position and marks follow the couple across phone and tablet. */
export function watchReaderState(userName: string, workKey: string): Source<SyncedReaderState> {
  if (!userName || !workKey || AgentMode.demo) return just(EMPTY_READER_STATE);
  return withFirestoreTimeout(
    (l) =>
      onSnapshot(
        doc(db, READER_STATE_COL, readerStateId(userName, workKey)),
        (snap) => l.data(mapReaderState(snap.data())),
        (e) => l.error?.(e),
      ),
    { label: 'reader-state' },
  );
}

/** A single goal shared by both partners, stored for the couple rather than per device. */
export function watchCoupleGoal(): Source<number> {
  if (AgentMode.demo) return just(12);
  return withFirestoreTimeout(
    snapshots<DocumentSnapshot, number>(
      (next, err) => onSnapshot(doc(db, 'couple_prefs', 'main'), next, err),
      (s) => {
        const value = Number(s.data()?.goal ?? 12);
        return Number.isFinite(value) && value > 0 ? value : 12;
      },
    ),
    { label: 'couple-goal' },
  );
}

export async function saveCoupleGoal(goal: number): Promise<void> {
  if (AgentMode.demo) return;
  try {
    await setDoc(doc(db, 'couple_prefs', 'main'), { goal }, { merge: true });
  } catch (e) {
    Logger.w(`saveCoupleGoal failed: ${String(e)}`);
  }
}

/** All recent reading states for the couple, newest first — feeds Home's Continue Reading. */
export function watchAllReaderProgress(limitCount = 20): Source<ReaderProgress[]> {
  if (AgentMode.demo) return just([]);
  return withFirestoreTimeout(
    snapshots<QuerySnapshot<DocumentData>, ReaderProgress[]>(
      (next, err) => onSnapshot(query(collection(db, READER_STATE_COL), orderBy('updatedAt', 'desc'), limit(limitCount)), next, err),
      (s) =>
        s.docs
          .map((d) => (d.data().progress as ReaderProgress | undefined))
          .filter((p): p is ReaderProgress => Boolean(p?.title && p?.workKey))
          .slice(0, limitCount),
    ),
    { label: 'all-reader-state' },
  );
}

export async function saveReaderState(userName: string, workKey: string, state: SyncedReaderState): Promise<void> {
  if (!userName || !workKey || AgentMode.demo) return;
  try {
    await setDoc(
      doc(db, READER_STATE_COL, readerStateId(userName, workKey)),
      { ...state, userName, workKey, updatedAt: Date.now() },
      { merge: true },
    );
  } catch (e) {
    Logger.w(`saveReaderState failed: ${String(e)}`);
  }
}

export async function saveToReadList(item: BookItem, status: string, userName: string): Promise<void> {
  if (!userName) return;
  if (AgentMode.demo) {
    const prev = demoReadlist.get(userName) ?? [];
    const idx = prev.findIndex((b) => b.workKey === item.workKey);
    const updated: BookItem = { ...item, status, userName, addedAt: new Date() };
    const next = [...prev];
    if (idx >= 0) next[idx] = updated;
    else next.unshift(updated);
    demoReadlist.set(userName, next);
    demoBookChanges.emit();
    return;
  }
  const col = collection(db, 'read_list');
  const existing = await getDocs(query(col, where('workKey', '==', item.workKey), where('userName', '==', userName), limit(1)));
  if (existing.docs.length > 0) {
    await updateDoc(existing.docs[0].ref, { status, addedAt: serverTimestamp() });
  } else {
    await addDoc(col, {
      workKey: item.workKey,
      editionKey: item.editionKey,
      iaId: item.iaId,
      title: item.title,
      author: item.author,
      coverUrl: item.coverUrl,
      year: item.year,
      publisher: item.publisher,
      isbn: item.isbn,
      pageCount: item.pageCount,
      subjects: item.subjects,
      status,
      userName,
      readSourceUrl: item.readSourceUrl,
      readSourceLabel: item.readSourceLabel,
      addedAt: serverTimestamp(),
    });
  }
}

export async function removeFromReadList(workKey: string, userName: string): Promise<void> {
  if (!userName || !workKey) return;
  if (AgentMode.demo) {
    demoReadlist.set(userName, (demoReadlist.get(userName) ?? []).filter((b) => b.workKey !== workKey));
    demoBookChanges.emit();
    return;
  }
  const existing = await getDocs(query(collection(db, 'read_list'), where('workKey', '==', workKey), where('userName', '==', userName), limit(10)));
  for (const d of existing.docs) await deleteDoc(d.ref);
}

export async function toggleBookFavorite(item: BookItem, userName: string, add: boolean): Promise<void> {
  if (!userName) return;
  if (AgentMode.demo) {
    const prev = demoFavorites.get(userName) ?? [];
    demoFavorites.set(
      userName,
      add
        ? prev.some((x) => x.workKey === item.workKey) ? prev : [{ ...item, status: 'favorite', userName, addedAt: new Date() }, ...prev]
        : prev.filter((x) => x.workKey !== item.workKey),
    );
    demoBookChanges.emit();
    return;
  }
  const col = collection(db, 'book_favorites');
  const existing = await getDocs(query(col, where('workKey', '==', item.workKey), where('userName', '==', userName), limit(1)));
  if (add && existing.docs.length === 0) {
    await addDoc(col, {
      workKey: item.workKey,
      iaId: item.iaId,
      title: item.title,
      author: item.author,
      coverUrl: item.coverUrl,
      year: item.year,
      status: 'favorite',
      userName,
      addedAt: serverTimestamp(),
    });
  } else if (!add) {
    for (const d of existing.docs) await deleteDoc(d.ref);
  }
}

export async function recordBookDownload(item: BookItem, format: string, userName: string): Promise<void> {
  if (!userName || !item.workKey) return;
  if (AgentMode.demo) {
    const prev = demoDownloads.get(userName) ?? [];
    const entry: BookItem = { ...item, status: 'downloaded', userName, addedAt: new Date() };
    demoDownloads.set(userName, [entry, ...prev.filter((x) => x.workKey !== item.workKey)]);
    demoBookChanges.emit();
    return;
  }
  try {
    const col = collection(db, 'book_download_history');
    const existing = await getDocs(
      query(col, where('workKey', '==', item.workKey), where('userName', '==', userName), where('format', '==', format), limit(1)),
    );
    if (existing.docs.length > 0) {
      await updateDoc(existing.docs[0].ref, { addedAt: serverTimestamp() });
      return;
    }
    await addDoc(col, {
      workKey: item.workKey,
      editionKey: item.editionKey,
      iaId: item.iaId,
      title: item.title,
      author: item.author,
      coverUrl: item.coverUrl,
      year: item.year,
      publisher: item.publisher,
      isbn: item.isbn,
      pageCount: item.pageCount,
      subjects: item.subjects,
      format,
      status: 'downloaded',
      userName,
      readSourceUrl: item.readSourceUrl,
      readSourceLabel: item.readSourceLabel,
      addedAt: serverTimestamp(),
    });
  } catch (e) {
    Logger.w(`recordBookDownload failed: ${String(e)}`);
  }
}

export function watchOurBooks(limitCount = 300): Source<OurBooksItem[]> {
  if (AgentMode.demo) {
    return (l) =>
      demoOurBooksChanges.source({
        data: (list) => l.data(list.slice(0, limitCount)),
      });
  }
  const q = query(collection(db, 'our_books'), orderBy('addedAt', 'desc'), limit(limitCount));
  return withFirestoreTimeout(
    snapshots<QuerySnapshot<DocumentData>, OurBooksItem[]>(
      (next, err) => onSnapshot(q, next, err),
      (s) =>
        s.docs.map((d) => {
          const data = d.data();
          const tsAdded = data.addedAt as Timestamp | undefined;
          const tsK = data.khentReadAt as Timestamp | undefined;
          const tsC = data.clairReadAt as Timestamp | undefined;
          return {
            id: d.id,
            workKey: String(data.workKey ?? ''),
            editionKey: String(data.editionKey ?? ''),
            iaId: String(data.iaId ?? ''),
            title: String(data.title ?? ''),
            author: String(data.author ?? ''),
            coverUrl: String(data.coverUrl ?? ''),
            year: String(data.year ?? ''),
            subjects: Array.isArray(data.subjects) ? data.subjects.map(String) : [],
            addedBy: String(data.addedBy ?? ''),
            addedAt: tsAdded?.toDate ? tsAdded.toDate() : new Date(),
            sourceLabel: String(data.sourceLabel ?? ''),
            khentReadAt: tsK?.toDate ? tsK.toDate() : undefined,
            clairReadAt: tsC?.toDate ? tsC.toDate() : undefined,
          };
        }),
    ),
    { label: 'our-books' },
  );
}

export async function addToOurBooks(item: BookItem, addedBy: string): Promise<void> {
  if (AgentMode.demo) {
    if (!demoOurBooks.some((b) => b.workKey === item.workKey)) {
      demoOurBooks = [
        {
          id: `demo_${Date.now()}`,
          workKey: item.workKey,
          editionKey: item.editionKey,
          iaId: item.iaId,
          title: item.title,
          author: item.author,
          coverUrl: item.coverUrl,
          year: item.year,
          subjects: item.subjects,
          addedBy,
          addedAt: new Date(),
          sourceLabel: item.readSourceLabel,
        },
        ...demoOurBooks,
      ];
      demoOurBooksChanges.emit();
    }
    return;
  }
  const key = item.workKey || `ia:${item.iaId}`;
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(key));
  const docId = Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('');
  const ref = doc(db, 'our_books', docId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) {
      tx.set(ref, {
        workKey: key,
        editionKey: item.editionKey,
        iaId: item.iaId,
        title: item.title,
        author: item.author,
        coverUrl: item.coverUrl,
        year: item.year,
        subjects: item.subjects,
        addedBy,
        addedAt: serverTimestamp(),
        sourceLabel: item.readSourceLabel,
      });
    }
  });
}

export async function setOurBookReadFlag(workKey: string, userName: string, read: boolean): Promise<void> {
  if (AgentMode.demo) {
    demoOurBooks = demoOurBooks.map((b) =>
      b.workKey === workKey
        ? {
            ...b,
            ...(isKhent(userName)
              ? { khentReadAt: read ? new Date() : undefined }
              : { clairReadAt: read ? new Date() : undefined }),
          }
        : b,
    );
    demoOurBooksChanges.emit();
    return;
  }
  const snap = await getDocs(query(collection(db, 'our_books'), where('workKey', '==', workKey), limit(1)));
  if (!snap.docs.length) return;
  const field = isKhent(userName) ? 'khentReadAt' : 'clairReadAt';
  await updateDoc(snap.docs[0].ref, { [field]: read ? serverTimestamp() : null });
}

export async function removeFromOurBooks(workKey: string): Promise<void> {
  if (AgentMode.demo) {
    demoOurBooks = demoOurBooks.filter((b) => b.workKey !== workKey);
    demoOurBooksChanges.emit();
    return;
  }
  const snap = await getDocs(query(collection(db, 'our_books'), where('workKey', '==', workKey), limit(1)));
  for (const d of snap.docs) await deleteDoc(d.ref);
}
