'use strict';

// Static guardrails for firestore.rules / storage.rules.
//
// The Firestore emulator needs Java, which isn't available in this
// environment, so these tests parse the rule sources instead of running
// them: they assert the security invariants this audit introduced
// (validators in helper scope, least-privilege academy writes, presence
// ownership, update allow-lists, secure-default deny, couple Storage
// reads). If the rules regress, these fail fast in CI without an
// emulator.

const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const rules = fs.readFileSync(
  path.join(__dirname, '..', 'firestore.rules'),
  'utf8',
);
const storage = fs.readFileSync(
  path.join(__dirname, '..', 'storage.rules'),
  'utf8',
);

test('shape validators live inside the match helpers scope', () => {
  for (const name of [
    'isValidRoomShape',
    'isValidVoiceRoomShape',
    'isValidAcademyQuestionShape',
    'isValidMatchShape',
  ]) {
    assert.match(rules, new RegExp(`function ${name}\\(data\\)`));
  }
  const serviceOpen = rules.indexOf('service cloud.firestore');
  const firstValidator = rules.indexOf('function isValidRoomShape');
  const serviceClose = rules.lastIndexOf('}');
  assert.ok(
    firstValidator > serviceOpen && firstValidator < serviceClose,
    'validators must be inside the service block',
  );
  assert.ok(
    !rules.includes('// ---------- Shape validators ----------\n\nfunction'),
    'no top-level (outside service) validator functions',
  );
});

test('academy_questions: no open write, delete denied', () => {
  assert.ok(!rules.includes('academy_questions/{docId} {\n      allow read, write'));
  assert.match(rules, /match \/academy_questions\/\{docId\} \{[\s\S]*?allow delete: if false/);
});

test('active_matches: host-owned create/delete, participant update', () => {
  assert.match(
    rules,
    /match \/active_matches\/\{docId\} \{[\s\S]*?request\.resource\.data\.hostId == request\.auth\.uid/,
  );
  assert.match(
    rules,
    /match \/active_matches\/\{docId\} \{[\s\S]*?resource\.data\.participantId/,
  );
});

test('presence writes are owner-scoped', () => {
  assert.match(
    rules,
    /match \/presence\/\{docId\} \{[^}]*docId == request\.auth\.uid/,
  );
  assert.match(
    rules,
    /match \/presence_sessions\/\{docId\} \{[^}]*resource\.data\.uid == request\.auth\.uid/,
  );
});

test('sanctuary/starlight updates keep type + allow-list', () => {
  assert.match(
    rules,
    /match \/sanctuary_messages\/\{messageId\} \{[\s\S]*?affectedKeys\(\)\.hasOnly\(\['text', 'updatedAt', 'editedAt', 'edited'\]\)/,
  );
  assert.match(
    rules,
    /match \/starlight_jar\/\{docId\} \{[\s\S]*?affectedKeys\(\)\.hasOnly\(\['content', 'updatedAt', 'opened', 'openedAt'\]\)/,
  );
});

test('watch_list cinema updates cannot reassign ownership', () => {
  assert.match(
    rules,
    /match \/watch_list\/\{docId\} \{[\s\S]*?request\.resource\.data\.userName == resource\.data\.userName/,
  );
});

test('tt_rooms updates allow a new guest claim and host-only rematch reset', () => {
  const block = rules.match(/match \/tt_rooms\/\{roomId\} \{([\s\S]*?)\n {4}\}/)?.[1] || '';
  assert.match(block, /resource\.data\.guestUid == null/);
  assert.match(block, /request\.resource\.data\.guestUid == request\.auth\.uid/);
  assert.match(block, /request\.auth\.uid == resource\.data\.hostUid/);
  assert.match(block, /request\.resource\.data\.hostUid == resource\.data\.hostUid/);
});

test('identity roles come from custom claims and user profiles are server-owned', () => {
  assert.match(rules, /request\.auth\.token\.role == 'couple'/);
  assert.match(rules, /request\.auth\.token\.role == 'cinema'/);
  const users = rules.match(/match \/users\/\{userId\} \{([\s\S]*?)\n {4}\}/)?.[1] || '';
  assert.match(users, /allow read: if isRegistered\(\);/);
  assert.match(users, /allow write: if false;/);
});

test('canvas eraser deletes are owner-scoped in rules', () => {
  assert.match(
    rules,
    /match \/canvas_strokes\/\{docId\} \{[\s\S]*?allow delete: if isCouple\(\) && resource\.data\.userId == request\.auth\.uid;/,
  );
});

test('secure-default deny-all is present', () => {
  assert.match(
    rules,
    /match \/\{document=\*\*\} \{ allow read, write: if false; \}/,
  );
  assert.match(
    storage,
    /match \/\{allPaths=\*\*\} \{\s*allow read, write: if false;/,
  );
});

test('garden_stats allows couple reads and owner-scoped writes', () => {
  assert.match(
    rules,
    /match \/users\/\{userId\}\/garden_stats\/\{docId\} \{[\s\S]*?allow read: if isCouple\(\);[\s\S]*?allow write: if isCouple\(\) && ownerOf\(userId\);/,
  );
});

test('storage gallery/memories/milestones use signed couple claims', () => {
  assert.match(storage, /request\.auth\.token\.role == 'couple'/);
  for (const prefix of ['gallery', 'memories', 'milestones']) {
    assert.match(
      storage,
      new RegExp(
        `match \\/${prefix}\\/\\{userId\\}[\\s\\S]*?allow read: if isCoupleUser\\(\\);`,
      ),
      `${prefix} must allow couple reads`,
    );
  }
});

test('motchi_games is couple-only', () => {
  assert.match(
    rules,
    /match \/motchi_games\/\{docId\} \{[\s\S]*?allow read: if isCouple\(\);[\s\S]*?allow delete: if isCouple\(\);/,
  );
});

test('motchi_sessions is couple read-only, client write denied', () => {
  assert.match(
    rules,
    /match \/motchi_sessions\/\{docId\} \{[\s\S]*?allow read: if isCouple\(\);[\s\S]*?allow write: if false;/,
  );
});

test('book library collections are couple-only', () => {
  for (const name of ['book_favorites', 'book_download_history']) {
    assert.match(
      rules,
      new RegExp(
        `match \\/${name}\\/\\{docId\\} \\{[\\s\\S]*?allow read: if isCouple\\(\\);`,
      ),
      `${name} must be couple-only`,
    );
  }
});
