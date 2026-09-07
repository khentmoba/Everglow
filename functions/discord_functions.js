'use strict';

// Everglow Cloud Functions — Discord group.
// Watch-party posts + button taps + stale-session sweep.
// Pure message builders stay in discord.js; HTTP + schedule wiring lives here.

const functions = require('firebase-functions/v1');
const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');

const { getDb, requireAuth, getVerifiedUsername } = require('./common.js');

const notifyDiscordWatch = functions.https.onRequest(async (req, res) => {
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
  const { title, posterPath, mediaType, season, episode } = req.body || {};
  if (!title || (mediaType !== 'movie' && mediaType !== 'tv')) { res.status(400).json({ error: 'title + mediaType required' }); return; }
  const { buildWatchPost, postToWebhook, patchWebhookMessage } = require('./discord.js');
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

const discordInteractions = onRequest({ invoker: 'public' }, async (req, res) => {
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }
  const sig = req.get('X-Signature-Ed25519') || '';
  const ts = req.get('X-Signature-Timestamp') || '';
  const raw = req.rawBody ? req.rawBody.toString('utf8') : JSON.stringify(req.body);
  const { verifyDiscordSignature, buildEndedPost, patchWebhookMessage, isAllowedDiscordUser } = require('./discord.js');
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
    const { patchWebhookMessage } = require('./discord.js');
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
};
