'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');
const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');

async function main() {
  const sourceDir = process.argv[2];
  if (!sourceDir) {
    throw new Error(
      'Usage: node scripts/migrate_private_milestones.js <private-image-directory>',
    );
  }

  initializeApp({
    credential: applicationDefault(),
    projectId: process.env.GCLOUD_PROJECT || 'everglow-1c6db',
  });
  const db = getFirestore();
  const bucket = getStorage().bucket();
  const files = (await fs.readdir(sourceDir))
    .filter((name) => /\.(?:jpe?g|png|webp)$/i.test(name))
    .sort();
  const urlsByName = new Map();

  for (const name of files) {
    const objectPath = `milestones/imported/${name}`;
    const token = crypto.randomUUID();
    const object = bucket.file(objectPath);
    const extension = path.extname(name).slice(1).toLowerCase();
    const contentType = extension === 'jpg' || extension === 'jpeg'
      ? 'image/jpeg'
      : `image/${extension}`;
    await object.save(await fs.readFile(path.join(sourceDir, name)), {
      resumable: false,
      metadata: {
        contentType,
        metadata: { firebaseStorageDownloadTokens: token },
      },
    });
    urlsByName.set(
      name,
      `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(objectPath)}?alt=media&token=${token}`,
    );
  }

  const snapshot = await db.collection('milestones').get();
  let updated = 0;
  for (const doc of snapshot.docs) {
    const urls = Array.isArray(doc.data().imageUrls)
      ? doc.data().imageUrls
      : [];
    const migrated = urls.map((url) => {
      if (typeof url !== 'string' || !url.startsWith('assets/')) return url;
      const name = url.split('/').pop();
      return urlsByName.get(name) || url;
    });
    if (migrated.some((url, index) => url !== urls[index])) {
      await doc.ref.update({ imageUrls: migrated });
      updated += 1;
    }
  }

  console.log(`Uploaded ${files.length} private milestone files; updated ${updated} docs.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
