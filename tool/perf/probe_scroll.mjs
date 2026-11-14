// Scrolls a REAL screen in agent mode and reports frame cost per phase.
//
// This is not the synthetic bench: it boots the release app at `/?agent=<screen>`,
// which uses the isolated demo session, so no login or couple data is involved.
//
//   node tool/perf/probe_scroll.mjs [--web-root DIR] [--dpr 3] [--throttle 4]
//                                   [--passes 2] [--json FILE]
//                                   [--screen dashboard|cinema|anime|manga|books]
//                                   [--profiles DIR]  (raw .cpuprofile per phase)
//
// Reports, per phase (first-down / repeat-down / repeat-up):
//   worst reported frame span, worst build/raster, long tasks over 200ms,
//   and the top self-time JS entries from a CDP CPU profile of the scroll.
//
// Desktop headless Chrome is not an iPhone. The numbers compare two builds on
// the same rig; they are not a device FPS claim.
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { launch, prepare, serve, sleep, stop } from './_harness.mjs';
import { loadSourceMap, shortSource } from './_sourcemap.mjs';

const args = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? fallback : args[i + 1];
};
const webRoot = flag('web-root', 'build/web');
const dpr = Number(flag('dpr', 3));
const throttle = Number(flag('throttle', 4));
const passes = Number(flag('passes', 2));
const jsonOut = flag('json', null);
const profilesDir = flag('profiles', null);
const SCREEN_PATHS = {
  dashboard: '/dashboard',
  cinema: '/cinema',
  anime: '/anime',
  manga: '/manga',
  books: '/books',
};
const screen = flag('screen', 'dashboard');
const screenPath = SCREEN_PATHS[screen];
if (!screenPath) {
  console.error(`unknown --screen ${screen}; use one of ${Object.keys(SCREEN_PATHS).join(', ')}`);
  process.exit(2);
}
const WIDTH = 430;
const HEIGHT = 932;

const LONG_TASK_OBSERVER = `(() => {
  window.__egLongTasks = [];
  try {
    const o = new PerformanceObserver((l) => {
      for (const e of l.getEntries()) window.__egLongTasks.push({dur: e.duration, start: e.startTime});
    });
    o.observe({type: 'longtask', buffered: true});
    window.__egFlushLongTasks = () => o.takeRecords().forEach((e) => window.__egLongTasks.push({dur: e.duration, start: e.startTime}));
  } catch (e) { window.__egLongTaskError = String(e); }
})();`;

const readMirror = (cdp) => cdp.eval('window.__everglowPerf || null');

async function waitForMirror(cdp, timeoutMs = 30000) {
  const deadline = Date.now() + timeoutMs;
  let last = 'missing';
  while (Date.now() < deadline) {
    const m = await readMirror(cdp);
    if (m && Number.isFinite(m.sessionFrames) && m.sessionFrames > 0 && m.sampleSequence > 0) return m;
    last = JSON.stringify(m)?.slice(0, 120) ?? 'null';
    await sleep(150);
  }
  throw new Error(`perf mirror never became valid (last: ${last})`);
}

async function scrollPhase(cdp, { label, direction, swipes }) {
  await cdp.eval('window.__egFlushLongTasks && window.__egFlushLongTasks()');
  // Reset per phase so the worst frame belongs to this phase, not to an
  // earlier one that happened to be slower.
  await cdp.eval('window.__everglowResetPerf && window.__everglowResetPerf()');
  await sleep(200);
  const before = await readMirror(cdp);
  const phaseStart = await cdp.eval('performance.now()');
  await cdp.send('Profiler.start');
  for (let i = 0; i < swipes; i++) {
    await cdp.send('Input.synthesizeScrollGesture', {
      x: Math.round(WIDTH / 2),
      y: Math.round(HEIGHT * 0.7),
      xDistance: 0,
      yDistance: direction * 420,
      speed: 1400,
      gestureSourceType: 'touch',
      repeatCount: 0,
    });
    await sleep(90);
  }
  // Let the fling settle and the meter publish its next reading.
  await sleep(900);
  const { result } = await cdp.send('Profiler.stop');
  if (profilesDir) {
    mkdirSync(profilesDir, { recursive: true });
    writeFileSync(join(profilesDir, `${screen}-${label}.cpuprofile`), JSON.stringify(result.profile));
  }
  await cdp.eval('window.__egFlushLongTasks && window.__egFlushLongTasks()');
  const after = await readMirror(cdp);
  const longTasks = await cdp.eval('(window.__egLongTasks || []).slice()');
  const fresh = longTasks.filter((t) => t.start >= phaseStart);
  return {
    label,
    freshFrames: after.sessionFrames - before.sessionFrames,
    worstFrameMs: after.sessionWorstFrameMs,
    worstBuildMs: after.sessionWorstBuildMs,
    worstRasterMs: after.sessionWorstRasterMs,
    over200ms: after.sessionOver200ms,
    fps: after.fps,
    avgBuildMs: after.buildAvgMs,
    avgRasterMs: after.rasterAvgMs,
    longTaskMaxMs: fresh.reduce((m, t) => Math.max(m, t.dur), 0),
    longTasksOver200: fresh.filter((t) => t.dur > 200).length,
    profile: topSelfTime(result.profile, 18),
    appInclusive: topAppInclusive(result.profile, 15),
  };
}

/** Names a CDP call frame, resolving through a source map when one exists. */
function frameName(f) {
  const file = (f.url || '').split('/').pop();
  const original = sourceMapFor(file)?.lookup(f.lineNumber + 1, f.columnNumber) ?? null;
  if (!original) return { name: `${f.functionName || '(anonymous)'} @${file}:${f.lineNumber}`, source: '' };
  return {
    name: `${original.name || f.functionName || '(anonymous)'} @${shortSource(original.source)}:${original.line}`,
    source: String(original.source).replace(/\\/g, '/'),
  };
}

const pctOf = (hits, total) => Math.round((hits / (total || 1)) * 1000) / 10;

/** Aggregates a CDP CPU profile into self time per function. */
function topSelfTime(profile, limit) {
  if (!profile?.nodes) return [];
  const self = new Map();
  for (const node of profile.nodes) {
    const hits = node.hitCount || 0;
    if (!hits) continue;
    const { name } = frameName(node.callFrame);
    self.set(name, (self.get(name) || 0) + hits);
  }
  const total = [...self.values()].reduce((a, b) => a + b, 0);
  return [...self.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([name, hits]) => ({ name, pct: pctOf(hits, total) }));
}

// Everglow's own code (not Flutter, not the engine), so the inclusive ranking
// points at a widget or service rather than at shared framework plumbing.
const APP_SOURCE = /^(\.\.\/)+lib\/(features|shared|core)\//;

/**
 * Inclusive time per Everglow function: the share of busy samples with that
 * function anywhere on the stack. Self time is spread thin across the engine;
 * this shows which of our widgets the expensive frames were spent under.
 */
function topAppInclusive(profile, limit) {
  if (!profile?.nodes || !profile.samples) return [];
  const parent = new Map();
  for (const node of profile.nodes) for (const child of node.children ?? []) parent.set(child, node.id);
  const byId = new Map(profile.nodes.map((n) => [n.id, n]));
  const appName = new Map();
  for (const node of profile.nodes) {
    const { name, source } = frameName(node.callFrame);
    if (APP_SOURCE.test(source)) appName.set(node.id, name);
  }
  const counts = new Map();
  let busy = 0;
  for (const id of profile.samples) {
    const fn = byId.get(id)?.callFrame.functionName;
    if (fn === '(idle)' || fn === '(program)' || fn === '(garbage collector)') continue;
    busy++;
    const seen = new Set();
    for (let cur = id; cur !== undefined; cur = parent.get(cur)) {
      const name = appName.get(cur);
      if (name && !seen.has(name)) {
        seen.add(name);
        counts.set(name, (counts.get(name) || 0) + 1);
      }
    }
  }
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([name, hits]) => ({ name, pct: pctOf(hits, busy) }));
}

// `flutter build web --source-maps` adds maps next to main.dart.js and each
// deferred part, so the profile can name Dart functions instead of minified
// dart2js symbols. Without maps the minified names are printed.
const sourceMaps = new Map();
function sourceMapFor(file) {
  if (!/^main\.dart\.js(_\d+\.part\.js)?$/.test(file)) return null;
  if (!sourceMaps.has(file)) {
    const mapPath = join(webRoot, `${file}.map`);
    sourceMaps.set(file, existsSync(mapPath) ? loadSourceMap(mapPath) : null);
  }
  return sourceMaps.get(file);
}

const server = await serve(webRoot, 0);
let browser;
const report = { webRoot, screen, dpr, throttle, width: WIDTH, height: HEIGHT, phases: [] };
try {
  browser = await launch(0, { dpr, width: WIDTH, height: HEIGHT });
  const { cdp } = browser;
  await prepare(cdp, { dpr, width: WIDTH, height: HEIGHT });
  await cdp.send('Page.addScriptToEvaluateOnNewDocument', { source: LONG_TASK_OBSERVER });
  await cdp.send('Profiler.enable');
  await cdp.send('Profiler.setSamplingInterval', { interval: 200 });
  if (throttle > 1) {
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: throttle });
    report.cpuThrottleRate = throttle;
  }
  const origin = `http://127.0.0.1:${server.address().port}`;
  const t0 = Date.now();
  await cdp.send('Page.navigate', { url: `${origin}/?agent=${screen}&perf=1` });

  // First frame → first dashboard paint. Cold-load timing is reported, not
  // budgeted here; the scroll numbers are the point of this probe.
  const deadline = Date.now() + 60000;
  let painted = false;
  while (Date.now() < deadline) {
    painted = await cdp.eval(`(() => {
      // Deliberately does NOT enable the accessibility tree. Clicking
      // flt-semantics-placeholder would build a full DOM semantics tree and
      // rewrite it on every scroll frame, which measured as its own multi-second
      // hotspot (lib/_engine/engine/semantics/scrollable.dart) and swamped the
      // thing this probe exists to measure. Screen identity comes from the
      // route plus a live meter instead.
      const canvas = !!(document.querySelector('canvas') ||
        document.querySelector('flt-glass-pane')?.shadowRoot?.querySelector('canvas'));
      return canvas && location.pathname === ${JSON.stringify(screenPath)} && !!window.__everglowPerf;
    })()`);
    if (painted) break;
    await sleep(150);
  }
  if (!painted) throw new Error(`${screen} never painted in agent mode`);
  report.firstPaintMs = Date.now() - t0;
  if (screen === 'dashboard') report.firstDashboardPaintMs = report.firstPaintMs;

  // Let the deferred sections above the fold mount before judging scroll cost.
  await waitForMirror(cdp);
  await sleep(2500);
  await cdp.eval('window.__everglowResetPerf && window.__everglowResetPerf()');
  await sleep(400);

  report.phases.push(await scrollPhase(cdp, { label: 'first-down', direction: -1, swipes: 6 }));
  for (let p = 1; p < passes; p++) {
    report.phases.push(await scrollPhase(cdp, { label: `repeat-down-${p}`, direction: -1, swipes: 8 }));
  }
  report.phases.push(await scrollPhase(cdp, { label: 'repeat-up', direction: 1, swipes: 8 }));

  const maxOf = (key) => Math.max(...report.phases.map((p) => p[key] ?? 0));
  const sumOf = (key) => report.phases.reduce((n, p) => n + (p[key] ?? 0), 0);
  report.session = {
    worstFrameMs: maxOf('worstFrameMs'),
    worstBuildMs: maxOf('worstBuildMs'),
    worstRasterMs: maxOf('worstRasterMs'),
    over200ms: sumOf('over200ms'),
    sessionFrames: sumOf('freshFrames'),
    longTaskMaxMs: maxOf('longTaskMaxMs'),
    longTasksOver200: sumOf('longTasksOver200'),
  };
  report.longTaskError = await cdp.eval('window.__egLongTaskError || null');
} finally {
  if (browser) await stop(browser);
  await new Promise((r) => server.close(r));
}

const fmt = (n) => (Number.isFinite(n) ? Math.round(n * 10) / 10 : n);
console.log(`\n[probe-scroll] ${screen}  ${webRoot}  ${WIDTH}x${HEIGHT} @${dpr}x  cpu x${throttle}`);
console.log(`first ${screen} paint: ${report.firstPaintMs}ms`);
console.log('phase                 frames  worstFrame  worstBuild  worstRaster  >200ms  longTaskMax  longTasks>200');
for (const p of report.phases) {
  console.log(
    `${p.label.padEnd(20)}  ${String(p.freshFrames).padStart(6)}  ${String(fmt(p.worstFrameMs)).padStart(10)}  ` +
    `${String(fmt(p.worstBuildMs)).padStart(10)}  ${String(fmt(p.worstRasterMs)).padStart(11)}  ` +
    `${String(p.over200ms).padStart(6)}  ${String(fmt(p.longTaskMaxMs)).padStart(11)}  ${String(p.longTasksOver200).padStart(13)}`,
  );
}
const s = report.session;
console.log(
  `${'all phases'.padEnd(20)}  ${String(s.sessionFrames).padStart(6)}  ${String(fmt(s.worstFrameMs)).padStart(10)}  ` +
  `${String(fmt(s.worstBuildMs)).padStart(10)}  ${String(fmt(s.worstRasterMs)).padStart(11)}  ` +
  `${String(s.over200ms).padStart(6)}  ${String(fmt(s.longTaskMaxMs)).padStart(11)}  ${String(s.longTasksOver200).padStart(13)}`,
);
for (const phase of [report.phases[0], report.phases.at(-1)]) {
  console.log(`\ntop self-time during scroll (${phase.label}):`);
  for (const row of phase.profile) console.log(`  ${String(row.pct).padStart(5)}%  ${row.name}`);
  if (phase.appInclusive.length) {
    console.log(`
Everglow code on the stack, share of busy samples (${phase.label}):`);
    for (const row of phase.appInclusive) console.log(`  ${String(row.pct).padStart(5)}%  ${row.name}`);
  }
}
if (report.longTaskError) console.log(`long task observer: ${report.longTaskError}`);
if (jsonOut) {
  writeFileSync(jsonOut, JSON.stringify(report, null, 2));
  console.log(`\nwrote ${jsonOut}`);
}
