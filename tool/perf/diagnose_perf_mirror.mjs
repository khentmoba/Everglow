// Diagnose why window.__everglowPerf is unreadable: Dart side, or CDP realm?
// __everglowMediaState is set by web/index.html, so it is a control — if that
// is also invisible the probe is the problem, not the Dart mirror.
import { spawn } from 'node:child_process';

const PORT = Number(process.argv[2] || 8955);
const CDP_PORT = Number(process.env.CDP_PORT || 9260);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

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
ws.onmessage = (e) => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } };
await new Promise((r) => { ws.onopen = r; });
const send = (method, params = {}) => new Promise((res) => { const c = id++; pending.set(c, res); ws.send(JSON.stringify({ id: c, method, params })); });

await send('Page.enable');
await send('Runtime.enable');
await send('Page.navigate', { url: `http://localhost:${PORT}/temp-preview?perf=1` });
await sleep(14000);

for (const expr of [
  'typeof window.__everglowMediaState',        // set in index.html (control)
  'JSON.stringify(window.__everglowMediaState || null)',
  'typeof window.__everglowPerf',              // set by perf_probe_web.dart
  'typeof window.__everglowResetPerf',         // set by registerPerfReset
  'Object.keys(window).filter(k => k.indexOf("everglow") === 0).join(",")',
  'typeof window.flutterConfiguration',
]) {
  const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true });
  console.log(expr.padEnd(52), '=>', JSON.stringify(r?.result?.result?.value));
}

const ctxs = await send('Runtime.evaluate', { expression: 'location.href', returnByValue: true });
console.log('context href =>', JSON.stringify(ctxs?.result?.result?.value));

ws.close();
chrome.kill();
