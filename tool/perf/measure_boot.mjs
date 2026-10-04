// Cold-boot measurement for the Everglow web shell.
//
// Unlike the scroll metrics, boot is *not* GPU-bound: the splash in
// web/index.html is inline HTML + inline CSS, so it can paint before the ~6MB
// main.dart.js is even requested. That makes it measurable here.
//
// Observers are installed before navigating, and a marker is set synchronously
// so a run that silently failed to install is distinguishable from a genuinely
// slow one — that distinction is what made an earlier attempt return
// `undefined` and be misread.
//
// Usage:
//   node tool/perf/measure_boot.mjs --build --runs 3 --profile slow3g
//   node tool/perf/measure_boot.mjs --runs 3 --profile none
//
// "First interactive" is the app's own `flutter-first-frame` event: the first
// Flutter frame on screen, which is the earliest point a person could actually
// use the app. LCP and first-paint are reported too, because they answer
// different questions and it is worth knowing which one moved.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import {
  LONG_TASK_OBSERVER,
  cleanup,
  launch,
  median,
  prepare,
  serve,
  sleep,
} from './_harness.mjs';

const argv = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = argv.indexOf(name);
  return i > -1 ? argv[i + 1] : fallback;
};
const has = (name) => argv.includes(name);

const RUNS = Number(flag('--runs', 3));
const PROFILE = flag('--profile', 'slow3g');
const ALLOW_SW = has('--sw');
// `--repeat` warms the service worker first, then measures the *second*
// navigation in the same profile. That is the visit Clair actually notices:
// she reopens an installed PWA that has been there for days.
const REPEAT = has('--repeat');
const PORT = Number(flag('--port', 8971));
const CDP_PORT = Number(process.env.CDP_PORT || 9311);
const SHOT = flag('--shot', null);
const BOOT_TIMEOUT_MS = Number(process.env.BOOT_TIMEOUT_MS || 40000);
const WEB_ROOT = resolve('build/web');

// The goal's bars for this pass.
const BAR = { firstInteractiveMs: 2500, longTaskMs: 500 };

// Link shaping happens in the static server, not via
// `Network.emulateNetworkConditions`: headless Chrome ignores that (asked for
// 400KB/s, it delivered 6.77MB in 67ms), so a "throttled" run measured with it
// was measuring an unthrottled download while reporting it as slow3g.
const PROFILES = {
  none: 0,
  fast3g: 1600,
  slow3g: 400,
};
const KBPS = PROFILES[PROFILE] ?? 400;

const PROBE = `
  window.__boot = { installed: performance.now(), fcp: null, lcp: null, dcl: null,
                    splash: null, flutterFrame: null };
  try {
    new PerformanceObserver((l) => {
      for (const e of l.getEntries()) if (e.name === 'first-contentful-paint') window.__boot.fcp = e.startTime;
    }).observe({ type: 'paint', buffered: true });
    new PerformanceObserver((l) => {
      for (const e of l.getEntries()) window.__boot.lcp = e.startTime;
    }).observe({ type: 'largest-contentful-paint', buffered: true });
    document.addEventListener('DOMContentLoaded', () => { window.__boot.dcl = performance.now(); });
    window.addEventListener('flutter-first-frame', () => { window.__boot.flutterFrame = performance.now(); });
    // When the splash node first exists in the document.
    new MutationObserver(() => {
      if (window.__boot.splash === null && document.getElementById('eg-splash')) {
        window.__boot.splash = performance.now();
      }
    }).observe(document, { childList: true, subtree: true });
    if (document.getElementById('eg-splash')) window.__boot.splash = performance.now();
  } catch (e) { window.__boot.error = String(e); }
`;

const READ = `
  (() => {
    const t = window.__egLongTasks || [];
    const dur = t.map((x) => x.dur);
    return JSON.stringify({
      boot: window.__boot || null,
      longTaskCount: t.length,
      longTaskWorstMs: dur.length ? Math.max.apply(null, dur) : 0,
      longTaskTotalMs: dur.reduce((a, b) => a + b, 0),
    });
  })()
`;

function build() {
  console.log('[boot] building web release ...');
  const r = spawnSync(
    'flutter',
    ['build', 'web', '--release', '--no-source-maps'],
    { stdio: 'inherit', shell: true },
  );
  if (r.status !== 0) throw new Error('build failed');
}

async function once(label, server) {
  const chrome = await launch(CDP_PORT, { dpr: 3 });
  const { cdp } = chrome;
  try {
    await prepare(cdp, { dpr: 3 });
    await cdp.send('Network.enable');

    // Cold boot: nothing from a previous visit may answer. The fresh
    // --user-data-dir (see _harness.launch) is what actually guarantees this —
    // the app ships a cache-first service worker, and a registered SW in a
    // reused profile would serve the shell straight from CacheStorage.
    await cdp.send('Network.clearBrowserCache');
    await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
    // Block the service worker for the cold run: this measurement is about the
    // shell download, and a SW registering mid-load only muddies that. Any run
    // that is *about* the SW (--sw, or --repeat, which needs it to have cached
    // the shell) must be allowed to install it.
    if (!ALLOW_SW && !REPEAT) {
      await cdp.send('Network.setBlockedURLs', { urls: ['*sw.js'] }).catch(() => {});
    }

    await cdp.eval(LONG_TASK_OBSERVER).catch(() => {});
    await cdp.send('Page.addScriptToEvaluateOnNewDocument', { source: PROBE });

    if (REPEAT) {
      // Warm-up navigation: let the SW install and precache the shell. Nothing
      // from this leg is reported. The link is unshaped for it on purpose —
      // the precache is ~13MB, so warming it over a 400kbit link takes minutes
      // and would still be downloading when the measured leg starts.
      server.setKbps(0);
      await cdp.send('Network.navigate', {}).catch(() => {});
      await cdp.send('Page.navigate', { url: `http://127.0.0.1:${PORT}/` });
      const warmUntil = Date.now() + BOOT_TIMEOUT_MS;
      while (Date.now() < warmUntil) {
        const ff = await cdp.eval('window.__boot ? window.__boot.flutterFrame : null');
        if (ff) break;
        await sleep(500);
      }
      await sleep(8000); // let the SW finish writing to CacheStorage
      const ready = await cdp.eval(
        'navigator.serviceWorker ? navigator.serviceWorker.ready.then(r => !!r.active) : false',
      );
      if (!ready) throw new Error('repeat run: service worker never activated');
      await cdp.eval('window.__boot = null; window.__egLongTasks = []; true');
      // Now shape the link for the navigation actually being measured.
      server.setKbps(KBPS);
    }

    await cdp.send('Page.navigate', { url: `http://127.0.0.1:${PORT}/` });

    // Poll for the first Flutter frame rather than sleeping a fixed guess:
    // a fixed sleep either wastes time on a fast boot or truncates a slow one.
    const deadline = Date.now() + BOOT_TIMEOUT_MS;
    let firstFrame = null;
    while (Date.now() < deadline) {
      const raw = await cdp.eval('window.__boot ? window.__boot.flutterFrame : null');
      if (raw) {
        firstFrame = raw;
        break;
      }
      await sleep(250);
    }

    // Let any late work (lazy media libs, deferred chunks) land so the long
    // task figures cover the whole boot rather than stopping at first frame.
    await sleep(3000);

    const raw = await cdp.eval(READ);
    const parsed = raw ? JSON.parse(raw) : null;
    const boot = parsed && parsed.boot;

    if (SHOT) {
      const shot = await cdp.send('Page.captureScreenshot', { format: 'png' });
      mkdirSync(dirname(SHOT), { recursive: true });
      writeFileSync(SHOT, Buffer.from(shot.result.data, 'base64'));
    }

    if (!boot || !boot.installed) return { label, installed: false };
    const round = (v) => (v == null ? null : Math.round(v));
    return {
      label,
      installed: true,
      firstInteractiveMs: round(firstFrame),
      fcpMs: round(boot.fcp),
      lcpMs: round(boot.lcp),
      dclMs: round(boot.dcl),
      splashMs: round(boot.splash),
      longTaskCount: parsed.longTaskCount,
      longTaskWorstMs: Math.round(parsed.longTaskWorstMs),
      longTaskTotalMs: Math.round(parsed.longTaskTotalMs),
    };
  } finally {
    chrome.proc.kill();
    cleanup(chrome.userDataDir);
    await sleep(400);
  }
}

async function main() {
  if (has('--build')) build();
  if (!existsSync(resolve(WEB_ROOT, 'index.html'))) {
    throw new Error(`no build to measure. run: node tool/perf/measure_boot.mjs --build`);
  }

  // `no-store` is what makes a first visit genuinely cold, but it also stops the
// service worker from caching anything (the Cache API refuses to store no-store
// responses). So whenever the SW is supposed to be doing its job, the server
// must let it cache — otherwise a "repeat visit" silently re-downloads the
// whole shell and reports roughly double the cold time.
const server = await serve(WEB_ROOT, PORT, {
  kbps: 0,
  noStore: !(ALLOW_SW || REPEAT),
});
  const rows = [];
  try {
    for (let i = 1; i <= RUNS; i++) {
      console.log(`[boot] ${PROFILE} run ${i}/${RUNS} ...`);
      const r = await once(`${PROFILE}-${i}`, server);
      rows.push(r);
      console.log(
        r.installed
          ? `        first interactive ${r.firstInteractiveMs}ms · ` +
              `fcp ${r.fcpMs}ms · worst long task ${r.longTaskWorstMs}ms`
          : '        probe never installed',
      );
    }
  } finally {
    server.close();
  }

  const ok = rows.filter((r) => r.installed && r.firstInteractiveMs != null);
  if (!ok.length) {
    console.log(JSON.stringify({ profile: PROFILE, error: 'no run reached first frame', rows }, null, 2));
    process.exitCode = 1;
    return;
  }
  const med = (k) => median(ok.map((r) => r[k]));

  const firstInteractiveMs = med('firstInteractiveMs');
  const longTaskWorstMs = med('longTaskWorstMs');
  const verdict = {
    firstInteractiveUnder2500ms: firstInteractiveMs < BAR.firstInteractiveMs ? 'YES' : 'NO',
    noLongTaskOver500ms: longTaskWorstMs < BAR.longTaskMs ? 'YES' : 'NO',
  };

  console.log(
    JSON.stringify(
      {
        profile: PROFILE,
        linkKbps: KBPS || 'unshaped',
        visit: REPEAT ? 'repeat (service worker already cached the shell)' : 'first visit',
        serviceWorker: ALLOW_SW || REPEAT ? 'allowed' : 'blocked (cold-download isolation)',
        runs: ok.length,
        bar: BAR,
        verdict,
        median: {
          firstInteractiveMs: Math.round(firstInteractiveMs),
          fcpMs: med('fcpMs'),
          lcpMs: med('lcpMs'),
          dclMs: med('dclMs'),
          splashMs: med('splashMs'),
          longTaskWorstMs: Math.round(longTaskWorstMs),
          longTaskTotalMs: Math.round(med('longTaskTotalMs')),
        },
        details: rows,
      },
      null,
      2,
    ),
  );

  if (verdict.firstInteractiveUnder2500ms === 'NO' || verdict.noLongTaskOver500ms === 'NO') {
    process.exitCode = 1;
  }
}

main().catch((e) => {
  console.error('[boot] failed:', e.message);
  process.exit(1);
});