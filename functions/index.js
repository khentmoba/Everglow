//
// Everglow Cloud Functions - composition root.
// Function groups live in dedicated modules; this file imports them
// and re-exports the same names so deploy analysis + client contract
// stay unchanged.
//
'use strict';

const { onRequest } = require('firebase-functions/v2/https');
const { cappedHttps } = require('./common.js');

const {
  proxyBookText,
  proxyBookFile,
  proxyCatalog,
  proxyMangaImage,
  proxyMangaKakalotImage,
  proxyMangaKatana,
  proxyComick,
  proxyAnimeImage,
  proxyLastfmImage,
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

const { proxyAnime, proxyAnimeSegment, proxyMegavidHls } = require('./anime.js');
const { proxySpotifySearch, spotifyExchange, spotifyRefresh, spotifyCurrentlyPlaying } = require('./spotify.js');
const { verifyPasscode, bootstrapProfile } = require('./passcode.js');
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
const { agnesImage, motchiStats } = require('./motchi_image_stats.js');
exports.agnesImage = agnesImage;
exports.motchiStats = motchiStats;
const { sweepApiUsageAnomalies } = require('./usage_alerts.js');
exports.sweepApiUsageAnomalies = sweepApiUsageAnomalies;
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
// Motchi streams long SSE replies (multi-round tool calls + large HTML game
// artifacts). The 60s default truncated chess games and web-search answers
// mid-stream — no closing fence means no Preview button, and a timeout
// before any content streams means no reply at all. 300s covers slow
// generations; artifact builds get 280s end-to-end (120s for chat).
exports.proxyAI = cappedHttps(10, handleProxyAI, { timeoutSeconds: 300, memory: '512MB' });
// V2 function on Cloud Run — natively supports SSE streaming. Keeps 1 warm
// instance so Motchi replies start immediately without a 3-8s cold start.
exports.proxyAIv2 = onRequest({ invoker: 'public', minInstances: 1, maxInstances: 10, timeoutSeconds: 300, memory: '512MiB' }, handleProxyAI);

// Motchi study-set generator for Academy Solo + 1v1. Plain JSON (no
// streaming): one call per set, well inside a 90s budget.
const { handleGenerateStudySet } = require('./motchi_study.js');
exports.generateStudySet = cappedHttps(10, handleGenerateStudySet, { timeoutSeconds: 90, memory: '256MB' });

// Motchi schedules live in motchi_schedules.js.
// Re-exported at the top of this file to keep the deploy surface identical.

// Motchi stats lives in motchi_image_stats.js (see top re-exports).

// Re-exports: keep the deploy surface identical.
module.exports = Object.assign({}, module.exports, {
  proxyBookText,
  proxyBookFile,
  proxyCatalog,
  proxyMangaImage,
  proxyMangaKakalotImage,
  proxyMangaKatana,
  proxyComick,
  proxyAnimeImage,
  proxyLastfmImage,
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
  proxyMegavidHls,
  proxySpotifySearch,
  spotifyExchange,
  spotifyRefresh,
  spotifyCurrentlyPlaying,
  verifyPasscode,
  bootstrapProfile,
  onNewChatMessage,
  onNewMood,
  onNewStarDrop,
  onNewWatchlistItem,
  onNewGalleryPhoto,
  onWatchPartyInvite,
  onNewMilestone,
});

