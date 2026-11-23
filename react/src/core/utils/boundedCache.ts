// Module-level caches live for the whole session, and this app is used for a
// long time on a phone. A cache without a ceiling quietly holds every detail
// payload the user ever opened until the tab is killed, so every long-lived
// `Map` goes through here.

/** Keeps `maxSize` newest entries, evicting the least recently written first. */
export function setBoundedCache<K, V>(cache: Map<K, V>, key: K, value: V, maxSize: number): void {
  cache.delete(key);
  cache.set(key, value);
  while (cache.size > maxSize) {
    const oldest = cache.keys().next().value;
    if (oldest === undefined) break;
    cache.delete(oldest);
  }
}

/** Drops the given caches when a profile signs out, so the next one starts fresh. */
export function clearOnLogout(...caches: { clear(): void }[]): void {
  if (typeof window === 'undefined') return;
  window.addEventListener('everglow:logout', () => {
    for (const cache of caches) cache.clear();
  });
}
