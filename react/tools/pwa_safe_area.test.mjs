// Verifies PWA manifest/meta alignment and safe-area layout across phone,
// tablet, and landscape viewports with simulated notch & home-indicator insets.
import assert from 'node:assert/strict';
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

function startDistServer() {
  return new Promise((done) => {
    const s = createServer((req, res) => {
      const urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
      let file = join(DIST, urlPath === '/' ? 'index.html' : urlPath);
      if (!existsSync(file) || statSync(file).isDirectory()) file = join(DIST, 'index.html');
      res.writeHead(200, { 'Content-Type': TYPES[extname(file)] || 'application/octet-stream' });
      createReadStream(file).pipe(res);
    });
    s.listen(0, '127.0.0.1', () => done({ server: s, origin: `http://127.0.0.1:${s.address().port}` }));
  });
}

test('PWA manifest and index.html align standalone metadata and theme colors', () => {
  const manifest = JSON.parse(readFileSync(join(DIST, 'manifest.json'), 'utf8'));
  assert.equal(manifest.display, 'standalone');
  assert.equal(manifest.start_url, '/');
  assert.equal(manifest.background_color, '#100A1C');
  assert.equal(manifest.theme_color, '#100A1C');

  const html = readFileSync(join(DIST, 'index.html'), 'utf8');
  assert.match(html, /viewport-fit=cover/);
  assert.match(html, /apple-mobile-web-app-capable"\s+content="yes"/);
  assert.match(html, /apple-mobile-web-app-status-bar-style"\s+content="black-translucent"/);
  assert.match(html, /name="theme-color"\s+content="#100A1C"/);

  const cssFiles = readdirSync(join(DIST, 'assets')).filter((f) => f.endsWith('.css'));
  const css = cssFiles.map((f) => readFileSync(join(DIST, 'assets', f), 'utf8')).join('\n');
  assert.match(
    css,
    /@supports\s*\(-webkit-touch-callout:\s*none\)\s*and\s*\(height:\s*100lvh\)/,
    '100lvh standalone rule must be gated by @supports (height: 100lvh) for iOS <15.4 safety',
  );
});

test('PWA safe-area insets keep top controls and headers clear of notches across devices', async () => {
  const { server, origin } = await startDistServer();
  const executablePath = findChrome();
  const browser = await chromium.launch({
    headless: true,
    executablePath,
    args: ['--mute-audio', '--no-sandbox', '--disable-dev-shm-usage'],
  });

  try {
    const context = await browser.newContext({ viewport: { width: 430, height: 932 } });
    const page = await context.newPage();

    const setSafeArea = (insets) =>
      page.evaluate(({ top = 0, right = 0, bottom = 0, left = 0 }) => {
        const root = document.documentElement.style;
        root.setProperty('--safe-top', `${top}px`);
        root.setProperty('--safe-right', `${right}px`);
        root.setProperty('--safe-bottom', `${bottom}px`);
        root.setProperty('--safe-left', `${left}px`);
      }, insets);

    // 1. iPhone 15 Pro Max portrait on Dashboard (59px Dynamic Island, 34px home indicator)
    await page.goto(`${origin}/?agent=dashboard&hud=0`, { waitUntil: 'networkidle' });
    await page.waitForSelector('button[aria-label="Open Sanctuary chat"]', { timeout: 15000 });
    await setSafeArea({ top: 59, bottom: 34 });

    const dashMetrics = await page.evaluate(() => {
      const bg = getComputedStyle(document.documentElement).backgroundColor;
      const labels = ['Open creator tools', 'Open mood picker', 'Open Everglow Canvas', 'Open Sanctuary chat'];
      const topButtons = labels.map((label) => {
        const el = document.querySelector(`button[aria-label="${label}"]`);
        const rect = el ? el.getBoundingClientRect() : null;
        return { label, top: rect?.top ?? -1, left: rect?.left ?? -1, right: rect?.right ?? -1 };
      });
      const motchi = document.querySelector('button[aria-label="Open Motchi AI assistant"]')?.getBoundingClientRect();
      return { bg, topButtons, motchiBottom: motchi?.bottom ?? 9999 };
    });

    assert.equal(dashMetrics.bg, 'rgb(16, 10, 28)', 'html background must match AppColors.inkDeep (#100A1C)');
    for (const btn of dashMetrics.topButtons) {
      assert.ok(btn.top >= 59, `Dashboard "${btn.label}" top (${btn.top}) must clear 59px Dynamic Island`);
    }
    assert.ok(dashMetrics.motchiBottom <= 932 - 34, `Motchi button bottom (${dashMetrics.motchiBottom}) must clear 34px home indicator`);

    // 2. Landscape iPhone on Dashboard (59px left/right island, 21px bottom)
    await page.setViewportSize({ width: 932, height: 430 });
    await setSafeArea({ top: 0, right: 59, bottom: 21, left: 59 });
    const landMetrics = await page.evaluate(() => {
      const creator = document.querySelector('button[aria-label="Open creator tools"]')?.getBoundingClientRect();
      const chat = document.querySelector('button[aria-label="Open Sanctuary chat"]')?.getBoundingClientRect();
      return { creatorLeft: creator?.left ?? -1, chatRight: chat?.right ?? 9999 };
    });
    assert.ok(landMetrics.creatorLeft >= 59, `Landscape creator button left (${landMetrics.creatorLeft}) must clear 59px left inset`);
    assert.ok(landMetrics.chatRight <= 932 - 59, `Landscape chat button right (${landMetrics.chatRight}) must clear 59px right inset`);

    // 3. Sanctuary Chat on iPhone 15 Pro Max portrait
    await page.setViewportSize({ width: 430, height: 932 });
    await page.goto(`${origin}/?agent=sanctuary&hud=0`, { waitUntil: 'networkidle' });
    await page.waitForSelector('h1', { timeout: 15000 });
    await setSafeArea({ top: 59, bottom: 34 });
    const sanctuaryTop = await page.evaluate(() => document.querySelector('h1')?.getBoundingClientRect().top ?? -1);
    assert.ok(sanctuaryTop >= 59, `Sanctuary header top (${sanctuaryTop}) must clear 59px Dynamic Island`);

    // 4. Anime and Manga headers on iPhone 11 portrait (48px notch)
    await page.setViewportSize({ width: 414, height: 896 });
    await page.goto(`${origin}/?agent=anime&hud=0`, { waitUntil: 'networkidle' });
    await page.waitForSelector('header', { timeout: 15000 });
    await setSafeArea({ top: 48, bottom: 34 });
    const animePadTop = await page.evaluate(() => parseFloat(getComputedStyle(document.querySelector('header')).paddingTop));
    assert.equal(animePadTop, 48, 'AnimeXTopHeader must respect 48px notch inset');

    await page.goto(`${origin}/?agent=manga&hud=0`, { waitUntil: 'networkidle' });
    await page.waitForSelector('header', { timeout: 15000 });
    await setSafeArea({ top: 48, bottom: 34 });
    const mangaPadTop = await page.evaluate(() => parseFloat(getComputedStyle(document.querySelector('header')).paddingTop));
    assert.equal(mangaPadTop, 48, 'KatanaHeader must respect 48px notch inset');

    // 5. EverglowScaffold (Gallery) in landscape (59px left/right inset)
    await page.setViewportSize({ width: 932, height: 430 });
    await page.goto(`${origin}/?agent=gallery&hud=0`, { waitUntil: 'networkidle' });
    await page.waitForSelector('h1', { timeout: 15000 });
    await setSafeArea({ top: 0, right: 59, bottom: 21, left: 59 });
    const galleryLeft = await page.evaluate(() => document.querySelector('h1')?.getBoundingClientRect().left ?? -1);
    assert.ok(galleryLeft >= 59, `Gallery heading left (${galleryLeft}) must clear 59px landscape safe area`);

    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});
