// Verifies React player host bridges (animex-player-state, animex-pref,
// everglow-key, exit-theater, EpisodeNavigator) and OfflineVideoHud controls.
import assert from 'node:assert/strict';
import { createReadStream, existsSync, readdirSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { homedir } from 'node:os';
import { extname, join, resolve } from 'node:path';
import test from 'node:test';
import { chromium } from 'playwright-core';
import { isEditableTarget, resolveEverglowPlayerKey } from '../src/shared/widgets/everglowPlayerKeys.ts';

const DIST = resolve('dist');
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

async function startDistServer() {
  const server = await new Promise((done) => {
    const s = createServer((req, res) => {
      const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
      let file = join(DIST, path);
      if (!existsSync(file) || !statSync(file).isFile()) file = join(DIST, 'index.html');
      res.writeHead(200, { 'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream', 'Cache-Control': 'no-store' });
      createReadStream(file).pipe(res);
    });
    s.listen(0, '127.0.0.1', () => done(s));
  });
  return { server, baseUrl: `http://127.0.0.1:${server.address().port}` };
}

test('resolveEverglowPlayerKey maps media keys, accepts expanded shortcuts, and filters non-player keys', () => {
  assert.equal(resolveEverglowPlayerKey('MediaPlayPause'), ' ');
  assert.equal(resolveEverglowPlayerKey('MediaFastForward'), 'l');
  assert.equal(resolveEverglowPlayerKey('MediaRewind'), 'j');
  assert.equal(resolveEverglowPlayerKey('MediaTrackNext'), 'n');
  for (const k of ['g', 'H', 's', 'i', 'z', '[', ']', '<', '>', '?', 'Escape', 'Home', 'End', '0', '9']) {
    assert.equal(resolveEverglowPlayerKey(k), k);
  }
  for (const bad of ['', 'a', 'Control', 'Shift', 'Tab']) {
    assert.equal(resolveEverglowPlayerKey(bad), null);
  }
  assert.equal(isEditableTarget(null), false);
});

test('Cinema player page renders accessible EpisodeNavigator, Provider sheet, and relays player bridge messages', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));

    // Stub external worker embed URL and Cinema wrapper URL so iframes load deterministically offline.
    await page.route('https://everglow-1c6db.web.app/**', async (route) => {
      await route.fulfill({ status: 200, contentType: 'text/html', body: '<!doctype html><html><body></body></html>' });
    });
    await page.route('https://everglow-stream.khentplaysmoba.workers.dev/**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'text/html',
        body: `<!doctype html><html><body><script>
          window.__rx = [];
          window.addEventListener('message', (e) => window.__rx.push(e.data));
          window.parent.postMessage({ type: 'animex-progress', positionSeconds: 12, durationSeconds: 1200 }, '*');
        </script></body></html>`,
      });
    });

    await page.goto(`${baseUrl}/cinema/video/1399?type=tv&season=1&episode=1&title=Game%20of%20Thrones&agent=1`, {
      waitUntil: 'domcontentloaded',
    });

    await page.waitForSelector('text=Provider:', { timeout: 10_000 });
    const epBtn = page.locator('button[aria-expanded]').first();
    await epBtn.waitFor({ state: 'visible', timeout: 10_000 });
    assert.equal(await epBtn.getAttribute('aria-expanded'), 'false');
    await epBtn.click();
    assert.equal(await epBtn.getAttribute('aria-expanded'), 'true');

    // Open Switch Provider sheet, verify native default-source buttons, and pick Everglow (everglow-embed).
    await page.getByText('Provider:').click();
    await page.waitForSelector('text=Switch Provider', { timeout: 5_000 });
    const defaultBtns = page.locator('button[aria-label="Set as default source"]');
    assert.ok((await defaultBtns.count()) >= 1, 'Switch Provider sheet must render native default-source buttons');
    await page.getByText('No ads — Everglow player').click();

    // Scroll back to top so key forwarder is active, wait for Everglow iframe, then verify bridges.
    await page.waitForFunction(
      () => Boolean(document.querySelector('iframe')?.src.includes('everglow-stream.khentplaysmoba.workers.dev')),
      null,
      { timeout: 5_000 },
    );
    await page.evaluate(() => {
      const sc = [...document.querySelectorAll('div')].find((d) => d.scrollTop > 0);
      if (sc) sc.scrollTop = 0;
    });
    const frame = page.frames().find((f) => f.url().includes('everglow-stream.khentplaysmoba.workers.dev'));
    assert.ok(frame, 'everglow-embed iframe should load');
    await page.waitForFunction(() => Array.isArray(window.__rx) && window.__rx.length > 0, null, { timeout: 5_000 }).catch(() => {});
    await frame.waitForFunction(() => Array.isArray(window.__rx) && window.__rx.some((m) => m?.type === 'animex-player-state'), null, {
      timeout: 5_000,
    });
    const rxBeforeKey = await frame.evaluate(() => window.__rx);
    assert.ok(
      rxBeforeKey.some(
        (m) => m?.type === 'animex-player-state' && m.hasEpisodes === true && m.theater === false && typeof m.title === 'string',
      ),
      `expected animex-player-state with hasEpisodes/theater/title, got ${JSON.stringify(rxBeforeKey)}`,
    );

    await page.keyboard.press('g');
    await page.waitForTimeout(80);
    const rxAfterKey = await frame.evaluate(() => window.__rx);
    assert.ok(
      rxAfterKey.some((m) => m?.type === 'everglow-key' && m.key === 'g'),
      `expected expanded everglow-key "g" to be forwarded, got ${JSON.stringify(rxAfterKey)}`,
    );

    // Verify animex-pref autoNext update + theater mode exit-theater action.
    await page.locator('button').filter({ has: page.locator('span:text-is("fullscreen")') }).click();
    await page.waitForTimeout(100);
    await frame.evaluate(() => {
      window.parent.postMessage({ type: 'animex-pref', key: 'autoNext', value: false }, '*');
      window.parent.postMessage({ type: 'animex-action', action: 'exit-theater' }, '*');
    });
    await page.waitForTimeout(150);
    const rxAfterExit = await frame.evaluate(() => window.__rx);
    assert.ok(
      rxAfterExit.some((m) => m?.type === 'animex-player-state' && m.theater === true),
      'entering theater should post theater:true',
    );
    assert.ok(
      rxAfterExit.some((m) => m?.type === 'animex-player-state' && m.theater === false && m.autoNext === false),
      'exit-theater and animex-pref should sync back to iframe',
    );

    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});

test('OfflineVideoHud mounts over cached offline video and drives playback, settings, shortcuts, stats, and lock controls', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 960, height: 720 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));

    // Boot once on origin to seed a real playable WebM blob into CacheStorage + Prefs.
    await page.goto(`${baseUrl}/cinema?agent=1`, { waitUntil: 'domcontentloaded' });
    await page.evaluate(async () => {
      const canvas = document.createElement('canvas');
      canvas.width = 64;
      canvas.height = 36;
      document.body.appendChild(canvas);
      const ctx = canvas.getContext('2d');
      const stream = canvas.captureStream(0);
      const track = stream.getVideoTracks()[0];
      const rec = new MediaRecorder(stream, { mimeType: 'video/webm;codecs=vp8' });
      const chunks = [];
      rec.ondataavailable = (e) => {
        if (e.data.size > 0) chunks.push(e.data);
      };
      const done = new Promise((r) => (rec.onstop = r));
      rec.start(50);
      for (let i = 0; i < 10; i++) {
        ctx.fillStyle = i % 2 === 0 ? '#221133' : '#441166';
        ctx.fillRect(0, 0, 64, 36);
        track.requestFrame?.();
        await new Promise((r) => setTimeout(r, 50));
      }
      rec.stop();
      await done;
      const blob = new Blob(chunks, { type: 'video/webm' });

      const cache = await caches.open('everglow-offline-media-v1');
      await cache.put(
        `${window.location.origin}/offline-media/test_blob_1399`,
        new Response(blob, { status: 200, headers: { 'Content-Type': 'video/webm', 'Content-Length': String(blob.size) } }),
      );
      const item = {
        id: 'cinema_tv_1399_s1_e1',
        type: 'tv',
        mediaId: '1399',
        title: 'Game of Thrones',
        subtitle: 'S1 E1',
        season: 1,
        episode: 1,
        coverUrl: '',
        status: 'completed',
        progress: 1,
        totalBytes: blob.size,
        downloadedBytes: blob.size,
        downloadedAt: new Date().toISOString(),
        durationSeconds: 1,
        lastPositionSeconds: 0,
        pageUrls: [],
        blobKey: 'test_blob_1399',
      };
      localStorage.setItem('flutter.everglow_offline_media_items_v1', JSON.stringify(JSON.stringify([item])));
    });

    await page.goto(`${baseUrl}/cinema/video/1399?type=tv&season=1&episode=1&title=Game%20of%20Thrones&agent=1`, {
      waitUntil: 'domcontentloaded',
    });

    await page.waitForSelector('div[role="slider"][aria-label="Seek"]', { timeout: 10_000 });
    const hasNativeControls = await page.evaluate(() => Boolean(document.querySelector('video')?.controls));
    assert.equal(hasNativeControls, false, 'offline <video> should disable native browser controls when OfflineVideoHud is active');

    // Cycle playback speed chip (1x -> 1.25x) and verify time readout button works.
    const timeBtn = page.locator('button[aria-label="Toggle elapsed or remaining time"]');
    await timeBtn.click();
    const speedBtn = page.locator('button[aria-label="1x"]');
    await speedBtn.click();
    await page.locator('button[aria-label="1.25x"]').waitFor({ state: 'visible', timeout: 5_000 });

    // Open Settings -> Shortcuts (?) -> Escape closes.
    await page.locator('button[aria-label="Settings"]').click();
    await page.waitForSelector('div[role="dialog"][aria-label="Player settings"]', { timeout: 5_000 });
    await page.getByRole('button', { name: 'Shortcuts (?)' }).click();
    await page.waitForSelector('div[role="dialog"][aria-label="Keyboard shortcuts"]', { timeout: 5_000 });
    await page.keyboard.press('Escape');
    await page.waitForSelector('div[role="dialog"][aria-label="Keyboard shortcuts"]', { state: 'detached', timeout: 5_000 });

    // Toggle stream stats with keyboard 'i'.
    await page.keyboard.press('i');
    await page.waitForSelector('text=Buffer', { timeout: 5_000 });

    // Lock screen and unlock.
    await page.locator('button[aria-label="Lock screen"]').click();
    const unlockBtn = page.locator('button[aria-label="Tap to unlock"]');
    await unlockBtn.waitFor({ state: 'visible', timeout: 5_000 });
    await unlockBtn.click();
    await page.locator('button[aria-label="Settings"]').waitFor({ state: 'visible', timeout: 5_000 });

    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});
