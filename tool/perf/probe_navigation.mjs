// Times the hop Clair makes most: dashboard -> a media section -> back.
//
// Boots the release app at `/?agent=dashboard&perf=1` (isolated demo session,
// no login or couple data), lets the dashboard settle, then opens Cinema,
// Anime, Mangacelestia and Books in turn through the router's own browser
// history path (pushState + popstate, where a link tap ends up too) and
// returns to the dashboard between each. Each section is opened twice: the
// first visit and a revisit.
//
// The time reported is from the navigation request to the end of the first
// frame that built the real screen, read from the `route:<label>` marks that
// `DeferredRouteLoader` records while the frame meter is on. A loading body
// does not count as arrival.
//
//   node tool/perf/probe_navigation.mjs [--web-root DIR] [--throttle 4]
//        [--network none|fast3g|slow3g] [--settle 6000] [--json FILE]
//
// Desktop headless Chrome is not a phone. Compare two builds on the same rig.
import { writeFileSync } from 'node:fs';
import {
  launch, LONG_TASK_OBSERVER, prepare, serve, shapeNetwork, sleep, stop,
} from './_harness.mjs';

const args = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? fallback : args[i + 1];
};
const webRoot = flag('web-root', 'build/web');
const throttle = Number(flag('throttle', 4));
const network = flag('network', 'fast3g');
const settleMs = Number(flag('settle', 6000));
const jsonOut = flag('json', null);
const WIDTH = 430;
const HEIGHT = 932;
const DPR = 3;

/// Route path and the `DeferredRouteLoader` label that marks its arrival.
const SECTIONS = [
  ['cinema', '/cinema', 'Cinema'],
  ['anime', '/anime', 'Anime'],
  ['manga', '/manga', 'Mangacelestia'],
  ['books', '/books', 'Books'],
];
const HOME = ['dashboard', '/dashboard', 'Home'];

const marks = (cdp) => cdp.eval('(window.__everglowMarks || []).slice()');

/// Navigates in the running app and waits for the screen's arrival mark.
async function open(cdp, [, path, label], timeoutMs = 30000) {
  await cdp.eval('window.__egFlushLongTasks && window.__egFlushLongTasks()');
  const start = await cdp.eval(`(() => {
    const t = performance.now();
    history.pushState({}, '', ${JSON.stringify(path)});
    dispatchEvent(new PopStateEvent('popstate', {state: {}}));
    return t;
  })()`);
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const hit = (await marks(cdp)).find((m) => m.name === `route:${label}` && m.at >= start);
    if (hit) {
      await sleep(300);
      await cdp.eval('window.__egFlushLongTasks && window.__egFlushLongTasks()');
      const tasks = (await cdp.eval('(window.__egLongTasks || []).slice()'))
        .filter((t) => t.start >= start && t.start <= hit.at);
      return {
        ms: Math.round(hit.at - start),
        longTaskMaxMs: Math.round(tasks.reduce((m, t) => Math.max(m, t.dur), 0)),
        longTasks: tasks.length,
      };
    }
    await sleep(25);
  }
  throw new Error(`${label} never arrived after navigating to ${path}`);
}

const server = await serve(webRoot, 0);
let browser;
const report = { webRoot, throttle, network, settleMs, visits: [] };
try {
  browser = await launch(0, { dpr: DPR, width: WIDTH, height: HEIGHT });
  const { cdp } = browser;
  await prepare(cdp, { dpr: DPR, width: WIDTH, height: HEIGHT });
  await cdp.send('Page.addScriptToEvaluateOnNewDocument', { source: LONG_TASK_OBSERVER });
  const origin = `http://127.0.0.1:${server.address().port}`;
  await cdp.send('Page.navigate', { url: `${origin}/?agent=dashboard&perf=1` });
  const deadline = Date.now() + 60000;
  while (Date.now() < deadline) {
    if ((await marks(cdp)).some((m) => m.name === 'route:Home')) break;
    await sleep(150);
  }
  if (!(await marks(cdp)).some((m) => m.name === 'route:Home')) {
    throw new Error('dashboard never arrived (no route:Home mark; is this build instrumented?)');
  }
  // Shape after boot: the probe times in-app hops, not the app shell download.
  if (network !== 'none') await shapeNetwork(cdp, network);
  if (throttle > 1) await cdp.send('Emulation.setCPUThrottlingRate', { rate: throttle });
  await sleep(settleMs);

  for (const visit of ['first', 'revisit']) {
    for (const section of SECTIONS) {
      const result = await open(cdp, section);
      report.visits.push({ section: section[0], visit, ...result });
      await sleep(1500);
      await open(cdp, HOME);
      await sleep(1500);
    }
  }
} finally {
  if (browser) await stop(browser);
  await new Promise((r) => server.close(r));
}

console.log(`\n[probe-navigation] ${webRoot}  ${WIDTH}x${HEIGHT} @${DPR}x  cpu x${throttle}  network ${network}`);
console.log('section   visit     tap->screen  longTaskMax  longTasks');
for (const v of report.visits) {
  console.log(
    `${v.section.padEnd(8)}  ${v.visit.padEnd(8)}  ${String(v.ms).padStart(9)}ms  ` +
    `${String(v.longTaskMaxMs).padStart(9)}ms  ${String(v.longTasks).padStart(9)}`,
  );
}
if (jsonOut) {
  writeFileSync(jsonOut, JSON.stringify(report, null, 2));
  console.log(`\nwrote ${jsonOut}`);
}
