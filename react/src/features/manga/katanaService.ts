import {
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  limit,
  onSnapshot,
  query,
  setDoc,
  Timestamp,
  where,
  type DocumentData,
  type QuerySnapshot,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { ConnectivityService } from '../../core/network/connectivity';
import { fetchFallbackChapterPages } from './mangaFallbackProviders';
import { auth, db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { Changes, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

const BASE_URL = 'https://mangakatana.com';
const PROXY_HTML_URL = 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyFetchHtml';
const PROXY_IMAGE_URL = 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaKatana';

export interface KatanaGenre {
  slug: string;
  name: string;
  count: number;
  description: string;
}

export interface KatanaChapter {
  id: string;
  num: string;
  title: string;
  updateAt?: Date;
  isNew?: boolean;
}

export interface KatanaManga {
  slug: string;
  id: string;
  title: string;
  coverUrl: string;
  status: string;
  updateText: string;
  summary: string;
  genres: KatanaGenre[];
  latestChapter?: KatanaChapter;
  recentChapters: KatanaChapter[];
  altNames: string[];
  authors: string[];
  artists: string[];
  chapters: KatanaChapter[];
  updateAt?: Date;
}

export interface KatanaBookmark {
  slug: string;
  title: string;
  coverUrl: string;
  status: string;
  addedAt: Date;
  lastReadChapterId: string;
  lastReadPage: number;
  lastReadChapterTitle: string;
  latestChapterTitle: string;
  recommendedBy: string;
  recommendationNote: string;
  readChapterIds: string[];
  bookmarked: boolean;
  /** Set once the reader reaches the last page of the final chapter of a completed series. */
  finishedAt?: Date;
}

export interface KatanaPageResult {
  items: KatanaManga[];
  page: number;
  hasNext: boolean;
  hasPrev: boolean;
}

export interface KatanaHomeData {
  hotUpdates: KatanaManga[];
  latest: KatanaManga[];
  hot: KatanaManga[];
  genres: KatanaGenre[];
}

export function katanaChapterNumFromId(id: string): string {
  if (id === 'fc') return '';
  const lower = id.toLowerCase();
  const cIdx = lower.lastIndexOf('c');
  if (cIdx < 0 || cIdx === lower.length - 1) return '';
  return lower.slice(cIdx + 1);
}

export function chapterDisplayTitle(c: KatanaChapter): string {
  if (c.title) return c.title;
  if (c.num) return `Chapter ${c.num}`;
  return 'Chapter';
}

export function proxyKatanaImageUrl(url: string): string {
  if (!url) return '';
  let u = url;
  if (u.toLowerCase().includes('mangakatana')) u = u.replace(/\.avif(?=$|[?&#])/gi, '.webp');
  if (u.includes('proxyMangaKatana')) return u;
  try {
    const host = new URL(u).host.toLowerCase();
    const proxied =
      host === 'mangakatana.com' ||
      host.endsWith('.mangakatana.com') ||
      host.endsWith('.mangakakalot.com') ||
      host.endsWith('.mkklcdnv6temp.com') ||
      host.endsWith('.catmanga.org');
    return proxied ? `${PROXY_IMAGE_URL}?url=${encodeURIComponent(u)}` : u;
  } catch {
    return u;
  }
}

const CDN_HOSTS = ['i1', 'i6', 'i7', 'i5', 'i2'];
export function katanaCdnFallback(url: string, step: number): string {
  if (step <= 0) return url;
  try {
    const parsed = new URL(url);
    const m = /^(i\d+)\./.exec(parsed.host);
    if (!m) return url;
    const others = CDN_HOSTS.filter((h) => h !== m[1]);
    if (step > others.length) return url;
    return url.replace(`${m[1]}.`, `${others[step - 1]}.`);
  } catch {
    return url;
  }
}

async function fetchHtml(url: string, cookie = ''): Promise<string | null> {
  const user = auth.currentUser;
  let proxyUrl = `${PROXY_HTML_URL}?url=${encodeURIComponent(url)}`;
  if (cookie) proxyUrl += `&cookie=${encodeURIComponent(cookie)}`;
  try {
    const token = user ? await user.getIdToken().catch(() => null) : null;
    const headers: Record<string, string> = token ? { Authorization: `Bearer ${token}` } : {};
    const res = await fetch(proxyUrl, { headers, signal: AbortSignal.timeout(9000) });
    if (!res.ok) return null;
    return (await res.text()) || null;
  } catch (e) {
    Logger.w(`KatanaService fetch failed: ${url} (${String(e)})`);
    return null;
  }
}

function unescapeHtml(raw: string): string {
  return new DOMParser().parseFromString(raw, 'text/html').documentElement.textContent ?? '';
}

function cleanText(raw: string): string {
  return unescapeHtml(raw.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim());
}

function extractCover(block: string): string {
  const m =
    /<source [^>]*srcset="((?:https?:)?\/\/[^"\s]+)"/.exec(block) ??
    /<img [^>]*src="((?:https?:)?\/\/[^"]+)"/.exec(block) ??
    /<img [^>]*data-src="((?:https?:)?\/\/[^"]+)"/.exec(block);
  if (!m) return '';
  const url = m[1].startsWith('//') ? `https:${m[1]}` : m[1];
  return proxyKatanaImageUrl(url);
}

/** Every `<div class="cls" ...>` block (balanced on nested divs) in [start, end). */
function blocksOfClass(html: string, cls: string, start = 0, end = -1): string[] {
  const out: string[] = [];
  const open = `<div class="${cls}"`;
  let at = html.indexOf(open, start);
  while (at >= 0 && !(end >= 0 && at >= end)) {
    const first = html.indexOf('<div', at);
    let depth = 0;
    let cursor = first;
    let close = -1;
    while (cursor < html.length) {
      const nextOpen = html.indexOf('<div', cursor);
      const nextClose = html.indexOf('</div>', cursor);
      if (nextClose < 0) break;
      if (nextOpen >= 0 && nextOpen < nextClose) {
        depth++;
        cursor = nextOpen + 4;
      } else {
        depth--;
        cursor = nextClose + 6;
        if (depth === 0) {
          close = cursor;
          break;
        }
      }
    }
    if (close < 0) break;
    out.push(html.slice(at, close));
    at = html.indexOf(open, close);
  }
  return out;
}

const CH_PAT = '(?:v\\d+)?c[^"/]+|fc';

const katanaMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** `Nov-10-2026` becomes local midnight of that day, like `_parseKatanaDate`. */
export function parseKatanaDate(raw: string): Date | undefined {
  const m = /(\w{3})-(\d{1,2})-(\d{4})/.exec(raw);
  if (!m) return undefined;
  const month = katanaMonths.indexOf(m[1]);
  if (month < 0) return undefined;
  return new Date(Number(m[3]), month, Number(m[2]));
}

/** Port of `formatKatanaTime`: relative for the last week, then `Mon-DD-YYYY`. */
export function formatKatanaTime(time?: Date): string {
  if (!time) return '';
  const seconds = Math.trunc((Date.now() - time.getTime()) / 1000);
  if (seconds < 60) return 'just now';
  const minutes = Math.trunc(seconds / 60);
  if (minutes < 60) return minutes === 1 ? '1 minute ago' : `${minutes} minutes ago`;
  const hours = Math.trunc(minutes / 60);
  if (hours < 24) return hours === 1 ? '1 hour ago' : `${hours} hours ago`;
  const days = Math.trunc(hours / 24);
  if (days < 7) return days === 1 ? '1 day ago' : `${days} days ago`;
  return `${katanaMonths[time.getMonth()]}-${String(time.getDate()).padStart(2, '0')}-${time.getFullYear()}`;
}

function parseExpandedItem(block: string): KatanaManga | null {
  const hrefM = /href="https:\/\/mangakatana\.com\/manga\/([^"/]+)"/.exec(block);
  if (!hrefM) return null;
  const slug = hrefM[1];
  const idM = /data-id="(\d+)"/.exec(block);
  const statusM = /class="status (ongoing|completed)"/.exec(block);
  const titleM = /<h3 class="title">.*?<a[^>]*href="[^"]*manga\/[^"]+"[^>]*>([^<]+)<\/a>/s.exec(block);
  const dateM = /<div class="date">.*?<\/div>/s.exec(block);
  const sumM = /<div class="summary[^"]*">(.*?)<\/div>/s.exec(block);

  const genres: KatanaGenre[] = [];
  const gRe = /href="https:\/\/mangakatana\.com\/genre\/([a-z0-9-]+)"[^>]*>([^<]+)<\/a>/g;
  let gm: RegExpExecArray | null;
  while ((gm = gRe.exec(block))) {
    genres.push({ slug: gm[1], name: unescapeHtml(gm[2].trim()), count: 0, description: '' });
  }

  const chRe = new RegExp(`<a href="https://mangakatana\\.com/manga/[^"]*/(${CH_PAT})"[^>]*>([^<]*)</a>`);
  const chM = chRe.exec(block);
  const latestChapter = chM
    ? { id: chM[1], num: katanaChapterNumFromId(chM[1]), title: unescapeHtml(chM[2].trim()) }
    : undefined;

  // Same as Flutter's `_reExpandedChapters`: a chapter only counts when its
  // update time sits next to it.
  const recentChapters: KatanaChapter[] = [];
  const recRe = new RegExp(
    `<div class="chapter"><a href="[^"]*/(${CH_PAT})"[^>]*>([^<]*)</a></div>` +
      String.raw`\s*</div>\s*<div class="uk-width-2-10"><div class="update_time">([^<]*)</div>`,
    'gs',
  );
  let rm: RegExpExecArray | null;
  while ((rm = recRe.exec(block))) {
    recentChapters.push({
      id: rm[1],
      num: katanaChapterNumFromId(rm[1]),
      title: unescapeHtml(rm[2].trim()),
      updateAt: parseKatanaDate(rm[3] ?? ''),
    });
  }

  return {
    slug,
    id: idM?.[1] ?? slug,
    title: titleM ? unescapeHtml(titleM[1].trim()) : slug,
    coverUrl: extractCover(block),
    status: statusM?.[1] ?? 'ongoing',
    updateText: dateM ? cleanText(dateM[0]) : '',
    summary: sumM ? cleanText(sumM[1]) : '',
    genres,
    latestChapter,
    recentChapters,
    altNames: [],
    authors: [],
    artists: [],
    chapters: [],
  };
}

function parseGenres(html: string): KatanaGenre[] {
  const map = new Map<string, KatanaGenre>();
  const chipRe = /href="https:\/\/mangakatana\.com\/genre\/([a-z0-9-]+)">([^<]+)<\/a> <span>\((\d+)\)<\/span>/g;
  let m: RegExpExecArray | null;
  while ((m = chipRe.exec(html))) {
    map.set(m[1], { slug: m[1], name: unescapeHtml(m[2].trim()), count: Number(m[3]) || 0, description: '' });
  }
  return Array.from(map.values()).sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
}

function items(blocks: string[]): KatanaManga[] {
  return blocks.map(parseExpandedItem).filter((m): m is KatanaManga => m != null);
}

export async function fetchKatanaHome(): Promise<KatanaHomeData> {
  const html = await fetchHtml(`${BASE_URL}/`);
  if (!html) return { hotUpdates: [], latest: [], hot: [], genres: [] };
  const hotIdx = html.indexOf('Hot Manga');
  const latestIdx = Math.max(0, html.indexOf('Latest Updates'));
  const latest = items(blocksOfClass(html, 'item', latestIdx, hotIdx < 0 ? -1 : hotIdx));
  const hot = hotIdx >= 0 ? items(blocksOfClass(html, 'item', hotIdx)) : [];
  const hotUpdateIdx = html.indexOf('id="hot_update"');
  const hotUpdateEnd = hotUpdateIdx >= 0 ? html.indexOf('id="wrap_content"', hotUpdateIdx) : -1;
  return {
    hotUpdates: hotUpdateIdx >= 0 ? items(blocksOfClass(html, 'item', hotUpdateIdx, hotUpdateEnd)) : [],
    latest,
    hot,
    genres: parseGenres(html),
  };
}

export async function fetchKatanaCatalog(opts: {
  mode?: string;
  page?: number;
  key?: string;
  query?: string;
  searchBy?: string;
  include?: string[];
  exclude?: string[];
  genreMode?: string;
  chapters?: string;
  orderBy?: string;
}): Promise<KatanaPageResult> {
  const page = opts.page ?? 1;
  const pagePath = page > 1 ? `/page/${page}` : '';
  let url: string;
  switch (opts.mode) {
    case 'latest':
      url = `${BASE_URL}/latest${pagePath}`;
      break;
    case 'new':
      url = `${BASE_URL}/new-manga${pagePath}`;
      break;
    case 'genre':
      url = `${BASE_URL}/genre/${opts.key ?? ''}${pagePath}`;
      break;
    case 'author':
      url = `${BASE_URL}/author/${opts.key ?? ''}${pagePath}`;
      break;
    case 'search': {
      const params = new URLSearchParams({ search: opts.query ?? '', search_by: opts.searchBy ?? 'm_name' });
      url = `${BASE_URL}${pagePath}?${params.toString()}`;
      break;
    }
    default:
      url = `${BASE_URL}/manga${pagePath}`;
      break;
  }
  if (opts.mode === 'directory' || opts.mode === 'genre' || opts.mode === 'author' || !opts.mode) {
    const params = new URLSearchParams({
      filter: '1',
      include: (opts.include ?? []).join(','),
      exclude: (opts.exclude ?? []).join('_'),
      genre_mode: opts.genreMode ?? 'and',
      chapters: opts.chapters ?? '1',
      order_by: opts.orderBy ?? 'latest',
    });
    url += `?${params.toString()}`;
  }
  const html = await fetchHtml(url);
  if (!html) return { items: [], page, hasNext: false, hasPrev: page > 1 };
  const blocks =
    opts.mode === 'search'
      ? (() => {
          const start = html.indexOf('Search results');
          const end = start >= 0 ? html.indexOf('widget-title', start + 20) : -1;
          return start >= 0 ? blocksOfClass(html, 'item', start, end) : [];
        })()
      : blocksOfClass(html, 'item');
  return {
    items: items(blocks),
    page,
    hasNext: html.includes('class="next page-numbers"'),
    hasPrev: page > 1 && html.includes('class="prev page-numbers"'),
  };
}

export async function fetchKatanaByType(type: string, page = 1): Promise<KatanaPageResult> {
  if (type === 'manga') return fetchKatanaCatalog({ mode: 'directory', page, exclude: ['manhwa', 'manhua'] });
  if (type === 'manhwa') return fetchKatanaCatalog({ mode: 'directory', page, include: ['manhwa'] });
  if (type === 'manhua') return fetchKatanaCatalog({ mode: 'directory', page, include: ['manhua'] });
  return fetchKatanaCatalog({ mode: 'directory', page });
}

export async function fetchKatanaSuggestions(queryText: string, searchBy = 'm_name'): Promise<KatanaManga[]> {
  if (queryText.trim().length < 3) return [];
  const res = await fetchKatanaCatalog({ mode: 'search', query: queryText.trim(), searchBy });
  return res.items.slice(0, 8);
}

export async function fetchKatanaDetail(slug: string): Promise<KatanaManga | null> {
  if (!slug) return null;
  const html = await fetchHtml(`${BASE_URL}/manga/${slug}`);
  if (!html) return null;
  const idM = /data-id="(\d+)"/.exec(html);
  const titleM = /<h1 class="heading">([^<]+)<\/h1>/.exec(html);
  const statusM = /class="d-cell-small value status (ongoing|completed)"/.exec(html);
  const updateM = /class="d-cell-small value updateAt">([^<]+)<\/div>/.exec(html);
  const altM =
    /<div class="d-cell-small label">Alt name\(s\):<\/div>\s*<div class="d-cell-small value"><div class="alt_name">([^<]+)<\/div>/s.exec(
      html,
    );
  const sumM = /<div class="summary">\s*<div class="label">Description<\/div>\s*<p>(.*?)<\/p>/s.exec(html);
  const altNames = altM
    ? unescapeHtml(altM[1].trim())
        .split(';')
        .map((s) => s.trim())
        .filter(Boolean)
    : [];

  const authors: string[] = [];
  const authorBlock = /<div class="d-cell-small label">Author\(s\) \/ Artist\(s\):<\/div>.*?<\/div>/s.exec(html);
  if (authorBlock) {
    const aRe = /<a class="author" href="[^"]*"[^>]*>([^<]+)<\/a>/g;
    let am: RegExpExecArray | null;
    while ((am = aRe.exec(authorBlock[0]))) authors.push(unescapeHtml(am[1].trim()));
  }

  const genres: KatanaGenre[] = [];
  const genreBlock = /<div class="d-cell-small label">Genres:<\/div>.*?<\/div>/s.exec(html)?.[0] ?? html;
  const gRe = /href="https:\/\/mangakatana\.com\/genre\/([a-z0-9-]+)"[^>]*>([^<]+)<\/a>/g;
  let gm: RegExpExecArray | null;
  while ((gm = gRe.exec(genreBlock))) {
    genres.push({ slug: gm[1], name: unescapeHtml(gm[2].trim()), count: 0, description: '' });
  }

  const chapters: KatanaChapter[] = [];
  const rowRe = /<tr data-jump="[^"]*">.*?<\/tr>/gs;
  const idRe = new RegExp(`href="https://mangakatana\\.com/manga/[^"]*/(${CH_PAT})"`);
  let row: RegExpExecArray | null;
  while ((row = rowRe.exec(html))) {
    const block = row[0];
    const idHit = idRe.exec(block);
    if (!idHit) continue;
    const titleHit = /<div class="chapter"><a[^>]*>([^<]*)<\/a>/.exec(block);
    chapters.push({
      id: idHit[1],
      num: katanaChapterNumFromId(idHit[1]),
      title: unescapeHtml(titleHit?.[1]?.trim() ?? `Chapter ${idHit[1]}`),
      isNew: block.includes('class="new"'),
    });
  }

  return {
    slug,
    id: idM?.[1] ?? slug,
    title: titleM ? unescapeHtml(titleM[1].trim()) : slug,
    coverUrl: extractCover(html),
    status: statusM?.[1] ?? 'ongoing',
    updateText: updateM?.[1]?.trim() ?? '',
    summary: sumM ? cleanText(sumM[1]) : '',
    genres,
    altNames,
    authors,
    artists: [],
    recentChapters: chapters.slice(0, 3),
    chapters,
  };
}

export async function fetchKatanaChapterPages(slug: string, chapterId: string, preferredServer = ''): Promise<string[]> {
  if (!slug || !chapterId || !ConnectivityService.isOnline) return [];
  const servers = [preferredServer, ...['', '?sv=mk', '?sv=3'].filter((s) => s !== preferredServer)];
  for (const server of servers) {
    const cookie = server === '?sv=mk' ? 's_r=sv2' : server === '?sv=3' ? 's_r=sv3' : '';
    const html = await fetchHtml(`${BASE_URL}/manga/${slug}/${chapterId}${server}`, cookie);
    if (!html) continue;
    for (const name of ['thzq', 'ytaw']) {
      const m = new RegExp(`var ${name}=\\[(.*?)\\];`, 's').exec(html);
      if (!m) continue;
      const pages = m[1]
        .split(',')
        .map((s) => s.trim().replace(/^'/, '').replace(/'$/, ''))
        .filter((s) => s.startsWith('http'));
      if (pages.length) return pages;
    }
  }
  // Multi-source fallback (MangaDex -> ComicK -> Bato -> Scanlation) when MangaKatana fails.
  const fallback = await fetchFallbackChapterPages(slug, chapterId);
  return fallback.pages;
}

const demoProgress = (
  slug: string,
  title: string,
  coverUrl: string,
  chapter: number,
  finishedAt?: Date,
): KatanaBookmark => ({
  slug,
  title,
  coverUrl,
  status: finishedAt ? 'completed' : 'ongoing',
  addedAt: new Date(2026, 1, 14),
  lastReadChapterId: `c${chapter}`,
  lastReadPage: 1,
  lastReadChapterTitle: `Chapter ${chapter}`,
  latestChapterTitle: '',
  recommendedBy: '',
  recommendationNote: '',
  readChapterIds: [`c${chapter}`],
  bookmarked: true,
  finishedAt,
});

// Agent mode keeps bookmarks in memory, per user, seeded with made-up reading progress.
const demoBookmarks = new Map<string, KatanaBookmark[]>([
  [
    'khentsgdz',
    [
      demoProgress('demo-starlight-manga', 'Fictional Starlight Manga', '/images/demo/poster-4.jpg', 42),
      demoProgress('demo-paper-moon', 'Demo Paper Moon', '/images/demo/poster-2.jpg', 120, new Date(2026, 2, 1)),
    ],
  ],
  [
    'clairjassen',
    [
      demoProgress('demo-starlight-manga', 'Fictional Starlight Manga', '/images/demo/poster-4.jpg', 12),
      demoProgress('demo-garden-of-letters', 'Demo Garden of Letters', '/images/demo/poster-3.jpg', 7),
    ],
  ],
]);
const demoChanges = new Changes<Record<string, KatanaBookmark[]>>(() => {
  const out: Record<string, KatanaBookmark[]> = {};
  for (const [user, list] of demoBookmarks.entries()) out[user] = list;
  return out;
});

function bookmarkFromDoc(data: DocumentData, id: string): KatanaBookmark {
  const ts = data.addedAt as Timestamp | undefined;
  return {
    slug: String(data.slug ?? id),
    title: String(data.title ?? ''),
    coverUrl: String(data.coverUrl ?? ''),
    status: String(data.status ?? 'ongoing'),
    addedAt: ts?.toDate ? ts.toDate() : new Date(),
    lastReadChapterId: String(data.lastReadChapterId ?? ''),
    lastReadPage: Number(data.lastReadPage ?? 0) || 0,
    lastReadChapterTitle: String(data.lastReadChapterTitle ?? ''),
    latestChapterTitle: String(data.latestChapterTitle ?? ''),
    recommendedBy: String(data.recommendedBy ?? ''),
    recommendationNote: String(data.recommendationNote ?? ''),
    readChapterIds: Array.isArray(data.readChapterIds) ? data.readChapterIds.map(String) : [],
    bookmarked: data.bookmarked !== false,
    finishedAt: (data.finishedAt as Timestamp | undefined)?.toDate?.(),
  };
}

export function watchKatanaBookmarks(userName: string): Source<KatanaBookmark[]> {
  if (!userName) {
    return (l) => {
      queueMicrotask(() => l.data([]));
      return () => {};
    };
  }
  if (AgentMode.demo) return (l) => demoChanges.source({ data: (all) => l.data(all[userName] ?? []) });
  const q = query(collection(db, 'katana_bookmarks'), where('userName', '==', userName), limit(500));
  return withFirestoreTimeout(
    snapshots(
      (next: (s: QuerySnapshot<DocumentData>) => void, error) => onSnapshot(q, next, error),
      (snap) => snap.docs.map((d) => bookmarkFromDoc(d.data(), d.id)).sort((a, b) => b.addedAt.getTime() - a.addedAt.getTime()),
    ),
    { label: `katana-bookmarks-${userName}` },
  );
}

async function getKatanaBookmark(slug: string, userName: string): Promise<KatanaBookmark | null> {
  if (!userName || !slug) return null;
  if (AgentMode.demo) return (demoBookmarks.get(userName) ?? []).find((b) => b.slug === slug) ?? null;
  try {
    const snap = await getDoc(doc(db, 'katana_bookmarks', `${userName}|${slug}`));
    return snap.exists() ? bookmarkFromDoc(snap.data(), snap.id) : null;
  } catch {
    return null;
  }
}

export async function setKatanaBookmark(manga: KatanaManga, userName: string, bookmarked: boolean): Promise<void> {
  if (!userName || !manga.slug) return;
  if (AgentMode.demo) {
    const list = demoBookmarks.get(userName) ?? [];
    const idx = list.findIndex((b) => b.slug === manga.slug);
    const entry: KatanaBookmark =
      idx >= 0
        ? { ...list[idx], bookmarked }
        : {
            slug: manga.slug,
            title: manga.title,
            coverUrl: manga.coverUrl,
            status: manga.status,
            addedAt: new Date(),
            lastReadChapterId: '',
            lastReadPage: 0,
            lastReadChapterTitle: '',
            latestChapterTitle: manga.latestChapter?.title ?? '',
            recommendedBy: '',
            recommendationNote: '',
            readChapterIds: [],
            bookmarked,
          };
    const next = [...list];
    if (idx >= 0) next[idx] = entry;
    else next.unshift(entry);
    demoBookmarks.set(userName, next);
    demoChanges.emit();
    return;
  }
  await setDoc(
    doc(db, 'katana_bookmarks', `${userName}|${manga.slug}`),
    bookmarked
      ? {
          slug: manga.slug,
          title: manga.title,
          coverUrl: manga.coverUrl,
          status: manga.status,
          userName,
          bookmarked: true,
          addedAt: Timestamp.now(),
        }
      : { bookmarked: false, userName },
    { merge: true },
  );
}

export async function saveKatanaReadingProgress(p: {
  userName: string;
  slug: string;
  chapterId: string;
  page: number;
  chapterTitle: string;
  title?: string;
  coverUrl?: string;
  finished?: boolean;
}): Promise<void> {
  if (!p.userName || !p.slug) return;
  if (AgentMode.demo) {
    const list = demoBookmarks.get(p.userName) ?? [];
    const idx = list.findIndex((b) => b.slug === p.slug);
    const cur = idx >= 0 ? list[idx] : undefined;
    const readChapterIds = Array.from(new Set([...(cur?.readChapterIds ?? []), p.chapterId]));
    const entry: KatanaBookmark = {
      slug: p.slug,
      title: p.title || cur?.title || p.slug,
      coverUrl: p.coverUrl || cur?.coverUrl || '',
      status: cur?.status || 'ongoing',
      addedAt: cur?.addedAt ?? new Date(),
      lastReadChapterId: p.chapterId,
      lastReadPage: p.page,
      lastReadChapterTitle: p.chapterTitle,
      latestChapterTitle: cur?.latestChapterTitle ?? '',
      recommendedBy: cur?.recommendedBy ?? '',
      recommendationNote: cur?.recommendationNote ?? '',
      readChapterIds,
      bookmarked: cur?.bookmarked ?? false,
      finishedAt: cur?.finishedAt ?? (p.finished ? new Date() : undefined),
    };
    const next = [...list];
    if (idx >= 0) next[idx] = entry;
    else next.unshift(entry);
    demoBookmarks.set(p.userName, next);
    demoChanges.emit();
    return;
  }
  const existing = await getKatanaBookmark(p.slug, p.userName);
  const readChapterIds = Array.from(new Set([...(existing?.readChapterIds ?? []), p.chapterId]));
  await setDoc(
    doc(db, 'katana_bookmarks', `${p.userName}|${p.slug}`),
    {
      slug: p.slug,
      userName: p.userName,
      lastReadChapterId: p.chapterId,
      lastReadPage: p.page,
      lastReadChapterTitle: p.chapterTitle,
      readChapterIds,
      ...(p.finished && !existing?.finishedAt ? { finishedAt: Timestamp.now(), status: 'completed' } : {}),
      ...(p.title ? { title: p.title } : {}),
      ...(p.coverUrl ? { coverUrl: p.coverUrl } : {}),
    },
    { merge: true },
  );
}

export async function clearKatanaReadingProgress(slug: string, userName: string): Promise<void> {
  if (!userName || !slug) return;
  if (AgentMode.demo) {
    const list = demoBookmarks.get(userName) ?? [];
    const idx = list.findIndex((b) => b.slug === slug);
    if (idx < 0) return;
    const cur = list[idx];
    const next = [...list];
    if (cur.bookmarked) {
      next[idx] = {
        ...cur,
        lastReadChapterId: '',
        lastReadPage: 0,
        lastReadChapterTitle: '',
        readChapterIds: [],
        finishedAt: undefined,
      };
    } else {
      next.splice(idx, 1);
    }
    demoBookmarks.set(userName, next);
    demoChanges.emit();
    return;
  }
  const existing = await getKatanaBookmark(slug, userName);
  const ref = doc(db, 'katana_bookmarks', `${userName}|${slug}`);
  if (!existing?.bookmarked) {
    await deleteDoc(ref);
    return;
  }
  await setDoc(
    ref,
    {
      lastReadChapterId: '',
      lastReadPage: 0,
      lastReadChapterTitle: '',
      readChapterIds: [],
      finishedAt: deleteField(),
    },
    { merge: true },
  );
}
