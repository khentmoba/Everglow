import assert from 'node:assert/strict';
import test from 'node:test';
import { loadHlsConstructor } from '../src/features/watch_party/hlsLoader.ts';

function installFakeDom() {
  const scripts = [];
  const head = {
    children: scripts,
    appendChild(node) {
      node.parentNode = head;
      scripts.push(node);
      return node;
    },
    removeChild(node) {
      const idx = scripts.indexOf(node);
      if (idx !== -1) scripts.splice(idx, 1);
      node.parentNode = null;
      return node;
    },
  };

  function makeScript() {
    const listeners = new Map();
    return {
      id: '',
      src: '',
      crossOrigin: '',
      parentNode: null,
      listeners,
      addEventListener(type, fn) {
        if (!listeners.has(type)) listeners.set(type, new Set());
        listeners.get(type).add(fn);
      },
      removeEventListener(type, fn) {
        listeners.get(type)?.delete(fn);
      },
      dispatch(type) {
        for (const fn of [...(listeners.get(type) ?? [])]) {
          listeners.get(type)?.delete(fn);
          fn();
        }
      },
    };
  }

  const fakeWindow = {
    setTimeout: globalThis.setTimeout.bind(globalThis),
    clearTimeout: globalThis.clearTimeout.bind(globalThis),
  };
  const fakeDocument = {
    head,
    getElementById(id) {
      return scripts.find((s) => s.id === id) ?? null;
    },
    createElement(tag) {
      assert.equal(tag, 'script');
      return makeScript();
    },
  };

  const prevWindow = globalThis.window;
  const prevDocument = globalThis.document;
  globalThis.window = fakeWindow;
  globalThis.document = fakeDocument;
  return {
    fakeWindow,
    scripts,
    restore() {
      if (prevWindow === undefined) delete globalThis.window;
      else globalThis.window = prevWindow;
      if (prevDocument === undefined) delete globalThis.document;
      else globalThis.document = prevDocument;
    },
  };
}

test('loadHlsConstructor deduplicates concurrent callers, cleans up on timeout/error, and retries cleanly', async () => {
  const env = installFakeDom();
  try {
    // 1. Two concurrent callers share one promise and one appended <script>.
    const p1 = loadHlsConstructor(30);
    const p2 = loadHlsConstructor(30);
    assert.equal(p1, p2, 'concurrent calls must share the in-flight promise');
    assert.equal(env.scripts.length, 1);
    const timedOutScript = env.scripts[0];

    // 2. Timeout resolves null, removes script + listeners, and resets promise for retry.
    const [r1, r2] = await Promise.all([p1, p2]);
    assert.equal(r1, null);
    assert.equal(r2, null);
    assert.equal(env.scripts.length, 0, 'timed-out script must be removed from head');
    assert.equal(timedOutScript.listeners.get('load')?.size ?? 0, 0);
    assert.equal(timedOutScript.listeners.get('error')?.size ?? 0, 0);

    // 3. Error event also cleans up and allows retry.
    const pErr = loadHlsConstructor(500);
    assert.equal(env.scripts.length, 1);
    env.scripts[0].dispatch('error');
    assert.equal(await pErr, null);
    assert.equal(env.scripts.length, 0);

    // 4. Subsequent retry appends a fresh <script> and resolves window.Hls on load.
    const fakeHls = function FakeHls() {};
    const pOk = loadHlsConstructor(500);
    assert.equal(env.scripts.length, 1);
    env.fakeWindow.Hls = fakeHls;
    env.scripts[0].dispatch('load');
    assert.equal(await pOk, fakeHls);
    assert.equal(env.scripts.length, 1, 'loaded script stays in head');

    // 5. Already-loaded window.Hls resolves immediately without appending another script.
    assert.equal(await loadHlsConstructor(500), fakeHls);
    assert.equal(env.scripts.length, 1);
  } finally {
    env.restore();
  }
});
