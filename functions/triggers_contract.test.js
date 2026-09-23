'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const source = fs.readFileSync(path.join(__dirname, 'triggers.js'), 'utf8');

test('FCM triggers use the app collections and payload types', () => {
  for (const contract of [
    "document('starlight_jar/{noteId}')",
    "type: 'starlight_drop'",
    "document('watch_list/{itemId}')",
    "type: 'watchlist_update'",
    "type: 'mood_update'",
    "type: 'gallery_photo'",
    "document('watch_party_rooms/{roomId}')",
    "type: 'watch_party_invite'",
  ]) {
    assert.ok(source.includes(contract), `missing FCM contract: ${contract}`);
  }
});

test('FCM delivery queries every device token for a username', () => {
  assert.match(source, /collection\('fcm_tokens'\)[\s\S]*?where\('username', '==', username\)/);
  assert.ok(!source.includes(".doc(uid).get()"));
});
