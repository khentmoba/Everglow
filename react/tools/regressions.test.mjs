import assert from 'node:assert/strict';
import { createReadStream, existsSync, readdirSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { homedir } from 'node:os';
import { extname, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright-core';

const DIST = fileURLToPath(new URL('../dist/', import.meta.url));
const ASSETS_DATA = fileURLToPath(new URL('../../assets/data/', import.meta.url));
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
    await page.getByRole('button', { name: 'Jump to Play' }).click();
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

test('Welcome gift covers the app for Clair until Continue, and only for Clair', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 430, height: 932 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    const gift = page.getByRole('dialog', { name: 'A gift for you' });
    const proceed = page.getByRole('button', { name: 'Continue to Everglow' });

    await page.goto(`${baseUrl}/dashboard?agent=clair&gift=1`, { waitUntil: 'domcontentloaded' });
    await gift.waitFor({ state: 'visible', timeout: 10_000 });
    assert.equal(await proceed.count(), 0, 'Continue stays hidden until the letter ends');
    const readOn = page.frameLocator('iframe[title="A gift for you"]').getByRole('button', { name: 'Read on' });
    await readOn.waitFor({ state: 'visible', timeout: 10_000 });
    await page.waitForTimeout(300);
    await readOn.click();
    await proceed.waitFor({ state: 'visible', timeout: 5_000 });
    await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
    await proceed.click();
    await gift.waitFor({ state: 'detached', timeout: 5_000 });

    for (const route of ['/dashboard?agent=clair', '/dashboard?agent=khent&gift=1']) {
      const other = await context.newPage();
      await other.goto(`${baseUrl}${route}`, { waitUntil: 'domcontentloaded' });
      await other.waitForSelector('text=Quick Access', { timeout: 10_000 });
      await other.waitForTimeout(500);
      assert.equal(await other.getByRole('dialog', { name: 'A gift for you' }).count(), 0, `${route} must not show the gift`);
      await other.close();
    }

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
    // Downloads left the phone bottom bar (5 items now) for the header button.
    const downloadsButton = page.getByRole('button', { name: 'Downloads', exact: true }).first();
    await downloadsButton.waitFor({ timeout: 10_000 });
    await collapseHud(page);
    await downloadsButton.click();
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
    await page.waitForSelector('text=/\\d+ genres/', { timeout: 5_000 });

    await page.getByRole('button', { name: /Currently Reading/ }).first().click();
    await page.waitForSelector('text=Mine', { timeout: 5_000 });
    await page.getByRole('button', { name: 'Clair', exact: true }).click();
    await page.getByRole('button', { name: 'Mine', exact: true }).click();

    await page.getByRole('button', { name: /Downloads/ }).first().click();
    await page.waitForSelector('text=Downloads are using', { timeout: 5_000 });
    await page.waitForSelector('text=/offline/i', { timeout: 5_000 });

    await page.locator('button:has-text("Ready offline")').first().click();
    await page.waitForFunction(
      () => [...document.querySelectorAll('img')].some((img) => img.src.includes('/images/demo/') && img.complete && img.naturalWidth > 0),
      null,
      { timeout: 10_000 },
    );
    // Manga now opens in Auto RTL paged mode by default, so no mode switch is needed.
    await page.waitForSelector('text=1 / 3', { timeout: 5_000 });
    await page.keyboard.press('ArrowLeft');
    await page.waitForSelector('text=2 / 3', { timeout: 5_000 });
    await page.waitForTimeout(450);
    await page.getByRole('button', { name: 'Close reader' }).click();
    await page.waitForSelector('text=Downloads are using', { timeout: 5_000 });
    await page.locator('button:has-text("Ready offline")').first().click();
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
    await page.locator('button[aria-label="Reading menu"]').click();
    const chaptersMenu = page.getByRole('dialog', { name: 'Reading menu' });
    await chaptersMenu.waitFor({ state: 'visible', timeout: 5_000 });
    await chaptersMenu.getByText('CHAPTER II', { exact: true }).click();
    await page.waitForSelector('text=I am already far north of London', { timeout: 5_000 });

    // The reader reflows text into paragraphs set in the dedicated reading font.
    const bodyFont = await page.locator('article p').first().evaluate((el) => getComputedStyle(el).fontFamily);
    assert.match(bodyFont, /DM Sans/, `reader body should use the reading font, got ${bodyFont}`);

    // Reading settings live in a sheet, can be changed, and close with Escape.
    await page.locator('button[aria-label="Reading settings"]').click();
    await page.waitForSelector('[role="dialog"][aria-label="Reading settings"]', { timeout: 5_000 });
    await page.locator('button[aria-label="Increase Text size"]').click();
    const bodySize = await page.locator('article p').first().evaluate((el) => getComputedStyle(el).fontSize);
    assert.equal(bodySize, '19px', `text size should grow from 18px to 19px, got ${bodySize}`);
    await page.keyboard.press('Escape');
    await page.waitForSelector('[role="dialog"][aria-label="Reading settings"]', { state: 'detached', timeout: 5_000 });

    // Bookmarks and in-book search live in the single Reading menu.
    await page.locator('button[aria-label="Reading menu"]').click();
    const readingMenu = page.getByRole('dialog', { name: 'Reading menu' });
    await readingMenu.waitFor({ state: 'visible', timeout: 5_000 });
    await readingMenu.getByRole('button', { name: /Bookmark/ }).first().click();
    await readingMenu.getByRole('button', { name: /Bookmarked/ }).first().waitFor({ timeout: 5_000 });
    await readingMenu.getByRole('button', { name: /Search in book/ }).first().click();
    await page.waitForSelector('[role="dialog"][aria-label="Search in book"]', { timeout: 5_000 });
    await page.locator('input[aria-label="Search in book"]').fill('north');
    await page.waitForSelector('text=I am already far north of London', { timeout: 5_000 });
    await page.keyboard.press('Escape');
    await page.waitForSelector('[role="dialog"][aria-label="Search in book"]', { state: 'detached', timeout: 5_000 });

    // A book with saved progress shows a one-tap Continue reading card on Home.
    await page.goto(`${baseUrl}/books?agent=1`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=CONTINUE READING', { timeout: 10_000 });

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
    await page.getByRole('button', { name: 'Jump to Play' }).click();
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

test('Restored Flutter features: Creator Studio, Jukebox insights, TV nav, Slow-network banner, Watch Party controls', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 430, height: 932 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));

    await page.goto(`${baseUrl}/dashboard?agent=1&hud=0&network=slow`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=Slow connection', { timeout: 10_000 });
    await page.locator('button[aria-label="Open creator tools"]').click();
    await page.waitForSelector('text=Creator Studio', { timeout: 5_000 });
    for (const tabName of ['Memories', 'Surprises', 'Accounts', 'System', 'Letters']) {
      await page.getByRole('tab', { name: tabName }).click();
    }
    await page.locator('button[aria-label="Close Creator Studio"]').click();

    await page.goto(`${baseUrl}/jukebox?agent=1&hud=0`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=On This Day in Your Music', { timeout: 10_000 });
    await page.waitForSelector('text=Loved Tracks', { timeout: 5_000 });
    await page.getByRole('button', { name: 'Feb 14' }).click();
    await page.waitForSelector('text=Anniversary Soundtrack', { timeout: 5_000 });

    await page.goto(`${baseUrl}/cinema?agent=1&hud=0&tv=1`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('nav[aria-label="TV Media Navigation"]', { timeout: 10_000 });
    await page.waitForSelector('text=MangaCelestia', { timeout: 5_000 });

    await page.goto(`${baseUrl}/watch-party?agent=1&hud=0`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=Host a Watch Party', { timeout: 10_000 });
    await page.getByRole('tab', { name: 'Just Us Rooms' }).click();
    await page.waitForSelector('text=Create a room', { timeout: 10_000 });
    const firstRoom = page.locator('button:has-text("LIVE"), button:has-text("IDLE")').first();
    if (await firstRoom.isVisible().catch(() => false)) {
      await firstRoom.click();
      await page.waitForSelector('[title*="Everglow Server"]', { timeout: 8_000 });
    }

    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});

test('Stale Flutter session stays on Gateway instead of broken Cinema, and Cinema exit button respects safe-area inset', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 430, height: 932 } });
    await context.addInitScript(() => {
      localStorage.setItem('flutter.current_user_name', JSON.stringify('khentsgdz'));
      localStorage.setItem('flutter.route_memory:last_location', JSON.stringify('/cinema'));
    });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));

    await page.goto(`${baseUrl}/`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=TV Mode', { timeout: 10_000 });
    assert.equal(new URL(page.url()).pathname, '/', 'stale localStorage session must stay on Gateway');
    assert.ok(!(await page.locator('text=The catalogue could not load.').isVisible().catch(() => false)));

    await page.goto(`${baseUrl}/cinema`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=TV Mode', { timeout: 10_000 });
    const bounced = new URL(page.url());
    assert.equal(bounced.pathname, '/', 'direct /cinema visit without Firebase session must redirect to Gateway');
    assert.equal(bounced.searchParams.get('from'), '/cinema');

    await page.goto(`${baseUrl}/cinema?agent=1&hud=0`, { waitUntil: 'domcontentloaded' });
    const backBtn = page.locator('button[aria-label="Back"]');
    await backBtn.waitFor({ state: 'visible', timeout: 10_000 });
    const parentStyle = await backBtn.evaluate((el) => el.parentElement?.getAttribute('style') ?? '');
    assert.ok(parentStyle.includes('safe-area-inset-top'), `expected safe-area-inset-top on Cinema mobile back button, got: ${parentStyle}`);
    await backBtn.click();
    await page.waitForURL('**/dashboard*', { timeout: 10_000 });

    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});

test('Mobile polish: Dashboard Quick Access 8+More, Cinema tab URL/Back sync, and zoomable viewport', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 430, height: 932 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));

    await page.goto(`${baseUrl}/dashboard?agent=1&hud=0`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=Quick Access', { timeout: 10_000 });

    const viewportContent = await page.locator('meta[name="viewport"]').getAttribute('content');
    assert.ok(viewportContent && !/user-scalable\s*=\s*no/i.test(viewportContent) && !/maximum-scale\s*=\s*1(\.0)?/i.test(viewportContent),
      `viewport should allow mobile zoom, got: ${viewportContent}`);

    await page.waitForSelector('button[aria-label="Cinema"]', { timeout: 5_000 });
    assert.equal(await page.locator('button[aria-label="Desktop App"]').count(), 0);
    await page.getByRole('button', { name: /More spaces \(7\)/ }).click();
    await page.waitForSelector('button[aria-label="Desktop App"]', { timeout: 5_000 });
    await page.getByRole('button', { name: 'Show less' }).click();
    assert.equal(await page.locator('button[aria-label="Desktop App"]').count(), 0);

    await page.goto(`${baseUrl}/cinema?agent=1&hud=0`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('button:has-text("Search")', { timeout: 10_000 });
    await page.locator('button:has-text("Search")').first().click();
    await page.waitForFunction(() => new URL(location.href).searchParams.get('tab') === '1', null, { timeout: 5_000 });
    await page.goBack();
    await page.waitForFunction(() => location.pathname === '/cinema' && !new URL(location.href).searchParams.has('tab'), null, { timeout: 5_000 });

    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});

test('AI conversation memory is erased on logout, including the visible assistant transcript', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 430, height: 932 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.route(/proxyaiv2-6pr4gqobxa-uc\.a\.run\.app/, (route) =>
      route.fulfill({
        status: 200,
        contentType: 'text/event-stream',
        body: 'data: {"content":"PRIVATECHATMARKER"}\n\n',
      }),
    );

    await page.goto(`${baseUrl}/motchi?agent=1&hud=0`, { waitUntil: 'domcontentloaded' });
    const input = page.getByPlaceholder('Message Motchi…');
    await input.waitFor({ timeout: 10_000 });
    await input.fill('Remember this private test message.');
    const proxyResponse = page.waitForResponse(
      (response) => response.url().includes('proxyaiv2-6pr4gqobxa-uc.a.run.app'),
      { timeout: 10_000 },
    );
    await page.getByRole('button', { name: 'Send message' }).click();
    await proxyResponse;
    try {
      await page.getByText('PRIVATECHATMARKER', { exact: true }).waitFor({ timeout: 10_000 });
    } catch (error) {
      throw new Error(`Mock reply did not render. Proxy status: ${(await proxyResponse).status()}. Body: ${(await page.locator('body').innerText()).slice(-1200)}; page errors: ${errors.join('; ')}`, { cause: error });
    }

    await page.evaluate(() => window.dispatchEvent(new Event('everglow:logout')));
    await page.getByText('PRIVATECHATMARKER', { exact: true }).waitFor({ state: 'detached', timeout: 5_000 });
    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});

test('Journal search waits for typing to settle before it scans', async () => {
  const { server, baseUrl } = await startDistServer();
  const browser = await chromium.launch({ headless: true, executablePath: findChrome(), args: ['--mute-audio'] });
  try {
    const context = await browser.newContext({ viewport: { width: 430, height: 932 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));

    await page.goto(`${baseUrl}/journal?agent=1&hud=0`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('text=The Magic of Ordinary Days', { timeout: 10_000 });

    const input = page.getByPlaceholder('Search memories, tags, dreams...');
    await input.click();
    await page.keyboard.type('coffee');

    // A scan per keystroke would already have painted the match here.
    await page.waitForTimeout(140);
    assert.equal(
      await page.getByText('The Magic of Ordinary Days').count(),
      0,
      'search ran before the typing settled',
    );

    await page.waitForSelector('text=The Magic of Ordinary Days', { timeout: 3_000 });

    await input.fill('zzzznomatch');
    await page.waitForSelector('text=No matching entries', { timeout: 3_000 });

    assert.deepEqual(errors, [], `unexpected page errors: ${errors.join('; ')}`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});
