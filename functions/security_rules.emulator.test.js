'use strict';

// Run against a demo project only:
// firebase emulators:exec --only firestore,storage --config firebase.emulators.json \
//   --project demo-everglow "node --test functions/security_rules.emulator.test.js"
// Uses native REST + emulator-only unsigned tokens: no new test dependency.
const assert = require('node:assert/strict');
const test = require('node:test');
const host = process.env.FIRESTORE_EMULATOR_HOST;
const project = process.env.GCLOUD_PROJECT || 'demo-everglow';

function token(uid, provider, username) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    sub: uid, user_id: uid, aud: project, iss: `https://securetoken.google.com/${project}`,
    iat: now, exp: now + 3600, firebase: { sign_in_provider: provider },
    ...(username ? { username } : {}),
  };
  return `${Buffer.from('{"alg":"none","typ":"JWT"}').toString('base64url')}.` +
    `${Buffer.from(JSON.stringify(payload)).toString('base64url')}.`;
}

async function request(path, bearer, method = 'GET', username) {
  return fetch(`http://${host}/v1/projects/${project}/databases/(default)/documents/${path}`, {
    method, headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
    ...(username ? { body: JSON.stringify({ fields: { username: { stringValue: username } } }) } : {}),
  });
}

test('rules prevent cinema-to-couple escalation and preserve both existing couple logins', {
  skip: !host,
}, async () => {
  assert.ok(project.startsWith('demo-'), 'never run this against a real project');
  const cinema = token('audit-cinema', 'password');
  const clair = token('audit-clair', 'custom', 'clairjassen');
  const khent = token('audit-khent', 'custom', 'khentsgdz');
  for (const [uid, bearer, username] of [
    ['audit-cinema', cinema, 'breyan'], ['audit-clair', clair, 'clairjassen'],
    ['audit-khent', khent, 'khentsgdz'],
  ]) {
    assert.equal((await request(`users/${uid}`, bearer, 'PATCH', username)).status, 200);
  }
  assert.equal((await request('notes/audit-note', 'owner', 'PATCH', 'demo')).status, 200);
  assert.equal((await request('notes/audit-note', cinema)).status, 403);
  assert.equal((await request('notes/audit-note', clair)).status, 200);
  assert.equal((await request('notes/audit-note', khent)).status, 200);
  assert.equal((await request('users/audit-cinema', cinema, 'DELETE')).status, 200);
  assert.equal((await request('users/audit-cinema', cinema, 'PATCH', 'khentsgdz')).status, 403);
  assert.equal((await request('users/audit-cinema', cinema, 'PATCH', 'clairjassen')).status, 403);
  assert.equal((await request('users/audit-cinema', cinema, 'PATCH', 'breyan')).status, 200);
  // Even a forged legacy profile seeded by Admin cannot grant couple access.
  assert.equal((await request('users/audit-cinema', 'owner', 'PATCH', 'khentsgdz')).status, 200);
  assert.equal((await request('notes/audit-note', cinema)).status, 403);
  assert.equal((await request('users/audit-clair', clair, 'DELETE')).status, 200);
  assert.equal((await request('users/audit-clair', clair, 'PATCH', 'khentsgdz')).status, 403);
  assert.equal((await request('users/audit-clair', clair, 'PATCH', 'clairjassen')).status, 200);

  const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
  assert.ok(storageHost, 'run with both firestore and storage emulators');
  async function image(path, bearer, method = 'GET') {
    const url = `http://${storageHost}/v0/b/${project}.appspot.com/o` +
      (method === 'POST' ? `?uploadType=media&name=${encodeURIComponent(path)}` :
        `/${encodeURIComponent(path)}?alt=media`);
    return fetch(url, { method,
      headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'image/png' },
      ...(method === 'POST' ? { body: Buffer.from('demo image') } : {}),
    });
  }
  for (const path of ['gallery/audit-khent/demo.png', 'milestones/legacy-demo.png']) {
    assert.equal((await image(path, 'owner', 'POST')).status, 200);
    assert.equal((await image(path, cinema)).status, 403);
    assert.equal((await image(path, clair)).status, 200);
    assert.equal((await image(path, khent)).status, 200);
  }
  assert.equal((await image('gallery/audit-cinema/demo.png', cinema, 'POST')).status, 403);
});

test('academy permits normal play but refuses poisoned joins and other-player scores', { skip: !host }, async () => {
  assert.ok(project.startsWith('demo-'), 'never run against a real project');
  const hostToken = token('academy-host', 'custom', 'khentsgdz');
  const guestToken = token('academy-guest', 'custom', 'clairjassen');
  const otherToken = token('academy-other', 'password');
  for (const [uid, bearer, username] of [
    ['academy-host', hostToken, 'khentsgdz'],
    ['academy-guest', guestToken, 'clairjassen'],
    ['academy-other', otherToken, 'breyan'],
  ]) {
    assert.equal((await request(`users/${uid}`, bearer, 'PATCH', username)).status, 200);
  }
  function encode(value) {
    if (value === null) return { nullValue: null };
    if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
    if (typeof value === 'boolean') return { booleanValue: value };
    if (typeof value === 'number') return { integerValue: String(value) };
    return { stringValue: value };
  }
  async function write(bearer, data, id = 'audit-academy') {
    return fetch(`http://${host}/v1/projects/${project}/databases/(default)/documents/active_matches/${id}`, {
      method: 'PATCH', headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: Object.fromEntries(
        Object.entries(data).map(([key, value]) => [key, encode(value)]),
      ) }),
    });
  }
  const waiting = {
    hostId: 'academy-host', hostUsername: 'khentsgdz', participantId: null,
    hostScore: 0, guestScore: 0, category: 'engineering', status: 'waiting',
    questionIds: ['q1', 'q2'], currentQuestionId: 'q1', questionIndex: 0,
    isReplenishing: false, winnerId: null,
  };
  assert.equal((await write(hostToken, waiting)).status, 200);
  const joined = { ...waiting, status: 'active', participantId: 'academy-guest',
    participantUsername: 'clairjassen' };
  assert.equal((await write(guestToken, { ...joined, hostScore: 99 })).status, 403);
  assert.equal((await write(guestToken, { ...joined, questionIds: ['poison'] })).status, 403);
  assert.equal((await write(guestToken, { ...joined, participantUsername: 'khentsgdz' })).status, 403);
  assert.equal((await write(guestToken, joined)).status, 200);
  assert.equal((await write(otherToken, { ...joined, participantId: 'academy-other' })).status, 403);
  assert.equal((await write(guestToken, { ...joined, questionIds: ['poison'] })).status, 403);
  const advanced = { ...joined, questionIndex: 1, currentQuestionId: 'q2', hostScore: 10 };
  assert.equal((await write(guestToken, advanced)).status, 403);
  assert.equal((await write(hostToken, advanced)).status, 200);
  const finished = { ...advanced, questionIndex: 2, currentQuestionId: '', guestScore: 10,
    status: 'finished', winnerId: 'draw' };
  assert.equal((await write(guestToken, finished)).status, 200);

  // The client's field patches must still work on waiting pre-refresh rows.
  const legacy = { ...waiting };
  delete legacy.questionIds;
  delete legacy.isReplenishing;
  assert.equal((await write(hostToken, legacy, 'audit-academy-legacy')).status, 200);
  const legacyJoined = { ...legacy, status: 'active', participantId: 'academy-guest',
    participantUsername: 'clairjassen' };
  assert.equal((await write(guestToken, legacyJoined, 'audit-academy-legacy')).status, 200);
  assert.equal((await write(guestToken, { ...legacyJoined, guestScore: 10,
    questionIndex: 1, currentQuestionId: '', status: 'finished', winnerId: 'clairjassen',
  }, 'audit-academy-legacy')).status, 200);

  const oldScores = { ...legacy, khentScore: 20, clairScore: 10 };
  delete oldScores.hostScore;
  delete oldScores.guestScore;
  assert.equal((await write('owner', oldScores, 'audit-academy-old-scores')).status, 200);
  const oldJoined = { ...oldScores, status: 'active', participantId: 'academy-guest',
    participantUsername: 'clairjassen' };
  assert.equal((await write(guestToken, oldJoined, 'audit-academy-old-scores')).status, 200);
  assert.equal((await write(guestToken, { ...oldJoined, hostScore: 20, guestScore: 20,
    questionIndex: 1, currentQuestionId: '', status: 'finished', winnerId: 'draw',
  }, 'audit-academy-old-scores')).status, 200);
});

test('either partner may host a fresh night, but an active room cannot be stolen', { skip: !host }, async () => {
  assert.ok(project.startsWith('demo-'));
  const khent = token('party-khent', 'custom', 'khentsgdz');
  const clair = token('party-clair', 'custom', 'clairjassen');
  await request('users/party-khent', khent, 'PATCH', 'khentsgdz');
  await request('users/party-clair', clair, 'PATCH', 'clairjassen');
  function encode(value) {
    if (value instanceof Date) return { timestampValue: value.toISOString() };
    if (typeof value === 'boolean') return { booleanValue: value };
    if (typeof value === 'number') return { integerValue: String(value) };
    return { stringValue: value };
  }
  async function write(bearer, data) {
    return fetch(`http://${host}/v1/projects/${project}/databases/(default)/documents/watch_party_rooms/audit-party`, {
      method: 'PATCH', headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: Object.fromEntries(
        Object.entries(data).map(([key, value]) => [key, encode(value)]),
      ) }),
    });
  }
  const room = { hostUid: 'party-khent', partnerUid: 'party-clair', hostName: 'Khent', partnerName: 'Clair',
    mediaType: 'movie', state: 'playing', currentTime: 100, active: true,
    updatedAt: new Date(), updatedBy: 'party-khent', streamUrl: 'https://demo.test/old.m3u8' };
  assert.equal((await write(khent, room)).status, 200);
  const nextNight = { ...room, hostUid: 'party-clair', partnerUid: 'party-khent',
    hostName: 'Clair', partnerName: 'Khent', state: 'paused', updatedBy: 'party-clair', currentTime: 0 };
  delete nextNight.streamUrl;
  assert.equal((await write(clair, nextNight)).status, 403);
  assert.equal((await write(khent, { ...room, active: false })).status, 200);
  assert.equal((await write(clair, nextNight)).status, 200);
  const response = await request('watch_party_rooms/audit-party', khent);
  assert.equal((await response.json()).fields.streamUrl, undefined);
  assert.equal((await write(khent, room)).status, 403);
  assert.equal((await write(clair, { ...nextNight,
    updatedAt: new Date(Date.now() - 16 * 60000),
  })).status, 200);
  assert.equal((await write(khent, { ...room, state: 'paused', currentTime: 0 })).status, 200);
});

test('table tennis permits one guest claim and play without a category field', { skip: !host }, async () => {
  assert.ok(project.startsWith('demo-'));
  const players = ['tt-host', 'tt-guest', 'tt-other'];
  const tokens = players.map((uid) => token(uid, 'password'));
  for (let i = 0; i < players.length; i++) {
    assert.equal((await request(`users/${players[i]}`, tokens[i], 'PATCH', 'breyan')).status, 200);
  }
  const room = { hostUid: 'tt-host', guestUid: null, status: 'waiting', lastTick: 0 };
  const encode = (value) => value === null ? { nullValue: null } :
    typeof value === 'number' ? { integerValue: String(value) } : { stringValue: value };
  async function write(bearer, data) {
    return fetch(`http://${host}/v1/projects/${project}/databases/(default)/documents/tt_rooms/audit-room`, {
      method: 'PATCH', headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: Object.fromEntries(
        Object.entries(data).map(([key, value]) => [key, encode(value)]),
      ) }),
    });
  }
  assert.equal((await write(tokens[0], room)).status, 200);
  const joined = { ...room, guestUid: 'tt-guest', status: 'playing', lastTick: 1 };
  assert.equal((await write(tokens[1], { ...joined, hostScore: 99 })).status, 403);
  assert.equal((await write(tokens[1], joined)).status, 200);
  assert.equal((await write(tokens[2], { ...joined, guestUid: 'tt-other' })).status, 403);
  const playing = { ...joined, lastTick: 2, hostScore: 1 };
  assert.equal((await write(tokens[0], playing)).status, 200);
  assert.equal((await write(tokens[1], { ...playing, guestPaddleY: 1 })).status, 200);
  assert.equal((await write(tokens[2], { ...playing, hostScore: 100 })).status, 403);
  assert.equal((await request('tt_rooms/audit-room', tokens[0], 'DELETE')).status, 200);
});
