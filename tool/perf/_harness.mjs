// Shared plumbing for the headless perf tools.
//
// Extracted because `measure_boot.mjs` and `bench.mjs` each grew their own
// Chrome launcher, and each hardcoded the author's Linux path
// (`/usr/local/bin/google-chrome`) — so neither ran on Windows. One copy, fixed
// once.
//
// Everything here is measurement scaffolding, not app code.
import { spawn, spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, rmSync } from 'node:fs';
import { extname, join } from 'node:path';
import { tmpdir } from 'node:os';

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export const median = (xs) => {
  if (!xs.length) return 0;
  const s = [...xs].sort((a, b) => a - b);
  const m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

export const r2 = (n) => Math.round(n * 100) / 100;

export const sha1 = (s) => createHash('sha1').update(s).digest('hex');

// Locate Chrome/Chromium per platform instead of assuming one OS.
export function chromePath() {
  const candidates = [
    process.env.CHROME_PATH,
    'C:/Program Files/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/usr/local/bin/google-chrome',
    '/usr/bin/google-chrome',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
  ].filter(Boolean);
  for (const c of candidates) if (existsSync(c)) return c;
  throw new Error(
    'No Chrome found. Set CHROME_PATH to a Chrome/Chromium binary.\n' +
      `Tried:\n  ${candidates.join('\n  ')}`,
  );
}

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.mp3': 'audio/mpeg',
  '.mp4': 'video/mp4',
  '.bin': 'application/octet-stream',
  '.symbols': 'text/plain',
};

/// Minimal static server, no deps. Flutter web is a SPA, so unknown paths fall
/// back to index.html. MIME matters: CanvasKit refuses to stream-compile with a
// text/plain wasm.
/// Minimal static server, no deps. Flutter web is a SPA, so unknown paths fall
/// back to index.html. MIME matters: CanvasKit refuses to stream-compile with a
/// text/plain wasm.
///
/// `kbps` shapes the link in the *server*, and is in **kilobits per second**,
/// matching Chrome DevTools' own presets (so "slow3g" is 400 kbps = 50KB/s).
/// Deliberate, because `Network.emulateNetworkConditions` is silently ignored
/// by headless Chrome: asked for 400KB/s it delivered 6.77MB in 67ms (~98MB/s),
/// so a "throttled" boot measured with it was measuring an unthrottled
/// download while reporting it as slow3g. Shaping at the source makes the
/// number reproducible and independent of the browser.
export function serve(root, port, { kbps = 0, noStore = true } = {}) {
  let bytesPerSec = (kbps * 1024) / 8;
  const server = createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    let file = join(root, url);
    if (!existsSync(file) || url.endsWith('/')) file = join(root, 'index.html');
    let body;
    try {
      body = readFileSync(file);
    } catch {
      res.writeHead(404).end('not found');
      return;
    }
    res.writeHead(200, {
      'Content-Type': MIME[extname(file).toLowerCase()] || 'application/octet-stream',
      'Content-Length': body.length,
      // Never let a proxy or the SW cache answer a measurement run.
      ...(noStore ? { 'Cache-Control': 'no-store' } : {}),
    });

    if (!bytesPerSec) {
      res.end(body);
      return;
    }
    // ~16KB chunks paced to the target rate.
    const chunk = 16 * 1024;
    let offset = 0;
    const started = Date.now();
    const pump = () => {
      if (offset >= body.length) {
        res.end();
        return;
      }
      const end = Math.min(offset + chunk, body.length);
      const slice = body.subarray(offset, end);
      offset = end;
      res.write(slice);
      const shouldHaveTakenMs = (offset / bytesPerSec) * 1000;
      const delay = Math.max(0, shouldHaveTakenMs - (Date.now() - started));
      setTimeout(pump, delay);
    };
    pump();
  });
  server.listen(port, '127.0.0.1', () => {});
  // Reshape the link at runtime. Needed for the repeat-visit case: the service
  // worker's own precache is ~13MB, so warming it on a 400kbit link takes
  // minutes and would still be downloading when the measured leg starts. Warm
  // up unshaped, then shape only the navigation being measured.
  server.setKbps = (n) => {
    bytesPerSec = (n * 1024) / 8;
  };
  return new Promise((ok) => server.on('listening', () => ok(server)));
}

// Windows keeps Chrome's profile files locked briefly after exit, so a hard rm
// can fail a run whose measurement already succeeded. Best-effort: leaving a
// temp dir behind is harmless, failing the run is not.
function sleepSync(ms) {
  const end = Date.now() + ms;
  while (Date.now() < end) {}
}

export function cleanup(dir) {
  for (let i = 0; i < 5; i++) {
    try {
      rmSync(dir, { recursive: true, force: true });
      return;
    } catch {
      spawnSync('cmd', ['/c', 'rmdir', '/s', '/q', dir], { stdio: 'ignore' });
      sleepSync(300);
    }
  }
}

export class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.pending = new Map();
    this.id = 1;
    ws.onmessage = (e) => {
      const m = JSON.parse(e.data);
      if (m.id && this.pending.has(m.id)) {
        this.pending.get(m.id)(m);
        this.pending.delete(m.id);
      }
    };
  }

  send(method, params = {}) {
    return new Promise((res) => {
      const cur = this.id++;
      this.pending.set(cur, res);
      this.ws.send(JSON.stringify({ id: cur, method, params }));
    });
  }

  // CDP nests evaluate results: {result:{result:{type,value}}}. Reading
  // `.result.value` silently yields undefined and makes a working mirror look
  // dead — which is how an earlier version of this rig had its numbers read off
  // screenshots by hand.
  async eval(expression) {
    const r = await this.send('Runtime.evaluate', {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    return r?.result?.result?.value;
  }
}

/**
 * Launches a throwaway headless Chrome and returns `{proc, cdp, userDataDir}`.
 *
 * The fresh `--user-data-dir` is not optional: the app ships a cache-first
 * service worker, and a cached shell would otherwise be measured instead of the
 * build under test. It also guarantees a genuine cold boot for measure_boot.
 */
export async function launch(cdpPort, opts = {}) {
  const { dpr = 3, width = 430, height = 932, extraFlags = [] } = opts;
  const userDataDir = join(tmpdir(), `eg-perf-${process.pid}-${cdpPort}`);
  rmSync(userDataDir, { recursive: true, force: true });
  const proc = spawn(
    chromePath(),
    [
      '--headless=new',
      `--remote-debugging-port=${cdpPort}`,
      `--user-data-dir=${userDataDir}`,
      '--no-sandbox',
      '--no-first-run',
      '--disable-extensions',
      '--disable-background-networking',
      // WebGL backend may be a real GPU (ANGLE/D3D11/Metal) or a software
      // fallback. Which one it is decides how raster may be read, so it is
      // detected per run rather than assumed.
      '--enable-unsafe-swiftshader',
      '--hide-scrollbars',
      // Headless Chrome backgrounds a page it thinks nobody is looking at,
      // which throttles rAF to a crawl and makes every frame metric read zero.
      // Deliberately NOT disabling the frame-rate limit: an uncapped renderer
      // has no dynamic range in its FPS/jank columns.
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-renderer-backgrounding',
      `--window-size=${Math.round(width * dpr)},${Math.round(height * dpr)}`,
      ...extraFlags,
      'about:blank',
    ],
    { stdio: 'ignore' },
  );

  for (let i = 0; i < 40; i++) {
    await sleep(250);
    try {
      const list = await (await fetch(`http://127.0.0.1:${cdpPort}/json/list`)).json();
      const page = list.find((p) => p.type === 'page');
      if (page) {
        const ws = new WebSocket(page.webSocketDebuggerUrl);
        await new Promise((ok, bad) => {
          ws.onopen = ok;
          ws.onerror = () => bad(new Error('devtools websocket refused'));
        });
        return { proc, cdp: new Cdp(ws), userDataDir };
      }
    } catch {
      /* not up yet */
    }
  }
  proc.kill();
  throw new Error('Chrome did not expose a debuggable page');
}

/// Enable the domains every perf run needs, plus the anti-throttling calls
/// that keep rAF live in a headless page.
export async function prepare(cdp, { dpr = 3, width = 430, height = 932 } = {}) {
  await cdp.send('Page.enable');
  await cdp.send('Runtime.enable');
  await cdp.send('Performance.enable');
  await cdp.send('Page.setWebLifecycleState', { state: 'active' }).catch(() => {});
  await cdp.send('Emulation.setFocusEmulationEnabled', { enabled: true }).catch(() => {});
  await cdp.send('Emulation.setDeviceMetricsOverride', {
    width,
    height,
    deviceScaleFactor: dpr,
    mobile: true,
  });
}

/// Collect long main-thread tasks in the page. A frame average can sit at 12ms
/// while one 400ms block hides inside it — that block is the freeze the goal
/// cares about, and average frame cost will never show it.
export const LONG_TASK_OBSERVER = `
  window.__egLongTasks = [];
  try {
    new PerformanceObserver((list) => {
      for (const e of list.getEntries()) {
        window.__egLongTasks.push({ dur: e.duration, start: e.startTime });
      }
    }).observe({ entryTypes: ['longtask'] });
  } catch (e) { window.__egLongTaskError = String(e); }
  true;
`;