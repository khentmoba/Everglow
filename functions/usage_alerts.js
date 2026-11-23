'use strict';

const { onSchedule } = require('firebase-functions/v2/scheduler');

const { getAdmin, getDb, phtDayKey } = require('./common.js');
const { sendFCMToUser } = require('./triggers.js');

const WARN_LEVELS = {
  proxyAI: 250,
};

const SPIKE_RATIO = 5;
const SPIKE_MINIMUM = 20;
const ALERT_COOLDOWN_MS = 12 * 60 * 60 * 1000;
const MAX_USERS_SCANNED = 20;

function _dayKey(date) {
  return phtDayKey(date);
}

function detectAnomalies(username, today, yesterday) {
  const alerts = [];
  for (const [endpoint, warnAt] of Object.entries(WARN_LEVELS)) {
    const now = Number(today[endpoint] || 0);
    if (now >= warnAt) {
      alerts.push(`${endpoint} at ${now} today (warn ${warnAt})`);
    }
    const prev = Number(yesterday[endpoint] || 0);
    if (now >= SPIKE_MINIMUM && prev > 0 && now >= SPIKE_RATIO * prev) {
      alerts.push(`${endpoint} spiked ${prev} → ${now} vs yesterday`);
    }
  }
  return alerts.map((line) => `${username}: ${line}`);
}

async function _coolToAlert(alertsRef, key) {
  try {
    const snap = await alertsRef.doc(key).get();
    if (!snap.exists) return true;
    const at = snap.data()?.lastAlertAt?.toMillis?.() || 0;
    return (Date.now() - at) >= ALERT_COOLDOWN_MS;
  } catch (_) {
    return true;
  }
}

async function _markAlerted(alertsRef, key, message) {
  try {
    await alertsRef.doc(key).set({
      message,
      lastAlertAt: getAdmin().firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.warn('[usageAlerts] cooldown write failed:', e.message);
  }
}

const sweepApiUsageAnomalies = onSchedule({
  schedule: 'every 60 minutes',
  timeZone: 'UTC',
  region: 'us-central1',
}, async () => {
  try {
    const db = getDb();
    const now = new Date();
    const todayKey = _dayKey(now);
    const yesterdayKey = _dayKey(new Date(now.getTime() - 24 * 60 * 60 * 1000));
    const alertsRef = db.collection('api_usage').doc('_alerts').collection('keys');

    const usersSnap = await db.collection('users').limit(MAX_USERS_SCANNED).get();
    const fresh = [];
    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;
      const username = (userDoc.data()?.username || uid).toString();
      let today = {};
      let yesterday = {};
      try {
        const daysRef = db.collection('api_usage').doc(uid).collection('days');
        const [tSnap, ySnap] = await Promise.all([
          daysRef.doc(todayKey).get(),
          daysRef.doc(yesterdayKey).get(),
        ]);
        today = tSnap.exists ? tSnap.data() : {};
        yesterday = ySnap.exists ? ySnap.data() : {};
      } catch (e) {
        console.warn(`[usageAlerts] counter read failed for ${username}:`, e.message);
        continue;
      }
      const lines = detectAnomalies(username, today, yesterday);
      for (const line of lines) {
        const key = `${uid}__${line.split(':')[1].trim().split(' ')[0]}`;
        if (await _coolToAlert(alertsRef, key)) {
          fresh.push(line);
          await _markAlerted(alertsRef, key, line);
        }
      }
    }

    if (fresh.length > 0) {
      console.warn('[usageAlerts] ANOMALY:\n' + fresh.join('\n'));
      await sendFCMToUser('khentsgdz', {
        title: '⚠️ Everglow usage alert',
        body: fresh.slice(0, 3).join(' · ').slice(0, 180),
        data: { type: 'usage_alert', count: String(fresh.length) },
      });
    } else {
      console.log('[usageAlerts] usage normal');
    }
  } catch (e) {
    console.warn('[usageAlerts] sweep failed:', e.message);
  }
});

module.exports = {
  sweepApiUsageAnomalies,
  detectAnomalies,
  WARN_LEVELS,
};
