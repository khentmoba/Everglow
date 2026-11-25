// Port of lib/core/services/offline_media/ (item + service + web storage).
// The list lives in the same shared_preferences key and the files in the same
// Cache Storage buckets, so downloads made in the Flutter app still show here.
import { useEffect } from 'react';
import { AgentMode } from '../agent/agentMode';
import { Logger } from '../system/logger';
import { Prefs } from '../system/prefs';
import { useValue, ValueNotifier } from '../system/store';

export type OfflineMediaType = 'movie' | 'tv' | 'anime' | 'manga';
export type OfflineDownloadStatus = 'queued' | 'downloading' | 'completed' | 'paused' | 'failed';

export interface OfflineMediaItem {
  id: string;
  type: OfflineMediaType;
  mediaId: string;
  title: string;
  subtitle: string;
  season?: number;
  episode?: number;
  chapterId?: string;
  coverUrl: string;
  sourceUrl?: string;
  status: OfflineDownloadStatus;
  progress: number;
  totalBytes: number;
  downloadedBytes: number;
  downloadedAt: string;
  durationSeconds?: number;
  lastPositionSeconds?: number;
  pageUrls: string[];
  downloadedPages?: number;
  verifiedCachedPages?: number;
  cacheMissingPages?: number;
  cacheVerifiedAt?: string;
  blobKey?: string;
}

const TYPES: OfflineMediaType[] = ['movie', 'tv', 'anime', 'manga'];
const STATUSES: OfflineDownloadStatus[] = ['queued', 'downloading', 'completed', 'paused', 'failed'];
const GB = 1024 * 1024 * 1024;
const MB = 1024 * 1024;

export const isCinemaItem = (i: OfflineMediaItem) => i.type === 'movie' || i.type === 'tv';
export const isEpisodeItem = (i: OfflineMediaItem) => i.type === 'tv' || i.type === 'anime';
const isCompleted = (i: OfflineMediaItem) => i.status === 'completed';
const isDownloading = (i: OfflineMediaItem) => i.status === 'downloading';

export function formatBytes(bytes: number): string {
  if (bytes <= 0) return '0 MB';
  if (bytes < GB) return `${(bytes / MB).toFixed(1)} MB`;
  return `${(bytes / GB).toFixed(2)} GB`;
}

export function formattedSize(i: OfflineMediaItem): string {
  if (!isCompleted(i) && !isDownloading(i)) return '0 MB';
  const bytes = i.downloadedBytes > 0 ? i.downloadedBytes : isCompleted(i) ? i.totalBytes : 0;
  if (bytes <= 0) return '0 MB';
  if (bytes < MB) return `${(bytes / 1024).toFixed(1)} KB`;
  return formatBytes(bytes);
}

export function formattedDuration(i: OfflineMediaItem): string {
  const sec = i.durationSeconds ?? 0;
  if (sec <= 0) return '';
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  return h > 0 ? `${h}h ${m}m` : `${m}m`;
}

function fromJson(json: Record<string, unknown>): OfflineMediaItem {
  const str = (v: unknown) => (typeof v === 'string' ? v : undefined);
  const int = (v: unknown) => (typeof v === 'number' ? Math.trunc(v) : undefined);
  const type = str(json.type)?.toLowerCase() as OfflineMediaType;
  const status = str(json.status)?.toLowerCase() as OfflineDownloadStatus;
  const at = str(json.downloadedAt);
  return {
    id: str(json.id) ?? '',
    type: TYPES.includes(type) ? type : 'movie',
    mediaId: str(json.mediaId) ?? '',
    title: str(json.title) ?? '',
    subtitle: str(json.subtitle) ?? '',
    season: int(json.season),
    episode: int(json.episode),
    chapterId: str(json.chapterId),
    coverUrl: str(json.coverUrl) ?? '',
    sourceUrl: str(json.sourceUrl),
    status: STATUSES.includes(status) ? status : 'completed',
    progress: typeof json.progress === 'number' ? json.progress : 1,
    totalBytes: int(json.totalBytes) ?? 0,
    downloadedBytes: int(json.downloadedBytes) ?? 0,
    downloadedAt: at && !Number.isNaN(Date.parse(at)) ? at : new Date().toISOString(),
    durationSeconds: int(json.durationSeconds),
    lastPositionSeconds: int(json.lastPositionSeconds),
    pageUrls: Array.isArray(json.pageUrls) ? json.pageUrls.filter((u): u is string => typeof u === 'string') : [],
    downloadedPages: int(json.downloadedPages),
    verifiedCachedPages: int(json.verifiedCachedPages),
    cacheMissingPages: int(json.cacheMissingPages),
    cacheVerifiedAt: str(json.cacheVerifiedAt),
    blobKey: str(json.blobKey),
  };
}

const toJson = (i: OfflineMediaItem) => ({
  id: i.id,
  type: i.type,
  mediaId: i.mediaId,
  title: i.title,
  subtitle: i.subtitle,
  season: i.season ?? null,
  episode: i.episode ?? null,
  chapterId: i.chapterId ?? null,
  coverUrl: i.coverUrl,
  sourceUrl: i.sourceUrl ?? null,
  status: i.status,
  progress: i.progress,
  totalBytes: i.totalBytes,
  downloadedBytes: i.downloadedBytes,
  downloadedAt: i.downloadedAt,
  durationSeconds: i.durationSeconds ?? null,
  lastPositionSeconds: i.lastPositionSeconds ?? null,
  pageUrls: i.pageUrls,
  downloadedPages: i.downloadedPages ?? null,
  verifiedCachedPages: i.verifiedCachedPages ?? null,
  cacheMissingPages: i.cacheMissingPages ?? null,
  cacheVerifiedAt: i.cacheVerifiedAt ?? null,
  blobKey: i.blobKey ?? null,
});

// --- Cache Storage (offline_media_storage_web.dart) ---------------------------

const MEDIA_CACHE = 'everglow-offline-media-v1';
const MANGA_CACHE = 'everglow-offline-manga-v1';
const objectUrls = new Set<string>();
const cacheKey = (key: string, isManga: boolean) =>
  `${window.location.origin}/${isManga ? 'offline-manga' : 'offline-media'}/${encodeURIComponent(key)}`;

async function saveBlob(key: string, bytes: Blob, isManga: boolean, mimeType: string): Promise<boolean> {
  try {
    const cache = await caches.open(isManga ? MANGA_CACHE : MEDIA_CACHE);
    const body = bytes.type === mimeType ? bytes : new Blob([bytes], { type: mimeType });
    await cache.put(
      cacheKey(key, isManga),
      new Response(body, {
        status: 200,
        statusText: 'OK',
        headers: { 'Content-Type': mimeType, 'Content-Length': String(body.size) },
      }),
    );
    return true;
  } catch (e) {
    Logger.e(`OfflineMediaStorage: could not save ${isManga ? 'manga page' : 'media blob'} ${key}`, e);
    return false;
  }
}

async function saveStreamToCache(
  key: string,
  res: Response,
  mimeType: string,
  onProgress?: (loadedBytes: number, totalBytes: number) => void,
): Promise<{ ok: boolean; bytes: number }> {
  try {
    const cache = await caches.open(MEDIA_CACHE);
    const contentLength = Number(res.headers.get('content-length')) || 0;
    if (!res.body || typeof TransformStream === 'undefined') {
      const blob = await res.blob();
      if (blob.size <= 0) return { ok: false, bytes: 0 };
      const ok = await saveBlob(key, blob, false, mimeType);
      return { ok, bytes: blob.size };
    }
    let loaded = 0;
    let lastReportAt = 0;
    const counter = new TransformStream<Uint8Array, Uint8Array>({
      transform(chunk, controller) {
        loaded += chunk.byteLength;
        controller.enqueue(chunk);
        const now = Date.now();
        if (onProgress && now - lastReportAt >= 400) {
          lastReportAt = now;
          onProgress(loaded, contentLength);
        }
      },
    });
    const stream = res.body.pipeThrough(counter);
    const headers: Record<string, string> = { 'Content-Type': mimeType };
    if (contentLength > 0) headers['Content-Length'] = String(contentLength);
    await cache.put(
      cacheKey(key, false),
      new Response(stream, { status: 200, statusText: 'OK', headers }),
    );
    return { ok: loaded > 0, bytes: loaded };
  } catch (e) {
    Logger.e(`OfflineMediaStorage: could not stream media ${key}`, e);
    return { ok: false, bytes: 0 };
  }
}

async function getBlobUrl(key: string, isManga: boolean): Promise<string | null> {
  try {
    const cache = await caches.open(isManga ? MANGA_CACHE : MEDIA_CACHE);
    const reqKey = cacheKey(key, isManga);
    let res = await cache.match(reqKey);
    if (!res) return null;
    let blob = await res.blob();
    if (!blob || blob.size <= 0) {
      await new Promise((r) => setTimeout(r, 120));
      res = await cache.match(reqKey);
      if (!res) return null;
      blob = await res.blob();
      if (!blob || blob.size <= 0) {
        await cache.delete(reqKey).catch(() => {});
        return null;
      }
    }
    const url = URL.createObjectURL(blob);
    objectUrls.add(url);
    return url;
  } catch (e) {
    Logger.e(`OfflineMediaStorage: could not create blob URL for ${key}`, e);
    return null;
  }
}

async function getCachedBlobSize(key: string, isManga: boolean): Promise<number> {
  try {
    const cache = await caches.open(isManga ? MANGA_CACHE : MEDIA_CACHE);
    const res = await cache.match(cacheKey(key, isManga));
    if (!res) return 0;
    const headerLen = Number(res.headers.get('content-length')) || 0;
    if (headerLen > 0) return headerLen;
    const blob = await res.blob();
    return blob?.size ?? 0;
  } catch {
    return 0;
  }
}

async function deleteBlob(key: string, isManga: boolean): Promise<void> {
  try {
    const cache = await caches.open(isManga ? MANGA_CACHE : MEDIA_CACHE);
    await cache.delete(cacheKey(key, isManga));
  } catch (e) {
    Logger.e(`OfflineMediaStorage: could not delete blob ${key}`, e);
  }
}

async function clearStorage(): Promise<void> {
  for (const url of objectUrls) URL.revokeObjectURL(url);
  objectUrls.clear();
  try {
    await caches.delete(MEDIA_CACHE);
    await caches.delete(MANGA_CACHE);
  } catch (e) {
    Logger.e('OfflineMediaStorage: could not clear caches', e);
  }
}

function revokeObjectUrl(url: string | null | undefined): void {
  if (!url || !objectUrls.has(url)) return;
  URL.revokeObjectURL(url);
  objectUrls.delete(url);
}

async function deleteItemBlobs(item: OfflineMediaItem) {
  if (item.blobKey) await deleteBlob(item.blobKey, item.type === 'manga');
  if (item.type === 'manga') {
    for (let i = 1; i <= item.pageUrls.length; i++) await deleteBlob(`${item.id}_p_${i}`, true);
  }
}

// --- Service ------------------------------------------------------------------

const FUNCTIONS_BASE = 'https://us-central1-everglow-1c6db.cloudfunctions.net';

export function defaultMangaPageProxy(raw: string): string {
  if (!raw) return '';
  let u = raw;
  if (u.toLowerCase().includes('mangakatana')) u = u.replace(/\.avif(?=$|[?&#])/gi, '.webp');
  if (
    u.includes('proxyMangaKatana') ||
    u.includes('proxyMangaImage') ||
    u.includes('proxyScanlation')
  ) {
    return u;
  }
  try {
    const host = new URL(u).host.toLowerCase();
    if (
      host === 'mangakatana.com' ||
      host.endsWith('.mangakatana.com') ||
      host.endsWith('.mangakakalot.com') ||
      host.endsWith('.mkklcdnv6temp.com') ||
      host.endsWith('.catmanga.org')
    ) {
      return `${FUNCTIONS_BASE}/proxyMangaKatana?url=${encodeURIComponent(u)}`;
    }
    if (
      host === 'uploads.mangadex.org' ||
      host.endsWith('.mangadex.org') ||
      host.endsWith('.mangadex.network')
    ) {
      return `${FUNCTIONS_BASE}/proxyMangaImage?url=${encodeURIComponent(u)}`;
    }
    if (
      host.endsWith('.comick.io') ||
      host.endsWith('.comick.pictures') ||
      host.endsWith('.comick.dev') ||
      host.endsWith('.bato.to') ||
      host.endsWith('.bato.si') ||
      host.endsWith('.img.bato.to') ||
      host.endsWith('.mbimg.org')
    ) {
      return `${FUNCTIONS_BASE}/proxyScanlation?url=${encodeURIComponent(u)}`;
    }
    return u;
  } catch {
    return u;
  }
}

const PREFS_KEY = 'everglow_offline_media_items_v1';
const DEMO_SOURCE = 'https://raw.githubusercontent.com/mediaelement/mediaelement-files/master/big_buck_bunny.mp4';

class OfflineMediaService extends ValueNotifier<Record<string, OfflineMediaItem>> {
  private initialized = false;
  private lastPositionSave = 0;

  constructor() {
    super({});
  }

  init() {
    if (this.initialized) return;
    this.initialized = true;
    const items: Record<string, OfflineMediaItem> = {};
    const autoResumeIds: string[] = [];
    try {
      const raw = Prefs.getString(PREFS_KEY);
      if (raw) {
        for (const entry of JSON.parse(raw) as unknown[]) {
          if (entry && typeof entry === 'object') {
            const item = fromJson(entry as Record<string, unknown>);
            if (item.status === 'downloading' || item.status === 'queued') {
              items[item.id] = { ...item, status: 'paused' };
              if (item.type === 'manga' && item.pageUrls.length > 0) {
                autoResumeIds.push(item.id);
              }
            } else {
              items[item.id] = item;
            }
          }
        }
      }
    } catch (e) {
      Logger.e('OfflineMediaService: could not load stored registry', e);
    }
    if (Object.keys(items).length === 0 && AgentMode.demo) {
      for (const item of demoItems()) items[item.id] = item;
    }
    this.value = items;
    if (typeof caches !== 'undefined') {
      queueMicrotask(() => {
        void this.verifyAllMangaChaptersCache();
      });
    }
    if (autoResumeIds.length > 0 && !AgentMode.demo && typeof navigator !== 'undefined' && navigator.onLine !== false) {
      queueMicrotask(() => {
        for (const id of autoResumeIds) {
          void this.resumeDownload(id);
        }
      });
    }
  }

  /** Completed or in-progress downloads, newest first. */
  get allItems(): OfflineMediaItem[] {
    return Object.values(this.value)
      .filter((i) => isCompleted(i) || isDownloading(i))
      .sort((a, b) => Date.parse(b.downloadedAt) - Date.parse(a.downloadedAt));
  }

  get cinemaItems() {
    return this.allItems.filter(isCinemaItem);
  }
  get animeItems() {
    return this.allItems.filter((i) => i.type === 'anime');
  }
  get mangaItems() {
    return this.allItems.filter((i) => i.type === 'manga');
  }

  private storage(filter: (i: OfflineMediaItem) => boolean) {
    return formatBytes(this.allItems.filter(filter).reduce((sum, i) => sum + i.downloadedBytes, 0));
  }
  get formattedTotalStorage() {
    return this.storage(() => true);
  }
  get formattedCinemaStorage() {
    return this.storage(isCinemaItem);
  }
  get formattedAnimeStorage() {
    return this.storage((i) => i.type === 'anime');
  }
  get formattedMangaStorage() {
    return this.storage((i) => i.type === 'manga');
  }

  getItem(id: string): OfflineMediaItem | undefined {
    return this.value[id];
  }
  isDownloaded(id: string) {
    const item = this.value[id];
    return !!item && isCompleted(item) && item.downloadedBytes > 0 && (item.cacheMissingPages ?? 0) === 0;
  }
  needsCacheRepair(id: string) {
    const item = this.value[id];
    return !!item && item.type === 'manga' && isCompleted(item) && (item.cacheMissingPages ?? 0) > 0;
  }
  isDownloading(id: string) {
    const item = this.value[id];
    return !!item && isDownloading(item);
  }

  getEpisodesForSeries(mediaId: string, season?: number): OfflineMediaItem[] {
    return Object.values(this.value)
      .filter((i) => i.mediaId === mediaId && isEpisodeItem(i) && (season == null || i.season === season))
      .sort((a, b) => (a.season ?? 0) - (b.season ?? 0) || (a.episode ?? 0) - (b.episode ?? 0));
  }

  getChaptersForManga(slug: string): OfflineMediaItem[] {
    return Object.values(this.value)
      .filter((i) => i.type === 'manga' && i.mediaId === slug)
      .sort((a, b) => ((a.chapterId ?? '') < (b.chapterId ?? '') ? -1 : (a.chapterId ?? '') > (b.chapterId ?? '') ? 1 : 0));
  }

  private activeControllers = new Map<string, AbortController>();
  private mangaProxyMap = new Map<string, (url: string) => string>();

  private put(item: OfflineMediaItem) {
    if (!item.id) return;
    this.value = { ...this.value, [item.id]: item };
  }

  private putIfPresent(id: string, patch: Partial<OfflineMediaItem>): boolean {
    const cur = this.value[id];
    if (!cur) return false;
    this.value = { ...this.value, [id]: { ...cur, ...patch } };
    return true;
  }

  private save() {
    if (AgentMode.demo) return;
    try {
      Prefs.set(PREFS_KEY, JSON.stringify(Object.values(this.value).map(toJson)));
    } catch (e) {
      Logger.e('OfflineMediaService: could not persist registry', e);
    }
  }

  async startDownloadMedia(args: {
    id: string;
    type: OfflineMediaType;
    mediaId: string;
    title: string;
    subtitle?: string;
    season?: number;
    episode?: number;
    coverUrl?: string;
    sourceUrl?: string;
    durationSeconds?: number;
    estimatedBytes?: number;
  }): Promise<void> {
    this.init();
    const existing = this.value[args.id];
    if (existing && isCompleted(existing)) return;
    const estimated =
      args.estimatedBytes && args.estimatedBytes > 0 ? args.estimatedBytes : args.type === 'movie' ? 1400 * MB : 350 * MB;
    const url = args.sourceUrl || DEMO_SOURCE;
    const initial: OfflineMediaItem = {
      id: args.id,
      type: args.type,
      mediaId: args.mediaId,
      title: args.title,
      subtitle: args.subtitle ?? '',
      season: args.season,
      episode: args.episode,
      coverUrl: args.coverUrl ?? '',
      sourceUrl: url,
      status: 'downloading',
      progress: 0.05,
      totalBytes: estimated,
      downloadedBytes: Math.round(estimated * 0.05),
      downloadedAt: new Date().toISOString(),
      durationSeconds: args.durationSeconds,
      pageUrls: [],
      blobKey: args.id,
    };
    this.put(initial);
    this.save();

    const controller = new AbortController();
    this.activeControllers.get(args.id)?.abort();
    this.activeControllers.set(args.id, controller);
    let timedOut = false;
    const timer = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, 10 * 60 * 1000);

    try {
      if (url.startsWith('http')) {
        try {
          const res = await fetch(url, { signal: controller.signal });
          if (res.ok) {
            const { ok, bytes } = await saveStreamToCache(args.id, res, 'video/mp4', (loaded, total) => {
              if (controller.signal.aborted || !this.value[args.id]) return;
              const denom = total > 0 ? total : Math.max(estimated, loaded);
              this.putIfPresent(args.id, {
                progress: Math.min(0.99, Math.max(0.05, loaded / denom)),
                downloadedBytes: loaded,
                totalBytes: denom,
              });
            });
            if (controller.signal.aborted && !timedOut) return;
            if (!timedOut && ok && bytes > 0) {
              if (this.putIfPresent(args.id, { status: 'completed', progress: 1, downloadedBytes: bytes, totalBytes: bytes })) {
                this.save();
              }
              return;
            }
          }
        } catch (e) {
          if (controller.signal.aborted && !timedOut) return;
          Logger.e(timedOut ? `Offline download timed out for ${args.id}` : `Offline download failed for ${args.id}`, e);
        }
      }
      if ((controller.signal.aborted && !timedOut) || this.activeControllers.get(args.id) !== controller) return;
      if (this.putIfPresent(args.id, { status: 'failed', progress: 0, downloadedBytes: 0 })) {
        this.save();
      }
    } finally {
      window.clearTimeout(timer);
      if (this.activeControllers.get(args.id) === controller) {
        this.activeControllers.delete(args.id);
      }
    }
  }

  async startDownloadMangaChapter(args: {
    slug: string;
    mangaTitle: string;
    coverUrl: string;
    chapterId: string;
    chapterTitle: string;
    pageUrls: string[];
    /** Rewrites a remote page URL through our image proxy (KatanaService.proxyImageUrl). */
    proxy?: (url: string) => string;
    /** Force delta re-download of evicted/missing Cache Storage pages even if status was 'completed'. */
    forceRepair?: boolean;
  }): Promise<void> {
    this.init();
    const id = OfflineIds.mangaChapterId(args.slug, args.chapterId);
    const existing = this.value[id];
    if (existing && isCompleted(existing) && !args.forceRepair && (existing.cacheMissingPages ?? 0) === 0) return;
    const proxy = args.proxy ?? this.mangaProxyMap.get(id) ?? defaultMangaPageProxy;
    this.mangaProxyMap.set(id, proxy);
    const estimated = args.pageUrls.length * 750 * 1024;
    const priorPages = existing && existing.pageUrls.length === args.pageUrls.length ? (existing.downloadedPages ?? 0) : 0;
    const priorProgress =
      args.pageUrls.length > 0 && priorPages > 0
        ? Math.min(0.98, Math.max(0.1, priorPages / args.pageUrls.length))
        : existing && existing.progress > 0.1 && existing.progress < 1
          ? existing.progress
          : 0.1;
    const initial: OfflineMediaItem = {
      id,
      type: 'manga',
      mediaId: args.slug,
      title: args.mangaTitle,
      subtitle: args.chapterTitle,
      chapterId: args.chapterId,
      coverUrl: args.coverUrl,
      status: 'downloading',
      progress: priorProgress,
      totalBytes: existing && existing.totalBytes > 0 ? existing.totalBytes : estimated,
      downloadedBytes:
        existing && existing.downloadedBytes > 0 ? existing.downloadedBytes : Math.round(estimated * priorProgress),
      downloadedAt: existing?.downloadedAt || new Date().toISOString(),
      pageUrls: args.pageUrls,
      downloadedPages: priorPages,
      blobKey: id,
    };
    this.put(initial);
    this.save();

    const controller = new AbortController();
    this.activeControllers.get(id)?.abort();
    this.activeControllers.set(id, controller);

    const waitBackoff = (ms: number) =>
      new Promise<void>((resolve) => {
        if (controller.signal.aborted) {
          resolve();
          return;
        }
        const t = setTimeout(() => {
          controller.signal.removeEventListener('abort', onAbort);
          resolve();
        }, ms);
        const onAbort = () => {
          clearTimeout(t);
          resolve();
        };
        controller.signal.addEventListener('abort', onAbort, { once: true });
      });

    try {
      if (args.pageUrls.length > 0) {
        let saved = 0;
        let total = 0;
        let storageFull = false;
        const downloadPage = async (i: number): Promise<boolean> => {
          if (controller.signal.aborted || !this.value[id] || storageFull) return false;
          const raw = args.pageUrls[i];
          const pageKey = `${id}_p_${i + 1}`;
          const cachedSize = await getCachedBlobSize(pageKey, true);
          if (controller.signal.aborted || !this.value[id] || storageFull) return false;
          if (cachedSize > 0) {
            saved++;
            total += cachedSize;
          } else {
            const src = raw.startsWith('http')
              ? proxy(raw)
              : raw.startsWith('assets/')
                ? `/${raw}`
                : raw.startsWith('/') || raw.startsWith('data:')
                  ? raw
                  : null;
            if (src) {
              let blob: Blob | null = null;
              let lastStatus = 0;
              const backoffDelays = [0, 500, 1400];
              for (let attempt = 0; attempt < backoffDelays.length; attempt++) {
                if (backoffDelays[attempt] > 0) {
                  await waitBackoff(backoffDelays[attempt]);
                }
                if (controller.signal.aborted || !this.value[id] || storageFull) return false;
                const pageController = new AbortController();
                const onParentAbort = () => pageController.abort();
                controller.signal.addEventListener('abort', onParentAbort, { once: true });
                const timer = setTimeout(() => pageController.abort(), 15000);
                try {
                  const res = await fetch(src, { signal: pageController.signal });
                  lastStatus = res.status;
                  if (res.ok) {
                    blob = await res.blob();
                  } else {
                    await res.body?.cancel().catch(() => {});
                    blob = null;
                  }
                } catch {
                  blob = null;
                } finally {
                  clearTimeout(timer);
                  controller.signal.removeEventListener('abort', onParentAbort);
                }
                if (blob && blob.size > 0) break;
              }
              if (controller.signal.aborted || !this.value[id] || storageFull) return false;
              if (blob && blob.size > 0) {
                const mime = blob.type && blob.type.startsWith('image/') ? blob.type : 'image/jpeg';
                const stored = await saveBlob(pageKey, blob, true, mime);
                if (stored) {
                  saved++;
                  total += blob.size;
                } else {
                  Logger.e(`Failed to cache manga page ${i} (${pageKey}) — storage quota may be full`);
                  storageFull = true;
                  return false;
                }
              } else {
                Logger.e(`Failed to fetch manga page ${i} (${src}) after retries: status ${lastStatus}`);
              }
            }
          }
          const progress = Math.min(1, saved / args.pageUrls.length);
          return this.putIfPresent(id, {
            progress,
            downloadedPages: saved,
            downloadedBytes: total > 0 ? total : Math.round(estimated * progress),
          });
        };
        try {
          const firstOk = await downloadPage(0);
          if (firstOk && !storageFull && !controller.signal.aborted && this.value[id] && args.pageUrls.length > 1) {
            let nextIndex = 1;
            const workerCount = Math.min(3, args.pageUrls.length - 1);
            const runWorker = async () => {
              while (!storageFull && !controller.signal.aborted && this.value[id]) {
                const i = nextIndex++;
                if (i >= args.pageUrls.length) break;
                if (!(await downloadPage(i))) return;
              }
            };
            await Promise.all(Array.from({ length: workerCount }, () => runWorker()));
          }
          if (controller.signal.aborted || !this.value[id]) return;
          if (saved === args.pageUrls.length && saved > 0) {
            const bytes = total > 0 ? total : estimated;
            if (
              this.putIfPresent(id, {
                status: 'completed',
                progress: 1,
                downloadedPages: saved,
                verifiedCachedPages: saved,
                cacheMissingPages: 0,
                cacheVerifiedAt: new Date().toISOString(),
                downloadedBytes: bytes,
                totalBytes: bytes,
              })
            ) {
              this.save();
            }
            return;
          }
        } catch (e) {
          if (controller.signal.aborted) return;
          Logger.e(`Manga chapter download failed for ${id}`, e);
        }
        if (controller.signal.aborted) return;
        // Keep already-cached page blobs intact so resume/retry continues from the remaining pages!
        const partialProgress = args.pageUrls.length > 0 ? Math.min(0.99, saved / args.pageUrls.length) : 0;
        if (
          this.putIfPresent(id, {
            status: 'failed',
            progress: partialProgress,
            downloadedPages: saved,
            verifiedCachedPages: saved,
            cacheMissingPages: Math.max(0, args.pageUrls.length - saved),
            cacheVerifiedAt: new Date().toISOString(),
            downloadedBytes: total,
          })
        ) {
          this.save();
        }
        return;
      }
      if (controller.signal.aborted) return;
      if (this.putIfPresent(id, { status: 'failed', progress: 0, downloadedPages: 0, downloadedBytes: 0 })) {
        this.save();
      }
    } finally {
      if (this.activeControllers.get(id) === controller) {
        this.activeControllers.delete(id);
      }
    }
  }

  pauseDownload(id: string) {
    this.activeControllers.get(id)?.abort();
    this.activeControllers.delete(id);
    const item = this.value[id];
    if (!item) return;
    this.put({ ...item, status: 'paused' });
    this.save();
  }

  async resumeDownload(id: string) {
    const item = this.value[id];
    if (!item) return;
    if (item.sourceUrl) {
      await this.startDownloadMedia({ ...item, sourceUrl: item.sourceUrl });
    } else if (item.type === 'manga' && item.pageUrls.length > 0) {
      await this.startDownloadMangaChapter({
        slug: item.mediaId,
        mangaTitle: item.title,
        coverUrl: item.coverUrl,
        chapterId: item.chapterId ?? '1',
        chapterTitle: item.subtitle,
        pageUrls: item.pageUrls,
        proxy: this.mangaProxyMap.get(id),
      });
    }
  }

  async deleteDownload(id: string) {
    this.activeControllers.get(id)?.abort();
    this.activeControllers.delete(id);
    this.mangaProxyMap.delete(id);
    const item = this.value[id];
    if (!item) return;
    const next = { ...this.value };
    delete next[id];
    this.value = next;
    this.save();
    await deleteItemBlobs(item);
  }

  async clearAll(type?: OfflineMediaType) {
    if (type == null) {
      for (const ctrl of this.activeControllers.values()) ctrl.abort();
      this.activeControllers.clear();
      this.mangaProxyMap.clear();
      this.value = {};
      this.save();
      await clearStorage();
    } else {
      const toDelete = Object.values(this.value).filter((item) => item.type === type);
      const next = { ...this.value };
      for (const item of toDelete) {
        this.activeControllers.get(item.id)?.abort();
        this.activeControllers.delete(item.id);
        this.mangaProxyMap.delete(item.id);
        delete next[item.id];
      }
      this.value = next;
      this.save();
      for (const item of toDelete) {
        await deleteItemBlobs(item);
      }
    }
  }

  updatePlaybackPosition(id: string, positionSeconds: number, immediate = false) {
    const item = this.value[id];
    if (!item) return;
    this.put({ ...item, lastPositionSeconds: positionSeconds });
    const now = Date.now();
    if (immediate || now - this.lastPositionSave >= 10000) {
      this.lastPositionSave = now;
      this.save();
    }
  }

  flushPlaybackPosition() {
    this.save();
  }

  async getPlayableUrl(item: OfflineMediaItem): Promise<string | null> {
    if (!item.blobKey) return null;
    return (await getBlobUrl(item.blobKey, item.type === 'manga')) || null;
  }

  private isBundledOrInlinePageUrl(raw: string): boolean {
    if (!raw) return false;
    if (raw.startsWith('data:')) return true;
    if (AgentMode.demo && (raw.startsWith('/images/demo/') || raw.startsWith('images/demo/'))) {
      return true;
    }
    return false;
  }

  /**
   * Verifies every page of a downloaded manga chapter in Cache Storage (`everglow-offline-manga-v1`),
   * updating `verifiedCachedPages` and `cacheMissingPages` so browser cache eviction is surfaced
   * instead of silently treated as offline-ready.
   */
  async verifyMangaChapterCache(
    itemId: string,
  ): Promise<{ totalPages: number; cachedPages: number; missingPages: number; isComplete: boolean }> {
    this.init();
    const item = this.value[itemId];
    if (!item || item.type !== 'manga') {
      return { totalPages: 0, cachedPages: 0, missingPages: 0, isComplete: false };
    }
    const totalPages = item.pageUrls.length;
    if (totalPages === 0) {
      return { totalPages: 0, cachedPages: 0, missingPages: 0, isComplete: false };
    }
    let cachedPages = 0;
    for (let i = 1; i <= totalPages; i++) {
      const raw = item.pageUrls[i - 1] ?? '';
      const size = await getCachedBlobSize(`${itemId}_p_${i}`, true);
      if (size > 0 || this.isBundledOrInlinePageUrl(raw)) {
        cachedPages += 1;
      }
    }
    const missingPages = Math.max(0, totalPages - cachedPages);
    const prevMissing = item.cacheMissingPages ?? 0;
    const prevVerified = item.verifiedCachedPages;
    if (prevMissing !== missingPages || prevVerified !== cachedPages) {
      if (
        this.putIfPresent(itemId, {
          verifiedCachedPages: cachedPages,
          cacheMissingPages: missingPages,
          cacheVerifiedAt: new Date().toISOString(),
        })
      ) {
        this.save();
      }
    }
    return {
      totalPages,
      cachedPages,
      missingPages,
      isComplete: missingPages === 0,
    };
  }

  async verifyAllMangaChaptersCache(): Promise<{
    checked: number;
    evictedChapters: number;
    missingPages: number;
  }> {
    this.init();
    const chapters = Object.values(this.value).filter((i) => i.type === 'manga' && isCompleted(i));
    let evictedChapters = 0;
    let missingPages = 0;
    for (const ch of chapters) {
      const res = await this.verifyMangaChapterCache(ch.id);
      if (res.missingPages > 0) {
        evictedChapters += 1;
        missingPages += res.missingPages;
      }
    }
    return {
      checked: chapters.length,
      evictedChapters,
      missingPages,
    };
  }

  async repairMangaChapter(itemId: string, proxy?: (url: string) => string): Promise<void> {
    this.init();
    const item = this.value[itemId];
    if (!item || item.type !== 'manga' || item.pageUrls.length === 0) return;
    await this.startDownloadMangaChapter({
      slug: item.mediaId,
      mangaTitle: item.title,
      coverUrl: item.coverUrl,
      chapterId: item.chapterId ?? '1',
      chapterTitle: item.subtitle,
      pageUrls: item.pageUrls,
      proxy: proxy ?? this.mangaProxyMap.get(itemId),
      forceRepair: true,
    });
  }

  async repairAllEvictedMangaChapters(proxy?: (url: string) => string): Promise<number> {
    this.init();
    const evicted = Object.values(this.value).filter(
      (i) => i.type === 'manga' && isCompleted(i) && (i.cacheMissingPages ?? 0) > 0,
    );
    for (const item of evicted) {
      await this.repairMangaChapter(item.id, proxy);
    }
    return evicted.length;
  }

  /**
   * Returns a verified offline page URL from Cache Storage (`blob:` URL) or bundled data/demo asset.
   * Never silently substitutes a remote network URL when a cached page was evicted—records the
   * cache miss on the item so the UI surfaces a repair/re-download state.
   */
  async getMangaPageUrl(
    itemId: string,
    pageNumber: number,
    opts?: { allowRemoteFallback?: boolean },
  ): Promise<string | null> {
    const url = await getBlobUrl(`${itemId}_p_${pageNumber}`, true);
    if (url) return url;
    const item = this.value[itemId];
    if (!item || pageNumber <= 0 || pageNumber > item.pageUrls.length) return null;
    const raw = item.pageUrls[pageNumber - 1];
    if (this.isBundledOrInlinePageUrl(raw) && (item.cacheMissingPages ?? 0) === 0) {
      return raw;
    }
    // Cache Storage miss for an offline chapter: flag missing pages immediately and verify full chapter cache
    if ((item.cacheMissingPages ?? 0) === 0) {
      this.putIfPresent(itemId, {
        cacheMissingPages: Math.max(1, item.cacheMissingPages ?? 1),
        verifiedCachedPages: Math.max(0, item.pageUrls.length - 1),
        cacheVerifiedAt: new Date().toISOString(),
      });
      this.save();
    }
    void this.verifyMangaChapterCache(itemId);
    const isOffline = typeof navigator !== 'undefined' && navigator.onLine === false;
    if (isOffline || opts?.allowRemoteFallback !== true) {
      return null;
    }
    return raw;
  }

  revokeBlobUrl(url: string | null | undefined) {
    revokeObjectUrl(url);
  }

  revokeBlobUrls(urls: Iterable<string>) {
    for (const url of urls) revokeObjectUrl(url);
  }

  /**
   * Exports a downloaded manga chapter as a portable, standards-compliant `.cbz` (ZIP archive)
   * containing `001.jpg..NNN.jpg` plus a `comicinfo.json` manifest so pages are never trapped
   * inside browser Cache Storage.
   */
  async exportMangaChapterCbz(itemId: string): Promise<{ blob: Blob; filename: string } | null> {
    this.init();
    const item = this.value[itemId];
    if (!item || item.type !== 'manga') return null;
    const files: Array<{ name: string; data: Uint8Array }> = [];
    const totalPages = Math.max(item.pageUrls.length, item.downloadedPages ?? 0);
    let mangaCache: Cache | null = null;
    try {
      mangaCache = await caches.open(MANGA_CACHE);
    } catch {
      mangaCache = null;
    }
    for (let i = 1; i <= totalPages; i++) {
      let bytes: Uint8Array | null = null;
      if (mangaCache) {
        try {
          const res = await mangaCache.match(cacheKey(`${itemId}_p_${i}`, true));
          if (res) {
            const buf = await res.arrayBuffer();
            if (buf.byteLength > 0) bytes = new Uint8Array(buf);
          }
        } catch {
          bytes = null;
        }
      }
      if (!bytes && item.pageUrls[i - 1]) {
        try {
          const rawUrl = item.pageUrls[i - 1];
          const res = await fetch(rawUrl.startsWith('assets/') ? `/${rawUrl}` : rawUrl, {
            signal: AbortSignal.timeout(15_000),
          });
          if (res.ok) {
            const buf = await res.arrayBuffer();
            if (buf.byteLength > 0) bytes = new Uint8Array(buf);
          }
        } catch {
          bytes = null;
        }
      }
      if (bytes && bytes.byteLength > 0) {
        files.push({ name: `${String(i).padStart(3, '0')}.jpg`, data: bytes });
      }
    }
    if (files.length === 0) return null;
    const chapterNumber = (item.chapterId ?? '1').replace(/^c/i, '');
    const manifest = JSON.stringify(
      {
        format: 'mangacelestia-cbz-v1',
        id: item.id,
        slug: item.mediaId,
        title: item.title,
        subtitle: item.subtitle,
        chapterId: item.chapterId ?? '1',
        coverUrl: item.coverUrl,
        pageCount: files.length,
        exportedAt: new Date().toISOString(),
      },
      null,
      2,
    );
    const comicInfoXml = [
      '<?xml version="1.0" encoding="utf-8"?>',
      '<ComicInfo xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">',
      `  <Series>${escapeXmlText(item.title || item.mediaId)}</Series>`,
      `  <Title>${escapeXmlText(item.subtitle || `Chapter ${chapterNumber}`)}</Title>`,
      `  <Number>${escapeXmlText(chapterNumber)}</Number>`,
      `  <PageCount>${files.length}</PageCount>`,
      '  <Manga>Yes</Manga>',
      `  <Web>${escapeXmlText(item.mediaId)}</Web>`,
      '</ComicInfo>',
    ].join('\n');
    files.push({ name: 'ComicInfo.xml', data: new TextEncoder().encode(comicInfoXml) });
    files.push({ name: 'comicinfo.json', data: new TextEncoder().encode(manifest) });
    const safeSlug = (item.mediaId || 'manga').replace(/[^a-z0-9_-]+/gi, '-');
    const safeCh = (item.chapterId || 'ch1').replace(/[^a-z0-9._-]+/gi, '-');
    return {
      blob: buildStoreZipBlob(files),
      filename: `${safeSlug}-${safeCh}.cbz`,
    };
  }

  /**
   * Imports a `.cbz` / `.zip` chapter archive (both stored method 0 and DEFLATE method 8,
   * with `ComicInfo.xml` or `comicinfo.json` metadata) into `everglow-offline-manga-v1`
   * Cache Storage and registers the offline chapter item.
   */
  async importMangaChapterCbz(file: File): Promise<OfflineMediaItem | null> {
    this.init();
    try {
      const buf = await file.arrayBuffer();
      const entries = await parseZipEntries(buf);
      if (entries.length === 0) return null;
      const manifestEntry = entries.find((e) => e.name.toLowerCase().endsWith('comicinfo.json'));
      const xmlEntry = entries.find((e) => e.name.toLowerCase().endsWith('comicinfo.xml'));
      let meta: {
        slug?: string;
        title?: string;
        subtitle?: string;
        chapterId?: string;
        coverUrl?: string;
      } = {};
      if (manifestEntry) {
        try {
          meta = JSON.parse(new TextDecoder().decode(manifestEntry.data));
        } catch {
          meta = {};
        }
      } else if (xmlEntry) {
        meta = parseComicInfoXml(new TextDecoder().decode(xmlEntry.data));
      }
      const imageEntries = entries
        .filter((e) => /\.(jpe?g|png|webp)$/i.test(e.name))
        .sort((a, b) => a.name.localeCompare(b.name));
      if (imageEntries.length === 0) return null;
      const baseName = file.name.replace(/\.(cbz|zip)$/i, '');
      const slug = (meta.slug || baseName.split('-ch')[0] || 'imported-manga')
        .toLowerCase()
        .replace(/[^a-z0-9_-]+/g, '-');
      const chapterId = meta.chapterId || 'c1';
      const id = OfflineIds.mangaChapterId(slug, chapterId);
      const existing = this.value[id];
      const prepared = imageEntries.map((img) => ({
        img,
        mime: img.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : img.name.toLowerCase().endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg',
      }));
      let totalBytes = 0;
      const pageUrls: string[] = [];
      if (existing) {
        // Stage into temporary keys first so a quota failure never damages the existing chapter.
        for (let i = 0; i < prepared.length; i++) {
          const { img, mime } = prepared[i];
          const tmpKey = `${id}_tmp_p_${i + 1}`;
          const stored = await saveBlob(tmpKey, new Blob([img.data as BlobPart], { type: mime }), true, mime);
          if (!stored) {
            for (let j = 1; j <= i; j++) {
              await deleteBlob(`${id}_tmp_p_${j}`, true);
            }
            Logger.e(`OfflineMediaService: failed to stage CBZ page ${i + 1} for ${id}`);
            return null;
          }
        }
        const prevCount = existing.pageUrls?.length ?? 0;
        for (let i = prepared.length + 1; i <= prevCount; i++) {
          await deleteBlob(`${id}_p_${i}`, true);
        }
        for (let i = 0; i < prepared.length; i++) {
          const { img, mime } = prepared[i];
          const pageKey = `${id}_p_${i + 1}`;
          const stored = await saveBlob(pageKey, new Blob([img.data as BlobPart], { type: mime }), true, mime);
          await deleteBlob(`${id}_tmp_p_${i + 1}`, true);
          if (!stored) {
            for (let j = i + 2; j <= prepared.length; j++) {
              await deleteBlob(`${id}_tmp_p_${j}`, true);
            }
            this.putIfPresent(id, { status: 'failed', cacheMissingPages: prepared.length - i });
            Logger.e(`OfflineMediaService: failed to commit CBZ page ${i + 1} for ${id}`);
            return null;
          }
          totalBytes += img.data.byteLength;
          pageUrls.push(cacheKey(pageKey, true));
        }
      } else {
        for (let i = 0; i < prepared.length; i++) {
          const { img, mime } = prepared[i];
          const pageKey = `${id}_p_${i + 1}`;
          const stored = await saveBlob(pageKey, new Blob([img.data as BlobPart], { type: mime }), true, mime);
          if (!stored) {
            for (let j = 1; j <= i; j++) {
              await deleteBlob(`${id}_p_${j}`, true);
            }
            Logger.e(`OfflineMediaService: failed to cache CBZ page ${i + 1} for ${id}`);
            return null;
          }
          totalBytes += img.data.byteLength;
          pageUrls.push(cacheKey(pageKey, true));
        }
      }
      const restored: OfflineMediaItem = {
        id,
        type: 'manga',
        mediaId: slug,
        title: meta.title || baseName,
        subtitle: meta.subtitle || `Chapter ${chapterId.replace(/^c/i, '')}`,
        chapterId,
        coverUrl: meta.coverUrl || '',
        status: 'completed',
        progress: 1,
        totalBytes,
        downloadedBytes: totalBytes,
        downloadedAt: new Date().toISOString(),
        pageUrls,
        downloadedPages: imageEntries.length,
        blobKey: id,
      };
      this.put(restored);
      this.save();
      return restored;
    } catch (e) {
      Logger.e('OfflineMediaService: failed to import CBZ archive', e);
      return null;
    }
  }
}

const CRC32_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[i] = c >>> 0;
  }
  return table;
})();

function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) {
    crc = CRC32_TABLE[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function buildStoreZipBlob(files: Array<{ name: string; data: Uint8Array }>): Blob {
  const enc = new TextEncoder();
  const localParts: Uint8Array[] = [];
  const centralParts: Uint8Array[] = [];
  let offset = 0;

  for (const file of files) {
    const nameBytes = enc.encode(file.name);
    const crc = crc32(file.data);
    const size = file.data.byteLength;

    const local = new Uint8Array(30 + nameBytes.length);
    const lv = new DataView(local.buffer);
    lv.setUint32(0, 0x04034b50, true);
    lv.setUint16(4, 20, true);
    lv.setUint16(6, 0x0800, true);
    lv.setUint16(8, 0, true); // store (uncompressed)
    lv.setUint32(14, crc, true);
    lv.setUint32(18, size, true);
    lv.setUint32(22, size, true);
    lv.setUint16(26, nameBytes.length, true);
    local.set(nameBytes, 30);
    localParts.push(local, file.data);

    const central = new Uint8Array(46 + nameBytes.length);
    const cv = new DataView(central.buffer);
    cv.setUint32(0, 0x02014b50, true);
    cv.setUint16(4, 20, true);
    cv.setUint16(6, 20, true);
    cv.setUint16(8, 0x0800, true);
    cv.setUint16(10, 0, true);
    cv.setUint32(16, crc, true);
    cv.setUint32(20, size, true);
    cv.setUint32(24, size, true);
    cv.setUint16(28, nameBytes.length, true);
    cv.setUint32(42, offset, true);
    central.set(nameBytes, 46);
    centralParts.push(central);

    offset += local.byteLength + size;
  }

  const centralSize = centralParts.reduce((s, p) => s + p.byteLength, 0);
  const eocd = new Uint8Array(22);
  const ev = new DataView(eocd.buffer);
  ev.setUint32(0, 0x06054b50, true);
  ev.setUint16(8, files.length, true);
  ev.setUint16(10, files.length, true);
  ev.setUint32(12, centralSize, true);
  ev.setUint32(16, offset, true);

  return new Blob([...localParts, ...centralParts, eocd] as BlobPart[], { type: 'application/vnd.comicbook+zip' });
}

function escapeXmlText(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function unescapeXmlText(value: string): string {
  return value
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&');
}

function parseComicInfoXml(xml: string): {
  slug?: string;
  title?: string;
  subtitle?: string;
  chapterId?: string;
} {
  const tag = (name: string): string | undefined => {
    const m = new RegExp(`<${name}[^>]*>([\\s\\S]*?)<\\/${name}>`, 'i').exec(xml);
    return m ? unescapeXmlText(m[1].trim()) : undefined;
  };
  const series = tag('Series');
  const title = tag('Title');
  const num = tag('Number');
  const web = tag('Web');
  return {
    slug: web && !/^https?:\/\//i.test(web) ? web : series?.toLowerCase().replace(/[^a-z0-9_-]+/g, '-'),
    title: series || title,
    subtitle: title || (num ? `Chapter ${num}` : undefined),
    chapterId: num ? (num.startsWith('c') ? num : `c${num}`) : undefined,
  };
}

const MAX_CBZ_ENTRIES = 500;
const MAX_CBZ_ENTRY_BYTES = 25 * 1024 * 1024;
const MAX_CBZ_TOTAL_BYTES = 250 * 1024 * 1024;

async function inflateDeflateRaw(compressed: Uint8Array, maxBytes: number): Promise<Uint8Array | null> {
  if (typeof DecompressionStream === 'undefined' || maxBytes <= 0) return null;
  try {
    const ds = new DecompressionStream('deflate-raw');
    const writer = ds.writable.getWriter();
    const writePromise = writer
      .write(compressed as unknown as BufferSource)
      .then(() => writer.close())
      .catch(() => {});
    const reader = ds.readable.getReader();
    const chunks: Uint8Array[] = [];
    let total = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        total += value.byteLength;
        if (total > maxBytes) {
          await reader.cancel().catch(() => {});
          throw new ZipLimitError('ZIP entry exceeds size limit');
        }
        chunks.push(value);
      }
    } finally {
      await writePromise;
    }
    const out = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) {
      out.set(chunk, offset);
      offset += chunk.byteLength;
    }
    return out;
  } catch (e) {
    if (e instanceof ZipLimitError) throw e;
    return null;
  }
}

class ZipLimitError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ZipLimitError';
  }
}

async function decodeZipEntryPayload(
  buf: ArrayBuffer,
  method: number,
  dataStart: number,
  compSize: number,
  maxBytes: number,
): Promise<Uint8Array | null> {
  if (compSize <= 0 || dataStart < 0 || dataStart + compSize > buf.byteLength) return null;
  if (maxBytes <= 0) throw new ZipLimitError('ZIP archive exceeds size limit');
  if (method === 0) {
    if (compSize > maxBytes) throw new ZipLimitError('ZIP entry exceeds size limit');
    return new Uint8Array(buf.slice(dataStart, dataStart + compSize));
  }
  if (method === 8) {
    const slice = new Uint8Array(buf.slice(dataStart, dataStart + compSize));
    return inflateDeflateRaw(slice, maxBytes);
  }
  return null;
}

export async function parseZipEntries(
  buf: ArrayBuffer,
  limits?: { maxEntries?: number; maxEntryBytes?: number; maxTotalBytes?: number },
): Promise<Array<{ name: string; data: Uint8Array }>> {
  const maxEntries = limits?.maxEntries ?? MAX_CBZ_ENTRIES;
  const maxEntryBytes = limits?.maxEntryBytes ?? MAX_CBZ_ENTRY_BYTES;
  const maxTotalBytes = limits?.maxTotalBytes ?? MAX_CBZ_TOTAL_BYTES;
  const view = new DataView(buf);
  const dec = new TextDecoder();
  const out: Array<{ name: string; data: Uint8Array }> = [];
  let totalDecodedBytes = 0;

  // Prefer Central Directory when present (handles DEFLATE + streaming data descriptors).
  const minEocdOffset = Math.max(0, buf.byteLength - 65557);
  let eocdPos = -1;
  for (let p = buf.byteLength - 22; p >= minEocdOffset; p--) {
    if (view.getUint32(p, true) === 0x06054b50) {
      eocdPos = p;
      break;
    }
  }
  if (eocdPos >= 0) {
    const rawTotalEntries = view.getUint16(eocdPos + 10, true);
    if (rawTotalEntries > maxEntries) {
      throw new ZipLimitError(`ZIP archive exceeds max entry limit (${maxEntries})`);
    }
    let cdPos = view.getUint32(eocdPos + 16, true);
    for (let i = 0; i < rawTotalEntries && cdPos + 46 <= buf.byteLength; i++) {
      if (view.getUint32(cdPos, true) !== 0x02014b50) break;
      const method = view.getUint16(cdPos + 10, true);
      const compSize = view.getUint32(cdPos + 20, true);
      const uncompSize = view.getUint32(cdPos + 24, true);
      const nameLen = view.getUint16(cdPos + 28, true);
      const extraLen = view.getUint16(cdPos + 30, true);
      const commentLen = view.getUint16(cdPos + 32, true);
      const localOffset = view.getUint32(cdPos + 42, true);
      const nextCdPos = cdPos + 46 + nameLen + extraLen + commentLen;
      if (cdPos + 46 + nameLen > buf.byteLength || nextCdPos > buf.byteLength) break;
      const name = dec.decode(new Uint8Array(buf, cdPos + 46, nameLen));
      const remainingBudget = Math.min(maxEntryBytes, maxTotalBytes - totalDecodedBytes);
      if (remainingBudget <= 0 || uncompSize > remainingBudget) {
        throw new ZipLimitError('ZIP archive exceeds size limit');
      }
      if (
        localOffset + 30 <= buf.byteLength &&
        view.getUint32(localOffset, true) === 0x04034b50
      ) {
        const localNameLen = view.getUint16(localOffset + 26, true);
        const localExtraLen = view.getUint16(localOffset + 28, true);
        const dataStart = localOffset + 30 + localNameLen + localExtraLen;
        const decoded = await decodeZipEntryPayload(buf, method, dataStart, compSize, remainingBudget);
        if (decoded) {
          totalDecodedBytes += decoded.byteLength;
          out.push({ name, data: decoded });
        }
      }
      cdPos = nextCdPos;
    }
    if (out.length > 0) return out;
  }

  // Fallback: walk Local File Headers sequentially.
  let pos = 0;
  while (pos + 30 <= buf.byteLength) {
    const sig = view.getUint32(pos, true);
    if (sig !== 0x04034b50) break;
    if (out.length >= maxEntries) {
      throw new ZipLimitError(`ZIP archive exceeds max entry limit (${maxEntries})`);
    }
    const method = view.getUint16(pos + 8, true);
    const compSize = view.getUint32(pos + 18, true);
    const uncompSize = view.getUint32(pos + 22, true);
    const nameLen = view.getUint16(pos + 26, true);
    const extraLen = view.getUint16(pos + 28, true);
    const nameStart = pos + 30;
    const dataStart = nameStart + nameLen + extraLen;
    if (dataStart + compSize > buf.byteLength) break;
    const name = dec.decode(new Uint8Array(buf, nameStart, nameLen));
    const remainingBudget = Math.min(maxEntryBytes, maxTotalBytes - totalDecodedBytes);
    if (remainingBudget <= 0 || uncompSize > remainingBudget) {
      throw new ZipLimitError('ZIP archive exceeds size limit');
    }
    const decoded = await decodeZipEntryPayload(buf, method, dataStart, compSize, remainingBudget);
    if (decoded) {
      totalDecodedBytes += decoded.byteLength;
      out.push({ name, data: decoded });
    }
    pos = dataStart + compSize;
  }
  return out;
}

export const offlineMedia = new OfflineMediaService();
export const OfflineIds = {
  mangaChapterId: (slug: string, chapterId: string) => `manga_${slug}_ch_${chapterId}`,
  animeEpisodeId: (animeId: string | number, episode: number, season = 1) => `anime_${animeId}_s${season}_e${episode}`,
  cinemaEpisodeId: (tmdbId: number, season: number, episode: number) => `cinema_tv_${tmdbId}_s${season}_e${episode}`,
  cinemaMovieId: (tmdbId: number) => `cinema_movie_${tmdbId}`,
};

/** Rebuilds when the download list changes (Flutter's ListenableBuilder on the service). */
export function useOfflineMedia(): OfflineMediaService {
  useEffect(() => offlineMedia.init(), []);
  useValue(offlineMedia);
  return offlineMedia;
}

function demoItems(): OfflineMediaItem[] {
  const ago = (ms: number) => new Date(Date.now() - ms).toISOString();
  const H = 3600 * 1000;
  const M = 60 * 1000;
  const st = 'https://image.tmdb.org/t/p/w500/49WJfeN0moxb9IPfGn8AIqMGskD.jpg';
  const fr = 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-n1HJZ2s7vGgA.jpg';
  const sl = '/images/demo/poster-4.jpg';
  const pages = ['/images/demo/poster-1.jpg', '/images/demo/poster-2.jpg', '/images/demo/poster-3.jpg'];
  const base = { status: 'completed' as const, progress: 1, pageUrls: [] as string[] };
  const video = (
    id: string,
    type: OfflineMediaType,
    mediaId: string,
    title: string,
    subtitle: string,
    coverUrl: string,
    bytes: number,
    at: string,
    durationSeconds: number,
    lastPositionSeconds: number,
    season?: number,
    episode?: number,
  ): OfflineMediaItem => ({
    ...base,
    id,
    type,
    mediaId,
    title,
    subtitle,
    season,
    episode,
    coverUrl,
    sourceUrl: DEMO_SOURCE,
    totalBytes: bytes,
    downloadedBytes: bytes,
    downloadedAt: at,
    durationSeconds,
    lastPositionSeconds,
    blobKey: id,
  });
  const chapter = (n: string, subtitle: string, bytes: number, at: string): OfflineMediaItem => ({
    ...base,
    id: `manga_demo-starlight-manga_ch_${n}`,
    type: 'manga',
    mediaId: 'demo-starlight-manga',
    title: 'Fictional Starlight Manga',
    subtitle,
    chapterId: n,
    coverUrl: sl,
    totalBytes: bytes,
    downloadedBytes: bytes,
    downloadedAt: at,
    pageUrls: pages,
    blobKey: `manga_demo-starlight-manga_ch_${n}`,
  });
  const frieren = "Frieren: Beyond Journey's End";
  return [
    video(
      'cinema_movie_157336',
      'movie',
      '157336',
      'Interstellar',
      'Movie • 2014',
      'https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
      1520000000,
      ago(3 * H),
      10140,
      1250,
    ),
    video(
      'cinema_tv_66732_s1_e1',
      'tv',
      '66732',
      'Stranger Things',
      'S1 E1 • Chapter One: The Vanishing of Will Byers',
      st,
      740000000,
      ago(2 * H),
      2940,
      420,
      1,
      1,
    ),
    video(
      'cinema_tv_66732_s1_e2',
      'tv',
      '66732',
      'Stranger Things',
      'S1 E2 • Chapter Two: The Weirdo on Maple Street',
      st,
      710000000,
      ago(2 * H),
      3300,
      0,
      1,
      2,
    ),
    video(
      'cinema_tv_66732_s2_e1',
      'tv',
      '66732',
      'Stranger Things',
      'S2 E1 • Chapter One: MADMAX',
      st,
      780000000,
      ago(H),
      2880,
      0,
      2,
      1,
    ),
    video(
      'anime_154587_s1_e1',
      'anime',
      '154587',
      frieren,
      "Episode 1 • The Journey's End",
      fr,
      420000000,
      ago(90 * M),
      1440,
      610,
      1,
      1,
    ),
    video(
      'anime_154587_s1_e2',
      'anime',
      '154587',
      frieren,
      "Episode 2 • It Didn't Have to Be Magic...",
      fr,
      415000000,
      ago(80 * M),
      1440,
      0,
      1,
      2,
    ),
    video(
      'anime_154587_s1_e3',
      'anime',
      '154587',
      frieren,
      'Episode 3 • Killing Magic',
      fr,
      430000000,
      ago(70 * M),
      1440,
      0,
      1,
      3,
    ),
    chapter('1', "Chapter 1: I'm Used to It", 24000000, ago(50 * M)),
    chapter('2', 'Chapter 2: The Double Dungeon', 28000000, ago(40 * M)),
  ];
}
