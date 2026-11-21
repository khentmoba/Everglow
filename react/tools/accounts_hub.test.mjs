import assert from 'node:assert/strict';
import { createReadStream, existsSync, readdirSync, statSync } from 'node:fs';
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

async function startDistServer() {
  const server = await new Promise((done) => {
    const s = createServer((req, res) => {
      const reqPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
      let file = join(DIST, reqPath);
      if (!existsSync(file) || !statSync(file).isFile()) {
        file = join(DIST, 'index.html');
      }
      res.writeHead(200, { 'Content-Type': TYPES[extname(file)] || 'application/octet-stream' });
      createReadStream(file).pipe(res);
    });
    s.listen(0, '127.0.0.1', () => done(s));
  });
  const { port } = server.address();
  return { server, base: `http://127.0.0.1:${port}` };
}

test('accounts sign-in/create validation, global chat, and watch party hub work end-to-end', async () => {
  const { server, base } = await startDistServer();
  const browser = await chromium.launch({
    executablePath: findChrome(),
    headless: true,
    args: ['--no-sandbox', '--mute-audio'],
  });
  try {
    const context = await browser.newContext({ viewport: { width: 430, height: 932 } });
    const page = await context.newPage();

    // 1. Gateway -> Account Sign In -> Create Account password mismatch check
    await page.goto(`${base}/`, { waitUntil: 'networkidle' });
    await page.getByRole('button', { name: 'Account Sign In' }).click();
    await page.getByRole('tab', { name: 'Create Account' }).click();
    await page.getByPlaceholder(/Choose a username/i).fill('mika_chan');
    await page.getByPlaceholder(/At least 6 characters/i).fill('secret123');
    await page.getByPlaceholder(/Re-enter your password/i).fill('secret999');
    await page.getByText('Passwords do not match').waitFor({ timeout: 5000 });
    const createBtn = page.getByRole('button', { name: 'Create Account' });
    assert.equal(await createBtn.isDisabled(), true);

    // 2. Global Chat works for cinema/member accounts and sends messages
    await page.goto(`${base}/global-chat?agent=breyan&hud=0`, { waitUntil: 'networkidle' });
    await page.getByText('Global Chat').first().waitFor({ timeout: 5000 });
    await page.getByText('octagram').first().waitFor({ timeout: 5000 });
    await page.getByPlaceholder('Message Global Chat…').fill('Hello from breyan!');
    await page.getByRole('button', { name: 'Send message' }).click();
    await page.getByText('Hello from breyan!').waitFor({ timeout: 5000 });

    // 3. MediaSectionMenuButton exposes all 5 sections + Global Chat
    await page.getByRole('button', { name: 'Switch section' }).click();
    for (const label of ['Cinema', 'Anime', 'Mangacelestia', 'Books', 'Watch Party', 'Global Chat']) {
      await page.getByRole('button', { name: label, exact: true }).waitFor({ timeout: 5000 });
    }

    // 4. Watch Party Hub: password-protected room rejects wrong password & unlocks with 1234
    await page.goto(`${base}/watch-party?agent=breyan&hud=0`, { waitUntil: 'networkidle' });
    await page.getByText('Friday Movie Night').waitFor({ timeout: 5000 });
    await page.getByText('Friday Movie Night').click();
    await page.getByPlaceholder('Room password').fill('wrong');
    await page.getByRole('button', { name: 'Join Room' }).click();
    await page.getByText('Incorrect room password.').waitFor({ timeout: 5000 });
    await page.getByPlaceholder('Room password').fill('1234');
    await page.getByRole('button', { name: 'Join Room' }).click();
    // Inside room: Everglow Server locked badge is shown (no third-party server switcher)
    await page.getByTitle(/locked to Everglow Server/i).waitFor({ timeout: 5000 });
    assert.equal(await page.getByRole('button', { name: 'Switch server' }).count(), 0);

    // 5. Watch Party Hub: Host a new open room
    await page.goto(`${base}/watch-party?agent=breyan&hud=0`, { waitUntil: 'networkidle' });
    await page.getByRole('button', { name: 'Host a watch party room' }).click();
    await page.getByPlaceholder(/Friday Anime Night/i).fill('Late Night Cinema');
    await page.getByRole('button', { name: 'Host Room' }).click();
    await page.getByText('Late Night Cinema').waitFor({ timeout: 5000 });
    await page.getByTitle(/locked to Everglow Server/i).waitFor({ timeout: 5000 });

    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
});
