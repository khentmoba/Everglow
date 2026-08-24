'use strict';

/** Normalize gateway input without logging or retaining credential material. */
function normalizePasscode(value) {
  return String(value || '').trim();
}

function isValidPasscodeFormat(value) {
  return /^\d{4}$/.test(normalizePasscode(value));
}

module.exports = {
  normalizePasscode,
  isValidPasscodeFormat,
};
