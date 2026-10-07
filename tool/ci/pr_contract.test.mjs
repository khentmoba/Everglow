import test from 'node:test';
import assert from 'node:assert/strict';
import {checkPrContract} from './pr_contract.mjs';

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
