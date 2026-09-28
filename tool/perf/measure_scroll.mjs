// Before/after scroll benchmark for the ultra-perf pass.
//
// Drives the real DashboardScreen in a release build over CDP at a phone
// viewport with Chrome's 4x CPU throttle, and prints the Frame Meter's own
// numbers as JSON so two builds can be diffed mechanically instead of read
// off a screenshot by eye.
//
//   node tool/perf/measure_scroll.mjs <port> <label> [--llvmpipe] [--shot path]
//
// The Frame Meter paints into a canvas, so its numbers are read from the HUD by
// OCR-free means: the app also mirrors each reading to
// `window.__everglowPerf` (see lib/core/perf/perf_probe_web.dart). If that
// mirror is unavailable the script still captures a screenshot for the record.
import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';

const PORT = Number(process.argv[2] || 8946);
const LABEL = process.argv[3] || 'run';
const USE_LLVM = process.argv.includes('--llvmpipe');
const shotIdx = process.argv.indexOf('--shot');
const SHOT = shotIdx > -1 ? process.argv[shotIdx + 1] : null;
const CDP_PORT = Number(process.env.CDP_PORT || 9251);
const SETTLE_MS = Number(process.env.SETTLE_MS || 12000);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const gpuFlags = USE_LLVM ? ['--use-gl=angle', '--use-angle=gl'] : [];
  const chrome = spawn('/usr/local/bin/google-chrome', [
    '--headless=new',
    `--remote-debugging-port=${CDP_PORT}`,
    '--no-sandbox',
    '--window-size=430,932',
    ...gpuFlags,
    'about:blank',
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
    const cur = id++;
    pending.set(cur, res);
    ws.send(JSON.stringify({ id: cur, method, params }));
  });

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Performance.enable');
  await send('Emulation.setDeviceMetricsOverride', {
    width: 430, height: 932, deviceScaleFactor: 1, mobile: true,
  });

  const renderer = await send('Runtime.evaluate', {
    expression: `(() => {
      const gl = document.createElement('canvas').getContext('webgl2');
      if (!gl) return 'none';
      const d = gl.getExtension('WEBGL_debug_renderer_info');
      return d ? gl.getParameter(d.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER);
    })()`, returnByValue: true,
  });

  await send('Page.navigate', { url: `http://localhost:${PORT}/temp-preview?perf=1` });

  // Settle before measuring. DeferredSection reveals on scroll and each
  // revealed section opens a Firestore read, so the scene keeps changing for a
  // while after boot. Scrolling into a still-changing scene is the main source
  // of run-to-run variance, so wait for it to go quiet first.
  await sleep(SETTLE_MS);

  // Report which GL backend Flutter actually got, once the app is up.
  const glInApp = await send('Runtime.evaluate', {
    expression: `(() => {
      const c = document.querySelector('canvas') || document.createElement('canvas');
      const gl = c.getContext('webgl2') || c.getContext('webgl');
      if (!gl) return 'no-context';
      const d = gl.getExtension('WEBGL_debug_renderer_info');
      return d ? gl.getParameter(d.UNMASKED_RENDERER_WEBGL) : String(gl.getParameter(gl.RENDERER));
    })()`, returnByValue: true,
  });

  // 4x CPU throttle for the scroll pass only, so boot is not penalised.
  await send('Emulation.setCPUThrottlingRate', { rate: 4 });
  // Long enough that the throttling itself is not inside the meter's window.
  await sleep(1200);
  // Double-tap the meter (bottom-left default corner) to reset its window, then
  // let it clear before the first gesture so no reset frame is counted.
  await send('Input.synthesizeTapGesture', { x: 40, y: 908, tapCount: 2, gestureSourceType: 'touch' });
  await sleep(1200);

  for (let i = 0; i < 8; i++) {
    await send('Input.synthesizeScrollGesture', { x: 215, y: 640, yDistance: -190, speed: 900, gestureSourceType: 'touch' });
    await sleep(200);
  }
  for (let i = 0; i < 5; i++) {
    await send('Input.synthesizeScrollGesture', { x: 215, y: 360, yDistance: 150, speed: 900, gestureSourceType: 'touch' });
    await sleep(200);
  }
  // Let late-arriving content finish so the final window is not cut mid-load.
  await sleep(2500);

  const perf = await send('Runtime.evaluate', {
    expression: 'JSON.stringify(window.__everglowPerf || null)', returnByValue: true,
  });
  // CDP nests evaluate results: {result:{result:{type,value}}}. Reading
  // `.result.value` silently yields undefined and makes a working mirror look
  // dead — which is how earlier numbers ended up read off screenshots by hand.
  const perfJson = perf?.result?.result?.value;
  const metrics = await send('Performance.getMetrics');
  const heap = metrics?.result?.metrics?.find((m) => m.name === 'JSHeapUsedSize')?.value || 0;
  // Frame count is the workload-equality check: two runs only form a controlled
  // pair if they recorded the same number of frames, i.e. the same elapsed
  // window at the same throughput. Different counts mean different work.
  const frames = perfJson && perfJson !== 'null' ? JSON.parse(perfJson).frames : null;

  const out = {
    label: LABEL,
    renderer: glInApp?.result?.result?.value ?? '?',
    perf: perfJson && perfJson !== 'null' ? JSON.parse(perfJson) : null,
    frames,
    heapMb: +(heap / 1048576).toFixed(2),
  };
  console.log(JSON.stringify(out));
  if (!out.perf) {
    console.error(
      '[warn] window.__everglowPerf unavailable — read the numbers off the ' +
      'HUD in the screenshot, and treat them as eyeballed, not measured.',
    );
  }

  if (SHOT) {
    const shot = await send('Page.captureScreenshot', { format: 'png' });
    mkdirSync(SHOT.replace(/\/[^/]+$/, ''), { recursive: true });
    writeFileSync(SHOT, Buffer.from(shot.result.data, 'base64'));
  }

  ws.close();
  chrome.kill();
}

main().catch((e) => { console.error(e); process.exit(1); });
