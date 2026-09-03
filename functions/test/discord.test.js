'use strict';
const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { buildWatchPost, buildEndedPost } = require('../discord');

describe('buildWatchPost', () => {
  it('mentions partner, shows S/E for tv, keeps End button', () => {
    const post = buildWatchPost({
      title: 'Attack on Titan', posterPath: '/p.jpg', mediaType: 'tv',
      season: 1, episode: 5, voiceUrl: 'https://discord.com/channels/1/2',
      hostDisplay: 'Khent', partnerMention: '<@123>',
    });
    assert.ok(post.content.includes('<@123>'));
    assert.ok(post.embeds[0].title.includes('Attack on Titan'));
    assert.ok(post.embeds[0].description.includes('S1 E5'));
    assert.equal(post.components[0].components[1].custom_id, 'end_watch');
  });
  it('omits S/E for movies', () => {
    const post = buildWatchPost({
      title: 'Dune', posterPath: '', mediaType: 'movie',
      season: null, episode: null, voiceUrl: 'https://discord.com/channels/1/2',
      hostDisplay: 'Clair', partnerMention: '<@456>',
    });
    assert.ok(!post.embeds[0].description.includes('S1'));
  });
});

describe('buildEndedPost', () => {
  it('marks ended with no buttons', () => {
    const post = buildEndedPost({ title: 'Dune', hostDisplay: 'Khent' });
    assert.ok(post.embeds[0].title.includes('Ended'));
    assert.equal(post.components.length, 0);
  });
});

const { postToWebhook } = require('../discord');

describe('postToWebhook', () => {
  it('appends wait=true and returns parsed id', async () => {
    const calls = [];
    const fakeFetch = async (url, opts) => {
      calls.push(url);
      return { ok: true, status: 200, json: async () => ({ id: 'msg1' }) };
    };
    const id = await postToWebhook({
      webhookUrl: 'https://discord.com/api/webhooks/a/b',
      payload: { content: 'hi' },
      fetchImpl: fakeFetch,
    });
    assert.equal(id, 'msg1');
    assert.ok(calls[0].includes('wait=true'));
    assert.ok(calls[0].includes('with_components=true'));
  });
});

const { isAllowedDiscordUser } = require('../discord');

describe('isAllowedDiscordUser', () => {
  it('allows only the two configured ids', () => {
    const env = { khent: '111', clair: '222' };
    assert.equal(isAllowedDiscordUser({ userId: '111', env }), true);
    assert.equal(isAllowedDiscordUser({ userId: '222', env }), true);
    assert.equal(isAllowedDiscordUser({ userId: '999', env }), false);
  });
  it('allows both Clair ids when split', () => {
    const env = { khent: '111', clair1: '222', clair2: '333' };
    assert.equal(isAllowedDiscordUser({ userId: '222', env }), true);
    assert.equal(isAllowedDiscordUser({ userId: '333', env }), true);
    assert.equal(isAllowedDiscordUser({ userId: '999', env }), false);
  });
});
