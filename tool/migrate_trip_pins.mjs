#!/usr/bin/env node
// Dry run by default. Keep source pins so every recovery is reversible.
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export async function migrateTripPins(db, { apply = false, log = console.log } = {}) {
  let cursor;
  const counts = { recovered: 0, skipped: 0, missingTrips: 0 };
  do {
    let query = db.collection('travel_pins').orderBy('__name__').limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const pin of page.docs) {
      const data = pin.data();
      if (typeof data.tripId !== 'string' || !data.tripId || data.tripId.includes('/')) {
        counts.missingTrips++; continue;
      }
      const ref = db.collection('travel_trips').doc(data.tripId);
      const outcome = await db.runTransaction(async (tx) => {
        const trip = await tx.get(ref);
        if (!trip.exists) return 'missingTrips';
        const places = Array.isArray(trip.data().places) ? trip.data().places : [];
        const id = `legacy_pin_${pin.id}`;
        if (places.some((place) => place.id === id)) return 'skipped';
        const place = { id, name: String(data.title || ''), note: String(data.note || ''), done: false };
        for (const field of ['lat', 'lng']) {
          if (typeof data[field] === 'number' && Number.isFinite(data[field])) place[field] = data[field];
        }
        if (typeof data.category === 'string') place.category = data.category;
        if (apply) tx.update(ref, { places: [...places, place] });
        return 'recovered';
      });
      counts[outcome]++;
    }
    cursor = page.docs.length === 100 ? page.docs.at(-1) : null;
  } while (cursor);
  log(`${apply ? 'APPLIED' : 'DRY RUN'} ${JSON.stringify(counts)}; source records retained.`);
  return counts;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const project = process.argv.find((arg) => arg.startsWith('--project='))?.slice('--project='.length);
  if (!project) throw new Error('Pass --project=PROJECT_ID; dry run unless --apply is also supplied.');
  const require = createRequire(new URL('../functions/package.json', import.meta.url));
  const { initializeApp } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  initializeApp({ projectId: project });
  await migrateTripPins(getFirestore(), { apply: process.argv.includes('--apply') });
}
