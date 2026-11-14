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

// The Worker is live code for Cinema and Anime. A merge must be the only way
// it ships, tested first and played on the edge after (#592, #594, #595).
test('a merge to main deploys the streaming Worker, tested before and smoked after', () => {
  const source = read('.github/workflows/deploy_worker.yml');
  assert.match(source, /push:\s*\n\s+branches: \[main\]/);
  assert.match(source, /- 'cloudflare\/\*\*'/);
  assert.match(source, /- 'functions\/hls_player\.js'/);
  assert.match(source, /cancel-in-progress: false/);
  const order = ['run: npm ci', 'run: npm test', '--save "$RUNNER_TEMP/smoke-before.json"', 'npx wrangler deploy',
    '--compare "$RUNNER_TEMP/smoke-before.json"'].map(step => {
    const at = source.indexOf(step);
    assert.ok(at >= 0, `deploy_worker.yml must run ${step}`);
    return at;
  });
  assert.deepEqual(order, [...order].sort((a, b) => a - b), 'test, baseline smoke, deploy, then compare');
  const {scripts} = JSON.parse(read('cloudflare/package.json'));
  assert.match(scripts.test, /src\/\*\.test\.js/);
  assert.match(read('.github/workflows/quality.yml'), /node --test "cloudflare\/src\/\*\.test\.js"/);
});

test('a PR body edit re-runs only the contract, never the full Quality suite', () => {
  const quality = read('.github/workflows/quality.yml');
  const types = quality.match(/types: \[([^\]]*)\]/)[1];
  assert.doesNotMatch(types, /edited|ready_for_review|converted_to_draft/);
  assert.doesNotMatch(quality, /pr_contract\.mjs/);
  const contract = read('.github/workflows/pr_contract.yml');
  assert.match(contract.match(/types: \[([^\]]*)\]/)[1], /edited/);
  assert.match(contract, /run: node tool\/ci\/pr_contract\.mjs/);
});
