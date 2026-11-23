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

test('runMangaUpdateCheck skips completed/dropped/on-hold series and supports MangaDex md- slugs', async () => {
  const pushed = [];
  const fakeDb = {
    collection: () => ({
      doc: () => ({
        get: async () => ({
          exists: true,
          data: () => ({
            alertPrefs: { frequency: 'instant', quietHours: false, skipCompleted: true, skipOnHold: true },
          }),
        }),
        set: async () => {},
      }),
      where: function () {
        return this;
      },
      get: async () => ({
        docs: [
          {
            id: 'khentsgdz|completed.1',
            data: () => ({
              slug: 'completed.1',
              title: 'Completed Series',
              bookmarked: true,
              readingStatus: 'completed',
              lastNotifiedChapter: '10',
            }),
            ref: { set: async () => {} },
          },
          {
            id: 'khentsgdz|onhold.2',
            data: () => ({
              slug: 'onhold.2',
              title: 'Paused Series',
              bookmarked: true,
              readingStatus: 'on_hold',
              lastNotifiedChapter: '10',
            }),
            ref: { set: async () => {} },
          },
          {
            id: 'khentsgdz|md-abcdef12-3456-7890-abcd-ef1234567890',
            data: () => ({
              slug: 'md-abcdef12-3456-7890-abcd-ef1234567890',
              title: 'MangaDex Series',
              bookmarked: true,
              readingStatus: 'reading',
              lastNotifiedChapter: '41',
            }),
            ref: { set: async () => {} },
          },
        ],
      }),
    }),
  };

  const res = await runMangaUpdateCheck({
    db: fakeDb,
    sendPush: async (uid, payload) => {
      pushed.push({ uid, payload });
      return true;
    },
    fetchLatest: async () =>
      new Map([
        ['completed.1', { chapterId: 'c11', chapterNum: '11', num: 11 }],
        ['onhold.2', { chapterId: 'c11', chapterNum: '11', num: 11 }],
      ]),
    fetchMangaDexLatest: async (slug) =>
      slug === 'md-abcdef12-3456-7890-abcd-ef1234567890'
        ? { chapterId: 'md-ch-42', chapterNum: '42', num: 42 }
        : null,
    now: new Date('2026-11-23T06:00:00Z'),
  });

  assert.equal(res.sentCount, 2);
  assert.equal(pushed[0].payload.data.slug, 'md-abcdef12-3456-7890-abcd-ef1234567890');
  assert.match(pushed[0].payload.body, /42/);
});
