// Scrolls the REAL dashboard in agent mode and reports frame cost per phase.
//
// This is not the synthetic bench: it boots the release app at `/?agent=dashboard`,
// which uses the isolated demo session, so no login or couple data is involved.
//
//   node tool/perf/probe_scroll.mjs [--web-root DIR] [--dpr 3] [--throttle 4]
//                                   [--passes 2] [--json FILE]
//
// Reports, per phase (first-down / repeat-down / repeat-up):
//   worst reported frame span, worst build/raster, long tasks over 200ms,
//   and the top self-time JS entries from a CDP CPU profile of the scroll.
//
// Desktop headless Chrome is not an iPhone. The numbers compare two builds on
// the same rig; they are not a device FPS claim.
import { writeFileSync } from 'node:fs';
import { launch, prepare, serve, sleep, stop } from './_harness.mjs';

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
  const before = await readMirror(cdp);
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
  await cdp.eval('window.__egFlushLongTasks && window.__egFlushLongTasks()');
  const after = await readMirror(cdp);
  const longTasks = await cdp.eval('(window.__egLongTasks || []).slice()');
  const fresh = longTasks.filter((t) => t.start >= (before.__wall ?? 0));
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
    longTaskMaxMs: longTasks.reduce((m, t) => Math.max(m, t.dur), 0),
    longTasksOver200: longTasks.filter((t) => t.dur > 200).length,
    profile: topSelfTime(result.profile, 18),
  };
}

/** Aggregates a CDP CPU profile into self time per function. */
function topSelfTime(profile, limit) {
  if (!profile?.nodes) return [];
  const byId = new Map(profile.nodes.map((n) => [n.id, n]));
  const self = new Map();
  for (const node of profile.nodes) {
    const hits = node.hitCount || 0;
    if (!hits) continue;
    const f = node.callFrame;
    const name = `${f.functionName || '(anonymous)'} @${(f.url || '').split('/').pop()}:${f.lineNumber}`;
    self.set(name, (self.get(name) || 0) + hits);
  }
  const total = [...self.values()].reduce((a, b) => a + b, 0) || 1;
  return [...self.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([name, hits]) => ({ name, pct: Math.round((hits / total) * 1000) / 10 }));
}

const server = await serve(webRoot, 0);
let browser;
const report = { webRoot, dpr, throttle, width: WIDTH, height: HEIGHT, phases: [] };
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
  await cdp.send('Page.navigate', { url: `${origin}/?agent=dashboard&perf=1` });

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
      return canvas && location.pathname === '/dashboard' && !!window.__everglowPerf;
    })()`);
    if (painted) break;
    await sleep(150);
  }
  if (!painted) throw new Error('dashboard never painted in agent mode');
  report.firstDashboardPaintMs = Date.now() - t0;

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

  const final = await readMirror(cdp);
  report.session = {
    worstFrameMs: final.sessionWorstFrameMs,
    worstBuildMs: final.sessionWorstBuildMs,
    worstRasterMs: final.sessionWorstRasterMs,
    over200ms: final.sessionOver200ms,
    sessionFrames: final.sessionFrames,
    overBudgetPct: final.sessionOverBudgetPercent,
  };
  report.longTaskError = await cdp.eval('window.__egLongTaskError || null');
} finally {
  if (browser) await stop(browser);
  await new Promise((r) => server.close(r));
}

const fmt = (n) => (Number.isFinite(n) ? Math.round(n * 10) / 10 : n);
console.log(`\n[probe-scroll] ${webRoot}  ${WIDTH}x${HEIGHT} @${dpr}x  cpu x${throttle}`);
console.log(`first dashboard paint: ${report.firstDashboardPaintMs}ms`);
console.log('phase                 frames  worstFrame  worstBuild  worstRaster  >200ms  longTaskMax  longTasks>200');
for (const p of report.phases) {
  console.log(
    `${p.label.padEnd(20)}  ${String(p.freshFrames).padStart(6)}  ${String(fmt(p.worstFrameMs)).padStart(10)}  ` +
    `${String(fmt(p.worstBuildMs)).padStart(10)}  ${String(fmt(p.worstRasterMs)).padStart(11)}  ` +
    `${String(p.over200ms).padStart(6)}  ${String(fmt(p.longTaskMaxMs)).padStart(11)}  ${String(p.longTasksOver200).padStart(13)}`,
  );
}
console.log('\ntop self-time during scroll (last phase):');
for (const row of report.phases.at(-1).profile) console.log(`  ${String(row.pct).padStart(5)}%  ${row.name}`);
if (report.longTaskError) console.log(`long task observer: ${report.longTaskError}`);
if (jsonOut) {
  writeFileSync(jsonOut, JSON.stringify(report, null, 2));
  console.log(`\nwrote ${jsonOut}`);
}
