'use strict';

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

/** Extract a brace-balanced `match ... { ... }` block so regexes never bleed across collections. */
function blockFor(src, matchPrefix) {
  const start = src.indexOf(matchPrefix);
  assert.ok(start !== -1, `missing block for ${matchPrefix}`);
  const open = src.indexOf(' {', start + matchPrefix.length);
  assert.ok(open !== -1, `missing opening brace for ${matchPrefix}`);
  let depth = 0;
  for (let i = open + 1; i < src.length; i++) {
    if (src[i] === '{') depth++;
    else if (src[i] === '}') {
      depth--;
      if (depth === 0) return src.slice(start, i + 1);
    }
  }
  assert.fail(`unclosed block for ${matchPrefix}`);
}

test('Motchi action reservations cannot be forged or read by clients', () => {
  assert.match(rules, /match \/motchi_actions\/\{docId\} \{ allow read, write: if false; \}/);
});

test('Motchi receipts expire without a cleanup query and do not index result bodies', () => {
  const indexes = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'firestore.indexes.json'), 'utf8'));
  const overrides = indexes.fieldOverrides.filter((o) => o.collectionGroup === 'motchi_actions');
  assert.equal(overrides.find((o) => o.fieldPath === 'expiresAt').ttl, true);
  assert.deepEqual(overrides.find((o) => o.fieldPath === 'expiresAt').indexes, []);
  assert.deepEqual(overrides.find((o) => o.fieldPath === 'result').indexes, []);
});

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
  const blk = blockFor(rules, 'match /academy_questions/{docId}');
  assert.ok(!/allow read,\s*write/.test(blk));
  assert.match(blk, /allow delete: if false/);
});

test('active_matches: join, question refresh, and scoring writes are field-scoped', () => {
  const matchRules = blockFor(rules, 'match /active_matches/{docId}');
  assert.match(matchRules, /request\.resource\.data\.hostId == request\.auth\.uid/);
  assert.match(matchRules, /request\.resource\.data\.participantId == null/);
  assert.match(matchRules, /resource\.data\.participantId == null/);
  assert.match(matchRules, /request\.resource\.data\.participantUsername == username\(\)/);
  assert.match(matchRules, /hasOnly\(\['status',\s*'participantId',\s*'participantUsername'\]\)/);
  assert.match(matchRules, /questionIds\.size\(\) <= 10/);
  assert.match(matchRules, /hasOnly\(\['questionIds',\s*'currentQuestionId',\s*'questionIndex'\]\)/);
  assert.match(matchRules, /hasOnly\(\['hostScore',\s*'guestScore',\s*'questionIndex',\s*'currentQuestionId',\s*'status',\s*'winnerId'\]\)/);
  assert.match(matchRules, /isMatchScoreUpdate\(\)/);
  assert.match(rules, /data\.get\('hostScore', resource\.data\.get\('khentScore', 0\)\)/);
  assert.match(rules, /data\.get\('guestScore', resource\.data\.get\('clairScore', 0\)\)/);
  assert.match(matchRules, /request\.resource\.data\.status == 'finished' && isMatchWinner\(\)/);
  assert.match(matchRules, /request\.auth\.uid == resource\.data\.hostId/);
  assert.match(matchRules, /request\.auth\.uid == resource\.data\.participantId/);
});

test('push tokens are private per-device registrations for the signed-in couple identity', () => {
  const blk = blockFor(rules, 'match /fcm_tokens/{docId}');
  assert.match(blk, /allow read, write: if false;/);
  const devicesBlk = blockFor(blk, 'match /devices/{deviceId}');
  assert.match(devicesBlk, /allow read: if false;/);
  assert.match(devicesBlk, /allow create, update: if isCouple\(\) && docId == username\(\)/);
  assert.match(devicesBlk, /request\.resource\.data\.uid == request\.auth\.uid/);
});

test('presence writes are owner-scoped', () => {
  assert.match(blockFor(rules, 'match /presence/{docId}'), /docId == request\.auth\.uid/);
  assert.match(blockFor(rules, 'match /presence_sessions/{docId}'), /resource\.data\.uid == request\.auth\.uid/);
});

test('sanctuary/starlight updates keep type + allow-list', () => {
  assert.match(
    blockFor(rules, 'match /sanctuary_messages/{messageId}'),
    /affectedKeys\(\)\.hasOnly\(\['text', 'updatedAt', 'editedAt', 'edited'\]\)/,
  );
  assert.match(
    blockFor(rules, 'match /starlight_jar/{docId}'),
    /affectedKeys\(\)\.hasOnly\(\['content', 'updatedAt', 'opened', 'openedAt'\]\)/,
  );
});

test('watch_list cinema updates cannot reassign ownership', () => {
  assert.match(
    blockFor(rules, 'match /watch_list/{docId}'),
    /request\.resource\.data\.userName == resource\.data\.userName/,
  );
});

test('tt_rooms updates restrict the match status', () => {
  assert.match(
    blockFor(rules, 'match /tt_rooms/{roomId}'),
    /request\.resource\.data\.status in \['waiting', 'playing', 'finished'\]/,
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
  const blk = blockFor(rules, 'match /users/{userId}/garden_stats/{docId}');
  assert.match(blk, /allow read: if isCouple\(\);/);
  assert.match(blk, /allow write: if isCouple\(\) && ownerOf\(userId\);/);
});

test('storage gallery/memories/milestones allow couple reads', () => {
  for (const prefix of ['gallery', 'memories', 'milestones']) {
    assert.match(
      blockFor(storage, `match /${prefix}/{userId}`),
      /allow read: if isCoupleUser\(\);/,
      `${prefix} must allow couple reads`,
    );
  }
  assert.doesNotMatch(storage, /match \/vault\//);
});

test('subscriptions is couple-only', () => {
  const blk = blockFor(rules, 'match /subscriptions/{docId}');
  assert.match(blk, /allow read: if isCouple\(\);/);
  assert.match(blk, /allow delete: if isCouple\(\);/);
});

test('motchi_games is couple-only', () => {
  const blk = blockFor(rules, 'match /motchi_games/{docId}');
  assert.match(blk, /allow read: if isCouple\(\);/);
  assert.match(blk, /allow delete: if isCouple\(\);/);
});

test('motchi_sessions is couple read-only, client write denied', () => {
  const blk = blockFor(rules, 'match /motchi_sessions/{docId}');
  assert.match(blk, /allow read: if isCouple\(\);/);
  assert.match(blk, /allow write: if false;/);
});

test('personal book and manga library collections are owner-scoped for cinema profiles', () => {
  for (const name of ['read_list', 'book_favorites', 'book_download_history']) {
    assert.match(
      blockFor(rules, `match /${name}/{docId}`),
      /allow read: if isCouple\(\) \|\|[\s\S]*?isCinemaProfile\(\) && resource\.data\.userName == username\(\)/,
      `${name} must scope cinema profile reads to own userName`,
    );
  }
  for (const [name, sep] of [['reader_state', '__'], ['katana_bookmarks', '\\\\|']]) {
    assert.match(
      blockFor(rules, `match /${name}/{docId}`),
      new RegExp(
        `allow list: if isCouple\\(\\) \\|\\|[\\s\\S]*?isCinemaProfile\\(\\) && resource\\.data\\.userName == username\\(\\)[\\s\\S]*?allow create: if \\(isCouple\\(\\) \\|\\|[\\s\\S]*?isCinemaProfile\\(\\) && docId\\.matches\\('\\^' \\+ username\\(\\) \\+ '${sep}\\.\\*'\\) &&[\\s\\S]*?request\\.resource\\.data\\.userName == username\\(\\)\\)`,
      ),
      `${name} must scope cinema profile lists and creates to own docId prefix and userName`,
    );
  }
  assert.match(
    blockFor(rules, 'match /our_books/{docId}'),
    /allow read: if isCouple\(\);/,
    'our_books must remain couple-only',
  );
});

test('member_accounts and community_watch_room_secrets are server-only, global_chat_messages and community_watch_rooms are protected', () => {
  assert.match(blockFor(rules, 'match /member_accounts/{accountId}'), /allow read, write: if false;/);
  assert.match(blockFor(rules, 'match /community_watch_room_secrets/{roomId}'), /allow read, write: if false;/);
  const globalChat = blockFor(rules, 'match /global_chat_messages/{messageId}');
  assert.match(globalChat, /allow read: if isAppUser\(\);/);
  assert.match(globalChat, /request\.resource\.data\.senderUid == request\.auth\.uid/);
  assert.match(globalChat, /request\.resource\.data\.senderName == username\(\)/);

  const watchRooms = blockFor(rules, 'match /community_watch_rooms/{roomId}');
  assert.match(watchRooms, /allow read: if isAppUser\(\);/);
  assert.match(watchRooms, /allow create: if false;/);
  assert.match(watchRooms, /isValidCommunityRoomShape\(request\.resource\.data\)/);
  assert.match(blockFor(watchRooms, 'match /members/{memberUid}'), /allow write: if false;/);
  assert.match(blockFor(watchRooms, 'match /messages/{messageId}'), /canAccessCommunityRoomById\(roomId\)/);
  assert.match(rules, /data\.serverHost == 'everglow'/);
});
