'use strict';

const { applyCors, cappedHttps, enforceRateLimit, getAdmin, getVerifiedUsername, requireAuth } = require('./common.js');
const { parseProjectStorageUrl, resolveGalleryDeletePath } = require('./media_proxy_core.js');
const { streamMediaBody } = require('./stream_media_body');

const RASTER_IMAGE_RE = /^image\/(jpeg|jpg|png|webp|gif|heic|heif|avif)(?:;|$)/i;

const proxyGalleryImage = cappedHttps(30, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }
  if (enforceRateLimit(req, res, { endpoint: 'proxyGalleryImage', limit: 240, windowMs: 60000 })) return;

  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<image url> query param' });
    return;
  }

  try {
    parseProjectStorageUrl(targetUrl);
  } catch (_) {
    res.status(403).json({ error: 'URL must be from the project Storage bucket' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      redirect: 'error',
      headers: { 'Accept': 'image/*,*/*;q=0.8' },
      signal: AbortSignal.timeout(20000),
    });
    if (!upstream.ok) {
      await upstream.body?.cancel().catch(() => {});
      res
        .status(upstream.status)
        .json({ error: `Upstream returned ${upstream.status}` });
      return;
    }
    const contentType =
      (upstream.headers.get('content-type') || '').trim() || 'image/jpeg';
    if (!RASTER_IMAGE_RE.test(contentType)) {
      if (upstream.body && typeof upstream.body.cancel === 'function') {
        await upstream.body.cancel().catch(() => {});
      }
      res.status(415).json({ error: 'Upstream did not return a supported image' });
      return;
    }
    res.set('Content-Type', contentType);
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Content-Security-Policy', "default-src 'none'; sandbox");
    const isThumbFile = targetUrl.includes('_thumb.jpg');
    if (isThumbFile) {
      res.set('Cache-Control', 'private, max-age=31536000, immutable');
    } else {
      res.set('Cache-Control', 'private, max-age=3600');
    }
    res.status(200);
    if (upstream.body != null) {
      await streamMediaBody(upstream.body, res);
    } else {
      const buffer = Buffer.from(await upstream.arrayBuffer());
      res.send(buffer);
    }
  } catch (e) {
    console.warn(`proxyGalleryImage failed (${targetUrl}):`, e.message);
    if (res.headersSent || res.destroyed) {
      if (!res.destroyed) res.destroy(e);
      return;
    }
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

const cleanupGallery = cappedHttps(5, async (req, res) => {
  applyCors(req, res, 'POST, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Only POST is accepted' });
    return;
  }

  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  const admin = getAdmin();
  if (await getVerifiedUsername(decoded) !== 'khentsgdz') {
    res.status(403).json({ error: 'Only khentsgdz can run cleanup' });
    return;
  }
  if (enforceRateLimit(req, res, { endpoint: 'cleanupGallery', limit: 10, windowMs: 60000, uid: decoded.uid })) return;

  if (req.body?.confirm !== true) {
    res.status(400).json({ error: 'Send { confirm: true } to actually delete' });
    return;
  }

  const db = admin.firestore();
  const bucket = admin.storage().bucket();
  const snap = await db.collection('gallery').limit(2000).get();
  let deleted = 0;

  const workerCount = 20;
  let cursor = 0;
  async function worker() {
    while (cursor < snap.docs.length) {
      const doc = snap.docs[cursor++];
      const d = doc.data();
      if (d.imageUrl && d.imageUrl.includes('firebasestorage.googleapis.com')) {
        try {
          const path = resolveGalleryDeletePath(d.imageUrl);
          if (path) await bucket.file(path).delete();
        } catch (_) { }
      }
      await doc.ref.delete();
      deleted++;
    }
  }
  await Promise.all(Array.from({ length: workerCount }, () => worker()));

  res.json({ deleted });
});

const deleteGalleryPhoto = cappedHttps(10, async (req, res) => {
  applyCors(req, res, 'POST, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Only POST is accepted' });
    return;
  }

  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  const username = await getVerifiedUsername(decoded);
  if (username !== 'khentsgdz' && username !== 'clairjassen') {
    res.status(403).json({ error: 'Couple only' });
    return;
  }
  if (enforceRateLimit(req, res, { endpoint: 'deleteGalleryPhoto', limit: 30, windowMs: 60000, uid: decoded.uid })) return;

  let objectPath;
  try {
    objectPath = resolveGalleryDeletePath(req.body && req.body.imageUrl);
  } catch (e) {
    res.status(400).json({ error: e.message });
    return;
  }

  try {
    await getAdmin().storage().bucket().file(objectPath).delete({ ignoreNotFound: true });
  } catch (e) {
    console.warn('deleteGalleryPhoto failed:', objectPath, e.message);
    res.status(502).json({ error: 'Storage delete failed' });
    return;
  }
  res.json({ ok: true });
});

module.exports = { proxyGalleryImage, cleanupGallery, deleteGalleryPhoto };
