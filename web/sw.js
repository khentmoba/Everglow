// BUILD=6.0.0+1-d43be55
// Everglow service worker: app-shell + asset caching + push.
//
// Pairing with firebase.json (last matching header rule wins there):
// - Entry points (/, /index.html, flutter_bootstrap.js, version.json, sw.js)
//   are served `no-cache` over HTTP, and network-only here. The shell can
//   never go stale: a deploy is live on the next navigation.
// - main.dart.js + CanvasKit/WASM/fonts/models are cache-first in a
//   BUILD-stamped cache. Filenames are STABLE across Flutter builds (nothing
//   here is content-hashed), so freshness comes from the stamp: `activate`
//   deletes every older cache, atomically swapping shell versions.
// - Repeat visits serve heavy bytes from CacheStorage with zero network;
//   HTTP `must-revalidate` (304s) is only the fallback when no worker
//   controls the page yet (very first visit).
//
// Push: this worker ALSO handles FCM background messages so a single
// registration owns the "/" scope. A second worker on the same scope
// (firebase-messaging-sw.js) would replace this one and kill offline
// caching, or vice versa — so that file is just a thin importScripts
// wrapper around this one, and both behave identically.
const CACHE="6.0.0+1-d43be55-CACHE-v1";
const CORE=["main.dart.js"];
// Never cached: entry points, loaders, worker scripts, version probes.
const NO_STORE=["/","/index.html","/version.json","/sw.js","/firebase-messaging-sw.js","/flutter.js","/flutter_bootstrap.js","/flutter_service_worker.js","/manifest.json"];
function isNoStore(path) {
  for (const n of NO_STORE) if (path === n) return true;
  return false;
}
function isCore(path) {
  for (const a of CORE) if (path.endsWith(a)) return true;
  return false;
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
    for (let i = 0; i < excess; i++) {
      await c.delete(keys[i]);
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
  // Only handle same-origin; CDN media (unpkg/jsdelivr/googleapis/gstatic)
  // keeps its own HTTP-cache behavior and must not pollute the versioned cache.
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
