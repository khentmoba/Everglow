import assert from 'node:assert/strict';
import { createReadStream, existsSync, readdirSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { homedir } from 'node:os';
import { extname, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright-core';
import {
  adjacentChapter,
  buildSpreads,
  clampZoomPan,
  computePinchAnchoredPan,
  computeTapAnchoredPan,
  detectChapterGap,
  DOUBLE_TAP_WINDOW_MS,
  findSpreadIndexForPage,
  isWideAspect,
  resolveEffectiveReadingMode,
  resolveTapZoneAction,
  setLruEntry,
  SINGLE_TAP_DELAY_MS,
} from '../src/features/manga/readerSpread.ts';

const DIST = fileURLToPath(new URL('../dist/', import.meta.url));
const TYPES = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
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

/** Flip document.visibilityState without a real tab switch. */
async function setVisibility(page, state) {
  await page.evaluate((next) => {
    Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => next });
    Object.defineProperty(document, 'hidden', { configurable: true, get: () => next === 'hidden' });
  }, state);
}

async function serveDist() {
  const server = createServer((req, res) => {
    const pathname = (req.url ?? '/').split('?')[0];
    const target = join(DIST, pathname === '/' ? 'index.html' : pathname);
    const file = existsSync(target) && statSync(target).isFile() ? target : join(DIST, 'index.html');
    res.writeHead(200, { 'content-type': TYPES[extname(file)] ?? 'application/octet-stream' });
    createReadStream(file).pipe(res);
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const addr = server.address();
  return { server, baseUrl: `http://127.0.0.1:${addr.port}` };
}

test('buildSpreads pairs double-page spreads with cover offset and keeps wide spreads solo', () => {
  const wide = new Set([3]);
  const spreads = buildSpreads(6, 'double-rtl', true, wide, true, false);
  assert.deepEqual(spreads, [
    [{ pageIndex: 0 }],
    [{ pageIndex: 1 }, { pageIndex: 2 }],
    [{ pageIndex: 3 }],
    [{ pageIndex: 4 }, { pageIndex: 5 }],
  ]);
  assert.equal(findSpreadIndexForPage(spreads, 2), 1);
  assert.equal(findSpreadIndexForPage(spreads, 3), 2);
});

test('buildSpreads splits wide pages in reading order when splitWidePages is enabled', () => {
  const wide = new Set([1]);
  const rtl = buildSpreads(3, 'paged-rtl', true, wide, true, true);
  assert.deepEqual(rtl, [
    [{ pageIndex: 0 }],
    [{ pageIndex: 1, cropHalf: 'right' }],
    [{ pageIndex: 1, cropHalf: 'left' }],
    [{ pageIndex: 2 }],
  ]);

  const ltr = buildSpreads(3, 'paged-ltr', true, wide, true, true);
  assert.deepEqual(ltr, [
    [{ pageIndex: 0 }],
    [{ pageIndex: 1, cropHalf: 'left' }],
    [{ pageIndex: 1, cropHalf: 'right' }],
    [{ pageIndex: 2 }],
  ]);
});

test('resolveTapZoneAction respects RTL, LTR, layouts, and inversion', () => {
  assert.equal(resolveTapZoneAction(0.15, 0.5, 'standard', true, false), 'next');
  assert.equal(resolveTapZoneAction(0.85, 0.5, 'standard', true, false), 'prev');
  assert.equal(resolveTapZoneAction(0.5, 0.5, 'standard', true, false), 'toggle-ui');
  assert.equal(resolveTapZoneAction(0.15, 0.5, 'standard', true, true), 'prev');
  assert.equal(resolveTapZoneAction(0.15, 0.5, 'standard', false, false), 'prev');
  assert.equal(resolveTapZoneAction(0.5, 0.1, 'kindle', false, false), 'toggle-ui');
  assert.equal(resolveTapZoneAction(0.5, 0.6, 'kindle', false, false), 'next');
  assert.equal(resolveTapZoneAction(0.1, 0.6, 'kindle', false, false), 'prev');
  assert.equal(resolveTapZoneAction(0.1, 0.5, 'disabled', true, false), 'toggle-ui');
});

test('adjacentChapter navigates newest-first chapter lists and skips read chapters when requested', () => {
  const chapters = [
    { id: 'c4', num: '4', title: 'Ch 4' },
    { id: 'c3', num: '3', title: 'Ch 3' },
    { id: 'c2', num: '2', title: 'Ch 2' },
    { id: 'c1', num: '1', title: 'Ch 1' },
  ];
  assert.equal(adjacentChapter(chapters, 'c2', 'next')?.id, 'c3');
  assert.equal(adjacentChapter(chapters, 'c2', 'prev')?.id, 'c1');
  assert.equal(adjacentChapter(chapters, 'c4', 'next'), null);
  assert.equal(
    adjacentChapter(chapters, 'c1', 'next', { skipRead: true, readIds: new Set(['c2', 'c3']) })?.id,
    'c4',
  );
  assert.equal(detectChapterGap(chapters[3], chapters[2]), 0);
  assert.equal(detectChapterGap({ id: 'c10', num: '10', title: '' }, { id: 'c13', num: '13', title: '' }), 2);
  assert.equal(detectChapterGap({ id: 'c10', num: '10', title: '' }, { id: 'c10.5', num: '10.5', title: '' }), 0);
});

test('tap timing, zoom bounds, tap-anchored pan, and finger-anchored pinch pan behave accurately', () => {
  assert.ok(SINGLE_TAP_DELAY_MS > DOUBLE_TAP_WINDOW_MS, 'single-tap delay must exceed double-tap window');
  assert.equal(isWideAspect(1400, 960), true);
  assert.equal(isWideAspect(800, 1200), false);
  assert.deepEqual(computeTapAnchoredPan(0.5, 0.5, 400, 800, 2), { x: 0, y: 0 });
  const topLeft = computeTapAnchoredPan(0.1, 0.1, 400, 800, 2);
  assert.ok(topLeft.x > 0 && topLeft.y > 0);
  // Original-fit oversized content allows full edge panning even at zoom 1.5
  const bigPan = clampZoomPan(500, 600, 1200, 1600, 400, 800, 1.5);
  assert.ok(bigPan.x === 500 && bigPan.y === 600);
  const pinch = computePinchAnchoredPan({ x: 0, y: 0 }, 1, 2, 0.2, 0.25, 400, 800);
  assert.ok(pinch.x > 0 && pinch.y > 0);
});

test('resolveEffectiveReadingMode auto-detects webtoons and switches phone portrait vs tablet landscape', () => {
  assert.equal(resolveEffectiveReadingMode('auto-rtl', 430, 932, 0.38), 'webtoon');
  assert.equal(resolveEffectiveReadingMode('auto-ltr', 1024, 768, 0.45), 'webtoon');
  assert.equal(resolveEffectiveReadingMode('auto-rtl', 430, 932, 0.68), 'paged-rtl');
  assert.equal(resolveEffectiveReadingMode('auto-rtl', 1024, 768, 0.68), 'double-rtl');
  assert.equal(resolveEffectiveReadingMode('auto-ltr', 768, 1024, 0.7), 'paged-ltr');
  assert.equal(resolveEffectiveReadingMode('auto-ltr', 1180, 820, 0.7), 'double-ltr');
  assert.equal(resolveEffectiveReadingMode('webtoon', 1180, 820, 0.7), 'webtoon');
});

test('l-shaped tap zones and true LRU map eviction behave accurately', () => {
  assert.equal(resolveTapZoneAction(0.5, 0.1, 'l-shaped', true, false), 'prev');
  assert.equal(resolveTapZoneAction(0.5, 0.5, 'l-shaped', true, false), 'toggle-ui');
  assert.equal(resolveTapZoneAction(0.5, 0.85, 'l-shaped', true, false), 'next');

  const cache = new Map();
  setLruEntry(cache, 'a', 1, 2);
  setLruEntry(cache, 'b', 2, 2);
  setLruEntry(cache, 'a', 10, 2); // refresh 'a'
  setLruEntry(cache, 'c', 3, 2); // should evict 'b', not 'a'
  assert.deepEqual(Array.from(cache.keys()), ['a', 'c']);
  assert.equal(cache.get('a'), 10);
});

test('Manga auto-read pauses while the tab is hidden', async (t) => {
  const executablePath = findChrome();
  if (!executablePath || !existsSync(join(DIST, 'index.html'))) {
    t.skip('Chrome or react/dist not available');
    return;
  }
  const { server, baseUrl } = await serveDist();
  const browser = await chromium.launch({ executablePath, headless: true, args: ['--mute-audio'] });
  try {
    const page = await browser.newPage({ viewport: { width: 430, height: 932 } });
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    // Fastest auto-read speed (2500ms a page) keeps the check short.
    await page.addInitScript(() => {
      localStorage.setItem(
        'flutter.katana_reader_settings_v3',
        JSON.stringify(JSON.stringify({ readingMode: 'paged-rtl', autoScrollSpeed: 3 })),
      );
    });
    await page.goto(`${baseUrl}/manga/reader?agent=1&hud=0`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('[aria-label^="Manga reader:"]', { timeout: 10000 });
    await page.waitForSelector('img[alt="Page 2"]', { timeout: 10000 });

    const pager = page.locator('button[aria-label*="Tap to type a page number"]');
    await pager.waitFor({ timeout: 5000 });
    const startPage = (await pager.textContent())?.trim() ?? '';
    assert.match(startPage, /2 \/ 6/);

    await page.click('button[aria-label="Start auto-read"]');
    await page.waitForSelector('button[aria-label="Pause auto-read"]', { timeout: 5000 });

    await setVisibility(page, 'hidden');
    await page.waitForTimeout(6000);
    assert.equal(
      (await pager.textContent())?.trim(),
      startPage,
      'a hidden tab must not auto-advance the reader',
    );

    await setVisibility(page, 'visible');
    await page.waitForFunction(
      (before) =>
        document.querySelector('button[aria-label*="Tap to type a page number"]')?.textContent?.trim() !==
        before,
      startPage,
      { timeout: 8000 },
    );

    assert.deepEqual(errors, [], `Expected zero page errors, got: ${errors.join('; ')}`);
  } finally {
    await browser.close();
    server.close();
  }
});

test('Celestial manga reader works end-to-end in Chrome on phone and tablet', async (t) => {
  const executablePath = findChrome();
  if (!executablePath || !existsSync(join(DIST, 'index.html'))) {
    t.skip('Chrome or react/dist not available');
    return;
  }
  const { server, baseUrl } = await serveDist();
  const browser = await chromium.launch({ executablePath, headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 430, height: 932 } });
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    await page.goto(`${baseUrl}/manga/reader?agent=1&hud=0`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('[aria-label^="Manga reader:"]', { timeout: 10000 });
    await page.waitForSelector('img[alt="Page 2"]', { timeout: 10000 });

    // Demo resumes to page 2 and shows vertical seekbar in webtoon mode
    const jumpBtn = page.locator('button[aria-label*="Tap to type a page number"]');
    await jumpBtn.waitFor({ timeout: 5000 });
    assert.match(await jumpBtn.textContent(), /2 \/ 6/);
    await page.waitForSelector('input[aria-label="Vertical page scrubber"]', { timeout: 5000 });

    // Direct Page Jump dialog jumps to page 5
    await jumpBtn.click();
    await page.fill('input[aria-label="Page number"]', '5');
    await page.click('button:has-text("Go")');
    assert.match(await jumpBtn.textContent(), /5 \/ 6/);

    // Bookmark current page & verify in Chapters / Pages / Saved drawer
    await page.click('button[aria-label="Bookmark current page"]');
    await page.click('button[aria-label="Open chapters and bookmarks"]');
    await page.click('button[role="tab"]:has-text("Pages")');
    await page.waitForSelector('img[alt="Thumbnail page 5"]', { timeout: 5000 });
    await page.click('button[role="tab"]:has-text("Saved")');
    await page.waitForSelector('text=Page 5', { timeout: 5000 });
    await page.keyboard.press('Escape');

    // Quick Display popover opens from bottom HUD and closes on Escape
    await page.click('button[aria-label="Quick brightness and display"]');
    await page.waitForSelector('input[aria-label="Quick brightness"]', { timeout: 5000 });
    await page.keyboard.press('Escape');

    // Settings sheet: switch to Manga RTL & enable Crop Scan Borders without breaking images
    await page.click('button[aria-label="Reader settings"]');
    await page.click('button:has-text("Manga RTL")');
    await page.click('button[role="tab"]:has-text("Display")');
    await page.click('button[role="switch"]:has-text("Crop scan borders")');
    await page.keyboard.press('Escape');

    await page.waitForSelector('img[alt="Page 5"]', { timeout: 5000 });
    const loadedOk = await page.evaluate(() => {
      const img = document.querySelector('img[alt="Page 5"]');
      return Boolean(img && img.complete && img.naturalWidth > 0);
    });
    assert.equal(loadedOk, true, 'Page 5 image must stay loaded with crop borders enabled');

    // RTL keyboard navigation: ArrowLeft advances forward (5 -> 6), ArrowRight goes back (6 -> 5), Space advances (5 -> 6)
    await page.keyboard.press('ArrowLeft');
    assert.match(await jumpBtn.textContent(), /6 \/ 6/);
    await page.keyboard.press('ArrowRight');
    assert.match(await jumpBtn.textContent(), /5 \/ 6/);
    await page.keyboard.press('Space');
    assert.match(await jumpBtn.textContent(), /6 \/ 6/);

    // Dismiss first-time tap-zone hint overlay if shown
    const hintText = page.locator('text=Tap Center for Menu');
    if (await hintText.isVisible()) {
      await hintText.click();
    }

    // Instant RTL tap-zone navigation using viewport ratios (no 265ms lag!)
    const vp = page.viewportSize();
    await page.mouse.click(Math.round(vp.width * 0.85), Math.round(vp.height * 0.5));
    assert.match(await jumpBtn.textContent(), /5 \/ 6/);
    await page.mouse.click(Math.round(vp.width * 0.15), Math.round(vp.height * 0.5));
    assert.match(await jumpBtn.textContent(), /6 \/ 6/);

    // Double-tap zoom in center shows Reset pill, clicking Reset returns to 1x
    await page.mouse.click(Math.round(vp.width * 0.5), Math.round(vp.height * 0.5));
    await page.waitForTimeout(70);
    await page.mouse.click(Math.round(vp.width * 0.5), Math.round(vp.height * 0.5));
    const resetPill = page.locator('button:has-text("Reset")');
    await resetPill.waitFor({ timeout: 3000 });
    await resetPill.click();
    await resetPill.waitFor({ state: 'detached', timeout: 3000 });

    // Continuous Horizontal Strip (Strip RTL) mode renders all pages horizontally
    await page.click('button[aria-label="Reader settings"]');
    await page.click('button:has-text("Strip RTL")');
    await page.click('button[aria-label="Close Reader Settings"]');
    await page.waitForSelector('img[alt="Page 1"]', { timeout: 5000 });

    // Compact 360px phone layout check: zero horizontal overflow in HUD
    await page.setViewportSize({ width: 360, height: 780 });
    await page.waitForTimeout(150);
    const overflow360 = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
    assert.equal(overflow360, false, '360px phone viewport must have zero horizontal overflow');

    // Tablet landscape auto-spread + Quick Profile preset check
    await page.setViewportSize({ width: 1024, height: 768 });
    await page.click('button[aria-label="Reader settings"]');
    await page.click('button:has-text("Tablet Spread")');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(200);

    assert.deepEqual(errors, [], `Expected zero page errors, got: ${errors.join('; ')}`);
  } finally {
    await browser.close();
    server.close();
  }
});

test('Webtoon Next chapter button advances even after seamless next-chapter append, and Currently Reading removal works', async (t) => {
  const chrome = findChrome();
  if (!chrome) {
    t.skip('No Chromium/Chrome executable found');
    return;
  }
  const { server, baseUrl } = await serveDist();
  const browser = await chromium.launch({ executablePath: chrome, headless: true, args: ['--mute-audio', '--no-sandbox'] });
  try {
    const page = await browser.newPage({ viewport: { width: 412, height: 892 } });
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));

    // 1. Open webtoon reader on Chapter 42
    await page.goto(`${baseUrl}/manga/reader?agent=1&hud=0`, { waitUntil: 'networkidle' });
    await page.waitForSelector('img[alt="Page 1"]', { timeout: 10000 });
    const liveStatus = page.locator('div[aria-live="polite"]').first();
    assert.match(await liveStatus.textContent(), /Chapter 42/);

    // Scroll near the bottom of Chapter 42 so seamless append loads Chapter 43 below it
    await page.evaluate(() => {
      const scroller = Array.from(document.querySelectorAll('div')).find(
        (d) => d.scrollHeight > d.clientHeight + 500 && getComputedStyle(d).overflowY === 'auto',
      );
      if (scroller) scroller.scrollTop = scroller.scrollHeight - scroller.clientHeight - 300;
    });
    await page.waitForFunction(() => document.querySelectorAll('[data-chapter-id="c43"]').length > 0, null, { timeout: 5000 });

    // Show HUD if scroll hid it, then click Next chapter
    await page.mouse.click(206, 446);
    await page.waitForTimeout(350);
    await page.locator('button[aria-label="Next chapter"]').click();
    await page.waitForFunction(
      () => /Chapter 43.*1 \/ 6/.test(document.querySelector('div[aria-live="polite"]')?.textContent ?? ''),
      null,
      { timeout: 5000 },
    );
    // Confirm it stays on Chapter 43 and does not bounce back to Chapter 42
    await page.waitForTimeout(300);
    assert.match(await liveStatus.textContent(), /Chapter 43.*1 \/ 6/);

    // Clicking Previous chapter returns to Chapter 42 cleanly, and scrolling seamlessly into Chapter 43 advances active chapter
    await page.locator('button[aria-label="Previous chapter"]').click();
    await page.waitForFunction(
      () => /Chapter 42/.test(document.querySelector('div[aria-live="polite"]')?.textContent ?? ''),
      null,
      { timeout: 5000 },
    );
    await page.evaluate(() => {
      const scroller = Array.from(document.querySelectorAll('div')).find(
        (d) => d.scrollHeight > d.clientHeight + 500 && getComputedStyle(d).overflowY === 'auto',
      );
      if (scroller) scroller.scrollTop = scroller.scrollHeight - scroller.clientHeight - 200;
    });
    await page.waitForFunction(() => document.querySelectorAll('[data-chapter-id="c43"]').length > 0, null, { timeout: 5000 });
    await page.evaluate(() => {
      const target = document.querySelector('[data-chapter-id="c43"][data-page-idx="1"]');
      if (target) target.scrollIntoView({ block: 'center' });
    });
    await page.waitForFunction(
      () => /Chapter 43/.test(document.querySelector('div[aria-live="polite"]')?.textContent ?? ''),
      null,
      { timeout: 5000 },
    );

    // 2. Mangacelestia Currently Reading removal removes the item immediately
    await page.goto(`${baseUrl}/manga?agent=1&hud=0`, { waitUntil: 'networkidle' });
    await page.waitForSelector('text=Currently Reading', { timeout: 10000 });
    await page.click('button:has-text("View all")');
    await page.waitForSelector('text=Fictional Starlight Manga', { timeout: 5000 });
    const removeBtn = page.locator('button[aria-label="Remove Fictional Starlight Manga from reading"]');
    await removeBtn.waitFor({ timeout: 5000 });
    await removeBtn.click();
    await page.waitForSelector('text=Fictional Starlight Manga', { state: 'detached', timeout: 5000 });

    assert.deepEqual(errors, [], `Expected zero page errors, got: ${errors.join('; ')}`);
  } finally {
    await browser.close();
    server.close();
  }
});
