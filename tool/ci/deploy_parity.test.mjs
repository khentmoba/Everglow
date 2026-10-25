import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {selectChecks} from './changes.mjs';

const read = path => readFileSync(new URL('../../' + path, import.meta.url), 'utf8');

for (const paths of [[], ['README.md'], ['lib/features/anime/player.dart'], ['functions/index.js'], ['firestore.rules']]) {
  test(`deployment prerequisites cannot be skipped for ${JSON.stringify(paths)}`, () => {
    const checks = selectChecks(paths);
    for (const key of ['app', 'web', 'backend', 'audit']) assert.equal(checks[key], true, key);
  });
}

test('PR and deployment use the same backend verification and locked install', () => {
  for (const workflow of ['quality', 'deploy']) {
    const source = read(`.github/workflows/${workflow}.yml`);
    assert.match(source, /working-directory: functions\r?\n\s+run: npm ci/);
    assert.match(source, /run: npm run verify/);
    assert.doesNotMatch(source, /run: npm install\s*$/m);
  }
  const {scripts} = JSON.parse(read('functions/package.json'));
  for (const command of ['npm run lint -- --max-warnings=25', 'npm test', 'node --check index.js', 'node eval_gate.js', 'npm audit --omit=dev --audit-level=moderate']) {
    assert.ok(scripts.verify.split(' && ').includes(command), command);
  }
});
