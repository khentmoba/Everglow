// Verifies built web shell artifacts, SW offline fallback, update prompt banner,
// and push notification routing parity.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createReadStream, existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { homedir } from 'node:os';
import { extname, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright-core';

const DIST = fileURLToPath(new URL('../dist/', import.meta.url));
const TYPES = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.ttf': 'font/ttf',
};

function findChrome() {
  for (const candidate of [
    process.env.CHROME_PATH,
    'C:/Program Files/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
    '/usr/bin/google-chrome',
    '/opt/google/chrome/chrome',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
  ].filter(Boolean)) {
    if (existsSync(candidate)) return candidate;
  }
  const base = join(homedir(), 'AppData', 'Local', 'ms-playwright');
  const dirs = existsSync(base)
    ? readdirSync(base).filter((d) => d.startsWith('chromium_headless_shell-')).sort().reverse()
    : [];
  for (const d of dirs) {
    for (const sub of readdirSync(join(base, d))) {
      const exe = join(base, d, sub, 'chrome-headless-shell.exe');
      if (existsSync(exe)) return exe;
    }
  }
  return undefined;
}

test('dist shell outputs include version.json, sw.js, manifests, and FCM sw', () => {
  for (const name of ['index.html', 'version.json', 'sw.js', 'manifest.json', 'manifest_screen.json', 'firebase-messaging-sw.js', 'favicon.png']) {
    assert.ok(existsSync(join(DIST, name)), `missing ${name} in react/dist`);
  }
  const ver = JSON.parse(readFileSync(join(DIST, 'version.json'), 'utf8'));
  const sha = execFileSync('git', ['rev-parse', '--short', 'HEAD'], { encoding: 'utf8' }).trim();
  assert.ok(ver.build.includes(sha), `version.json build "${ver.build}" should contain git sha "${sha}"`);
  assert.ok(typeof ver.core === 'string' && ver.core.startsWith('/assets/index-'), 'version.json core points to main entry chunk');

  const sw = readFileSync(join(DIST, 'sw.js'), 'utf8');
  for (const cache of ['everglow-offline-photos-v1', 'everglow-offline-media-v1', 'everglow-offline-manga-v1']) {
    assert.ok(sw.includes(cache), `sw.js must preserve ${cache}`);
  }
  assert.ok(sw.includes('onBackgroundMessage') && sw.includes('notificationclick'), 'sw.js handles background push notifications');
});

test('browser registers service worker, shows update prompt on new version.json, and boots offline', async () => {
  const initialVersion = readFileSync(join(DIST, 'version.json'), 'utf8');
  const parsed = JSON.parse(initialVersion);
  let servedVersion = initialVersion;

  const server = await new Promise((done) => {
    const s = createServer((req, res) => {
      const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
      if (path === '/version.json') {
        res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
        res.end(servedVersion);
        return;
      }
      let file = join(DIST, path);
      if (!existsSync(file) || !statSync(file).isFile()) file = join(DIST, 'index.html');
      res.writeHead(200, { 'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream', 'Cache-Control': 'no-store' });
      createReadStream(file).pipe(res);
    });
    s.listen(0, '127.0.0.1', () => done(s));
  });

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({ headless: true, executablePath: findChrome() });
  try {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));

    await page.goto(`${baseUrl}/dashboard?agent=1`, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(() => Boolean(navigator.serviceWorker?.controller), null, { timeout: 10_000 });

    // Serve a new version and fire an `online` re-check event to trigger AppUpdatePrompt.
    servedVersion = JSON.stringify({ ...parsed, build: `${parsed.build}-next`, core: parsed.core });
    await page.evaluate(() => window.dispatchEvent(new Event('online')));
    await page.waitForSelector('text=A fresh Everglow update is ready', { timeout: 10_000 });
    const restartVisible = await page.isVisible('text=Restart');
    assert.ok(restartVisible, 'AppUpdatePrompt Restart button should be visible');

    // Switch context offline and verify cached SPA reload succeeds with SW controller intact.
    await context.setOffline(true);
    await page.goto(`${baseUrl}/dashboard?agent=1`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=Together', { timeout: 10_000 });
    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});

test('notification routing covers all Flutter notification types', () => {
  const src = readFileSync(new URL('../src/core/services/notifications.ts', import.meta.url), 'utf8');
  const expected = {
    chat_message: '/sanctuary',
    mood_update: '/dashboard',
    milestone: '/dashboard',
    special_day: '/dashboard',
    special_day_upcoming: '/dashboard',
    mood_checkin: '/dashboard',
    watch_party_invite: '/watch-party',
    starlight_drop: '/starlight',
    watchlist_update: '/cinema',
    motchi_note: '/motchi',
    daily_digest: '/motchi-today',
    night_recap: '/motchi-today',
    gallery_photo: '/gallery',
  };
  for (const [type, route] of Object.entries(expected)) {
    assert.ok(src.includes(`case '${type}'`), `missing notification type ${type}`);
    assert.ok(src.includes(`return '${route}'`), `missing notification route ${route}`);
  }
  const swSrc = readFileSync(new URL('../dist/sw.js', import.meta.url), 'utf8');
  assert.ok(swSrc.includes('watch_party_invite: "/watch-party"'), 'sw.js should route watch_party_invite to /watch-party');
  assert.ok(swSrc.includes('?room='), 'sw.js should deep-link watch_party_invite roomId when present');
});
