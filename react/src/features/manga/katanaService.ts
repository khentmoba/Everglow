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
import { getDemoChapterPages } from './readerDemo';
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
  const m = /(\d+(?:\.\d+)?)/.exec(raw);
  return m ? Number.parseFloat(m[1]) || 0 : 0;
}

export function estimateUnreadCount(bm: KatanaBookmark, knownLatestNum?: number): number {
  const status = resolveLibraryStatus(bm);
  if (status === 'completed' || status === 'dropped') return 0;
  const latestNum = knownLatestNum ?? extractChapterNumber(bm.latestChapterTitle);
  const readNum =
    extractChapterNumber(bm.lastReadChapterTitle) ||
    extractChapterNumber(katanaChapterNumFromId(bm.lastReadChapterId));
  if (latestNum <= 0) return 0;
  if (readNum <= 0) return Math.floor(latestNum);
  return Math.max(0, Math.floor(latestNum - readNum));
}

export function isBookmarkCaughtUp(bm: KatanaBookmark, knownLatestNum?: number): boolean {
  const status = resolveLibraryStatus(bm);
  if (status !== 'reading' || !bm.lastReadChapterId) return false;
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
    chapterCount: parsedChCount > 0 ? parsedChCount : undefined,
    demographic,
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

export function pushRecentMangaSearch(q: string): string[] {
  const trimmed = q.trim();
  if (!trimmed) return getRecentMangaSearches();
  const next = [trimmed, ...getRecentMangaSearches().filter((s) => s.toLowerCase() !== trimmed.toLowerCase())].slice(0, 8);
  try {
    localStorage.setItem(RECENT_SEARCH_KEY, JSON.stringify(next));
  } catch {
    // ignore storage quota
  }
  return next;
}

export function removeRecentMangaSearch(q: string): string[] {
  const next = getRecentMangaSearches().filter((s) => s.toLowerCase() !== q.toLowerCase());
  try {
    localStorage.setItem(RECENT_SEARCH_KEY, JSON.stringify(next));
  } catch {
    // ignore
  }
  return next;
}

export function clearRecentMangaSearches(): void {
  try {
    localStorage.removeItem(RECENT_SEARCH_KEY);
  } catch {
    // ignore
  }
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
      };
    }
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
  const result: KatanaHomeData = {
    hotUpdates: hotUpdateIdx >= 0 ? items(blocksOfClass(html, 'item', hotUpdateIdx, hotUpdateEnd)) : [],
    latest,
    hot,
    genres: parseGenres(html),
  };
  saveHomeCache(result);
  return result;
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
  if (!html) {
    if (AgentMode.demo) {
      let demo = buildDemoCatalog();
      if (opts.mode === 'genre' && opts.key) {
        demo = demo.filter((m) => m.genres.some((g) => g.slug === opts.key));
      }
      if (opts.mode === 'search' && opts.query) {
        const q = opts.query.trim().toLowerCase();
        demo = demo.filter((m) =>
          opts.searchBy === 'author'
            ? m.authors.some((a) => a.toLowerCase().includes(q))
            : m.title.toLowerCase().includes(q) || m.altNames.some((a) => a.toLowerCase().includes(q)),
        );
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
      const filtered = applyClientFilters(demo);
      return { items: filtered, page, hasNext: false, hasPrev: page > 1, totalPages: 1, totalResults: filtered.length };
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
  const parsedItems = applyClientFilters(items(blocks));
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
      status: manga.status || cur?.status || 'ongoing',
      addedAt: cur?.addedAt ?? new Date(),
      lastReadChapterId: cur?.lastReadChapterId ?? '',
      lastReadPage: cur?.lastReadPage ?? 0,
      lastReadChapterTitle: cur?.lastReadChapterTitle ?? '',
      latestChapterTitle: cur?.latestChapterTitle ?? '',
      recommendedBy: cur?.recommendedBy ?? '',
      recommendationNote: cur?.recommendationNote ?? '',
      readChapterIds: cur?.readChapterIds ?? [],
      bookmarked: true,
      libraryStatus,
      finishedAt: libraryStatus === 'completed' ? cur?.finishedAt ?? new Date() : undefined,
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
    {
      slug: manga.slug,
      title: manga.title,
      coverUrl: manga.coverUrl,
      status: manga.status,
      userName,
      bookmarked: true,
      libraryStatus,
      ...(libraryStatus === 'completed' ? { finishedAt: Timestamp.now() } : { finishedAt: deleteField() }),
      addedAt: Timestamp.now(),
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
