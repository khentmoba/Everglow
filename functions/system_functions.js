'use strict';

const { onSchedule } = require('firebase-functions/v2/scheduler');

const { APP_VERSION, getAdmin, getDb, enforceRateLimit, cappedHttps } = require('./common.js');
const { STALE_PRESENCE_MS, isStalePresence } = require('./system_core.js');

const health = cappedHttps(10, async (req, res) => {
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
  if (enforceRateLimit(req, res, { endpoint: 'health', limit: 60, windowMs: 60000 })) return;

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
