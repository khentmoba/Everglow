// Find a Chrome flag set that gives this container hardware WebGL.
// Reads the real UNMASKED_RENDERER_WEBGL string, and times a fill-rate probe,
// so "we have no GPU" can be checked instead of assumed.
import { spawn } from 'node:child_process';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const CANDIDATES = [
  { name: 'default', flags: [] },
  { name: 'ignore-blocklist', flags: ['--ignore-gpu-blocklist', '--enable-gpu-rasterization'] },
  { name: 'angle-gl', flags: ['--use-angle=gl', '--ignore-gpu-blocklist'] },
  { name: 'angle-vulkan', flags: ['--use-angle=vulkan', '--ignore-gpu-blocklist', '--enable-features=Vulkan'] },
  { name: 'angle-d3d12', flags: ['--use-angle=d3d12', '--ignore-gpu-blocklist'] },
  { name: 'egl', flags: ['--use-gl=egl', '--ignore-gpu-blocklist'] },
  { name: 'angle-gl-egl', flags: ['--use-gl=angle', '--use-angle=gl', '--ignore-gpu-blocklist'] },
  { name: 'vulkan-explicit', flags: ['--enable-features=Vulkan,VulkanFromANGLE', '--use-angle=vulkan', '--ignore-gpu-blocklist', '--enable-gpu-rasterization'] },
];

const PROBE = `
(() => {
  const c = document.createElement('canvas');
  const gl = c.getContext('webgl2') || c.getContext('webgl');
  if (!gl) return JSON.stringify({ renderer: null, note: 'no webgl context' });
  const dbg = gl.getExtension('WEBGL_debug_renderer_info');
  const renderer = dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER);
  const vendor = dbg ? gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR);
  // Fill-rate probe: how long to cover a 430x932 surface 60 times, i.e. the
  // per-frame cost of one full-screen paint.
  c.width = 430; c.height = 932;
  const t0 = performance.now();
  for (let i = 0; i < 60; i++) { gl.clearColor(i / 60, 0.2, 0.3, 1); gl.clear(gl.COLOR_BUFFER_BIT); }
  gl.finish();
  const msPerFrame = (performance.now() - t0) / 60;
  return JSON.stringify({ renderer, vendor, msPerFrame: +msPerFrame.toFixed(3) });
})()
`;

async function probe(flags) {
  const port = 9300 + Math.floor(Math.random() * 400);
  const chrome = spawn('/usr/local/bin/google-chrome', [
    '--headless=new',
    `--remote-debugging-port=${port}`,
    '--no-sandbox',
    ...flags,
    'about:blank',
  ]);
  let out = null;
  try {
    await sleep(2500);
    const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
    const page = list.find((p) => p.type === 'page') || list[0];
    const ws = new WebSocket(page.webSocketDebuggerUrl);
    const pending = new Map();
    let id = 1;
    ws.onmessage = (e) => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } };
    await new Promise((r) => { ws.onopen = r; });
    const send = (method, params = {}) => new Promise((res) => { const c = id++; pending.set(c, res); ws.send(JSON.stringify({ id: c, method, params })); });
    await send('Runtime.enable');
    const r = await send('Runtime.evaluate', { expression: PROBE, returnByValue: true, awaitPromise: false });
    // CDP nests the result twice: {result:{result:{type,value}}}
    const raw = r?.result?.result?.value;
    out = typeof raw === 'string' ? JSON.parse(raw) : { error: JSON.stringify(r).slice(0, 200) };
    ws.close();
  } catch (e) {
    out = { error: String(e).slice(0, 120) };
  } finally {
    chrome.kill();
    await sleep(400);
  }
  return out;
}

for (const c of CANDIDATES) {
  const r = await probe(c.flags);
  console.log(c.name.padEnd(18), JSON.stringify(r));
}
