import assert from 'node:assert/strict';
import test from 'node:test';

// `--experimental-strip-types` lets the browser helper load in plain Node.
const { setBoundedCache, clearOnLogout } = await import('../src/core/utils/boundedCache.ts');

test('setBoundedCache keeps the newest entries and evicts the oldest', () => {
  const cache = new Map();
  for (let i = 0; i < 5; i++) setBoundedCache(cache, `k${i}`, i, 3);
  assert.deepEqual([...cache.keys()], ['k2', 'k3', 'k4'], 'only the newest 3 survive');
  assert.equal(cache.size, 3);
});

test('setBoundedCache rewrites the newest entry instead of duplicating it', () => {
  const cache = new Map([
    ['a', 1],
    ['b', 2],
  ]);
  setBoundedCache(cache, 'a', 9, 2);
  assert.deepEqual([...cache.entries()], [
    ['b', 2],
    ['a', 9],
  ]);
});

test('setBoundedCache never drops the entry it was given, even at max 1', () => {
  const cache = new Map();
  setBoundedCache(cache, 'only', 1, 1);
  setBoundedCache(cache, 'only', 2, 1);
  assert.deepEqual([...cache.entries()], [['only', 2]]);
});

test('clearOnLogout empties every cache it was given when the event fires', () => {
  const previousWindow = globalThis.window;
  globalThis.window = new EventTarget();
  try {
    const details = new Map([['a', 1]]);
    const images = new Map([['b', 2]]);
    const untouched = new Map([['c', 3]]);
    clearOnLogout(details, images);
    globalThis.window.dispatchEvent(new Event('everglow:logout'));
    assert.equal(details.size, 0);
    assert.equal(images.size, 0);
    assert.equal(untouched.size, 1);
  } finally {
    if (previousWindow === undefined) delete globalThis.window;
    else globalThis.window = previousWindow;
  }
});
