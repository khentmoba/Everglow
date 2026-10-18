'use strict';

/** Normalize gateway input without logging or retaining credential material. */
function normalizePasscode(value) {
  return String(value || '').trim();
}

function isValidPasscodeFormat(value) {
  return /^\d{4}$/.test(normalizePasscode(value));
}

/** Only verifyPasscode's signed identity can authorize couple data. */
function trustedProfileUsername(decoded, profileUsername = '', cinemaEmail = '') {
  const provider = decoded?.firebase?.sign_in_provider;
  if (!decoded?.uid || provider === 'anonymous') return null;
  if (provider === 'custom' && ['khentsgdz', 'clairjassen'].includes(decoded.username)) {
    return decoded.username;
  }
  // A self-created profile name is not proof of an approved cinema account.
  return provider === 'password' && ['breyan', 'octagram'].includes(profileUsername) &&
    cinemaEmail && decoded.email?.toLowerCase() === cinemaEmail.toLowerCase()
    ? profileUsername : null;
}

module.exports = {
  trustedProfileUsername,
  normalizePasscode,
  isValidPasscodeFormat,
};
