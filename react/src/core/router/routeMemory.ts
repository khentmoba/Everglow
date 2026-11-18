// Port of lib/core/router/route_memory.dart.
import { Prefs } from '../system/prefs';

const STORAGE_KEY = 'route_memory:last_location';

const EXTRA_ONLY_PATHS = new Set([
  '/academy/solo',
  '/academy/match',
  '/academy/podium',
  '/books/reader',
  '/books/detail',
  '/books/listen',
  '/books/list',
  '/books/category',
  '/manga/reader',
]);

export const RouteMemory = {
  storageKey: STORAGE_KEY,

  restorableOrNull(location: string | null | undefined): string | null {
    if (!location) return null;
    if (location.includes('..') || location.startsWith('//')) return null;
    if (/^[a-z][a-z0-9+.-]*:/i.test(location)) return null;
    try {
      const url = new URL(location, 'http://x');
      const path = url.pathname;
      if (!path || path === '/' || path.includes('..') || path.startsWith('//')) return null;
      if (EXTRA_ONLY_PATHS.has(path)) return null;
      return location;
    } catch {
      return null;
    }
  },

  load(): string | null {
    return this.restorableOrNull(Prefs.getString(STORAGE_KEY));
  },

  remember(location: string): void {
    const safe = this.restorableOrNull(location);
    if (!safe) return;
    Prefs.set(STORAGE_KEY, safe);
  },

  clear(): void {
    Prefs.remove(STORAGE_KEY);
  },
};
