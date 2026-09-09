// BUILD=6.1.0+1-9b21b04
// Everglow service worker: app-shell + asset caching + push.
//
// Pairing with firebase.json (last matching header rule wins there):
// - Entry points (/, /index.html, flutter_bootstrap.js, version.json, sw.js)
//   are served `no-cache` over HTTP, and network-only here. The shell can
//   never go stale: a deploy is live on the next navigation.
// - The core shell (main.dart.js) carries a `?v=BUILD` query stamped by
//   tool/build_web.dart, so every build is a distinct cache key in the
//   STABLE core cache below. A reload after a deploy always misses and
//   fetches genuinely fresh bytes — no reliance on worker-activation
//   timing (the old BUILD-stamped shell cache served stale bytes whenever
//   the old worker was still active, which on slow lines was near-certain).
// - Repeat visits serve heavy bytes from CacheStorage with zero network;
//   HTTP `must-revalidate` (304s) is only the fallback when no worker
//   controls the page yet (very first visit).
//
// Push: this worker ALSO handles FCM background messages so a single
// registration owns the "/" scope. A second worker on the same scope
// (firebase-messaging-sw.js) would replace this one and kill offline
// caching, or vice versa — so that file is just a thin importScripts
// wrapper around this one, and both behave identically.
const SHELL="6.1.0+1-9b21b04-SHELL-v1";
// Stable across builds on purpose: entries rotate by `?v=` query, so a new
// build misses (fetches fresh) while the previous shell stays cached for
// offline boots. Only the newest two shells are kept (see trimCore).
const CORE="everglow-core-v1";
// Immutable bytes keyed by engine revision, not by app build: CanvasKit
// filenames are STABLE across Flutter builds, so a per-build purge would
// force a ~7MB re-download on every deploy even when the engine did not
// change. This cache is only purged when the stored revision mismatches.
// NOTE: keep ENGINE_REV in sync with the build output. The deploy
// workflow rewrites it from `flutter --version --machine` after the web
// build; a stale value only costs one extra wasm download, never staleness.
const ENGINE_REV="__ENGINE_REV__";
const IMMUTABLE="canvaskit-"+ENGINE_REV;
// Light precache only: the core shell is fetched on demand (by the page or
// by the update warm-up) and rotating it here as well would just download
// the 6MB twice on slow lines.
const PRECACHE=["/index.html"];
// Never cached: entry points, loaders, worker scripts, version probes,
// and Cloud Function rewrites (same-origin /api/* GETs must never serve stale).
const NO_STORE=["/","/index.html","/version.json","/sw.js","/firebase-messaging-sw.js","/flutter.js","/flutter_bootstrap.js","/flutter_service_worker.js","/manifest.json"];
function isNoStore(path) {
  if (path.startsWith("/api/")) return true;
  for (const n of NO_STORE) if (path === n) return true;
  return false;
}
function isCore(path) {
  // Query-blind on purpose: URL.pathname excludes `?v=`, so every build's
  // shell URL routes here while the cache key keeps the full query.
  return path.endsWith("main.dart.js");
}
function isImmutable(url) {
  const p = new URL(url).pathname;
  if (isNoStore(p)) return false;
  if (p.startsWith("/canvaskit/")) return true;
  if (p.startsWith("/assets/") || p.startsWith("/icons/")) return true;
  return /\.(wasm|ttf|otf|woff2|glb|gltf|bin|data|mp3|js|css)$/.test(p);
}
async function trimRuntime(cacheName, maxEntries) {
  try {
    const c = await caches.open(cacheName);
    const keys = await c.keys();
    const excess = keys.length - maxEntries;
    for (let i = 0; i < excess; i++) await c.delete(keys[i]);
  } catch (_) {}
}
async function trimCore() {
  try {
    const c = await caches.open(CORE);
    const keys = await c.keys();
    const shells = keys.filter((k) => new URL(k.url).pathname.endsWith("main.dart.js"));
    // Keep current + previous: an offline deploy-day still boots.
    while (shells.length > 2) await c.delete(shells.shift());
  } catch (_) {}
}
async function newestCoreEntry() {
  try {
    const c = await caches.open(CORE);
    const keys = await c.keys();
    for (let i = keys.length - 1; i >= 0; i--) {
      if (new URL(keys[i].url).pathname.endsWith("main.dart.js")) return keys[i];
    }
  } catch (_) {}
  return null;
}
self.addEventListener("install", (e) => {
  self.skipWaiting();
  e.waitUntil(
    caches.open(SHELL).then((c) => c.addAll(PRECACHE).catch(() => {}))
      .then(() => caches.open(IMMUTABLE).then((c) =>
        c.addAll(["/canvaskit/canvaskit.wasm"]).catch(() => {}))),
  );
});
self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((ks) => Promise.all(
        ks.filter((k) => k !== SHELL && k !== IMMUTABLE && k !== CORE).map((k) => caches.delete(k)),
      ))
      .then(() => self.clients.claim()),
  );
});
self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET") return;
  const url = new URL(e.request.url);
  // Only handle same-origin; CDN media (jsdelivr/googleapis/gstatic)
  // keeps its own HTTP-cache behavior and must not pollute the versioned cache.
  if (url.origin !== self.location.origin) return;
  const path = url.pathname;
  const offlineResponse = () => new Response("Offline", {
    status: 503,
    statusText: "Service Unavailable",
    headers: { "Content-Type": "text/plain" },
  });
  const fallbackNavigate = async () => {
    const cached = await caches.match(e.request);
    if (cached) return cached;
    const indexFallback = (await caches.match("/index.html")) || (await caches.match("/"));
    if (indexFallback) return indexFallback;
    try {
      const net = await fetch("/index.html");
      if (net && net.ok) {
        const copy = net.clone();
        caches.open(SHELL).then((c) => {
          c.put("/index.html", copy.clone());
          c.put("/", copy);
        });
        return net;
      }
    } catch (_) {}
    return offlineResponse();
  };
  if (isNoStore(path)) {
    e.respondWith(
      fetch(e.request, { cache: "no-store" })
        .then((res) => {
          if (res && res.ok && (path === "/" || path === "/index.html")) {
            const copy = res.clone();
            caches.open(SHELL).then((c) => {
              c.put("/index.html", copy.clone());
              c.put("/", copy);
            });
          }
          return res;
        })
        .catch(async () => {
          if (e.request.mode === "navigate") return fallbackNavigate();
          const cached = await caches.match(e.request);
          return cached || offlineResponse();
        }),
    );
    return;
  }
  // Immutable bytes (CanvasKit/WASM/fonts/models) live in the
  // engine-revision cache so app deploys do not evict them.
  if (isImmutable(e.request.url) && !isCore(path)) {
    e.respondWith(
      caches.match(e.request, { cacheName: IMMUTABLE }).then((hit) => hit || fetch(e.request).then((res) => {
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(IMMUTABLE).then((c) => c.put(e.request, copy));
        }
        return res;
      })).catch(async () => {
        const cached = await caches.match(e.request);
        return cached || offlineResponse();
      }),
    );
    return;
  }
  if (isCore(path)) {
    // Exact-URL match (query included): a new `?v=` always misses and
    // fetches genuinely fresh bytes, whatever worker is active. Offline
    // with an unknown `?v=`, boot the newest cached shell instead of dying.
    e.respondWith(
      caches.match(e.request, { cacheName: CORE }).then((hit) => {
        if (hit) return hit;
        return fetch(e.request).then((res) => {
          if (res && res.ok) {
            const copy = res.clone();
            caches.open(CORE).then((c) => c.put(e.request, copy).then(() => trimCore()));
          }
          return res;
        });
      }).catch(async () => {
        const fallback = await newestCoreEntry();
        if (fallback) {
          const res = await caches.match(fallback, { cacheName: CORE });
          if (res) return res;
        }
        return offlineResponse();
      }),
    );
    return;
  }
  // Default: network-first, fall back to cache when offline.
  e.respondWith(
    fetch(e.request)
      .then((res) => {
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(SHELL).then((c) => {
            c.put(e.request, copy).then(() => trimRuntime(SHELL, 240));
          });
        }
        return res;
      })
      .catch(async () => {
        const cached = await caches.match(e.request);
        if (cached) return cached;
        if (e.request.mode === "navigate") return fallbackNavigate();
        return offlineResponse();
      }),
  );
});
// --- Push (merged here so one worker owns the scope) ---
// Guarded: importScripts throws when gstatic is unreachable (offline first
// install) — caching above must still work, so push is best-effort.
try {
  importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js");
  importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js");
  firebase.initializeApp({
    apiKey: "AIzaSyBMk0z4e-k_SAYzaLypYKJn3euwfx0fW5c",
    authDomain: "everglow-1c6db.firebaseapp.com",
    projectId: "everglow-1c6db",
    storageBucket: "everglow-1c6db.firebasestorage.app",
    messagingSenderId: "220334592353",
    appId: "1:220334592353:web:6b31555509529613647520",
  });
  const messaging = firebase.messaging();
  // Show a native notification when a push arrives while the
  // browser tab is closed or in the background.
  messaging.onBackgroundMessage(function(payload) {
    const title = payload.notification?.title || "Everglow";
    const body = payload.notification?.body || "";
    const data = payload.data || {};
    self.registration.showNotification(title, {
      body,
      icon: "/icons/Icon-192.png",
      badge: "/icons/Icon-192.png",
      data,
      tag: data.type || "everglow",
    });
  });
} catch (_) {
  // Push unavailable (offline at install, or blocked CDN) — caching unaffected.
}
// When the user taps the notification, focus or open the app.
self.addEventListener("notificationclick", function(event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then(function(clientList) {
      // If the app is already open, focus it.
      for (const client of clientList) {
        if ("focus" in client) return client.focus();
      }
      // Otherwise open a new window.
      return clients.openWindow("/");
    })
  );
});
