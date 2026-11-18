// Fails fast when react/dist is missing or older than the code, so the browser
// suites never report a stale build as a test failure.
import { execFileSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = fileURLToPath(new URL('../', import.meta.url));
const DIST = join(ROOT, 'dist');
const fix = 'Run `npm --prefix react run build` first.';

function newestMtime(dir) {
  let newest = 0;
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    const st = statSync(full);
    newest = Math.max(newest, st.isDirectory() ? newestMtime(full) : st.mtimeMs);
  }
  return newest;
}

const problem = (() => {
  const versionFile = join(DIST, 'version.json');
  if (!existsSync(versionFile)) return 'react/dist/version.json is missing.';
  const { build = '' } = JSON.parse(readFileSync(versionFile, 'utf8'));
  let sha = '';
  try {
    sha = execFileSync('git', ['rev-parse', '--short', 'HEAD'], { cwd: ROOT, encoding: 'utf8' }).trim();
  } catch {
    // outside git: the source-time check below still applies
  }
  if (sha && !build.includes(sha)) return `react/dist was built from another commit (${build}), HEAD is ${sha}.`;
  const builtAt = statSync(versionFile).mtimeMs;
  if (newestMtime(join(ROOT, 'src')) > builtAt) return 'react/src changed after react/dist was built.';
  return null;
})();

if (problem) {
  console.error(`[dist] stale build: ${problem} ${fix}`);
  process.exit(1);
}
console.log('[dist] OK: react/dist matches the current code.');
