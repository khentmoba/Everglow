"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { existsSync, readFileSync } = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const origin = "https://demo.everglow.test";

function workerFromViteConfig() {
  const viteSrc = readFileSync(path.join(root, "react/vite.config.ts"), "utf8");
  const match = viteSrc.match(/return `(\/\/ BUILD=\$\{buildStamp\}[\s\S]*?)`;/);
  assert.ok(match, "missing buildServiceWorkerSource template in react/vite.config.ts");
  const source = match[1]
    .replaceAll("${buildStamp}", "test-build")
    .replaceAll("${precacheList}", '["/index.html","/manifest.json","/assets/index-test.js"]')
    .replaceAll("\\$", "$")
    .replaceAll("\\`", "`");

  const stores = new Map();
  const handlers = {};
  let offline = false;
  const key = (req) => (typeof req === "string" ? req : req.url);
  const caches = {
    async open(name) {
      if (!stores.has(name)) stores.set(name, new Map());
      const data = stores.get(name);
      return {
        async keys() { return [...data.keys()].map((url) => ({ url })); },
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
    URL,
    Response,
    caches,
    importScripts() {},
    self: {
      location: { origin },
      skipWaiting() {},
      clients: { async claim() {}, async matchAll() { return []; }, async openWindow() {} },
      addEventListener: (event, handler) => { handlers[event] = handler; },
    },
    async fetch() {
      if (offline) throw new Error("offline");
      return new Response("fresh-asset", { status: 200 });
    },
  });
  vm.runInContext(source, context);
  return {
    stores,
    caches,
    offline() { offline = true; },
    async seed(name, url, body) {
      await (await caches.open(name)).put(origin + url, new Response(body));
    },
    async activate() {
      let done;
      handlers.activate({ waitUntil(promise) { done = promise; } });
      await done;
    },
    async request(url) {
      let response;
      handlers.fetch({
        request: { method: "GET", url: origin + url, mode: url === "/" ? "navigate" : "cors" },
        respondWith(promise) { response = promise; },
      });
      return response;
    },
  };
}

test("activation preserves offline photo/media/manga caches while evicting stale shell caches", async () => {
  const w = workerFromViteConfig();
  await w.seed("everglow-offline-photos-v1", "/photo/1.jpg", "photo-bytes");
  await w.seed("everglow-offline-media-v1", "/video/1.mp4", "video-bytes");
  await w.seed("everglow-offline-manga-v1", "/manga/1.webp", "manga-bytes");
  await w.seed("0.0.0-old-SHELL-v1", "/assets/index-old.js", "old-core");
  await w.activate();
  assert.ok(w.stores.has("everglow-offline-photos-v1"));
  assert.ok(w.stores.has("everglow-offline-media-v1"));
  assert.ok(w.stores.has("everglow-offline-manga-v1"));
  assert.equal(w.stores.has("0.0.0-old-SHELL-v1"), false);
});

test("cached hashed font/bundle assets remain readable offline", async () => {
  const w = workerFromViteConfig();
  const asset = "/assets/material-icons-test.woff2";
  const res = await w.request(asset);
  assert.equal(await res.text(), "fresh-asset");
  w.offline();
  const cached = await w.request(asset);
  assert.equal(await cached.text(), "fresh-asset");
});

test("hosting marks Vite assets immutable and revalidates shell metadata", () => {
  const { hosting } = JSON.parse(readFileSync(path.join(root, "firebase.json"), "utf8"));
  assert.equal(hosting.public, "react/dist");
  const hasCache = (src, pred) =>
    hosting.headers.some((e) => e.source === src && e.headers.some((h) => h.key === "Cache-Control" && pred(h.value)));
  assert.ok(hasCache("/assets/**", (v) => v.includes("immutable")));
  for (const src of ["/", "/index.html", "/sw.js", "/version.json", "/manifest{,_screen}.json"]) {
    assert.ok(hasCache(src, (v) => v.includes("no-cache")), `missing no-cache on ${src}`);
  }
  assert.ok(existsSync(path.join(root, "react/vite.config.ts")));
});
