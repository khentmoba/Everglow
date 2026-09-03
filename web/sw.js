// BUILD=6.0.0+1-9313f79
// Everglow service worker: app-shell + immutable-asset caching.
//
// Strategy:
// - CORE (flutter_bootstrap.js, main.dart.js): cache-first, populated on
//   install. These are content-hashed per Flutter build; the BUILD-stamped
//   CACHE name guarantees a fresh shell after every deploy, and `activate`
//   deletes all older caches so users never run mixed old-shell/new-asset.
// - IMMUTABLE (canvaskit/*, *.wasm, fonts, models, icons): cache-first with
//   runtime population. Canvaskit WASM (~7MB) and chibi_cat.glb (~4MB) are the
//   heaviest repeat-visit bytes; serving them from CacheStorage cuts repeat
//   load to near-zero network.
// - HTML/version probes (/, /index.html, /version.json, /sw.js,
//   /flutter_bootstrap.js is CORE so excluded here): network-only, no-store.
//   The app shell must never serve a stale entry point.
// - Everything else (posters, API proxies): network-first with cache
//   fallback, bounded to 120 entries to avoid unbounded CacheStorage growth
//   from TMDB/Spotify artwork.
const CACHE="6.0.0+1-9313f79-CACHE-v1";
const CORE=["flutter_bootstrap.js","main.dart.js"];
function isCore(path) {
  for (const a of CORE) if (path.endsWith(a)) return true;
  return false;
}
function isImmutable(url) {
  const p = new URL(url).pathname;
  if (p.startsWith("/canvaskit/")) return true;
  if (p.startsWith("/assets/") || p.startsWith("/icons/")) return true;
  return /\.(wasm|ttf|otf|woff2|glb|gltf|bin|data|mp3|js|css)$/.test(p);
}
function isNoStore(path) {
  return path === "/" || path === "/index.html" || path === "/version.json" ||
    path === "/sw.js" || path === "/flutter.js";
}
async function trimRuntime(cacheName, maxEntries) {
  try {
    const c = await caches.open(cacheName);
    const keys = await c.keys();
    if (keys.length > maxEntries) {
      await c.delete(keys[0]);
    }
  } catch (_) {}
}
self.addEventListener("install", (e) => {
  self.skipWaiting();
  e.waitUntil(
    caches.open(CACHE).then((c) => c.addAll(CORE).catch(() => {})),
  );
});
self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((ks) => Promise.all(
        ks.filter((k) => k !== CACHE).map((k) => caches.delete(k)),
      ))
      .then(() => self.clients.claim()),
  );
});
self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET") return;
  const url = new URL(e.request.url);
  // Only handle same-origin; CDN media (unpkg/jsdelivr/googleapis) keeps its
  // own HTTP-cache behavior and must not pollute the versioned cache.
  if (url.origin !== self.location.origin) return;
  const path = url.pathname;
  if (isNoStore(path)) {
    e.respondWith(fetch(e.request, { cache: "no-store" }));
    return;
  }
  if (isCore(path) || isImmutable(e.request.url)) {
    e.respondWith(
      caches.match(e.request).then((hit) => hit || fetch(e.request).then((res) => {
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(e.request, copy));
        }
        return res;
      })),
    );
    return;
  }
  // Default: network-first, fall back to cache when offline.
  e.respondWith(
    fetch(e.request)
      .then((res) => {
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then((c) => {
            c.put(e.request, copy).then(() => trimRuntime(CACHE, 240));
          });
        }
        return res;
      })
      .catch(() => caches.match(e.request)),
  );
});
