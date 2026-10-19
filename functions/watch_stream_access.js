'use strict';

const { createHmac, timingSafeEqual } = require('node:crypto');

const WATCH_PROXY_URL = 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyWatchStream';
const STREAM_LIFETIME_MS = 6 * 60 * 60 * 1000;

function mediaUrl(value) {
  const url = new URL(value);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) {
    throw new Error('Only credential-free http(s) urls are allowed');
  }
  return url.toString();
}

function signature(url, { uid, expires, referer = '', secret }) {
  return createHmac('sha256', secret).update(JSON.stringify([uid, expires, url, referer])).digest('hex');
}

function signedStreamUrl(url, access) {
  const target = mediaUrl(url);
  const result = new URL(WATCH_PROXY_URL);
  result.search = new URLSearchParams({ url: target, uid: access.uid, expires: String(access.expires),
    signature: signature(target, access), ...(access.referer ? { referer: access.referer } : {}) }).toString();
  return result.toString();
}

function validStreamSignature(url, access, supplied, now = Date.now()) {
  if (!Number.isSafeInteger(access.expires) || access.expires <= now ||
      access.expires > now + STREAM_LIFETIME_MS || !/^[a-f0-9]{64}$/.test(supplied || '')) return false;
  const expected = signature(url, access);
  return timingSafeEqual(Buffer.from(expected, 'hex'), Buffer.from(supplied, 'hex'));
}

// Cover nested playlists, segments, AES keys, init maps, audio and subtitles.
function rewritePlaylist(text, base, access) {
  return text.split(/\r?\n/).map((line) => {
    if (!line.trim()) return line;
    if (line.trimStart().startsWith('#')) {
      return line.replace(/\bURI="([^"]+)"/g, (_, uri) =>
        `URI="${signedStreamUrl(new URL(uri, base).toString(), access)}"`);
    }
    return signedStreamUrl(new URL(line.trim(), base).toString(), access);
  }).join('\n');
}

module.exports = {
  WATCH_PROXY_URL, STREAM_LIFETIME_MS, mediaUrl, signedStreamUrl, validStreamSignature, rewritePlaylist,
};
