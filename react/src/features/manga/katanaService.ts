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
  type DocumentSnapshot,
  type QuerySnapshot,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { ConnectivityService } from '../../core/network/connectivity';
import { fetchFallbackChapterPages } from './mangaFallbackProviders';
import { getDemoChapterPages } from './readerDemo';
import { auth, db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { Changes, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';
import { catalogProxyGet } from '../../shared/utils/catalogProxy';

const BASE_URL = 'https://mangakatana.com';
const FUNCTIONS_BASE = 'https://us-central1-everglow-1c6db.cloudfunctions.net';
const PROXY_HTML_URL = `${FUNCTIONS_BASE}/proxyFetchHtml`;
const PROXY_IMAGE_URL = `${FUNCTIONS_BASE}/proxyMangaKatana`;
const PROXY_MANGADEX_URL = `${FUNCTIONS_BASE}/proxyMangaDex`;
const PROXY_MANGA_IMAGE_URL = `${FUNCTIONS_BASE}/proxyMangaImage`;

export type KatanaCatalogSource = 'mangakatana' | 'mangadex';

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

export type KatanaWeekday = 'Mon' | 'Tue' | 'Wed' | 'Thu' | 'Fri' | 'Sat' | 'Sun';

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
  rating?: number;
  follows?: number;
  chapterCount?: number;
  demographic?: string;
  releaseDay?: KatanaWeekday;
}

export type KatanaLibraryStatus = 'reading' | 'completed' | 'on_hold' | 'planned' | 'dropped';

export interface KatanaBookmark {
  slug: string;
  title: string;
  coverUrl: string;
  status: string;
  addedAt: Date;
  lastReadAt?: Date;
  lastReadChapterId: string;
  lastReadPage: number;
  lastReadChapterTitle: string;
  latestChapterTitle: string;
  recommendedBy: string;
  recommendationNote: string;
  readChapterIds: string[];
  bookmarked: boolean;
  libraryStatus?: KatanaLibraryStatus;
  /** User-defined custom shelf/category names (Mihon-style multi-membership). */
  categories?: string[];
  /** Personal tracker fields synced per user in Firestore. */
  userScore?: number;
  rereadCount?: number;
  startedAt?: Date;
  anilistId?: string;
  malId?: string;
  trackerNote?: string;
  /** Live tracker metadata synced via Jikan (MyAnimeList) proxy. */
  malScore?: number;
  malRank?: number;
  malTotalChapters?: number;
  malStatus?: string;
  lastSyncedAt?: Date;
  /** Per-series new-chapter alert opt-in (defaults true for bookmarked series when undefined). */
  notifyOnUpdate?: boolean;
  /** Per-series auto-download opt-in for new unread chapters. */
  autoDownload?: boolean;
  /** Set once the reader reaches the last page of the final chapter of a completed series. */
  finishedAt?: Date;
}

export function resolveLibraryStatus(bm: KatanaBookmark): KatanaLibraryStatus {
  if (bm.libraryStatus) return bm.libraryStatus;
  if (bm.finishedAt) return 'completed';
  if (bm.lastReadChapterId) return 'reading';
  return 'planned';
}

export function extractChapterNumber(raw?: string): number {
  if (!raw) return 0;
  // Prefer explicit chapter token (Ch. 12.5, Chapter 42, c108) before falling back to first number.
  const explicit = /(?:ch(?:apter|\.)?\s*|c)(\d+(?:\.\d+)?)/i.exec(raw);
  if (explicit) return Number.parseFloat(explicit[1]) || 0;
  const m = /(\d+(?:\.\d+)?)/.exec(raw);
  return m ? Number.parseFloat(m[1]) || 0 : 0;
}

export function estimateUnreadCount(
  bm: KatanaBookmark,
  knownLatestNum?: number,
  knownChapters?: KatanaChapter[],
): number {
  const status = resolveLibraryStatus(bm);
  if (status === 'completed' || status === 'dropped') return 0;
  if (knownChapters && knownChapters.length > 0) {
    const readSet = new Set(bm.readChapterIds);
    if (bm.lastReadChapterId) readSet.add(bm.lastReadChapterId);
    return knownChapters.reduce((acc, c) => acc + (readSet.has(c.id) ? 0 : 1), 0);
  }
  const latestNum = knownLatestNum ?? extractChapterNumber(bm.latestChapterTitle);
  const readNum =
    extractChapterNumber(bm.lastReadChapterTitle) ||
    extractChapterNumber(katanaChapterNumFromId(bm.lastReadChapterId));
  if (latestNum <= 0) return 0;
  if (readNum <= 0) return Math.max(1, Math.ceil(latestNum));
  const diff = latestNum - readNum;
  if (diff <= 0.001) return 0;
  return Math.max(1, Math.ceil(diff - 0.001));
}

export function isBookmarkCaughtUp(
  bm: KatanaBookmark,
  knownLatestNum?: number,
  knownChapters?: KatanaChapter[],
): boolean {
  const status = resolveLibraryStatus(bm);
  if (status !== 'reading' || !bm.lastReadChapterId) return false;
  if (knownChapters && knownChapters.length > 0) {
    return estimateUnreadCount(bm, knownLatestNum, knownChapters) === 0;
  }
  const latestNum = knownLatestNum ?? extractChapterNumber(bm.latestChapterTitle);
  if (latestNum <= 0) return false;
  return estimateUnreadCount(bm, latestNum) === 0;
}

export function formatCompactNumber(n?: number): string {
  if (!n || n <= 0) return '';
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1).replace(/\.0$/, '')}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1).replace(/\.0$/, '')}K`;
  return String(n);
}

export interface KatanaPageResult {
  items: KatanaManga[];
  page: number;
  hasNext: boolean;
  hasPrev: boolean;
  totalPages?: number;
  totalResults?: number;
  error?: string;
}

export interface KatanaHomeData {
  hotUpdates: KatanaManga[];
  latest: KatanaManga[];
  hot: KatanaManga[];
  genres: KatanaGenre[];
  error?: string;
  fromCache?: boolean;
  fetchedAt?: number;
  sourceLabel?: string;
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
  return `${katanaMonths[time.getMonth()]} ${time.getDate()}, ${time.getFullYear()}`;
}

const WEEKDAYS: KatanaWeekday[] = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/** Derives a release weekday from recent chapter dates or relative update text so Release Schedule works in production. */
export function deriveReleaseDay(updateText?: string, recentChapters?: KatanaChapter[]): KatanaWeekday | undefined {
  const latestDate = recentChapters?.[0]?.updateAt;
  if (latestDate && !Number.isNaN(latestDate.getTime())) {
    return WEEKDAYS[latestDate.getDay()];
  }
  const raw = (updateText ?? '').trim();
  if (!raw) return undefined;
  const parsedKatana = parseKatanaDate(raw);
  if (parsedKatana) return WEEKDAYS[parsedKatana.getDay()];
  const lower = raw.toLowerCase();
  const now = new Date();
  if (lower.includes('just now') || lower.includes('minute') || lower.includes('hour') || lower.includes('today')) {
    return WEEKDAYS[now.getDay()];
  }
  if (lower.includes('yesterday')) {
    const d = new Date(now.getTime() - 86_400_000);
    return WEEKDAYS[d.getDay()];
  }
  const daysM = /(\d+)\s*days?\s*ago/.exec(lower);
  if (daysM) {
    const d = new Date(now.getTime() - Number(daysM[1]) * 86_400_000);
    return WEEKDAYS[d.getDay()];
  }
  const weeksM = /(\d+)\s*weeks?\s*ago/.exec(lower);
  if (weeksM) {
    const d = new Date(now.getTime() - Number(weeksM[1]) * 7 * 86_400_000);
    return WEEKDAYS[d.getDay()];
  }
  const fallbackTs = Date.parse(raw);
  if (!Number.isNaN(fallbackTs)) {
    return WEEKDAYS[new Date(fallbackTs).getDay()];
  }
  return undefined;
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

  const demographic = genres.find((g) => ['shounen', 'seinen', 'shoujo', 'josei'].includes(g.slug))?.name;
  const parsedChCount = latestChapter ? Math.floor(extractChapterNumber(latestChapter.num || latestChapter.title)) : 0;

  const updateText = dateM ? cleanText(dateM[0]) : '';
  return {
    slug,
    id: idM?.[1] ?? slug,
    title: titleM ? unescapeHtml(titleM[1].trim()) : slug,
    coverUrl: extractCover(block),
    status: statusM?.[1] ?? 'ongoing',
    updateText,
    summary: sumM ? cleanText(sumM[1]) : '',
    genres,
    latestChapter,
    recentChapters,
    altNames: [],
    authors: [],
    artists: [],
    chapters: [],
    chapterCount: parsedChCount > 0 ? parsedChCount : undefined,
    demographic,
    releaseDay: deriveReleaseDay(updateText, recentChapters),
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

const HOME_CACHE_KEY = 'everglow_katana_home_cache_v1';
const RECENT_SEARCH_KEY = 'everglow_katana_recent_searches_v1';
const PREFERRED_GENRES_KEY = 'everglow_katana_preferred_genres_v1';

export function getPreferredMangaGenres(): string[] {
  try {
    const raw = localStorage.getItem(PREFERRED_GENRES_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter((s): s is string => typeof s === 'string').slice(0, 6) : [];
  } catch {
    return [];
  }
}

export function setPreferredMangaGenres(slugs: string[]): string[] {
  const next = Array.from(new Set(slugs.map((s) => s.trim().toLowerCase()).filter(Boolean))).slice(0, 6);
  try {
    localStorage.setItem(PREFERRED_GENRES_KEY, JSON.stringify(next));
  } catch {
    // ignore storage quota
  }
  return next;
}

export function getRecentMangaSearches(): string[] {
  try {
    const raw = localStorage.getItem(RECENT_SEARCH_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter((s): s is string => typeof s === 'string').slice(0, 8) : [];
  } catch {
    return [];
  }
}

export function pushRecentMangaSearch(q: string, userName?: string): string[] {
  const trimmed = q.trim();
  if (!trimmed) return getRecentMangaSearches();
  const next = [trimmed, ...getRecentMangaSearches().filter((s) => s.toLowerCase() !== trimmed.toLowerCase())].slice(0, 8);
  try {
    localStorage.setItem(RECENT_SEARCH_KEY, JSON.stringify(next));
  } catch {
    // ignore storage quota
  }
  if (userName) saveKatanaRecentSearches(userName, next);
  return next;
}

export function removeRecentMangaSearch(q: string, userName?: string): string[] {
  const next = getRecentMangaSearches().filter((s) => s.toLowerCase() !== q.toLowerCase());
  try {
    localStorage.setItem(RECENT_SEARCH_KEY, JSON.stringify(next));
  } catch {
    // ignore
  }
  if (userName) saveKatanaRecentSearches(userName, next);
  return next;
}

export function clearRecentMangaSearches(userName?: string): void {
  try {
    localStorage.removeItem(RECENT_SEARCH_KEY);
  } catch {
    // ignore
  }
  if (userName) saveKatanaRecentSearches(userName, []);
}

function saveHomeCache(data: KatanaHomeData): void {
  if (data.latest.length === 0 && data.hot.length === 0) return;
  try {
    localStorage.setItem(HOME_CACHE_KEY, JSON.stringify({ savedAt: Date.now(), data }));
  } catch {
    // ignore storage quota
  }
}

function loadHomeCache(): KatanaHomeData | null {
  try {
    const raw = localStorage.getItem(HOME_CACHE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { savedAt?: number; data?: KatanaHomeData };
    if (!parsed?.data) return null;
    const reviveChapter = (c: KatanaChapter): KatanaChapter => ({
      ...c,
      updateAt: c.updateAt ? new Date(c.updateAt) : undefined,
    });
    const reviveManga = (m: KatanaManga): KatanaManga => ({
      ...m,
      updateAt: m.updateAt ? new Date(m.updateAt) : undefined,
      latestChapter: m.latestChapter ? reviveChapter(m.latestChapter) : undefined,
      recentChapters: (m.recentChapters ?? []).map(reviveChapter),
      chapters: (m.chapters ?? []).map(reviveChapter),
    });
    return {
      hotUpdates: (parsed.data.hotUpdates ?? []).map(reviveManga),
      latest: (parsed.data.latest ?? []).map(reviveManga),
      hot: (parsed.data.hot ?? []).map(reviveManga),
      genres: parsed.data.genres ?? [],
      fromCache: true,
      fetchedAt: parsed.savedAt ?? parsed.data.fetchedAt,
      sourceLabel: 'MangaKatana (cached)',
    };
  } catch {
    return null;
  }
}

function buildDemoGenres(): KatanaGenre[] {
  return [
    { slug: 'action', name: 'Action', count: 1420, description: 'High-stakes battles, martial arts, and relentless momentum.' },
    { slug: 'fantasy', name: 'Fantasy', count: 1180, description: 'Arcane realms, dungeons, and grand world-building.' },
    { slug: 'manhwa', name: 'Manhwa', count: 960, description: 'Full-color Korean vertical-scroll webtoons and action epics.' },
    { slug: 'manhua', name: 'Manhua', count: 640, description: 'Chinese cultivation, wuxia, and mythic adventures.' },
    { slug: 'adventure', name: 'Adventure', count: 1090, description: 'Long journeys across uncharted frontiers.' },
    { slug: 'sci-fi', name: 'Sci-Fi', count: 510, description: 'Cyberpunk cities, orbital colonies, and speculative futures.' },
    { slug: 'mystery', name: 'Mystery', count: 470, description: 'Twisted investigations, clues, and psychological tension.' },
    { slug: 'slice-of-life', name: 'Slice of Life', count: 690, description: 'Quiet everyday stories with warmth and craft.' },
    { slug: 'drama', name: 'Drama', count: 830, description: 'Character-driven turning points and emotional stakes.' },
    { slug: 'comedy', name: 'Comedy', count: 780, description: 'Sharp wit, deadpan gags, and ensemble chaos.' },
    { slug: 'seinen', name: 'Seinen', count: 620, description: 'Mature storytelling, intricate art, and complex themes.' },
    { slug: 'supernatural', name: 'Supernatural', count: 710, description: 'Spirits, curses, and hidden worlds beyond sight.' },
  ];
}

function makeDemoChapters(count: number, prefix: string): KatanaChapter[] {
  const now = Date.now();
  return Array.from({ length: count }, (_, i) => {
    const n = count - i;
    return {
      id: `c${n}`,
      num: String(n),
      title: `Chapter ${n}${i === 0 ? `: ${prefix}` : ''}`,
      updateAt: new Date(now - i * 36 * 3600 * 1000),
      isNew: i < 2,
    };
  });
}

function buildDemoCatalog(): KatanaManga[] {
  const genres = buildDemoGenres();
  const g = (...slugs: string[]) => genres.filter((x) => slugs.includes(x.slug));
  const now = Date.now();
  const series: Array<{
    slug: string;
    title: string;
    coverUrl: string;
    status: 'ongoing' | 'completed';
    authors: string[];
    altNames: string[];
    genres: KatanaGenre[];
    summary: string;
    chapterCount: number;
    latestSubtitle: string;
    updateText: string;
    hoursAgo: number;
    rating: number;
    follows: number;
    demographic: string;
    releaseDay: KatanaWeekday;
  }> = [
    {
      slug: 'demo-starlight-manga',
      title: 'Fictional Starlight Manga',
      coverUrl: '/images/demo/poster-4.jpg',
      status: 'ongoing',
      authors: ['Renji Takahashi'],
      altNames: ['Hoshikuzu Senki', 'Starlight Chronicles'],
      genres: g('action', 'fantasy', 'adventure'),
      summary: 'When an ancient observatory splits the night sky over the archipelago, a young cartographer and a rogue bladesmith race across floating ruins to chart the fallen stars before rival guilds claim them.',
      chapterCount: 43,
      latestSubtitle: 'Beyond the Horizon',
      updateText: '2 hours ago',
      hoursAgo: 2,
      rating: 9.2,
      follows: 64800,
      demographic: 'Shounen',
      releaseDay: 'Mon',
    },
    {
      slug: 'demo-iron-sovereign',
      title: 'Iron Sovereign of the Ashen Gate',
      coverUrl: '/images/demo/poster-1.jpg',
      status: 'ongoing',
      authors: ['Min-Jun Kang', 'Studio Baekho'],
      altNames: ['Ashen Gate', 'Cheolwang-ui Mun'],
      genres: g('manhwa', 'action', 'fantasy'),
      summary: 'Left for dead inside a collapsing S-rank labyrinth, a low-tier smith awakens the memory of a forgotten forge master and climbs back through every tower floor.',
      chapterCount: 118,
      latestSubtitle: 'The Seventh Anvil',
      updateText: '4 hours ago',
      hoursAgo: 4,
      rating: 9.4,
      follows: 142000,
      demographic: 'Shounen',
      releaseDay: 'Tue',
    },
    {
      slug: 'demo-paper-moon',
      title: 'Demo Paper Moon',
      coverUrl: '/images/demo/poster-2.jpg',
      status: 'completed',
      authors: ['Haruka Sato'],
      altNames: ['Kami no Tsuki'],
      genres: g('mystery', 'drama', 'seinen'),
      summary: 'In a rain-drenched coastal town where letters arrive from the wrong decade, an archivist pieces together a century-old disappearance hidden inside bindings of old journals.',
      chapterCount: 120,
      latestSubtitle: 'Final Postmark',
      updateText: '1 day ago',
      hoursAgo: 24,
      rating: 9.1,
      follows: 51300,
      demographic: 'Seinen',
      releaseDay: 'Wed',
    },
    {
      slug: 'demo-jade-sky-blade',
      title: 'Jade Sky Blade Pavilion',
      coverUrl: '/images/demo/poster-3.jpg',
      status: 'ongoing',
      authors: ['Lin Wuyue'],
      altNames: ['Bi Tian Jian Ge'],
      genres: g('manhua', 'action', 'supernatural'),
      summary: 'A wandering ink-painter discovers his brush strokes can unseal ancient sword spirits dormant across the Nine River Provinces.',
      chapterCount: 86,
      latestSubtitle: 'Mist Over Southern Peak',
      updateText: '6 hours ago',
      hoursAgo: 6,
      rating: 8.7,
      follows: 38900,
      demographic: 'Shounen',
      releaseDay: 'Thu',
    },
    {
      slug: 'demo-neon-courier',
      title: 'Neon Courier 2099',
      coverUrl: '/images/demo/poster-1.jpg',
      status: 'ongoing',
      authors: ['Kenji Morita'],
      altNames: ['Shinjuku Express 99'],
      genres: g('sci-fi', 'action', 'seinen'),
      summary: 'A zero-gravity bike messenger in Neo-Kobe takes one unlogged parcel and triggers a citywide blackout pursued by orbital syndicates.',
      chapterCount: 54,
      latestSubtitle: 'Sublevel Relay',
      updateText: '9 hours ago',
      hoursAgo: 9,
      rating: 8.9,
      follows: 29400,
      demographic: 'Seinen',
      releaseDay: 'Fri',
    },
    {
      slug: 'demo-garden-of-letters',
      title: 'Demo Garden of Letters',
      coverUrl: '/images/demo/poster-3.jpg',
      status: 'ongoing',
      authors: ['Aoi Nishimura'],
      altNames: ['Tegami no Niwa'],
      genres: g('slice-of-life', 'drama', 'comedy'),
      summary: 'Two stubborn apprentices inherit a hillside bookshop and revive a neighborhood reading circle one eccentric regular at a time.',
      chapterCount: 28,
      latestSubtitle: 'Rainy Afternoon Shelf',
      updateText: '12 hours ago',
      hoursAgo: 12,
      rating: 8.8,
      follows: 21700,
      demographic: 'Josei',
      releaseDay: 'Sat',
    },
    {
      slug: 'demo-crimson-tides',
      title: 'Crimson Tides of Busan',
      coverUrl: '/images/demo/poster-2.jpg',
      status: 'ongoing',
      authors: ['Ji-Hoon Park'],
      altNames: ['Bulgeun Pado'],
      genres: g('manhwa', 'mystery', 'supernatural'),
      summary: 'When ghost ships begin docking at dawn with passengers who never aged, a harbor diver uncovers a pact beneath the breakwater.',
      chapterCount: 67,
      latestSubtitle: 'Low Tide Signal',
      updateText: '18 hours ago',
      hoursAgo: 18,
      rating: 9.0,
      follows: 44100,
      demographic: 'Seinen',
      releaseDay: 'Sun',
    },
    {
      slug: 'demo-cloud-sect-alchemist',
      title: 'Cloud Sect Alchemist',
      coverUrl: '/images/demo/poster-4.jpg',
      status: 'completed',
      authors: ['Chen Zihan'],
      altNames: ['Yun Zong Dan Shi'],
      genres: g('manhua', 'fantasy', 'comedy'),
      summary: 'Banished from the inner sect for brewing tea instead of elixirs, a laid-back disciple accidentally turns his roadside stall into the most feared neutral ground in the realm.',
      chapterCount: 95,
      latestSubtitle: 'Epilogue: First Steep',
      updateText: '3 days ago',
      hoursAgo: 72,
      rating: 8.6,
      follows: 33500,
      demographic: 'Shounen',
      releaseDay: 'Mon',
    },
  ];

  return series.map((s, idx) => {
    const chapters = makeDemoChapters(s.chapterCount, s.latestSubtitle);
    return {
      slug: s.slug,
      id: String(1000 + idx),
      title: s.title,
      coverUrl: s.coverUrl,
      status: s.status,
      updateText: s.updateText,
      summary: s.summary,
      genres: s.genres,
      latestChapter: chapters[0],
      recentChapters: chapters.slice(0, 3),
      altNames: s.altNames,
      authors: s.authors,
      artists: [],
      chapters,
      updateAt: new Date(now - s.hoursAgo * 3600 * 1000),
      rating: s.rating,
      follows: s.follows,
      chapterCount: s.chapterCount,
      demographic: s.demographic,
      releaseDay: s.releaseDay,
    };
  });
}

export async function fetchKatanaHome(): Promise<KatanaHomeData> {
  const html = await fetchHtml(`${BASE_URL}/`);
  if (!html) {
    if (AgentMode.demo) {
      const catalog = buildDemoCatalog();
      return {
        hotUpdates: catalog.slice(0, 6),
        latest: catalog,
        hot: [...catalog].sort((a, b) => b.chapters.length - a.chapters.length),
        genres: buildDemoGenres(),
        fetchedAt: Date.now(),
        sourceLabel: 'MangaKatana',
      };
    }
    const mdFallback = await buildMangaDexHomeFallback();
    if (mdFallback) return mdFallback;
    const cached = loadHomeCache();
    if (cached) {
      return { ...cached, error: 'Live catalog refresh failed — showing your last cached list.' };
    }
    return { hotUpdates: [], latest: [], hot: [], genres: [], error: 'Could not reach the manga catalog right now.' };
  }
  const hotIdx = html.indexOf('Hot Manga');
  const latestIdx = Math.max(0, html.indexOf('Latest Updates'));
  const latest = items(blocksOfClass(html, 'item', latestIdx, hotIdx < 0 ? -1 : hotIdx));
  const hot = hotIdx >= 0 ? items(blocksOfClass(html, 'item', hotIdx)) : [];
  const hotUpdateIdx = html.indexOf('id="hot_update"');
  const hotUpdateEnd = hotUpdateIdx >= 0 ? html.indexOf('id="wrap_content"', hotUpdateIdx) : -1;
  const hotUpdates = hotUpdateIdx >= 0 ? items(blocksOfClass(html, 'item', hotUpdateIdx, hotUpdateEnd)) : [];
  const parsedGenres = parseGenres(html);
  if (latest.length === 0 && hot.length === 0 && !AgentMode.demo) {
    const mdFallback = await buildMangaDexHomeFallback();
    if (mdFallback) {
      return {
        ...mdFallback,
        genres: parsedGenres.length > 0 ? parsedGenres : mdFallback.genres,
      };
    }
    const cached = loadHomeCache();
    if (cached) {
      return { ...cached, error: 'Primary catalog returned empty — showing your last cached list.' };
    }
  }
  const result: KatanaHomeData = {
    hotUpdates,
    latest,
    hot,
    genres: parsedGenres,
    fetchedAt: Date.now(),
    sourceLabel: 'MangaKatana',
  };
  saveHomeCache(result);
  return result;
}

async function buildMangaDexHomeFallback(): Promise<KatanaHomeData | null> {
  try {
    const [popularRes, latestRes] = await Promise.all([
      searchMangaDexCatalog({ orderBy: 'popular', page: 1 }),
      searchMangaDexCatalog({ orderBy: 'latest', page: 1 }),
    ]);
    if (popularRes.items.length === 0 && latestRes.items.length === 0) return null;
    const hot = popularRes.items.length > 0 ? popularRes.items : latestRes.items;
    const latest = latestRes.items.length > 0 ? latestRes.items : popularRes.items;
    const genreMap = new Map<string, KatanaGenre>();
    for (const m of [...hot, ...latest]) {
      for (const g of m.genres) {
        if (!genreMap.has(g.slug)) genreMap.set(g.slug, g);
      }
    }
    return {
      hotUpdates: hot.slice(0, 8),
      latest,
      hot,
      genres: [...genreMap.values()],
      fetchedAt: Date.now(),
      sourceLabel: 'MangaDex (Fallback)',
    };
  } catch {
    return null;
  }
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
  status?: 'all' | 'ongoing' | 'completed';
  demographic?: string;
  author?: string;
}): Promise<KatanaPageResult> {
  const applyClientFilters = (list: KatanaManga[]): KatanaManga[] => {
    let out = [...list];
    if (opts.status && opts.status !== 'all') {
      out = out.filter((m) => m.status.toLowerCase() === opts.status);
    }
    if (opts.demographic && opts.demographic !== 'all') {
      const target = opts.demographic.toLowerCase();
      out = out.filter(
        (m) =>
          (m.demographic ?? '').toLowerCase() === target ||
          m.genres.some((g) => g.slug === target || g.name.toLowerCase() === target),
      );
    }
    if (opts.author && opts.author.trim()) {
      const aq = opts.author.trim().toLowerCase();
      out = out.filter((m) => m.authors.some((a) => a.toLowerCase().includes(aq)));
    }
    if (opts.mode === 'search') {
      if (opts.include && opts.include.length > 0) {
        const inc = opts.include.map((s) => s.toLowerCase());
        out = out.filter((m) => {
          const slugs = m.genres.map((g) => g.slug);
          return opts.genreMode === 'or' ? inc.some((s) => slugs.includes(s)) : inc.every((s) => slugs.includes(s));
        });
      }
      if (opts.exclude && opts.exclude.length > 0) {
        const exc = new Set(opts.exclude.map((s) => s.toLowerCase()));
        out = out.filter((m) => !m.genres.some((g) => exc.has(g.slug)));
      }
      if (opts.chapters) {
        const minCh = Number(opts.chapters) || 0;
        if (minCh > 1) out = out.filter((m) => (m.chapterCount ?? m.chapters.length) >= minCh);
      }
      if (opts.orderBy === 'az') out.sort((a, b) => a.title.localeCompare(b.title));
      else if (opts.orderBy === 'numc') out.sort((a, b) => (b.chapterCount ?? b.chapters.length) - (a.chapterCount ?? a.chapters.length));
      else if (opts.orderBy === 'new') out.sort((a, b) => (a.chapterCount ?? a.chapters.length) - (b.chapterCount ?? b.chapters.length));
      else if (opts.orderBy === 'rating') out.sort((a, b) => (b.rating ?? 0) - (a.rating ?? 0));
      else if (opts.orderBy === 'popular') out.sort((a, b) => (b.follows ?? 0) - (a.follows ?? 0));
    } else if (opts.orderBy === 'rating') {
      out.sort((a, b) => (b.rating ?? 0) - (a.rating ?? 0));
    } else if (opts.orderBy === 'popular') {
      out.sort((a, b) => (b.follows ?? 0) - (a.follows ?? 0));
    }
    return out;
  };
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
      const urlSlugMatch = /\/manga\/([a-z0-9._-]+)/i.exec(opts.query ?? '');
      const effectiveQuery = urlSlugMatch ? urlSlugMatch[1].replace(/[-_.]+/g, ' ') : (opts.query ?? '');
      const upstreamSearchBy = opts.searchBy === 'author' ? 'author' : 'm_name';
      const params = new URLSearchParams({ search: effectiveQuery, search_by: upstreamSearchBy });
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
      order_by: opts.orderBy === 'rating' || opts.orderBy === 'popular' ? 'latest' : (opts.orderBy ?? 'latest'),
    });
    url += `?${params.toString()}`;
  }
  const matchesSearch = (m: KatanaManga, rawQuery: string, searchBy?: string): boolean => {
    const trimmed = rawQuery.trim();
    const urlSlugMatch = /\/manga\/([a-z0-9._-]+)/i.exec(trimmed);
    if (urlSlugMatch && m.slug.toLowerCase() === urlSlugMatch[1].toLowerCase()) return true;
    const q = (urlSlugMatch ? urlSlugMatch[1].replace(/[-_.]+/g, ' ') : trimmed).toLowerCase();
    if (!q) return true;
    if (searchBy === 'author') {
      return m.authors.some((a) => a.toLowerCase().includes(q));
    }
    if (searchBy === 'alt_theme') {
      return (
        m.title.toLowerCase().includes(q) ||
        m.altNames.some((a) => a.toLowerCase().includes(q)) ||
        m.genres.some((g) => g.name.toLowerCase().includes(q) || g.slug.toLowerCase().includes(q)) ||
        (m.summary ?? '').toLowerCase().includes(q) ||
        m.authors.some((a) => a.toLowerCase().includes(q))
      );
    }
    return (
      m.title.toLowerCase().includes(q) ||
      m.altNames.some((a) => a.toLowerCase().includes(q)) ||
      m.slug.toLowerCase().includes(q)
    );
  };
  const html = await fetchHtml(url);
  if (!html) {
    if (AgentMode.demo) {
      let demo = buildDemoCatalog();
      if (opts.mode === 'genre' && opts.key) {
        demo = demo.filter((m) => m.genres.some((g) => g.slug === opts.key));
      }
      if (opts.mode === 'search' && opts.query) {
        demo = demo.filter((m) => matchesSearch(m, opts.query!, opts.searchBy));
      }
      if (opts.include && opts.include.length > 0) {
        const inc = opts.include.map((s) => s.toLowerCase());
        demo = demo.filter((m) => {
          const slugs = m.genres.map((g) => g.slug);
          return opts.genreMode === 'or' ? inc.some((s) => slugs.includes(s)) : inc.every((s) => slugs.includes(s));
        });
      }
      if (opts.exclude && opts.exclude.length > 0) {
        const exc = new Set(opts.exclude.map((s) => s.toLowerCase()));
        demo = demo.filter((m) => !m.genres.some((g) => exc.has(g.slug)));
      }
      if (opts.chapters) {
        const minCh = Number(opts.chapters) || 0;
        if (minCh > 1) demo = demo.filter((m) => m.chapters.length >= minCh);
      }
      if (opts.orderBy === 'az') demo.sort((a, b) => a.title.localeCompare(b.title));
      else if (opts.orderBy === 'numc') demo.sort((a, b) => (b.chapterCount ?? b.chapters.length) - (a.chapterCount ?? a.chapters.length));
      else if (opts.orderBy === 'new') demo.sort((a, b) => (a.chapterCount ?? a.chapters.length) - (b.chapterCount ?? b.chapters.length));
      else if (opts.orderBy === 'rating') demo.sort((a, b) => (b.rating ?? 0) - (a.rating ?? 0));
      else if (opts.orderBy === 'popular') demo.sort((a, b) => (b.follows ?? 0) - (a.follows ?? 0));
      const filtered = applyClientFilters(demo);
      return { items: filtered, page, hasNext: false, hasPrev: page > 1, totalPages: 1, totalResults: filtered.length };
    }
    const cached = loadHomeCache();
    if (cached) {
      const seen = new Set<string>();
      let pool: KatanaManga[] = [];
      for (const m of [...cached.latest, ...cached.hot, ...cached.hotUpdates]) {
        if (!seen.has(m.slug)) {
          seen.add(m.slug);
          pool.push(m);
        }
      }
      if (opts.mode === 'genre' && opts.key) {
        pool = pool.filter((m) => m.genres.some((g) => g.slug === opts.key));
      }
      if (opts.mode === 'search' && opts.query) {
        pool = pool.filter((m) => matchesSearch(m, opts.query!, opts.searchBy));
      }
      const filtered = applyClientFilters(pool);
      if (filtered.length > 0) {
        return {
          items: filtered,
          page: 1,
          hasNext: false,
          hasPrev: false,
          totalPages: 1,
          totalResults: filtered.length,
          error: 'Live catalog unavailable — showing matching titles from your cached catalog.',
        };
      }
    }
    return { items: [], page, hasNext: false, hasPrev: page > 1, error: 'Could not load catalog right now.' };
  }
  const blocks =
    opts.mode === 'search'
      ? (() => {
          const start = html.indexOf('Search results');
          const end = start >= 0 ? html.indexOf('widget-title', start + 20) : -1;
          return start >= 0 ? blocksOfClass(html, 'item', start, end) : [];
        })()
      : blocksOfClass(html, 'item');
  let parsedItems = applyClientFilters(items(blocks));
  if (opts.mode === 'search' && opts.query && parsedItems.length === 0) {
    const cached = loadHomeCache();
    if (cached) {
      const seen = new Set<string>();
      const pool: KatanaManga[] = [];
      for (const m of [...cached.latest, ...cached.hot, ...cached.hotUpdates]) {
        if (!seen.has(m.slug)) {
          seen.add(m.slug);
          pool.push(m);
        }
      }
      parsedItems = applyClientFilters(pool.filter((m) => matchesSearch(m, opts.query!, 'alt_theme')));
    }
  }
  const hasNext = html.includes('class="next page-numbers"');
  const pageNums = [...html.matchAll(/class="page-numbers"[^>]*>(\d+)</g)].map((m) => Number(m[1])).filter((n) => n > 0);
  const maxListedPage = pageNums.length > 0 ? Math.max(...pageNums, page) : hasNext ? undefined : page;
  return {
    items: parsedItems,
    page,
    hasNext,
    hasPrev: page > 1 && html.includes('class="prev page-numbers"'),
    totalPages: maxListedPage,
    totalResults: !hasNext && page === 1 ? parsedItems.length : undefined,
  };
}

export async function fetchKatanaByType(type: string, page = 1): Promise<KatanaPageResult> {
  if (type === 'manga') return fetchKatanaCatalog({ mode: 'directory', page, exclude: ['manhwa', 'manhua'] });
  if (type === 'manhwa') return fetchKatanaCatalog({ mode: 'directory', page, include: ['manhwa'] });
  if (type === 'manhua') return fetchKatanaCatalog({ mode: 'directory', page, include: ['manhua'] });
  return fetchKatanaCatalog({ mode: 'directory', page });
}

export async function fetchKatanaSuggestions(queryText: string, searchBy = 'm_name'): Promise<KatanaManga[]> {
  if (queryText.trim().length < 2) return [];
  const res = await fetchKatanaCatalog({ mode: 'search', query: queryText.trim(), searchBy });
  return res.items.slice(0, 8);
}

export async function fetchKatanaDetail(slug: string): Promise<KatanaManga | null> {
  if (!slug) return null;
  const html = await fetchHtml(`${BASE_URL}/manga/${slug}`);
  if (!html) {
    if (AgentMode.demo) {
      return buildDemoCatalog().find((m) => m.slug === slug) ?? buildDemoCatalog()[0] ?? null;
    }
    return null;
  }
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
  const artists: string[] = [];
  const authorBlock = /<div class="d-cell-small label">Author\(s\)(?: \/ Artist\(s\))?:<\/div>.*?<\/div>/s.exec(html);
  if (authorBlock) {
    const aRe = /<a class="author" href="[^"]*"[^>]*>([^<]+)<\/a>/g;
    let am: RegExpExecArray | null;
    while ((am = aRe.exec(authorBlock[0]))) authors.push(unescapeHtml(am[1].trim()));
  }
  const artistBlock = /<div class="d-cell-small label">Artist\(s\):<\/div>.*?<\/div>/s.exec(html);
  if (artistBlock) {
    const aRe = /<a class="author" href="[^"]*"[^>]*>([^<]+)<\/a>/g;
    let am: RegExpExecArray | null;
    while ((am = aRe.exec(artistBlock[0]))) artists.push(unescapeHtml(am[1].trim()));
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

  const detailUpdateText = updateM?.[1]?.trim() ?? '';
  return {
    slug,
    id: idM?.[1] ?? slug,
    title: titleM ? unescapeHtml(titleM[1].trim()) : slug,
    coverUrl: extractCover(html),
    status: statusM?.[1] ?? 'ongoing',
    updateText: detailUpdateText,
    summary: sumM ? cleanText(sumM[1]) : '',
    genres,
    altNames,
    authors,
    artists,
    recentChapters: chapters.slice(0, 3),
    chapters,
    releaseDay: deriveReleaseDay(detailUpdateText, chapters.slice(0, 3)),
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
  if (fallback.pages.length > 0) return fallback.pages;
  if (AgentMode.demo) return getDemoChapterPages(chapterId);
  return [];
}

const demoProgress = (
  slug: string,
  title: string,
  coverUrl: string,
  chapter: number,
  finishedAt?: Date,
  latestChapterTitle = '',
  lastReadAt?: Date,
): KatanaBookmark => ({
  slug,
  title,
  coverUrl,
  status: finishedAt ? 'completed' : 'ongoing',
  addedAt: new Date(2026, 1, 14),
  lastReadAt: lastReadAt ?? finishedAt ?? new Date(2026, 2, 10),
  lastReadChapterId: `c${chapter}`,
  lastReadPage: 1,
  lastReadChapterTitle: `Chapter ${chapter}`,
  latestChapterTitle,
  recommendedBy: '',
  recommendationNote: '',
  readChapterIds: Array.from({ length: Math.min(chapter, 6) }, (_, i) => `c${chapter - i}`),
  bookmarked: true,
  libraryStatus: finishedAt ? 'completed' : 'reading',
  finishedAt,
});

// Agent mode keeps bookmarks in memory, per user, seeded with made-up reading progress.
const demoBookmarks = new Map<string, KatanaBookmark[]>([
  [
    'khentsgdz',
    [
      demoProgress('demo-starlight-manga', 'Fictional Starlight Manga', '/images/demo/poster-4.jpg', 42, undefined, 'Chapter 43', new Date(2026, 2, 12, 20, 0)),
      demoProgress('demo-paper-moon', 'Demo Paper Moon', '/images/demo/poster-2.jpg', 120, new Date(2026, 2, 1), 'Chapter 120', new Date(2026, 2, 1, 18, 0)),
    ],
  ],
  [
    'clairjassen',
    [
      demoProgress('demo-starlight-manga', 'Fictional Starlight Manga', '/images/demo/poster-4.jpg', 12, undefined, 'Chapter 43', new Date(2026, 2, 11, 21, 0)),
      demoProgress('demo-garden-of-letters', 'Demo Garden of Letters', '/images/demo/poster-3.jpg', 7, undefined, 'Chapter 28', new Date(2026, 2, 9, 15, 0)),
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
  const lastReadTs = data.lastReadAt as Timestamp | undefined;
  return {
    slug: String(data.slug ?? id),
    title: String(data.title ?? ''),
    coverUrl: String(data.coverUrl ?? ''),
    status: String(data.status ?? 'ongoing'),
    addedAt: ts?.toDate ? ts.toDate() : new Date(),
    lastReadAt: lastReadTs?.toDate ? lastReadTs.toDate() : undefined,
    lastReadChapterId: String(data.lastReadChapterId ?? ''),
    lastReadPage: Number(data.lastReadPage ?? 0) || 0,
    lastReadChapterTitle: String(data.lastReadChapterTitle ?? ''),
    latestChapterTitle: String(data.latestChapterTitle ?? ''),
    recommendedBy: String(data.recommendedBy ?? ''),
    recommendationNote: String(data.recommendationNote ?? ''),
    readChapterIds: Array.isArray(data.readChapterIds) ? data.readChapterIds.map(String) : [],
    bookmarked: data.bookmarked !== false,
    libraryStatus:
      data.libraryStatus === 'reading' ||
      data.libraryStatus === 'completed' ||
      data.libraryStatus === 'on_hold' ||
      data.libraryStatus === 'planned' ||
      data.libraryStatus === 'dropped'
        ? data.libraryStatus
        : undefined,
    categories: Array.isArray(data.categories) ? data.categories.map(String).filter(Boolean) : [],
    userScore: typeof data.userScore === 'number' && data.userScore >= 1 && data.userScore <= 10 ? data.userScore : undefined,
    rereadCount: typeof data.rereadCount === 'number' && data.rereadCount >= 0 ? data.rereadCount : undefined,
    startedAt: (data.startedAt as Timestamp | undefined)?.toDate?.(),
    anilistId: typeof data.anilistId === 'string' && data.anilistId.trim() ? data.anilistId.trim() : undefined,
    malId: typeof data.malId === 'string' && data.malId.trim() ? data.malId.trim() : undefined,
    trackerNote: typeof data.trackerNote === 'string' && data.trackerNote.trim() ? data.trackerNote.trim() : undefined,
    malScore: typeof data.malScore === 'number' && data.malScore > 0 ? data.malScore : undefined,
    malRank: typeof data.malRank === 'number' && data.malRank > 0 ? data.malRank : undefined,
    malTotalChapters: typeof data.malTotalChapters === 'number' && data.malTotalChapters > 0 ? data.malTotalChapters : undefined,
    malStatus: typeof data.malStatus === 'string' && data.malStatus.trim() ? data.malStatus.trim() : undefined,
    lastSyncedAt: (data.lastSyncedAt as Timestamp | undefined)?.toDate?.(),
    notifyOnUpdate: typeof data.notifyOnUpdate === 'boolean' ? data.notifyOnUpdate : undefined,
    autoDownload: typeof data.autoDownload === 'boolean' ? data.autoDownload : undefined,
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
      (snap) =>
        snap.docs
          .filter((d) => !String(d.data().kind ?? '').endsWith('_meta'))
          .map((d) => bookmarkFromDoc(d.data(), d.id))
          .sort((a, b) => b.addedAt.getTime() - a.addedAt.getTime()),
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
            notifyOnUpdate: true,
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
          notifyOnUpdate: true,
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
      lastReadAt: new Date(),
      lastReadChapterId: p.chapterId,
      lastReadPage: p.page,
      lastReadChapterTitle: p.chapterTitle,
      latestChapterTitle: cur?.latestChapterTitle ?? '',
      recommendedBy: cur?.recommendedBy ?? '',
      recommendationNote: cur?.recommendationNote ?? '',
      readChapterIds,
      bookmarked: cur?.bookmarked ?? false,
      libraryStatus: p.finished ? 'completed' : cur?.libraryStatus,
      categories: cur?.categories ?? [],
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
      ...(existing == null ? { bookmarked: false } : {}),
      lastReadAt: Timestamp.now(),
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

export async function setKatanaLibraryStatus(
  manga: Pick<KatanaManga, 'slug' | 'title' | 'coverUrl' | 'status'>,
  userName: string,
  libraryStatus: KatanaLibraryStatus,
): Promise<void> {
  if (!userName || !manga.slug) return;
  if (AgentMode.demo) {
    const list = demoBookmarks.get(userName) ?? [];
    const idx = list.findIndex((b) => b.slug === manga.slug);
    const cur = idx >= 0 ? list[idx] : undefined;
    const entry: KatanaBookmark = {
      slug: manga.slug,
      title: manga.title || cur?.title || manga.slug,
      coverUrl: manga.coverUrl || cur?.coverUrl || '',
      status: cur?.status || manga.status || 'ongoing',
      addedAt: cur?.addedAt ?? new Date(),
      lastReadAt: cur?.lastReadAt,
      lastReadChapterId: cur?.lastReadChapterId ?? '',
      lastReadPage: cur?.lastReadPage ?? 0,
      lastReadChapterTitle: cur?.lastReadChapterTitle ?? '',
      latestChapterTitle: cur?.latestChapterTitle ?? '',
      recommendedBy: cur?.recommendedBy ?? '',
      recommendationNote: cur?.recommendationNote ?? '',
      readChapterIds: cur?.readChapterIds ?? [],
      bookmarked: true,
      libraryStatus,
      categories: cur?.categories ?? [],
      userScore: cur?.userScore,
      rereadCount: cur?.rereadCount,
      startedAt: cur?.startedAt,
      anilistId: cur?.anilistId,
      malId: cur?.malId,
      trackerNote: cur?.trackerNote,
      finishedAt: libraryStatus === 'completed' ? cur?.finishedAt ?? new Date() : undefined,
    };
    const next = [...list];
    if (idx >= 0) next[idx] = entry;
    else next.unshift(entry);
    demoBookmarks.set(userName, next);
    demoChanges.emit();
    return;
  }
  const existing = await getKatanaBookmark(manga.slug, userName);
  await setDoc(
    doc(db, 'katana_bookmarks', `${userName}|${manga.slug}`),
    {
      slug: manga.slug,
      title: manga.title || existing?.title || manga.slug,
      coverUrl: manga.coverUrl || existing?.coverUrl || '',
      status: existing?.status || manga.status || 'ongoing',
      userName,
      bookmarked: true,
      libraryStatus,
      ...(libraryStatus === 'completed'
        ? existing?.finishedAt
          ? {}
          : { finishedAt: Timestamp.now() }
        : { finishedAt: deleteField() }),
      ...(existing == null ? { addedAt: Timestamp.now() } : {}),
    },
    { merge: true },
  );
}

export async function markKatanaChaptersRead(
  manga: Pick<KatanaManga, 'slug' | 'title' | 'coverUrl' | 'status'>,
  userName: string,
  chapterIds: string[],
  read: boolean,
): Promise<void> {
  if (!userName || !manga.slug || chapterIds.length === 0) return;
  const targets = new Set(chapterIds);
  if (AgentMode.demo) {
    const list = demoBookmarks.get(userName) ?? [];
    const idx = list.findIndex((b) => b.slug === manga.slug);
    const cur = idx >= 0 ? list[idx] : undefined;
    const prev = cur?.readChapterIds ?? [];
    const readChapterIds = read
      ? Array.from(new Set([...prev, ...chapterIds]))
      : prev.filter((id) => !targets.has(id));
    const entry: KatanaBookmark = {
      slug: manga.slug,
      title: manga.title || cur?.title || manga.slug,
      coverUrl: manga.coverUrl || cur?.coverUrl || '',
      status: manga.status || cur?.status || 'ongoing',
      addedAt: cur?.addedAt ?? new Date(),
      lastReadChapterId: cur?.lastReadChapterId ?? '',
      lastReadPage: cur?.lastReadPage ?? 0,
      lastReadChapterTitle: cur?.lastReadChapterTitle ?? '',
      latestChapterTitle: cur?.latestChapterTitle ?? '',
      recommendedBy: cur?.recommendedBy ?? '',
      recommendationNote: cur?.recommendationNote ?? '',
      readChapterIds,
      bookmarked: cur?.bookmarked ?? false,
      libraryStatus: cur?.libraryStatus,
      categories: cur?.categories ?? [],
      finishedAt: cur?.finishedAt,
    };
    const next = [...list];
    if (idx >= 0) next[idx] = entry;
    else next.unshift(entry);
    demoBookmarks.set(userName, next);
    demoChanges.emit();
    return;
  }
  const existing = await getKatanaBookmark(manga.slug, userName);
  const prev = existing?.readChapterIds ?? [];
  const readChapterIds = read
    ? Array.from(new Set([...prev, ...chapterIds]))
    : prev.filter((id) => !targets.has(id));
  await setDoc(
    doc(db, 'katana_bookmarks', `${userName}|${manga.slug}`),
    {
      slug: manga.slug,
      userName,
      ...(existing == null ? { bookmarked: false, title: manga.title, coverUrl: manga.coverUrl, status: manga.status } : {}),
      readChapterIds,
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

const CUSTOM_CATS_STORAGE_PREFIX = 'katana.customCategories.v1.';
const CATEGORIES_META_SUFFIX = '|__categories__';
const demoCustomCategories = new Map<string, string[]>();
const demoCategoryChanges = new Changes<Record<string, string[]>>(() => {
  const out: Record<string, string[]> = {};
  for (const [u, list] of demoCustomCategories.entries()) out[u] = list;
  return out;
});

export function loadKatanaCustomCategories(userName: string): string[] {
  try {
    const raw = localStorage.getItem(`${CUSTOM_CATS_STORAGE_PREFIX}${userName || 'guest'}`);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return Array.from(new Set(parsed.map((s) => String(s).trim()).filter(Boolean)));
  } catch {
    return [];
  }
}

export function watchKatanaCustomCategories(userName: string): Source<string[]> {
  if (!userName) {
    return (l) => {
      queueMicrotask(() => l.data([]));
      return () => {};
    };
  }
  if (AgentMode.demo) {
    return (l) =>
      demoCategoryChanges.source({
        data: (all) => l.data(all[userName] ?? loadKatanaCustomCategories(userName)),
      });
  }
  const ref = doc(db, 'katana_bookmarks', `${userName}${CATEGORIES_META_SUFFIX}`);
  return withFirestoreTimeout(
    snapshots(
      (next: (s: DocumentSnapshot<DocumentData>) => void, error) => onSnapshot(ref, next, error),
      (snap): string[] => {
        if (!snap.exists()) return loadKatanaCustomCategories(userName);
        const data = snap.data();
        const cats = Array.isArray(data?.categories)
          ? Array.from(new Set(data.categories.map((s: unknown) => String(s).trim()).filter(Boolean)))
          : [];
        try {
          localStorage.setItem(`${CUSTOM_CATS_STORAGE_PREFIX}${userName}`, JSON.stringify(cats));
        } catch {
          // ignore storage quota errors
        }
        return cats;
      },
    ),
    { label: `katana-categories-${userName}` },
  );
}

export function saveKatanaRecentSearches(userName: string, searches: string[]): void {
  const clean = searches.map((s) => s.trim()).filter(Boolean).slice(0, 8);
  try {
    localStorage.setItem(RECENT_SEARCH_KEY, JSON.stringify(clean));
  } catch {
    // ignore storage quota
  }
  if (!userName || AgentMode.demo) return;
  setDoc(
    doc(db, 'katana_bookmarks', `${userName}${CATEGORIES_META_SUFFIX}`),
    {
      kind: 'categories_meta',
      userName,
      recentSearches: clean,
      updatedAt: Timestamp.now(),
    },
    { merge: true },
  ).catch((err) => Logger.e('KatanaService: saveKatanaRecentSearches failed', err));
}

export function watchKatanaRecentSearches(userName: string): Source<string[]> {
  if (!userName || AgentMode.demo) {
    return (l) => {
      queueMicrotask(() => l.data(getRecentMangaSearches()));
      return () => {};
    };
  }
  const ref = doc(db, 'katana_bookmarks', `${userName}${CATEGORIES_META_SUFFIX}`);
  return withFirestoreTimeout(
    snapshots(
      (next: (s: DocumentSnapshot<DocumentData>) => void, error) => onSnapshot(ref, next, error),
      (snap): string[] => {
        if (!snap.exists()) return getRecentMangaSearches();
        const data = snap.data();
        if (!Array.isArray(data?.recentSearches)) return getRecentMangaSearches();
        const clean = data.recentSearches.map((s: unknown) => String(s).trim()).filter(Boolean).slice(0, 8);
        try {
          localStorage.setItem(RECENT_SEARCH_KEY, JSON.stringify(clean));
        } catch {
          // ignore
        }
        return clean;
      },
    ),
    { label: `katana-recent-searches-${userName}` },
  );
}

export function saveKatanaCustomCategories(userName: string, categories: string[]): void {
  const clean = Array.from(new Set(categories.map((s) => s.trim()).filter(Boolean)));
  try {
    localStorage.setItem(`${CUSTOM_CATS_STORAGE_PREFIX}${userName || 'guest'}`, JSON.stringify(clean));
  } catch {
    // ignore storage quota errors
  }
  if (!userName) return;
  if (AgentMode.demo) {
    demoCustomCategories.set(userName, clean);
    demoCategoryChanges.emit();
    return;
  }
  setDoc(
    doc(db, 'katana_bookmarks', `${userName}${CATEGORIES_META_SUFFIX}`),
    {
      kind: 'categories_meta',
      userName,
      categories: clean,
      updatedAt: Timestamp.now(),
    },
    { merge: true },
  ).catch((err) => Logger.e('KatanaService: saveKatanaCustomCategories failed', err));
}

export async function setKatanaBookmarkCategories(
  manga: Pick<KatanaManga, 'slug' | 'title' | 'coverUrl' | 'status'>,
  userName: string,
  categories: string[],
): Promise<void> {
  if (!userName || !manga.slug) return;
  const clean = Array.from(new Set(categories.map((s) => s.trim()).filter(Boolean)));
  if (AgentMode.demo) {
    const list = demoBookmarks.get(userName) ?? [];
    const idx = list.findIndex((b) => b.slug === manga.slug);
    const cur = idx >= 0 ? list[idx] : undefined;
    const entry: KatanaBookmark = {
      slug: manga.slug,
      title: manga.title || cur?.title || manga.slug,
      coverUrl: manga.coverUrl || cur?.coverUrl || '',
      status: cur?.status || manga.status || 'ongoing',
      addedAt: cur?.addedAt ?? new Date(),
      lastReadAt: cur?.lastReadAt,
      lastReadChapterId: cur?.lastReadChapterId ?? '',
      lastReadPage: cur?.lastReadPage ?? 0,
      lastReadChapterTitle: cur?.lastReadChapterTitle ?? '',
      latestChapterTitle: cur?.latestChapterTitle ?? '',
      recommendedBy: cur?.recommendedBy ?? '',
      recommendationNote: cur?.recommendationNote ?? '',
      readChapterIds: cur?.readChapterIds ?? [],
      bookmarked: true,
      libraryStatus: cur?.libraryStatus ?? 'reading',
      categories: clean,
      userScore: cur?.userScore,
      rereadCount: cur?.rereadCount,
      startedAt: cur?.startedAt,
      anilistId: cur?.anilistId,
      malId: cur?.malId,
      trackerNote: cur?.trackerNote,
      finishedAt: cur?.finishedAt,
    };
    const next = [...list];
    if (idx >= 0) next[idx] = entry;
    else next.unshift(entry);
    demoBookmarks.set(userName, next);
    demoChanges.emit();
    return;
  }
  const existing = await getKatanaBookmark(manga.slug, userName);
  await setDoc(
    doc(db, 'katana_bookmarks', `${userName}|${manga.slug}`),
    {
      slug: manga.slug,
      title: manga.title || existing?.title || manga.slug,
      coverUrl: manga.coverUrl || existing?.coverUrl || '',
      status: existing?.status || manga.status || 'ongoing',
      userName,
      bookmarked: true,
      categories: clean,
      ...(existing == null ? { addedAt: Timestamp.now() } : {}),
    },
    { merge: true },
  );
}

export interface KatanaTrackerPatch {
  userScore?: number | null;
  rereadCount?: number | null;
  startedAt?: Date | null;
  anilistId?: string | null;
  malId?: string | null;
  trackerNote?: string | null;
  malScore?: number | null;
  malRank?: number | null;
  malTotalChapters?: number | null;
  malStatus?: string | null;
  lastSyncedAt?: Date | null;
  notifyOnUpdate?: boolean;
  autoDownload?: boolean;
}

export interface MalTrackerSnapshot {
  malId: string;
  title: string;
  score?: number;
  rank?: number;
  totalChapters?: number;
  status?: string;
  url: string;
}

/** Looks up live MyAnimeList metadata for a manga via Everglow's `proxyCatalog` Jikan proxy. */
export async function lookupMalManga(title: string, malId?: string): Promise<MalTrackerSnapshot | null> {
  const cleanId = malId?.trim();
  if (AgentMode.demo) {
    const hash = Array.from(title).reduce((acc, ch) => (acc * 31 + ch.charCodeAt(0)) % 90000, 10000);
    const id = cleanId && /^\d+$/.test(cleanId) ? cleanId : String(hash);
    return {
      malId: id,
      title,
      score: Number((7.8 + (hash % 14) * 0.1).toFixed(2)),
      rank: 120 + (hash % 850),
      totalChapters: 48 + (hash % 90),
      status: 'Publishing',
      url: `https://myanimelist.net/manga/${id}`,
    };
  }
  try {
    if (cleanId && /^\d+$/.test(cleanId)) {
      const resp = await catalogProxyGet('jikan', `manga/${cleanId}`, { timeoutMs: 12000 });
      if (resp.ok) {
        const json = (await resp.json()) as { data?: Record<string, unknown> };
        const d = json.data;
        if (d && d.mal_id) {
          return {
            malId: String(d.mal_id),
            title: String(d.title ?? title),
            score: typeof d.score === 'number' ? d.score : undefined,
            rank: typeof d.rank === 'number' ? d.rank : undefined,
            totalChapters: typeof d.chapters === 'number' ? d.chapters : undefined,
            status: typeof d.status === 'string' ? d.status : undefined,
            url: typeof d.url === 'string' ? d.url : `https://myanimelist.net/manga/${d.mal_id}`,
          };
        }
      }
    }
    const resp = await catalogProxyGet('jikan', 'manga', {
      query: { q: title.trim(), limit: '3', sfw: 'true' },
      timeoutMs: 12000,
    });
    if (!resp.ok) return null;
    const json = (await resp.json()) as { data?: Array<Record<string, unknown>> };
    const list = Array.isArray(json.data) ? json.data : [];
    const norm = title.trim().toLowerCase();
    const match =
      list.find((m) => String(m.title ?? '').trim().toLowerCase() === norm) ??
      list.find((m) => String(m.title_english ?? '').trim().toLowerCase() === norm) ??
      list[0];
    if (!match || !match.mal_id) return null;
    return {
      malId: String(match.mal_id),
      title: String(match.title ?? title),
      score: typeof match.score === 'number' ? match.score : undefined,
      rank: typeof match.rank === 'number' ? match.rank : undefined,
      totalChapters: typeof match.chapters === 'number' ? match.chapters : undefined,
      status: typeof match.status === 'string' ? match.status : undefined,
      url: typeof match.url === 'string' ? match.url : `https://myanimelist.net/manga/${match.mal_id}`,
    };
  } catch (err) {
    Logger.w(`KatanaService: lookupMalManga failed: ${String(err)}`);
    return null;
  }
}

const HIDDEN_CATS_PREFIX = 'katana_hidden_cats_v1_';
const AUTO_DL_KEY = 'katana_auto_dl_next_v1';

export function loadKatanaHiddenCategories(userName: string): string[] {
  try {
    const raw = localStorage.getItem(`${HIDDEN_CATS_PREFIX}${userName || 'guest'}`);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.map(String).filter(Boolean) : [];
  } catch {
    return [];
  }
}

export function saveKatanaHiddenCategories(userName: string, hidden: string[]): void {
  const clean = Array.from(new Set(hidden.map((s) => s.trim()).filter(Boolean)));
  try {
    localStorage.setItem(`${HIDDEN_CATS_PREFIX}${userName || 'guest'}`, JSON.stringify(clean));
  } catch {
    // ignore storage errors
  }
}

export function loadKatanaAutoDownloadCount(): number {
  try {
    const n = Number(localStorage.getItem(AUTO_DL_KEY) ?? '0');
    return [0, 1, 3, 5].includes(n) ? n : 0;
  } catch {
    return 0;
  }
}

export function saveKatanaAutoDownloadCount(count: number): void {
  try {
    localStorage.setItem(AUTO_DL_KEY, String(count));
  } catch {
    // ignore storage errors
  }
}

export async function saveKatanaTrackerData(
  manga: Pick<KatanaManga, 'slug' | 'title' | 'coverUrl' | 'status'>,
  userName: string,
  patch: KatanaTrackerPatch,
): Promise<void> {
  if (!userName || !manga.slug) return;
  if (AgentMode.demo) {
    const list = demoBookmarks.get(userName) ?? [];
    const idx = list.findIndex((b) => b.slug === manga.slug);
    const cur = idx >= 0 ? list[idx] : undefined;
    const entry: KatanaBookmark = {
      slug: manga.slug,
      title: manga.title || cur?.title || manga.slug,
      coverUrl: manga.coverUrl || cur?.coverUrl || '',
      status: cur?.status || manga.status || 'ongoing',
      addedAt: cur?.addedAt ?? new Date(),
      lastReadAt: cur?.lastReadAt,
      lastReadChapterId: cur?.lastReadChapterId ?? '',
      lastReadPage: cur?.lastReadPage ?? 0,
      lastReadChapterTitle: cur?.lastReadChapterTitle ?? '',
      latestChapterTitle: cur?.latestChapterTitle ?? '',
      recommendedBy: cur?.recommendedBy ?? '',
      recommendationNote: cur?.recommendationNote ?? '',
      readChapterIds: cur?.readChapterIds ?? [],
      bookmarked: cur?.bookmarked ?? true,
      libraryStatus: cur?.libraryStatus ?? 'reading',
      categories: cur?.categories ?? [],
      userScore: patch.userScore === null ? undefined : patch.userScore !== undefined ? patch.userScore : cur?.userScore,
      rereadCount: patch.rereadCount === null ? undefined : patch.rereadCount !== undefined ? patch.rereadCount : cur?.rereadCount,
      startedAt: patch.startedAt === null ? undefined : patch.startedAt !== undefined ? patch.startedAt : cur?.startedAt,
      anilistId: patch.anilistId === null ? undefined : patch.anilistId !== undefined ? patch.anilistId.trim() || undefined : cur?.anilistId,
      malId: patch.malId === null ? undefined : patch.malId !== undefined ? patch.malId.trim() || undefined : cur?.malId,
      trackerNote: patch.trackerNote === null ? undefined : patch.trackerNote !== undefined ? patch.trackerNote.trim() || undefined : cur?.trackerNote,
      malScore: patch.malScore === null ? undefined : patch.malScore !== undefined ? patch.malScore : cur?.malScore,
      malRank: patch.malRank === null ? undefined : patch.malRank !== undefined ? patch.malRank : cur?.malRank,
      malTotalChapters: patch.malTotalChapters === null ? undefined : patch.malTotalChapters !== undefined ? patch.malTotalChapters : cur?.malTotalChapters,
      malStatus: patch.malStatus === null ? undefined : patch.malStatus !== undefined ? patch.malStatus : cur?.malStatus,
      lastSyncedAt: patch.lastSyncedAt === null ? undefined : patch.lastSyncedAt !== undefined ? patch.lastSyncedAt : cur?.lastSyncedAt,
      notifyOnUpdate: patch.notifyOnUpdate !== undefined ? patch.notifyOnUpdate : cur?.notifyOnUpdate,
      autoDownload: patch.autoDownload !== undefined ? patch.autoDownload : cur?.autoDownload,
      finishedAt: cur?.finishedAt,
    };
    const next = [...list];
    if (idx >= 0) next[idx] = entry;
    else next.unshift(entry);
    demoBookmarks.set(userName, next);
    demoChanges.emit();
    return;
  }
  const existing = await getKatanaBookmark(manga.slug, userName);
  const payload: Record<string, unknown> = {
    slug: manga.slug,
    title: manga.title || existing?.title || manga.slug,
    coverUrl: manga.coverUrl || existing?.coverUrl || '',
    status: existing?.status || manga.status || 'ongoing',
    userName,
    ...(existing == null ? { bookmarked: true, libraryStatus: 'reading', addedAt: Timestamp.now() } : {}),
  };
  if (patch.userScore !== undefined) payload.userScore = patch.userScore === null ? deleteField() : patch.userScore;
  if (patch.rereadCount !== undefined) payload.rereadCount = patch.rereadCount === null ? deleteField() : patch.rereadCount;
  if (patch.startedAt !== undefined) payload.startedAt = patch.startedAt === null ? deleteField() : Timestamp.fromDate(patch.startedAt);
  if (patch.anilistId !== undefined) payload.anilistId = patch.anilistId ? patch.anilistId.trim() : deleteField();
  if (patch.malId !== undefined) payload.malId = patch.malId ? patch.malId.trim() : deleteField();
  if (patch.trackerNote !== undefined) payload.trackerNote = patch.trackerNote ? patch.trackerNote.trim() : deleteField();
  if (patch.malScore !== undefined) payload.malScore = patch.malScore === null ? deleteField() : patch.malScore;
  if (patch.malRank !== undefined) payload.malRank = patch.malRank === null ? deleteField() : patch.malRank;
  if (patch.malTotalChapters !== undefined) payload.malTotalChapters = patch.malTotalChapters === null ? deleteField() : patch.malTotalChapters;
  if (patch.malStatus !== undefined) payload.malStatus = patch.malStatus ? patch.malStatus : deleteField();
  if (patch.lastSyncedAt !== undefined) payload.lastSyncedAt = patch.lastSyncedAt === null ? deleteField() : Timestamp.fromDate(patch.lastSyncedAt);
  if (patch.notifyOnUpdate !== undefined) payload.notifyOnUpdate = patch.notifyOnUpdate;
  if (patch.autoDownload !== undefined) payload.autoDownload = patch.autoDownload;
  await setDoc(doc(db, 'katana_bookmarks', `${userName}|${manga.slug}`), payload, { merge: true });
}

export function exportKatanaLibraryJson(bookmarks: KatanaBookmark[], categories: string[]): string {
  return JSON.stringify(
    {
      format: 'mangacelestia-backup-v1',
      exportedAt: new Date().toISOString(),
      categories,
      bookmarks: bookmarks.map((b) => ({
        ...b,
        addedAt: b.addedAt.toISOString(),
        lastReadAt: b.lastReadAt?.toISOString(),
        startedAt: b.startedAt?.toISOString(),
        finishedAt: b.finishedAt?.toISOString(),
      })),
    },
    null,
    2,
  );
}

function xmlEsc(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

export function exportKatanaLibraryMalXml(bookmarks: KatanaBookmark[]): string {
  const statusMap: Record<KatanaLibraryStatus, string> = {
    reading: 'Reading',
    completed: 'Completed',
    on_hold: 'On-Hold',
    planned: 'Plan to Read',
    dropped: 'Dropped',
  };
  const rows = bookmarks
    .filter((b) => b.bookmarked)
    .map((b) => {
      const malStatus = statusMap[b.libraryStatus ?? (b.finishedAt ? 'completed' : 'reading')];
      const chNum = Math.max(b.readChapterIds.length, Number(katanaChapterNumFromId(b.lastReadChapterId)) || 0);
      return [
        '  <manga>',
        `    <manga_mangadb_id>${xmlEsc(b.malId ?? '0')}</manga_mangadb_id>`,
        `    <manga_title><![CDATA[${b.title}]]></manga_title>`,
        `    <my_read_chapters>${Math.floor(chNum)}</my_read_chapters>`,
        `    <my_score>${b.userScore ?? 0}</my_score>`,
        `    <my_status>${malStatus}</my_status>`,
        `    <my_times_read>${b.rereadCount ?? 0}</my_times_read>`,
        `    <update_on_import>1</update_on_import>`,
        '  </manga>',
      ].join('\n');
    })
    .join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>\n<myanimelist>\n${rows}\n</myanimelist>\n`;
}

export async function importKatanaLibraryJson(raw: string, userName: string): Promise<number> {
  if (!userName) return 0;
  const parsed = JSON.parse(raw) as { categories?: unknown; bookmarks?: unknown };
  if (Array.isArray(parsed.categories)) {
    const existing = loadKatanaCustomCategories(userName);
    const merged = Array.from(new Set([...existing, ...parsed.categories.map((c) => String(c).trim()).filter(Boolean)]));
    saveKatanaCustomCategories(userName, merged);
  }
  if (!Array.isArray(parsed.bookmarks)) return 0;
  let imported = 0;
  for (const item of parsed.bookmarks) {
    if (!item || typeof item !== 'object') continue;
    const rec = item as Record<string, unknown>;
    const slug = String(rec.slug ?? '').trim();
    const title = String(rec.title ?? '').trim();
    if (!slug || !title) continue;
    const status = String(rec.status ?? 'ongoing');
    const coverUrl = String(rec.coverUrl ?? '');
    const libStatus: KatanaLibraryStatus =
      rec.libraryStatus === 'reading' ||
      rec.libraryStatus === 'completed' ||
      rec.libraryStatus === 'on_hold' ||
      rec.libraryStatus === 'planned' ||
      rec.libraryStatus === 'dropped'
        ? rec.libraryStatus
        : 'reading';
    await setKatanaLibraryStatus({ slug, title, coverUrl, status }, userName, libStatus);
    if (Array.isArray(rec.categories) && rec.categories.length > 0) {
      await setKatanaBookmarkCategories({ slug, title, coverUrl, status }, userName, rec.categories.map(String));
    }
    const patch: KatanaTrackerPatch = {};
    if (typeof rec.userScore === 'number') patch.userScore = rec.userScore;
    if (typeof rec.rereadCount === 'number') patch.rereadCount = rec.rereadCount;
    if (typeof rec.anilistId === 'string') patch.anilistId = rec.anilistId;
    if (typeof rec.malId === 'string') patch.malId = rec.malId;
    if (typeof rec.trackerNote === 'string') patch.trackerNote = rec.trackerNote;
    if (Object.keys(patch).length > 0) {
      await saveKatanaTrackerData({ slug, title, coverUrl, status }, userName, patch);
    }
    imported++;
  }
  return imported;
}

/** Imports a MyAnimeList / AniList XML export into the user's Manga Celestia library. */
export async function importKatanaLibraryMalXml(xml: string, userName: string): Promise<number> {
  if (!userName) return 0;
  const docXml = new DOMParser().parseFromString(xml, 'text/xml');
  const nodes = Array.from(docXml.querySelectorAll('manga'));
  if (nodes.length === 0) return 0;
  const statusMap: Record<string, KatanaLibraryStatus> = {
    reading: 'reading',
    completed: 'completed',
    'on-hold': 'on_hold',
    'plan to read': 'planned',
    dropped: 'dropped',
  };
  let imported = 0;
  for (const node of nodes) {
    const title = (node.querySelector('manga_title')?.textContent ?? '').trim();
    if (!title) continue;
    const malId = (node.querySelector('manga_mangadb_id')?.textContent ?? '').trim();
    const rawStatus = (node.querySelector('my_status')?.textContent ?? '').trim().toLowerCase();
    const libStatus: KatanaLibraryStatus = statusMap[rawStatus] ?? 'reading';
    const score = Number.parseInt((node.querySelector('my_score')?.textContent ?? '0').trim(), 10) || 0;
    const reread = Number.parseInt((node.querySelector('my_times_read')?.textContent ?? '0').trim(), 10) || 0;
    const slug = title
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '') || `mal-${malId || imported}`;
    await setKatanaLibraryStatus({ slug, title, coverUrl: '', status: 'ongoing' }, userName, libStatus);
    const patch: KatanaTrackerPatch = { lastSyncedAt: new Date() };
    if (malId && malId !== '0') patch.malId = malId;
    if (score >= 1 && score <= 10) patch.userScore = score;
    if (reread > 0) patch.rereadCount = reread;
    await saveKatanaTrackerData({ slug, title, coverUrl: '', status: 'ongoing' }, userName, patch);
    imported++;
  }
  return imported;
}

export interface KatanaHistoryEntry {
  slug: string;
  title: string;
  coverUrl: string;
  chapterId: string;
  chapterTitle: string;
  page?: number;
  readAt: number;
}

const HISTORY_KEY_PREFIX = 'katana_history_v1_';
const NOTIFIED_ALERTS_PREFIX = 'katana_notified_alerts_v1_';

function buildDemoHistory(): KatanaHistoryEntry[] {
  const now = Date.now();
  return [
    {
      slug: 'frieren-beyond-journeys-end',
      title: "Frieren: Beyond Journey's End",
      coverUrl: '/images/demo/manga-frieren.svg',
      chapterId: 'c139',
      chapterTitle: 'Chapter 139: A Quiet Lantern',
      page: 14,
      readAt: now - 1000 * 60 * 38,
    },
    {
      slug: 'solo-leveling-ragnarok',
      title: 'Solo Leveling: Ragnarok',
      coverUrl: '/images/demo/manga-solo.svg',
      chapterId: 'c41',
      chapterTitle: 'Chapter 41: Shadow Sovereign',
      page: 22,
      readAt: now - 1000 * 60 * 60 * 5,
    },
    {
      slug: 'witch-hat-atelier',
      title: 'Witch Hat Atelier',
      coverUrl: '/images/demo/manga-witch.svg',
      chapterId: 'c82',
      chapterTitle: 'Chapter 82: Silver Ink',
      page: 9,
      readAt: now - 1000 * 60 * 60 * 28,
    },
    {
      slug: 'omniscient-readers-viewpoint',
      title: "Omniscient Reader's Viewpoint",
      coverUrl: '/images/demo/manga-orv.svg',
      chapterId: 'c244',
      chapterTitle: 'Chapter 244: Constellation Banquet',
      page: 18,
      readAt: now - 1000 * 60 * 60 * 52,
    },
  ];
}

const HISTORY_META_SUFFIX = '|__history__';
const PREFS_META_SUFFIX = '|__prefs__';
const ALERT_PREFS_PREFIX = 'katana_alert_prefs_v1_';
const LAST_DIGEST_PREFIX = 'katana_last_digest_v1_';
const USER_PREFS_PREFIX = 'katana_user_prefs_v1_';

export interface KatanaAlertPrefs {
  frequency: 'instant' | 'daily';
  quietHours: boolean;
}

export interface KatanaUserPrefs {
  alertPrefs: KatanaAlertPrefs;
  wifiOnlyDownloads: boolean;
  autoDownloadNext: number;
  autoDownloadCategories?: string[];
  themeMode?: 'dark' | 'oled' | 'light' | 'sepia';
}

const DEFAULT_ALERT_PREFS: KatanaAlertPrefs = {
  frequency: 'instant',
  quietHours: false,
};

const DEFAULT_USER_PREFS: KatanaUserPrefs = {
  alertPrefs: DEFAULT_ALERT_PREFS,
  wifiOnlyDownloads: false,
  autoDownloadNext: 0,
  autoDownloadCategories: [],
};

export function loadKatanaAlertPrefs(userName: string): KatanaAlertPrefs {
  if (!userName) return DEFAULT_ALERT_PREFS;
  try {
    const raw = localStorage.getItem(`${ALERT_PREFS_PREFIX}${userName}`);
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<KatanaAlertPrefs>;
      return {
        frequency: parsed.frequency === 'daily' ? 'daily' : 'instant',
        quietHours: Boolean(parsed.quietHours),
      };
    }
  } catch {
    // ignore storage errors
  }
  return DEFAULT_ALERT_PREFS;
}

export function loadKatanaUserPrefs(userName: string): KatanaUserPrefs {
  if (!userName) return DEFAULT_USER_PREFS;
  try {
    const raw = localStorage.getItem(`${USER_PREFS_PREFIX}${userName}`);
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<KatanaUserPrefs>;
      return {
        alertPrefs: {
          frequency: parsed.alertPrefs?.frequency === 'daily' ? 'daily' : loadKatanaAlertPrefs(userName).frequency,
          quietHours: parsed.alertPrefs?.quietHours ?? loadKatanaAlertPrefs(userName).quietHours,
        },
        wifiOnlyDownloads: Boolean(parsed.wifiOnlyDownloads),
        autoDownloadNext: typeof parsed.autoDownloadNext === 'number' && parsed.autoDownloadNext >= 0 ? parsed.autoDownloadNext : 0,
        autoDownloadCategories: Array.isArray(parsed.autoDownloadCategories)
          ? parsed.autoDownloadCategories.filter((c): c is string => typeof c === 'string')
          : [],
        themeMode:
          parsed.themeMode === 'dark' ||
          parsed.themeMode === 'oled' ||
          parsed.themeMode === 'light' ||
          parsed.themeMode === 'sepia'
            ? parsed.themeMode
            : undefined,
      };
    }
  } catch {
    // ignore storage errors
  }
  return {
    ...DEFAULT_USER_PREFS,
    alertPrefs: loadKatanaAlertPrefs(userName),
  };
}

export function saveKatanaUserPrefs(userName: string, partial: Partial<KatanaUserPrefs>): KatanaUserPrefs {
  const current = loadKatanaUserPrefs(userName);
  const next: KatanaUserPrefs = {
    ...current,
    ...partial,
    alertPrefs: partial.alertPrefs ? { ...current.alertPrefs, ...partial.alertPrefs } : current.alertPrefs,
  };
  if (!userName) return next;
  try {
    localStorage.setItem(`${USER_PREFS_PREFIX}${userName}`, JSON.stringify(next));
    localStorage.setItem(`${ALERT_PREFS_PREFIX}${userName}`, JSON.stringify(next.alertPrefs));
  } catch {
    // ignore storage errors
  }
  if (!AgentMode.demo) {
    setDoc(
      doc(db, 'katana_bookmarks', `${userName}${PREFS_META_SUFFIX}`),
      {
        kind: 'prefs_meta',
        userName,
        alertPrefs: next.alertPrefs,
        wifiOnlyDownloads: next.wifiOnlyDownloads,
        autoDownloadNext: next.autoDownloadNext,
        autoDownloadCategories: next.autoDownloadCategories ?? [],
        ...(next.themeMode ? { themeMode: next.themeMode } : {}),
        updatedAt: Timestamp.now(),
      },
      { merge: true },
    ).catch((err) => Logger.e('KatanaService: saveKatanaUserPrefs failed', err));
  }
  return next;
}

export function watchKatanaUserPrefs(userName: string): Source<KatanaUserPrefs> {
  if (!userName) {
    return (l) => {
      queueMicrotask(() => l.data(DEFAULT_USER_PREFS));
      return () => {};
    };
  }
  if (AgentMode.demo) {
    return (l) => {
      queueMicrotask(() => l.data(loadKatanaUserPrefs(userName)));
      return () => {};
    };
  }
  const ref = doc(db, 'katana_bookmarks', `${userName}${PREFS_META_SUFFIX}`);
  return withFirestoreTimeout(
    snapshots(
      (next: (s: DocumentSnapshot<DocumentData>) => void, error) => onSnapshot(ref, next, error),
      (snap): KatanaUserPrefs => {
        if (!snap.exists()) return loadKatanaUserPrefs(userName);
        const data = snap.data();
        const merged: KatanaUserPrefs = {
          alertPrefs: {
            frequency: data?.alertPrefs?.frequency === 'daily' ? 'daily' : 'instant',
            quietHours: Boolean(data?.alertPrefs?.quietHours),
          },
          wifiOnlyDownloads: Boolean(data?.wifiOnlyDownloads),
          autoDownloadNext: typeof data?.autoDownloadNext === 'number' && data.autoDownloadNext >= 0 ? data.autoDownloadNext : 0,
          autoDownloadCategories: Array.isArray(data?.autoDownloadCategories)
            ? data.autoDownloadCategories.filter((c: unknown): c is string => typeof c === 'string')
            : [],
          themeMode:
            data?.themeMode === 'dark' ||
            data?.themeMode === 'oled' ||
            data?.themeMode === 'light' ||
            data?.themeMode === 'sepia'
              ? data.themeMode
              : undefined,
        };
        try {
          localStorage.setItem(`${USER_PREFS_PREFIX}${userName}`, JSON.stringify(merged));
          localStorage.setItem(`${ALERT_PREFS_PREFIX}${userName}`, JSON.stringify(merged.alertPrefs));
        } catch {
          // ignore
        }
        return merged;
      },
    ),
    { label: `katana-prefs-${userName}` },
  );
}

export function saveKatanaAlertPrefs(userName: string, prefs: KatanaAlertPrefs): void {
  saveKatanaUserPrefs(userName, { alertPrefs: prefs });
}

function isQuietHoursNow(): boolean {
  const hour = new Date().getHours();
  return hour >= 22 || hour < 8;
}

const demoHistoryStore = new Map<string, KatanaHistoryEntry[]>();
const demoHistoryChanges = new Set<() => void>();
function emitDemoHistoryChange() {
  for (const fn of demoHistoryChanges) fn();
}

function persistKatanaHistoryToFirestore(userName: string, entries: KatanaHistoryEntry[]): void {
  if (!userName || AgentMode.demo) return;
  setDoc(
    doc(db, 'katana_bookmarks', `${userName}${HISTORY_META_SUFFIX}`),
    {
      kind: 'history_meta',
      userName,
      entries: entries.slice(0, 80),
      updatedAt: Timestamp.now(),
    },
    { merge: true },
  ).catch((err) => Logger.e('KatanaService: saveKatanaHistory failed', err));
}

export function watchKatanaHistory(userName: string): Source<KatanaHistoryEntry[]> {
  if (!userName) {
    return (l) => {
      queueMicrotask(() => l.data([]));
      return () => {};
    };
  }
  if (AgentMode.demo) {
    return (l) => {
      const emit = () => l.data(demoHistoryStore.get(userName) ?? loadKatanaHistory(userName));
      queueMicrotask(emit);
      demoHistoryChanges.add(emit);
      return () => {
        demoHistoryChanges.delete(emit);
      };
    };
  }
  const ref = doc(db, 'katana_bookmarks', `${userName}${HISTORY_META_SUFFIX}`);
  return withFirestoreTimeout(
    snapshots(
      (next: (s: DocumentSnapshot<DocumentData>) => void, error) => onSnapshot(ref, next, error),
      (snap): KatanaHistoryEntry[] => {
        if (!snap.exists()) return loadKatanaHistory(userName);
        const data = snap.data();
        if (!Array.isArray(data?.entries)) return loadKatanaHistory(userName);
        const entries = (data.entries as KatanaHistoryEntry[])
          .filter((e) => e && typeof e.slug === 'string' && typeof e.chapterId === 'string')
          .slice(0, 100);
        try {
          localStorage.setItem(`${HISTORY_KEY_PREFIX}${userName}`, JSON.stringify(entries));
        } catch {
          // ignore
        }
        return entries;
      },
    ),
    { label: `katana-history-${userName}` },
  );
}

export function loadKatanaHistory(userName: string): KatanaHistoryEntry[] {
  if (!userName) return [];
  if (AgentMode.demo && demoHistoryStore.has(userName)) {
    return demoHistoryStore.get(userName) ?? [];
  }
  try {
    const raw = localStorage.getItem(`${HISTORY_KEY_PREFIX}${userName}`);
    if (raw) {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) return parsed;
    }
  } catch {
    // ignore storage errors
  }
  return AgentMode.demo ? buildDemoHistory() : [];
}

export function recordKatanaHistory(userName: string, entry: KatanaHistoryEntry): KatanaHistoryEntry[] {
  if (!userName || !entry.slug || !entry.chapterId) return [];
  const existing = loadKatanaHistory(userName).filter(
    (item) => !(item.slug === entry.slug && item.chapterId === entry.chapterId),
  );
  const next = [entry, ...existing].slice(0, 100);
  try {
    localStorage.setItem(`${HISTORY_KEY_PREFIX}${userName}`, JSON.stringify(next));
  } catch {
    // ignore storage errors
  }
  if (AgentMode.demo) {
    demoHistoryStore.set(userName, next);
    emitDemoHistoryChange();
  } else {
    persistKatanaHistoryToFirestore(userName, next);
  }
  return next;
}

export function removeKatanaHistoryEntry(userName: string, slug: string, chapterId: string): KatanaHistoryEntry[] {
  if (!userName) return [];
  const next = loadKatanaHistory(userName).filter(
    (item) => !(item.slug === slug && item.chapterId === chapterId),
  );
  try {
    localStorage.setItem(`${HISTORY_KEY_PREFIX}${userName}`, JSON.stringify(next));
  } catch {
    // ignore storage errors
  }
  if (AgentMode.demo) {
    demoHistoryStore.set(userName, next);
    emitDemoHistoryChange();
  } else {
    persistKatanaHistoryToFirestore(userName, next);
  }
  return next;
}

export function clearKatanaHistory(userName: string): void {
  if (!userName) return;
  try {
    localStorage.setItem(`${HISTORY_KEY_PREFIX}${userName}`, JSON.stringify([]));
  } catch {
    // ignore storage errors
  }
  if (AgentMode.demo) {
    demoHistoryStore.set(userName, []);
    emitDemoHistoryChange();
  } else {
    persistKatanaHistoryToFirestore(userName, []);
  }
}

export interface KatanaAlertHit {
  slug: string;
  title: string;
  coverUrl: string;
  chapterId: string;
  chapterTitle: string;
}

export function markKatanaAlertSeen(userName: string, slug: string, chapterId: string): void {
  if (!userName || !slug || !chapterId) return;
  try {
    const raw = localStorage.getItem(`${NOTIFIED_ALERTS_PREFIX}${userName}`);
    const seenMap: Record<string, string> = raw ? (JSON.parse(raw) as Record<string, string>) : {};
    if (seenMap[slug] === chapterId) return;
    seenMap[slug] = chapterId;
    localStorage.setItem(`${NOTIFIED_ALERTS_PREFIX}${userName}`, JSON.stringify(seenMap));
  } catch {
    // ignore storage errors
  }
}

/**
 * Checks alert-enabled bookmarks against live catalog updates.
 * Fires a real browser Notification when permission is granted and a previously
 * unseen chapter arrives (instant or batched once-a-day digest), deferring
 * during quiet hours instead of dropping alerts.
 */
export function checkKatanaChapterAlerts(
  userName: string,
  bookmarks: KatanaBookmark[],
  catalog: KatanaManga[],
): KatanaAlertHit[] {
  if (!userName || bookmarks.length === 0 || catalog.length === 0) return [];
  const bySlug = new Map(catalog.map((m) => [m.slug, m]));
  let seenMap: Record<string, string> = {};
  try {
    const raw = localStorage.getItem(`${NOTIFIED_ALERTS_PREFIX}${userName}`);
    if (raw) seenMap = JSON.parse(raw) as Record<string, string>;
  } catch {
    seenMap = {};
  }

  const hits: KatanaAlertHit[] = [];
  const unseenHits: KatanaAlertHit[] = [];
  let mapChanged = false;
  const alertPrefs = loadKatanaAlertPrefs(userName);
  const suppressByQuietHours = alertPrefs.quietHours && isQuietHoursNow();
  const canBrowserNotify =
    typeof window !== 'undefined' &&
    'Notification' in window &&
    Notification.permission === 'granted' &&
    !AgentMode.demo &&
    !suppressByQuietHours;

  for (const bm of bookmarks) {
    if (bm.notifyOnUpdate === false) continue;
    const item = bySlug.get(bm.slug);
    const latest = item?.latestChapter;
    if (!item || !latest?.id) continue;
    const readIds = new Set(bm.readChapterIds ?? []);
    if (readIds.has(latest.id) || bm.lastReadChapterId === latest.id) continue;
    const hit: KatanaAlertHit = {
      slug: item.slug,
      title: item.title,
      coverUrl: item.coverUrl,
      chapterId: latest.id,
      chapterTitle: latest.title || `Chapter ${latest.num}`,
    };
    hits.push(hit);
    if (seenMap[item.slug] !== latest.id) {
      unseenHits.push(hit);
    }
  }

  if (canBrowserNotify && unseenHits.length > 0) {
    if (alertPrefs.frequency === 'instant') {
      for (const hit of unseenHits) {
        try {
          new Notification(`${hit.title} — New Chapter`, {
            body: `${hit.chapterTitle} is ready to read in Manga Celestia.`,
            tag: `manga-update-${hit.slug}`,
          });
          seenMap[hit.slug] = hit.chapterId;
          mapChanged = true;
        } catch {
          // ignore notification constructor errors on restricted browsers
        }
      }
    } else {
      let lastDigestAt = 0;
      try {
        lastDigestAt = Number(localStorage.getItem(`${LAST_DIGEST_PREFIX}${userName}`) || '0') || 0;
      } catch {
        lastDigestAt = 0;
      }
      const ONE_DAY_MS = 24 * 60 * 60 * 1000;
      if (Date.now() - lastDigestAt >= ONE_DAY_MS) {
        const preview = unseenHits.slice(0, 3).map((h) => `${h.title} (${h.chapterTitle})`).join(', ');
        const extra = unseenHits.length > 3 ? ` +${unseenHits.length - 3} more` : '';
        try {
          new Notification(
            unseenHits.length === 1
              ? `${unseenHits[0].title} — Daily Digest`
              : `${unseenHits.length} manga updated today`,
            {
              body: `${preview}${extra}`,
              tag: `manga-daily-digest-${userName}`,
            },
          );
          for (const hit of unseenHits) {
            seenMap[hit.slug] = hit.chapterId;
          }
          mapChanged = true;
          try {
            localStorage.setItem(`${LAST_DIGEST_PREFIX}${userName}`, String(Date.now()));
          } catch {
            // ignore
          }
        } catch {
          // ignore notification constructor errors
        }
      }
    }
  }

  if (mapChanged) {
    try {
      localStorage.setItem(`${NOTIFIED_ALERTS_PREFIX}${userName}`, JSON.stringify(seenMap));
    } catch {
      // ignore storage errors
    }
  }
  return hits;
}

export interface MangaDexCatalogOptions {
  query?: string;
  page?: number;
  status?: 'all' | 'ongoing' | 'completed';
  demographic?: string;
  orderBy?: string;
  include?: string[];
  exclude?: string[];
  genreMode?: string;
  chapters?: string;
  author?: string;
}

/**
 * Secondary catalog source backed by our Cloud Function MangaDex proxy
 * so readers can browse/search MangaDex with pagination and filters.
 */
export async function searchMangaDexCatalog(
  optsOrQuery: string | MangaDexCatalogOptions,
): Promise<KatanaPageResult> {
  const opts: MangaDexCatalogOptions = typeof optsOrQuery === 'string' ? { query: optsOrQuery } : optsOrQuery;
  const q = (opts.query ?? '').trim();
  const page = Math.max(1, opts.page ?? 1);
  const pageSize = 24;

  const applySharedFilters = (list: KatanaManga[]): KatanaManga[] => {
    let out = [...list];
    if (opts.status && opts.status !== 'all') {
      out = out.filter((m) => m.status.toLowerCase() === opts.status);
    }
    if (opts.demographic && opts.demographic !== 'all') {
      const target = opts.demographic.toLowerCase();
      out = out.filter(
        (m) =>
          (m.demographic ?? '').toLowerCase() === target ||
          m.genres.some((g) => g.slug === target || g.name.toLowerCase() === target),
      );
    }
    if (opts.include && opts.include.length > 0) {
      const inc = opts.include.map((s) => s.toLowerCase());
      out = out.filter((m) => {
        const slugs = m.genres.map((g) => g.slug);
        return opts.genreMode === 'or' ? inc.some((s) => slugs.includes(s)) : inc.every((s) => slugs.includes(s));
      });
    }
    if (opts.exclude && opts.exclude.length > 0) {
      const exc = new Set(opts.exclude.map((s) => s.toLowerCase()));
      out = out.filter((m) => !m.genres.some((g) => exc.has(g.slug)));
    }
    if (opts.chapters) {
      const minCh = Number(opts.chapters) || 0;
      if (minCh > 1) {
        out = out.filter((m) => {
          const chCount = m.chapterCount ?? (m.latestChapter ? Number.parseFloat(m.latestChapter.num) || 0 : m.chapters.length);
          return chCount >= minCh;
        });
      }
    }
    if (opts.author && opts.author.trim()) {
      const aq = opts.author.trim().toLowerCase();
      out = out.filter((m) => m.authors.some((a) => a.toLowerCase().includes(aq)));
    }
    if (opts.orderBy === 'az') out.sort((a, b) => a.title.localeCompare(b.title));
    return out;
  };

  if (AgentMode.demo) {
    const catalog = buildDemoCatalog();
    const filtered = applySharedFilters(
      q
        ? catalog.filter(
            (m) =>
              m.title.toLowerCase().includes(q.toLowerCase()) ||
              m.genres.some((g) => g.name.toLowerCase().includes(q.toLowerCase())),
          )
        : catalog,
    ).map((m) => ({
      ...m,
      summary: m.summary ? `[MangaDex] ${m.summary}` : 'Available via MangaDex catalog source.',
    }));
    const demoPageSize = 8;
    const totalPages = Math.max(1, Math.ceil(filtered.length / demoPageSize));
    const start = (page - 1) * demoPageSize;
    return {
      items: filtered.slice(start, start + demoPageSize),
      page,
      hasPrev: page > 1,
      hasNext: page < totalPages,
      totalPages,
      totalResults: filtered.length,
    };
  }
  if (!ConnectivityService.isOnline) {
    return { items: [], page, hasPrev: page > 1, hasNext: false, totalPages: 1, totalResults: 0, error: 'You are offline.' };
  }
  try {
    const headers: Record<string, string> = { Accept: 'application/json' };
    try {
      const token = await auth.currentUser?.getIdToken();
      if (token) headers.Authorization = `Bearer ${token}`;
    } catch {
      // continue unsigned if guest
    }
    const params: string[] = [
      `limit=${pageSize}`,
      `offset=${(page - 1) * pageSize}`,
      'includes[]=cover_art',
      'includes[]=author',
      'contentRating[]=safe',
      'contentRating[]=suggestive',
    ];
    if (q) params.push(`title=${encodeURIComponent(q)}`);
    if (opts.status === 'ongoing' || opts.status === 'completed') {
      params.push(`status[]=${opts.status}`);
    }
    if (opts.demographic && opts.demographic !== 'all') {
      const mdDemo = opts.demographic.toLowerCase() === 'shoujo' ? 'shoujo' : opts.demographic.toLowerCase();
      if (['shounen', 'seinen', 'shoujo', 'josei'].includes(mdDemo)) {
        params.push(`publicationDemographic[]=${mdDemo}`);
      }
    }
    if (opts.orderBy === 'az') params.push('order[title]=asc');
    else if (opts.orderBy === 'new') params.push('order[createdAt]=desc');
    else if (opts.orderBy === 'rating') params.push('order[rating]=desc');
    else if (opts.orderBy === 'latest') params.push('order[latestUploadedChapter]=desc');
    else if (q) params.push('order[relevance]=desc');
    else params.push('order[followedCount]=desc');

    const mdPath = `/manga?${params.join('&')}`;
    const resp = await fetch(`${PROXY_MANGADEX_URL}?path=${encodeURIComponent(mdPath)}`, {
      headers,
      signal: AbortSignal.timeout(10000),
    });
    if (!resp.ok) {
      return { items: [], page, hasPrev: page > 1, hasNext: false, totalPages: 1, totalResults: 0, error: 'MangaDex catalog is temporarily unavailable.' };
    }
    const json = (await resp.json()) as {
      total?: number;
      data?: Array<{
        id: string;
        attributes?: {
          title?: Record<string, string>;
          altTitles?: Array<Record<string, string>>;
          description?: Record<string, string>;
          status?: string;
          publicationDemographic?: string | null;
          lastChapter?: string | null;
          tags?: Array<{ id?: string; attributes?: { name?: Record<string, string> } }>;
        };
        relationships?: Array<{ type?: string; attributes?: { fileName?: string; name?: string } }>;
      }>;
    };
    const rawItems = json.data ?? [];
    const mapped = rawItems.map((entry) => {
      const attrs = entry.attributes ?? {};
      const titleObj = attrs.title ?? {};
      const title = titleObj.en || titleObj['ja-ro'] || Object.values(titleObj)[0] || 'Untitled';
      const coverRel = entry.relationships?.find((r) => r.type === 'cover_art');
      const fileName = coverRel?.attributes?.fileName;
      const coverUrl = fileName
        ? `${PROXY_MANGA_IMAGE_URL}?url=${encodeURIComponent(`https://uploads.mangadex.org/covers/${entry.id}/${fileName}.512.jpg`)}`
        : '';
      const authors = (entry.relationships ?? [])
        .filter((r) => r.type === 'author' && r.attributes?.name)
        .map((r) => r.attributes!.name!);
      const slug = title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '');
      const genres: KatanaGenre[] = (attrs.tags ?? [])
        .map((t) => t.attributes?.name?.en || '')
        .filter(Boolean)
        .slice(0, 6)
        .map((name) => ({
          slug: name.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
          name,
          count: 0,
          description: '',
        }));
      const statusRaw = (attrs.status ?? 'ongoing').toLowerCase();
      const status = statusRaw === 'completed' ? 'Completed' : statusRaw === 'hiatus' ? 'Hiatus' : 'Ongoing';
      const lastCh = attrs.lastChapter ? String(attrs.lastChapter) : '';
      const safeSlug = slug || entry.id;
      return {
        id: safeSlug,
        slug: safeSlug,
        title,
        coverUrl,
        summary: attrs.description?.en || '',
        status,
        demographic: attrs.publicationDemographic || undefined,
        updateText: '',
        genres,
        latestChapter: lastCh ? { id: `c${lastCh}`, num: lastCh, title: `Chapter ${lastCh}` } : undefined,
        recentChapters: [],
        authors,
        artists: [],
        altNames: (attrs.altTitles ?? []).flatMap((o) => Object.values(o)).slice(0, 4),
        chapters: [],
      } satisfies KatanaManga;
    });
    const filtered = applySharedFilters(mapped);
    const total = typeof json.total === 'number' ? Math.min(json.total, 9600) : filtered.length;
    const totalPages = Math.max(1, Math.ceil(total / pageSize));
    return {
      items: filtered,
      page,
      hasPrev: page > 1,
      hasNext: page < totalPages && rawItems.length >= pageSize,
      totalPages,
      totalResults: total,
    };
  } catch (err) {
    Logger.e('KatanaService: searchMangaDexCatalog failed', err);
    return { items: [], page, hasPrev: page > 1, hasNext: false, totalPages: 1, totalResults: 0, error: 'Could not reach MangaDex right now.' };
  }
}
