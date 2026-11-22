import test from 'node:test';
import assert from 'node:assert/strict';
import {checkPrContract} from './pr_contract.mjs';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, mkdirSync, writeFileSync, rmSync} from 'node:fs';
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
Review: independent — second-model review, no blocking findings
## Merge Danger
**Door:** two-way
**Blast radius:** demo fixtures only
## Still to do
None`;
const pr = {body,paths:['react/src/core/agent/fixtures.ts']};

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
    body.replace('## Merge Danger','## Risk'), body.replace(/## Still to do[\s\S]*/,''), body.replace('Tests: passed — 1492 tests','Tests: timed out'),
    body + '\nUnverified: browser route', body + '\n- [ ] screenshot']) {
    assert.ok(checkPrContract({...pr,body:bad}).length);
  }
});

test('follow-ups need an explicit answer, not just a heading or template comment', () => {
  for (const answer of ['', '<!-- Write None or name the follow-up. -->']) {
    assert.ok(checkPrContract({...pr, body: body.replace(/None$/, answer)})
      .some(error => error.includes('Still to do')));
  }
  assert.deepEqual(checkPrContract({...pr, body: body.replace(/None$/,
    'Khent: verify the phone-to-PC handoff after merge.')}), []);
});

test('every PR records its review, or why no independent review ran', () => {
  assert.deepEqual(checkPrContract(pr, () => true), []);
  assert.ok(checkPrContract({...pr, body: body.replace(/^Review:.*\n/m, '')}).some(e => e.includes('Review:')));
  assert.ok(checkPrContract({...pr, body: body.replace(/^Review:.*$/m, 'Review:')}).length);
  assert.deepEqual(checkPrContract({...pr, body: body.replace(/^Review:.*$/m,
    'Review: self — delegate reviewer hit a provider quota (429)')}), []);
});

test('proof must live under docs/pr-proof/pr-<number>/', () => {
  const flat = shot.replace('pr-1/shot.png', 'shot.png');
  assert.ok(checkPrContract({...pr, body: body.replace(shot, flat)})
    .some(error => error.includes('screenshot')));
});

test('drafts may report blockers; nonvisual PRs must explain N/A', () => {
  assert.deepEqual(checkPrContract({draft:true,paths:pr.paths}), []);
  assert.deepEqual(checkPrContract({body:body.replace(shot,'Proof: N/A — docs only'),paths:['AGENTS.md']}), []);
  assert.ok(checkPrContract({body:body.replace(shot,''),paths:['AGENTS.md']}).length);
  assert.ok(checkPrContract({body:'<!-- '+body+' -->',paths:pr.paths}).length);
});

test('--body checks a local branch and tells a visual PR to open as a draft first', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'pr-contract-local-'));
  const git = (...args) => execFileSync('git', args, {cwd, stdio:'pipe'});
  const cli = (bodyText) => {
    writeFileSync(join(cwd, 'body.md'), bodyText);
    try {
      return {ok:true, out:execFileSync(process.execPath,
        [fileURLToPath(new URL('./pr_contract.mjs', import.meta.url)), '--body', 'body.md', '--base', 'main'],
        {cwd, encoding:'utf8', stdio:'pipe'})};
    } catch (error) {return {ok:false, out:String(error.stderr)};}
  };
  try {
    git('init', '-b', 'main');
    git('config', 'user.name', 'Test');
    git('config', 'user.email', 'test@example.com');
    writeFileSync(join(cwd, 'README.md'), 'Base');
    git('add', '.');
    git('commit', '-m', 'base');
    git('checkout', '-b', 'feature');
    mkdirSync(join(cwd, 'react/src/features/notes'), {recursive:true});
    writeFileSync(join(cwd, 'react/src/features/notes/NotesPage.tsx'), 'export function NotesPage() { return null; }');
    git('add', '.');
    git('commit', '-m', 'visual change');

    const noShot = cli(body.replace(shot, ''));
    assert.equal(noShot.ok, false);
    assert.match(noShot.out, /Open the PR as a draft first/);
    const noLines = cli(body.replace(/^Tests:.*\n/m, ''));
    assert.match(noLines.out, /Record Tests:/);

    git('checkout', 'main');
    git('checkout', '-b', 'docs');
    writeFileSync(join(cwd, 'README.md'), 'Docs');
    git('commit', '-am', 'docs');
    assert.match(cli(body.replace(shot, 'Proof: N/A — docs only')).out, /\[pr-contract\] OK/);

    // --help and --draft flags work from CLI
    const helpOut = execFileSync(process.execPath,
      [fileURLToPath(new URL('./pr_contract.mjs', import.meta.url)), '--help'],
      {cwd, encoding:'utf8', stdio:'pipe'});
    assert.match(helpOut, /--body <file>/);
    assert.match(helpOut, /--draft/);

    writeFileSync(join(cwd, 'empty.md'), 'WIP draft');
    const draftOut = execFileSync(process.execPath,
      [fileURLToPath(new URL('./pr_contract.mjs', import.meta.url)), '--body', 'empty.md', '--base', 'main', '--draft'],
      {cwd, encoding:'utf8', stdio:'pipe'});
    assert.match(draftOut, /\[pr-contract\] OK/);

    // One-way door without plain-text Recovery: explains the exact prefix
    const oneWayErrs = checkPrContract({
      body: body.replace('**Door:** two-way', '**Door:** one-way').replace(shot, 'Proof: N/A — docs only'),
      paths: ['AGENTS.md'],
    });
    assert.ok(oneWayErrs.some(e => e.includes('Recovery: <failure and undo steps>')));
  } finally {
    rmSync(cwd, {recursive:true, force:true});
  }
});
