import assert from 'node:assert/strict';
import test from 'node:test';

const { loadNamedModule } = await import('../src/core/router/routeChunks.ts');

test('a chunk load failure rejects and schedules one reload instead of hanging', async () => {
  const store = new Map();
  let reloads = 0;
  globalThis.window = {
    sessionStorage: {
      getItem: (key) => store.get(key) ?? null,
      setItem: (key, value) => store.set(key, value),
      removeItem: (key) => store.delete(key),
    },
    location: {
      pathname: '/cinema',
      search: '?agent=1',
      reload: () => { reloads++; },
    },
  };

  try {
    const failure = new Error('Failed to fetch dynamically imported module');
    const loader = async () => { throw failure; };
    await assert.rejects(loadNamedModule(loader, 'x'), (err) => err === failure);
    await new Promise((resolve) => setTimeout(resolve, 5));
    assert.equal(reloads, 1);

    await assert.rejects(loadNamedModule(loader, 'x'), (err) => err === failure);
    await new Promise((resolve) => setTimeout(resolve, 5));
    assert.equal(reloads, 1);
  } finally {
    delete globalThis.window;
  }
});

test('a successful chunk load clears a stale reload marker', async () => {
  const store = new Map([['everglow:chunk-reload', '/cinema?agent=1']]);
  globalThis.window = {
    sessionStorage: {
      getItem: (key) => store.get(key) ?? null,
      setItem: (key, value) => store.set(key, value),
      removeItem: (key) => store.delete(key),
    },
    location: { pathname: '/cinema', search: '?agent=1', reload: () => {} },
  };

  try {
    const component = () => null;
    const loaded = await loadNamedModule(async () => ({ x: component }), 'x');
    assert.equal(loaded.default, component);
    assert.equal(store.has('everglow:chunk-reload'), false);
  } finally {
    delete globalThis.window;
  }
});
