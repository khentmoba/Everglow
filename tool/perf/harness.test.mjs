// node --test tool/perf/harness.test.mjs (Node 22+, no npm packages).
// CI sets PERF_REQUIRE_CHROME=1: the browser fault controls may not be skipped.
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import fs from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawn } from 'node:child_process';
import childProcess from 'node:child_process';
import { syncBuiltinESMExports } from 'node:module';
import { EventEmitter } from 'node:events';
import { PassThrough } from 'node:stream';
import { randomBytes } from 'node:crypto';
import vm from 'node:vm';
import {
  Cdp, LONG_TASK_OBSERVER, NETWORK_PROFILES, chromePath,
  readLongTasks, shapeNetwork, cleanup, launch, stop,
} from './_harness.mjs';
import { summarizeBoot } from './measure_boot.mjs';
import { aggregate, benchPassed, markdown, validateMirror, validateScroll } from './bench.mjs';

const mirror = (overrides = {}) => ({
  fps:60,buildAvgMs:1,buildWorstMs:2,rasterAvgMs:1,rasterWorstMs:2,worstFrameMs:4,
  jankPercent:0,slowFramePercent:0,frames:10,devicePixelRatio:3,sampleSequence:1,
  sessionFrames:10,sessionWorstBuildMs:2,sessionWorstRasterMs:2,sessionWorstFrameMs:4,
  sessionOver200ms:0,sessionOverBudgetPercent:0,sessionSlowFramePercent:0,...overrides,
});
const goodBoot = {firstFlutterFrameMs:100,longTaskWorstMs:0,longTaskCount:0};
const phase = {fps:60,avgBuildMs:1,avgRasterMs:2,worstBuildMs:3,worstRasterMs:4,worstFrameMs:10,freshFrames:10};
const run = (overrides = {}) => ({idle:{...phase},scroll:{...phase},longTasks:{worstMs:0,overBar:0},...overrides});

test('bench source uses public fixtures only; frame-stat browser tests stay platform-neutral', () => {
  const source = readFileSync(new URL('../../lib/core/perf/perf_bench_route.dart',import.meta.url),'utf8');
  assert.match(source,/\/perf-fixtures\//);
  assert.doesNotMatch(source,/milestones/i);
  for (let i=1; i<=4; i++) {
    const name = `poster-${i}.jpg`;
    assert.ok(source.includes(`'${name}'`),`bench must reference ${name}`);
    assert.ok(existsSync(new URL(`../../web/perf-fixtures/${name}`,import.meta.url)),`missing public fixture ${name}`);
  }
  const frameTests = readFileSync(new URL('../../test/core/perf/frame_stats_test.dart',import.meta.url),'utf8');
  assert.doesNotMatch(frameTests,/dart:io/);
});

test('CDP rejects protocol/evaluation errors, timeouts and closed sockets', async () => {
  const ws = {send(s) {this.sent = JSON.parse(s);},close() {}};
  const cdp = new Cdp(ws,{timeoutMs:30});
  let p = cdp.send('Network.bad');
  ws.onmessage({data:JSON.stringify({id:ws.sent.id,error:{code:-32601,message:'not found'}})});
  await assert.rejects(p,/Network.bad.*not found/);
  p = cdp.eval('bad()');
  ws.onmessage({data:JSON.stringify({id:ws.sent.id,result:{exceptionDetails:{text:'Uncaught',exception:{description:'fixture exploded'}}}})});
  await assert.rejects(p,/fixture exploded/);
  await assert.rejects(cdp.send('Hung.command'),/Hung.command.*timeout/);
  p = cdp.send('Pending.command');
  ws.onclose();
  await assert.rejects(p,/socket closed/);
  await assert.rejects(cdp.send('Later.command'),/socket closed/);
  assert.equal(cdp.pending.size,0);
});

test('network profile uses checked CDP latency and decimal aggregate throughput', async () => {
  const calls = [];
  const cdp = {async send(...args) {calls.push(args); return {result:{}};}};
  await shapeNetwork(cdp,'slow3g','worker-session');
  assert.deepEqual(calls[1],[
    'Network.emulateNetworkConditions',
    {offline:false,latency:400,downloadThroughput:50000,uploadThroughput:50000},
    {sessionId:'worker-session'},
  ]);
  assert.equal(NETWORK_PROFILES.slow3g.downloadKbps,400);
  await assert.rejects(shapeNetwork(cdp,'imaginary'),/unknown network profile/);
  await assert.rejects(shapeNetwork({send:async () => {throw new Error('CDP unsupported');}},'slow3g'),/unsupported/);
});

test('missing/unsupported observer cannot be interpreted as zero long tasks', async () => {
  const context = {window:{},performance:{timeOrigin:123}};
  const cdp = {eval:async expression => vm.runInNewContext(expression,context)};
  await assert.rejects(readLongTasks(cdp),/instrumentation missing/);
  context.PerformanceObserver = class {static supportedEntryTypes = [];};
  vm.runInNewContext(LONG_TASK_OBSERVER,context);
  await assert.rejects(readLongTasks(cdp),/unsupported/);
  context.PerformanceObserver = class {
    static supportedEntryTypes = ['longtask'];
    observe() {}
    takeRecords() {return [{duration:350,startTime:50}];}
  };
  vm.runInNewContext(LONG_TASK_OBSERVER,context);
  const tasks = await readLongTasks(cdp);
  assert.equal(tasks.worstMs,350);
  assert.equal(tasks.overBar,1);
  context.performance.timeOrigin++;
  await assert.rejects(readLongTasks(cdp),/instrumentation missing/);
});

test('all requested boots count: timeout, missing sample and single 350ms outlier fail', () => {
  assert.equal(summarizeBoot([goodBoot,goodBoot,{...goodBoot,longTaskWorstMs:350}],3).verdict.noLongTaskOver200ms,false);
  for (const rows of [[goodBoot], [goodBoot,{error:'timeout'}], [goodBoot,{...goodBoot,firstFlutterFrameMs:null}]]) {
    const report = summarizeBoot(rows,2);
    assert.equal(report.verdict.complete,false);
    assert.equal(report.median,null);
  }
  assert.equal(summarizeBoot([goodBoot,{...goodBoot,firstFlutterFrameMs:3000},goodBoot],3).verdict.allFirstFlutterFramesWithinBudget,false);
  assert.equal(summarizeBoot([goodBoot],1).verdict.noLongTaskOver200ms,true);
});

test('fresh nonzero cumulative frame samples and actual scene/scroll extent are required', () => {
  assert.throws(() => validateMirror(mirror({frames:0,sessionFrames:0})),/zero/);
  assert.throws(() => validateMirror(null),/missing/);
  assert.throws(() => validateMirror(mirror({sampleSequence:2}),mirror()),/stale/);
  assert.throws(() => validateMirror(mirror({sampleSequence:2,sessionFrames:11,sessionWorstFrameMs:1}),mirror()),/worst was reset/);
  validateMirror(mirror({sampleSequence:2,sessionFrames:11}),mirror());
  assert.throws(() => validateScroll({scene:'shelves',offset:0,maxScrollExtent:0},'shelves'),/non-scrollable/);
  assert.throws(() => validateScroll({scene:'grid',offset:10,maxScrollExtent:100},'shelves'),/wrong/);
  assert.throws(() => validateScroll({scene:'shelves',offset:Infinity,maxScrollExtent:100},'shelves'),/non-scrollable/);
});

test('aggregates preserve maximum session worsts; incomplete benches cannot produce passing reports', () => {
  const runs = [run(),run({scroll:{...phase,worstFrameMs:350}}),run()];
  assert.equal(aggregate(runs,3).scroll.worstFrameMs,350);
  assert.equal(aggregate(runs,4),null);
  const results = {shelves:[run(),run({longTasks:{worstMs:350,overBar:1}}),run()]};
  assert.equal(benchPassed(results,['shelves'],3),false);
  assert.equal(benchPassed({shelves:[run()]},['shelves'],2),false);
  const report = markdown(results,{scenes:['shelves'],runs:3,dpr:3,throttle:4});
  assert.match(report,/\*\*FAIL\*\*/);
  assert.match(report,/not phone-calibrated/);
  assert.doesNotMatch(report,/phone-representable|Gate on the `min`/);
});

test('cleanup refuses unrelated directories', () => {
  assert.throws(() => cleanup(tmpdir()),/Refusing/);
});

let chrome;
try { chrome = chromePath(); }
catch (e) { if (process.env.PERF_REQUIRE_CHROME === '1') throw e; }

// Replace only the OS process boundary; exercise real discovery and cleanup.
function mockChromeSpawn(t, replacement) {
  const original = childProcess.spawn;
  const mocked = t.mock.method(childProcess,'spawn',replacement);
  syncBuiltinESMExports();
  t.after(() => { mocked.mock.restore(); syncBuiltinESMExports(); });
  return original;
}
function chromeProcess(stderr) {
  const proc = new EventEmitter();
  proc.stderr = new PassThrough();
  proc.exitCode = null;
  proc.signalCode = null;
  proc.kill = () => {
    proc.signalCode = 'SIGTERM';
    proc.emit('exit',null,'SIGTERM');
    return true;
  };
  queueMicrotask(() => proc.stderr.end(stderr));
  return proc;
}
function failedChrome(stderr, {code = 23, signal = null} = {}) {
  const proc = chromeProcess(stderr);
  queueMicrotask(() => {
    proc.exitCode = code;
    proc.signalCode = signal;
    proc.emit('exit',code,signal);
  });
  return proc;
}

test('Chrome startup retries once with a fresh profile after cleaning the failed process', {skip:!chrome}, async t => {
  const profiles = [];
  const warnings = [];
  t.mock.method(console,'warn',message => warnings.push(message));
  const original = mockChromeSpawn(t,(binary,args,options) => {
    const profile = args.find(a => a.startsWith('--user-data-dir=')).slice('--user-data-dir='.length);
    profiles.push(profile);
    if (profiles.length === 1) return failedChrome('synthetic startup crash');
    assert.equal(existsSync(profiles[0]),false,'failed profile is removed before retry');
    return original(binary,args,options);
  });
  const browser = await launch();
  try {
    assert.equal(profiles.length,2);
    assert.notEqual(profiles[0],profiles[1]);
    assert.equal(await browser.cdp.eval('1 + 1'),2);
    assert.match(warnings.join('\n'),/synthetic startup crash/);
  } finally { await stop(browser); }
  assert.equal(existsSync(profiles[1]),false);
});

test('Chrome startup failure retains both bounded stderr tails and exit or signal diagnostics', {skip:!chrome}, async t => {
  const profiles = [];
  t.mock.method(console,'warn',() => {});
  mockChromeSpawn(t,(_binary,args) => {
    profiles.push(args.find(a => a.startsWith('--user-data-dir=')).slice('--user-data-dir='.length));
    const attempt = profiles.length;
    return failedChrome('discard-this-prefix' + 'x'.repeat(5000) + ` startup-${attempt}`, attempt === 1
      ? {code:23} : {code:null,signal:'SIGKILL'});
  });
  await assert.rejects(launch(),error => {
    assert.match(error.message,/startup-1/);
    assert.match(error.message,/startup-2/);
    assert.match(error.message,/exit=23/);
    assert.match(error.message,/signal=SIGKILL/);
    assert.match(error.message,/endpoint=missing/);
    assert.doesNotMatch(error.message,/discard-this-prefix/);
    assert.ok(error.message.length < 10000,'stderr is capped per attempt');
    return true;
  });
  assert.equal(profiles.length,2,'permanent startup failure never gets a third attempt');
  assert.ok(profiles.every(p => !existsSync(p)));
});

test('Chrome startup diagnostics preserve an advertised endpoint and the last discovery failure', {skip:!chrome}, async t => {
  let activeProcess;
  t.mock.method(console,'warn',() => {});
  t.mock.method(globalThis,'fetch',async () => {
    const proc = activeProcess;
    setImmediate(() => { proc.exitCode = 23; proc.emit('exit',23,null); });
    return new Response('unavailable',{status:503});
  });
  mockChromeSpawn(t,() => {
    activeProcess = chromeProcess('DevTools listening on ws://127.0.0.1:9999/devtools/browser/fixture\n');
    return activeProcess;
  });
  await assert.rejects(launch(),error => {
    assert.match(error.message,/endpoint=advertised/);
    assert.match(error.message,/HTTP 503/);
    return true;
  });
});

test('Chrome startup waits for termination before deleting a failed profile', {skip:!chrome}, async t => {
  const profiles = [], profilesAtExit = [];
  const socket = 'ws://127.0.0.1:9999/devtools/browser/fixture';
  t.mock.method(console,'warn',() => {});
  t.mock.method(globalThis,'fetch',async url => Response.json(url.endsWith('/json/version')
    ? {webSocketDebuggerUrl:socket} : [{type:'page',webSocketDebuggerUrl:socket}]));
  const originalWebSocket = globalThis.WebSocket;
  globalThis.WebSocket = class {
    constructor() { queueMicrotask(() => this.onerror()); }
    close() {}
  };
  t.after(() => { globalThis.WebSocket = originalWebSocket; });
  mockChromeSpawn(t,(_binary,args) => {
    const profile = args.find(a => a.startsWith('--user-data-dir=')).slice('--user-data-dir='.length);
    profiles.push(profile);
    const proc = chromeProcess(`DevTools listening on ${socket}\n`);
    proc.kill = () => {
      setImmediate(() => {
        profilesAtExit.push(existsSync(profile));
        proc.signalCode = 'SIGTERM';
        proc.emit('exit',null,'SIGTERM');
      });
      return true;
    };
    return proc;
  });
  await assert.rejects(launch(),/CDP connect refused/);
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(profilesAtExit,[true,true],'each process exits before its profile is removed');
  assert.ok(profiles.every(p => !existsSync(p)));
});

test('Chrome startup refuses another attempt when its failed profile cannot be removed', {skip:!chrome}, async t => {
  const profiles = [];
  t.mock.method(console,'warn',() => {});
  const removal = t.mock.method(fs,'rmSync',() => { throw new Error('synthetic EACCES removing Chrome profile'); });
  syncBuiltinESMExports();
  mockChromeSpawn(t,(_binary,args) => {
    profiles.push(args.find(a => a.startsWith('--user-data-dir=')).slice('--user-data-dir='.length));
    return failedChrome('synthetic startup crash');
  });
  try {
    await assert.rejects(launch(),/Cleanup failed: synthetic EACCES/);
    assert.equal(profiles.length,1,'cleanup failure must prevent the retry');
    assert.equal(existsSync(profiles[0]),true);
  } finally {
    removal.mock.restore();
    syncBuiltinESMExports();
    for (const profile of profiles) cleanup(profile);
  }
});

test('failed boot results preserve the startup error before resource lookup', () => {
  const report = summarizeBoot([{label:'none-1',error:'Chrome did not expose a debuggable page'}],1);
  const result = {code:1,stdout:`[boot] none run 1/1\n${JSON.stringify(report)}`,stderr:''};
  for (const expectedCode of [0,1]) {
    assert.throws(() => bootReport(result,expectedCode).details[0].localResources.find(r => r.path === '/heavy.js'),
      /Chrome did not expose a debuggable page/);
  }
});

// Two startup attempts plus an 8s shaped boot can exceed the old 20s wrapper.
async function driver(script,args,timeout=45000) {
  return new Promise((ok,bad) => {
    const child = spawn(process.execPath,[resolve(`tool/perf/${script}`),...args],{
      env:{...process.env,CDP_PORT:'0'},stdio:['ignore','pipe','pipe'],
    });
    let stdout = '',stderr = '';
    child.stdout.on('data',s => {stdout += s;});
    child.stderr.on('data',s => {stderr += s;});
    const timer = setTimeout(() => {child.kill(); bad(new Error(`driver timeout: ${stdout}\n${stderr}`));},timeout);
    child.once('error',e => {clearTimeout(timer); bad(e);});
    child.once('exit',code => {clearTimeout(timer); ok({code,stdout,stderr});});
  });
}
function bootJson(stdout) { return JSON.parse(stdout.slice(stdout.indexOf('\n{')+1)); }
function bootReport(result,expectedCode=0) {
  const diagnostic = result.stdout + result.stderr;
  assert.equal(result.code,expectedCode,diagnostic);
  const report = bootJson(result.stdout);
  assert.equal(report.verdict.complete,true,diagnostic);
  return report;
}
function fixture(dir,source) {
  writeFileSync(join(dir,'fixture.js'),source);
  writeFileSync(join(dir,'index.html'),`<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><div id="eg-splash">Synthetic perf fixture only</div><script>window.__EVERGLOW_BUILD__='fixture-stamp'</script><script src="/fixture.js"></script>`);
}
const bootArgs = root => ['--web-root',root,'--runs','1','--port','0','--profile','none','--timeout-ms','3000','--settle-ms','200'];
const benchArgs = (root,out) => ['--web-root',root,'--out',out,'--runs','1','--scene','shelves','--port','0',
  '--throttle','1','--timeout-ms','1500','--settle-ms','0','--idle-ms','100','--scroll-steps','1','--scroll-settle-ms','0'];

// Real Chrome controls, with synthetic content only. No Flutter build/login/network.
test('Chrome fault controls', {skip:!chrome,timeout:90000}, async t => {
  const root = mkdtempSync(join(tmpdir(),'eg-perf-fixture-'));
  try {
    await t.test('navigation retains observer and boot CLI rejects a 350ms injected freeze',async () => {
      fixture(root,`const end=performance.now()+350;while(performance.now()<end){};
        window.dispatchEvent(new Event('flutter-first-frame'));`);
      const r = await driver('measure_boot.mjs',bootArgs(root));
      const report = bootReport(r,1);
      assert.ok(report.details[0].longTaskWorstMs >= 340,r.stdout);
      assert.equal(report.verdict.noLongTaskOver200ms,false);
      assert.ok(report.details[0].firstFlutterFrameMs > 0);
      assert.doesNotMatch(r.stdout,/firstInteractive/);
    });
    await t.test('cold slow3g really throttles uncached compressed responses before navigation',async () => {
      // Random text resists gzip; spaces would turn a 128KiB file into ~200 bytes.
      writeFileSync(join(root,'heavy.js'),`/*${randomBytes(96*1024).toString('base64')}*/\nwindow.dispatchEvent(new Event('flutter-first-frame'));`);
      writeFileSync(join(root,'index.html'),`<!doctype html><script>window.__EVERGLOW_BUILD__='fixture-stamp'</script><script src="/heavy.js"></script>`);
      const fast = bootReport(await driver('measure_boot.mjs',bootArgs(root)));
      const r = await driver('measure_boot.mjs',[...bootArgs(root),'--profile','slow3g','--timeout-ms','8000','--frame-budget-ms','10000']);
      const slow = bootReport(r);
      assert.equal(slow.link.downloadKbps,400);
      assert.equal(slow.link.latencyMs,400);
      const slowResource = slow.details[0].localResources.find(r => r.path === '/heavy.js');
      const fastResource = fast.details[0].localResources.find(r => r.path === '/heavy.js');
      assert.ok(slowResource.encodedBodyBytes > 90000,r.stdout);
      assert.equal(slowResource.encodedBodyBytes,fastResource.encodedBodyBytes);
      assert.ok(slowResource.durationMs > slowResource.encodedBodyBytes / 50000 * 1000 * 0.8,r.stdout);
    });
    await t.test('absent observer is rejected by the real boot CLI',async () => {
      fixture(root,`delete window.__egLongTaskState; window.dispatchEvent(new Event('flutter-first-frame'));`);
      const r = await driver('measure_boot.mjs',bootArgs(root));
      assert.equal(r.code,1);
      assert.match(r.stdout,/instrumentation missing/);
    });
    await t.test('missing first-frame marker is an explicit failed run',async () => {
      fixture(root,'');
      const r = await driver('measure_boot.mjs',[...bootArgs(root),'--timeout-ms','300']);
      assert.equal(r.code,1);
      assert.match(r.stdout,/first Flutter frame timeout/);
      assert.equal(bootJson(r.stdout).median,null);
    });
    await t.test('zero-frame changing-clock fixture cannot pass bench',async () => {
      fixture(root,`window.__everglowPerf=${JSON.stringify(mirror({frames:0,sessionFrames:0}))};
        setInterval(() => document.body.textContent=Date.now(),30);`);
      const out = join(root,'zero.md');
      const r = await driver('bench.mjs',benchArgs(root,out));
      assert.equal(r.code,1,r.stdout+r.stderr);
      assert.match(readFileSync(out,'utf8'),/zero\/missing frame samples/);
    });
    await t.test('non-scrollable fixture with changing pixels and valid frame samples cannot pass',async () => {
      fixture(root,`window.__everglowPerf=${JSON.stringify(mirror())};
        window.__everglowBenchScroll=()=>({scene:'shelves',offset:0,maxScrollExtent:0});
        setInterval(() => {document.body.textContent=Date.now();
          window.__everglowPerf.sampleSequence++;window.__everglowPerf.sessionFrames++;},30);`);
      const out = join(root,'static.md');
      const r = await driver('bench.mjs',benchArgs(root,out));
      assert.equal(r.code,1,r.stdout+r.stderr);
      assert.match(readFileSync(out,'utf8'),/non-scrollable/);
    });
    await t.test('changing clock with a positive extent but fixed offset is rejected after actual gestures',async () => {
      fixture(root,`window.__everglowPerf=${JSON.stringify(mirror())};
        window.__everglowBenchScroll=()=>({scene:'shelves',offset:0,maxScrollExtent:5000});
        setInterval(() => {document.body.textContent=Date.now();
          window.__everglowPerf.sampleSequence++;window.__everglowPerf.sessionFrames++;},30);`);
      const out = join(root,'fixed-offset.md');
      const r = await driver('bench.mjs',benchArgs(root,out));
      assert.equal(r.code,1,r.stdout+r.stderr);
      assert.match(readFileSync(out,'utf8'),/did not move the actual scroll offset/);
    });
    await t.test('real scrollable control passes, but a load freeze survives late good samples',async () => {
      const source = freeze => `document.body.style.margin='0';
        document.body.insertAdjacentHTML('beforeend','<div style="height:6000px;background:linear-gradient(red,blue)"></div>');
        window.__everglowPerf=${JSON.stringify(mirror())};
        window.__everglowBenchScroll=()=>({scene:'shelves',offset:scrollY,maxScrollExtent:document.documentElement.scrollHeight-innerHeight});
        ${freeze ? 'const end=performance.now()+350;while(performance.now()<end){};' : ''}
        setInterval(()=>{window.__everglowPerf.sampleSequence++;window.__everglowPerf.sessionFrames++;},30);`;
      fixture(root,source(false));
      const good = await driver('bench.mjs',benchArgs(root,join(root,'good.md')));
      assert.equal(good.code,0,good.stdout+good.stderr);
      fixture(root,source(true));
      const out = join(root,'freeze.md');
      const bad = await driver('bench.mjs',benchArgs(root,out));
      assert.equal(bad.code,1,bad.stdout+bad.stderr);
      assert.match(readFileSync(out,'utf8'),/full session exceeded/);
      assert.match(readFileSync(out,'utf8'),/\*\*FAIL\*\*/);
    });
    await t.test('repeat shapes worker network too, after cached stamped core; document is fresh',async () => {
      writeFileSync(join(root,'main.dart.js'),"window.dispatchEvent(new Event('flutter-first-frame'));");
      writeFileSync(join(root,'bootstrap-heavy.js'),`/*${randomBytes(96*1024).toString('base64')}*/`);
      writeFileSync(join(root,'sw.js'),`self.addEventListener('install',e=>e.waitUntil(caches.open('fixture-stamp').then(c=>c.add('/main.dart.js?v=fixture-stamp')).then(()=>self.skipWaiting())));
        self.addEventListener('activate',e=>e.waitUntil(self.clients.claim()));
        self.addEventListener('fetch',e=>e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request))));`);
      writeFileSync(join(root,'index.html'),`<!doctype html><script>window.__EVERGLOW_BUILD__='fixture-stamp';navigator.serviceWorker.register('/sw.js');</script><script src="/bootstrap-heavy.js"></script><script src="/main.dart.js?v=fixture-stamp"></script>`);
      const r = await driver('measure_boot.mjs',[...bootArgs(root),'--repeat','--profile','slow3g','--timeout-ms','8000','--frame-budget-ms','10000']);
      const report = bootReport(r);
      assert.ok(report.details[0].warm.coreUrl.endsWith('/main.dart.js?v=fixture-stamp'));
      assert.notEqual(report.details[0].timeOrigin,report.details[0].warm.timeOrigin);
      const loader = report.details[0].localResources.find(r => r.path === '/bootstrap-heavy.js');
      assert.ok(loader.encodedBodyBytes > 90000,r.stdout);
      assert.ok(loader.durationMs > loader.encodedBodyBytes / 50000 * 1000 * 0.8,r.stdout);
      const core = report.details[0].localResources.find(r => r.path === '/main.dart.js');
      assert.equal(core.transferBytes,0,r.stdout);
      assert.match(report.note,/no offline/);
    });
  } finally { rmSync(root,{recursive:true,force:true}); }
});
