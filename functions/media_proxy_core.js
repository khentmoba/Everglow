'use strict';

function normalizeTmdbPath(value) {
  return String(value || '')
    .split('/')
    .filter(Boolean)
    .join('/');
}

function isAllowedTmdbPath(value) {
  const path = normalizeTmdbPath(value);
  return path.length > 0 && !path.includes('..') && !path.includes('//');
}

function buildTmdbUpstream(path, query = {}, apiKey = '') {
  if (!isAllowedTmdbPath(path)) throw new Error('Invalid TMDB path');
  const upstream = new URL(`https://api.themoviedb.org/3/${normalizeTmdbPath(path)}`);
  for (const [key, value] of Object.entries(query)) {
    const name = key.toLowerCase();
    if (name === 'api_key' || name === 'access_token' || name === '__auth') continue;
    upstream.searchParams.set(key, String(value));
  }
  upstream.searchParams.set('api_key', apiKey);
  return upstream;
}

const LASTFM_METHOD_PATTERN =
  /^(user\.get(?:recenttracks|toptracks|topartists|topalbums|lovedtracks|info)|track\.getinfo)$/;

function isAllowedLastfmMethod(method) {
  return LASTFM_METHOD_PATTERN.test(String(method || ''));
}

function buildLastfmUpstream(query = {}, apiKey = '') {
  if (!isAllowedLastfmMethod(query.method)) {
    throw new Error('Last.fm method not allowed');
  }
  const upstream = new URL('https://ws.audioscrobbler.com/2.0/');
  for (const [key, value] of Object.entries(query)) {
    if (key.toLowerCase() === 'api_key' || key.toLowerCase() === '__auth') continue;
    upstream.searchParams.set(key, String(value));
  }
  upstream.searchParams.set('format', 'json');
  upstream.searchParams.set('api_key', apiKey);
  return upstream;
}

/**
 * Maps a Firebase Storage download URL to the bucket-relative path that
 * the Admin SDK needs for deletion. Only allows this project bucket
 * and only the couple-shared `gallery/` prefix, so the delete endpoint
 * built on this can never be aimed at other files. Throws otherwise.
 */
function resolveGalleryDeletePath(imageUrl) {
  if (typeof imageUrl !== 'string' || imageUrl.length === 0) {
    throw new Error('Missing imageUrl');
  }
  let parsed;
  try {
    parsed = new URL(imageUrl);
  } catch (_) {
    throw new Error('Invalid imageUrl');
  }
  if (parsed.hostname !== 'firebasestorage.googleapis.com') {
    throw new Error('URL must be from the project Storage bucket');
  }
  if (!parsed.pathname.includes('everglow-1c6db')) {
    throw new Error('URL must be from the project Storage bucket');
  }
  const marker = '/o/';
  const at = parsed.pathname.indexOf(marker);
  if (at < 0) throw new Error('Not a Storage download URL');
  const objectPath = decodeURIComponent(parsed.pathname.slice(at + marker.length));
  if (!objectPath || !objectPath.startsWith('gallery/')) {
    throw new Error('Only gallery files can be deleted here');
  }
  if (objectPath.includes('..')) throw new Error('Invalid path');
  return objectPath;
}

module.exports = {
  buildLastfmUpstream,
  buildTmdbUpstream,
  isAllowedLastfmMethod,
  isAllowedTmdbPath,
  normalizeTmdbPath,
  resolveGalleryDeletePath,
};
