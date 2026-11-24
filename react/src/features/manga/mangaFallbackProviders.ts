import { ConnectivityService } from '../../core/network/connectivity';
import { NetworkQualityService } from '../../core/network/networkQuality';
import { auth } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';

const FUNCTIONS_BASE = 'https://us-central1-everglow-1c6db.cloudfunctions.net';
const PROXY_MANGADEX = `${FUNCTIONS_BASE}/proxyMangaDex`;
const PROXY_COMICK = `${FUNCTIONS_BASE}/proxyComick`;
const PROXY_MANGA_IMAGE = `${FUNCTIONS_BASE}/proxyMangaImage`;
const PROXY_SCANLATION = `${FUNCTIONS_BASE}/proxyScanlation`;
const PROXY_FETCH_HTML = `${FUNCTIONS_BASE}/proxyFetchHtml`;

export interface FallbackChapterResult {
  pages: string[];
  source: 'MangaDex' | 'ComicK' | 'Bato' | 'Scanlation' | '';
}

async function authHeaders(accept = 'application/json'): Promise<Record<string, string>> {
  const headers: Record<string, string> = { Accept: accept };
  try {
    const token = await auth.currentUser?.getIdToken();
    if (token) headers.Authorization = `Bearer ${token}`;
  } catch {
    // Continue unsigned if guest/not signed in yet.
  }
  return headers;
}

function extractChapterNumber(chapterId: string): string {
  const m = /(\d+(?:\.\d+)?)/.exec(chapterId);
  return m ? m[1] : '';
}

function slugToTitle(slug: string): string {
  return slug
    .replace(/\.[0-9]+$/, '')
    .replace(/[-_]+/g, ' ')
    .trim();
}

function proxiedMangaImage(url: string): string {
  if (!url) return '';
  if (url.includes('proxyMangaImage')) return url;
  return `${PROXY_MANGA_IMAGE}?url=${encodeURIComponent(url)}`;
}

function proxiedScanlationImage(url: string, referer?: string): string {
  if (!url) return '';
  if (url.includes('proxyScanlation')) return url;
  const qs = new URLSearchParams({ url });
  if (referer) qs.set('referer', referer);
  return `${PROXY_SCANLATION}?${qs.toString()}`;
}

async function tryMangaDex(title: string, chapterNum: string): Promise<string[]> {
  if (!title || !chapterNum) return [];
  try {
    const headers = await authHeaders();
    const searchPath = `/manga?title=${encodeURIComponent(title)}&limit=3&contentRating[]=safe&contentRating[]=suggestive`;
    const searchResp = await fetch(`${PROXY_MANGADEX}?path=${encodeURIComponent(searchPath)}`, {
      headers,
      signal: AbortSignal.timeout(NetworkQualityService.timeoutMs(9000)),
    });
    if (!searchResp.ok) return [];
    const searchJson = (await searchResp.json()) as { data?: Array<{ id?: string }> };
    const mangaId = searchJson.data?.[0]?.id;
    if (!mangaId) return [];

    const feedPath = `/manga/${mangaId}/feed?translatedLanguage[]=en&chapter=${encodeURIComponent(chapterNum)}&limit=5`;
    const feedResp = await fetch(`${PROXY_MANGADEX}?path=${encodeURIComponent(feedPath)}`, {
      headers,
      signal: AbortSignal.timeout(NetworkQualityService.timeoutMs(9000)),
    });
    if (!feedResp.ok) return [];
    const feedJson = (await feedResp.json()) as { data?: Array<{ id?: string }> };
    const chId = feedJson.data?.[0]?.id;
    if (!chId) return [];

    const atHomeResp = await fetch(`${PROXY_MANGADEX}?path=${encodeURIComponent(`/at-home/server/${chId}`)}`, {
      headers,
      signal: AbortSignal.timeout(NetworkQualityService.timeoutMs(9000)),
    });
    if (!atHomeResp.ok) return [];
    const atHome = (await atHomeResp.json()) as {
      baseUrl?: string;
      chapter?: { hash?: string; data?: string[]; dataSaver?: string[] };
    };
    const baseUrl = atHome.baseUrl;
    const hash = atHome.chapter?.hash;
    const files = NetworkQualityService.isSlowConnection
      ? atHome.chapter?.dataSaver ?? atHome.chapter?.data ?? []
      : atHome.chapter?.data ?? atHome.chapter?.dataSaver ?? [];
    const mode = NetworkQualityService.isSlowConnection && atHome.chapter?.dataSaver?.length ? 'data-saver' : 'data';
    if (!baseUrl || !hash || !files.length) return [];
    return files.map((file) => proxiedMangaImage(`${baseUrl}/${mode}/${hash}/${file}`));
  } catch (e) {
    Logger.e('MangaDex fallback failed', e);
    return [];
  }
}

async function tryComick(title: string, chapterNum: string): Promise<string[]> {
  if (!title || !chapterNum) return [];
  try {
    const headers = await authHeaders();
    const searchResp = await fetch(
      `${PROXY_COMICK}?path=${encodeURIComponent(`/v1.0/search?q=${encodeURIComponent(title)}&limit=3`)}`,
      { headers, signal: AbortSignal.timeout(NetworkQualityService.timeoutMs(9000)) },
    );
    if (!searchResp.ok) return [];
    const searchJson = (await searchResp.json()) as Array<{ hid?: string }>;
    const hid = Array.isArray(searchJson) ? searchJson[0]?.hid : undefined;
    if (!hid) return [];

    const chResp = await fetch(
      `${PROXY_COMICK}?path=${encodeURIComponent(`/comic/${hid}/chapters?lang=en&chap=${encodeURIComponent(chapterNum)}&limit=5`)}`,
      { headers, signal: AbortSignal.timeout(NetworkQualityService.timeoutMs(9000)) },
    );
    if (!chResp.ok) return [];
    const chJson = (await chResp.json()) as { chapters?: Array<{ hid?: string }> };
    const chHid = chJson.chapters?.[0]?.hid;
    if (!chHid) return [];

    const detailResp = await fetch(`${PROXY_COMICK}?path=${encodeURIComponent(`/chapter/${chHid}`)}`, {
      headers,
      signal: AbortSignal.timeout(NetworkQualityService.timeoutMs(9000)),
    });
    if (!detailResp.ok) return [];
    const detail = (await detailResp.json()) as { chapter?: { md_images?: Array<{ b2key?: string }> } };
    const imgs = detail.chapter?.md_images ?? [];
    return imgs
      .map((img) => (img.b2key ? proxiedMangaImage(`https://meo.comick.pictures/${img.b2key}`) : ''))
      .filter(Boolean);
  } catch (e) {
    Logger.e('ComicK fallback failed', e);
    return [];
  }
}

async function tryBato(title: string, chapterNum: string): Promise<string[]> {
  if (!title || !chapterNum) return [];
  try {
    const headers = await authHeaders('text/html');
    const searchUrl = `https://bato.to/search?q=${encodeURIComponent(title)}`;
    const resp = await fetch(`${PROXY_FETCH_HTML}?url=${encodeURIComponent(searchUrl)}`, {
      headers,
      signal: AbortSignal.timeout(NetworkQualityService.timeoutMs(8000)),
    });
    if (!resp.ok) return [];
    const html = await resp.text();
    const seriesMatch = /href="(\/series\/\d+[^"]*)"/.exec(html);
    if (!seriesMatch) return [];
    const seriesResp = await fetch(`${PROXY_FETCH_HTML}?url=${encodeURIComponent(`https://bato.to${seriesMatch[1]}`)}`, {
      headers,
      signal: AbortSignal.timeout(NetworkQualityService.timeoutMs(8000)),
    });
    if (!seriesResp.ok) return [];
    const seriesHtml = await seriesResp.text();
    const chRe = new RegExp(`href="(\\/chapter\\/\\d+[^"]*)"[^>]*>[^<]*(?:ch(?:apter)?\\.?\\s*${escapeRegExp(chapterNum)}\\b)`, 'i');
    const chMatch = chRe.exec(seriesHtml);
    if (!chMatch) return [];
    const pageResp = await fetch(`${PROXY_FETCH_HTML}?url=${encodeURIComponent(`https://bato.to${chMatch[1]}`)}`, {
      headers,
      signal: AbortSignal.timeout(NetworkQualityService.timeoutMs(8000)),
    });
    if (!pageResp.ok) return [];
    const pageHtml = await pageResp.text();
    const imgHttps = /const\s+imgHttps\s*=\s*(\[[\s\S]*?\]);/.exec(pageHtml);
    if (!imgHttps) return [];
    const parsed = JSON.parse(imgHttps[1]) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter((u): u is string => typeof u === 'string' && u.startsWith('http'))
      .map((u) => proxiedScanlationImage(u, 'https://bato.to'));
  } catch (e) {
    Logger.e('Bato fallback failed', e);
    return [];
  }
}

const SCANLATION_SITES = [
  { name: 'AsuraScans', baseUrl: 'https://asurascans.com', seriesPath: '/manga/' },
  { name: 'ReaperScans', baseUrl: 'https://reaperscans.com', seriesPath: '/series/' },
  { name: 'ArcaneScans', baseUrl: 'https://arcanescans.com', seriesPath: '/series/' },
];

const SCAN_IMG_EXCLUDE = ['avatar', 'logo', 'icon', 'banner', 'header', 'discord'];

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

async function tryScanlation(title: string, chapterNum: string): Promise<string[]> {
  if (!title || !chapterNum) return [];
  const slug = title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
  if (!slug) return [];
  const headers = await authHeaders('text/html');
  for (const site of SCANLATION_SITES) {
    try {
      const seriesUrl = `${site.baseUrl}${site.seriesPath}${slug}/`;
      const resp = await fetch(`${PROXY_FETCH_HTML}?url=${encodeURIComponent(seriesUrl)}`, {
        headers,
        signal: AbortSignal.timeout(NetworkQualityService.timeoutMs(7000)),
      });
      if (!resp.ok) continue;
      const html = await resp.text();
      const chRe = new RegExp(`href="(https?:\\/\\/[^"]*?(?:chapter|ch)[-_]${escapeRegExp(chapterNum)}(?:[^0-9"][^"]*)?)"`, 'i');
      const chMatch = chRe.exec(html);
      if (!chMatch) continue;
      const chResp = await fetch(`${PROXY_FETCH_HTML}?url=${encodeURIComponent(chMatch[1])}`, {
        headers,
        signal: AbortSignal.timeout(NetworkQualityService.timeoutMs(7000)),
      });
      if (!chResp.ok) continue;
      const chHtml = await chResp.text();
      const imgs: string[] = [];
      const imgRe = /<img[^>]*src="(https?:\/\/[^"]+)"[^>]*>/gi;
      let m: RegExpExecArray | null;
      while ((m = imgRe.exec(chHtml)) !== null) {
        const u = m[1];
        const lower = u.toLowerCase();
        if (SCAN_IMG_EXCLUDE.some((ex) => lower.includes(ex))) continue;
        if (!imgs.includes(u)) imgs.push(proxiedScanlationImage(u, site.baseUrl));
      }
      if (imgs.length >= 3) return imgs;
    } catch {
      // Try next scanlation site.
    }
  }
  return [];
}

/**
 * Multi-source chapter fallback ported from Flutter's MangaDex, ComicK, Bato, and Scanlation services.
 * Only runs when MangaKatana fails to return chapter pages.
 */
export async function fetchFallbackChapterPages(slugOrTitle: string, chapterId: string): Promise<FallbackChapterResult> {
  if (!ConnectivityService.isOnline) return { pages: [], source: '' };
  const title = slugToTitle(slugOrTitle);
  const chapterNum = extractChapterNumber(chapterId);
  if (!title || !chapterNum) return { pages: [], source: '' };

  const providers: Array<{ name: FallbackChapterResult['source']; fn: () => Promise<string[]> }> = [
    { name: 'MangaDex', fn: () => tryMangaDex(title, chapterNum) },
    { name: 'ComicK', fn: () => tryComick(title, chapterNum) },
    { name: 'Bato', fn: () => tryBato(title, chapterNum) },
    { name: 'Scanlation', fn: () => tryScanlation(title, chapterNum) },
  ];

  for (const p of providers) {
    const pages = await p.fn();
    if (pages.length > 0) {
      return { pages, source: p.name };
    }
  }
  return { pages: [], source: '' };
}
