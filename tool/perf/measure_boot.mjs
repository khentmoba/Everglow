// Usage: node tool/perf/measure_boot.mjs [--build | --web-root DIR]
//        [--runs 3] [--profile slow3g|fast3g|none] [--repeat]
// --sw alone is rejected: a newly installing worker cannot be shaped in time.
// flutter-first-frame is a frame marker, NOT proof that the UI is clickable.
// Repeat measures a new document with a controlled SW and cached stamped core.
// This is an online shaped-link test, never a claim of fully offline support.
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  LONG_TASK_OBSERVER, NETWORK_PROFILES, buildWeb, launch, median, prepare,
  readLongTasks, serve, shapeNetwork, sleep, stop,
} from './_harness.mjs';

export const BOOT_PROBE = `
  window.__boot = {timeOrigin: performance.timeOrigin, fcp: null, lcp: null,
    dcl: null, splash: null, flutterFrame: null, error: null};
  try {
    new PerformanceObserver(l => {
      for (const e of l.getEntries()) if (e.name === 'first-contentful-paint') window.__boot.fcp = e.startTime;
    }).observe({type:'paint', buffered:true});
    new PerformanceObserver(l => {
      for (const e of l.getEntries()) window.__boot.lcp = e.startTime;
    }).observe({type:'largest-contentful-paint', buffered:true});
    document.addEventListener('DOMContentLoaded', () => {window.__boot.dcl = performance.now();});
    window.addEventListener('flutter-first-frame', () => {window.__boot.flutterFrame ??= performance.now();});
    new MutationObserver(() => {
      if (window.__boot.splash === null && document.getElementById('eg-splash')) window.__boot.splash = performance.now();
    }).observe(document, {childList:true, subtree:true});
  } catch (e) {window.__boot.error = String(e);}
`;

export function summarizeBoot(rows, expectedRuns, frameBudgetMs = 2500) {
  const complete = rows.length === expectedRuns && rows.every(r =>
    !r.error && Number.isFinite(r.firstFlutterFrameMs) && r.firstFlutterFrameMs > 0 &&
    Number.isFinite(r.longTaskWorstMs) && r.longTaskWorstMs >= 0 &&
    Number.isInteger(r.longTaskCount) && r.longTaskCount >= 0);
  const verdict = {
    complete,
    allFirstFlutterFramesWithinBudget: complete && rows.every(r => r.firstFlutterFrameMs < frameBudgetMs),
    noLongTaskOver200ms: complete && rows.every(r => r.longTaskWorstMs <= 200),
  };
  return {
    requestedRuns: expectedRuns, recordedRuns: rows.length,
    bar: { firstFlutterFrameMs: frameBudgetMs, longTaskMs: 200 }, verdict,
    // No passing median can be made by silently removing missing/timed-out runs.
    median: complete ? { firstFlutterFrameMs: median(rows.map(r => r.firstFlutterFrameMs)) } : null,
    worst: complete ? {
      firstFlutterFrameMs: Math.max(...rows.map(r => r.firstFlutterFrameMs)),
      longTaskMs: Math.max(...rows.map(r => r.longTaskWorstMs)),
    } : null,
    details: rows,
  };
}

async function firstFrame(cdp, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const boot = await cdp.eval('window.__boot || null');
    if (boot?.error) throw new Error(`boot probe: ${boot.error}`);
    if (Number.isFinite(boot?.flutterFrame) && boot.flutterFrame > 0) return boot;
    await sleep(100);
  }
  throw new Error(`first Flutter frame timeout after ${timeoutMs}ms`);
}

// Must inspect the actual stamped core resource, not assume an 8s wait warmed it.
async function cachedCore(cdp, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const ready = await cdp.eval(`(async () => {
      const controller = navigator.serviceWorker?.controller;
      if (!controller || controller.state !== 'activated') return null;
      const stamp = window.__EVERGLOW_BUILD__;
      if (typeof stamp !== 'string' || !stamp) throw new Error('repeat requires a stamped production artifact');
      const core = performance.getEntriesByType('resource').find(r => {
        const u = new URL(r.name);
        const v = /[?&]v=([^&]+)/.exec(u.search);
        return u.origin === location.origin && u.pathname.endsWith('/main.dart.js') &&
          v && decodeURIComponent(v[1]) === stamp;
      });
      if (!core || !(await caches.match(core.name))) return null;
      return {stamp, coreUrl:core.name, workerUrl:controller.scriptURL, timeOrigin:performance.timeOrigin};
    })()`);
    if (ready) return ready;
    await sleep(150);
  }
  throw new Error('repeat warm-up timeout: no controlled worker with cached stamped core');
}

async function once(label, url, options) {
  const chrome = await launch(options.cdpPort);
  const { cdp } = chrome;
  let result = { label };
  try {
    await prepare(cdp);
    await cdp.send('Network.enable');
    await cdp.send('Network.clearBrowserCache');
    await cdp.send('Page.addScriptToEvaluateOnNewDocument', {source: LONG_TASK_OBSERVER + BOOT_PROBE});
    await cdp.send('Network.setBypassServiceWorker', {bypass: !options.sw && !options.repeat});
    if (!options.sw && !options.repeat) await cdp.send('Network.setBlockedURLs', {urls:['*sw.js*']});
    let warm;
    if (options.repeat) {
      await shapeNetwork(cdp, 'none');
      await cdp.send('Network.setCacheDisabled', {cacheDisabled:false});
      const nav = await cdp.send('Page.navigate', {url});
      if (nav.result?.errorText) throw new Error(nav.result.errorText);
      await firstFrame(cdp, options.timeoutMs);
      warm = await cachedCore(cdp, options.timeoutMs);
      // Leave the old document; navigating to an identical URL is not proof of
      // a fresh timeOrigin. Keep the warmed worker in this disposable profile.
      await cdp.send('Page.navigate', {url:'about:blank'});
      result.warm = warm;
    }
    // Fresh profiles + no-store responses isolate cold HTTP requests. Clear the
    // warm HTTP cache without destroying CacheStorage. On Chrome, disabling the
    // cache through CDP can hide initial script long tasks (regression control).
    await cdp.send('Network.clearBrowserCache');
    await cdp.send('Network.setCacheDisabled', {cacheDisabled:false});
    await shapeNetwork(cdp, options.profile); // applies to COLD runs too
    if (options.repeat) {
      // Worker fetches have their own target. Page-only emulation is insufficient.
      const targets = await cdp.send('Target.getTargets');
      const workers = targets.result.targetInfos.filter(t => t.type === 'service_worker' && t.url === warm.workerUrl);
      if (!workers.length) throw new Error('controlled worker target missing; cannot apply network shaping');
      for (const t of workers) {
        const attached = await cdp.send('Target.attachToTarget', {targetId:t.targetId, flatten:true});
        await shapeNetwork(cdp, options.profile, attached.result.sessionId);
      }
    }
    const before = await cdp.eval('performance.timeOrigin');
    const nav = await cdp.send('Page.navigate', {url:`${url}?eg-perf-run=${encodeURIComponent(label)}`});
    if (nav.result?.errorText) throw new Error(nav.result.errorText);
    const boot = await firstFrame(cdp, options.timeoutMs);
    await sleep(options.settleMs);
    const tasks = await readLongTasks(cdp);
    const document = await cdp.eval(`({timeOrigin:performance.timeOrigin, stamp:window.__EVERGLOW_BUILD__,
      controlled:!!navigator.serviceWorker?.controller,
      localResources:performance.getEntriesByType('resource').filter(r => new URL(r.name).origin === location.origin).map(r => ({
        path:new URL(r.name).pathname, durationMs:r.duration, encodedBodyBytes:r.encodedBodySize,
        decodedBodyBytes:r.decodedBodySize, transferBytes:r.transferSize
      }))})`);
    if (boot.timeOrigin !== document.timeOrigin || document.timeOrigin === before ||
        (warm && document.timeOrigin === warm.timeOrigin)) throw new Error('boot reused the previous document/timeOrigin');
    if (typeof document.stamp !== 'string' || !document.stamp) throw new Error('missing production build stamp; use --build or a stamped --web-root');
    if (warm && (!document.controlled || document.stamp !== warm.stamp)) throw new Error('repeat lost its controlled worker/build stamp');
    result = {
      ...result, build: document.stamp, timeOrigin: document.timeOrigin,
      firstFlutterFrameMs: boot.flutterFrame, fcpMs: boot.fcp, lcpMs: boot.lcp,
      dclMs: boot.dcl, splashMs: boot.splash, longTaskCount: tasks.count,
      longTaskWorstMs: tasks.worstMs, longTaskTotalMs: tasks.totalMs,
      longTaskOver200ms: tasks.overBar, localResources: document.localResources,
    };
    if (options.shot) {
      const shot = await cdp.send('Page.captureScreenshot', {format:'png'});
      mkdirSync(dirname(options.shot), {recursive:true});
      writeFileSync(options.shot, Buffer.from(shot.result.data, 'base64'));
    }
  } catch (e) {
    result.error = e.message;
    // Keep useful freeze evidence even if the first-frame marker timed out.
    try {
      const t = await readLongTasks(cdp);
      Object.assign(result, {longTaskCount:t.count, longTaskWorstMs:t.worstMs, longTaskOver200ms:t.overBar});
    } catch (instrumentation) { result.instrumentationError = instrumentation.message; }
  } finally { await stop(chrome); }
  return result;
}

export async function main(argv = process.argv.slice(2)) {
  const flag = (n, d) => argv.includes(n) ? argv[argv.lastIndexOf(n) + 1] : d;
  const options = {
    runs:Number(flag('--runs',3)), profile:flag('--profile','slow3g'),
    repeat:argv.includes('--repeat'), sw:argv.includes('--sw'),
    timeoutMs:Number(flag('--timeout-ms',process.env.BOOT_TIMEOUT_MS || 40000)),
    settleMs:Number(flag('--settle-ms',3000)), frameBudgetMs:Number(flag('--frame-budget-ms',2500)),
    cdpPort:Number(process.env.CDP_PORT || 0), shot:flag('--shot',null),
  };
  if (!Number.isInteger(options.runs) || options.runs < 1 ||
      !NETWORK_PROFILES[options.profile] || options.timeoutMs <= 0 || !Number.isFinite(options.timeoutMs) ||
      options.settleMs < 0 || !Number.isFinite(options.settleMs) ||
      options.frameBudgetMs <= 0 || !Number.isFinite(options.frameBudgetMs)) throw new Error('invalid boot arguments');
  if (options.sw && !options.repeat) throw new Error('--sw alone cannot isolate cold shaping; use --repeat or omit --sw');
  const root = resolve(flag('--web-root','build/web'));
  if (argv.includes('--build')) {
    if (root !== resolve('build/web')) throw new Error('--build writes build/web; do not combine with a different --web-root');
    buildWeb();
  }
  if (!existsSync(join(root,'index.html'))) throw new Error('no web artifact; use --build or --web-root');
  const server = await serve(root,Number(flag('--port',8971))); // CacheStorage may still cache no-store responses
  const url = `http://127.0.0.1:${server.address().port}/`;
  const rows = [];
  try {
    for (let i=1; i<=options.runs; i++) {
      console.log(`[boot] ${options.profile} run ${i}/${options.runs}`);
      try { rows.push(await once(`${options.profile}-${i}`,url,options)); }
      catch (e) { rows.push({label:`${options.profile}-${i}`,error:e.message}); }
    }
  } finally { server.closeAllConnections(); server.close(); }
  const report = {
    profile:options.profile, link:NETWORK_PROFILES[options.profile], webRoot:root,
    visit:options.repeat ? 'repeat: controlled SW + cached stamped core; new document' : 'cold: fresh profile, uncached requests, SW bypassed',
    note:'CDP synthetic link on desktop; firstFlutterFrame is not interactivity; no offline/device guarantee. Local ResourceTiming encoded body bytes reflect compression, not filesystem size.',
    ...summarizeBoot(rows,options.runs,options.frameBudgetMs),
  };
  console.log(JSON.stringify(report,null,2));
  if (Object.values(report.verdict).some(v => !v)) process.exitCode = 1;
  return report;
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch(e => {console.error('[boot] failed:',e.message); process.exitCode = 1;});
}
