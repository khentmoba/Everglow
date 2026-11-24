import assert from 'node:assert/strict';
import { register } from 'node:module';
import test from 'node:test';

const mockLoader = `
export async function resolve(specifier, context, nextResolve) {
  if (specifier === 'react') return { url: 'mock:react', shortCircuit: true };
  if (specifier.endsWith('/agent/agentMode')) return { url: 'mock:agentMode', shortCircuit: true };
  if (specifier.endsWith('/system/logger')) return { url: 'mock:logger', shortCircuit: true };
  if (specifier.endsWith('/system/prefs')) return { url: 'mock:prefs', shortCircuit: true };
  if (specifier.endsWith('/system/store')) return { url: 'mock:store', shortCircuit: true };
  return nextResolve(specifier, context);
}

export async function load(url, context, nextLoad) {
  if (url === 'mock:react') {
    return { format: 'module', shortCircuit: true, source: 'export function useEffect() {}' };
  }
  if (url === 'mock:agentMode') {
    return { format: 'module', shortCircuit: true, source: 'export const AgentMode = { demo: false };' };
  }
  if (url === 'mock:logger') {
    return { format: 'module', shortCircuit: true, source: 'export const Logger = { e() {}, w() {}, i() {} };' };
  }
  if (url === 'mock:prefs') {
    return {
      format: 'module',
      shortCircuit: true,
      source: 'const map = new Map(); export const Prefs = { getString: (k) => map.get(k) ?? null, set: (k, v) => map.set(k, v) };',
    };
  }
  if (url === 'mock:store') {
    return {
      format: 'module',
      shortCircuit: true,
      source: 'export class ValueNotifier { constructor(v) { this.value = v; } } export function useValue(n) { return n.value; }',
    };
  }
  return nextLoad(url, context);
}
`;

register(`data:text/javascript,${encodeURIComponent(mockLoader)}`, import.meta.url);

if (typeof globalThis.window === 'undefined') {
  globalThis.window = {
    location: { origin: 'https://everglow-1c6db.web.app' },
    setTimeout: globalThis.setTimeout,
    clearTimeout: globalThis.clearTimeout,
  };
}

const { defaultMangaPageProxy, parseZipEntries, offlineMedia, OfflineIds } = await import(
  '../src/core/services/offlineMedia.ts'
);

test('defaultMangaPageProxy routes hosts to real Cloud Function endpoints', () => {
  const katana = defaultMangaPageProxy('https://i1.mangakatana.com/token/01.avif');
  assert.ok(katana.includes('/proxyMangaKatana?url='), katana);
  assert.ok(!katana.includes('proxyKatanaImage'), 'must never hit nonexistent proxyKatanaImage');
  assert.ok(decodeURIComponent(katana).endsWith('.webp'));

  const dex = defaultMangaPageProxy('https://uploads.mangadex.org/data/abc/1.jpg');
  assert.ok(dex.includes('/proxyMangaImage?url='), dex);

  const comick = defaultMangaPageProxy('https://meo.comick.pictures/cover.jpg');
  assert.ok(comick.includes('/proxyScanlation?url='), comick);
});

test('parseZipEntries handles truncated Central Directory without throwing and enforces size caps', async () => {
  // Truncated Central Directory entry claiming a 500-byte filename inside a 90-byte buffer
  const corrupt = new Uint8Array(90);
  const view = new DataView(corrupt.buffer);
  // Central Directory signature at offset 0
  view.setUint32(0, 0x02014b50, true);
  view.setUint16(28, 500, true); // nameLen exceeds buffer
  // EOCD at offset 68 (90 - 22)
  view.setUint32(68, 0x06054b50, true);
  view.setUint16(78, 1, true); // totalEntries = 1
  view.setUint32(84, 0, true); // cdOffset = 0
  const corruptEntries = await parseZipEntries(corrupt.buffer);
  assert.deepEqual(corruptEntries, []);

  // Stored ZIP entry exceeding maxTotalBytes cap must be skipped
  const nameBytes = new TextEncoder().encode('001.jpg');
  const payload = new Uint8Array(64).fill(0xab);
  const local = new Uint8Array(30 + nameBytes.length + payload.length);
  const lv = new DataView(local.buffer);
  lv.setUint32(0, 0x04034b50, true);
  lv.setUint16(8, 0, true); // store
  lv.setUint32(18, payload.length, true);
  lv.setUint32(22, payload.length, true);
  lv.setUint16(26, nameBytes.length, true);
  local.set(nameBytes, 30);
  local.set(payload, 30 + nameBytes.length);

  const accepted = await parseZipEntries(local.buffer, { maxEntryBytes: 128, maxTotalBytes: 128 });
  assert.equal(accepted.length, 1);
  await assert.rejects(
    () => parseZipEntries(local.buffer, { maxEntryBytes: 32, maxTotalBytes: 32 }),
    /exceeds size limit/,
  );
});

test('startDownloadMangaChapter fails and aborts immediately when Cache Storage put fails', async () => {
  const origCaches = globalThis.caches;
  const origFetch = globalThis.fetch;
  let fetchCount = 0;
  globalThis.caches = {
    open: async () => ({
      match: async () => undefined,
      put: async () => {
        throw new Error('QuotaExceededError');
      },
      delete: async () => true,
    }),
    delete: async () => true,
  };
  globalThis.fetch = async () => {
    fetchCount++;
    return new Response(new Uint8Array([0xff, 0xd8, 0xff, 0xd9]), {
      status: 200,
      headers: { 'Content-Type': 'image/jpeg' },
    });
  };
  try {
    await offlineMedia.startDownloadMangaChapter({
      slug: 'quota-test',
      mangaTitle: 'Quota Test',
      coverUrl: '',
      chapterId: 'c1',
      chapterTitle: 'Chapter 1',
      pageUrls: [
        'https://i1.mangakatana.com/token/01.jpg',
        'https://i1.mangakatana.com/token/02.jpg',
        'https://i1.mangakatana.com/token/03.jpg',
      ],
    });
    const item = offlineMedia.getItem(OfflineIds.mangaChapterId('quota-test', 'c1'));
    assert.ok(item);
    assert.equal(item.status, 'failed');
    assert.equal(item.downloadedPages, 0);
    assert.equal(fetchCount, 1, 'should stop after first storage quota failure instead of fetching remaining pages');
  } finally {
    globalThis.caches = origCaches;
    globalThis.fetch = origFetch;
  }
});

test('importMangaChapterCbz preserves existing cached chapter if re-import hits storage quota', async () => {
  const origCaches = globalThis.caches;
  const store = new Map();
  let failOnSecondTmp = false;
  let tmpWrites = 0;
  globalThis.caches = {
    open: async () => ({
      match: async (k) => store.get(String(k)),
      put: async (k, resp) => {
        const key = String(k);
        if (failOnSecondTmp && key.includes('_tmp_p_')) {
          tmpWrites++;
          if (tmpWrites >= 2) throw new Error('QuotaExceededError');
        }
        store.set(key, resp);
      },
      delete: async (k) => store.delete(String(k)),
    }),
    delete: async () => true,
  };

  function makeStoredZip(files) {
    const enc = new TextEncoder();
    const parts = [];
    for (const f of files) {
      const nameBytes = enc.encode(f.name);
      const header = new Uint8Array(30 + nameBytes.length);
      const v = new DataView(header.buffer);
      v.setUint32(0, 0x04034b50, true);
      v.setUint16(8, 0, true);
      v.setUint32(18, f.data.length, true);
      v.setUint32(22, f.data.length, true);
      v.setUint16(26, nameBytes.length, true);
      header.set(nameBytes, 30);
      parts.push(header, f.data);
    }
    const total = parts.reduce((a, p) => a + p.length, 0);
    const out = new Uint8Array(total);
    let off = 0;
    for (const p of parts) {
      out.set(p, off);
      off += p.length;
    }
    return out;
  }

  try {
    const zipBytes = makeStoredZip([
      { name: '001.jpg', data: new Uint8Array([1, 2, 3, 4]) },
      { name: '002.jpg', data: new Uint8Array([5, 6, 7, 8]) },
    ]);
    const file1 = { name: 'reimport-test-ch1.cbz', arrayBuffer: async () => zipBytes.buffer };
    const first = await offlineMedia.importMangaChapterCbz(file1);
    assert.ok(first);
    assert.equal(first.status, 'completed');
    const existingKeys = [...store.keys()];
    assert.equal(existingKeys.length, 2);

    // Re-import the same chapter when staging the 2nd page throws QuotaExceededError
    failOnSecondTmp = true;
    const second = await offlineMedia.importMangaChapterCbz(file1);
    assert.equal(second, null);
    const afterItem = offlineMedia.getItem(first.id);
    assert.ok(afterItem);
    assert.equal(afterItem.status, 'completed');
    // Existing chapter blobs must still be present and no temp blobs left behind
    assert.deepEqual([...store.keys()].sort(), existingKeys.sort());
  } finally {
    globalThis.caches = origCaches;
  }
});

test('exportMangaChapterCbz opens Cache Storage once across all pages', async () => {
  const store = new Map();
  let openCalls = 0;
  const origCaches = globalThis.caches;
  const id = OfflineIds.mangaChapterId('cache-once-slug', 'c1');
  const origin = window.location.origin;
  store.set(`${origin}/offline-manga/${encodeURIComponent(`${id}_p_1`)}`, new Response(new Uint8Array([1, 2, 3])));
  store.set(`${origin}/offline-manga/${encodeURIComponent(`${id}_p_2`)}`, new Response(new Uint8Array([4, 5, 6])));
  store.set(`${origin}/offline-manga/${encodeURIComponent(`${id}_p_3`)}`, new Response(new Uint8Array([7, 8, 9])));
  globalThis.caches = {
    open: async () => {
      openCalls++;
      return {
        match: async (k) => {
          const res = store.get(k);
          return res ? res.clone() : undefined;
        },
      };
    },
  };
  offlineMedia.value = {
    ...offlineMedia.value,
    [id]: {
      id,
      type: 'manga',
      mediaId: 'cache-once-slug',
      chapterId: 'c1',
      title: 'Cache Once Test',
      subtitle: 'Chapter 1',
      coverUrl: '',
      status: 'completed',
      progress: 1,
      pageUrls: ['https://a/1.jpg', 'https://a/2.jpg', 'https://a/3.jpg'],
      downloadedPages: 3,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    },
  };
  try {
    const exported = await offlineMedia.exportMangaChapterCbz(id);
    assert.ok(exported);
    assert.equal(openCalls, 1);
  } finally {
    globalThis.caches = origCaches;
  }
});
