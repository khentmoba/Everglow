import assert from 'node:assert/strict';
import { register } from 'node:module';
import test from 'node:test';

register('./ai_chat_ts_loader.mjs', import.meta.url);

const { fetchFallbackChapterPages } = await import('../src/features/manga/mangaFallbackProviders.ts');

test('ComicK fallback routes meo.comick.pictures images through proxyScanlation', async (t) => {
  t.mock.method(globalThis, 'fetch', async (url) => {
    const u = String(url);
    if (u.includes('proxyMangaDex')) {
      return { ok: true, json: async () => ({ data: [] }) };
    }
    if (u.includes('proxyComick') && u.includes('search')) {
      return { ok: true, json: async () => [{ hid: 'comic-hid' }] };
    }
    if (u.includes('proxyComick') && u.includes('chapters')) {
      return { ok: true, json: async () => ({ chapters: [{ hid: 'ch-hid' }] }) };
    }
    if (u.includes('proxyComick') && u.includes('ch-hid')) {
      return {
        ok: true,
        json: async () => ({
          chapter: { md_images: [{ b2key: 'p1.jpg' }, { b2key: 'p2.jpg' }] },
        }),
      };
    }
    return { ok: false, status: 404 };
  });

  const res = await fetchFallbackChapterPages('solo-leveling', 'c1');
  assert.equal(res.source, 'ComicK');
  assert.equal(res.pages.length, 2);
  assert.ok(res.pages[0].includes('/proxyScanlation?'), `expected proxyScanlation, got ${res.pages[0]}`);
  assert.ok(!res.pages[0].includes('/proxyMangaImage?'), `must not route comick.pictures to proxyMangaImage`);
  assert.ok(res.pages[0].includes(encodeURIComponent('https://meo.comick.pictures/p1.jpg')));
});

test('Scanlation fallback deduplicates repeated page image URLs', async (t) => {
  t.mock.method(globalThis, 'fetch', async (url) => {
    const u = String(url);
    if (u.includes('proxyMangaDex') || u.includes('proxyComick')) {
      return { ok: false, status: 404 };
    }
    if (u.includes('proxyFetchHtml') && u.includes('bato.to')) {
      return { ok: false, status: 404 };
    }
    if (u.includes('proxyFetchHtml') && u.includes('asurascans.com') && !u.includes('chapter-1')) {
      return {
        ok: true,
        text: async () => '<a href="https://asurascans.com/solo-leveling-chapter-1/">Ch 1</a>',
      };
    }
    if (u.includes('proxyFetchHtml') && u.includes('chapter-1')) {
      return {
        ok: true,
        text: async () => [
          '<img src="https://cdn.asurascans.com/p1.jpg">',
          '<img src="https://cdn.asurascans.com/p1.jpg">',
          '<img src="https://cdn.asurascans.com/p2.jpg">',
          '<img src="https://cdn.asurascans.com/p3.jpg">',
          '<img src="https://cdn.asurascans.com/p2.jpg">',
        ].join(''),
      };
    }
    return { ok: false, status: 404 };
  });

  const res = await fetchFallbackChapterPages('solo-leveling', 'c1');
  assert.equal(res.source, 'Scanlation');
  assert.equal(res.pages.length, 3);
  assert.equal(new Set(res.pages).size, 3);
});
