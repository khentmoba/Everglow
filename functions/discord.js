'use strict';

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
  const sodium = require('libsodium-wrappers');
  await sodium.ready;
  const msg = Buffer.concat([Buffer.from(timestamp, 'utf8'), Buffer.from(body)]);
  return sodium.crypto_sign_verify_detached(
    Buffer.from(signatureHex, 'hex'),
    msg,
    Buffer.from(publicKeyHex, 'hex'),
  );
}

module.exports = { buildWatchPost, buildEndedPost, verifyDiscordSignature };

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

module.exports.postToWebhook = postToWebhook;
module.exports.patchWebhookMessage = patchWebhookMessage;

function isAllowedDiscordUser({ userId, env }) {
  if (!userId || !env) return false;
  const allowed = [env.khent, env.clair, env.clair1, env.clair2].filter(Boolean);
  return allowed.includes(userId);
}
module.exports.isAllowedDiscordUser = isAllowedDiscordUser;
