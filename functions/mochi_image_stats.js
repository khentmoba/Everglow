'use strict';

// Everglow Cloud Functions — Mochi image + stats group.
// Agnes image generation proxy + 7-day observability rollup.

const functions = require('firebase-functions/v1');

const { getAdmin, getDb, requireAuth, getVerifiedUsername } = require('./common.js');

// ── Agnes Image Generation Proxy ────────────────────────────────────
const agnesImage = functions.https.onRequest(async (req, res) => {
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
 * W5-F21: Eval harness — aggregate Mochi observability.
 * GET /mochiStats  (Auth required, couple-only)
 * Returns tool success rates, hallucination counts, and reminder stats
 * for the last 7 days. Used by a future dashboard.
 */
const mochiStats = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
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
      db.collection('mochi_stats').doc('tool_calls').collection('calls').where('createdAt', '>=', weekTs).limit(200).get().catch(() => ({ empty: true, docs: [] })),
      db.collection('mochi_stats').doc('hallucinations').collection('checks').where('createdAt', '>=', weekTs).limit(50).get().catch(() => ({ empty: true, docs: [] })),
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
    res.json({
      window: '7d',
      generatedAt: new Date().toISOString(),
      tools: toolStats,
      totalCalls,
      okRate: totalCalls ? (okCalls / totalCalls) : 0,
      hallucinations: { count: hallucinations.length, samples: hallucinations.slice(0, 5) },
      reminders,
    });
  } catch (e) {
    console.warn('[mochiStats] failed:', e.message);
    res.status(500).json({ error: e.message });
  }
});

module.exports = {
  agnesImage,
  mochiStats,
};
