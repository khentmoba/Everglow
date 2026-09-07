//
// Everglow Cloud Functions - composition root.
// Function groups live in dedicated modules; this file imports them
// and re-exports the same names so deploy analysis + client contract
// stay unchanged.
//
'use strict';

const functions = require('firebase-functions/v1');
const { onRequest } = require('firebase-functions/v2/https');

const {
  proxyBookText,
  proxyMangaImage,
  proxyMangaKakalotImage,
  proxyMangaKatana,
  proxyComick,
  proxyAnimeImage,
  proxyGalleryImage,
  cleanupGallery,
  deleteGalleryPhoto,
  proxyScanlation,
  proxyFetchHtml,
  proxyEmbed,
  proxyMangaDex,
  proxyVideoStream,
  proxyWatchStream,
} = require('./media_proxies.js');

const {
  onNewChatMessage,
  onNewMood,
  onNewStarDrop,
  onNewWatchlistItem,
  onNewGalleryPhoto,
  onWatchPartyInvite,
  onNewMilestone,
} = require('./triggers.js');

const { proxySpotifySearch, spotifyExchange, spotifyRefresh, spotifyCurrentlyPlaying, spotifyClientId } = require('./spotify.js');
const { verifyPasscode } = require('./passcode.js');
const { health, sweepStalePresence } = require('./system_functions.js');
exports.health = health;
exports.sweepStalePresence = sweepStalePresence;
const { proxyTmdb, proxyLastfm } = require('./catalog.js');
exports.proxyTmdb = proxyTmdb;
exports.proxyLastfm = proxyLastfm;
const { notifyDiscordWatch, discordInteractions, sweepStaleDiscordWatch } = require('./discord_functions.js');
exports.notifyDiscordWatch = notifyDiscordWatch;
exports.discordInteractions = discordInteractions;
exports.sweepStaleDiscordWatch = sweepStaleDiscordWatch;
const { agnesImage, mochiStats } = require('./mochi_image_stats.js');
exports.agnesImage = agnesImage;
exports.mochiStats = mochiStats;
const {
  mochiDailyDigest,
  mochiNightRecap,
  mochiMoodCheckIn,
  mochiSmartNudge,
  mochiWeeklyRecap,
  mochiSpecialDayNudge,
  mochiReminderChecker,
  mochiMemorySweep,
} = require('./mochi_schedules.js');
exports.mochiDailyDigest = mochiDailyDigest;
exports.mochiNightRecap = mochiNightRecap;
exports.mochiMoodCheckIn = mochiMoodCheckIn;
exports.mochiSmartNudge = mochiSmartNudge;
exports.mochiWeeklyRecap = mochiWeeklyRecap;
exports.mochiSpecialDayNudge = mochiSpecialDayNudge;
exports.mochiReminderChecker = mochiReminderChecker;
exports.mochiMemorySweep = mochiMemorySweep;
const { handleProxyAI } = require('./mochi_chat.js');
exports.proxyAI = functions.https.onRequest(handleProxyAI);
// V2 function on Cloud Run — natively supports SSE streaming.
exports.proxyAIv2 = onRequest({ invoker: 'public' }, handleProxyAI);

// Mochi schedules live in mochi_schedules.js.
// Re-exported at the top of this file to keep the deploy surface identical.

// Mochi stats lives in mochi_image_stats.js (see top re-exports).

// Re-exports: keep the deploy surface identical.
module.exports = Object.assign({}, module.exports, {
  proxyBookText,
  proxyMangaImage,
  proxyMangaKakalotImage,
  proxyMangaKatana,
  proxyComick,
  proxyAnimeImage,
  proxyGalleryImage,
  cleanupGallery,
  deleteGalleryPhoto,
  proxyScanlation,
  proxyFetchHtml,
  proxyEmbed,
  proxyMangaDex,
  proxyVideoStream,
  proxyWatchStream,
  proxySpotifySearch,
  spotifyExchange,
  spotifyRefresh,
  spotifyCurrentlyPlaying,
  spotifyClientId,
  verifyPasscode,
  onNewChatMessage,
  onNewMood,
  onNewStarDrop,
  onNewWatchlistItem,
  onNewGalleryPhoto,
  onWatchPartyInvite,
  onNewMilestone,
});

