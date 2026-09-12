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
  proxyCatalog,
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

const { proxyAnime, proxyAnimeSegment } = require('./anime.js');
const { proxySpotifySearch, spotifyExchange, spotifyRefresh, spotifyCurrentlyPlaying } = require('./spotify.js');
const { verifyPasscode } = require('./passcode.js');
const { health, sweepStalePresence, keepAnivexaWarm } = require('./system_functions.js');
exports.health = health;
exports.sweepStalePresence = sweepStalePresence;
exports.keepAnivexaWarm = keepAnivexaWarm;
const { proxyTmdb, proxyLastfm } = require('./catalog.js');
exports.proxyTmdb = proxyTmdb;
exports.proxyLastfm = proxyLastfm;
const { notifyDiscordWatch, discordInteractions, sweepStaleDiscordWatch } = require('./discord_functions.js');
exports.notifyDiscordWatch = notifyDiscordWatch;
exports.discordInteractions = discordInteractions;
exports.sweepStaleDiscordWatch = sweepStaleDiscordWatch;
const { agnesImage, motchiStats } = require('./motchi_image_stats.js');
exports.agnesImage = agnesImage;
exports.motchiStats = motchiStats;
const {
  motchiDailyDigest,
  motchiNightRecap,
  motchiMoodCheckIn,
  motchiSmartNudge,
  motchiWeeklyRecap,
  motchiSpecialDayNudge,
  motchiReminderChecker,
  motchiMemorySweep,
} = require('./motchi_schedules.js');
exports.motchiDailyDigest = motchiDailyDigest;
exports.motchiNightRecap = motchiNightRecap;
exports.motchiMoodCheckIn = motchiMoodCheckIn;
exports.motchiSmartNudge = motchiSmartNudge;
exports.motchiWeeklyRecap = motchiWeeklyRecap;
exports.motchiSpecialDayNudge = motchiSpecialDayNudge;
exports.motchiReminderChecker = motchiReminderChecker;
exports.motchiMemorySweep = motchiMemorySweep;
const { handleProxyAI } = require('./motchi_chat.js');
exports.proxyAI = functions.https.onRequest(handleProxyAI);
// V2 function on Cloud Run — natively supports SSE streaming.
exports.proxyAIv2 = onRequest({ invoker: 'public' }, handleProxyAI);

// Motchi schedules live in motchi_schedules.js.
// Re-exported at the top of this file to keep the deploy surface identical.

// Motchi stats lives in motchi_image_stats.js (see top re-exports).

// Re-exports: keep the deploy surface identical.
module.exports = Object.assign({}, module.exports, {
  proxyBookText,
  proxyCatalog,
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
  proxyAnime,
  proxyAnimeSegment,
  proxySpotifySearch,
  spotifyExchange,
  spotifyRefresh,
  spotifyCurrentlyPlaying,
  verifyPasscode,
  onNewChatMessage,
  onNewMood,
  onNewStarDrop,
  onNewWatchlistItem,
  onNewGalleryPhoto,
  onWatchPartyInvite,
  onNewMilestone,
});

