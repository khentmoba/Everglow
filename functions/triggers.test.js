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
    return { get: async () => ({ exists: true, data: () => ({ token: 'demo-token' }) }) };
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
