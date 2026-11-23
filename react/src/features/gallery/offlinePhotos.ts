// Port of lib/features/gallery/data/services/offline_photos_web.dart: small grid
// photos kept in a Cache Storage bucket the service worker serves offline.
import { Logger } from '../../core/system/logger';

const cacheName = 'everglow-offline-photos-v1';

function safeUrlPath(raw: string): string {
  try {
    const u = new URL(raw);
    return u.origin + u.pathname;
  } catch {
    return '<invalid-url>';
  }
}

export const OfflinePhotos = {
  get supported(): boolean {
    return typeof caches !== 'undefined';
  },

  async savedCount(): Promise<number> {
    try {
      const cache = await caches.open(cacheName);
      return (await cache.keys()).length;
    } catch (e) {
      Logger.e('Offline photos: could not count saved photos', e);
      return 0;
    }
  },

  async save(urls: string[], onProgress?: (done: number) => void): Promise<number> {
    const cache = await caches.open(cacheName);
    let saved = 0;
    let done = 0;
    for (const url of urls) {
      if (!url.startsWith('http')) {
        saved++;
        onProgress?.(++done);
        continue;
      }
      try {
        await cache.add(url);
        saved++;
      } catch (e) {
        Logger.e(`Offline photos: could not keep ${safeUrlPath(url)}`, e);
      }
      onProgress?.(++done);
    }
    return saved;
  },

  async clear(): Promise<void> {
    try {
      await caches.delete(cacheName);
    } catch (e) {
      Logger.e('Offline photos: could not clear saved photos', e);
    }
  },
};
