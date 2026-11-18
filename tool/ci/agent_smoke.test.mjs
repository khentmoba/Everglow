// Needs Chrome (set CHROME_PATH): proves the smoke sweep fails on a page that
// throws, which it once silently passed.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const smoke = fileURLToPath(new URL('../agent_smoke.mjs', import.meta.url));

test('agent smoke fails when a page throws after mounting', () => {
  const dist = mkdtempSync(join(tmpdir(), 'smoke-throw-'));
  try {
    writeFileSync(
      join(dist, 'index.html'),
      `<!doctype html><div id="root"><p>Mounted</p></div>
<script>setTimeout(() => { throw new Error('boom from smoke self-test'); }, 0);</script>`,
    );
    const run = spawnSync(process.execPath, [smoke, dist], { encoding: 'utf8', timeout: 60_000 });
    assert.notEqual(run.status, 0, `smoke passed a throwing page:\n${run.stdout}`);
    assert.match(run.stderr, /boom from smoke self-test/);
  } finally {
    rmSync(dist, { recursive: true, force: true });
  }
});
