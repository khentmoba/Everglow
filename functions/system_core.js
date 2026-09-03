'use strict';

/**
 * Pure system helpers shared by Cloud Functions and `node --test`.
 * Kept dependency-free so tests can verify TTL logic without Firestore.
 */

const STALE_PRESENCE_MS = 6 * 60 * 1000; // heartbeat is 180s; 2-beat grace

function timestampToMillis(value) {
  if (value == null) return null;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : parsed;
  }
  if (typeof value === 'number') return value;
  return null;
}

/**
 * True when a presence document still claims online but its lastSeen is
 * older than the stale window (or missing entirely).
 */
function isStalePresence(data, nowMs = Date.now(), staleAfterMs = STALE_PRESENCE_MS) {
  if (!data || data.isOnline !== true) return false;
  const lastSeen = timestampToMillis(data.lastSeen);
  if (lastSeen == null) return true;
  return nowMs - lastSeen > staleAfterMs;
}

module.exports = {
  STALE_PRESENCE_MS,
  timestampToMillis,
  isStalePresence,
};
