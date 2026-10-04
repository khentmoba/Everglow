// Headless perf bench for the Everglow web app.
//
// Measures the real frame meter in a real browser: drives a deterministic
// scene over CDP at a phone viewport, reads the numbers the app itself
// publishes, and writes a before/after table to docs/perf-baseline.md.
//
//   node tool/perf/bench.mjs --build            # build + serve + measure
//   node tool/perf/bench.mjs                    # measure an existing build
//   node tool/perf/bench.mjs --runs 5 --throttle 4
//
// ## What this can and cannot prove
//
// CAN: build/raster cost of the shared render layer, jank and dropped-frame
// share, worst single frame, long main-thread tasks, and — because the scene
// is fixed — a trustworthy A/B between two builds. This is the regression net.
//
// CANNOT: the goal's ">= 55 FPS on Clair's iPhone" bar. This box has a
// discrete desktop GPU where a phone has a small power-budgeted one, so paint
// cost here is not phone-representative; and headless has no steady virtual
// vsync, so observed FPS wanders on a healthy build. The recorded renderer
// line in the output says exactly what painted the pixels. Treat raster as a
// build-to-build signal, and let the on-phone frame meter
// (`?perf=1`, Creator Studio -> System) carry the device verdict. See
// docs/perf-baseline.md.
//
// ## Hygiene
//
// Each run gets a throwaway --user-data-dir, because the app ships a
// cache-first service worker and a cached shell would otherwise be measured
// instead of the build under test. The SW is also explicitly unregistered.
//
// Usage: node tool/perf/bench.mjs [--build] [--runs N] [--throttle N]
//                                 [--dpr N] [--scene NAME] [--shot DIR]
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createServer } from 'node:http';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { extname, join, resolve } from 'node:path';
import { tmpdir } from 'node:os';

// ── args ────────────────────────────────────────────────────────────────────
const argv = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = argv.indexOf(name);
  return i > -1 ? argv[i + 1] : fallback;
};
const has = (name) => argv.includes(name);

const RUNS = Number(flag('--runs', 3));
// 4x CPU throttle is the default and is the whole reason the bench has any
// sensitivity: unthrottled on a desktop GPU this content costs ~0.6ms build
// and ~0.7ms raster, so real inefficiencies are invisible. Throttling puts the
// rig in the same CPU ballpark as a phone, which is the device the goal is
// about. (This is also the method docs/PERF_NOTES.md already prescribes.)
const THROTTLE = Number(flag('--throttle', 4));
const DPR = Number(flag('--dpr', 3));
const SCENES = (flag('--scene', 'shelves,grid')).split(',').filter(Boolean);
const SHOT_DIR = flag('--shot', null);
const PORT = Number(flag('--port', 8946));
const CDP_PORT = Number(process.env.CDP_PORT || 9251);
const SETTLE_MS = Number(process.env.SETTLE_MS || 9000);
const OUT = flag('--out', 'docs/perf-baseline.md');
const WEB_ROOT = resolve('build/web');
const BAR = { fps: 55, jankPct: 5, droppedPct: 0, blockMs: 200 };

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const median = (xs) => {
  if (!xs.length) return 0;
  const s = [...xs].sort((a, b) => a - b);
  const m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};
const r2 = (n) => Math.round(n * 100) / 100;

// ── chrome ──────────────────────────────────────────────────────────────────
// The deleted harness hardcoded /usr/local/bin/google-chrome, so it only ran on
// the author's Linux box. Detect per platform instead.
function chromePath() {
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

// ── static server ───────────────────────────────────────────────────────────
// Minimal, no deps: Flutter web is a SPA, so unknown paths fall back to
// index.html. MIME matters — CanvasKit refuses to stream-compile with a
// text/plain wasm.
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

function serve(root, port) {
  const server = createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    let file = join(root, url);
    if (!existsSync(file) || url.endsWith('/')) file = join(root, 'index.html');
    try {
      const body = readFileSync(file);
      res.writeHead(200, {
        'Content-Type': MIME[extname(file).toLowerCase()] || 'application/octet-stream',
        // Never let a proxy or the SW cache answer a measurement run.
        'Cache-Control': 'no-store',
      });
      res.end(body);
    } catch {
      res.writeHead(404).end('not found');
    }
  });
  return new Promise((ok) => server.listen(port, '127.0.0.1', () => ok(server)));
}

// ── CDP ─────────────────────────────────────────────────────────────────────
class Cdp {
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
  // dead — which is how an earlier version of this script had its numbers
  // read off screenshots by hand.
  async eval(expression) {
    const r = await this.send('Runtime.evaluate', {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    return r?.result?.result?.value;
  }
}

async function launch(cdpPort) {
  const userDataDir = join(tmpdir(), `eg-bench-${process.pid}-${cdpPort}`);
  rmSync(userDataDir, { recursive: true, force: true });
  const bin = chromePath();
  const proc = spawn(
    bin,
    [
      '--headless=new',
      `--remote-debugging-port=${cdpPort}`,
      `--user-data-dir=${userDataDir}`,
      '--no-sandbox',
      '--no-first-run',
      '--disable-extensions',
      '--disable-background-networking',
      // WebGL backend: this may be a real GPU (ANGLE/D3D11/Metal) or a
      // software fallback. Which one it is decides how the raster column may
      // be read, so it is detected per run rather than assumed.
      '--enable-unsafe-swiftshader',
      '--hide-scrollbars',
      // Headless Chrome backgrounds a page it thinks nobody is looking at,
      // which throttles requestAnimationFrame to a crawl and makes every
      // frame metric read as zero. These keep it live and painting.
      //
      // Deliberately NOT disabling the frame-rate limit: an uncapped renderer
      // runs at ~85fps here, so FPS never drops and jank is always 0%, which
      // leaves the regression net with no dynamic range. Keeping vsync means
      // FPS and jank mean what the goal's bar says they mean.
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-renderer-backgrounding',
      `--window-size=${Math.round(430 * DPR)},${Math.round(932 * DPR)}`,
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
          ws.onerror = bad;
        });
        return { proc, cdp: new Cdp(ws), userDataDir, bin };
      }
    } catch {
      /* not up yet */
    }
  }
  proc.kill();
  throw new Error('Chrome did not expose a debuggable page');
}

// ── measurement ─────────────────────────────────────────────────────────────
// Long tasks are the "no freeze" half of the bar: a frame can average 12ms and
// still hide one 400ms block that Clair feels as a stutter.
const OBSERVER = `
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

const CLEAR_TASKS = 'window.__egLongTasks = []; true;';
const READ_TASKS = `
  (() => {
    const t = window.__egLongTasks || [];
    const dur = t.map((x) => x.dur);
    return JSON.stringify({
      count: t.length,
      worstMs: dur.length ? Math.max(...dur) : 0,
      overBar: dur.filter((d) => d > ${BAR.blockMs}).length,
      over100: dur.filter((d) => d > 100).length,
    });
  })()
`;

async function readMirror(cdp) {
  const raw = await cdp.eval('JSON.stringify(window.__everglowPerf || null)');
  if (!raw || raw === 'null') return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

async function waitForMirror(cdp, timeoutMs = 25000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await readMirror(cdp)) return true;
    await sleep(500);
  }
  return false;
}

// One window of measurement: reset the meter's rolling window, run `act`,
// then read. Idle and scroll are measured separately on purpose — #440's win
// is specifically "ambient tickers stop competing with a scroll", so a single
// combined number would hide both effects.
async function measure(cdp, { act, label, shot }) {
  await cdp.eval(OBSERVER);
  await cdp.eval('window.__everglowResetPerf ? (window.__everglowResetPerf(), true) : false');
  await cdp.eval(CLEAR_TASKS);
  await sleep(700); // let the reset frame and the observer settle out of the window

  await act();

  const perf = await readMirror(cdp);
  const tasks = JSON.parse((await cdp.eval(READ_TASKS)) || '{}');
  const metrics = await cdp.send('Performance.getMetrics');
  const heapMb =
    (metrics?.result?.metrics?.find((m) => m.name === 'JSHeapUsedSize')?.value || 0) /
    1048576;

  if (shot) {
    const s = await cdp.send('Page.captureScreenshot', { format: 'png' });
    mkdirSync(shot.replace(/\/[^/]+$/, ''), { recursive: true });
    writeFileSync(shot, Buffer.from(s.result.data, 'base64'));
  }

  return {
    phase: label,
    fps: perf ? perf.fps : 0,
    jankPct: perf ? perf.jankPercent : 0,
    droppedPct: perf ? perf.droppedPercent : 0,
    avgBuildMs: perf ? perf.buildAvgMs : 0,
    worstBuildMs: perf ? perf.buildWorstMs : 0,
    avgRasterMs: perf ? perf.rasterAvgMs : 0,
    worstRasterMs: perf ? perf.rasterWorstMs : 0,
    worstTotalMs: perf ? perf.worstFrameMs : 0,
    frames: perf ? perf.frames : 0,
    devicePixelRatio: perf ? perf.devicePixelRatio : 0,
    longTaskWorstMs: tasks.worstMs || 0,
    longTaskCount: tasks.count || 0,
    longTaskOverBar: tasks.overBar || 0,
    heapMb: r2(heapMb),
  };
}

// A 10s scripted scroll: down the page in phone-sized flicks, then back up,
// which is exactly the gesture that used to stutter.
function scrollPass() {
  return async () => {
    for (let i = 0; i < 10; i++) {
      await scrollOnce(-190);
      await sleep(180);
    }
    for (let i = 0; i < 6; i++) {
      await scrollOnce(150);
      await sleep(180);
    }
    await sleep(2000); // let late images land outside the window
  };
}

let _cdpRef = null;
async function scrollOnce(distance) {
  await _cdpRef.send('Input.synthesizeScrollGesture', {
    x: 215,
    y: 640,
    yDistance: distance,
    speed: 900,
    gestureSourceType: 'touch',
  });
}

/// Scene name to app route. `shelves` is the bare path; other scenes are
/// sub-routes. Kept in one place so the harness and the router cannot drift
/// into disagreeing about what `/perf-bench/shelves` even is.
function scenePath(scene) {
  return scene === 'shelves' ? '/perf-bench' : `/perf-bench/${scene}`;
}

// Cheap visual fingerprint of the page. Used to prove the scroll gesture
// actually moved the scene: if the "scroll" window looks identical to the
// "idle" one, the harness measured a static page twice and every scroll number
// it reports is fiction.
async function pageFingerprint(cdp) {
  const shot = await cdp.send('Page.captureScreenshot', {
    format: 'jpeg',
    quality: 20,
    optimizeForSpeed: true,
  });
  return createHash('sha1').update(shot.result.data).digest('hex');
}

async function runScene(scene, runIndex, server) {
  const chrome = await launch(CDP_PORT);
  _cdpRef = chrome.cdp;
  const { cdp } = chrome;
  try {
    await cdp.send('Page.enable');
    await cdp.send('Runtime.enable');
    await cdp.send('Performance.enable');
    // Keep the page "active" so rAF is not throttled, and focus it so the
    // pointer/visibility paths behave like a real foreground tab.
    await cdp.send('Page.setWebLifecycleState', { state: 'active' }).catch(() => {});
    await cdp.send('Emulation.setFocusEmulationEnabled', { enabled: true }).catch(() => {});
    await cdp.send('Emulation.setDeviceMetricsOverride', {
      width: 430,
      height: 932,
      deviceScaleFactor: DPR,
      mobile: true,
    });
    if (THROTTLE > 1) {
      await cdp.send('Emulation.setCPUThrottlingRate', { rate: THROTTLE });
    }

    await cdp.send('Page.navigate', {
      url: `http://127.0.0.1:${server}${scenePath(scene)}?perf=1`,
    });

    // Fail loudly if the app bounced somewhere else. The meter is mounted over
    // the whole app, so its numbers look perfectly healthy on the login gateway
    // — which is exactly how an earlier version of this bench produced a clean
    // baseline for a screen it never actually measured.
    await sleep(1200);
    const landed = await cdp.eval('location.pathname');
    if (!String(landed || '').startsWith('/perf-bench')) {
      throw new Error(
        `bench was redirected to "${landed}" instead of ${scenePath(scene)} — ` +
          'these numbers would describe the wrong screen',
      );
    }

    // The meter publishes from the first frame, but DeferredSection reveals and
    // the images decode for a while after. Scrolling into a still-changing
    // scene is the main source of run-to-run variance, so let it go quiet.
    const ok = await waitForMirror(cdp, 30000);
    if (!ok) throw new Error(`perf mirror never appeared on scene "${scene}"`);
    await sleep(SETTLE_MS);

    // The build ships a cache-first service worker; answer a measurement run
    // from disk, never from a cached shell.
    await cdp.eval(
      'navigator.serviceWorker && navigator.serviceWorker.getRegistrations().then(rs => rs.forEach(r => r.unregister())).then(() => true)',
    );

    const shot = SHOT_DIR ? `${SHOT_DIR}/${scene}-${runIndex}.png` : null;
    const idle = await measure(cdp, { act: () => sleep(5000), label: 'idle', shot });
    const beforeScroll = await pageFingerprint(cdp);
    const scrolled = await measure(cdp, { act: scrollPass(), label: 'scroll' });
    const afterScroll = await pageFingerprint(cdp);
    if (beforeScroll === afterScroll) {
      throw new Error(
        `scene "${scene}" did not move during the scroll pass (identical ` +
          'screenshots before and after) — the idle and scroll numbers would be ' +
          'the same static page measured twice',
      );
    }

    const renderer = await cdp.eval(`(() => {
      const c = document.querySelector('canvas') || document.createElement('canvas');
      const gl = c.getContext('webgl2') || c.getContext('webgl');
      if (!gl) return 'no-context';
      const d = gl.getExtension('WEBGL_debug_renderer_info');
      return d ? gl.getParameter(d.UNMASKED_RENDERER_WEBGL) : String(gl.getParameter(gl.RENDERER));
    })()`);

    return { scene, run: runIndex + 1, renderer, idle, scroll: scrolled };
  } finally {
    chrome.proc.kill();
    cleanup(chrome.userDataDir);
    await sleep(400);
  }
}

// Windows keeps Chrome's profile files locked briefly after exit, so a hard
// rm here would fail a run whose measurement already succeeded. Best-effort:
// leaving a temp dir behind is harmless, failing the run is not.
function sleepSync(ms) {
  const end = Date.now() + ms;
  while (Date.now() < end) {}
}

function cleanup(dir) {
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

// ── build + report ──────────────────────────────────────────────────────────
function build() {
  console.log('[bench] building web release with EG_PERF_BENCH=true ...');
  // Plain `flutter build web`, not tool/build_web.dart: that wrapper spawns
  // `flutter` via Process.start, which cannot resolve flutter.bat on Windows.
  // Skipping it also means self-hosted canvaskit/, which is deterministic
  // (no CDN fetch between runs) and irrelevant to frame cost anyway.
  const r = spawnSync(
    'flutter',
    [
      'build',
      'web',
      '--release',
      '--no-source-maps',
      '--dart-define=EG_PERF_BENCH=true',
    ],
    { stdio: 'inherit', shell: true },
  );
  if (r.status !== 0) throw new Error('build failed');
  if (!existsSync(join(WEB_ROOT, 'index.html'))) {
    throw new Error(`no build/web/index.html — expected at ${WEB_ROOT}`);
  }
}

function agg(runs) {
  // `min` is the honest estimator, not `median`: noise on a shared machine is
  // one-sided (a stray compile, a background tab, a thermal dip) — it can only
  // ever make a run slower, never faster. The minimum over N runs is therefore
  // the closest repeatable estimate of true cost, and it is far tighter than
  // the median. Both are reported.
  const min = (phase, key) => (runs.length ? Math.min(...runs.map((r) => r[phase][key])) : 0);
  const pick = (phase, key) => median(runs.map((r) => r[phase][key]));
  const phase = (name) => ({
    fps: pick(name, 'fps'),
    jankPct: pick(name, 'jankPct'),
    droppedPct: pick(name, 'droppedPct'),
    avgBuildMs: pick(name, 'avgBuildMs'),
    avgRasterMs: pick(name, 'avgRasterMs'),
    worstTotalMs: pick(name, 'worstTotalMs'),
    longTaskWorstMs: pick(name, 'longTaskWorstMs'),
    frames: pick(name, 'frames'),
    minBuildMs: min(name, 'avgBuildMs'),
    minRasterMs: min(name, 'avgRasterMs'),
    minWorstTotalMs: min(name, 'worstTotalMs'),
  });
  return { idle: phase('idle'), scroll: phase('scroll') };
}

const row = (label, phase, m) =>
  `| ${label} | ${phase} | ${r2(m.fps)} | ${r2(m.jankPct)}% | ` +
  `${r2(m.avgBuildMs)} | ${r2(m.minBuildMs)} | ${r2(m.avgRasterMs)} | ${r2(m.minRasterMs)} | ` +
  `${r2(m.worstTotalMs)} | ${r2(m.minWorstTotalMs)} | ${r2(m.longTaskWorstMs)} |`;

function spreadPct(values) {
  const m = median(values);
  if (!values.length || m === 0) return 0;
  return r2(((Math.max(...values) - Math.min(...values)) / Math.abs(m)) * 100);
}

function markdown(results, meta) {
  const lines = [
    '# Perf baseline',
    '',
    'Generated by `node tool/perf/bench.mjs --build`. Do not hand-edit: the',
    'numbers below are medians over the recorded runs so two builds can be',
    'diffed mechanically instead of read off a screenshot by eye.',
    '',
    `Runs per scene: ${RUNS} · viewport 430x932 @ DPR ${DPR} · ` +
      `CPU throttle ${THROTTLE}x · renderer \`${meta.renderer}\``,
    '',
    '## How to read this',
    '',
    '### Gate on the `min` columns',
    '',
    'Machine noise is one-sided: a stray compile, a background tab or a',
    'thermal dip can only ever make a run *slower*. So the minimum over N runs',
    'is the closest repeatable estimate of real cost, and it is far tighter',
    'than the median. A `min` change is the claim; the median is context.',
    '',
    '| metric | why |',
    '| --- | --- |',
    '| **build min ms** | CPU-side widget/layout work. Moves when a rebuild loop is fixed. Noisiest column — see the band below before trusting a small delta. |',
    '| **raster min ms** | Pixels painted. Most stable column, so it is the best regression tripwire. |',
    '| **worst frame min ms** | The "slowest frame you would feel". Catches stalls an average hides. |',
    '| **worst long task** | Uninterrupted main-thread work. The freeze check. |',
    '',
    '### Ignore FPS and jank columns',
    '',
    'Headless has no steady virtual vsync, so observed FPS wanders roughly',
    '60-100 on a *healthy* build with jank pinned at 0%. That is an environment',
    'artifact, not a property of the app: those two columns have no dynamic',
    'range and a regression can hide in them. Smoke signal only. The goal bar',
    '(>= 55 FPS, < 5% jank, 0 dropped) is a **device** claim, verified on the',
    'phone frame meter, not here.',
    '',
    '### Raster is not phone-representative',
    '',
    `The renderer line above is what actually painted these pixels. This rig is`,
    'a desktop GPU; an iPhone is a small power-budgeted one, so absolute raster',
    'here says nothing about the phone. Compare builds, never compare to a',
    'device.',
    '',
    '### Companion file',
    '',
    'This file is the **throttled** run: phone-like CPU, sensitive enough to',
    'show a real regression, but noisy (see the spread columns).',
    '`docs/perf-baseline-unthrottled.md` is the same scenes with no CPU',
    'throttle, where the numbers are far tighter and so make the better',
    'regression tripwire. Use unthrottled to catch paint/build regressions, and',
    'this file to judge whether something matters at phone CPU speeds.',
    '',
    '## Results',
    '',
    '| scene | phase | fps | jank | build med | build min | raster med | raster min | worst med | worst min | long task |',
    '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |',
  ];
  for (const scene of SCENES) {
    const a = results[scene];
    if (!a) continue;
    lines.push(row(scene, 'idle', a.idle));
    lines.push(row(scene, 'scroll', a.scroll));
  }

  lines.push('');
  lines.push('## Noise band');
  lines.push('');
  lines.push(
    'Spread across the runs of the *same unchanged build*. The `min` column is',
    'the gate value (noise is one-sided, so the fastest run is the cleanest',
    'estimate of true cost); the spread is how much jitter surrounds it. A',
    'before/after delta smaller than the spread of the metric it moves is not',
    'evidence of anything.',
    '',
    '| scene | phase | build min | build spread | raster min | raster spread | worst min | worst spread |',
    '| --- | --- | --- | --- | --- | --- | --- | --- |',
  );
  const mn = (runs, phase, k) => Math.min(...runs.map((x) => x[phase][k]));
  for (const scene of SCENES) {
    const runs = results.raw?.[scene] || [];
    if (!runs.length) continue;
    for (const phase of ['idle', 'scroll']) {
      lines.push(
        `| ${scene} | ${phase} | ` +
          `${r2(mn(runs, phase, 'avgBuildMs'))} | ` +
          `±${spreadPct(runs.map((x) => x[phase].avgBuildMs))}% | ` +
          `${r2(mn(runs, phase, 'avgRasterMs'))} | ` +
          `±${spreadPct(runs.map((x) => x[phase].avgRasterMs))}% | ` +
          `${r2(mn(runs, phase, 'worstTotalMs'))} | ` +
          `±${spreadPct(runs.map((x) => x[phase].worstTotalMs))}% |`,
      );
    }
  }
  lines.push('');
  lines.push('## Raw runs');
  lines.push('');
  for (const scene of SCENES) {
    for (const r of results.raw?.[scene] || []) {
      lines.push(
        `- ${scene} run ${r.run}: idle ${r2(r.idle.fps)}fps build ${r2(r.idle.avgBuildMs)}ms ` +
          `(${r.idle.frames} frames) · scroll ${r2(r.scroll.fps)}fps build ${r2(r.scroll.avgBuildMs)}ms ` +
          `raster ${r2(r.scroll.avgRasterMs)}ms worst ${r2(r.scroll.worstTotalMs)}ms ` +
          `longTask ${r2(r.scroll.longTaskWorstMs)}ms heap ${r.scroll.heapMb}MB`,
      );
    }
  }
  lines.push('');
  return lines.join('\n');
}

async function main() {
  if (has('--build')) build();
  if (!existsSync(join(WEB_ROOT, 'index.html'))) {
    throw new Error(`no build to measure. run: node tool/perf/bench.mjs --build`);
  }

  const server = await serve(WEB_ROOT, PORT);
  console.log(`[bench] serving ${WEB_ROOT} on ${PORT}`);

  const results = { raw: {} };
  let renderer = '?';
  try {
    for (const scene of SCENES) {
      const runs = [];
      for (let i = 0; i < RUNS; i++) {
        console.log(`[bench] ${scene} run ${i + 1}/${RUNS} ...`);
        const r = await runScene(scene, i, PORT);
        renderer = r.renderer;
        runs.push(r);
        console.log(
          `         idle ${r2(r.idle.fps)}fps build ${r2(r.idle.avgBuildMs)}ms ` +
            `frames ${r.idle.frames} | scroll ${r2(r.scroll.fps)}fps build ${r2(r.scroll.avgBuildMs)}ms ` +
            `raster ${r2(r.scroll.avgRasterMs)}ms worst ${r2(r.scroll.worstTotalMs)}ms ` +
            `frames ${r.scroll.frames} longTask ${r2(r.scroll.longTaskWorstMs)}ms`,
        );
      }
      results.raw[scene] = runs;
      results[scene] = agg(runs);
    }
  } finally {
    server.close();
  }

  writeFileSync(OUT, markdown(results, { renderer }));
  console.log(`[bench] wrote ${OUT}`);
  console.log(JSON.stringify(Object.fromEntries(SCENES.map((s) => [s, results[s]])), null, 2));
}

main().catch((e) => {
  console.error('[bench] failed:', e.message);
  process.exit(1);
});