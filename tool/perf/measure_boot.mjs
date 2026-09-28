// Cold-boot first-paint measurement for the Everglow web shell.
//
// The sub-second-boot criterion needs a real number, and unlike the scroll
// metrics this one is *not* GPU-bound: the splash in web/index.html is inline
// HTML + inline CSS, so it can paint before the 6 MB main.dart.js is even
// requested. That makes it measurable here.
//
// Install observers before navigating (otherwise the paint already happened),
// and leave a marker behind so a run that silently failed to install is
// distinguishable from a genuinely slow one — that distinction is what made
// an earlier attempt of this script return `undefined` and be misread.
//
// Usage: node tool/perf/measure_boot.mjs <port> [profile]
//   profile: none | slow3g | fast3g
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';

const PORT = Number(process.argv[2] || 8980);
const PROFILE = process.argv[3] || 'none';
const CDP_PORT = Number(process.env.CDP_PORT || 9700);
const SHOT = process.env.SHOT_PATH || null;
const RUNS = Number(process.env.RUNS || 3);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Chrome DevTools' own network presets, in bytes/sec.
const PROFILES = {
  none: null,
  fast3g: { offline: false, latency: 150, downloadThroughput: (1.6 * 1024 * 1024) / 8, uploadThroughput: (750 * 1024) / 8 },
  slow3g: { offline: false, latency: 400, downloadThroughput: (400 * 1024) / 8, uploadThroughput: (400 * 1024) / 8 },
};

async function once(label) {
  const chrome = spawn('/usr/local/bin/google-chrome', [
    '--headless=new', `--remote-debugging-port=${CDP_PORT}`, '--no-sandbox',
    '--window-size=430,932', 'about:blank',
  ]);
  await sleep(2200);
  const list = await (await fetch(`http://127.0.0.1:${CDP_PORT}/json/list`)).json();
  const page = list.find((p) => p.type === 'page') || list[0];
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  const pending = new Map();
  let id = 1;
  ws.onmessage = (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
  };
  await new Promise((r) => { ws.onopen = r; });
  const send = (method, params = {}) => new Promise((res) => {
    const c = id++; pending.set(c, res);
    ws.send(JSON.stringify({ id: c, method, params }));
  });

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Network.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 430, height: 932, deviceScaleFactor: 1, mobile: true });

  // Cold boot: nothing from a previous visit may answer.
  await send('Network.clearBrowserCache');
  await send('Network.setCacheDisabled', { cacheDisabled: true });
  if (PROFILES[PROFILE]) {
    await send('Network.emulateNetworkConditions', PROFILES[PROFILE]);
  }

  // Install BEFORE navigating. The marker is set synchronously so a run that
  // never executed this is obvious rather than looking like "very slow".
  await send('Page.addScriptToEvaluateOnNewDocument', {
    source: `
      window.__boot = { installed: performance.now(), fcp: null, lcp: null, dcl: null, splash: null, flutterFrame: null };
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
    `,
  });

  await send('Page.navigate', { url: `http://localhost:${PORT}/` });
  await sleep(15000);

  const r = await send('Runtime.evaluate', {
    expression: 'JSON.stringify(window.__boot || null)', returnByValue: true,
  });
  const raw = r?.result?.result?.value;          // CDP nests: result.result.value
  const boot = raw && raw !== 'null' ? JSON.parse(raw) : null;

  const nav = await send('Performance.getMetrics');
  void nav;

  if (SHOT) {
    const shot = await send('Page.captureScreenshot', { format: 'png' });
    mkdirSync(SHOT.replace(/\/[^/]+$/, ''), { recursive: true });
    writeFileSync(SHOT, Buffer.from(shot.result.data, 'base64'));
  }

  ws.close();
  chrome.kill();
  await sleep(600);

  if (!boot) return { label, installed: false };
  const round = (v) => (v == null ? null : Math.round(v));
  return {
    label,
    installed: true,
    fcpMs: round(boot.fcp),
    lcpMs: round(boot.lcp),
    dclMs: round(boot.dcl),
    splashMs: round(boot.splash),
    flutterFirstFrameMs: round(boot.flutterFrame),
  };
}

async function main() {
  const rows = [];
  for (let i = 1; i <= RUNS; i++) rows.push(await once(`${PROFILE}-${i}`));
  const ok = rows.filter((r) => r.installed);
  if (!ok.length) {
    console.log(JSON.stringify({ profile: PROFILE, error: 'observer never installed', rows }, null, 2));
    return;
  }
  const med = (k) => {
    const v = ok.map((r) => r[k]).filter((x) => x != null).sort((a, b) => a - b);
    return v.length ? v[Math.floor(v.length / 2)] : null;
  };
  console.log(JSON.stringify({
    profile: PROFILE,
    boot: 'cold (cache cleared, service worker bypassed)',
    runs: ok.length,
    median: {
      fcpMs: med('fcpMs'),
      lcpMs: med('lcpMs'),
      dclMs: med('dclMs'),
      splashMs: med('splashMs'),
      flutterFirstFrameMs: med('flutterFirstFrameMs'),
    },
    subSecondFirstPaint: (med('fcpMs') != null && med('fcpMs') < 1000) ? 'YES' : 'NO',
    details: rows,
  }, null, 2));
}

main().catch((e) => { console.error(e); process.exit(1); });
