'use strict';

function normalizePasscode(value) {
  return String(value || '').trim();
}

function isValidPasscodeFormat(value) {
  return /^\d{4}$/.test(normalizePasscode(value));
}

function trustedProfileUsername(decoded) {
  return decoded?.uid && decoded.firebase?.sign_in_provider === 'custom' &&
    ['khentsgdz', 'clairjassen', 'breyan', 'octagram'].includes(decoded.username)
    ? decoded.username : null;
}

module.exports = {
  trustedProfileUsername,
  normalizePasscode,
  isValidPasscodeFormat,
};
