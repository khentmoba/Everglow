import test from 'node:test';
import assert from 'node:assert/strict';
import { migrate } from './migrate_private_milestone_photos.mjs';

function fakeBucket(existing = []) {
  const uploaded = [];
  return {
    uploaded,
    file(path) { return { exists: async () => [existing.includes(path)] }; },
    async upload(local, options) { uploaded.push({ local, options }); },
  };
}

test('dry-run reports eligible files but never uploads', async () => {
  const bucket = fakeBucket();
  const logs = [];
  await migrate({ bucket, sourceDir: '/local', files: ['one.jpg', 'bad.txt'], log: (line) => logs.push(line) });
  assert.equal(bucket.uploaded.length, 0);
  assert.match(logs[0], /DRY RUN upload/);
});

test('apply uploads private objects with no token and generation precondition; skips existing', async () => {
  const bucket = fakeBucket(['milestones/legacy/existing.png']);
  const logs = [];
  await migrate({ bucket, sourceDir: '/local', files: ['existing.png', 'new.webp'], apply: true, log: (line) => logs.push(line) });
  assert.equal(bucket.uploaded.length, 1);
  assert.equal(bucket.uploaded[0].options.destination, 'milestones/legacy/new.webp');
  assert.deepEqual(bucket.uploaded[0].options.preconditionOpts, { ifGenerationMatch: 0 });
  assert.equal(bucket.uploaded[0].options.metadata.metadata.downloadTokens, undefined);
  assert.match(logs[0], /SKIP exists/);
});
