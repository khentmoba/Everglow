// Unified local verification entrypoint for Everglow.
// Checks node_modules (or installs them with --install), then runs react, functions, cloudflare, and tool/ci checks.
// Usage: node tool/ci/verify_all.mjs [--quick] [--install]
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

const args = new Set(process.argv.slice(2));
if (args.has('--help') || args.has('-h')) {
  console.log('Usage: node tool/ci/verify_all.mjs [--quick] [--install]\n  --quick    Skip headless browser tests (react test + agent_smoke)\n  --install  Run npm ci for any package missing node_modules before checking');
  process.exit(0);
}
const quick = args.has('--quick');
const autoInstall = args.has('--install');
const npmCmd = process.platform === 'win32' ? 'cmd.exe' : 'npm';
const npmArgs = (...a) => (process.platform === 'win32' ? ['/d', '/s', '/c', 'npm', ...a] : a);

const missingDeps = ['react', 'functions', 'cloudflare'].filter(
  (dir) => !existsSync(resolve(dir, 'node_modules')),
);
if (missingDeps.length > 0) {
  if (!autoInstall) {
    console.error(
      `[verify_all] missing node_modules in: ${missingDeps.join(', ')}.\n` +
        `Run: node tool/ci/verify_all.mjs --install (or ${missingDeps.map((d) => `npm --prefix ${d} ci`).join(' && ')})`,
    );
    process.exit(1);
  }
  for (const dir of missingDeps) {
    console.log(`\n=== install ${dir} ===`);
    const res = spawnSync(npmCmd, npmArgs('--prefix', dir, 'ci'), { stdio: 'inherit' });
    if (res.status !== 0) {
      console.error(`\n[verify_all] FAILED at: install ${dir}`);
      process.exit(res.status ?? 1);
    }
  }
}

const steps = [
  ['react typecheck', npmCmd, npmArgs('--prefix', 'react', 'run', 'typecheck')],
  ['react lint', npmCmd, npmArgs('--prefix', 'react', 'run', 'lint')],
  ['react build', npmCmd, npmArgs('--prefix', 'react', 'run', 'build')],
  ['regression guards', process.execPath, ['tool/ci/run_checks.mjs']],
  ['tool unit tests', process.execPath, ['--test', '--test-reporter=dot', 'tool/ci/changes.test.mjs', 'tool/ci/deploy_parity.test.mjs', 'tool/ci/run_checks.test.mjs', 'tool/ci/pr_contract.test.mjs', 'tool/remove_worktree.test.mjs', 'tool/capture_proof.test.mjs']],
  ['verify-gate rules', process.execPath, ['--experimental-strip-types', '--test', '--test-reporter=dot', '.pi/extensions/everglow_verify_gate/rules.test.ts']],
  ['functions verify', npmCmd, npmArgs('--prefix', 'functions', 'run', 'verify')],
  ['cloudflare tests', npmCmd, npmArgs('--prefix', 'cloudflare', 'test')],
];

if (!quick) {
  steps.push(
    ['react browser tests', npmCmd, npmArgs('--prefix', 'react', 'test')],
    ['agent smoke unit test', process.execPath, ['--test', '--test-reporter=dot', 'tool/ci/agent_smoke.test.mjs']],
    ['agent smoke', process.execPath, ['tool/agent_smoke.mjs', 'react/dist']],
  );
}

for (const [label, cmd, cmdArgs] of steps) {
  console.log(`\n=== ${label} ===`);
  const res = spawnSync(cmd, cmdArgs, { stdio: 'inherit' });
  if (res.status !== 0) {
    console.error(`\n[verify_all] FAILED at: ${label}`);
    process.exit(res.status ?? 1);
  }
}

console.log('\n[verify_all] ALL CHECKS PASSED.');
