'use strict';

// Everglow Cloud Functions — Motchi image + stats group.
// Agnes image generation proxy + 7-day observability rollup.

const { getAdmin, getDb, requireAuth, enforceRateLimit, cappedHttps, checkDailyCap, getVerifiedUsername } = require('./common.js');

// ── Agnes Image Generation Proxy ────────────────────────────────────
const agnesImage = cappedHttps(5, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  // Couple-only: image credits are the priciest per call, so cinema
  // profiles stay out (mirrors motchiStats below).
  const _imgUser = await getVerifiedUsername(decoded);
  if (!['khentsgdz', 'clairjassen'].includes(_imgUser || '')) {
    res.status(403).json({ error: 'Couple-only' });
    return;
  }
  if (enforceRateLimit(req, res, { endpoint: 'agnesImage', limit: 10, windowMs: 60000, uid: decoded.uid })) return;
  const _imgUsage = await checkDailyCap(decoded.uid, 'agnesImage', 30);
  if (!_imgUsage.allowed) {
    res.status(429).json({ error: 'Daily image limit reached — try again tomorrow.' });
    return;
  }

  const apiKey = process.env.AGNES_API_KEY;
  if (!apiKey) {
    res.status(503).json({ error: 'AI image generation is not configured' });
    return;
  }

  const { prompt, size = '1024x1024', image, return_base64 = false } = req.body;

  if (!prompt) {
    res.status(400).json({ error: 'prompt is required' });
    return;
  }

  try {
    const body = {
      model: 'agnes-image-2.0-flash',
      prompt,
      size,
      ...(return_base64 ? { return_base64: true } : {}),
      ...(image ? { extra_body: { image, response_format: return_base64 ? 'b64_json' : 'url' } } : { extra_body: { response_format: 'url' } }),
    };

    const resp = await fetch('https://apihub.agnes-ai.com/v1/images/generations', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(60000),
    });

    if (!resp.ok) {
      const errText = await resp.text().catch(() => '');
      console.error('[agnesImage] Agnes image API error:', resp.status, errText);
      return res.status(resp.status).json({ error: `Agnes image API returned ${resp.status}`, detail: errText });
    }

    const data = await resp.json();
    res.json(data);
  } catch (e) {
    console.error('[agnesImage] Error:', e.message);
    res.status(500).json({ error: e.message || 'Image generation failed' });
  }
});

/**
 * W5-F21: Eval harness — aggregate Motchi observability.
 * GET /motchiStats  (Auth required, couple-only)
 * Returns tool success rates, hallucination counts, and reminder stats
 * for the last 7 days. Used by a future dashboard.
 */
const motchiStats = cappedHttps(5, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (enforceRateLimit(req, res, { endpoint: 'motchiStats', limit: 60, windowMs: 60000, uid: decoded.uid })) return;
  // Couple-only gate: verify username is khentsgdz/clairjassen
  const username = await getVerifiedUsername(decoded);
  if (!['khentsgdz', 'clairjassen'].includes(username || '')) {
    res.status(403).json({ error: 'Couple-only' });
    return;
  }
  try {
    const db = getDb();
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const weekTs = getAdmin().firestore.Timestamp.fromDate(weekAgo);
    const [toolSnap, hallSnap, remSnap] = await Promise.all([
      db.collection('motchi_stats').doc('tool_calls').collection('calls').where('createdAt', '>=', weekTs).limit(200).get().catch(() => ({ empty: true, docs: [] })),
      db.collection('motchi_stats').doc('hallucinations').collection('checks').where('createdAt', '>=', weekTs).limit(50).get().catch(() => ({ empty: true, docs: [] })),
      db.collection('reminders').where('createdAt', '>=', weekTs).limit(50).get().catch(() => ({ empty: true, docs: [] })),
    ]);
    const toolStats = {};
    let totalCalls = 0, okCalls = 0;
    (toolSnap.docs || []).forEach(doc => {
      const d = doc.data();
      const tool = d.tool || 'unknown';
      if (!toolStats[tool]) toolStats[tool] = { total: 0, ok: 0, fail: 0, avgMs: 0, _sumMs: 0 };
      toolStats[tool].total++;
      totalCalls++;
      const isOk = d.ok !== false;
      if (isOk) { toolStats[tool].ok++; okCalls++; } else toolStats[tool].fail++;
      if (typeof d.elapsedMs === 'number') toolStats[tool]._sumMs += d.elapsedMs;
    });
    for (const k of Object.keys(toolStats)) {
      const s = toolStats[k];
      s.avgMs = s.total ? Math.round(s._sumMs / s.total) : 0;
      delete s._sumMs;
    }
    const hallucinations = (hallSnap.docs || []).map(d => {
      const data = d.data();
      return { titles: data.titles || [], at: data.createdAt?.toDate?.()?.toISOString() || null };
    });
    const reminders = { total: (remSnap.docs || []).length, fired: (remSnap.docs || []).filter(d => d.data().fired === true).length };
    // Today's per-user API counters + recent anomaly alerts, so Khent's
    // Creator tab can show usage without opening the Firestore console.
    // Best-effort: never fail the whole stats call over this section.
    const usage = {};
    let recentAlerts = [];
    const usageDay = new Date().toISOString().slice(0, 10);
    try {
      const usersSnap = await db.collection('users').limit(20).get();
      await Promise.all(usersSnap.docs.map(async (u) => {
        const snap = await db.collection('api_usage').doc(u.id).collection('days').doc(usageDay).get().catch(() => null);
        if (snap && snap.exists) {
          const d = snap.data() || {};
          usage[u.data()?.username || u.id] = { proxyAI: d.proxyAI || 0, agnesImage: d.agnesImage || 0 };
        }
      }));
      const alertSnap = await db.collection('api_usage').doc('_alerts').collection('keys').orderBy('lastAlertAt', 'desc').limit(10).get().catch(() => ({ docs: [] }));
      recentAlerts = (alertSnap.docs || []).map((a) => ({ message: a.data()?.message || '', at: a.data()?.lastAlertAt?.toDate?.()?.toISOString() || null }));
    } catch (_) {}
    res.json({
      window: '7d',
      generatedAt: new Date().toISOString(),
      usage,
      usageDay,
      recentAlerts,
      tools: toolStats,
      totalCalls,
      okRate: totalCalls ? (okCalls / totalCalls) : 0,
      hallucinations: { count: hallucinations.length, samples: hallucinations.slice(0, 5) },
      reminders,
    });
  } catch (e) {
    console.warn('[motchiStats] failed:', e.message);
    res.status(500).json({ error: e.message });
  }
});

module.exports = {
  agnesImage,
  motchiStats,
};
