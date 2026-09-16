'use strict';

const { cappedHttps, enforceRateLimit, getAdmin, getVerifiedUsername, requireAuth } = require('./common.js');
const { resolveGalleryDeletePath } = require('./media_proxy_core.js');

/**
 * Proxies gallery images from Firebase Storage so Flutter web isn't
 * blocked by any CORS or auth issues with direct Storage download URLs.
 *
 * Accepts:
 *   GET /proxyGalleryImage?url=<encoded Storage download URL>[&w=<px>]
 *
 * Validates that the URL belongs to the project's Storage bucket,
 * then fetches and streams it back with permissive CORS headers.
 *
 * `w` is a client perf hint: when present (e.g. `&w=440` from gallery
 * rails/grids), the response is served with a long immutable-style
 * cache header so the downscaled thumb URL is cached independently of
 * the full-res viewer URL. No server-side resize is performed.
 *
 * NOTE: Does NOT require Firebase Auth via Authorization header because
 * Flutter Web Image.network cannot send custom headers. The upstream
 * Storage URL already contains a per-file download token, and we
 * restrict to our own bucket to prevent open-proxy abuse.
 */
const proxyGalleryImage = cappedHttps(30, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }
  // No login by design (<img> tags can't send headers), so the per-IP
  // limit is the abuse backstop here. Gallery grids burst on scroll.
  if (enforceRateLimit(req, res, { endpoint: 'proxyGalleryImage', limit: 240, windowMs: 60000 })) return;

  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<image url> query param' });
    return;
  }

  // Only allow URLs from the project's own Storage bucket
  if (!targetUrl.includes('firebasestorage.googleapis.com') ||
      !targetUrl.includes('everglow-1c6db')) {
    res.status(403).json({ error: 'URL must be from the project Storage bucket' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: { 'Accept': 'image/*,*/*;q=0.8' },
      signal: AbortSignal.timeout(20000),
    });
    if (!upstream.ok) {
      res
        .status(upstream.status)
        .json({ error: `Upstream returned ${upstream.status}` });
      return;
    }
    const contentType =
      upstream.headers.get('content-type') || 'image/jpeg';
    res.set('Content-Type', contentType);
    // Thumb URLs (&w=) are stable per width: cache them long. Full-res
    // viewer URLs keep the short TTL so re-uploads surface quickly.
    const thumbWidth = Array.isArray(req.query.w)
      ? req.query.w[0]
      : req.query.w;
    const thumbPx = typeof thumbWidth === 'string' ? parseInt(thumbWidth, 10) : NaN;
    if (Number.isFinite(thumbPx) && thumbPx > 0 && thumbPx <= 1600) {
      res.set('Cache-Control', 'public, max-age=31536000, immutable');
    } else {
      res.set('Cache-Control', 'public, max-age=3600');
    }
    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.status(200).send(buffer);
  } catch (e) {
    console.warn(`proxyGalleryImage failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Cleans up orphaned gallery data: deletes all Firestore docs in
 * the gallery collection AND their Storage files.
 *
 * Accepts:
 *   POST /cleanupGallery  { confirm: true }
 *
 * Auth required (only khentsgdz can call this).
 */
const cleanupGallery = cappedHttps(5, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Only POST is accepted' });
    return;
  }

  // Verify auth
  const idToken = req.headers.authorization?.replace('Bearer ', '');
  if (!idToken) {
    res.status(401).json({ error: 'Auth required' });
    return;
  }
  const admin = getAdmin();
  let decoded;
  try {
    decoded = await admin.auth().verifyIdToken(idToken);
  } catch (e) {
    res.status(401).json({ error: 'Invalid or expired auth token' });
    return;
  }
  if (decoded.uid !== 'Khentsgdz') {
    // Fall back to the user document so recreated accounts keep working.
    const userDoc = await admin.firestore().collection('users').doc(decoded.uid).get();
    if (!userDoc.exists || userDoc.data()?.username !== 'khentsgdz') {
      res.status(403).json({ error: 'Only khentsgdz can run cleanup' });
      return;
    }
  }
  // Destructive + scans up to 2000 docs: keep it rare.
  if (enforceRateLimit(req, res, { endpoint: 'cleanupGallery', limit: 10, windowMs: 60000, uid: decoded.uid })) return;

  if (req.body?.confirm !== true) {
    res.status(400).json({ error: 'Send { confirm: true } to actually delete' });
    return;
  }

  const db = admin.firestore();
  const bucket = admin.storage().bucket();
  const snap = await db.collection('gallery').limit(2000).get();
  let deleted = 0;

  // Bounded concurrency keeps this from exhausting memory/CPU when the
  // gallery grows; each worker handles storage + Firestore deletion.
  const workerCount = 20;
  let cursor = 0;
  async function worker() {
    while (cursor < snap.docs.length) {
      const doc = snap.docs[cursor++];
      const d = doc.data();
      // Delete Storage file
      if (d.imageUrl && d.imageUrl.includes('firebasestorage.googleapis.com')) {
        try {
          const path = decodeURIComponent(d.imageUrl.split('/o/')[1]?.split('?')[0] || '');
          if (path) await bucket.file(path).delete();
        } catch (_) { /* best effort */ }
      }
      // Delete Firestore doc
      await doc.ref.delete();
      deleted++;
    }
  }
  await Promise.all(Array.from({ length: workerCount }, () => worker()));

  res.json({ deleted });
});

/**
 * Deletes one gallery Storage file as the couple. The client SDK Storage
 * rules only let each user delete under their own uid prefix, so when
 * Clair deletes one of Khent's photos (or vice versa) the direct delete
 * fails and the file is orphaned. This endpoint closes that gap.
 *
 * Accepts:
 *   POST /deleteGalleryPhoto  { imageUrl: <Storage download URL> }
 *
 * Auth required (Khent or Clair only). The path is derived server-side
 * from the download URL and restricted to the `gallery/` prefix, so the
 * caller can never aim this at other files.
 */
const deleteGalleryPhoto = cappedHttps(10, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

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
