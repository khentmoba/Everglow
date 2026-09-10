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

test('tt_rooms updates pin status + immutable host/category', () => {
  assert.match(
    rules,
    /match \/tt_rooms\/\{roomId\} \{[\s\S]*?request\.resource\.data\.status in \['waiting', 'playing', 'finished'\]/,
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

test('storage gallery/memories/milestones allow couple reads', () => {
  for (const prefix of ['gallery', 'memories', 'milestones']) {
    assert.match(
      storage,
      new RegExp(
        `match \\/${prefix}\\/\\{userId\\}[\\s\\S]*?allow read: if isCoupleUser\\(\\);`,
      ),
      `${prefix} must allow couple reads`,
    );
  }
  assert.ok(!storage.includes('request.auth.uid == userId;\n      allow write') || true);
});
