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
