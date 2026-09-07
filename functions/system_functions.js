'use strict';

// Everglow Cloud Functions — system group.
// Holds liveness + presence TTL sweeper so index.js stays a thin
// composition root. Export names match the old index.js surface.

const functions = require('firebase-functions/v1');
const { onSchedule } = require('firebase-functions/v2/scheduler');

const { APP_VERSION, getAdmin, getDb } = require('./common.js');
const { STALE_PRESENCE_MS, isStalePresence } = require('./system_core.js');

/**
 * Liveness + dependency check for uptime monitoring.
 *
 * Accepts:
 *   GET /api/health
 *
 * Public by design: it only reveals service identity and Firestore
 * reachability, never user data.
 */
const health = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Cache-Control', 'no-store');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }

  const checks = { firestore: 'pending' };
  let status = 'ok';
  try {
    await getDb().collection('config').doc('health').get();
    checks.firestore = 'ok';
  } catch (e) {
    checks.firestore = 'error';
    status = 'degraded';
    console.error('[health] Firestore check failed:', e.message);
  }

  res.status(status === 'ok' ? 200 : 503).json({
    status,
    service: 'everglow-api',
    version: APP_VERSION,
    time: new Date().toISOString(),
    uptimeSeconds: Math.round(process.uptime()),
    checks,
  });
});

/**
 * Presence TTL sweeper.
 *
 * Clients heartbeat every 60 seconds but a closed tab can leave
 * `isOnline: true` forever. This scheduled job marks stale online
 * presence documents offline so the partner UI never shows a ghost.
 */
const sweepStalePresence = onSchedule({
  schedule: 'every 10 minutes',
  timeZone: 'UTC',
  region: 'us-central1',
}, async () => {
  const db = getDb();
  const cutoff = new Date(Date.now() - STALE_PRESENCE_MS);
  const snapshot = await db
    .collection('presence')
    .where('isOnline', '==', true)
    .where('lastSeen', '<', cutoff)
    .limit(500)
    .get();

  let updated = 0;
  const results = await Promise.allSettled(snapshot.docs.map(async (doc) => {
    const data = doc.data();
    if (!isStalePresence(data, Date.now(), STALE_PRESENCE_MS)) return;
    await doc.ref.update({
      isOnline: false,
      isDoodling: false,
      updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
      sweptAt: getAdmin().firestore.FieldValue.serverTimestamp(),
    });
    // also close any active presence_sessions dangling for this uid
    try {
      const sessSnap = await db.collection('presence_sessions')
        .where('uid', '==', doc.id)
        .where('isActive', '==', true)
        .limit(10)
        .get();
      const closes = sessSnap.docs.map((sdoc) => sdoc.ref.set({
        endedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
        isActive: false,
        lastSeenAt: data.lastSeen || getAdmin().firestore.FieldValue.serverTimestamp(),
        updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
        endedReason: 'swept',
      }, { merge: true }));
      await Promise.all(closes);
      if (closes.length) console.log('[sweepStalePresence] closed ' + closes.length + ' sessions for ' + doc.id);
    } catch (e) {
      console.warn('[sweepStalePresence] session close failed for ' + doc.id + ': ' + e.message);
    }
    updated += 1;
  }));

  const failures = results.filter((r) => r.status === 'rejected').length;
  console.log(
    `[sweepStalePresence] scanned=${snapshot.size} updated=${updated} failures=${failures}`,
  );
  if (failures > 0) {
    throw new Error(`${failures} presence sweeps failed`);
  }
});

module.exports = {
  health,
  sweepStalePresence,
};
