// Reusable PR proof screenshot CLI for Everglow.
// Usage:
//   node tool/capture_proof.mjs --route "/books?agent=1&hud=0" --viewport phone --out docs/pr-proof/pr-123/shot.png
//   node tool/capture_proof.mjs --pack pack-manifest.json
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { launch, serve, sleep, stop } from './perf/_harness.mjs';

const VIEWPORTS = {
  phone: { width: 430, height: 932, deviceScaleFactor: 2, mobile: true },
  tablet: { width: 820, height: 1180, deviceScaleFactor: 2, mobile: true },
  desktop: { width: 1280, height: 800, deviceScaleFactor: 1, mobile: false },
};

export const HELP_TEXT = `Usage:
  node tool/capture_proof.mjs --route <path> --out <file.png> [options]
  node tool/capture_proof.mjs --pack <manifest.json> [options]

Options:
  --route <path>       App route to capture (e.g. "/books?agent=1&hud=0")
  --out <file.png>     Output PNG path (parent dirs created automatically)
  --pack <file.json>   JSON array of { route, out, viewport?, selector?, wait?, fullPage? } shots (one Chrome launch)
  --viewport <preset>  phone (430x932, default) | tablet (820x1180) | desktop (1280x800) | WxH
  --dist <dir>         Built web dist directory (default: react/dist)
  --selector <css>     Optional CSS selector to wait for before capturing
  --wait <ms>          Extra settle wait after mount in ms (default: 1200)
  --full-page          Capture full scrollable page height
  --skip-dist-check    Skip react/tools/check_dist.mjs freshness check
  --help, -h           Show this help`;

export function parseViewport(spec = 'phone') {
  const key = String(spec).toLowerCase();
  if (VIEWPORTS[key]) return VIEWPORTS[key];
  const m = /^(\d{3,4})x(\d{3,4})$/i.exec(key);
  if (!m) throw new Error(`Invalid --viewport "${spec}". Use phone, tablet, desktop, or WxH (e.g. 430x932).`);
  const width = Number(m[1]);
  const height = Number(m[2]);
  return { width, height, deviceScaleFactor: width <= 900 ? 2 : 1, mobile: width <= 900 };
}

export function normalizeShot(raw, defaults = {}) {
  if (!raw || typeof raw !== 'object') throw new Error('Pack entry must be an object.');
  const route = String(raw.route ?? '').trim();
  const out = String(raw.out ?? '').trim();
  if (!route) throw new Error('Missing required --route (e.g. --route "/books?agent=1&hud=0").');
  if (!out) throw new Error('Missing required --out (e.g. --out docs/pr-proof/pr-123/shot.png).');
  const wait = raw.wait !== undefined ? Number(raw.wait) : (defaults.wait ?? 1200);
  if (!Number.isFinite(wait) || wait < 0) throw new Error(`Invalid --wait: ${wait}`);
  const viewport = raw.viewport ?? defaults.viewport ?? 'phone';
  parseViewport(viewport);
  return {
    route: route.startsWith('/') ? route : `/${route}`,
    out,
    viewport,
    selector: String(raw.selector ?? defaults.selector ?? ''),
    wait,
    fullPage: Boolean(raw.fullPage ?? defaults.fullPage ?? false),
  };
}

export function parseArgs(argv) {
  const opts = {
    route: '',
    out: '',
    pack: '',
    viewport: 'phone',
    dist: 'react/dist',
    selector: '',
    wait: 1200,
    fullPage: false,
    skipDistCheck: false,
    help: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--help' || a === '-h') opts.help = true;
    else if (a === '--full-page') opts.fullPage = true;
    else if (a === '--skip-dist-check') opts.skipDistCheck = true;
    else if (a === '--route') opts.route = argv[++i] ?? '';
    else if (a === '--out') opts.out = argv[++i] ?? '';
    else if (a === '--pack') opts.pack = argv[++i] ?? '';
    else if (a === '--viewport') opts.viewport = argv[++i] ?? 'phone';
    else if (a === '--dist') opts.dist = argv[++i] ?? 'react/dist';
    else if (a === '--selector') opts.selector = argv[++i] ?? '';
    else if (a === '--wait') opts.wait = Number(argv[++i] ?? 1200);
    else throw new Error(`Unknown argument: ${a}`);
  }
  if (!opts.help) {
    if (!Number.isFinite(opts.wait) || opts.wait < 0) throw new Error(`Invalid --wait: ${opts.wait}`);
    if (!opts.pack) {
      if (!opts.route) throw new Error('Missing required --route (e.g. --route "/books?agent=1&hud=0").');
      if (!opts.out) throw new Error('Missing required --out (e.g. --out docs/pr-proof/pr-123/shot.png).');
    }
  }
  return opts;
}

export function loadPack(packPath, defaults = {}) {
  const parsed = JSON.parse(readFileSync(packPath, 'utf8'));
  const rawShots = Array.isArray(parsed) ? parsed : parsed?.shots;
  if (!Array.isArray(rawShots) || rawShots.length === 0) {
    throw new Error(`Pack manifest "${packPath}" must be a non-empty array or { shots: [...] }.`);
  }
  return rawShots.map((item) => normalizeShot(item, defaults));
}

async function captureOne(cdp, port, shot) {
  const vp = parseViewport(shot.viewport);
  await cdp.send('Emulation.setDeviceMetricsOverride', {
    width: vp.width,
    height: vp.height,
    deviceScaleFactor: vp.deviceScaleFactor,
    mobile: vp.mobile,
  });

  const url = `http://127.0.0.1:${port}${shot.route}`;
  await cdp.send('Page.navigate', { url });

  const deadline = Date.now() + 15_000;
  let mounted = false;
  while (Date.now() < deadline) {
    const ready = await cdp.eval(`(() => {
      const root = document.getElementById('root');
      const text = (document.body?.innerText || '').trim();
      const sel = ${JSON.stringify(shot.selector)};
      const selOk = !sel || Boolean(document.querySelector(sel));
      return Boolean(root && root.childElementCount > 0 && text.length > 0 && selOk);
    })()`);
    if (ready) {
      mounted = true;
      break;
    }
    await sleep(100);
  }
  if (!mounted) {
    throw new Error(`Timed out waiting for ${shot.route}${shot.selector ? ` (selector: ${shot.selector})` : ''} to mount.`);
  }
  if (shot.wait > 0) await sleep(shot.wait);

  const img = await cdp.send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: shot.fullPage,
  });
  const outPath = resolve(shot.out);
  mkdirSync(dirname(outPath), { recursive: true });
  writeFileSync(outPath, Buffer.from(img.result.data, 'base64'));
  console.log(`[proof] saved ${outPath} (${vp.width}x${vp.height} @${vp.deviceScaleFactor}x, route=${shot.route})`);
}

async function capture(opts) {
  const shots = opts.pack ? loadPack(opts.pack, opts) : [normalizeShot(opts)];
  if (!opts.skipDistCheck && resolve(opts.dist) === resolve('react/dist')) {
    execFileSync(process.execPath, [fileURLToPath(new URL('../react/tools/check_dist.mjs', import.meta.url))], {
      stdio: 'inherit',
    });
  }

  const server = await serve(opts.dist, 0);
  const chrome = await launch(0, { extraFlags: ['--mute-audio'] });
  try {
    const { cdp } = chrome;
    await cdp.send('Page.enable');
    await cdp.send('Runtime.enable');
    const port = server.address().port;
    for (const shot of shots) {
      await captureOne(cdp, port, shot);
    }
  } finally {
    server.closeAllConnections?.();
    server.close();
    await stop(chrome);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const opts = parseArgs(process.argv.slice(2));
    if (opts.help) {
      console.log(HELP_TEXT);
    } else {
      await capture(opts);
    }
  } catch (err) {
    console.error(`[proof] ${err.message}`);
    process.exitCode = 1;
  }
}
