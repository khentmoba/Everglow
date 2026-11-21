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

function formatBytes(bytes: number): string {
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
    const body = new Blob([bytes], { type: mimeType });
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

async function getBlobUrl(key: string, isManga: boolean): Promise<string | null> {
  try {
    const cache = await caches.open(isManga ? MANGA_CACHE : MEDIA_CACHE);
    const res = await cache.match(cacheKey(key, isManga));
    if (!res) return null;
    const url = URL.createObjectURL(await res.blob());
    objectUrls.add(url);
    return url;
  } catch (e) {
    Logger.e(`OfflineMediaStorage: could not create blob URL for ${key}`, e);
    return null;
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
    try {
      const raw = Prefs.getString(PREFS_KEY);
      if (raw) {
        for (const entry of JSON.parse(raw) as unknown[]) {
          if (entry && typeof entry === 'object') {
            const item = fromJson(entry as Record<string, unknown>);
            items[item.id] = item.status === 'downloading' ? { ...item, status: 'paused' } : item;
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
    return !!item && isCompleted(item) && item.downloadedBytes > 0;
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

  private put(item: OfflineMediaItem) {
    this.value = { ...this.value, [item.id]: item };
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

    if (url.startsWith('http')) {
      try {
        const res = await fetch(url, { signal: AbortSignal.timeout(10 * 60 * 1000) });
        const blob = res.ok ? await res.blob() : null;
        if (blob && blob.size > 0) {
          await saveBlob(args.id, blob, false, 'video/mp4');
          this.put({ ...initial, status: 'completed', progress: 1, downloadedBytes: blob.size, totalBytes: blob.size });
          this.save();
          return;
        }
      } catch (e) {
        Logger.e(`Offline download failed for ${args.id}`, e);
      }
    }
    this.put({ ...initial, status: 'failed', progress: 0, downloadedBytes: 0 });
    this.save();
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
  }): Promise<void> {
    this.init();
    const id = OfflineIds.mangaChapterId(args.slug, args.chapterId);
    const existing = this.value[id];
    if (existing && isCompleted(existing)) return;
    const estimated = args.pageUrls.length * 750 * 1024;
    const initial: OfflineMediaItem = {
      id,
      type: 'manga',
      mediaId: args.slug,
      title: args.mangaTitle,
      subtitle: args.chapterTitle,
      chapterId: args.chapterId,
      coverUrl: args.coverUrl,
      status: 'downloading',
      progress: 0.1,
      totalBytes: estimated,
      downloadedBytes: Math.round(estimated * 0.1),
      downloadedAt: new Date().toISOString(),
      pageUrls: args.pageUrls,
      blobKey: id,
    };
    this.put(initial);
    this.save();

    if (args.pageUrls.length > 0) {
      try {
        let saved = 0;
        let total = 0;
        for (let i = 0; i < args.pageUrls.length; i++) {
          const raw = args.pageUrls[i];
          const pageKey = `${id}_p_${i + 1}`;
          const src = raw.startsWith('http')
            ? args.proxy
              ? args.proxy(raw)
              : raw
            : raw.startsWith('assets/')
              ? `/${raw}`
              : null;
          if (src) {
            const res = await fetch(src, { signal: AbortSignal.timeout(15000) });
            const blob = res.ok ? await res.blob() : null;
            if (blob && blob.size > 0) {
              await saveBlob(pageKey, blob, true, 'image/jpeg');
              saved++;
              total += blob.size;
            } else {
              Logger.e(`Failed to fetch manga page ${i} (${src}): status ${res.status}`);
            }
          }
          const progress = Math.min(1, saved / args.pageUrls.length);
          this.put({ ...this.value[id], progress, downloadedBytes: total > 0 ? total : Math.round(estimated * progress) });
        }
        if (saved === args.pageUrls.length && saved > 0) {
          const bytes = total > 0 ? total : estimated;
          this.put({ ...this.value[id], status: 'completed', progress: 1, downloadedBytes: bytes, totalBytes: bytes });
          this.save();
          return;
        }
      } catch (e) {
        Logger.e(`Manga chapter download failed for ${id}`, e);
      }
    }
    for (let i = 1; i <= args.pageUrls.length; i++) await deleteBlob(`${id}_p_${i}`, true);
    this.put({ ...initial, status: 'failed', progress: 0, downloadedBytes: 0 });
    this.save();
  }

  pauseDownload(id: string) {
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
      });
    }
  }

  async deleteDownload(id: string) {
    const item = this.value[id];
    if (!item) return;
    const next = { ...this.value };
    delete next[id];
    await deleteItemBlobs(item);
    this.value = next;
    this.save();
  }

  async clearAll(type?: OfflineMediaType) {
    if (type == null) {
      this.value = {};
      await clearStorage();
    } else {
      const next = { ...this.value };
      for (const item of Object.values(this.value)) {
        if (item.type !== type) continue;
        delete next[item.id];
        await deleteItemBlobs(item);
      }
      this.value = next;
    }
    this.save();
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

  async getMangaPageUrl(itemId: string, pageNumber: number): Promise<string | null> {
    const url = await getBlobUrl(`${itemId}_p_${pageNumber}`, true);
    if (url) return url;
    const item = this.value[itemId];
    if (item && pageNumber > 0 && pageNumber <= item.pageUrls.length) return item.pageUrls[pageNumber - 1];
    return null;
  }

  revokeBlobUrl(url: string | null | undefined) {
    revokeObjectUrl(url);
  }

  revokeBlobUrls(urls: Iterable<string>) {
    for (const url of urls) revokeObjectUrl(url);
  }
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
  const sl = 'https://uploads.mangadex.org/covers/32d76d19-8a05-4db0-9fc2-e0b0648fe9d0/37aeaa0a-8bf7-42f5-b28e-f5139031c03a.jpg';
  const pages = ['assets/images/demo/poster-1.jpg', 'assets/images/demo/poster-2.jpg', 'assets/images/demo/poster-3.jpg'];
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
    id: `manga_solo-leveling_ch_${n}`,
    type: 'manga',
    mediaId: 'solo-leveling',
    title: 'Solo Leveling',
    subtitle,
    chapterId: n,
    coverUrl: sl,
    totalBytes: bytes,
    downloadedBytes: bytes,
    downloadedAt: at,
    pageUrls: pages,
    blobKey: `manga_solo-leveling_ch_${n}`,
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
