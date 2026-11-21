import {
  cpSync,
  createReadStream,
  existsSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { execSync } from 'node:child_process';
import { extname, join, resolve, sep } from 'node:path';
import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';

// Self-contained web games that live in the `web/` folder and are
// shown in an iframe, plus PWA metadata/icons and service worker.
const WEB_FOLDERS = ['table_tennis'];
const PWA_FILES = [
  'manifest.json',
  'manifest_screen.json',
  'favicon.png',
  'firebase-messaging-sw.js',
  'embed.html',
  'embed.js',
  'hls_bridge.js',
];
const webRoot = resolve(__dirname, '../web');
const pkgPath = resolve(__dirname, 'package.json');

const TYPES: Record<string, string> = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.mp3': 'audio/mpeg',
  '.ogg': 'audio/ogg',
  '.wav': 'audio/wav',
};

function readAppBuildStamp(): string {
  let version = '0.0.0';
  if (existsSync(pkgPath)) {
    const parsed = JSON.parse(readFileSync(pkgPath, 'utf8')) as { version?: string };
    if (parsed.version) version = parsed.version.trim();
  }
  let sha = 'local';
  try {
    sha = execSync('git rev-parse --short HEAD', { stdio: ['ignore', 'pipe', 'ignore'] })
      .toString('utf8')
      .trim();
  } catch {
    // ignore if git unavailable
  }
  return `${version}-${sha}`;
}

function buildServiceWorkerSource(buildStamp: string, precacheUrls: string[]): string {
  const precacheList = JSON.stringify(['/index.html', '/manifest.json', ...precacheUrls]);
  return `// BUILD=${buildStamp}
const SHELL = "${buildStamp}-SHELL-v1";
const OFFLINE_PHOTOS = "everglow-offline-photos-v1";
const OFFLINE_MEDIA = "everglow-offline-media-v1";
const OFFLINE_MANGA = "everglow-offline-manga-v1";
const PRESERVED = new Set([SHELL, OFFLINE_PHOTOS, OFFLINE_MEDIA, OFFLINE_MANGA]);
const PRECACHE = ${precacheList};
const NO_STORE = new Set(["/", "/index.html", "/version.json", "/sw.js", "/firebase-messaging-sw.js", "/manifest.json", "/manifest_screen.json"]);

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(SHELL).then(async (cache) => {
      await Promise.allSettled(PRECACHE.map((url) => cache.add(url)));
      if (await cache.match("/index.html")) {
        await self.skipWaiting();
      }
    }).catch(() => {})
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.map((key) => (PRESERVED.has(key) ? undefined : caches.delete(key)))
      )
    ).then(() => self.clients.claim()).catch(() => {})
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.pathname.endsWith("/proxyGalleryImage")) {
    event.respondWith(
      caches.open(OFFLINE_PHOTOS).then(async (cache) => {
        const hit = await cache.match(req);
        if (hit) return hit;
        return fetch(req);
      })
    );
    return;
  }
  if (url.origin !== self.location.origin) return;
  const path = url.pathname;
  if (path.startsWith("/api/") || path === "/version.json" || path === "/sw.js" || path === "/firebase-messaging-sw.js") {
    return;
  }

  if (path.startsWith("/assets/") || path.startsWith("/icons/") || /\\.(wasm|ttf|otf|woff2?|mp3|webp|png|jpg)$/.test(path)) {
    event.respondWith(
      caches.open(SHELL).then(async (cache) => {
        const hit = await cache.match(req);
        if (hit) return hit;
        try {
          const res = await fetch(req);
          if (res && res.ok) await cache.put(req, res.clone());
          return res;
        } catch {
          return hit || Response.error();
        }
      })
    );
    return;
  }

  if (req.mode === "navigate" || !NO_STORE.has(path)) {
    event.respondWith(
      fetch(req).catch(async () => {
        const cached = await caches.match(req);
        if (cached) return cached;
        if (req.mode === "navigate") {
          const fallback = await caches.match("/index.html", { cacheName: SHELL });
          if (fallback) return fallback;
        }
        return Response.error();
      })
    );
  }
});

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
  messaging.onBackgroundMessage(function(payload) {
    const title = (payload.notification && payload.notification.title) || "Everglow";
    const body = (payload.notification && payload.notification.body) || "";
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
  // Push unavailable when offline or CDN unreachable.
}

self.addEventListener("notificationclick", function(event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then(function(clientList) {
      for (const client of clientList) {
        if ("focus" in client) return client.focus();
      }
      return clients.openWindow("/");
    })
  );
});
`;
}

function webShellPlugin(): Plugin {
  return {
    name: 'everglow-web-shell',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        let path: string;
        try {
          path = decodeURIComponent((req.url ?? '').split('?')[0]);
        } catch {
          res.statusCode = 400;
          res.end('Bad Request');
          return;
        }
        if (/(^|\/)env\.txt$/i.test(path) || /(^|\/)\.env(\.|$)/i.test(path)) {
          res.statusCode = 404;
          res.end('Not Found');
          return;
        }
        const allowed =
          WEB_FOLDERS.some((f) => path.startsWith(`/${f}/`)) ||
          path.startsWith('/icons/') ||
          PWA_FILES.some((f) => path === `/${f}`);
        if (!allowed) return next();
        const file = resolve(webRoot, `.${path}`);
        if (!file.startsWith(webRoot + sep) || !existsSync(file) || !statSync(file).isFile()) return next();
        res.setHeader('Content-Type', TYPES[extname(file)] ?? 'application/octet-stream');
        createReadStream(file).pipe(res);
      });
    },
    closeBundle() {
      const distRoot = resolve(__dirname, 'dist');
      for (const entry of existsSync(distRoot) ? readdirSync(distRoot) : []) {
        if (/^env\.txt$/i.test(entry) || /^\.env(\.|$)/i.test(entry)) {
          rmSync(join(distRoot, entry), { force: true });
        }
      }
      for (const f of WEB_FOLDERS) {
        const src = join(webRoot, f);
        if (existsSync(src)) cpSync(src, join(distRoot, f), { recursive: true });
      }
      if (existsSync(join(webRoot, 'icons'))) {
        cpSync(join(webRoot, 'icons'), join(distRoot, 'icons'), { recursive: true });
      }
      for (const f of PWA_FILES) {
        const src = join(webRoot, f);
        if (existsSync(src)) cpSync(src, join(distRoot, f));
      }

      const assetsDir = join(distRoot, 'assets');
      const assetFiles = existsSync(assetsDir) ? readdirSync(assetsDir) : [];
      const mainEntry = assetFiles.find((n) => /^index-.*\.js$/.test(n));
      const mainCss = assetFiles.find((n) => /^index-.*\.css$/.test(n));
      const parts = assetFiles.filter((n) => n.endsWith('.js') && n !== mainEntry).sort();
      const build = readAppBuildStamp();
      const core = mainEntry ? `/assets/${mainEntry}` : '/index.html';

      writeFileSync(
        join(distRoot, 'version.json'),
        `${JSON.stringify({ build, core, parts })}\n`,
        'utf8',
      );
      const indexHtml = existsSync(join(distRoot, 'index.html'))
        ? readFileSync(join(distRoot, 'index.html'), 'utf8')
        : '';
      const htmlAssets = [
        ...indexHtml.matchAll(/(?:src|href)="(\/assets\/[^"]+\.(?:js|css))"/g),
      ].map((m) => m[1]);
      // Precache the entry shell + Dashboard chunk (and its direct imports) so
      // offline reload of /dashboard works immediately after SW activation.
      const precacheSet = new Set<string>([
        ...(mainEntry ? [`/assets/${mainEntry}`] : []),
        ...(mainCss ? [`/assets/${mainCss}`] : []),
        ...htmlAssets,
      ]);
      const dashChunks = assetFiles.filter((n) => /^(?:DashboardPage|DashboardLowerZones)-.*\.js$/.test(n));
      if (dashChunks.length > 0) {
        const queue = [...dashChunks];
        const visited = new Set<string>();
        while (queue.length > 0) {
          const name = queue.shift()!;
          if (visited.has(name) || name === mainEntry) continue;
          visited.add(name);
          precacheSet.add(`/assets/${name}`);
          const src = readFileSync(join(assetsDir, name), 'utf8');
          for (const m of src.matchAll(/(?:from|import)\s*\(?\s*["']\.\/([^"']+\.js)["']/g)) {
            if (existsSync(join(assetsDir, m[1]))) queue.push(m[1]);
          }
        }
      }
      writeFileSync(join(distRoot, 'sw.js'), buildServiceWorkerSource(build, [...precacheSet]), 'utf8');
    },
  };
}

// The Flutter app and this one share one `assets/` folder, so fonts and
// images live in a single place until the move is finished.
export default defineConfig({
  plugins: [react(), webShellPlugin()],
  publicDir: '../assets',
  build: {
    rollupOptions: {
      output: {
        experimentalMinChunkSize: 12_000,
        manualChunks(id) {
          if (id.includes('node_modules/react-dom') || id.includes('node_modules/react/') || id.includes('node_modules/scheduler') || id.includes('node_modules/react-router')) {
            return 'react-vendor';
          }
          if (id.includes('node_modules/firebase/messaging') || id.includes('node_modules/@firebase/messaging')) {
            return 'firebase-messaging';
          }
          if (id.includes('node_modules/firebase/storage') || id.includes('node_modules/@firebase/storage')) {
            return 'firebase-storage';
          }
          if (id.includes('node_modules/firebase/') || id.includes('node_modules/@firebase/')) {
            return 'firebase-core';
          }
          return undefined;
        },
      },
    },
  },
  server: { open: false },
  preview: { open: false },
});
