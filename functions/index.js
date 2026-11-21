'use strict';

const { onRequest } = require('firebase-functions/v2/https');
const { cappedHttps } = require('./common.js');

const { proxyBookText, proxyBookFile } = require('./media_proxy_books.js');
const {
  proxyMangaImage,
  proxyMangaKakalotImage,
  proxyMangaKatana,
  proxyComick,
  proxyMangaDex,
} = require('./media_proxy_manga.js');
const { proxyAnimeImage } = require('./media_proxy_anime.js');
const { proxyLastfmImage } = require('./media_proxy_music.js');
const {
  proxyGalleryImage,
  cleanupGallery,
  deleteGalleryPhoto,
} = require('./media_proxy_gallery.js');
const {
  proxyScanlation,
  proxyFetchHtml,
} = require('./media_proxy_html.js');
const { proxyWatchStream } = require('./media_proxy_video.js');
const { proxyCatalog } = require('./media_proxy_catalog.js');

const {
  onNewChatMessage,
  onNewMood,
  onNewStarDrop,
  onNewWatchlistItem,
  onNewGalleryPhoto,
  onNewMilestone,
} = require('./triggers.js');

const { proxyAnime, proxyAnimeSegment, proxyMegavidHls } = require('./anime.js');
const { proxySpotifySearch, spotifyExchange, spotifyRefresh, spotifyCurrentlyPlaying } = require('./spotify.js');
const { verifyPasscode } = require('./passcode.js');
const { registerAccount, loginAccount, manageAccounts, communityWatchPartyAccess } = require('./accounts.js');
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
const { motchiStats } = require('./motchi_stats.js');
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
exports.proxyAI = cappedHttps(10, handleProxyAI, { timeoutSeconds: 300, memory: '512MB' });
exports.proxyAIv2 = onRequest({ invoker: 'public', minInstances: 0, maxInstances: 10, timeoutSeconds: 300, memory: '512MiB' }, handleProxyAI);

const { handleGenerateStudySet } = require('./motchi_study.js');
exports.generateStudySet = cappedHttps(10, handleGenerateStudySet, { timeoutSeconds: 90, memory: '256MB' });

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
  proxyMangaDex,
  proxyWatchStream,
  proxyAnime,
  proxyAnimeSegment,
  proxyMegavidHls,
  proxySpotifySearch,
  spotifyExchange,
  spotifyRefresh,
  spotifyCurrentlyPlaying,
  verifyPasscode,
  registerAccount,
  loginAccount,
  manageAccounts,
  communityWatchPartyAccess,
  onNewChatMessage,
  onNewMood,
  onNewStarDrop,
  onNewWatchlistItem,
  onNewGalleryPhoto,
  onNewMilestone,
});

