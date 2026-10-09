import test from 'node:test';
import assert from 'node:assert/strict';
import {checkPrContract} from './pr_contract.mjs';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';

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

test('CLI checks the merge parent when the PR event base is unavailable', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'pr-contract-'));
  const git = (...args) => execFileSync('git', args, {cwd, stdio:'pipe'});
  try {
    git('init');
    git('config', 'user.name', 'Test');
    git('config', 'user.email', 'test@example.com');
    writeFileSync(join(cwd, 'README.md'), 'Base');
    git('add', '.');
    git('commit', '-m', 'base');
    const base = git('rev-parse', 'HEAD').toString().trim();
    git('checkout', '-b', 'feature');
    writeFileSync(join(cwd, 'README.md'), 'Updated');
    git('commit', '-am', 'change');
    git('checkout', '-b', 'merge', base);
    git('merge', '--no-ff', 'feature', '-m', 'PR merge');
    const eventPath = join(cwd, 'event.json');
    writeFileSync(eventPath, JSON.stringify({pull_request:{
      base:{sha:'f'.repeat(40)}, draft:false,
      body:body.replace(shot, 'Proof: N/A — docs only'),
    }}));
    const output = execFileSync(process.execPath,
      [fileURLToPath(new URL('./pr_contract.mjs', import.meta.url)), eventPath],
      {cwd, encoding:'utf8', env:{...process.env, GITHUB_EVENT_PATH:eventPath}});
    assert.match(output, /\[pr-contract\] OK/);
  } finally {
    rmSync(cwd, {recursive:true, force:true});
  }
});

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
