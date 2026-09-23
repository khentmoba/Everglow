'use strict';

/** Normalize gateway input without logging or retaining credential material. */
function normalizePasscode(value) {
  return String(value || '').trim();
}

function isValidPasscodeFormat(value) {
  const passcode = normalizePasscode(value);
  return passcode.length >= 16 && passcode.length <= 256;
}

/**
 * Advances one failed-attempt budget. A successful attempt clears only its
 * own IP bucket; the global bucket is never reset by one login.
 */
function advanceAttemptBudget(
  existing,
  { now = Date.now(), maxFails, windowMs, lockMs },
  failed,
) {
  const data = existing || {};
  let firstFailAt = Number(data.firstFailAt || now);
  let fails = Number(data.fails || 0);
  let lockedUntil = Number(data.lockedUntil || 0);

  if (lockedUntil > now) {
    return { locked: true, lockedUntil, fails, firstFailAt };
  }
  if (now - firstFailAt >= windowMs) {
    fails = 0;
    firstFailAt = now;
  }
  if (!failed) {
    return { locked: false, lockedUntil: 0, fails: 0, firstFailAt: now };
  }

  fails += 1;
  lockedUntil = fails >= maxFails ? now + lockMs : 0;
  return { locked: lockedUntil > now, lockedUntil, fails, firstFailAt };
}

module.exports = {
  normalizePasscode,
  isValidPasscodeFormat,
  advanceAttemptBudget,
};
