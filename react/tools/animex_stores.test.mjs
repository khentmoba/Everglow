import assert from 'node:assert/strict';
import { register } from 'node:module';
import test from 'node:test';

const mockLoader = `
export async function resolve(specifier, context, nextResolve) {
  if (specifier.endsWith('/system/logger')) return { url: 'mock:logger', shortCircuit: true };
  if (specifier.endsWith('/system/prefs')) return { url: 'mock:prefs', shortCircuit: true };
  if (specifier.endsWith('/system/store')) return { url: 'mock:store', shortCircuit: true };
  if (specifier.endsWith('/cinema/tmdbService')) return { url: 'mock:tmdbService', shortCircuit: true };
  if (specifier.endsWith('/cinema/cinemaTypes')) return { url: 'mock:cinemaTypes', shortCircuit: true };
  if (specifier === './animexData') return { url: 'mock:animexData', shortCircuit: true };
  return nextResolve(specifier, context);
}

export async function load(url, context, nextLoad) {
  if (url === 'mock:logger') {
    return { format: 'module', shortCircuit: true, source: 'export const Logger = { e() {}, w() {}, i() {} };' };
  }
  if (url === 'mock:prefs') {
    return {
      format: 'module',
      shortCircuit: true,
      source: \`
        export const __store = new Map();
        export const Prefs = {
          getString: (k) => __store.get(k) ?? null,
          set: (k, v) => __store.set(k, v),
          remove: (k) => __store.delete(k),
        };
      \`,
    };
  }
  if (url === 'mock:store') {
    return {
      format: 'module',
      shortCircuit: true,
      source: 'export class ValueNotifier { constructor(v) { this.value = v; } } export function useValue(n) { return n.value; }',
    };
  }
  if (url === 'mock:tmdbService') {
    return { format: 'module', shortCircuit: true, source: 'export function isWatchedItem() { return false; }' };
  }
  if (url === 'mock:cinemaTypes') {
    return { format: 'module', shortCircuit: true, source: 'export {};' };
  }
  if (url === 'mock:animexData') {
    return { format: 'module', shortCircuit: true, source: 'export function mediaIsMovie() { return false; } export function mediaPosterUrl() { return ""; }' };
  }
  return nextLoad(url, context);
}
`;

register(`data:text/javascript,${encodeURIComponent(mockLoader)}`, import.meta.url);

const { __store } = await import('mock:prefs');
const { AnimexStores } = await import('../src/features/anime/animexStores.ts');

test('AnimexStores.load isolates malformed history/playlists JSON and still loads valid prefs', () => {
  __store.clear();
  __store.set('animex_watch_history_v1_khentsgdz', '{not-valid-json');
  __store.set('animex_playlists_v1_khentsgdz', '{"not":"an-array"}');
  __store.set(
    'animex_prefs_v1_khentsgdz',
    JSON.stringify({ titleJapanese: true, hideSpoilers: false, autoNext: false, skipIntro: false }),
  );

  AnimexStores.load('khentsgdz');

  assert.equal(AnimexStores.loaded, true);
  assert.deepEqual(AnimexStores.history, []);
  assert.deepEqual(AnimexStores.playlists, []);
  assert.equal(AnimexStores.titleJapanese, true);
  assert.equal(AnimexStores.hideSpoilers, false);
  assert.equal(AnimexStores.autoNext, false);
  assert.equal(AnimexStores.skipIntro, false);
});
