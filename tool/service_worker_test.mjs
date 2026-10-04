// node --test tool/service_worker_test.mjs
// node tool/service_worker_test.mjs --browser (also runs a real Chrome SW check)
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, mkdirSync, copyFileSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import vm from 'node:vm';
import {createServer} from 'node:http';

const origin = 'https://demo.everglow.test';
const A = '0.0.0+1-old';
const B = '0.0.0+2-new';
const C = '0.0.0+3-pending';
const core = (stamp) => `/main.dart.js?v=${stamp}`;
const part = (stamp) => `/main.dart.js_1.part.js?v=${encodeURIComponent(stamp)}`;
const shell = (stamp) => `${stamp}-SHELL-v1`;
const script = (body, status = 200) => new Response(body, {
  status, headers: {'Content-Type': 'text/javascript; charset=utf-8'},
});
const bootstrap = (stamp) => `window.__EVERGLOW_BUILD__ = "${stamp}";
const mainJsPath = "main.dart.js?v=${stamp}";
const main = document.createElement('script'); main.src = mainJsPath; document.head.append(main);`;

function generateWorker(stamp) {
  // Execute Dart in an isolated metadata-only copy; never rewrite tracked web/.
  const dir = mkdtempSync(join(tmpdir(), 'everglow-sw-test-'));
  try {
    mkdirSync(join(dir, 'tool'));
    mkdirSync(join(dir, 'web'));
    for (const file of ['generate_sw.dart', 'build_stamp.dart']) {
      copyFileSync(new URL(file, import.meta.url), join(dir, 'tool', file));
    }
    writeFileSync(join(dir, 'pubspec.yaml'), `version: ${stamp}\n`);
    const run = process.platform === 'win32'
      ? spawnSync('cmd.exe', ['/d', '/s', '/c', 'dart tool/generate_sw.dart'], {cwd: dir, encoding: 'utf8'})
      : spawnSync('dart', ['tool/generate_sw.dart'], {cwd: dir, encoding: 'utf8'});
    assert.equal(run.status, 0, run.stderr || run.stdout);
    const source = readFileSync(join(dir, 'web/sw.js'), 'utf8');
    assert.ok(source.startsWith(`// BUILD=${stamp}\n`), 'temporary metadata controls the stamp');
    return source;
  } finally {
    rmSync(dir, {recursive: true, force: true});
  }
}
const sources = new Map([A, B, C].map((stamp) => [stamp, generateWorker(stamp)]));

function worker(stamp = A, stores = new Map()) {
  const handlers = {};
  const calls = [];
  let network = async () => script('current-build');
  const key = (req) => new URL(typeof req === 'string' ? req : req.url, origin).href;
  const caches = {
    async open(name) {
      if (!stores.has(name)) stores.set(name, new Map());
      const data = stores.get(name);
      return {
        async keys() { return [...data.keys()].map((url) => ({url})); },
        async match(req) { return data.get(key(req))?.clone(); },
        async put(req, response) { data.set(key(req), response.clone()); },
        async delete(req) { return data.delete(key(req)); },
      };
    },
    async keys() { return [...stores.keys()]; },
    async delete(name) { return stores.delete(name); },
    async match(req, options = {}) {
      const names = options.cacheName ? [options.cacheName] : [...stores.keys()];
      for (const name of names) {
        const hit = stores.get(name)?.get(key(req));
        if (hit) return hit.clone();
      }
    },
  };
  vm.runInNewContext(sources.get(stamp), {
    URL, Response, caches,
    navigator: {onLine: false}, // Skip unrelated activation pre-warm.
    self: {
      location: {origin}, clients: {async claim() {}}, skipWaiting() {},
      addEventListener: (event, handler) => { handlers[event] = handler; },
    },
    async fetch(req, options) {
      calls.push({url: key(req), cache: options?.cache});
      return network(new URL(key(req)), options);
    },
  });
  return {
    stores, caches, calls,
    online(build) {
      network = async (url) => {
        if (['/flutter_bootstrap.js', '/flutter.js'].includes(url.pathname)) return script(bootstrap(build));
        if (url.pathname === '/main.dart.js') return script(`main:${build}`);
        if (url.pathname.endsWith('.part.js')) return script(`part:${build}`);
        return new Response(`index:${build}`, {headers: {'Content-Type': 'text/html'}});
      };
    },
    network(fn) { network = fn; },
    offline() { network = async () => { throw new Error('offline'); }; },
    async seed(name, url, response) {
      await (await caches.open(name)).put(url, response);
    },
    async activate() {
      let done;
      handlers.activate({waitUntil(promise) { done = promise; }});
      await done;
    },
    async request(url, mode) {
      let response;
      const pending = [];
      handlers.fetch({
        request: {method: 'GET', url: key(url), mode},
        respondWith(promise) { response = promise; },
        waitUntil(promise) { pending.push(promise); },
      });
      const result = await response;
      await Promise.all(pending);
      // Drain legacy fire-and-forget cache writes too.
      await new Promise((resolve) => setImmediate(resolve));
      return result;
    },
  };
}

async function warm(w, stamp) {
  w.online(stamp);
  await w.request('/', 'navigate');
  await w.request('/flutter_bootstrap.js');
  await w.request('/flutter.js');
  await w.request(core(stamp));
  await w.request(part(stamp));
}

test('required loaders are network/no-store online and cached for offline boot', async () => {
  const w = worker();
  await warm(w, A);
  w.offline();
  assert.equal(await (await w.request('/flutter_bootstrap.js')).text(), bootstrap(A));
  assert.equal(await (await w.request('/flutter.js')).text(), bootstrap(A));
  assert.equal(await (await w.request(core(A))).text(), `main:${A}`);
  assert.equal(await (await w.request(part(A))).text(), `part:${A}`);
  for (const path of ['/', '/flutter_bootstrap.js', '/flutter.js']) {
    assert.ok(w.calls.filter((c) => new URL(c.url).pathname === path).every((c) => c.cache === 'no-store'));
  }
});

test('old worker serves a fresh deploy and keeps its bootstrap/main/chunks paired offline', async () => {
  const w = worker(A);
  await warm(w, A);
  await warm(w, B); // Same worker, newly deployed bytes.
  assert.equal(await (await w.request('/flutter_bootstrap.js?fresh=1')).text(), bootstrap(B));
  assert.equal(await (await w.request(core(B))).text(), `main:${B}`);
  const calls = w.calls.length;
  assert.equal(await (await w.request(core(A))).text(), `main:${A}`);
  assert.equal(w.calls.length, calls, 'version-keyed core stays cache-first');
  assert.equal(await (await w.request(part(A))).text(), `part:${A}`, 'a newer deploy cannot overwrite a cached old chunk');
  assert.ok(storesContain(w, shell(B), '/flutter_bootstrap.js'));
  assert.ok(storesContain(w, shell(B), part(B)), 'encoded + in deferred query resolves the same shell');
  w.offline();
  assert.equal(await (await w.request('/flutter_bootstrap.js')).text(), bootstrap(B));
  assert.equal(await (await w.request(part(A))).text(), `part:${A}`);
  assert.equal(await (await w.request(part(B))).text(), `part:${B}`);
});

function storesContain(w, name, path) {
  return w.stores.get(name)?.has(new URL(path, origin).href);
}

test('activation preserves the previous complete shell when the new core is not yet cached', async () => {
  const old = worker(A);
  await warm(old, A);
  const next = worker(B, old.stores);
  next.online(B);
  await next.request('/flutter_bootstrap.js'); // No B main/chunks yet.
  await next.activate();
  next.offline();
  assert.equal(await (await next.request('/flutter_bootstrap.js')).text(), bootstrap(A));
  assert.equal(await (await next.request(core(A))).text(), `main:${A}`);
  assert.equal(await (await next.request(part(A))).text(), `part:${A}`);
  assert.equal((await next.request(core(B))).type, 'error', 'never substitute another build under B URL');
  assert.equal((await next.request(part(B))).type, 'error');
});

test('two complete builds survive rotation, but an incomplete newest bootstrap is skipped', async () => {
  const w = worker();
  await warm(w, A);
  await warm(w, B);
  w.online(C);
  await w.request('/flutter_bootstrap.js');
  w.offline();
  assert.equal(await (await w.request('/flutter_bootstrap.js')).text(), bootstrap(B));
  await warm(w, C);
  assert.equal(w.stores.get('everglow-core-v1').size, 2);
  assert.equal(w.stores.has(shell(A)), false, 'evicted main and dependent loaders/chunks rotate together');
  w.offline();
  assert.equal(await (await w.request('/', 'navigate')).text(), `index:${B}`, 'navigation survives rotation of the old worker cache');
  assert.equal(await (await w.request('/flutter_bootstrap.js')).text(), bootstrap(C));
  assert.equal(await (await w.request(part(B))).text(), `part:${B}`);
});

test('API/auth, manifest and push/worker scripts never cache or use cached fallback', async () => {
  const w = worker();
  for (const path of ['/api/checkLoginCode', '/api/proxyCatalog', '/manifest.json', '/sw.js',
    '/firebase-messaging-sw.js', '/flutter_service_worker.js']) {
    w.network(async () => new Response('fresh'));
    assert.equal(await (await w.request(path)).text(), 'fresh');
    assert.equal([...w.stores.values()].some((s) => s.has(origin + path)), false);
    await w.seed(shell(A), path, new Response('stale/private'));
    w.offline();
    assert.equal((await w.request(path)).type, 'error', path);
    assert.equal((await w.request(path, 'navigate')).type, 'error', 'no private/API or script navigation fallback');
    assert.ok(w.calls.filter((c) => c.url === origin + path).every((c) => c.cache === 'no-store'));
  }
  assert.deepEqual(await (await w.request('/version.json')).json(), {offline: true});
});

test('cache storage failure does not turn a successful new deploy into stale bootstrap bytes', async () => {
  const w = worker();
  await warm(w, A);
  w.online(B);
  const open = w.caches.open;
  w.caches.open = async (name) => {
    if (name === shell(B)) throw new Error('cache quota');
    return open(name);
  };
  assert.equal(await (await w.request('/flutter_bootstrap.js')).text(), bootstrap(B));
});

test('failed or HTML SPA-rewrite JS responses cannot poison a boot loader or a build URL', async () => {
  const w = worker();
  await warm(w, A);
  for (const bad of [
    () => new Response('<!doctype html><html>SPA</html>', {headers: {'Content-Type': 'text/html'}}),
    () => script('unavailable', 503),
  ]) {
    w.network(async () => bad());
    assert.equal(await (await w.request('/flutter_bootstrap.js')).text(), bootstrap(A));
    for (const path of [core(B), part(B)]) {
      assert.equal((await w.request(path)).type, 'error');
      assert.equal(await w.caches.match(path), undefined, 'bad response must not enter any cache');
    }
  }
});

for (const path of ['/assets/fonts/MaterialIcons-Regular.otf', '/assets/FontManifest.json']) {
  test(`${path} still refreshes online and falls back only to the active build`, async () => {
    const w = worker();
    await w.seed('canvaskit-__ENGINE_REV__', path, new Response('stale-icons'));
    await w.seed(shell(B), path, new Response('other-build-icons'));
    assert.equal(await (await w.request(path)).text(), 'current-build');
    assert.equal(w.calls[0].cache, 'no-cache');
    w.offline();
    assert.equal(await (await w.request(path)).text(), 'current-build');
    await w.activate();
    assert.equal(await w.caches.match(path, {cacheName: 'canvaskit-__ENGINE_REV__'}), undefined);
  });
}

test('Chrome boots paired loaders/main/deferred code with BOTH page and worker offline',
  {skip: !process.argv.includes('--browser'), timeout: 60000}, async () => {
    const {launch, prepare, sleep, cleanup, Cdp} = await import('./perf/_harness.mjs');
    let build = A;
    const server = createServer((req, res) => {
      const path = new URL(req.url, 'http://local').pathname;
      let body;
      let type = 'text/javascript';
      if (path === '/sw.js') body = sources.get(A); // Old worker stays active during deploy B.
      else if (path === '/flutter_bootstrap.js') body = bootstrap(build);
      else if (path === '/main.dart.js') body = `window.__mainBuild = '${build}';
        const part = document.createElement('script');
        part.src = 'main.dart.js_1.part.js?v=' + encodeURIComponent(window.__EVERGLOW_BUILD__);
        document.head.append(part);`;
      else if (path.endsWith('.part.js')) body = `window.__boot = '${build}';`;
      else if (path === '/' || path === '/index.html') {
        type = 'text/html';
        body = '<!doctype html><script>navigator.serviceWorker.register("/sw.js")</script>' +
          '<script src="/flutter_bootstrap.js"></script>';
      } else { res.writeHead(404).end(); return; }
      res.writeHead(200, {'Content-Type': type, 'Cache-Control': 'no-store'}).end(body);
    });
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const url = `http://127.0.0.1:${server.address().port}/`;
    // Ask the OS for a free debugger port; only our throwaway Chrome is driven.
    const portServer = createServer();
    await new Promise((resolve) => portServer.listen(0, '127.0.0.1', resolve));
    const port = portServer.address().port;
    await new Promise((resolve) => portServer.close(resolve));
    let chrome;
    let wcdp;
    try {
      chrome = await launch(port);
      const {cdp} = chrome;
      await prepare(cdp);
      const wait = async (expression) => {
        for (let i = 0; i < 100; i++) {
          if (await cdp.eval(expression)) return;
          await sleep(100);
        }
        throw new Error(`Browser condition timed out: ${expression}`);
      };
      const visit = async (stamp) => {
        await cdp.send('Page.navigate', {url});
        await wait(`window.__boot === '${stamp}' && window.__mainBuild === '${stamp}'`);
      };
      await visit(A);
      await wait('!!navigator.serviceWorker.controller');
      await visit(A); // First controlled visit stores bootstrap and deferred bytes.
      build = B;
      await visit(B); // No stale HTML/bootstrap/main after deploy, despite old worker.
      const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      const target = targets.find((t) => t.type === 'service_worker' && t.url === url + 'sw.js');
      assert.ok(target, 'attach to the actual active worker, not just the page');
      const ws = new WebSocket(target.webSocketDebuggerUrl);
      await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
      wcdp = new Cdp(ws);
      for (const targetCdp of [cdp, wcdp]) {
        const enabled = await targetCdp.send('Network.enable');
        assert.equal(enabled.error, undefined);
        const offline = await targetCdp.send('Network.emulateNetworkConditions', {
          offline: true, latency: 0, downloadThroughput: 0, uploadThroughput: 0,
        });
        assert.equal(offline.error, undefined);
      }
      server.closeAllConnections();
      await new Promise((resolve) => server.close(resolve)); // No network path even if emulation leaks.
      await visit(B);
      const state = await cdp.eval('({bootstrap:window.__EVERGLOW_BUILD__,main:window.__mainBuild,part:window.__boot,controlled:!!navigator.serviceWorker.controller})');
      assert.deepEqual(state, {bootstrap: B, main: B, part: B, controlled: true});
      console.log('Real Chrome, server stopped, page+worker CDP offline:', state);
    } finally {
      wcdp?.ws.close();
      chrome?.cdp.ws.close();
      if (chrome) {
        chrome.proc.kill();
        cleanup(chrome.userDataDir);
      }
      if (server.listening) {
        server.closeAllConnections();
        await new Promise((resolve) => server.close(resolve));
      }
    }
  });

const icon = '/assets/fonts/MaterialIcons-Regular.otf';
test('incomplete active build must serve the icons of its selected offline bootstrap', async () => {
  const old = worker(A);
  await warm(old, A);
  old.network(async () => new Response('icons:A'));
  await old.request(icon);
  const next = worker(B, old.stores);
  next.online(B);
  await next.request('/flutter_bootstrap.js'); // B main not yet available.
  await next.activate();
  next.offline();
  assert.equal(await (await next.request('/flutter_bootstrap.js')).text(), bootstrap(A));
  assert.equal(await (await next.request(core(A))).text(), `main:${A}`);
  const font = await next.request(icon);
  assert.equal(await font.text(), 'icons:A', 'cached A font must accompany A offline main');
});

test('old active worker cannot overwrite the previous offline font before new main finishes', async () => {
  const w = worker(A);
  await warm(w, A);
  w.network(async () => new Response('icons:A'));
  await w.request(icon);
  w.online(B);
  await w.request('/flutter_bootstrap.js'); // B core fetch still incomplete.
  w.network(async () => new Response('icons:B'));
  await w.request(icon);
  w.offline();
  assert.equal(await (await w.request('/flutter_bootstrap.js')).text(), bootstrap(A));
  const font = await w.request(icon);
  assert.equal(await font.text(), 'icons:A', 'B subset must not be served with A main');
});

test('online main still fetches if CacheStorage reads fail', async () => {
  const w = worker(A);
  w.online(B);
  w.caches.match = async () => { throw new Error('cache unavailable'); };
  const res = await w.request(core(B));
  assert.equal(await res.text(), `main:${B}`);
});

test('versioned deferred JS remains network-readable when its cache read fails', async () => {
  const w = worker(A);
  w.online(B);
  const match = w.caches.match;
  w.caches.match = async (req, options) => {
    const key = typeof req === 'string' ? req : req.url;
    if (key.includes('.part.js')) throw new Error('CacheStorage read failed');
    return match(req, options);
  };
  const response = await w.request(part(B));
  assert.equal(w.calls.length, 1, 'cache failure must not suppress a valid network response');
  assert.equal(await response.text(), `part:${B}`);
});
