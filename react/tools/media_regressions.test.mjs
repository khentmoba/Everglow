// Regression tests for Living Archive photos, Jukebox artwork, Dashboard
// carousels & scroll memory, Cinema/Anime hover details, and Anime Continue Watching.
import assert from 'node:assert/strict';
import { createReadStream, existsSync, readdirSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { homedir } from 'node:os';
import { extname, join, resolve } from 'node:path';
import test from 'node:test';
import { chromium } from 'playwright-core';

const DIST = resolve('dist');
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

async function withDistServer(fn) {
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
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({ headless: true, executablePath: findChrome() });
  try {
    await fn(baseUrl, browser);
  } finally {
    await browser.close();
    server.close();
  }
}

test('Dashboard: Living Archive images, Jukebox artwork, carousels, and scroll restoration work', async () => {
  await withDistServer(async (baseUrl, browser) => {
    const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));

    await page.goto(`${baseUrl}/dashboard?agent=1`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=LIVING ARCHIVE', { timeout: 10_000 });

    // Living Archive renders real milestone images with non-zero naturalWidth.
    const archiveImgs = await page.evaluate(() => {
      const imgs = [...document.querySelectorAll('button[aria-label^="Open memory "] img')];
      return imgs.map((img) => ({ complete: img.complete, w: img.naturalWidth }));
    });
    assert.ok(archiveImgs.length >= 2, `expected Living Archive photos, got ${archiveImgs.length}`);
    for (const img of archiveImgs) {
      assert.ok(img.complete && img.w > 0, `Living Archive image failed to load: ${JSON.stringify(img)}`);
    }

    // Jukebox Top 10, Recently Heard, and Artist Showdown render album artwork.
    await page.waitForSelector("text=Khent's Top 10", { timeout: 10_000 });
    await page.waitForSelector('text=Demo Track One', { timeout: 10_000 });
    await page.waitForSelector('text=Demo Ballad One', { timeout: 10_000 });
    const jukeboxImgs = await page.evaluate(() => {
      const imgs = [...document.querySelectorAll('img')].filter((i) => i.src.includes('/images/demo/poster-'));
      return imgs.filter((i) => i.complete && i.naturalWidth > 0).length;
    });
    assert.ok(jukeboxImgs >= 8, `expected artwork images across Living Archive & Jukebox, got ${jukeboxImgs}`);

    // Scroll Cinema Vault into view so IntersectionObserver marks it visible, then verify its marquee animates.
    await page.locator('text=Cinema Vault').scrollIntoViewIfNeeded();
    await page.waitForTimeout(150);
    const t1 = await page.evaluate(() => {
      const tracks = [...document.querySelectorAll('div[style*="will-change: transform"]')];
      return tracks.map((t) => t.style.transform);
    });
    assert.ok(t1.length >= 3, `expected marquee tracks on dashboard, got ${t1.length}`);
    await page.waitForTimeout(300);
    const t2 = await page.evaluate(() => {
      const tracks = [...document.querySelectorAll('div[style*="will-change: transform"]')];
      return tracks.map((t) => t.style.transform);
    });
    assert.ok(
      t1.some((v, idx) => v !== t2[idx]),
      `expected visible dashboard carousel to advance (${JSON.stringify(t1)} vs ${JSON.stringify(t2)})`,
    );

    // Scroll down Dashboard, navigate to Cinema, then return and verify scroll position is preserved.
    await page.locator('text=Cinema Vault').scrollIntoViewIfNeeded();
    await page.waitForTimeout(300);
    const savedScroll = await page.evaluate(() => {
      const scroller = [...document.querySelectorAll('div')].find(
        (d) => getComputedStyle(d).overflowY === 'auto' && d.scrollHeight > d.clientHeight + 200,
      );
      return scroller ? scroller.scrollTop : 0;
    });
    assert.ok(savedScroll >= 800, `expected Dashboard to be scrolled down before navigating, got ${savedScroll}`);
    await page.locator('button:has-text("View All")').nth(1).click();
    await page.waitForSelector('text=Trending Now', { timeout: 10_000 });
    await page.locator('button:has-text("Everglow")').first().click();
    await page.waitForSelector('text=LIVING ARCHIVE', { timeout: 10_000 });
    await page.waitForTimeout(350);
    const restoredScroll = await page.evaluate(() => {
      const scroller = [...document.querySelectorAll('div')].find(
        (d) => getComputedStyle(d).overflowY === 'auto' && d.scrollHeight > d.clientHeight + 200,
      );
      return scroller ? scroller.scrollTop : 0;
    });
    assert.ok(restoredScroll >= 800, `expected Dashboard scrollTop to restore near ${savedScroll}, got ${restoredScroll}`);
    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  });
});

test('Cinema & Anime: hover details appear and Anime Continue Watching excludes finished series', async () => {
  await withDistServer(async (baseUrl, browser) => {
    const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
    const page = await context.newPage();

    // Cinema hover details popover.
    await page.goto(`${baseUrl}/cinema?agent=1`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=Trending Now', { timeout: 10_000 });
    const cinemaCard = page.locator('button[aria-label^="Details for "]').first();
    await cinemaCard.hover();
    await page.waitForTimeout(360);
    const matchVisible = await page.locator('text=/% Match/').first().isVisible();
    assert.ok(matchVisible, 'expected Cinema hover details popover with % Match on desktop hover');

    // Anime Continue Watching excludes watched/finished anime and shows 280x200 landscape cards.
    await page.goto(`${baseUrl}/anime?agent=1`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=Continue Watching', { timeout: 10_000 });
    await page.waitForSelector('text=Trending This Week', { timeout: 10_000 });

    const continueSectionText = await page.evaluate(() => {
      const headings = [...document.querySelectorAll('div')];
      const cw = headings.find((el) => el.textContent?.trim() === 'Continue Watching');
      const section = cw?.closest('div[style*="margin-bottom: 40px"]');
      return section?.textContent ?? '';
    });
    assert.ok(continueSectionText.includes('Demo Anime Adventure'), `expected ongoing anime in Continue Watching, got: ${continueSectionText}`);
    assert.ok(continueSectionText.includes('EP 5/12'), `expected EP 5/12 badge on Continue Watching card, got: ${continueSectionText}`);
    assert.ok(!continueSectionText.includes('Demo Finished Quest'), `completed anime must not appear in Continue Watching: ${continueSectionText}`);

    const animeCard = page.locator('[data-animex-card="poster"]').first();
    await animeCard.scrollIntoViewIfNeeded();
    await animeCard.hover();
    await page.waitForSelector('text=Watch / More Info', { timeout: 5_000 });
    const watchHintVisible = await page.locator('text=Watch / More Info').isVisible();
    assert.ok(watchHintVisible, 'expected Anime hover details popover with Watch / More Info on desktop hover');

    await context.close();
  });
});
