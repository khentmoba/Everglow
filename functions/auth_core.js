'use strict';

const LEGACY_PROFILES = ['khentsgdz', 'clairjassen', 'breyan', 'octagram'];
const USERNAME_RE = /^[a-zA-Z0-9_-]{3,24}$/;
const RESERVED_USERNAMES = new Set([
  'khentsgdz',
  'clairjassen',
  'breyan',
  'octagram',
  'khent',
  'clair',
  'admin',
  'system',
  'everglow',
  'moderator',
  'mod',
]);

function normalizePasscode(value) {
  return String(value || '').trim();
}

function isValidPasscodeFormat(value) {
  return /^\d{4}$/.test(normalizePasscode(value));
}

function normalizeUsername(value) {
  return String(value || '').trim();
}

function isValidUsername(value) {
  return USERNAME_RE.test(normalizeUsername(value));
}

function isReservedUsername(value) {
  return RESERVED_USERNAMES.has(normalizeUsername(value).toLowerCase());
}

function trustedProfileUsername(decoded) {
  if (!decoded?.uid || decoded.firebase?.sign_in_provider !== 'custom') return null;
  if (typeof decoded.username !== 'string') return null;
  if (LEGACY_PROFILES.includes(decoded.username)) return decoded.username;
  if (
    decoded.accountType === 'member' &&
    isValidUsername(decoded.username) &&
    !isReservedUsername(decoded.username)
  ) {
    return decoded.username;
  }
  return null;
}

module.exports = {
  LEGACY_PROFILES,
  RESERVED_USERNAMES,
  trustedProfileUsername,
  normalizePasscode,
  isValidPasscodeFormat,
  normalizeUsername,
  isValidUsername,
  isReservedUsername,
};
