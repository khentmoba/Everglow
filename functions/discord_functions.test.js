'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const discordFunctions = require('./discord_functions');
const indexExports = require('./index');

test('discord group exposes watch post + interactions + sweep', () => {
  assert.equal(typeof discordFunctions.notifyDiscordWatch, 'function');
  assert.equal(typeof discordFunctions.discordInteractions, 'function');
  assert.equal(typeof discordFunctions.sweepStaleDiscordWatch, 'function');
});

test('index re-exports the discord group without renaming', () => {
  assert.equal(indexExports.notifyDiscordWatch, discordFunctions.notifyDiscordWatch);
  assert.equal(indexExports.discordInteractions, discordFunctions.discordInteractions);
  assert.equal(indexExports.sweepStaleDiscordWatch, discordFunctions.sweepStaleDiscordWatch);
});

test('postToWebhook and patchWebhookMessage drain response bodies', async () => {
  let postCancelled = false;
  await assert.rejects(
    discordFunctions.postToWebhook({
      webhookUrl: 'https://discord.com/api/webhooks/1/tok',
      payload: { content: 'hi' },
      fetchImpl: async () => ({
        ok: false,
        status: 500,
        body: { cancel: async () => { postCancelled = true; } },
      }),
    }),
    /Discord post failed: 500/,
  );
  assert.equal(postCancelled, true);

  let patchCancelled = false;
  await discordFunctions.patchWebhookMessage({
    webhookUrl: 'https://discord.com/api/webhooks/1/tok',
    messageId: '123',
    payload: { content: 'done' },
    fetchImpl: async () => ({
      ok: true,
      status: 200,
      body: { cancel: async () => { patchCancelled = true; } },
    }),
  });
  assert.equal(patchCancelled, true);
});

test('safeHttpsPosterUrl allows only credential-free https URLs', () => {
  assert.equal(
    discordFunctions.safeHttpsPosterUrl('https://image.tmdb.org/t/p/w500/abc.jpg'),
    'https://image.tmdb.org/t/p/w500/abc.jpg',
  );
  assert.equal(discordFunctions.safeHttpsPosterUrl('http://image.tmdb.org/a.jpg'), '');
  assert.equal(discordFunctions.safeHttpsPosterUrl('javascript:alert(1)'), '');
  assert.equal(discordFunctions.safeHttpsPosterUrl('https://user:pass@image.tmdb.org/a.jpg'), '');
  assert.equal(discordFunctions.safeHttpsPosterUrl(null), '');
});
