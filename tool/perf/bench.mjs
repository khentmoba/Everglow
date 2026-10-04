// Desktop/headless shared-widget benchmark, not a calibrated phone measurement.
// node tool/perf/bench.mjs [--build | --web-root DIR] [--runs 3]
//   [--scene shelves,grid] [--throttle 4] [--dpr 3] [--out FILE] [--shot DIR]
// Requires the compile-time bench route, live meter and runtime-only scroll getter.
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  LONG_TASK_OBSERVER, buildWeb, launch, median, prepare, r2,
  readLongTasks, serve, sleep, stop,
} from './_harness.mjs';

const SCENE_PATHS = {shelves:'/perf-bench', grid:'/perf-bench/grid', 'shelves-plain':'/perf-bench/shelves-plain'};
const NUMERIC_FIELDS = [
  'fps','buildAvgMs','buildWorstMs','rasterAvgMs','rasterWorstMs','worstFrameMs',
  'jankPercent','slowFramePercent','frames','devicePixelRatio','sampleSequence',
  'sessionFrames','sessionWorstBuildMs','sessionWorstRasterMs','sessionWorstFrameMs',
  'sessionOver200ms','sessionOverBudgetPercent','sessionSlowFramePercent',
];
export function validateMirror(m, previous) {
  if (!m || NUMERIC_FIELDS.some(k => !Number.isFinite(m[k]) || m[k] < 0)) {
    throw new Error('missing/invalid perf mirror (including cumulative session fields)');
  }
  if (!Number.isInteger(m.sampleSequence) || !Number.isInteger(m.sessionFrames) ||
      m.frames <= 0 || m.sessionFrames <= 0 || m.sampleSequence <= 0 || m.devicePixelRatio <= 0) {
    throw new Error('zero/missing frame samples');
  }
  if (previous) {
    if (m.sampleSequence <= previous.sampleSequence || m.sessionFrames <= previous.sessionFrames) {
      throw new Error('stale perf mirror: no fresh frame samples');
    }
    for (const k of ['sessionWorstBuildMs','sessionWorstRasterMs','sessionWorstFrameMs']) {
      if (m[k] < previous[k]) throw new Error('cumulative session worst was reset/lost');
    }
  }
  return m;
}
export function validateScroll(s, scene) {
  if (!s || s.scene !== scene || !Number.isFinite(s.offset) ||
      !Number.isFinite(s.maxScrollExtent) || s.maxScrollExtent <= 1 ||
      s.offset < -1 || s.offset > s.maxScrollExtent + 1) {
    throw new Error(`wrong/non-scrollable bench scene: expected ${scene}`);
  }
  return s;
}
async function readScroll(cdp, scene) {
  return validateScroll(await cdp.eval(`typeof window.__everglowBenchScroll === 'function'
    ? window.__everglowBenchScroll() : null`),scene);
}
async function readMirror(cdp) { return cdp.eval('window.__everglowPerf || null'); }
async function waitForMirror(cdp, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let reason = 'missing perf mirror';
  while (Date.now() < deadline) {
    try { return validateMirror(await readMirror(cdp)); }
    catch (e) { reason = e.message; }
    await sleep(100);
  }
  throw new Error(`perf mirror timeout: ${reason}`);
}

async function measure(cdp, act, phase, previous) {
  const before = validateMirror(await readMirror(cdp));
  await act();
  // Meter publishes periodically, so include its next reading, not old data.
  await sleep(600);
  const perf = validateMirror(await readMirror(cdp),before);
  if (previous) validateMirror(perf,previous);
  return {
    snapshot:perf,
    phase, fps:perf.fps, rollingWorkJankPct:perf.jankPercent, rollingSlowFramePct:perf.slowFramePercent,
    sessionOver200ms:perf.sessionOver200ms, sessionOverBudgetPct:perf.sessionOverBudgetPercent,
    sessionSlowFramePct:perf.sessionSlowFramePercent,
    avgBuildMs:perf.buildAvgMs, avgRasterMs:perf.rasterAvgMs,
    // Full-session maxima survive the HUD's bounded rolling window.
    worstBuildMs:perf.sessionWorstBuildMs, worstRasterMs:perf.sessionWorstRasterMs,
    worstFrameMs:perf.sessionWorstFrameMs, sessionFrames:perf.sessionFrames,
    freshFrames:perf.sessionFrames-before.sessionFrames, sampleSequence:perf.sampleSequence,
  };
}
// Scripted wheel gestures exercise the scene's real offset; not a phone flick.
async function scrollPass(cdp, scene, steps, settleMs) {
  const initial = await readScroll(cdp,scene);
  let maxOffset = initial.offset;
  for (let i=0; i<steps; i++) {
    await cdp.send('Input.synthesizeScrollGesture', {
      x:215, y:640, yDistance:-190, speed:900, gestureSourceType:'mouse',
    });
    await sleep(100);
    maxOffset = Math.max(maxOffset,(await readScroll(cdp,scene)).offset);
  }
  if (maxOffset <= initial.offset + 1) throw new Error('scroll pass did not move the actual scroll offset down');
  let minOffset = maxOffset;
  for (let i=0; i<steps; i++) {
    await cdp.send('Input.synthesizeScrollGesture', {
      x:215, y:640, yDistance:150, speed:900, gestureSourceType:'mouse',
    });
    await sleep(100);
    minOffset = Math.min(minOffset,(await readScroll(cdp,scene)).offset);
  }
  if (minOffset >= maxOffset - 1) throw new Error('scroll pass did not move the actual scroll offset back up');
  await sleep(settleMs);
  return {initial:initial.offset, maxOffset, final:(await readScroll(cdp,scene)).offset};
}

async function runScene(scene, run, url, options) {
  const chrome = await launch(options.cdpPort,{dpr:options.dpr});
  const {cdp} = chrome;
  const row = {scene,run};
  try {
    await prepare(cdp,{dpr:options.dpr});
    await cdp.send('Network.enable');
    await cdp.send('Network.clearBrowserCache');
    await cdp.send('Network.setCacheDisabled',{cacheDisabled:false});
    await cdp.send('Network.setBypassServiceWorker',{bypass:true});
    await cdp.send('Network.setBlockedURLs',{urls:['*sw.js*']});
    await cdp.send('Emulation.setCPUThrottlingRate',{rate:options.throttle});
    // Observe the WHOLE navigation/session, including load and idle. Never clear
    // tasks between phases: late good samples must not erase an earlier freeze.
    await cdp.send('Page.addScriptToEvaluateOnNewDocument',{source:LONG_TASK_OBSERVER});
    const before = await cdp.eval('performance.timeOrigin');
    const nav = await cdp.send('Page.navigate',{url:`${url}${SCENE_PATHS[scene]}?perf=1`});
    if (nav.result?.errorText) throw new Error(nav.result.errorText);
    const initial = await waitForMirror(cdp,options.timeoutMs);
    await sleep(options.settleMs);
    const doc = await cdp.eval('({path:location.pathname,timeOrigin:performance.timeOrigin,stamp:window.__EVERGLOW_BUILD__})');
    if (doc.path !== SCENE_PATHS[scene]) throw new Error(`wrong bench route: ${doc.path}`);
    if (doc.timeOrigin === before) throw new Error('bench did not open a fresh document');
    if (typeof doc.stamp !== 'string' || !doc.stamp) throw new Error('missing production build stamp; use --build or a stamped --web-root');
    row.build = doc.stamp;
    await readLongTasks(cdp); // missing/unsupported instrumentation is an error
    await readScroll(cdp,scene);
    row.idle = await measure(cdp,() => sleep(options.idleMs),'idle',initial);
    let movement;
    row.scroll = await measure(cdp,async () => {
      movement = await scrollPass(cdp,scene,options.scrollSteps,options.scrollSettleMs);
    },'scroll',row.idle.snapshot);
    row.movement = movement;
    row.renderer = await cdp.eval(`(() => {
      const c = document.createElement('canvas');
      const gl = c.getContext('webgl2') || c.getContext('webgl');
      if (!gl) return 'no-context';
      const d = gl.getExtension('WEBGL_debug_renderer_info');
      return String(gl.getParameter(d ? d.UNMASKED_RENDERER_WEBGL : gl.RENDERER));
    })()`);
    if (options.shotDir) {
      const path = join(options.shotDir,`${scene}-${run}.png`);
      mkdirSync(dirname(path),{recursive:true});
      const shot = await cdp.send('Page.captureScreenshot',{format:'png'});
      writeFileSync(path,Buffer.from(shot.result.data,'base64'));
    }
    row.longTasks = await readLongTasks(cdp);
    if (row.longTasks.overBar > 0) row.error = 'full session exceeded the 200ms long-task budget';
  } catch (e) {
    row.error = e.message;
    try { row.longTasks = await readLongTasks(cdp); }
    catch (e) { row.instrumentationError = e.message; }
  } finally { await stop(chrome); }
  return row;
}

export function aggregate(runs, expectedRuns) {
  if (runs.length !== expectedRuns || runs.some(r => r.error || !r.idle || !r.scroll || !r.longTasks)) return null;
  const phase = (name) => ({
    fps:median(runs.map(r => r[name].fps)),
    avgBuildMs:median(runs.map(r => r[name].avgBuildMs)),
    avgRasterMs:median(runs.map(r => r[name].avgRasterMs)),
    worstBuildMs:Math.max(...runs.map(r => r[name].worstBuildMs)),
    worstRasterMs:Math.max(...runs.map(r => r[name].worstRasterMs)),
    worstFrameMs:Math.max(...runs.map(r => r[name].worstFrameMs)),
  });
  return {idle:phase('idle'),scroll:phase('scroll'),
    longTaskWorstMs:Math.max(...runs.map(r => r.longTasks.worstMs))};
}
export function benchPassed(results, scenes, expectedRuns) {
  return scenes.every(scene => results[scene]?.length === expectedRuns && results[scene].every(r =>
    !r.error && r.idle?.freshFrames > 0 && r.scroll?.freshFrames > 0 &&
    Number.isFinite(r.longTasks?.worstMs) && r.longTasks.worstMs <= 200));
}

export function markdown(results, options) {
  const passed = benchPassed(results,options.scenes,options.runs);
  const lines = [
    '# Perf baseline','',`Verdict: **${passed ? 'PASS' : 'FAIL'}** · every requested run must complete; no long task >200ms.`,
    '',`Desktop/headless · 430x932 @ DPR ${options.dpr} · CPU throttle ${options.throttle}x · ${options.runs} runs per scene.`,
    '', 'Synthetic viewport/CPU settings are **not phone-calibrated**. This does not prove phone FPS,',
    'presentation/dropped frames, interactivity, offline support, or feature-screen performance.',
    'Rolling HUD FPS/work percentages are diagnostic only. Build/raster averages are final rolling',
    'readings summarized by median; worst frame/build/raster values are cumulative session maxima',
    '(including load/settle), maximized across ALL runs. No minimum/median of worsts is a guarantee.',
    '', '| scene | phase | FPS median (diagnostic) | build avg median ms | raster avg median ms | session worst build ms | session worst raster ms | session worst frame ms | session worst long task ms |',
    '| --- | --- | --- | --- | --- | --- | --- | --- | --- |',
  ];
  for (const scene of options.scenes) {
    const a = aggregate(results[scene] || [],options.runs);
    if (!a) { lines.push(`| ${scene} | incomplete/failed — no aggregate | | | | | | | |`); continue; }
    for (const phase of ['idle','scroll']) {
      const p = a[phase];
      lines.push(`| ${scene} | ${phase} | ${r2(p.fps)} | ${r2(p.avgBuildMs)} | ${r2(p.avgRasterMs)} | ${r2(p.worstBuildMs)} | ${r2(p.worstRasterMs)} | ${r2(p.worstFrameMs)} | ${r2(a.longTaskWorstMs)} |`);
    }
  }
  lines.push('','## All raw runs','', '```json',JSON.stringify(results,null,2),'```','');
  return lines.join('\n');
}

export async function main(argv = process.argv.slice(2)) {
  const flag = (n,d) => argv.includes(n) ? argv[argv.lastIndexOf(n)+1] : d;
  const options = {
    runs:Number(flag('--runs',3)), throttle:Number(flag('--throttle',4)), dpr:Number(flag('--dpr',3)),
    scenes:flag('--scene','shelves,grid').split(','), cdpPort:Number(process.env.CDP_PORT || 0),
    timeoutMs:Number(flag('--timeout-ms',30000)), settleMs:Number(flag('--settle-ms',process.env.SETTLE_MS || 9000)),
    idleMs:Number(flag('--idle-ms',5000)), scrollSteps:Number(flag('--scroll-steps',10)),
    scrollSettleMs:Number(flag('--scroll-settle-ms',2000)), shotDir:flag('--shot',null),
  };
  if (!Number.isInteger(options.runs) || options.runs < 1 ||
      !Number.isInteger(options.scrollSteps) || options.scrollSteps < 1 ||
      options.scenes.some(s => !SCENE_PATHS[s]) || !options.scenes.length ||
      new Set(options.scenes).size !== options.scenes.length ||
      ['throttle','dpr','timeoutMs','idleMs'].some(k => !Number.isFinite(options[k]) || options[k] <= 0) ||
      ['settleMs','scrollSettleMs'].some(k => !Number.isFinite(options[k]) || options[k] < 0)) throw new Error('invalid bench arguments');
  const root = resolve(flag('--web-root','build/web'));
  if (argv.includes('--build')) {
    if (root !== resolve('build/web')) throw new Error('--build writes build/web; do not combine with a different --web-root');
    buildWeb(true);
  }
  if (!existsSync(join(root,'index.html'))) throw new Error('no web artifact; use --build or --web-root');
  const server = await serve(root,Number(flag('--port',8946)));
  const url = `http://127.0.0.1:${server.address().port}`;
  const results = {};
  try {
    for (const scene of options.scenes) {
      results[scene] = [];
      for (let i=1; i<=options.runs; i++) {
        console.log(`[bench] ${scene} ${i}/${options.runs}`);
        let r;
        try { r = await runScene(scene,i,url,options); }
        catch (e) { r = {scene,run:i,error:e.message}; }
        results[scene].push(r);
        console.log(JSON.stringify(r));
      }
    }
  } finally { server.closeAllConnections(); server.close(); }
  const out = flag('--out','docs/perf-baseline.md');
  writeFileSync(out,markdown(results,options));
  console.log(`[bench] wrote ${out}`);
  if (!benchPassed(results,options.scenes,options.runs)) process.exitCode = 1;
  return results;
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch(e => {console.error('[bench] failed:',e.message); process.exitCode = 1;});
}
