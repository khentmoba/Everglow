// Dependency-free Chrome/CDP plumbing. Every launch owns a unique temp profile.
import { spawn, spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { existsSync, readFileSync, rmSync, mkdtempSync } from 'node:fs';
import { extname, join, resolve, sep } from 'node:path';
import { tmpdir } from 'node:os';
import { gzipSync } from 'node:zlib';

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
export const median = (xs) => {
  if (!xs.length || xs.some((n) => !Number.isFinite(n))) throw new Error('missing median samples');
  const s = [...xs].sort((a, b) => a - b);
  const m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};
export const r2 = (n) => Math.round(n * 100) / 100;

export function chromePath() {
  const candidates = [
    process.env.CHROME_PATH,
    'C:/Program Files/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/usr/local/bin/google-chrome', '/usr/bin/google-chrome',
    '/usr/bin/chromium', '/usr/bin/chromium-browser',
  ].filter(Boolean);
  for (const c of candidates) if (existsSync(c)) return c;
  throw new Error('No Chrome found. Set CHROME_PATH. Tried: ' + candidates.join(', '));
}

const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8', '.json': 'application/json',
  '.wasm': 'application/wasm', '.css': 'text/css', '.svg': 'image/svg+xml',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
  '.webp': 'image/webp', '.ttf': 'font/ttf', '.otf': 'font/otf',
  '.woff': 'font/woff', '.woff2': 'font/woff2', '.mp3': 'audio/mpeg',
  '.mp4': 'video/mp4',
};

// Compression approximates hosting, not its CDN. Network shaping belongs to
// Chrome's shared link, never an independent timer/bandwidth budget per response.
export async function serve(root, port, { noStore = true } = {}) {
  root = resolve(root);
  const server = createServer((req, res) => {
    let path;
    try { path = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); }
    catch { res.writeHead(400).end('bad URL'); return; }
    let file = resolve(root, '.' + path);
    if (file !== root && !file.startsWith(root + sep)) {
      res.writeHead(403).end('forbidden'); return;
    }
    if (path.endsWith('/') || (!existsSync(file) && !extname(path))) file = join(root, 'index.html');
    let body;
    try { body = readFileSync(file); }
    catch { res.writeHead(404).end('not found'); return; }
    const type = MIME[extname(file)] || 'application/octet-stream';
    const compressed = /gzip/.test(req.headers['accept-encoding'] || '') &&
      /text|javascript|json|wasm|svg/.test(type);
    if (compressed) body = gzipSync(body);
    res.writeHead(200, {
      'Content-Type': type, 'Content-Length': body.length, 'Vary': 'Accept-Encoding',
      'Cache-Control': noStore ? 'no-store' : 'public, max-age=3600',
      ...(compressed ? { 'Content-Encoding': 'gzip' } : {}),
    });
    res.end(req.method === 'HEAD' ? undefined : body);
  });
  await new Promise((ok, bad) => {
    server.once('error', bad);
    server.listen(port, '127.0.0.1', ok);
  });
  return server;
}

const ownedProfiles = new Set();
export function cleanup(dir) {
  if (!ownedProfiles.has(dir)) throw new Error('Refusing to remove a profile not created by this harness');
  try {
    rmSync(dir, { recursive: true, force: true, maxRetries: 5, retryDelay: 300 });
    ownedProfiles.delete(dir);
  } catch (e) { console.warn(`[perf] disposable profile left at ${dir}: ${e.message}`); }
}

export class Cdp {
  constructor(ws, { timeoutMs = 15000 } = {}) {
    this.ws = ws;
    this.timeoutMs = timeoutMs;
    this.pending = new Map();
    this.id = 1;
    this.closed = false;
    ws.onmessage = (e) => {
      let m;
      try { m = JSON.parse(e.data); }
      catch { this.fail(new Error('invalid CDP JSON')); return; }
      const p = this.pending.get(m.id);
      if (!p) return;
      this.pending.delete(m.id);
      clearTimeout(p.timer);
      if (m.error) p.reject(new Error(`${p.method}: CDP ${m.error.code}: ${m.error.message}`));
      else if (!('result' in m)) p.reject(new Error(`${p.method}: missing CDP protocol result`));
      else p.resolve(m);
    };
    ws.onclose = () => this.fail(new Error('CDP socket closed'));
    ws.onerror = () => this.fail(new Error('CDP socket error'));
  }
  fail(error) {
    this.closed = true;
    for (const p of this.pending.values()) { clearTimeout(p.timer); p.reject(error); }
    this.pending.clear();
  }
  send(method, params = {}, { sessionId, timeoutMs = this.timeoutMs } = {}) {
    if (this.closed) return Promise.reject(new Error(`${method}: CDP socket closed`));
    return new Promise((resolve, reject) => {
      const id = this.id++;
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`${method}: CDP timeout after ${timeoutMs}ms`));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer, method });
      try { this.ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) })); }
      catch (e) { clearTimeout(timer); this.pending.delete(id); reject(e); }
    });
  }
  async eval(expression, options = {}) {
    const r = await this.send('Runtime.evaluate', {
      expression, returnByValue: true, awaitPromise: true,
    }, options);
    if (r.result?.exceptionDetails) {
      const e = r.result.exceptionDetails;
      throw new Error(`Runtime.evaluate: ${e.exception?.description || e.text}`);
    }
    if (!r.result?.result) throw new Error('Runtime.evaluate: missing protocol result');
    return r.result.result.value;
  }
  close() { this.fail(new Error('CDP closed by harness')); this.ws.close(); }
}

export async function launch(cdpPort = 0, opts = {}) {
  const { dpr = 3, width = 430, height = 932, extraFlags = [] } = opts;
  const binary = chromePath();
  const userDataDir = mkdtempSync(join(tmpdir(), 'eg-perf-'));
  ownedProfiles.add(userDataDir);
  const proc = spawn(binary, [
    '--headless=new', `--remote-debugging-port=${cdpPort}`, `--user-data-dir=${userDataDir}`,
    '--no-sandbox', '--no-first-run', '--disable-extensions', '--disable-background-networking',
    '--enable-unsafe-swiftshader', '--hide-scrollbars',
    '--disable-background-timer-throttling', '--disable-backgrounding-occluded-windows',
    '--disable-renderer-backgrounding',
    `--window-size=${Math.round(width * dpr)},${Math.round(height * dpr)}`,
    ...extraFlags, 'about:blank',
  ], { stdio: ['ignore', 'ignore', 'pipe'] });
  let spawnError, browserSocket;
  proc.on('error', (e) => { spawnError = e; });
  let stderr = '';
  proc.stderr.on('data', (s) => {
    stderr = (stderr + s).slice(-4096);
    browserSocket ||= stderr.match(/DevTools listening on (ws:\/\/[^\s]+)/)?.[1];
  });
  try {
    const deadline = Date.now() + 10000;
    while (Date.now() < deadline) {
      if (spawnError) throw spawnError;
      if (proc.exitCode != null) throw new Error(`Chrome exited ${proc.exitCode}`);
      let page;
      try {
        // Only connect to the endpoint printed by OUR process. A fixed port
        // might already belong to somebody else's browser; never close it.
        if (!browserSocket) throw new Error('Chrome is still starting');
        const port = Number(new URL(browserSocket).port);
        const version = await (await fetch(`http://127.0.0.1:${port}/json/version`, {
          signal: AbortSignal.timeout(1000),
        })).json();
        if (version.webSocketDebuggerUrl !== browserSocket) throw new Error('CDP endpoint belongs to another browser');
        const list = await (await fetch(`http://127.0.0.1:${port}/json/list`, {
          signal: AbortSignal.timeout(1000),
        })).json();
        page = list.find((p) => p.type === 'page');
      } catch { /* Chrome is still starting. */ }
      if (page) {
        const ws = new WebSocket(page.webSocketDebuggerUrl);
        await new Promise((ok, bad) => {
          const timer = setTimeout(() => { ws.close(); bad(new Error('CDP connect timeout')); }, 3000);
          ws.onopen = () => { clearTimeout(timer); ok(); };
          ws.onerror = () => { clearTimeout(timer); bad(new Error('CDP connect refused')); };
        });
        return { proc, cdp: new Cdp(ws), userDataDir };
      }
      await sleep(100);
    }
    throw new Error('Chrome did not expose a debuggable page');
  } catch (e) { await stop({ proc, userDataDir }); throw e; }
}

export async function stop(chrome) {
  try { await chrome.cdp?.send('Browser.close', {}, { timeoutMs: 2000 }); } catch { /* already exited */ }
  chrome.cdp?.close();
  if (chrome.proc.exitCode == null && chrome.proc.signalCode == null) {
    await Promise.race([new Promise((r) => chrome.proc.once('exit', r)), sleep(1500)]);
    if (chrome.proc.exitCode == null && chrome.proc.signalCode == null) chrome.proc.kill();
  }
  cleanup(chrome.userDataDir);
}

export async function prepare(cdp, { dpr = 3, width = 430, height = 932 } = {}) {
  await cdp.send('Page.enable');
  await cdp.send('Runtime.enable');
  await cdp.send('Performance.enable');
  await cdp.send('Page.setWebLifecycleState', { state: 'active' });
  await cdp.send('Emulation.setFocusEmulationEnabled', { enabled: true });
  await cdp.send('Emulation.setDeviceMetricsOverride', {
    width, height, deviceScaleFactor: dpr, mobile: true,
  });
}

// Explicit synthetic link presets, not measured/calibrated phone connections.
// Kbps means decimal kilobits/second; CDP wants bytes/second. Latency is CDP's
// minimum request-to-response-header delay, not a server sleep per chunk.
export const NETWORK_PROFILES = {
  none: { latencyMs: 0, downloadKbps: 0, uploadKbps: 0 },
  fast3g: { latencyMs: 150, downloadKbps: 1600, uploadKbps: 750 },
  slow3g: { latencyMs: 400, downloadKbps: 400, uploadKbps: 400 },
};
export async function shapeNetwork(cdp, profile, sessionId) {
  const settings = NETWORK_PROFILES[profile];
  if (!settings) throw new Error(`unknown network profile: ${profile}`);
  await cdp.send('Network.enable', {}, { sessionId });
  await cdp.send('Network.emulateNetworkConditions', {
    offline: false, latency: settings.latencyMs,
    downloadThroughput: settings.downloadKbps ? settings.downloadKbps * 1000 / 8 : -1,
    uploadThroughput: settings.uploadKbps ? settings.uploadKbps * 1000 / 8 : -1,
  }, { sessionId });
  return settings;
}

export const LONG_TASK_OBSERVER = `
  (() => {
    const state = window.__egLongTaskState = {
      timeOrigin: performance.timeOrigin, supported: false, error: null
    };
    window.__egLongTasks = [];
    try {
      if (!PerformanceObserver.supportedEntryTypes.includes('longtask')) {
        throw new Error('longtask observer unsupported');
      }
      const collect = (entries) => {
        for (const e of entries) window.__egLongTasks.push({dur: e.duration, start: e.startTime});
      };
      const observer = new PerformanceObserver((list) => collect(list.getEntries()));
      observer.observe({type: 'longtask', buffered: true});
      window.__egFlushLongTasks = () => collect(observer.takeRecords());
      state.supported = true;
    } catch (e) { state.error = String(e); }
  })();
`;
export async function readLongTasks(cdp) {
  return cdp.eval(`(() => {
    const s = window.__egLongTaskState;
    if (!s || !s.supported || s.error || s.timeOrigin !== performance.timeOrigin ||
        !Array.isArray(window.__egLongTasks) || typeof window.__egFlushLongTasks !== 'function') {
      throw new Error('long-task instrumentation missing/unsupported: ' + (s?.error || 'missing observer'));
    }
    window.__egFlushLongTasks();
    const t = window.__egLongTasks;
    if (t.some(x => !Number.isFinite(x.dur) || !Number.isFinite(x.start))) throw new Error('invalid long-task sample');
    return {count: t.length, worstMs: t.reduce((n,x) => Math.max(n,x.dur),0),
      totalMs: t.reduce((n,x) => n+x.dur,0), overBar: t.filter(x => x.dur > 200).length};
  })()`);
}

export function buildWeb(bench = false) {
  for (const args of [
    ['tool/generate_sw.dart'],
    ['tool/build_web.dart', '--', '--release', '--no-source-maps',
      ...(bench ? ['--dart-define=EG_PERF_BENCH=true'] : [])],
  ]) {
    const r = spawnSync('dart', args, { stdio: 'inherit', shell: true });
    if (r.status !== 0) throw new Error('production build wrapper failed; supply a stamped artifact with --web-root');
  }
}
