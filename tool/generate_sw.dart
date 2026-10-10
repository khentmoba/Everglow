// ignore_for_file: avoid_print
// Build tool: stamps web/sw.js with the current version+commit, writes
// web/version.json for the in-app update check, and prints the stamp.
import "dart:io";

import "build_stamp.dart";

void main() {
  final buildConst = buildStamp();
  // The version-busted core shell URL. build_web.dart stamps the exact same
  // string into flutter_bootstrap.js after `flutter build web`, so the loader
  // requests this URL and the worker below can tell builds apart by URL
  // alone.
  final coreUrl = "main.dart.js?v=$buildConst";

  final sw =
      """
// BUILD=$buildConst
// Everglow service worker: app-shell + asset caching + push.
//
// Pairing with firebase.json (last matching header rule wins there):
// - Entry points (/, /index.html, flutter_bootstrap.js, version.json, sw.js)
//   are served `no-cache` over HTTP, and network-first/no-store here. A
//   deploy is live on the next online navigation; boot loaders are saved
//   only for a network-error fallback paired with their versioned core.
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
const SHELL="$buildConst-SHELL-v1";
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
// Always network/no-store online: entry points, loaders, worker scripts,
// version probes and Cloud Functions. Only HTML and boot loaders have an
// offline cache fallback; /api/*, manifests and worker scripts never do.
const BOOT_LOADERS=["/flutter_bootstrap.js","/flutter.js"];
const NO_STORE=["/","/index.html","/version.json","/sw.js","/firebase-messaging-sw.js","/flutter.js","/flutter_bootstrap.js","/flutter_service_worker.js","/manifest.json","/manifest_screen.json","/screen_test.html"];
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
function isScriptResponse(res) {
  // A hosting SPA rewrite can return index.html with status 200 for a
  // missing JS file. Never save or execute it as a boot loader.
  return res && res.ok && /^(text|application)\\/(x-)?(java|ecma)script\\b/i.test(res.headers.get("Content-Type") || "");
}
function shellForUrl(url) {
  // Deferred chunks encode '+' in the stamp; main.dart.js does not.
  const version = /[?&]v=([^&]+)/.exec(url.search);
  return version ? decodeURIComponent(version[1]) + "-SHELL-v1" : SHELL;
}
let currentBootstrapBuild = null;

async function newestCompleteStamp() {
  try {
    const core = await caches.open(CORE);
    const names = await caches.keys();
    for (const name of names.reverse()) {
      if (!name.endsWith("-SHELL-v1")) continue;
      const stamp = name.slice(0, -"-SHELL-v1".length);
      let main;
      try {
        main = await core.match(new URL("main.dart.js?v=" + stamp, self.location.origin).href);
      } catch {}
      if (!isScriptResponse(main)) continue;
      try {
        const cache = await caches.open(name);
        if (await cache.match("/flutter_bootstrap.js")) return stamp;
      } catch {}
    }
  } catch {}
  return null;
}

async function cachedBootLoader(path) {
  const stamp = await newestCompleteStamp();
  if (stamp) {
    currentBootstrapBuild = stamp;
    try {
      const cache = await caches.open(stamp + "-SHELL-v1");
      const loader = await cache.match(path);
      if (isScriptResponse(loader)) return loader;
    } catch {}
  }
  return Response.error();
}

async function iconCacheName() {
  if (currentBootstrapBuild) return currentBootstrapBuild + "-SHELL-v1";
  const stamp = await newestCompleteStamp();
  if (stamp) return stamp + "-SHELL-v1";
  return SHELL;
}
// Flutter tree-shakes MaterialIcons on every app build. Its stable URL is
// NOT engine-immutable: an old subset leaves newly added icons blank.
function isIconAsset(path) {
  return path === "/assets/fonts/MaterialIcons-Regular.otf" || path === "/assets/FontManifest.json";
}
function isImmutable(url) {
  let p;
  try {
    p = new URL(url).pathname;
  } catch {
    return false;
  }
  if (isNoStore(p) || isIconAsset(p)) return false;
  if (p.endsWith(".part.js")) return false;
  if (p.startsWith("/canvaskit/")) return true;
  if (p.startsWith("/assets/") || p.startsWith("/icons/")) return true;
  return /\\.(wasm|ttf|otf|woff2|glb|gltf|bin|data|mp3)\$/.test(p);
}
async function trimRuntime(cacheName, maxEntries) {
  try {
    const c = await caches.open(cacheName);
    const keys = await c.keys();
    const excess = keys.length - maxEntries;
    for (let i = 0; i < excess; i++) await c.delete(keys[i]);
  } catch {}
}
async function trimCore() {
  try {
    const c = await caches.open(CORE);
    const keys = await c.keys();
    const shells = keys.filter((k) => new URL(k.url).pathname.endsWith("main.dart.js"));
    // Keep current + previous: an offline deploy-day still boots.
    while (shells.length > 2) {
      const old = shells.shift();
      await c.delete(old);
      await caches.delete(shellForUrl(new URL(old.url)));
    }
  } catch {}
}
async function newestCoreEntry() {
  try {
    const c = await caches.open(CORE);
    const keys = await c.keys();
    for (let i = keys.length - 1; i >= 0; i--) {
      if (new URL(keys[i].url).pathname.endsWith("main.dart.js")) return keys[i];
    }
  } catch {}
  return null;
}
// Pre-warm the core shell for THIS build so the next cold open paints
// straight from CacheStorage instead of re-downloading ~6MB.
//
// Deliberately not part of `install`: the install handler must not compete
// with the page it is serving. This runs off `activate`, only when the shell
// for the current build stamp is genuinely absent, and it bails out on a
// save-data or 2g connection (see SAVE_DATA) so it never spends a metered
// user's data. Any failure is swallowed: a warm that misses only costs the
// next visit one normal fetch.
const SAVE_DATA = (navigator.connection &&
  (navigator.connection.saveData ||
   /(^|-)2g\$/.test(navigator.connection.effectiveType || "")));
async function warmCoreShell() {
  if (SAVE_DATA) return;
  try {
    const c = await caches.open(CORE);
    const shellUrl = new URL("main.dart.js?v=$buildConst", self.location.origin).href;
    const already = await c.match(shellUrl);
    if (already) return;
    if (navigator.onLine === false) return;
    const res = await fetch(shellUrl, { cache: "no-store" });
    if (!isScriptResponse(res)) return;
    await c.put(shellUrl, res.clone());
    await trimCore();
  } catch {}
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
        // Keep previous versioned loaders/chunks until their core rotates
        // out. Activation can precede the new build's first complete boot.
        ks.filter((k) => !k.endsWith("-SHELL-v1") && k !== IMMUTABLE && k !== CORE).map((k) => caches.delete(k)),
      ))
      .then(async () => {
        try {
          const imm = await caches.open(IMMUTABLE);
          const keys = await imm.keys();
          for (const req of keys) {
            const u = req.url.split("?")[0];
            if (isIconAsset(new URL(u).pathname) || u.endsWith(".part.js") || (u.endsWith(".js") && u.indexOf("/canvaskit/") === -1)) {
              await imm.delete(req);
            }
          }
        } catch {}
      })
      .then(() => self.clients.claim())
      .then(() => warmCoreShell()),
  );
});
self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET") return;
  let url;
  try {
    url = new URL(e.request.url);
  } catch {
    return;
  }
  // Only handle same-origin; CDN media (jsdelivr/googleapis/gstatic)
  // keeps its own HTTP-cache behavior and must not pollute the versioned cache.
  if (url.origin !== self.location.origin) return;
  const path = url.pathname;
  // Offline means a true network error (Response.error()), never a fake
  // HTTP status: a synthesized error status made Chrome log
  // "Failed to load resource" for ordinary offline/aborted fetches.
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
    } catch {}
    return Response.error();
  };
  if (isNoStore(path)) {
    e.respondWith(
      fetch(e.request, { cache: "no-store" })
        .then(async (res) => {
          if (BOOT_LOADERS.includes(path)) {
            if (!isScriptResponse(res)) throw new Error("Invalid boot loader");
            // The active worker may still be the previous deploy. Use the
            // loader's stamped main URL, NOT this worker's BUILD, for pairing.
            try {
              const body = await res.clone().text();
              const build = /"main\\.dart\\.js\\?v=([^"/]+)"/.exec(body);
              if (build) {
                currentBootstrapBuild = build[1];
                const cache = await caches.open(build[1] + "-SHELL-v1");
                await cache.put(path, res.clone());
                // Keep a navigation fallback when the old worker's SHELL
                // rotates out after serving several newer deploys.
                const index = await caches.match("/index.html", { cacheName: SHELL });
                if (index) await cache.put("/index.html", index);
              }
            } catch {} // Cache quota/failure must not hide a fresh deploy.
          }
          if (res && res.ok && (path === "/" || path === "/index.html")) {
            try {
              const cache = await caches.open(SHELL);
              await cache.put("/index.html", res.clone());
              await cache.put("/", res.clone());
            } catch {}
          }
          return res;
        })
        .catch(async () => {
          if (BOOT_LOADERS.includes(path)) return cachedBootLoader(path);
          if (path === "/" || path === "/index.html") return fallbackNavigate();
          if (path === "/version.json") {
            return new Response(JSON.stringify({ offline: true }), {
              status: 200,
              headers: { "Content-Type": "application/json" },
            });
          }
          return Response.error();
        }),
    );
    return;
  }
  // Immutable bytes (CanvasKit/static fonts/models) live in the
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
        return cached || Response.error();
      }),
    );
    return;
  }
  if (isCore(path)) {
    // Exact-URL match (query included): a new `?v=` always misses and
    // fetches genuinely fresh bytes, whatever worker is active. A stamped
    // bootstrap must never receive another build's main/deferred code.
    e.respondWith(
      (async () => {
        let hit = null;
        try {
          hit = await caches.match(e.request, { cacheName: CORE });
        } catch {}
        if (hit) return hit;

        try {
          const res = await fetch(e.request);
          if (!isScriptResponse(res)) throw new Error("Invalid core script");
          if (res && res.ok) {
            const copy = res.clone();
            e.waitUntil(caches.open(CORE).then((c) => c.put(e.request, copy).then(() => trimCore())).catch(() => {}));
          }
          return res;
        } catch {
          if (url.searchParams.has("v")) return Response.error();
          let fallback;
          try {
            fallback = await newestCoreEntry();
          } catch {}
          if (fallback) {
            try {
              const res = await caches.match(fallback, { cacheName: CORE });
              if (res) return res;
            } catch {}
          }
          return Response.error();
        }
      })(),
    );
    return;
  }
  // Default: network-first, fall back to cache when offline. Icon assets
  // also revalidate HTTP: previously they had a one-year immutable header.
  const isPart = path.endsWith(".part.js");
  const isIcon = isIconAsset(path);
  e.respondWith(
    (async () => {
      let runtimeCache = SHELL;
      if (isPart) {
        runtimeCache = shellForUrl(url);
      } else if (isIcon) {
        runtimeCache = await iconCacheName();
      }

      let hit = null;
      if (isPart && url.searchParams.has("v")) {
        try {
          hit = await caches.match(e.request, { cacheName: runtimeCache });
        } catch {}
      }
      if (hit) return hit;

      try {
        const res = await fetch(e.request, isIcon ? { cache: "no-cache" } : {});
        if (isPart && !isScriptResponse(res)) throw new Error("Invalid deferred script");
        if (res && res.ok) {
          const copy = res.clone();
          const write = caches.open(runtimeCache).then((c) =>
            c.put(e.request, copy).then(() => trimRuntime(runtimeCache, 240))).catch(() => {});
          if (isPart) e.waitUntil(write);
        }
        return res;
      } catch {
        let cached;
        try {
          cached = await caches.match(e.request, (isIcon || isPart) ? { cacheName: runtimeCache } : {});
        } catch {}
        return cached || (e.request.mode === "navigate" ? fallbackNavigate() : Response.error());
      }
    })(),
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
} catch {
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
""";

  File("web/sw.js").writeAsStringSync(sw);
  File(
    "web/version.json",
  ).writeAsStringSync('{"build": "$buildConst", "core": "$coreUrl"}\n');
  print("sw.js written with BUILD = $buildConst");
}
