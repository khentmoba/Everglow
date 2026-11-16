// Pieces shared by compare.mjs and motion.mjs.
import { createReadStream, existsSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { homedir } from 'node:os';
import { extname, join, resolve } from 'node:path';
import pixelmatch from 'pixelmatch';
import { chromium } from 'playwright-core';
import { PNG } from 'pngjs';

export const args = process.argv.slice(2);
export const flag = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : fallback;
};

// Clair uses a phone and a tablet. Flutter picks button sizes, spacing and
// scrolling from the browser's user agent, so the devices must say Android,
// not desktop Chrome.
const ANDROID_PHONE_UA =
  'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';
const ANDROID_TABLET_UA =
  'Mozilla/5.0 (Linux; Android 14; Pixel Tablet) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

export const SIZES = {
  phone: { width: 390, height: 844, deviceScaleFactor: 2, isMobile: true, hasTouch: true, userAgent: ANDROID_PHONE_UA },
  tablet: { width: 820, height: 1180, deviceScaleFactor: 2, isMobile: true, hasTouch: true, userAgent: ANDROID_TABLET_UA },
};

const TYPES = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.webp': 'image/webp', '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2',
  '.woff': 'font/woff', '.mp3': 'audio/mpeg', '.glb': 'model/gltf-binary',
};

function serve(root, extraRoots = []) {
  return new Promise((done) => {
    const server = createServer((req, res) => {
      const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
      let file = [root, ...extraRoots].map((r) => join(r, path)).find((f) => existsSync(f) && statSync(f).isFile());
      if (!file) file = join(root, 'index.html');
      res.writeHead(200, { 'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream', 'Cache-Control': 'no-store' });
      createReadStream(file).pipe(res);
    });
    server.listen(0, '127.0.0.1', () => done(server));
  });
}

function findChrome() {
  const base = join(homedir(), 'AppData', 'Local', 'ms-playwright');
  const dirs = existsSync(base) ? readdirSync(base).filter((d) => d.startsWith('chromium_headless_shell-')).sort().reverse() : [];
  for (const d of dirs) {
    for (const sub of readdirSync(join(base, d))) {
      const exe = join(base, d, sub, 'chrome-headless-shell.exe');
      if (existsSync(exe)) return exe;
    }
  }
  return undefined;
}

/** Serves both builds, launches headless muted Chrome, runs fn, cleans up. */
export async function withApps(fn) {
  const flutterRoot = resolve('..', 'build', 'web');
  const reactRoot = resolve('dist');
  for (const [name, root] of [['Flutter', flutterRoot], ['React', reactRoot]]) {
    if (!existsSync(join(root, 'index.html'))) {
      console.error(`${name} build missing at ${root}`);
      process.exit(1);
    }
  }
  const flutterServer = await serve(flutterRoot);
  const reactServer = await serve(reactRoot, [resolve('..', 'assets')]);
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    await fn(browser, {
      flutter: `http://127.0.0.1:${flutterServer.address().port}`,
      react: `http://127.0.0.1:${reactServer.address().port}`,
    });
  } finally {
    await browser.close();
    flutterServer.close();
    reactServer.close();
  }
}

/** New page at a device size. Flutter's own service worker cache is skipped. */
const apiCache = new Map();
function normalize(body) {
  if (!body) return '';
  const sortKeys = (v) =>
    Array.isArray(v) ? v.map(sortKeys) : v && typeof v === 'object'
      ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, sortKeys(v[k])]))
      : v;
  try {
    return JSON.stringify(sortKeys(JSON.parse(body)));
  } catch {
    return body;
  }
}

export async function openPage(browser, url, size, { motion = false } = {}) {
  const { width, height, ...rest } = size;
  const context = await browser.newContext({
    viewport: { width, height },
    ...rest,
    reducedMotion: motion ? 'no-preference' : 'reduce',
  });
  const page = await context.newPage();
  await page.route('**/flutter_service_worker.js', (r) => r.abort());
  // Catalog APIs rate-limit and drift between the two loads, so the first
  // answer to each query is replayed to the other app.
  await page.route(/graphql\.anilist\.co|api\.jikan\.moe|proxyCatalog/, async (r) => {
    const req = r.request();
    // Dart and the browser escape query strings slightly differently.
    const plain = (u) => { try { return decodeURIComponent(u.replace(/\+/g, ' ')); } catch { return u; } };
    const key = req.method() + ' ' + plain(plain(req.url())) + ' ' + normalize(req.postData());
    const hit = apiCache.get(key);
    if (hit) return r.fulfill(hit);
    try {
      const resp = await r.fetch();
      const body = await resp.body();
      const reply = { status: resp.status(), headers: resp.headers(), body };
      if (resp.ok()) apiCache.set(key, reply);
      return r.fulfill(reply);
    } catch {
      return r.abort();
    }
  });
  // Live trailers differ frame to frame; both apps get the same black embed.
  await page.route(/youtube(-nocookie)?\.com\/embed\//, (r) =>
    r.fulfill({ contentType: 'text/html', body: '<html><body style="margin:0;background:#000"></body></html>' }),
  );
  await page.goto(url, { waitUntil: 'load' });
  return { page, context };
}

export function diff(a, b, out) {
  const imgA = PNG.sync.read(readFileSync(a));
  const imgB = PNG.sync.read(readFileSync(b));
  const { width, height } = imgA;
  const result = new PNG({ width, height });
  const changed = pixelmatch(imgA.data, imgB.data, result.data, width, height, { threshold: 0.1, includeAA: false });
  writeFileSync(out, PNG.sync.write(result));
  const total = width * height;
  return { changed, total, pct: ((changed / total) * 100).toFixed(2) };
}
