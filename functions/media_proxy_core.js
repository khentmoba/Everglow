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
  let upstream;
  try {
    upstream = new URL(`https://api.themoviedb.org/3/${normalizeTmdbPath(path)}`);
  } catch (err) {
    throw new Error('Invalid TMDB path', { cause: err });
  }
  if (upstream.origin !== 'https://api.themoviedb.org' || !upstream.pathname.startsWith('/3/')) {
    throw new Error('Invalid TMDB path');
  }
  for (const [key, value] of Object.entries(query)) {
    const name = key.toLowerCase();
    if (name === 'api_key' || name === 'access_token' || name === '__auth') continue;
    upstream.searchParams.set(key, String(value));
  }
  upstream.searchParams.set('api_key', apiKey);
  return upstream;
}

const LASTFM_METHOD_PATTERN =
  /^(user\.get(?:recenttracks|toptracks|topartists|topalbums|lovedtracks|artisttracks|trackscrobbles|info)|track\.getinfo|artist\.(?:search|getinfo|gettoptracks))$/i;

function isAllowedLastfmMethod(method) {
  return LASTFM_METHOD_PATTERN.test(String(method || ''));
}

function buildLastfmUpstream(query = {}, apiKey = '') {
  if (!isAllowedLastfmMethod(query.method)) {
    throw new Error('Last.fm method not allowed');
  }
  let upstream;
  try {
    upstream = new URL('https://ws.audioscrobbler.com/2.0/');
  } catch (err) {
    throw new Error('Failed to create Last.fm upstream URL', { cause: err });
  }
  for (const [key, value] of Object.entries(query)) {
    if (key.toLowerCase() === 'api_key' || key.toLowerCase() === '__auth') continue;
    upstream.searchParams.set(key, String(value));
  }
  upstream.searchParams.set('format', 'json');
  upstream.searchParams.set('api_key', apiKey);
  return upstream;
}

function parseProjectStorageUrl(value) {
  let parsed;
  try {
    parsed = new URL(value);
  } catch (err) {
    throw new Error('Invalid imageUrl', { cause: err });
  }
  const match = parsed.pathname.match(/^\/v0\/b\/([^/]+)\/o\/(.+)$/);
  const buckets = ['everglow-1c6db.firebasestorage.app', 'everglow-1c6db.appspot.com'];
  if (parsed.protocol !== 'https:' || parsed.hostname !== 'firebasestorage.googleapis.com' ||
      parsed.port || parsed.username || parsed.password || !match || !buckets.includes(match[1])) {
    throw new Error('URL must be from the project Storage bucket');
  }
  return parsed;
}

function resolveGalleryDeletePath(imageUrl) {
  if (typeof imageUrl !== 'string' || imageUrl.length === 0) {
    throw new Error('Missing imageUrl');
  }
  const parsed = parseProjectStorageUrl(imageUrl);
  const marker = '/o/';
  const at = parsed.pathname.indexOf(marker);
  if (at < 0) throw new Error('Not a Storage download URL');
  let objectPath;
  try {
    objectPath = decodeURIComponent(parsed.pathname.slice(at + marker.length));
  } catch (err) {
    throw new Error('Invalid imageUrl', { cause: err });
  }
  if (!objectPath || !objectPath.startsWith('gallery/')) {
    throw new Error('Only gallery files can be deleted here');
  }
  if (objectPath.includes('..')) throw new Error('Invalid path');
  return objectPath;
}

function resolveKatanaServerCookie(hostname, cookieParam) {
  const host = String(hostname || '');
  const hostOk =
    host === 'mangakatana.com' || host.endsWith('.mangakatana.com');
  if (!hostOk) return '';
  return cookieParam === 's_r=sv2' || cookieParam === 's_r=sv3'
    ? cookieParam
    : '';
}

module.exports = {
  buildLastfmUpstream,
  buildTmdbUpstream,
  isAllowedLastfmMethod,
  isAllowedTmdbPath,
  normalizeTmdbPath,
  parseProjectStorageUrl,
  resolveGalleryDeletePath,
  resolveKatanaServerCookie,
};
