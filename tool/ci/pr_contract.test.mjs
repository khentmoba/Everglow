import test from 'node:test';
import assert from 'node:assert/strict';
import {checkPrContract} from './pr_contract.mjs';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';

test('CLI fetches an event base missing from a shallow checkout', t => {
  const root = mkdtempSync(join(tmpdir(), 'eg-pr-contract-'));
  t.after(() => rmSync(root, {recursive:true, force:true}));
  const origin = join(root, 'origin');
  const checkout = join(root, 'checkout');
  const git = (args, cwd = origin) => execFileSync('git', args, {cwd, encoding:'utf8', stdio:['ignore','pipe','pipe']}).trim();
  execFileSync('git', ['init', origin], {stdio:'pipe'});
  const commit = value => {
    writeFileSync(join(origin, 'file.txt'), value);
    git(['add', '.']);
    git(['-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-m', value]);
    return git(['rev-parse', 'HEAD']);
  };
  const base = commit('old event base');
  commit('new base');
  commit('merge checkout');
  git(['clone', '--depth=2', pathToFileURL(origin).href, checkout], root);
  assert.notEqual(spawnSync('git', ['cat-file', '-e', base], {cwd:checkout}).status, 0);
  const eventPath = join(root, 'event.json');
  writeFileSync(eventPath, JSON.stringify({pull_request:{draft:true, base:{sha:base}}}));
  const result = spawnSync(process.execPath, [fileURLToPath(new URL('./pr_contract.mjs', import.meta.url)), eventPath], {cwd:checkout, encoding:'utf8', env:{...process.env, GITHUB_EVENT_PATH:eventPath}});
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /\[pr-contract\] OK/);
  assert.equal(spawnSync('git', ['cat-file', '-e', base], {cwd:checkout}).status, 0);
});

const shot = `![Demo](https://raw.githubusercontent.com/khentmoba/Everglow/${'a'.repeat(40)}/docs/pr-proof/pr-1/shot.png)`;
const body = `## Summary
Replace personal demo artwork.
## Evidence
${shot}
Analysis: passed — clean
Tests: passed — 1492 tests
Guards: passed — all guards
Browser: passed — phone and tablet
## Merge Danger
**Door:** two-way
**Blast radius:** demo fixtures only`;
const pr = {body,paths:['lib/core/agent/agent_fixtures.dart']};

test('ready visual PR requires real pinned proof and completed check declarations', () => {
  assert.deepEqual(checkPrContract(pr, () => true), []);
  assert.ok(checkPrContract(pr, () => false).some(e => e.includes('missing')));
  for (const bad of [body.replace(shot,'Proof: N/A — capture failed'), body.replace('a'.repeat(40),'main'),
    body.replace('## Merge Danger','## Risk'), body.replace('Tests: passed — 1492 tests','Tests: timed out'),
    body + '\nUnverified: browser route', body + '\n- [ ] screenshot']) {
    assert.ok(checkPrContract({...pr,body:bad}).length);
  }
});

test('drafts may report blockers; nonvisual PRs must explain N/A', () => {
  assert.deepEqual(checkPrContract({draft:true,paths:pr.paths}), []);
  assert.deepEqual(checkPrContract({body:body.replace(shot,'Proof: N/A — docs only'),paths:['AGENTS.md']}), []);
  assert.ok(checkPrContract({body:body.replace(shot,''),paths:['AGENTS.md']}).length);
  assert.ok(checkPrContract({body:'<!-- '+body+' -->',paths:pr.paths}).length);
});
