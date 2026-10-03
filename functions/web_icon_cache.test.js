"use strict";

const {test} = require("node:test");
const assert = require("node:assert/strict");
const {readFileSync} = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const origin = "https://demo.everglow.test";
const font = "/assets/fonts/MaterialIcons-Regular.otf";
const manifest = "/assets/FontManifest.json";

function worker() {
  // Exercise the generator, not a potentially stale checked-in sw.js.
  const dart = readFileSync(path.join(root, "tool/generate_sw.dart"), "utf8");
  const source = dart.match(/final sw\s*=\s*"""([\s\S]*?)""";/)[1]
      .replaceAll("$buildConst", "test-build")
      .replaceAll("\\$", "$")
      .replaceAll("\\\\", "\\");
  const stores = new Map();
  const handlers = {};
  const calls = [];
  let offline = false;
  const key = (req) => typeof req === "string" ? req : req.url;
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
  const context = vm.createContext({
    URL, Response, caches,
    navigator: {onLine: false}, // No unrelated shell warm-up during activation.
    self: {
      location: {origin},
      clients: {async claim() {}},
      addEventListener: (event, handler) => { handlers[event] = handler; },
    },
    async fetch(req, options) {
      calls.push({url: key(req), cache: options?.cache});
      if (offline) throw new Error("offline");
      return new Response("current-build");
    },
  });
  vm.runInContext(source, context);
  return {
    stores, caches, calls,
    offline() { offline = true; },
    async seed(name, url, body) {
      await (await caches.open(name)).put(origin + url, new Response(body));
    },
    async activate() {
      let done;
      handlers.activate({waitUntil(promise) { done = promise; }});
      await done;
    },
    async request(url) {
      let response;
      handlers.fetch({
        request: {method: "GET", url: origin + url},
        respondWith(promise) { response = promise; },
      });
      return response;
    },
  };
}

for (const asset of [font, manifest]) {
  test(`${asset} refreshes across app builds and remains usable offline`, async () => {
    const w = worker();
    await w.seed("canvaskit-__ENGINE_REV__", asset, "old-build-missing-tonight");
    const response = await w.request(asset);
    assert.equal(await response.text(), "current-build");
    assert.equal(w.calls[0].cache, "no-cache", "bypass old immutable HTTP bytes");
    // Let the worker's asynchronous cache write finish.
    await new Promise((resolve) => setImmediate(resolve));
    w.offline();
    assert.equal(await (await w.request(asset)).text(), "current-build");
  });
}

test("activation removes old icon bytes without evicting CanvasKit or core", async () => {
  const w = worker();
  const engine = "canvaskit-__ENGINE_REV__";
  await w.seed(engine, font, "old-icons");
  await w.seed(engine, manifest, "old-manifest");
  await w.seed(engine, "/canvaskit/canvaskit.wasm", "engine");
  await w.seed("everglow-core-v1", "/main.dart.js?v=previous", "core");
  await w.activate();
  assert.equal(await w.caches.match(origin + font), undefined);
  assert.equal(await w.caches.match(origin + manifest), undefined);
  assert.equal(await (await w.request("/canvaskit/canvaskit.wasm")).text(), "engine");
  assert.equal(await (await w.request("/main.dart.js?v=previous")).text(), "core");
  assert.equal(w.calls.length, 0);
});

test("hosting revalidates the build-dependent icon font and manifest", () => {
  const {hosting} = JSON.parse(readFileSync(path.join(root, "firebase.json"), "utf8"));
  for (const asset of [font, manifest]) {
    const rule = hosting.headers.findLast((entry) => entry.source === asset);
    assert.ok(rule, `missing explicit header for ${asset}`);
    assert.equal(rule.headers.find((h) => h.key === "Cache-Control").value,
        "public, max-age=0, must-revalidate");
  }
});
