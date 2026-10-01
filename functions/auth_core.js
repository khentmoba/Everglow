'use strict';

/** Normalize gateway input without logging or retaining credential material. */
function normalizePasscode(value) {
  return String(value || '').trim();
}

function isValidPasscodeFormat(value) {
  return /^\d{4}$/.test(normalizePasscode(value));
}

/** Only verifyPasscode's signed identity can authorize couple data. */
function trustedProfileUsername(decoded, profileUsername = '') {
  const provider = decoded?.firebase?.sign_in_provider;
  if (!decoded?.uid || provider === 'anonymous') return null;
  if (provider === 'custom' && ['khentsgdz', 'clairjassen'].includes(decoded.username)) {
    return decoded.username;
  }
  // The legacy email/password cinema profiles cannot become the couple,
  // even if their profile document has been forged or recreated.
  return ['breyan', 'octagram'].includes(profileUsername) ? profileUsername : null;
}

module.exports = {
  trustedProfileUsername,
  normalizePasscode,
  isValidPasscodeFormat,
};
