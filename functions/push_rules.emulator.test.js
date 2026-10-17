'use strict';

// Emulator-only push registration coverage. Run with the other rule tests:
// firebase emulators:exec --only firestore --config firebase.emulators.json \
//   --project demo-everglow "node --test functions/*.emulator.test.js"
const assert = require('node:assert/strict');
const test = require('node:test');
const host = process.env.FIRESTORE_EMULATOR_HOST;
const project = process.env.GCLOUD_PROJECT || 'demo-everglow';
const documents = `http://${host}/v1/projects/${project}/databases/(default)/documents`;

function token(uid, provider, username) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    sub: uid,
    user_id: uid,
    aud: project,
    iss: `https://securetoken.google.com/${project}`,
    iat: now,
    exp: now + 3600,
    firebase: { sign_in_provider: provider },
    ...(username ? { username } : {}),
  };
  return `${Buffer.from('{"alg":"none","typ":"JWT"}').toString('base64url')}.` +
    `${Buffer.from(JSON.stringify(payload)).toString('base64url')}.`;
}

function fields(values) {
  return Object.fromEntries(Object.entries(values).map(([key, value]) => [key, {
    stringValue: value,
  }]));
}

async function request(path, bearer, method = 'GET', values) {
  return fetch(`${documents}/${path}`, {
    method,
    headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
    ...(values ? { body: JSON.stringify({ fields: fields(values) }) } : {}),
  });
}

async function writeDevice(username, uid, bearer, deviceId) {
  return fetch(`${documents}:commit`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ writes: [{
      update: {
        name: `projects/${project}/databases/(default)/documents/fcm_tokens/${username}/devices/${deviceId}`,
        fields: fields({ token: 'demo-fcm-token', uid, platform: 'test' }),
      },
      updateMask: { fieldPaths: ['token', 'uid', 'platform'] },
      updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
    }] }),
  });
}

test('FCM registrations are private and scoped to the verified couple profile', {
  skip: !host,
}, async () => {
  assert.ok(project.startsWith('demo-'), 'never run this against a real project');
  const clairUid = 'push-rules-clair';
  const khentUid = 'push-rules-khent';
  const cinemaUid = 'push-rules-cinema';
  const clair = token(clairUid, 'custom', 'clairjassen');
  const khent = token(khentUid, 'custom', 'khentsgdz');
  const cinema = token(cinemaUid, 'password');

  for (const [uid, username] of [
    [clairUid, 'clairjassen'],
    [khentUid, 'khentsgdz'],
    [cinemaUid, 'breyan'],
  ]) {
    assert.equal((await request(`users/${uid}`, 'owner', 'PATCH', { username })).status, 200);
  }

  // The parent may not exist: each installation can create only its own child.
  assert.equal((await writeDevice('clairjassen', clairUid, clair, 'phone')).status, 200);
  assert.equal((await writeDevice('clairjassen', khentUid, clair, 'wrong-uid')).status, 403);
  assert.equal((await request(
    'fcm_tokens/clairjassen/devices/phone', clair,
  )).status, 403, 'device token documents are not readable by clients');
  assert.equal((await writeDevice('khentsgdz', clairUid, clair, 'foreign')).status, 403);
  assert.equal((await writeDevice('clairjassen', cinemaUid, cinema, 'cinema')).status, 403);

  // Historical single-token docs are server-only, so they cannot be revived
  // by an old client after logout. Motchi fields remain server-managed there.
  assert.equal((await request('fcm_tokens/clairjassen', 'owner', 'PATCH', {
    token: 'legacy-token', motchi: 'legacy-preferences',
  })).status, 200);
  assert.equal((await request('fcm_tokens/clairjassen', clair)).status, 403);
  assert.equal((await request('fcm_tokens/clairjassen', clair, 'PATCH', {
    token: 'stale-after-logout',
  })).status, 403);

  assert.equal((await request(
    'fcm_tokens/clairjassen/devices/phone', clair, 'DELETE',
  )).status, 200, 'logout may remove its own token registration');
  assert.equal((await request(
    'fcm_tokens/clairjassen/devices/phone', khent, 'DELETE',
  )).status, 403, 'partner cannot remove another profile registration');
});
