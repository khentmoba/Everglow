'use strict';

/**
 * Pure Mochi tool contracts shared by tests and the offline eval gate.
 *
 * Mirrors the argument guards, clamps, enum fallbacks, and matching rules
 * in `index.js` (`MOCHI_TOOLS` + `executeTool`) without Firestore, fetch,
 * or secrets, so `node --test` can verify them deterministically.
 *
 * If `executeTool` gains a new guard or clamp, add it here first (and a
 * test in `test/mochi_tools.test.js`), then port it to `index.js`.
 */

const TOOL_TIMEOUT_MS = 25000;
const MAX_TOOL_ROUNDS = 8;

const TOOL_NAMES = [
  'add_to_watchlist',
  'save_to_starlight_jar',
  'set_mood',
  'search_movies',
  'get_weather',
  'create_reminder',
  'log_activity',
  'search_books',
  'get_date_ideas',
  'read_chat_messages',
  'send_sanctuary_message',
  'get_xp_stats',
  'search_anime',
  'add_book_to_our_books',
  'read_starlight_jar',
  'get_watchlist',
  'remember_fact',
  'read_memories',
  'pin_memory',
  'delete_memory',
  'edit_memory',
  'web_search',
  'read_web_page',
  'mark_watchlist_item_watched',
  'update_book_progress',
  'add_xp',
  'send_note_to_partner',
  'get_relationship_insights',
  'get_memory_trivia',
  'get_today_recap',
  'get_gallery',
  'get_garden',
  'get_canvas',
  'search_spotify',
  'remove_from_watchlist',
  'search_everglow',
  'plan_date_night',
  'add_calendar_event',
  'create_journal_entry',
  'add_bucket_item',
  'add_trip',
  'add_trip_pin',
  'log_habit',
  'complete_habit',
  'get_calendar_events',
  'get_bucket_list',
  'get_journal_entries',
  'get_trips',
];

function _text(value) {
  return String(value ?? '').trim();
}

function _numOr(value, fallback) {
  const n = Number(value);
  return Number.isNaN(n) ? fallback : n;
}

function _isValidDateString(value) {
  if (!_text(value)) return false;
  return !Number.isNaN(new Date(_text(value)).getTime());
}

function isValidHttpUrl(value) {
  return /^https?:\/\//i.test(_text(value));
}

/**
 * Argument guard mirroring the early `return { error: ... }` paths in
 * `executeTool`. Tools without an arg-level guard always validate.
 */
function validateToolArgs(toolName, args = {}) {
  const a = args && typeof args === 'object' ? args : {};
  switch (toolName) {
    case 'add_to_watchlist': {
      const title = _text(a.title);
      const tid = a.tmdb_id ?? a.tmdbId ?? null;
      if (!title && (tid === null || tid === undefined || String(tid).trim() === '')) {
        return { ok: false, error: 'No title provided' };
      }
      return { ok: true };
    }
    case 'add_book_to_our_books':
      if (!_text(a.query)) return { ok: false, error: 'No query provided' };
      return { ok: true };
    case 'remember_fact':
      if (!_text(a.fact)) return { ok: false, error: 'No fact provided' };
      return { ok: true };
    case 'send_note_to_partner':
      if (!_text(a.note)) return { ok: false, error: 'No note provided' };
      return { ok: true };
    case 'send_sanctuary_message': {
      const text = String(a.text ?? '').trim();
      if (!text) return { ok: false, error: 'No text provided' };
      if (text.length > 2000) return { ok: false, error: 'Message too long (max 2000)' };
      return { ok: true };
    }
    case 'pin_memory':
    case 'delete_memory':
      if (!_text(a.memory_id)) return { ok: false, error: 'memory_id required' };
      return { ok: true };
    case 'edit_memory': {
      if (!_text(a.memory_id) || !_text(a.fact)) {
        return { ok: false, error: 'memory_id and fact required' };
      }
      if (_text(a.fact).length > 500) {
        return { ok: false, error: 'Fact too long (max 500)' };
      }
      return { ok: true };
    }
    case 'mark_watchlist_item_watched':
    case 'update_book_progress':
      if (!_text(a.title)) return { ok: false, error: 'No title provided' };
      return { ok: true };
    case 'remove_from_watchlist': {
      const title = _text(a.title);
      const tid = a.tmdb_id ?? a.tmdbId ?? null;
      if (!title && (tid === null || tid === undefined || String(tid).trim() === '')) {
        return { ok: false, error: 'Provide title or tmdb_id' };
      }
      return { ok: true };
    }
    case 'log_habit':
    case 'add_bucket_item':
    case 'add_trip_pin':
      if (!_text(a.title)) return { ok: false, error: 'title required' };
      return { ok: true };
    case 'add_calendar_event':
      if (!_text(a.title)) return { ok: false, error: 'title required' };
      if (!_text(a.date || a.start_date)) return { ok: false, error: 'date required' };
      if (!_isValidDateString(a.date || a.start_date)) {
        return { ok: false, error: `Invalid date: ${_text(a.date || a.start_date)}` };
      }
      return { ok: true };
    case 'create_journal_entry': {
      if (!_text(a.title) || !_text(a.content)) {
        return { ok: false, error: 'title and content required' };
      }
      if (_text(a.content).length > 5000) {
        return { ok: false, error: 'content too long (max 5000)' };
      }
      return { ok: true };
    }
    case 'add_trip':
      if (!_text(a.title)) return { ok: false, error: 'title required' };
      if (!_isValidDateString(a.start_date) || !_isValidDateString(a.end_date)) {
        return { ok: false, error: 'Invalid start_date or end_date' };
      }
      return { ok: true };
    case 'search_spotify': {
      const q = _text(a.query || a.track);
      const query =
        q || (_text(a.artist) && _text(a.track) ? `${_text(a.artist)} ${_text(a.track)}` : '') ||
        _text(a.artist) || _text(a.track);
      if (!query) return { ok: false, error: 'No query provided' };
      return { ok: true };
    }
    case 'search_everglow':
    case 'web_search':
      if (!_text(a.query)) return { ok: false, error: 'No search query provided' };
      return { ok: true };
    case 'read_web_page': {
      const raw = Array.isArray(a.urls) ? a.urls : [a.urls];
      const urls = raw.map((u) => _text(u)).filter((u) => isValidHttpUrl(u)).slice(0, 3);
      if (urls.length === 0) return { ok: false, error: 'No valid http(s) URLs provided', urls };
      return { ok: true, urls };
    }
    default:
      if (!TOOL_NAMES.includes(toolName)) return { ok: false, error: `Unknown tool: ${toolName}` };
      return { ok: true };
  }
}

/** `Math.min(args.x || def, max)` clamps used by read/count tools. */
function clampWithDefault(value, def, max) {
  return Math.min(value || def, max);
}

/** `Math.min(Math.max(Number(x) || def, min), max)` bounded clamps. */
function clampBounded(value, def, min, max) {
  return Math.min(Math.max(_numOr(value, NaN) || def, min), max);
}

const clampStarlightLimit = (v) => clampWithDefault(v, 10, 25);
const clampWatchlistLimit = (v) => clampWithDefault(v, 15, 40);
const clampChatLimit = (v) => clampWithDefault(v, 20, 50);
const clampMemoriesLimit = (v) => clampWithDefault(v, 20, 50);
const clampDateIdeasCount = (v) => clampWithDefault(v, 3, 10);
const clampTriviaCount = (v) => clampWithDefault(v, 5, 10);
const clampPlanDateCount = (v) => clampWithDefault(v, 3, 5);
const clampGalleryLimit = (v) => clampBounded(v, 10, 1, 20);
const clampCalendarDays = (v) => clampBounded(v, 14, 1, 60);
const clampCalendarLimit = (v) => clampBounded(v, 10, 1, 20);
const clampBucketLimit = (v) => clampBounded(v, 10, 1, 20);
const clampJournalLimit = (v) => clampBounded(v, 5, 1, 10);
const clampTripsLimit = (v) => clampBounded(v, 5, 1, 10);
const clampBookProgress = (v) => Math.min(Math.max(_numOr(v, 0) || 0, 0), 100);
const clampXpAmount = (v) => Math.min(Math.max(_numOr(v, 10) || 10, 1), 100);

/** Enum fallbacks mirroring `executeTool` (unknown -> default). */
function normalizeHabitCategory(v) {
  return ['health', 'fitness', 'mindfulness', 'learning', 'social', 'other'].includes(String(v || ''))
    ? String(v)
    : 'health';
}
function normalizeHabitFrequency(v) {
  return ['daily', 'weekly', 'custom'].includes(String(v || '')) ? String(v) : 'daily';
}
function normalizeCalendarType(v) {
  return ['dateNight', 'anniversary', 'reminder', 'custom'].includes(String(v || ''))
    ? String(v)
    : 'custom';
}
function normalizeJournalCategory(v) {
  return ['daily', 'gratitude', 'memory', 'letter', 'dream', 'idea'].includes(String(v || ''))
    ? String(v)
    : 'daily';
}
function normalizeBucketCategory(v) {
  return ['travel', 'experience', 'food', 'adventure', 'milestone', 'other'].includes(String(v || ''))
    ? String(v)
    : 'other';
}
function normalizeBucketPriority(v) {
  return ['low', 'medium', 'high', 'urgent'].includes(String(v || '')) ? String(v) : 'medium';
}
function normalizeTripPinCategory(v) {
  return ['stay', 'eat', 'sight', 'activity', 'transit'].includes(String(v || ''))
    ? String(v)
    : 'sight';
}
function normalizeActivityCategory(v) {
  const allowed = ['date', 'gaming', 'movie', 'music', 'food', 'travel', 'other'];
  return allowed.includes(String(v || '')) ? String(v) : 'other';
}

/**
 * Case-insensitive substring match either direction, mirroring the
 * watchlist/book title lookups in `executeTool`.
 */
function titlesMatch(a, b) {
  const x = _text(a).toLowerCase();
  const y = _text(b).toLowerCase();
  if (!x || !y) return false;
  return x.includes(y) || y.includes(x);
}

/**
 * Disambiguation rule from `add_to_watchlist` / `add_book_to_our_books`:
 * no exact (case-insensitive) match and >= 2 substring candidates.
 */
function needsConfirmation(query, titles) {
  const q = _text(query).toLowerCase();
  if (!q || !Array.isArray(titles) || titles.length === 0) return false;
  const lower = titles.map((t) => _text(t).toLowerCase()).filter(Boolean);
  if (lower.some((t) => t === q)) return false;
  const subs = lower.filter((t) => t.includes(q) || q.includes(t)).slice(0, 3);
  return subs.length >= 2;
}

/**
 * Whether `create_reminder` would store a usable `remindAtTs`
 * (ISO date or a "tomorrow …" relative phrase).
 */
function isReminderSchedulable(raw) {
  const text = _text(raw);
  if (!text) return false;
  if (!Number.isNaN(new Date(text).getTime())) return true;
  return /tomorrow/i.test(text);
}

module.exports = {
  TOOL_TIMEOUT_MS,
  MAX_TOOL_ROUNDS,
  TOOL_NAMES,
  validateToolArgs,
  isValidHttpUrl,
  clampWithDefault,
  clampBounded,
  clampStarlightLimit,
  clampWatchlistLimit,
  clampChatLimit,
  clampMemoriesLimit,
  clampDateIdeasCount,
  clampTriviaCount,
  clampPlanDateCount,
  clampGalleryLimit,
  clampCalendarDays,
  clampCalendarLimit,
  clampBucketLimit,
  clampJournalLimit,
  clampTripsLimit,
  clampBookProgress,
  clampXpAmount,
  normalizeHabitCategory,
  normalizeHabitFrequency,
  normalizeCalendarType,
  normalizeJournalCategory,
  normalizeBucketCategory,
  normalizeBucketPriority,
  normalizeTripPinCategory,
  normalizeActivityCategory,
  titlesMatch,
  needsConfirmation,
  isReminderSchedulable,
};
