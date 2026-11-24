// Verifies React player host bridges (animex-player-state, animex-pref,
// everglow-key, exit-theater, EpisodeNavigator) and OfflineVideoHud controls.
import assert from 'node:assert/strict';
import { createReadStream, existsSync, readdirSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { homedir } from 'node:os';
import { extname, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright-core';
import { isEditableTarget, resolveEverglowPlayerKey } from '../src/shared/widgets/everglowPlayerKeys.ts';
import { checkMovieStreamDuration, formatMinutesShort } from '../src/features/cinema/movieDurationGuard.ts';

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

/** Tap one row in an already-open Switch Provider sheet (rows read "Name desc"). */
async function pickFromSheet(page, name) {
  await page.getByRole('button', { name: new RegExp(`^${name} `) }).first().click();
  await page.waitForSelector('text=Switch Provider', { state: 'detached', timeout: 5_000 });
}

/** Open the Switch Provider sheet and tap one row by its name. */
async function pickProvider(page, name) {
  // The card is keyboard-operable, and Enter sidesteps the pulsing dot's animation.
  await page.locator('[data-testid="player-source"]').first().press('Enter');
  await page.waitForSelector('text=Switch Provider', { timeout: 5_000 });
  await pickFromSheet(page, name);
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

    await page.waitForSelector('[data-testid="player-source"]', { timeout: 10_000 });
    const epBtn = page.locator('button[aria-expanded]').first();
    await epBtn.waitFor({ state: 'visible', timeout: 10_000 });
    assert.equal(await epBtn.getAttribute('aria-expanded'), 'false');
    await epBtn.click();
    assert.equal(await epBtn.getAttribute('aria-expanded'), 'true');

    // Open Switch Provider sheet, verify native default-source buttons, and pick Everglow (everglow-embed).
    // The card is keyboard-operable, and Enter sidesteps the pulsing dot's animation.
  await page.locator('[data-testid="player-source"]').first().press('Enter');
    await page.waitForSelector('text=Switch Provider', { timeout: 5_000 });
    const defaultBtns = page.locator('button[aria-label="Set as default source"]');
    assert.ok((await defaultBtns.count()) >= 1, 'Switch Provider sheet must render native default-source buttons');
    // Everglow is the first row and the default; switching must work both ways and
    // end on Everglow, which is the player the bridge assertions below drive.
    await pickFromSheet(page, 'Celestia');
    await pickProvider(page, 'Everglow');

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
    // The iframe's src is set before its frame navigates, so wait for the navigation instead of assuming it happened.
    const isEmbed = (f) => f.url().includes('everglow-stream.khentplaysmoba.workers.dev');
    const frame =
      page.frames().find(isEmbed) ??
      (await page.waitForEvent('framenavigated', { predicate: isEmbed, timeout: 10_000 }).catch(() => undefined));
    assert.ok(frame, 'everglow-embed iframe should load');
    await page.waitForFunction(() => Array.isArray(window.__rx) && window.__rx.length > 0, null, { timeout: 5_000 }).catch(() => {});
    await frame.waitForFunction(() => Array.isArray(window.__rx) && window.__rx.some((m) => m?.type === 'animex-player-state'), null, {
      timeout: 10_000,
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
      track.stop();
      canvas.remove();
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

    await page.waitForSelector('video', { timeout: 15_000 });
    await page.waitForSelector('div[role="slider"][aria-label="Seek"]', { timeout: 20_000 });
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

test('Cinema movie player keeps server switcher reachable on phone portrait, landscape, and theater mode', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));

    await page.route('https://everglow-1c6db.web.app/**', async (route) => {
      await route.fulfill({ status: 200, contentType: 'text/html', body: '<!doctype html><html><body></body></html>' });
    });
    await page.route('https://everglow-stream.khentplaysmoba.workers.dev/**', async (route) => {
      await route.fulfill({ status: 200, contentType: 'text/html', body: '<!doctype html><html><body></body></html>' });
    });

    await page.goto(`${baseUrl}/cinema/video/4348?type=movie&title=Pride%20%26%20Prejudice&agent=1&hud=0`, {
      waitUntil: 'domcontentloaded',
    });

    await page.waitForSelector('[data-testid="player-source"]', { timeout: 10_000 });

    // Everglow's own player draws its theater chrome, so pick Celestia first: this
    // test covers the app-owned server switcher.
    await pickProvider(page, 'Celestia');

    const layout = await page.evaluate(() => {
      const iframe = document.querySelector('iframe');
      const provCard = [...document.querySelectorAll('[role="button"]')].find((el) =>
        el.getAttribute('data-testid') === 'player-source',
      );
      const topServers = [...document.querySelectorAll('button')].find(
        (b) => b.textContent?.includes('Servers'),
      );
      const bodyText = document.body.innerText;
      return {
        iframeRect: iframe?.getBoundingClientRect().toJSON() ?? null,
        provRect: provCard?.getBoundingClientRect().toJSON() ?? null,
        topServersRect: topServers?.getBoundingClientRect().toJSON() ?? null,
        hasHideSpoilers: bodyText.includes('Hide spoilers'),
        hasAutoplayNext: bodyText.includes('Autoplay next episode'),
      };
    });

    assert.ok(layout.iframeRect, 'movie iframe should mount');
    assert.ok(layout.iframeRect.top <= 64, `portrait player should sit directly under header, got top=${layout.iframeRect.top}`);
    assert.ok(layout.provRect && layout.provRect.bottom < 420, `provider card should sit immediately below video, got ${JSON.stringify(layout.provRect)}`);
    assert.ok(layout.topServersRect && layout.topServersRect.width > 0, 'top bar Servers button should be visible on phone portrait');
    assert.equal(layout.hasHideSpoilers, false, 'movie page should not show TV-only Hide spoilers chip');
    assert.equal(layout.hasAutoplayNext, false, 'movie page should not show TV-only Autoplay next episode chip');

    // Landscape phone: top-bar Servers button stays visible above the fold and opens Switch Provider.
    await page.setViewportSize({ width: 844, height: 390 });
    await page.waitForTimeout(100);
    const landscapeServers = page.getByRole('button', { name: /Servers/ }).first();
    await landscapeServers.waitFor({ state: 'visible', timeout: 5_000 });
    const box = await landscapeServers.boundingBox();
    assert.ok(box && box.y >= 0 && box.y + box.height <= 60, `landscape top-bar Servers button should be in header, got ${JSON.stringify(box)}`);
    await landscapeServers.click();
    await page.waitForSelector('text=Switch Provider', { timeout: 5_000 });
    await page.keyboard.press('Escape');
    await page.waitForSelector('text=Switch Provider', { state: 'detached', timeout: 5_000 });

    // Theater mode exposes Switch server alongside Exit theater and switches to Everglow.
    await page.locator('button').filter({ has: page.locator('span:text-is("fullscreen")') }).click();
    const switchInTheater = page.locator('button[aria-label="Switch server"]');
    await switchInTheater.waitFor({ state: 'visible', timeout: 5_000 });
    await switchInTheater.click();
    await page.waitForSelector('text=Switch Provider', { timeout: 5_000 });
    await pickFromSheet(page, 'Everglow');
    await page.waitForFunction(
      () => Boolean(document.querySelector('iframe')?.src.includes('everglow-stream.khentplaysmoba.workers.dev')),
      null,
      { timeout: 5_000 },
    );

    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});

test('checkMovieStreamDuration detects decoy clips and wrong-movie runtime mismatches without false positives', () => {
  // Pride & Prejudice (2005) = 129m; CineSrc 2003 mismatch = 6198s (103m); Everglow = 7689s (128m).
  assert.deepEqual(checkMovieStreamDuration(7689, 129), { kind: 'ok' });
  assert.deepEqual(checkMovieStreamDuration(6198, 129), { kind: 'mismatch', actualMinutes: 103, expectedMinutes: 129 });
  // Trailer / decoy under 15 minutes for a feature film.
  assert.deepEqual(checkMovieStreamDuration(180, 129), { kind: 'decoy', actualMinutes: 3, expectedMinutes: 129 });
  // PAL 4% speedup (115m vs 120m) and short films (<45m) stay ok.
  assert.deepEqual(checkMovieStreamDuration(115 * 60, 120), { kind: 'ok' });
  assert.deepEqual(checkMovieStreamDuration(10 * 60, 25), { kind: 'ok' });
  assert.equal(formatMinutesShort(103), '1h 43m');
  assert.equal(formatMinutesShort(42), '42m');
});

test('Cinema movie player warns on runtime mismatch with 1-tap switch and auto-fails over on short decoy clips', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));

    let shellDuration = 4200;
    await page.route('https://everglow-1c6db.web.app/**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'text/html',
        body: `<!doctype html><html><body><script>
          window.parent.postMessage({ type: 'cinesrc:loadedmetadata', duration: ${shellDuration} }, '*');
        </script></body></html>`,
      });
    });
    await page.route('https://everglow-stream.khentplaysmoba.workers.dev/**', async (route) => {
      await route.fulfill({ status: 200, contentType: 'text/html', body: '<!doctype html><html><body></body></html>' });
    });

    // 1. Mismatch (70m vs 167m agent runtime): shows warning banner with 1-tap Try Everglow button.
    await page.goto(`${baseUrl}/cinema/video/693134?type=movie&title=Dune%3A%20Part%20Two&agent=1&hud=0`, {
      waitUntil: 'domcontentloaded',
    });
    // The wrapper shell is the server that reports duration, so start on Celestia.
    await page.waitForSelector('[data-testid="player-source"]', { timeout: 10_000 });
    await pickProvider(page, 'Celestia');
    await page.waitForSelector('text=may be the wrong movie', { timeout: 10_000 });
    await page.getByRole('button', { name: 'Try Everglow' }).click();
    await page.waitForFunction(
      () => Boolean(document.querySelector('iframe')?.src.includes('everglow-stream.khentplaysmoba.workers.dev')),
      null,
      { timeout: 5_000 },
    );
    assert.equal(await page.locator('text=may be the wrong movie').count(), 0);

    // 2. Short decoy clip (3m vs 181m): auto-fails over from Celestia to Everglow.
    shellDuration = 180;
    await page.goto(`${baseUrl}/cinema/video/872585?type=movie&title=Oppenheimer&agent=1&hud=0`, {
      waitUntil: 'domcontentloaded',
    });
    await page.waitForSelector('[data-testid="player-source"]', { timeout: 10_000 });
    await pickProvider(page, 'Celestia');
    await page.waitForFunction(
      () => Boolean(document.querySelector('iframe')?.src.includes('everglow-stream.khentplaysmoba.workers.dev')),
      null,
      { timeout: 10_000 },
    );

    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});
