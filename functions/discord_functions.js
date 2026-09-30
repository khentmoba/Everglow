'use strict';

// Everglow Cloud Functions — Discord group.
// Watch-party posts + button taps + stale-session sweep.

const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');

const { getDb, requireAuth, enforceRateLimit, cappedHttps, getVerifiedUsername } = require('./common.js');

function epLabel(mediaType, season, episode) {
  if (mediaType !== 'tv' || season == null || episode == null) return null;
  return `S${season} E${episode}`;
}

function buildWatchPost({ title, posterPath, mediaType, season, episode, voiceUrl, hostDisplay, partnerMention }) {
  const ep = epLabel(mediaType, season, episode);
  const description = [
    `${hostDisplay} is hosting — join voice, then they Go Live.`,
    ep ? ep : null,
    `[Join voice](${voiceUrl})`,
  ].filter(Boolean).join('\n');
  return {
    content: `${partnerMention} movie night: ${title}`,
    embeds: [{
      title: `Now hosting: ${title}`,
      description,
      image: posterPath ? { url: posterPath } : undefined,
    }],
    components: [{
      type: 1,
      components: [
        { type: 2, style: 5, label: 'Join voice', url: voiceUrl },
        { type: 2, style: 4, label: 'End', custom_id: 'end_watch' },
      ],
    }],
  };
}

function buildEndedPost({ title, hostDisplay }) {
  return {
    content: `Movie night ended: ${title} (hosted by ${hostDisplay})`,
    embeds: [{ title: `Ended: ${title}`, description: 'Thanks for watching.' }],
    components: [],
  };
}

async function verifyDiscordSignature({ publicKeyHex, signatureHex, timestamp, body }) {
  const sodium = require('libsodium-wrappers-sumo');
  await sodium.ready;
  const msg = Buffer.concat([Buffer.from(timestamp, 'utf8'), Buffer.from(body)]);
  return sodium.crypto_sign_verify_detached(
    Buffer.from(signatureHex, 'hex'),
    msg,
    Buffer.from(publicKeyHex, 'hex'),
  );
}

async function postToWebhook({ webhookUrl, payload, fetchImpl }) {
  const useFetch = fetchImpl || fetch;
  const sep = webhookUrl.includes('?') ? '&' : '?';
  const resp = await useFetch(`${webhookUrl}${sep}wait=true&with_components=true`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(12000),
  });
  if (!resp.ok) throw new Error(`Discord post failed: ${resp.status}`);
  const data = await resp.json();
  return data.id;
}

async function patchWebhookMessage({ webhookUrl, messageId, payload, fetchImpl }) {
  const useFetch = fetchImpl || fetch;
  const sep = webhookUrl.includes('?') ? '&' : '?';
  const resp = await useFetch(`${webhookUrl}/messages/${messageId}${sep}with_components=true`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(12000),
  });
  if (!resp.ok) throw new Error(`Discord edit failed: ${resp.status}`);
}

function isAllowedDiscordUser({ userId, env }) {
  if (!userId || !env) return false;
  const allowed = [env.khent, env.clair, env.clair1, env.clair2].filter(Boolean);
  return allowed.includes(userId);
}

const notifyDiscordWatch = cappedHttps(10, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Cache-Control', 'private, no-store');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  let username = '';
  try { username = await getVerifiedUsername(decoded); } catch (e) { console.warn('[notifyDiscordWatch] user lookup failed:', e.message); }
  if (username !== 'khentsgdz' && username !== 'clairjassen') { res.status(403).json({ error: 'Couple only' }); return; }
  if (enforceRateLimit(req, res, { endpoint: 'notifyDiscordWatch', limit: 30, windowMs: 60000, uid: decoded.uid })) return;
  const { title, posterPath, mediaType, season, episode } = req.body || {};
  if (!title || (mediaType !== 'movie' && mediaType !== 'tv')) { res.status(400).json({ error: 'title + mediaType required' }); return; }
  const hostDisplay = username === 'khentsgdz' ? 'Khent' : 'Clair';
  const clairMention = [(process.env.DISCORD_CLAIR_ID1 || '').trim(), (process.env.DISCORD_CLAIR_ID2 || '').trim(), (process.env.DISCORD_CLAIR_ID || '').trim()].filter(Boolean).map((id) => `<@${id}>`).join(' ');
  const partnerMention = username === 'khentsgdz'
    ? clairMention
    : `<@${(process.env.DISCORD_KHENT_ID || '').trim()}>`;
  const voiceUrl = (process.env.DISCORD_VOICE_URL || '').trim();
  const webhookUrl = (process.env.DISCORD_WEBHOOK_URL || '').trim();
  if (!webhookUrl || !voiceUrl) { res.status(503).json({ error: 'Discord is not configured' }); return; }
  const db = getDb();
  const ref = db.collection('discord_watch_sessions').doc('active');
  try {
    const prev = await ref.get();
    if (prev.exists && prev.data().active && prev.data().messageId) {
      try {
        await patchWebhookMessage({ webhookUrl, messageId: prev.data().messageId, payload: { content: `Replaced by new pick: ${title}`, components: [] } });
      } catch (e) { console.warn('[notifyDiscordWatch] supersede edit failed:', e.message); }
    }
    const payload = buildWatchPost({ title, posterPath: posterPath || '', mediaType, season: season ?? null, episode: episode ?? null, voiceUrl, hostDisplay, partnerMention });
    let messageId;
    try {
      messageId = await postToWebhook({ webhookUrl, payload });
    } catch (e) {
      console.warn('[notifyDiscordWatch] post failed:', e.message);
      await ref.set({ title, posterPath: posterPath || '', mediaType, season: season ?? null, episode: episode ?? null, startedBy: username, startedAtMs: Date.now(), active: false, status: 'pending', messageId: '' }, { merge: true });
      res.status(502).json({ error: 'Discord post failed, saved as pending' });
      return;
    }
    await ref.set({ messageId, title, posterPath: posterPath || '', mediaType, season: season ?? null, episode: episode ?? null, startedBy: username, startedAtMs: Date.now(), active: true, status: 'live' });
    res.status(200).json({ messageId });
  } catch (e) { console.warn('[notifyDiscordWatch] failed:', e.message); res.status(500).json({ error: 'Share failed' }); }
});

const discordInteractions = onRequest({ invoker: 'public', maxInstances: 10 }, async (req, res) => {
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }
  // Public by necessity (Discord calls us); signature-checked below and
  // per-IP capped here so forged floods die cheaply.
  if (enforceRateLimit(req, res, { endpoint: 'discordInteractions', limit: 120, windowMs: 60000 })) return;
  const sig = req.get('X-Signature-Ed25519') || '';
  const ts = req.get('X-Signature-Timestamp') || '';
  const raw = req.rawBody ? req.rawBody.toString('utf8') : JSON.stringify(req.body);
  let ok = false;
  try {
    ok = await verifyDiscordSignature({ publicKeyHex: (process.env.DISCORD_PUBLIC_KEY || '').trim(), signatureHex: sig, timestamp: ts, body: raw });
  } catch (e) { console.warn('[discordInteractions] verify failed:', e.message); }
  if (!ok) { res.status(401).json({ error: 'Bad signature' }); return; }
  const body = req.body || {};
  if (body.type === 1) { res.status(200).json({ type: 1 }); return; }
  const memberId = body?.member?.user?.id || body?.user?.id || '';
  const env = { khent: (process.env.DISCORD_KHENT_ID || '').trim(), clair: (process.env.DISCORD_CLAIR_ID || '').trim(), clair1: (process.env.DISCORD_CLAIR_ID1 || '').trim(), clair2: (process.env.DISCORD_CLAIR_ID2 || '').trim() };
  if (!isAllowedDiscordUser({ userId: memberId, env })) { res.status(200).json({ type: 4, data: { content: 'Not for you.', flags: 64 } }); return; }
  const name = body?.data?.name || '';
  const button = body?.data?.custom_id || '';
  if (name !== 'end' && button !== 'end_watch') { res.status(200).json({ type: 4, data: { content: 'Unknown command.', flags: 64 } }); return; }
  const db = getDb();
  const ref = db.collection('discord_watch_sessions').doc('active');
  try {
    const snap = await ref.get();
    if (!snap.exists || !snap.data().active) { res.status(200).json({ type: 4, data: { content: 'Nothing active.', flags: 64 } }); return; }
    const s = snap.data();
    const hostDisplay = s.startedBy === 'khentsgdz' ? 'Khent' : 'Clair';
    const webhookUrl = (process.env.DISCORD_WEBHOOK_URL || '').trim();
    try {
      await patchWebhookMessage({ webhookUrl, messageId: s.messageId, payload: buildEndedPost({ title: s.title, hostDisplay }) });
    } catch (e) { console.warn('[discordInteractions] edit failed:', e.message); }
    await ref.set({ active: false, status: 'ended' }, { merge: true });
    res.status(200).json({ type: 4, data: { content: `Ended: ${s.title}`, flags: 64 } });
  } catch (e) { console.warn('[discordInteractions] failed:', e.message); res.status(200).json({ type: 4, data: { content: 'End failed, try again.', flags: 64 } }); }
});

const sweepStaleDiscordWatch = onSchedule({ schedule: 'every 60 minutes' }, async () => {
  const db = getDb();
  const ref = db.collection('discord_watch_sessions').doc('active');
  try {
    const snap = await ref.get();
    if (!snap.exists || !snap.data().active) return;
    if (Date.now() - (snap.data().startedAtMs || 0) < 12 * 60 * 60 * 1000) return;
    const webhookUrl = (process.env.DISCORD_WEBHOOK_URL || '').trim();
    try {
      await patchWebhookMessage({ webhookUrl, messageId: snap.data().messageId, payload: { content: `Expired: ${snap.data().title}`, components: [] } });
    } catch (e) { console.warn('[sweepStaleDiscordWatch] edit failed:', e.message); }
    await ref.set({ active: false, status: 'expired' }, { merge: true });
  } catch (e) { console.warn('[sweepStaleDiscordWatch] failed:', e.message); }
});

module.exports = {
  notifyDiscordWatch,
  discordInteractions,
  sweepStaleDiscordWatch,
  // Pure builders, exported for unit tests.
  buildWatchPost,
  buildEndedPost,
  postToWebhook,
  patchWebhookMessage,
  isAllowedDiscordUser,
};
