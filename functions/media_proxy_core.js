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

module.exports = {
  buildLastfmUpstream,
  buildTmdbUpstream,
  isAllowedLastfmMethod,
  isAllowedTmdbPath,
  normalizeTmdbPath,
};
