import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {existsSync, mkdtempSync, mkdirSync, writeFileSync, readFileSync, renameSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve, sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {selectChecks} from './changes.mjs';

const baseline = {app:true, browser:false, web:true, backend:true, security:false, audit:true};
const all = {app:true, browser:true, web:true, backend:true, security:true, audit:true};

// Missing a shared input or classifying a deleted source as documentation must
// never let a PR bypass the checks that source can affect.
for (const [name, paths, want] of [
  ['docs retain every deployment prerequisite without extra browser coverage', ['AGENTS.md', 'README.md', 'docs/PERF_NOTES.md', '.agents/skills/everglow-ship/SKILL.md'], baseline],
  ['PR template edits retain deployment prerequisites', ['.github/pull_request_template.md'], baseline],
  ['ordinary app feature keeps app verification and its release build', ['lib/features/notes/note.dart'], {...baseline, app:true, web:true}],
  ['shared app code also keeps browser coverage', ['lib/shared/widgets/button.dart'], {...baseline, app:true, browser:true, web:true}],
  ['anime changes keep browser-only app coverage', ['lib/features/anime/player.dart'], {...baseline, app:true, browser:true, web:true}],
  ['unit test edits retain deployment prerequisites', ['test/features/notes/note_test.dart'], {...baseline, app:true}],
  ['browser test edits retain browser execution', ['test/embedded_media_web_memory_test.dart'], {...baseline, app:true, browser:true}],
  ['app dependencies retain all app platforms', ['pubspec.lock'], {...baseline, app:true, browser:true, web:true}],
  ['backend edits retain backend and privacy verification', ['functions/auth_core.js'], {...baseline, backend:true, security:true}],
  ['backend dependency edits also audit the lockfile', ['functions/package-lock.json'], {...baseline, backend:true, security:true, audit:true}],
  ['rules-only changes execute privacy tests', ['firestore.rules', 'storage.rules'], {...baseline, security:true}],
  ['client auth changes also execute privacy tests', ['lib/core/services/auth_service.dart'], {...baseline, app:true, browser:true, web:true, security:true}],
  ['worker changes retain the release build and deterministic worker tests', ['tool/generate_sw.dart', 'tool/service_worker_test.mjs'], {...baseline, web:true}],
  ['performance tool changes use manual browser verification', ['tool/perf/_harness.mjs'], baseline],
  ['CI changes verify every affected execution path', ['.github/workflows/quality.yml'], all],
  ['selection logic changes cannot skip their own consumers', ['tool/ci/changes.mjs'], all],
  ['unrecognized inputs conservatively run everything', ['new-build-system/config.toml'], all],
  ['mixed changes retain each relevant check', ['docs/note.md', 'functions/media.js', 'lib/features/notes/note.dart'], {...baseline, app:true, web:true, backend:true, security:true}],
  ['an unavailable diff runs everything', null, all],
]) {
  test(name, () => assert.deepEqual(selectChecks(paths), want));
}

const script = fileURLToPath(new URL('./changes.mjs', import.meta.url));
function repository(t) {
  const dir = mkdtempSync(join(tmpdir(), 'everglow-ci-test-'));
  assert.ok(resolve(dir).startsWith(resolve(tmpdir()) + sep));
  t.after(() => rmSync(dir, {recursive:true, force:true}));
  const git = (...args) => execFileSync('git', args, {cwd:dir, encoding:'utf8'}).trim();
  git('init', '-q');
  git('config', 'core.autocrlf', 'false');
  mkdirSync(join(dir, 'functions'));
  mkdirSync(join(dir, 'docs'));
  writeFileSync(join(dir, 'functions/auth_core.js'), 'fixture\n');
  git('add', '.');
  git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'baseline');
  const base = git('rev-parse', 'HEAD');
  const run = (baseSha = base) => {
    const output = join(dir, 'outputs');
    const result = spawnSync(process.execPath, [script], {
      cwd:dir, encoding:'utf8', env:{...process.env, BASE_SHA:baseSha, GITHUB_OUTPUT:output},
    });
    assert.equal(result.status, 0, result.stderr);
    assert.ok(existsSync(output), 'the CLI must publish check-selection outputs');
    return Object.fromEntries(readFileSync(output, 'utf8').trim().split('\n').map(line => line.split('=')));
  };
  return {dir, run, git};
}

test('the CLI includes deleted backend paths when a file is renamed into docs', t => {
  const {dir, run, git} = repository(t);
  renameSync(join(dir, 'functions/auth_core.js'), join(dir, 'docs/fixture.md'));
  git('add', '.');
  git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'move into docs');
  assert.deepEqual(run(), {app:'true', browser:'false', web:'true', backend:'true', security:'true', audit:'true'});
});

test('the CLI falls back to full verification when Git cannot provide the diff', t => {
  const {run} = repository(t);
  assert.deepEqual(run('not-a-commit'), {app:'true', browser:'true', web:'true', backend:'true', security:'true', audit:'true'});
});
