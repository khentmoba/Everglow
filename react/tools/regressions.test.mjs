import assert from 'node:assert/strict';
import { createReadStream, existsSync, readdirSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { homedir } from 'node:os';
import { extname, join, resolve } from 'node:path';
import test from 'node:test';
import { chromium } from 'playwright-core';

const DIST = resolve('dist');
const ASSETS_DATA = resolve('../assets/data');
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

async function startDistServer() {
  const server = await new Promise((done) => {
    const s = createServer((req, res) => {
      const reqPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
      let file = join(DIST, reqPath);
      if (!existsSync(file) || !statSync(file).isFile()) {
        if (reqPath.startsWith('/data/')) {
          const assetFile = join(ASSETS_DATA, reqPath.slice('/data/'.length));
          if (existsSync(assetFile) && statSync(assetFile).isFile()) file = assetFile;
          else file = join(DIST, 'index.html');
        } else {
          file = join(DIST, 'index.html');
        }
      }
      res.writeHead(200, { 'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream', 'Cache-Control': 'no-store' });
      createReadStream(file).pipe(res);
    });
    s.listen(0, '127.0.0.1', () => done(s));
  });
  return { server, baseUrl: `http://127.0.0.1:${server.address().port}` };
}

async function collapseHud(page) {
  const btn = page.locator('button[aria-label="Collapse HUD (clean screenshot mode)"]');
  if (await btn.isVisible().catch(() => false)) {
    await btn.click();
  }
}

test('Dashboard RandomizerCard toggles AI mode, spins roulette, and renders CelebrationDialog', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 430, height: 932 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));

    await page.goto(`${baseUrl}/dashboard?agent=1`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=Digital Roulette', { timeout: 10_000 });
    await collapseHud(page);

    await page.getByRole('button', { name: 'Random', exact: true }).click();
    await page.waitForSelector('text=AI Powered', { timeout: 3_000 });
    await page.getByRole('button', { name: 'AI Powered', exact: true }).click();
    await page.waitForSelector('text=Random', { timeout: 3_000 });

    await page.getByRole('button', { name: 'Spin date roulette' }).click();
    await page.waitForSelector('text=You should...', { timeout: 5_000 });
    await page.getByRole('button', { name: 'Perfect!', exact: true }).click();
    await page.waitForFunction(() => !document.body.innerText.includes('You should...'), null, { timeout: 3_000 });

    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});

test('Desktop App page uses the bridge Everglow-Desktop injects', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 430, height: 932 } });
    // Same shape as Everglow-Desktop's src-tauri/src/website_bridge.rs script.
    await context.addInitScript(() => {
      Object.defineProperty(window, '__everglowDesktopVersion', { value: '0.3.0' });
      Object.defineProperty(window, '__everglowCheckForUpdates', {
        value: () => { window.__updateChecks = (window.__updateChecks ?? 0) + 1; },
      });
    });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));

    await page.goto(`${baseUrl}/desktop-app?agent=1`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=Everglow Desktop 0.3.0', { timeout: 10_000 });
    const pagesBefore = context.pages().length;
    await page.getByRole('button', { name: 'Check for desktop updates' }).click();
    assert.equal(await page.evaluate(() => window.__updateChecks), 1);
    assert.equal(context.pages().length, pagesBefore, 'update check must not open the download link');

    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});

test('Anime Downloads tab and Manga Genres portal, Genres grid, Reading toggle, Downloads, and Reader work', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 430, height: 932 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));

    await page.route('https://us-central1-everglow-1c6db.cloudfunctions.net/proxyFetchHtml**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'text/plain; charset=utf-8',
        body: `
          <html><body>
            <div id="hot_update"></div>
            <div>Latest Updates</div>
            <div>Hot Manga</div>
            <div class="genres">
              <a href="https://mangakatana.com/genre/action">Action</a> <span>(1240)</span>
              <a href="https://mangakatana.com/genre/romance">Romance</a> <span>(980)</span>
              <a href="https://mangakatana.com/genre/fantasy">Fantasy</a> <span>(750)</span>
            </div>
          </body></html>
        `,
      });
    });

    await page.goto(`${baseUrl}/anime?agent=1`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=Downloads', { timeout: 10_000 });
    await collapseHud(page);
    await page.getByText('Downloads', { exact: true }).first().click();
    await page.waitForSelector('text=Offline storage used', { timeout: 5_000 });
    await page.waitForSelector("text=Frieren: Beyond Journey's End", { timeout: 5_000 });

    await page.goto(`${baseUrl}/manga?agent=1`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=Action', { timeout: 10_000 });
    await collapseHud(page);
    await page.getByRole('button', { name: /Genres/ }).first().click();
    await page.waitForSelector('text=Browse all genres', { timeout: 5_000 });
    const dropdownBox = await page.getByText('Browse all genres').boundingBox();
    assert.ok(dropdownBox && dropdownBox.height > 10 && dropdownBox.y >= 0, 'Genres dropdown must portal outside header overflow');
    await page.getByText('Browse all genres').click();
    await page.waitForSelector('text=1 genres', { timeout: 5_000 }).catch(() => page.waitForSelector('text=3 genres', { timeout: 5_000 }));

    await page.getByRole('button', { name: /Currently Reading/ }).first().click();
    await page.waitForSelector('text=Mine', { timeout: 5_000 });
    await page.getByRole('button', { name: 'Clair', exact: true }).click();
    await page.getByRole('button', { name: 'Mine', exact: true }).click();

    await page.getByRole('button', { name: /Downloads/ }).first().click();
    await page.waitForSelector('text=Offline storage used', { timeout: 5_000 });
    await page.waitForSelector('text=/offline/i', { timeout: 5_000 });

    await page.locator('button:has-text("Chapter"), button:has-text("Ch.")').first().click();
    await page.waitForFunction(
      () => [...document.querySelectorAll('img')].some((img) => img.src.includes('/images/demo/') && img.complete && img.naturalWidth > 0),
      null,
      { timeout: 10_000 },
    );
    await page.getByRole('button', { name: 'Webtoon', exact: true }).click();
    await page.waitForSelector('text=1 / 3', { timeout: 5_000 });
    await page.getByRole('button', { name: 'Next Page', exact: true }).click();
    await page.waitForSelector('text=2 / 3', { timeout: 5_000 });
    await page.waitForTimeout(450);
    await page.locator('button:has-text("arrow_back")').last().click();
    await page.waitForSelector('text=Offline storage used', { timeout: 5_000 });
    await page.locator('button:has-text("Chapter"), button:has-text("Ch.")').first().click();
    await page.waitForSelector('button:has-text("Webtoon")', { timeout: 5_000 });
    await page.getByRole('button', { name: 'Webtoon', exact: true }).click();
    await page.waitForSelector('text=2 / 3', { timeout: 5_000 });

    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});

test('BookReaderPage splits chapters with TOC/TTS and direct-entry canPop back buttons stay in app', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 430, height: 932 } });
    const page = await context.newPage();
    const errors = [];
    const consoleErrors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });

    await page.route('https://us-central1-everglow-1c6db.cloudfunctions.net/proxyCatalog**', async (route) => {
      const url = new URL(route.request().url());
      if (url.searchParams.get('base') === 'archive') {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ files: [{ name: 'frankenstein.txt', format: 'Text' }] }),
        });
      } else if (url.searchParams.get('path')?.includes('works/')) {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ description: 'Classic novel.', subjects: ['Gothic'] }),
        });
      } else {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            docs: [{ key: '/works/OL1W', title: 'Frankenstein', author_name: ['Mary Shelley'], ia: ['pg84'] }],
            numFound: 1,
          }),
        });
      }
    });
    await page.route('https://everglow-1c6db.web.app/api/proxyBookText**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          usedUrl: 'https://www.gutenberg.org/files/84/84-0.txt',
          text: [
            '*** START OF THE PROJECT GUTENBERG EBOOK FRANKENSTEIN ***',
            '',
            'CHAPTER I',
            'You will rejoice to hear that no disaster has accompanied the commencement of an enterprise.',
            '',
            'CHAPTER II',
            'I am already far north of London, and as I walk in the streets of Petersburgh, I feel a cold northern breeze.',
            '',
            '*** END OF THE PROJECT GUTENBERG EBOOK FRANKENSTEIN ***',
          ].join('\n'),
        }),
      });
    });

    await page.goto(`${baseUrl}/books?agent=1`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('button[aria-label="Search"]', { timeout: 10_000 });
    await collapseHud(page);
    await page.locator('button[aria-label="Search"]').click();
    const searchInput = page.locator('input').first();
    await searchInput.waitFor({ state: 'visible', timeout: 5_000 });
    await searchInput.fill('Frankenstein');
    await searchInput.press('Enter');
    await page.waitForSelector('text=Frankenstein', { timeout: 5_000 });
    await page.getByText('Frankenstein').first().click();
    await page.waitForSelector('button:has-text("Listen")', { timeout: 5_000 });
    await page.locator('button:has-text("Read")').first().click();

    await page.waitForSelector('text=CHAPTER I', { timeout: 10_000 });
    await page.waitForSelector('text=Next →', { timeout: 5_000 });
    await page.locator('button[title="Chapters"]').click();
    await page.waitForSelector('text=CHAPTER II', { timeout: 5_000 });
    await page.getByText('CHAPTER II').first().click();
    await page.waitForSelector('text=I am already far north of London', { timeout: 5_000 });

    for (const [routePath, backSelector, expectedTarget] of [
      ['/motchi-minis?agent=1', 'button[aria-label="Back"]', '/motchi'],
      ['/desktop-app?agent=1', 'button[aria-label="Go back"]', '/dashboard'],
      ['/our-books?agent=1', 'button:has-text("arrow_back")', '/books'],
    ]) {
      const fresh = await context.newPage();
      fresh.on('pageerror', (e) => errors.push(`${routePath}: ${e.message}`));
      fresh.on('console', (msg) => {
        if (msg.type() === 'error') consoleErrors.push(`${routePath}: ${msg.text()}`);
      });
      await fresh.goto(`${baseUrl}${routePath}`, { waitUntil: 'domcontentloaded' });
      const backBtn = fresh.locator(backSelector).first();
      await backBtn.waitFor({ state: 'visible', timeout: 10_000 });
      await backBtn.click();
      await fresh.waitForFunction((p) => window.location.pathname === p, expectedTarget, { timeout: 5_000 });
      await fresh.close();
    }

    for (const demoRoute of ['/academy?agent=1', '/motchi?agent=1', '/study?agent=1']) {
      await page.goto(`${baseUrl}${demoRoute}`, { waitUntil: 'domcontentloaded' });
      await page.waitForTimeout(500);
    }

    const firebaseErrs = consoleErrors.filter((t) => /permission-denied|firebase|insufficient permissions/i.test(t));
    assert.deepEqual(firebaseErrs, [], `unexpected Firebase errors in demo mode: ${firebaseErrs.join('; ')}`);
    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});

test('Dashboard Mangacelestia shelf shows each reader’s chapter and a Finished reading row', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 430, height: 932 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));

    await page.goto(`${baseUrl}/dashboard?agent=1`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=where each of us is reading', { timeout: 10_000 });
    await page.waitForSelector('text=Khent ch 42 · Clair ch 12', { state: 'attached', timeout: 5_000 });
    await page.waitForSelector('text=finished reading', { state: 'attached', timeout: 5_000 });
    await page.waitForSelector('text=Demo Paper Moon', { state: 'attached', timeout: 5_000 });

    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});
