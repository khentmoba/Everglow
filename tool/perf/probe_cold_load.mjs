// Cold-load resource probe: records EVERY network resource (including
// cross-origin CanvasKit / Firebase SDK), not just same-origin ones, plus
// time-to-first-Flutter-frame.
//
// Usage: node tool/perf/probe_cold_load.mjs [--web-root DIR] [--runs N]
//        [--profile none|fast3g|slow3g] [--out FILE]
import { existsSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  NETWORK_PROFILES, launch, prepare, serve, shapeNetwork, sleep, stop, median,
} from './_harness.mjs';

const PROBE = `
  window.__probe = {timeOrigin: performance.timeOrigin, fcp: null, flutterFrame: null,
    firestoreFirstDoc: null, firestoreListenStart: null};
  try {
    new PerformanceObserver(l => {
      for (const e of l.getEntries()) if (e.name === 'first-contentful-paint') window.__probe.fcp = e.startTime;
    }).observe({type:'paint', buffered:true});
    window.addEventListener('flutter-first-frame', () => {window.__probe.flutterFrame ??= performance.now();});
  } catch (e) { window.__probe.error = String(e); }
`;

async function once(url, options) {
  const chrome = await launch(options.cdpPort);
  const { cdp } = chrome;
  const out = { profile: options.profile };
  try {
    await prepare(cdp);
    await cdp.send('Network.enable');
    await cdp.send('Network.clearBrowserCache');
    await cdp.send('Page.addScriptToEvaluateOnNewDocument', { source: PROBE });
    // Cold means cold: no service worker, no HTTP cache.
    await cdp.send('Network.setBypassServiceWorker', { bypass: true });
    await cdp.send('Network.setBlockedURLs', { urls: ['*sw.js*'] });
    await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
    await shapeNetwork(cdp, options.profile);
    const nav = await cdp.send('Page.navigate', { url });
    if (nav.result?.errorText) throw new Error(nav.result.errorText);

    const deadline = Date.now() + options.timeoutMs;
    let probe = null;
    while (Date.now() < deadline) {
      probe = await cdp.eval('window.__probe || null');
      if (probe?.error) throw new Error(`probe: ${probe.error}`);
      if (Number.isFinite(probe?.flutterFrame) && probe.flutterFrame > 0) break;
      await sleep(100);
    }
    if (!Number.isFinite(probe?.flutterFrame)) throw new Error('first Flutter frame timeout');
    await sleep(options.settleMs);

    const doc = await cdp.eval(`(() => {
      const entries = performance.getEntriesByType('resource');
      return {
        timeOrigin: performance.timeOrigin,
        stamp: window.__EVERGLOW_BUILD__ || null,
        resources: entries.map(r => ({
          url: r.name,
          startMs: r.startTime,
          durationMs: r.duration,
          transferBytes: r.transferSize,
          encodedBodyBytes: r.encodedBodySize,
          decodedBodyBytes: r.decodedBodySize,
        })),
      };
    })()`);
    out.firstFlutterFrameMs = probe.flutterFrame;
    out.fcpMs = probe.fcp;
    out.stamp = doc.stamp;
    out.resources = doc.resources;
    out.totalTransferBytes = doc.resources.reduce((s, r) => s + (r.transferBytes || 0), 0);
    out.totalDecodedBytes = doc.resources.reduce((s, r) => s + (r.decodedBodyBytes || 0), 0);
    const wasm = doc.resources.filter(r => /canvaskit.*\.wasm/.test(r.url));
    out.canvaskit = wasm.map(r => ({ url: r.url, bytes: r.transferBytes || r.encodedBodyBytes }));
    const fb = doc.resources.filter(r => /firebasejs|firestore\.googleapis|identitytoolkit|securetoken/.test(r.url));
    out.firebase = fb.map(r => ({ url: r.url, startMs: r.startMs, durationMs: r.durationMs, bytes: r.transferBytes || r.encodedBodyBytes }));
    const gf = doc.resources.filter(r => /fonts\.gstatic\.com/.test(r.url));
    out.googleFonts = gf.map(r => ({ url: r.url.split('/').pop(), bytes: r.transferBytes || r.encodedBodyBytes }));
    out.googleFontsBytes = out.googleFonts.reduce((s, r) => s + r.bytes, 0);
  } catch (e) {
    out.error = e.message;
  } finally {
    await stop(chrome);
  }
  return out;
}

async function main(argv = process.argv.slice(2)) {
  const flag = (n, d) => (argv.includes(n) ? argv[argv.lastIndexOf(n) + 1] : d);
  const options = {
    runs: Number(flag('--runs', 1)),
    profile: flag('--profile', 'none'),
    timeoutMs: Number(flag('--timeout-ms', 60000)),
    settleMs: Number(flag('--settle-ms', 4000)),
    cdpPort: Number(process.env.CDP_PORT || 0),
  };
  if (!NETWORK_PROFILES[options.profile]) throw new Error(`unknown profile ${options.profile}`);
  const root = resolve(flag('--web-root', 'build/web'));
  if (!existsSync(`${root}/index.html`)) throw new Error(`no web artifact at ${root}`);
  const server = await serve(root, Number(flag('--port', 8977)));
  const path = flag('--path', '/');
  const url = `http://127.0.0.1:${server.address().port}${path}`;
  const rows = [];
  try {
    for (let i = 1; i <= options.runs; i++) {
      console.log(`[probe] ${options.profile} run ${i}/${options.runs}`);
      rows.push(await once(url, options));
    }
  } finally {
    server.closeAllConnections();
    server.close();
  }
  const ok = rows.filter(r => !r.error);
  const report = {
    profile: options.profile,
    webRoot: root,
    path,
    runs: rows.length,
    okRuns: ok.length,
    medianFirstFlutterFrameMs: ok.length ? median(ok.map(r => r.firstFlutterFrameMs)) : null,
    medianTransferBytes: ok.length ? median(ok.map(r => r.totalTransferBytes)) : null,
    details: rows,
  };
  const out = flag('--out', null);
  if (out) {
    mkdirSync(dirname(resolve(out)), { recursive: true });
    writeFileSync(resolve(out), JSON.stringify(report, null, 1));
  }
  for (const r of rows) {
    if (r.error) { console.log(`  ERROR ${r.error}`); continue; }
    console.log(`  firstFlutterFrame=${Math.round(r.firstFlutterFrameMs)}ms fcp=${Math.round(r.fcpMs)}ms`);
    console.log(`  transfer=${r.totalTransferBytes.toLocaleString()}B decoded=${r.totalDecodedBytes.toLocaleString()}B`);
    console.log(`  canvaskit=${JSON.stringify(r.canvaskit)}`);
    console.log(`  googleFonts=${r.googleFontsBytes.toLocaleString()}B over ${r.googleFonts.length} files`);
    for (const f of r.firebase) console.log(`  firebase ${f.url.split('/').pop()} start=${Math.round(f.startMs)}ms dur=${Math.round(f.durationMs)}ms ${f.bytes}B`);
  }
  return report;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((e) => { console.error(e); process.exit(1); });
}
export { main, once };
