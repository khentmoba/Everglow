'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { normalizePasscode, isValidPasscodeFormat, trustedProfileUsername } = require('./auth_core');

test('a client profile cannot impersonate the couple; signed identity wins', () => {
  const cinema = { uid: 'demo-cinema', firebase: { sign_in_provider: 'password' } };
  assert.equal(trustedProfileUsername(cinema, 'khentsgdz'), null);
  assert.equal(trustedProfileUsername(cinema, 'clairjassen'), null);
  assert.equal(trustedProfileUsername(cinema, 'breyan'), 'breyan');
  assert.equal(trustedProfileUsername({ ...cinema, username: 'clairjassen' }, 'clairjassen'), null);
  const couple = { uid: 'demo-couple', username: 'clairjassen', firebase: { sign_in_provider: 'custom' } };
  assert.equal(trustedProfileUsername(couple, 'khentsgdz'), 'clairjassen');
  assert.equal(trustedProfileUsername({ ...couple, firebase: { sign_in_provider: 'anonymous' } }), null);
});

test('web build inputs and client config cannot ship couple codes', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const root = path.join(__dirname, '..');
  const config = fs.readFileSync(path.join(root, 'lib/core/config/env_config.dart'), 'utf8');
  assert.ok(!/CLAIR_PASSCODE|KHENT_PASSCODE/.test(config));
  for (const workflow of ['deploy.yml', 'preview.yml']) {
    const source = fs.readFileSync(path.join(root, '.github/workflows', workflow), 'utf8');
    const build = source.split('- name: Build web')[1].split('\n      - name:')[0];
    assert.ok(!/CLAIR_PASSCODE|KHENT_PASSCODE/.test(build));
  }
});

test('normalizePasscode trims string input safely', () => {
  assert.equal(normalizePasscode(' 0938 '), '0938');
  assert.equal(normalizePasscode(null), '');
});

test('passcode format accepts exactly four digits', () => {
  assert.equal(isValidPasscodeFormat('0938'), true);
  assert.equal(isValidPasscodeFormat(' 0938 '), true);
  assert.equal(isValidPasscodeFormat('09381'), false);
  assert.equal(isValidPasscodeFormat('093a'), false);
  assert.equal(isValidPasscodeFormat('\\d123'), false);
});
