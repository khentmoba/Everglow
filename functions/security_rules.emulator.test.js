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
