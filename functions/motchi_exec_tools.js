'use strict';

/* Motchi tool dispatcher — moved verbatim from motchi_chat.js
 * executeTool() (mechanical split, no behavior change).
 *
 * Per-domain executors live in motchi_exec_{media,memory,social,planning,
 * insights}.js. Shared services ride on ctx so executors stay pure
 * (ctx, args) => JSON string functions that unit tests can call with
 * stub services.
 *
 * Two small behavior hardenings vs the old inline switch:
 * - validateToolArgs gates every call (it was defined + tested but never
 *   wired in). Malformed calls fail fast with an explicit error instead
 *   of running with junk args.
 * - TOOL_TIMEOUT_MS / MAX_TOOL_ROUNDS come from motchi_tools.js
 *   (single source; the chat.js duplicates are gone).
 */

const functions = require('firebase-functions/v1');

const {
  getAdmin,
  _getExternalCache,
  _setExternalCache,
  _EXTERNAL_CACHE_TTLS,
} = require('./common.js');
const { sendFCMToUser } = require('./triggers.js');
const { getTmdbKey } = require('./motchi_context.js');
const { phtDateString } = require('./motchi_core.js');
const { validateToolArgs, TOOL_TIMEOUT_MS } = require('./motchi_tools.js');

const {
  exec_add_to_watchlist,
  exec_search_movies,
  exec_get_watchlist,
  exec_mark_watchlist_item_watched,
  exec_remove_from_watchlist,
  exec_search_anime,
  exec_search_books,
  exec_add_book_to_our_books,
  exec_update_book_progress,
  exec_search_spotify,
} = require('./motchi_exec_media.js');
const {
  exec_remember_fact,
  exec_read_memories,
  exec_pin_memory,
  exec_delete_memory,
  exec_edit_memory,
  exec_save_to_starlight_jar,
  exec_read_starlight_jar,
  exec_create_journal_entry,
  exec_get_journal_entries,
  exec_search_journal_entries,
  exec_read_journal_entry,
  exec_edit_journal_entry,
  exec_delete_journal_entry,
} = require('./motchi_exec_memory.js');
const {
  exec_set_mood,
  exec_read_chat_messages,
  exec_send_sanctuary_message,
  exec_send_note_to_partner,
  exec_get_xp_stats,
  exec_add_xp,
  exec_log_activity,
  exec_get_gallery,
  exec_get_garden,
  exec_get_canvas,
} = require('./motchi_exec_social.js');
const {
  exec_create_reminder,
  exec_list_reminders,
  exec_cancel_reminder,
  exec_add_calendar_event,
  exec_get_calendar_events,
  exec_update_calendar_event,
  exec_delete_calendar_event,
  exec_add_bucket_item,
  exec_get_bucket_list,
  exec_complete_bucket_item,
  exec_delete_bucket_item,
  exec_add_trip,
  exec_add_trip_pin,
  exec_get_trips,
  exec_log_habit,
  exec_complete_habit,
  exec_plan_date_night,
  exec_get_date_ideas,
  exec_get_weather,
} = require('./motchi_exec_planning.js');
const {
  exec_get_relationship_insights,
  exec_get_memory_trivia,
  exec_get_today_recap,
  exec_search_everglow,
  exec_web_search,
  exec_read_web_page,
} = require('./motchi_exec_insights.js');

// ── XP curve (200 XP per level) ──────────────────────────
// Mirrors lib/features/xp/domain/models/user_progress.dart so Motchi,
// the client, and the progress bar always agree on the level.
// Level math: level = floor(xp / 200) + 1.
const XP_PER_LEVEL = 200;
function levelForXp(xpTotal) {
  const xp = Number(xpTotal) || 0;
  if (xp <= 0) return 1;
  return Math.floor(xp / XP_PER_LEVEL) + 1;
}

function _getSpotifyCreds() {
  const id = (process.env.SPOTIFY_CLIENT_ID || "").trim() || (functions.config().spotify && functions.config().spotify.client_id) || "";
  const secret = (process.env.SPOTIFY_CLIENT_SECRET || "").trim() || (functions.config().spotify && functions.config().spotify.client_secret) || "";
  return { id, secret };
}
let _spotifyTokenCache = null;
async function _getSpotifyAppToken() {
  const { id, secret } = _getSpotifyCreds();
  if (!id || !secret) return null;
  if (_spotifyTokenCache && Date.now() < _spotifyTokenCache.expiresAt - 60000) return _spotifyTokenCache.token;
  const basic = Buffer.from(id + ":" + secret).toString("base64");
  const res = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: { "Authorization": "Basic " + basic, "Content-Type": "application/x-www-form-urlencoded" },
    body: "grant_type=client_credentials",
    signal: AbortSignal.timeout(10000),
  });
  if (!res.ok) { console.warn("[spotify] token error", res.status, await res.text().catch(()=>"" )); return null; }
  const data = await res.json();
  _spotifyTokenCache = { token: data.access_token, expiresAt: Date.now() + (data.expires_in * 1000) };
  return data.access_token;
}

/** Shared services for executors. Pass stubs in tests. */
function createToolCtx({ callerUid, caller } = {}) {
  const admin = getAdmin();
  return {
    admin,
    db: admin.firestore(),
    callerUid,
    caller,
    levelForXp,
    phtDateString,
    getTmdbKey,
    sendFCMToUser,
    getSpotifyAppToken: _getSpotifyAppToken,
    cacheGet: _getExternalCache,
    cacheSet: _setExternalCache,
    cacheTTLs: _EXTERNAL_CACHE_TTLS,
  };
}

const TOOL_EXECUTORS = {
  add_to_watchlist: exec_add_to_watchlist,
  search_movies: exec_search_movies,
  get_watchlist: exec_get_watchlist,
  mark_watchlist_item_watched: exec_mark_watchlist_item_watched,
  remove_from_watchlist: exec_remove_from_watchlist,
  search_anime: exec_search_anime,
  search_books: exec_search_books,
  add_book_to_our_books: exec_add_book_to_our_books,
  update_book_progress: exec_update_book_progress,
  search_spotify: exec_search_spotify,
  remember_fact: exec_remember_fact,
  read_memories: exec_read_memories,
  pin_memory: exec_pin_memory,
  delete_memory: exec_delete_memory,
  edit_memory: exec_edit_memory,
  save_to_starlight_jar: exec_save_to_starlight_jar,
  read_starlight_jar: exec_read_starlight_jar,
  create_journal_entry: exec_create_journal_entry,
  get_journal_entries: exec_get_journal_entries,
  search_journal_entries: exec_search_journal_entries,
  read_journal_entry: exec_read_journal_entry,
  edit_journal_entry: exec_edit_journal_entry,
  delete_journal_entry: exec_delete_journal_entry,
  set_mood: exec_set_mood,
  read_chat_messages: exec_read_chat_messages,
  send_sanctuary_message: exec_send_sanctuary_message,
  send_note_to_partner: exec_send_note_to_partner,
  get_xp_stats: exec_get_xp_stats,
  add_xp: exec_add_xp,
  log_activity: exec_log_activity,
  get_gallery: exec_get_gallery,
  get_garden: exec_get_garden,
  get_canvas: exec_get_canvas,
  create_reminder: exec_create_reminder,
  list_reminders: exec_list_reminders,
  cancel_reminder: exec_cancel_reminder,
  add_calendar_event: exec_add_calendar_event,
  get_calendar_events: exec_get_calendar_events,
  update_calendar_event: exec_update_calendar_event,
  delete_calendar_event: exec_delete_calendar_event,
  add_bucket_item: exec_add_bucket_item,
  get_bucket_list: exec_get_bucket_list,
  complete_bucket_item: exec_complete_bucket_item,
  delete_bucket_item: exec_delete_bucket_item,
  add_trip: exec_add_trip,
  add_trip_pin: exec_add_trip_pin,
  get_trips: exec_get_trips,
  log_habit: exec_log_habit,
  complete_habit: exec_complete_habit,
  plan_date_night: exec_plan_date_night,
  get_date_ideas: exec_get_date_ideas,
  get_weather: exec_get_weather,
  get_relationship_insights: exec_get_relationship_insights,
  get_memory_trivia: exec_get_memory_trivia,
  get_today_recap: exec_get_today_recap,
  search_everglow: exec_search_everglow,
  web_search: exec_web_search,
  read_web_page: exec_read_web_page,
};

const _timeout = (ms) =>
  new Promise((_, reject) => {
    const t = setTimeout(() => reject(new Error('Tool timeout')), ms);
    // Don't hold the event loop: when the executor wins the race this
    // timer is dead weight (in production the request holds the loop;
    // in tests an unref'd timer delayed process exit by the full 25s).
    if (typeof t.unref === 'function') t.unref();
  });

// Max gallery thumbnails attached as vision input per tool round.
// Each image costs vision tokens, so the executor caps its side at 3
// and the loop caps the merged total here too.
const VISION_IMAGES_PER_ROUND = 3;

/**
 * Builds a user message carrying tool-result images (OpenAI-style
 * image_url parts) for the next model call, or null when no tool
 * returned any. Pure — takes the FULL (untrimmed) result strings.
 */
function visionMessageForResults(fullResults) {
  const urls = [];
  for (const r of fullResults || []) {
    try {
      const p = typeof r === 'string' ? JSON.parse(r) : r;
      if (!p || !Array.isArray(p.vision_images)) continue;
      for (const v of p.vision_images) {
        if (v && v.url && urls.length < VISION_IMAGES_PER_ROUND) urls.push(v.url);
      }
    } catch (_) {}
  }
  if (urls.length === 0) return null;
  return {
    role: 'user',
    content: [
      { type: 'text', text: '[Gallery photos attached for your question above — describe or reference what you actually see in them.]' },
      ...urls.map((url) => ({ type: 'image_url', image_url: { url } })),
    ],
  };
}

/** Validated, time-boxed tool call. Always resolves to a JSON string. */
async function executeToolCall(ctx, toolName, args) {
  const v = validateToolArgs(toolName, args);
  if (!v.ok) return JSON.stringify({ error: v.error || 'Invalid tool args' });
  const fn = TOOL_EXECUTORS[toolName];
  if (!fn) return JSON.stringify({ error: `Unknown tool: ${toolName}` });
  try {
    return await Promise.race([fn(ctx, args || {}), _timeout(TOOL_TIMEOUT_MS)]);
  } catch (e) {
    return JSON.stringify({ error: (e && e.message) || 'Tool execution failed' });
  }
}

module.exports = {
  createToolCtx,
  executeToolCall,
  visionMessageForResults,
  VISION_IMAGES_PER_ROUND,
  TOOL_EXECUTORS,
  levelForXp,
  XP_PER_LEVEL,
};
