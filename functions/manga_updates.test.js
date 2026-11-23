'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  extractLatestChaptersFromHomeHtml,
  buildMangaPushPayload,
  isWithinQuietHours,
  runMangaUpdateCheck,
} = require('./manga_updates.js');

test('isWithinQuietHours handles overnight and daytime windows', () => {
  assert.equal(isWithinQuietHours(23, 22, 8), true);
  assert.equal(isWithinQuietHours(3, 22, 8), true);
  assert.equal(isWithinQuietHours(8, 22, 8), false);
  assert.equal(isWithinQuietHours(14, 22, 8), false);
  assert.equal(isWithinQuietHours(10, 9, 12), true);
  assert.equal(isWithinQuietHours(10, 10, 10), false);
});

test('extractLatestChaptersFromHomeHtml picks highest chapter per slug', () => {
  const html = `
    <a href="https://mangakatana.com/manga/solo-leveling.123/c199">Chapter 199</a>
    <a href="https://mangakatana.com/manga/solo-leveling.123/c200.5">Chapter 200.5</a>
    <a href="https://mangakatana.com/manga/frieren.456/c135">Chapter 135</a>
  `;
  const map = extractLatestChaptersFromHomeHtml(html);
  assert.equal(map.get('solo-leveling.123')?.chapterNum, '200.5');
  assert.equal(map.get('frieren.456')?.chapterNum, '135');
});

test('buildMangaPushPayload formats single and batched manga_update payloads', () => {
  const single = buildMangaPushPayload([{ slug: 'frieren.456', title: 'Frieren', chapterNum: '136' }]);
  assert.equal(single.data.type, 'manga_update');
  assert.equal(single.data.slug, 'frieren.456');
  assert.match(single.body, /136/);

  const multi = buildMangaPushPayload([
    { slug: 'frieren.456', title: 'Frieren', chapterNum: '136' },
    { slug: 'solo.123', title: 'Solo Leveling', chapterNum: '201' },
    { slug: 'sakamoto.789', title: 'Sakamoto Days', chapterNum: '185' },
  ]);
  assert.equal(multi.data.type, 'manga_update');
  assert.match(multi.title, /3 followed manga/);
  assert.match(multi.body, /\+1 more/);
});

test('runMangaUpdateCheck respects quiet hours without losing unseen chapters', async () => {
  const writes = [];
  const pushed = [];
  const fakeDb = {
    collection: () => ({
      doc: (id) => ({
        get: async () => ({
          exists: true,
          data: () =>
            id.startsWith('clairjassen')
              ? { alertPrefs: { frequency: 'instant', quietHours: true } }
              : { alertPrefs: { frequency: 'instant', quietHours: false } },
        }),
        set: async (data) => writes.push({ id, data }),
      }),
      where: function () {
        return this;
      },
      get: async () => ({
        docs: [
          {
            id: 'khentsgdz|frieren.456',
            data: () => ({
              slug: 'frieren.456',
              title: 'Frieren',
              bookmarked: true,
              lastNotifiedChapter: '134',
            }),
            ref: { set: async (data) => writes.push({ id: 'khentsgdz|frieren.456', data }) },
          },
        ],
      }),
    }),
  };

  // 23:00 Asia/Manila (15:00 UTC)
  const res = await runMangaUpdateCheck({
    db: fakeDb,
    sendPush: async (uid, payload) => {
      pushed.push({ uid, payload });
      return true;
    },
    fetchLatest: async () => new Map([['frieren.456', { chapterId: 'c135', chapterNum: '135', num: 135 }]]),
    now: new Date('2026-11-23T15:00:00Z'),
  });

  assert.equal(res.sentCount, 1);
  assert.equal(pushed.length, 1);
  assert.equal(pushed[0].uid, 'khentsgdz');
  assert.equal(pushed[0].payload.data.type, 'manga_update');
  assert.equal(pushed[0].payload.data.slug, 'frieren.456');
  assert.equal(writes.length, 1);
});
