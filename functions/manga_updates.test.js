'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  extractLatestChaptersFromFeedXml,
  extractLatestChaptersFromHomeHtml,
  buildMangaPushPayload,
  isWithinQuietHours,
  parseChapterNumber,
  runMangaUpdateCheck,
} = require('./manga_updates.js');

test('parseChapterNumber prioritizes explicit chapter tokens over season/volume numbers', () => {
  assert.equal(parseChapterNumber('Season 2 #1'), 1);
  assert.equal(parseChapterNumber('Vol. 3 Ch. 14.5'), 14.5);
  assert.equal(parseChapterNumber('c108'), 108);
  assert.equal(parseChapterNumber('210.5'), 210.5);
});

test('isWithinQuietHours handles overnight and daytime windows', () => {
  assert.equal(isWithinQuietHours(23, 22, 8), true);
  assert.equal(isWithinQuietHours(3, 22, 8), true);
  assert.equal(isWithinQuietHours(8, 22, 8), false);
  assert.equal(isWithinQuietHours(14, 22, 8), false);
  assert.equal(isWithinQuietHours(10, 9, 12), true);
  assert.equal(isWithinQuietHours(10, 10, 10), false);
});

test('extractLatestChaptersFromFeedXml parses RSS feed links and picks highest chapter', () => {
  const xml = `
    <rss><channel>
      <item><link>https://mangakatana.com/manga/frieren.456/c135</link></item>
      <item><link>https://mangakatana.com/manga/frieren.456/c136</link></item>
      <item><link>https://mangakatana.com/manga/solo.123/c200.5</link></item>
    </channel></rss>
  `;
  const map = extractLatestChaptersFromFeedXml(xml);
  assert.equal(map.get('frieren.456')?.chapterNum, '136');
  assert.equal(map.get('solo.123')?.chapterNum, '200.5');
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
  const single = buildMangaPushPayload([{ slug: 'frieren.456', title: 'Frieren', chapterNum: '136', chapterId: 'c136' }]);
  assert.equal(single.data.type, 'manga_update');
  assert.equal(single.data.slug, 'frieren.456');
  assert.equal(single.data.chapterId, 'c136');
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
    fetchKatanaSeriesLatest: async () => null,
    now: new Date('2026-11-23T15:00:00Z'),
  });

  assert.equal(res.sentCount, 1);
  assert.equal(pushed.length, 1);
  assert.equal(pushed[0].uid, 'khentsgdz');
  assert.equal(pushed[0].payload.data.type, 'manga_update');
  assert.equal(pushed[0].payload.data.slug, 'frieren.456');
  assert.ok(writes.some((w) => w.id === 'khentsgdz|frieren.456' && w.data.lastNotifiedChapter === '135'));
  assert.ok(writes.some((w) => w.id === 'khentsgdz|__prefs__' && typeof w.data.lastUpdateCheckAt === 'number'));
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
    fetchKatanaSeriesLatest: async () => null,
    now: new Date('2026-11-23T06:00:00Z'),
  });

  assert.equal(res.sentCount, 2);
  assert.equal(pushed[0].payload.data.slug, 'md-abcdef12-3456-7890-abcd-ef1234567890');
  assert.match(pushed[0].payload.body, /42/);
});

test('runMangaUpdateCheck reads a followed series page when it misses the feed, seeding silently first', async () => {
  const writes = [];
  const pushed = [];
  const makeDb = (bookmark) => ({
    collection: () => ({
      doc: (id) => ({
        get: async () => ({ exists: true, data: () => ({ alertPrefs: { frequency: 'instant', quietHours: false } }) }),
        set: async (data) => writes.push({ id, data }),
      }),
      where: function () {
        return this;
      },
      get: async () => ({
        docs: [
          {
            id: 'khentsgdz|solo.99',
            data: () => ({ slug: 'solo.99', title: 'Solo', bookmarked: true, readingStatus: 'reading', ...bookmark }),
            ref: { set: async (data) => writes.push({ id: 'khentsgdz|solo.99', data }) },
          },
        ],
      }),
    }),
  });
  const opts = {
    sendPush: async (uid, payload) => {
      pushed.push({ uid, payload });
      return true;
    },
    fetchLatest: async () => new Map(),
    fetchMangaDexLatest: async () => null,
    fetchKatanaSeriesLatest: async (slug) => (slug === 'solo.99' ? { chapterId: 'c12', chapterNum: '12', num: 12 } : null),
    now: new Date('2026-11-23T06:00:00Z'),
  };

  const first = await runMangaUpdateCheck({ db: makeDb({}), ...opts });
  assert.equal(first.sentCount, 0);
  assert.ok(writes.some((w) => w.id === 'khentsgdz|solo.99' && w.data.latestChapterNum === '12'));

  const second = await runMangaUpdateCheck({ db: makeDb({ latestChapterNum: '11' }), ...opts });
  assert.equal(second.sentCount, 2);
  assert.match(pushed[0].payload.body, /12/);
});

test('runMangaUpdateCheck respects custom quietStartHour/quietEndHour and predicted nextCheckAt cadence', async () => {
  let seriesProbes = 0;
  const fakeDb = {
    collection: () => ({
      doc: () => ({
        get: async () => ({
          exists: true,
          data: () => ({
            alertPrefs: { frequency: 'instant', quietHours: false, quietStartHour: 1, quietEndHour: 6 },
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
            id: 'khentsgdz|future.1',
            data: () => ({
              slug: 'future.1',
              title: 'Not Due Yet',
              bookmarked: true,
              readingStatus: 'reading',
              latestChapterNum: '10',
              nextCheckAt: Date.parse('2026-11-23T12:00:00Z'),
            }),
            ref: { set: async () => {} },
          },
        ],
      }),
    }),
  };

  await runMangaUpdateCheck({
    db: fakeDb,
    sendPush: async () => true,
    fetchLatest: async () => new Map(),
    fetchMangaDexLatest: async () => null,
    fetchKatanaSeriesLatest: async () => {
      seriesProbes += 1;
      return { chapterId: 'c11', chapterNum: '11', num: 11 };
    },
    now: new Date('2026-11-23T06:00:00Z'),
  });

  assert.equal(seriesProbes, 0, 'should skip direct series probe when now < nextCheckAt');
});

test('runMangaUpdateCheck batch-resolves multiple MangaDex md- slugs and persists updateCursorSlug', async () => {
  const writes = [];
  const pushed = [];
  const fakeDb = {
    collection: () => ({
      doc: (id) => ({
        get: async () => ({
          exists: true,
          data: () => ({
            alertPrefs: { frequency: 'instant', quietHours: false },
            updateCursorSlug: 'katana.1',
          }),
        }),
        set: async (data) => writes.push({ id, data }),
      }),
      where: function () {
        return this;
      },
      get: async () => ({
        docs: [
          {
            id: 'khentsgdz|katana.1',
            data: () => ({ slug: 'katana.1', title: 'Katana 1', bookmarked: true, lastNotifiedChapter: '5' }),
            ref: { set: async (data) => writes.push({ id: 'khentsgdz|katana.1', data }) },
          },
          {
            id: 'khentsgdz|katana.2',
            data: () => ({ slug: 'katana.2', title: 'Katana 2', bookmarked: true, lastNotifiedChapter: '8' }),
            ref: { set: async (data) => writes.push({ id: 'khentsgdz|katana.2', data }) },
          },
          {
            id: 'khentsgdz|md-11111111-2222-3333-4444-555555555555',
            data: () => ({
              slug: 'md-11111111-2222-3333-4444-555555555555',
              title: 'MD Series A',
              bookmarked: true,
              lastNotifiedChapter: '10',
            }),
            ref: { set: async (data) => writes.push({ id: 'khentsgdz|md-a', data }) },
          },
          {
            id: 'khentsgdz|md-66666666-7777-8888-9999-000000000000',
            data: () => ({
              slug: 'md-66666666-7777-8888-9999-000000000000',
              title: 'MD Series B',
              bookmarked: true,
              lastNotifiedChapter: '20',
            }),
            ref: { set: async (data) => writes.push({ id: 'khentsgdz|md-b', data }) },
          },
        ],
      }),
    }),
  };

  let batchCalls = 0;
  let singleMdCalls = 0;
  await runMangaUpdateCheck({
    db: fakeDb,
    sendPush: async (uid, payload) => {
      pushed.push({ uid, payload });
      return true;
    },
    fetchLatest: async () => new Map(),
    fetchMangaDexBatch: async (slugs) => {
      batchCalls += 1;
      assert.equal(slugs.length, 2);
      return new Map([
        ['md-11111111-2222-3333-4444-555555555555', { chapterId: 'md-c11', chapterNum: '11', num: 11 }],
        ['md-66666666-7777-8888-9999-000000000000', { chapterId: 'md-c20', chapterNum: '20', num: 20 }],
      ]);
    },
    fetchMangaDexLatest: async () => {
      singleMdCalls += 1;
      return null;
    },
    fetchKatanaSeriesLatest: async () => null,
    now: new Date('2026-11-23T06:00:00Z'),
  });

  assert.equal(batchCalls, 2);
  assert.equal(singleMdCalls, 0, 'batch map should satisfy both md- slugs without individual probes');
  assert.equal(pushed.length, 2);
  assert.ok(writes.some((w) => w.id === 'khentsgdz|__prefs__' && typeof w.data.updateCursorSlug === 'string'));
  assert.ok(writes.some((w) => w.id === 'khentsgdz|__prefs__' && w.data.sourceHealth?.fallbackActive === true));
});

test('runMangaUpdateCheck skips bookmarks with ignoreUpdates=true or in excludeUpdateCategories', async () => {
  const pushed = [];
  const fakeDb = {
    collection: () => ({
      doc: () => ({
        get: async () => ({
          exists: true,
          data: () => ({
            alertPrefs: {
              frequency: 'instant',
              quietHours: false,
              excludeUpdateCategories: ['Backlog'],
            },
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
            id: 'khentsgdz|ignored.1',
            data: () => ({
              slug: 'ignored.1',
              title: 'Ignored Series',
              bookmarked: true,
              ignoreUpdates: true,
              lastNotifiedChapter: '10',
            }),
            ref: { set: async () => {} },
          },
          {
            id: 'khentsgdz|cat.2',
            data: () => ({
              slug: 'cat.2',
              title: 'Backlog Series',
              bookmarked: true,
              categories: ['Backlog'],
              lastNotifiedChapter: '10',
            }),
            ref: { set: async () => {} },
          },
        ],
      }),
    }),
  };

  await runMangaUpdateCheck({
    db: fakeDb,
    sendPush: async (uid, payload) => {
      pushed.push({ uid, payload });
      return true;
    },
    fetchLatest: async () =>
      new Map([
        ['ignored.1', { chapterId: 'c11', chapterNum: '11', num: 11 }],
        ['cat.2', { chapterId: 'c11', chapterNum: '11', num: 11 }],
      ]),
    fetchMangaDexLatest: async () => null,
    fetchKatanaSeriesLatest: async () => null,
    now: new Date('2026-11-23T06:00:00Z'),
  });

  assert.equal(pushed.length, 0);
});

test('runMangaUpdateCheck checks ComicK ck- and Bato bt- slugs and alerts khentsgdz after 2 consecutive feed failures', async () => {
  const writes = [];
  const pushed = [];
  const fakeDb = {
    collection: () => ({
      doc: (id) => ({
        get: async () => ({
          exists: true,
          data: () => ({
            alertPrefs: { frequency: 'instant', quietHours: false },
            sourceHealth: { fallbackActive: true, consecutiveFeedFailures: 1 },
          }),
        }),
        set: async (data) => writes.push({ id, data }),
      }),
      where: function () {
        return this;
      },
      get: async () => ({
        docs: [
          {
            id: 'khentsgdz|ck-hid12345',
            data: () => ({
              slug: 'ck-hid12345',
              title: 'ComicK Series',
              bookmarked: true,
              lastNotifiedChapter: '14',
            }),
            ref: { set: async (data) => writes.push({ id: 'khentsgdz|ck-hid12345', data }) },
          },
          {
            id: 'khentsgdz|bt-987654',
            data: () => ({
              slug: 'bt-987654',
              title: 'Bato Webtoon',
              bookmarked: true,
              lastNotifiedChapter: '88',
            }),
            ref: { set: async (data) => writes.push({ id: 'khentsgdz|bt-987654', data }) },
          },
        ],
      }),
    }),
  };

  await runMangaUpdateCheck({
    db: fakeDb,
    sendPush: async (uid, payload) => {
      pushed.push({ uid, payload });
      return true;
    },
    fetchLatest: async () => new Map(),
    fetchComickLatest: async (slug) =>
      slug === 'ck-hid12345' ? { chapterId: 'ck-ch15', chapterNum: '15', num: 15 } : null,
    fetchBatoLatest: async (slug) =>
      slug === 'bt-987654' ? { chapterId: 'bt-ch89', chapterNum: '89', num: 89 } : null,
    fetchKatanaSeriesLatest: async () => null,
    now: new Date('2026-11-23T06:00:00Z'),
  });

  assert.ok(pushed.some((p) => p.uid === 'khentsgdz' && /Feed fallback active/.test(p.payload.title)));
  assert.ok(pushed.some((p) => p.uid === 'khentsgdz' && /2 followed manga updated/.test(p.payload.title)));
  assert.ok(writes.some((w) => w.id === 'khentsgdz|ck-hid12345' && w.data.lastNotifiedChapter === '15'));
  assert.ok(writes.some((w) => w.id === 'khentsgdz|bt-987654' && w.data.lastNotifiedChapter === '89'));
  assert.ok(writes.some((w) => w.id === 'khentsgdz|__prefs__' && w.data.sourceHealth?.comickOk === true && w.data.sourceHealth?.batoOk === true));
});

