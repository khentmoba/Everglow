import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  launch, median, NETWORK_PROFILES, prepare, serve, shapeNetwork, sleep, stop,
} from './_harness.mjs';

const SKELETON_TEXT = /Finding your next watch/;

const ROWS_TEXT = /More Info/;

const READ_STATE = `(() => {
  // Flutter only builds the DOM semantics tree on demand; without this the
  // page text is empty no matter what is painted on the canvas.
  document.querySelector('flt-semantics-placeholder')?.click();
  const text = document.body?.innerText || '';
  const canvas = !!(document.querySelector('canvas') ||
    document.querySelector('flt-glass-pane')?.shadowRoot?.querySelector('canvas'));
  const parts = performance.getEntriesByType('resource')
    .filter(r => /main\\.dart\\.js_\\d+\\.part\\.js$/.test(new URL(r.name).pathname))
    .map(r => new URL(r.name).pathname);
  const net = performance.getEntriesByType('resource')
    .map(r => ({u: r.name, b: r.transferSize || 0}));
  return {canvas, text, parts, net, url: location.pathname};
})()`;

function summarizeRequests(entries) {
  const byHost = {};
  let bytes = 0;
  for (const e of entries) {
    let host;
    try { host = new URL(e.u).host; } catch { host = 'invalid'; }
    byHost[host] = (byHost[host] || 0) + 1;
    bytes += e.b || 0;
  }
  return { total: entries.length, bytes, byHost };
}

async function goTo(cdp, path) {
  await cdp.eval(`(() => {
    history.pushState({}, '', ${JSON.stringify(path)});
    window.dispatchEvent(new PopStateEvent('popstate', {state: {}}));
    return true;
  })()`);
}

async function waitUntil(cdp, predicate, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let last = null;
  while (Date.now() < deadline) {
    last = await cdp.eval(READ_STATE);
    if (predicate(last)) return last;
    await sleep(20);
  }
  return null;
}

async function openCinema(cdp, { timeoutMs }) {
  const before = await cdp.eval(READ_STATE);
  const beforeParts = new Set(before.parts);
  const beforeNet = new Set(before.net.map((e) => e.u));
  const t0 = Date.now();

  await goTo(cdp, '/cinema');

  let skeletonMs = null;
  let rowsMs = null;
  let state = null;
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    state = await cdp.eval(READ_STATE);
    const elapsed = Date.now() - t0;
    if (skeletonMs === null && SKELETON_TEXT.test(state.text)) skeletonMs = elapsed;
    if (ROWS_TEXT.test(state.text)) {
      rowsMs = elapsed;
      break;
    }
    await sleep(20);
  }

  const after = state ?? (await cdp.eval(READ_STATE));
  const newParts = after.parts.filter((p) => !beforeParts.has(p));
  const newRequests = after.net.filter((e) => !beforeNet.has(e.u));

  return {
    skeletonMs,
    rowsMs,
    newChunks: newParts.length,
    requests: summarizeRequests(newRequests),
    navigated: after.url === '/cinema',
  };
}

async function backToDashboard(cdp, timeoutMs, settleMs = 400) {
  await goTo(cdp, '/dashboard');
  const ok = await waitUntil(
    cdp,
    (s) => s.url === '/dashboard' && /Forever In Bloom/.test(s.text),
    timeoutMs,
  );
  if (!ok) throw new Error('could not return to the dashboard');
  await sleep(settleMs);
}

async function bootToDashboard(cdp, origin, timeoutMs, settleMs) {
  await cdp.send('Page.navigate', { url: `${origin}/?agent=dashboard` });
  const dashboard = await waitUntil(
    cdp,
    (s) => s.canvas && /Forever In Bloom/.test(s.text),
    timeoutMs,
  );
  if (!dashboard) {
    const last = await cdp.eval(READ_STATE);
    throw new Error(
      `dashboard never painted (canvas=${last.canvas}, text=${JSON.stringify(last.text.slice(0, 200))})`,
    );
  }
  await sleep(settleMs);
}

export async function main(argv = process.argv.slice(2)) {
  const flag = (n, d) => (argv.includes(n) ? argv[argv.lastIndexOf(n) + 1] : d);
  const options = {
    webRoot: resolve(flag('--web-root', 'build/web')),
    profile: flag('--profile', 'none'),
    cpu: Number(flag('--cpu', 1)),
    warm: Number(flag('--warm', 3)),
    label: flag('--label', 'build'),
    settleMs: Number(flag('--settle-ms', 1200)),
    prime: argv.includes('--prime'),
    shot: flag('--shot', null),
    timeoutMs: Number(flag('--timeout-ms', 40000)),
  };
  if (!NETWORK_PROFILES[options.profile]) {
    throw new Error(`unknown network profile: ${options.profile}`);
  }
  if (!Number.isInteger(options.warm) || options.warm < 1) {
    throw new Error('--warm must be a positive integer');
  }

  const server = await serve(options.webRoot, 0);
  const origin = `http://127.0.0.1:${server.address().port}`;
  const rows = [];
  let browser;
  try {
    browser = await launch(0, { dpr: 1, width: 430, height: 932 });
    const { cdp } = browser;
    await prepare(cdp, { dpr: 1, width: 430, height: 932 });
    await cdp.send('Page.enable');
    await cdp.send('Runtime.enable');
    await cdp.send('Network.enable');
    if (options.cpu > 1) {
      await cdp.send('Emulation.setCPUThrottlingRate', { rate: options.cpu });
    }
    await shapeNetwork(cdp, options.profile);

    await bootToDashboard(cdp, origin, options.timeoutMs, options.settleMs);

    if (options.prime) {
      console.log(`[cinema-open] ${options.label} priming saved rows`);
      await openCinema(cdp, options);
      await sleep(1500);
      await bootToDashboard(cdp, origin, options.timeoutMs, options.settleMs);
    }

    console.log(`[cinema-open] ${options.label} cold open`);
    rows.push({ run: 'cold', ...(await openCinema(cdp, options)) });

    if (options.shot) {
      const shot = await cdp.send('Page.captureScreenshot', { format: 'png' });
      mkdirSync(dirname(options.shot), { recursive: true });
      writeFileSync(options.shot, Buffer.from(shot.result.data, 'base64'));
      console.log(`[cinema-open] screenshot -> ${options.shot}`);
    }

    for (let i = 1; i <= options.warm; i++) {
      await backToDashboard(cdp, options.timeoutMs);
      console.log(`[cinema-open] ${options.label} warm open ${i}/${options.warm}`);
      rows.push({ run: `warm-${i}`, ...(await openCinema(cdp, options)) });
    }
  } finally {
    if (browser) await stop(browser);
    server.closeAllConnections();
    server.close();
  }

  const cold = rows.find((r) => r.run === 'cold');
  const warm = rows.filter((r) => r.run !== 'cold');
  const complete =
    rows.every((r) => Number.isFinite(r.rowsMs) && r.navigated) &&
    warm.length === options.warm;

  const report = {
    label: options.label,
    webRoot: options.webRoot,
    profile: options.profile,
    cpuThrottle: options.cpu,
    note:
      'In-app navigation from a warm dashboard, not a page reload. CDP ' +
      'synthetic link on desktop Chrome; not a phone measurement. Cold = ' +
      'first Cinema open after an app boot' +
      (options.prime
        ? ' with rows already saved on this device (returning visitor).'
        : ' on a device with no saved rows (first ever visit).'),
    complete,
    cold: Number.isFinite(cold?.rowsMs)
      ? {
          skeletonMs: cold.skeletonMs,
          rowsMs: cold.rowsMs,
          newChunks: cold.newChunks,
          requests: cold.requests,
        }
      : null,
    warm: complete && warm.length
      ? {
          runs: warm.length,
          medianRowsMs: median(warm.map((r) => r.rowsMs)),
          worstRowsMs: Math.max(...warm.map((r) => r.rowsMs)),
          medianSkeletonMs: median(
            warm.map((r) => (Number.isFinite(r.skeletonMs) ? r.skeletonMs : r.rowsMs)),
          ),
          medianRequests: median(warm.map((r) => r.requests.total)),
          medianRequestBytes: median(warm.map((r) => r.requests.bytes)),
        }
      : null,
    details: rows,
  };
  console.log(JSON.stringify(report, null, 2));
  if (!complete) process.exitCode = 1;
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch((e) => {
    console.error('[cinema-open] failed:', e.message);
    process.exitCode = 1;
  });
}
