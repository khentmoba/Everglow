'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const { getAdmin } = require('./common.js');
const triggers = require('./triggers.js');

test('partner triggers use app collection paths, authors, and navigation types', async (t) => {
  const previousProject = process.env.GCLOUD_PROJECT;
  process.env.GCLOUD_PROJECT = 'demo-everglow';
  t.after(() => {
    if (previousProject === undefined) delete process.env.GCLOUD_PROJECT;
    else process.env.GCLOUD_PROJECT = previousProject;
  });
  const sent = [];
  const recipients = [];
  const admin = getAdmin();
  t.mock.method(admin, 'firestore', () => ({ collection: () => ({ doc: (name) => {
    recipients.push(name);
    return { collection: () => ({ get: async () => ({ docs: [
      { data: () => ({ token: 'demo-token' }), ref: { delete: async () => {} } },
    ] }) }) };
  } }) }));
  t.mock.method(admin, 'messaging', () => ({ send: async (message) => sent.push(message) }));
  const cases = [
    ['onNewMood', 'moods/{moodId}', { username: 'khentsgdz', moodEmoji: 'happy' }, 'mood_update'],
    ['onNewStarDrop', 'starlight_jar/{noteId}', { author: 'khentsgdz', content: 'Demo gratitude' }, 'starlight_drop'],
    ['onNewWatchlistItem', 'watch_list/{itemId}', { userName: 'khentsgdz', title: 'Demo movie' }, 'watchlist_update'],
    ['onNewGalleryPhoto', 'gallery/{photoId}', { uploadedBy: 'khentsgdz', caption: 'Demo photo' }, 'gallery_photo'],
    ['onWatchPartyInvite', 'watch_party_invites/{inviteId}', { to: 'clairjassen' }, 'watch_party_invite'],
  ];
  for (const [name, path, data, type] of cases) {
    assert.ok(triggers[name].__trigger.eventTrigger.resource.endsWith(path));
    await triggers[name].run({ data: () => data });
    assert.equal(recipients.at(-1), 'clairjassen');
    assert.equal(sent.at(-1).data.type, type);
  }
  const before = sent.length;
  await triggers.onNewWatchlistItem.run({ data: () => ({ userName: 'breyan', title: 'Guest movie' }) });
  assert.equal(sent.length, before, 'cinema guests must not notify the couple');
});

test('new Motchi device gets default scheduled pushes without a preferences parent', async (t) => {
  t.mock.timers.enable({ apis: ['Date'], now: Date.parse('2026-10-11T04:00:00Z') });
  const previousProject = process.env.GCLOUD_PROJECT;
  process.env.GCLOUD_PROJECT = 'demo-everglow';
  t.after(() => {
    if (previousProject === undefined) delete process.env.GCLOUD_PROJECT;
    else process.env.GCLOUD_PROJECT = previousProject;
  });
  let parent;
  const sent = [];
  const admin = getAdmin();
  t.mock.method(admin, 'firestore', () => ({
    collection: () => ({ doc: () => ({
      collection: () => ({ get: async () => ({ docs: [
        { data: () => ({ token: 'new-device-token' }), ref: { delete: async () => {} } },
      ] }) }),
    }) }),
    runTransaction: async (work) => work({
      get: async () => ({ exists: false }),
      set: (_ref, value) => { parent = value; },
    }),
  }));
  t.mock.method(admin, 'messaging', () => ({ send: async (message) => sent.push(message) }));

  await triggers.sendFCMToUser('clairjassen', {
    title: 'Demo digest', body: 'Demo only', motchi: true,
    data: { type: 'daily_digest' },
  });

  assert.equal(sent.length, 1);
  assert.equal(sent[0].token, 'new-device-token');
  assert.ok(parent.motchi.lastDigests.daily_digest);
});

test('push goes to every registered device, ignores legacy tokens, and removes dead registrations', async (t) => {
  const previousProject = process.env.GCLOUD_PROJECT;
  process.env.GCLOUD_PROJECT = 'demo-everglow';
  t.after(() => {
    if (previousProject === undefined) delete process.env.GCLOUD_PROJECT;
    else process.env.GCLOUD_PROJECT = previousProject;
  });
  const sent = [];
  const deleted = [];
  let legacyReads = 0;
  const devices = ['phone-token', 'tablet-token', 'dead-token'].map((token) => ({
    data: () => ({ token }),
    ref: { delete: async () => deleted.push(token) },
  }));
  const admin = getAdmin();
  t.mock.method(admin, 'firestore', () => ({ collection: () => ({ doc: () => ({
    get: async () => {
      legacyReads++;
      return { exists: true, data: () => ({ token: 'stale-legacy-token' }) };
    },
    collection: () => ({ get: async () => ({ docs: devices }) }),
  }) }) }));
  t.mock.method(admin, 'messaging', () => ({ send: async ({ token }) => {
    sent.push(token);
    if (token === 'dead-token') {
      throw Object.assign(new Error('not registered'), {
        code: 'messaging/registration-token-not-registered',
      });
    }
  } }));

  await triggers.sendFCMToUser('clairjassen', {
    title: 'Private demo', body: 'Demo only', data: { type: 'chat_message' },
  });

  assert.deepEqual(sent.sort(), ['dead-token', 'phone-token', 'tablet-token']);
  assert.deepEqual(deleted, ['dead-token']);
  assert.equal(legacyReads, 0, 'a stale top-level token is never delivered');
});
