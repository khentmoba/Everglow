#!/usr/bin/env node
// Dry-run by default. Upload preserved local legacy photos privately with ADC;
// does not create download tokens or modify Firestore.
import { existsSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const source = join(root, 'assets/images/milestones');
const supported = (name) => /^[A-Za-z0-9_-]+\.(jpg|jpeg|png|webp)$/i.test(name);

export async function migrate({ bucket, sourceDir, files, apply = false, log = console.log }) {
  for (const name of files.filter(supported)) {
    const objectPath = `milestones/legacy/${name}`;
    const destination = bucket.file(objectPath);
    const [exists] = await destination.exists();
    if (exists) {
      log(`SKIP exists: ${objectPath}`);
      continue;
    }
    if (!apply) {
      log(`DRY RUN upload: ${join(sourceDir, name)} -> ${objectPath}`);
      continue;
    }
    await bucket.upload(join(sourceDir, name), {
      destination: objectPath,
      resumable: false,
      metadata: {
        contentType: name.toLowerCase().endsWith('.png') ? 'image/png' :
          name.toLowerCase().endsWith('.webp') ? 'image/webp' : 'image/jpeg',
        metadata: { migratedFrom: 'legacy-milestone-bundle' },
      },
      preconditionOpts: { ifGenerationMatch: 0 },
    });
    log(`UPLOADED private object: ${objectPath}`);
  }
  log(apply ? 'Migration complete.' : 'Dry run only; pass --apply to upload.');
}

async function main() {
  const bucketName = process.env.FIREBASE_STORAGE_BUCKET;
  if (!bucketName) throw new Error('Set FIREBASE_STORAGE_BUCKET to the project bucket.');
  if (!existsSync(source)) throw new Error(`Local migration files not found: ${source}`);
  const files = readdirSync(source).filter(supported);
  if (!files.length) throw new Error(`No supported photos found in ${source}`);
  const { initializeApp } = await import('../functions/node_modules/firebase-admin/lib/app/index.js');
  const { getStorage } = await import('../functions/node_modules/firebase-admin/lib/storage/index.js');
  initializeApp({ storageBucket: bucketName });
  await migrate({ bucket: getStorage().bucket(), sourceDir: source, files,
    apply: process.argv.includes('--apply') });
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main();
}
