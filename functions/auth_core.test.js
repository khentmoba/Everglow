'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { normalizePasscode, isValidPasscodeFormat, trustedProfileUsername } = require('./auth_core');

test('only server-signed app profiles are trusted', () => {
  for (const username of ['khentsgdz', 'clairjassen', 'breyan', 'octagram']) {
    const signed = { uid: 'demo', username, firebase: { sign_in_provider: 'custom' } };
    assert.equal(trustedProfileUsername(signed), username);
    for (const provider of ['password', 'anonymous', 'google.com']) {
      assert.equal(trustedProfileUsername({ ...signed, firebase: { sign_in_provider: provider } }), null);
    }
  }
  assert.equal(trustedProfileUsername({ uid: 'demo', username: 'stranger',
    firebase: { sign_in_provider: 'custom' } }), null);
  assert.equal(trustedProfileUsername(null), null);
});

test('web build inputs and client config cannot ship any login credentials', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const root = path.join(__dirname, '..');
  const forbidden = /(?:CLAIR|KHENT|BREYAN|OCTAGRAM)_(?:PASSCODE|PASSWORD|EMAIL)/;
  const config = fs.readFileSync(path.join(root, 'lib/core/config/env_config.dart'), 'utf8');
  assert.ok(!forbidden.test(config));
  for (const workflow of ['deploy.yml', 'quality.yml']) {
    const source = fs.readFileSync(path.join(root, '.github/workflows', workflow), 'utf8');
    const build = source.split('- name: Build web')[1].split('\n      - name:')[0];
    assert.ok(!forbidden.test(build), workflow);
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
