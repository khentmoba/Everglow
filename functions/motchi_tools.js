'use strict';

/**
 * Pure Motchi tool contracts shared by tests and the offline eval gate.
 *
 * Mirrors the argument guards, clamps, enum fallbacks, and matching rules
 * in `index.js` (`MOTCHI_TOOLS` + `executeTool`) without Firestore, fetch,
 * or secrets, so `node --test` can verify them deterministically.
 *
 * If `executeTool` gains a new guard or clamp, add it here first (and a
 * test in `test/motchi_tools.test.js`), then port it to `index.js`.
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
  'list_reminders',
  'cancel_reminder',
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
  'search_journal_entries',
  'read_journal_entry',
  'get_trips',
  'edit_journal_entry',
  'delete_journal_entry',
  'update_calendar_event',
  'delete_calendar_event',
  'complete_bucket_item',
  'delete_bucket_item',
  'browse_web',
];

// ── Intent-based tool routing ─────────────────────────────────────
// Sends Motchi only the tools that match the message intent instead of
// every schema every turn. Saves input tokens on every request and
// cuts mistaken tool calls. Guaranteed by tests: every eval case's
// expectedTools must be a subset of selectToolNames(message), and every
// known tool must stay reachable from core + groups.

// Always available: memory writes, mood, recap, web, XP, activity.
const CORE_TOOLS = [
  'set_mood',
  'save_to_starlight_jar',
  'remember_fact',
  'read_memories',
  'get_today_recap',
  'web_search',
  'read_web_page',
  'browse_web',
  'add_xp',
  'log_activity',
];

// Read-only lookups, added only when no intent group matches, so plain
// chat can still inspect the shared spaces.
const AWARENESS_TOOLS = [
  'read_chat_messages',
  'get_watchlist',
  'read_starlight_jar',
  'get_garden',
  'get_gallery',
  'get_calendar_events',
];

// Intent groups: keyword pattern plus the tools that intent needs. All
// matching groups merge. Keywords stay generous — a spurious group
// costs ~3 tools, a missed group costs a failed request.
const TOOL_GROUPS = [
  {
    match: /movie|film|cinema|watchlist|watched|\bwatch\b|\btv\b|shows|series|episode|tmdb|netflix|k-?drama/i,
    tools: ['add_to_watchlist', 'search_movies', 'get_watchlist', 'mark_watchlist_item_watched', 'remove_from_watchlist'],
  },
  {
    match: /\bbook\b|books|\bread\b|reading|author|novel|chapter|percent|progress|\blibrary\b/i,
    tools: ['search_books', 'add_book_to_our_books', 'update_book_progress'],
  },
  {
    match: /anime|manga|jikan|myanimelist/i,
    tools: ['search_anime'],
  },
  {
    match: /music|song|spotify|playlist|\bplay\b|artist|album|\btrack\b|listen|karaoke|jukebox/i,
    tools: ['search_spotify'],
  },
  {
    match: /chat|sanctuary|said|\bsay\b|\btell\b|relay|messaged|convo/i,
    tools: ['read_chat_messages', 'send_sanctuary_message', 'send_note_to_partner'],
  },
  {
    match: /starlight|\bjar\b|grateful|gratitude|thankful|\bnotes?\b/i,
    tools: ['read_starlight_jar'],
  },
  {
    match: /\bmoods?\b|feeling|\bfeel\b|felt|emotion|happy|sad|stressed|tired|excited|anxious|lonely/i,
    tools: ['get_relationship_insights'],
  },
  {
    match: /memor|remember|forget|trivia|\bquiz\b/i,
    tools: ['pin_memory', 'edit_memory', 'delete_memory', 'get_memory_trivia'],
  },
  {
    match: /\bdates?\b|dating|anniversary|romantic|date night|datenight|\bideas?\b/i,
    tools: ['get_date_ideas', 'plan_date_night'],
  },
  {
    match: /weather|rain|sunny|forecast|temperature|storm|typhoon/i,
    tools: ['get_weather', 'plan_date_night'],
  },
  {
    match: /remind|reminder|alarm|\bnotify\b/i,
    tools: ['create_reminder', 'list_reminders', 'cancel_reminder'],
  },
  {
    match: /calendar|schedul|coming up|upcoming|this month|this week|tomorrow|\bevents?\b|appointment|deadline|reschedul|postpon/i,
    tools: ['add_calendar_event', 'get_calendar_events', 'update_calendar_event', 'delete_calendar_event'],
  },
  {
    match: /journal|diar|reflect|\bentr(?:y|ies)\b|letter|rewrite/i,
    tools: ['create_journal_entry', 'get_journal_entries', 'search_journal_entries', 'read_journal_entry', 'edit_journal_entry', 'delete_journal_entry'],
  },
  {
    match: /bucket|\bdreams?\b|\bwish(?:es)?\b|\bgoals?\b|\bcomplet\w*\b|\bfinish\w*\b/i,
    tools: ['add_bucket_item', 'get_bucket_list', 'complete_bucket_item', 'delete_bucket_item'],
  },
  {
    match: /\btrips?\b|travel|vacation|getaway|itinerary|flight|hotel/i,
    tools: ['add_trip', 'add_trip_pin', 'get_trips'],
  },
  {
    match: /habit|streak|workout|\bgym\b|routine/i,
    tools: ['log_habit', 'complete_habit'],
  },
  {
    match: /photos?|pictures?|gallery|selfie|\bimages?\b/i,
    tools: ['get_gallery'],
  },
  {
    match: /garden|plants?|flowers?|lily|lilies|bloom/i,
    tools: ['get_garden'],
  },
  {
    match: /draw|canvas|\bart\b|sketch|paint/i,
    tools: ['get_canvas'],
  },
  {
    match: /\bxp\b|\blevels?\b|achievement|\branks?\b/i,
    tools: ['get_xp_stats'],
  },
  {
    match: /recommend|suggest|discover|\bfind\b|looking for|any good/i,
    tools: ['search_everglow'],
  },
  {
    match: /\bplan\b|planning|surprise|organize/i,
    tools: ['plan_date_night', 'search_everglow'],
  },
];

/** Tool names for a message: core + every matching intent group. */
function selectToolNames(message, prevAssistantText = '') {
  const text = String(message || '');
  const picked = new Set(CORE_TOOLS);
  // Follow-through first: a bare yes to an offered plan keeps the
  // write tools (normal keyword routing would starve it).
  if (isBareYes(text) && hasOffer(prevAssistantText)) {
    for (const name of FOLLOW_THROUGH_TOOLS) picked.add(name);
    return [...picked];
  }
  let matched = 0;
  for (const group of TOOL_GROUPS) {
    let hit = false;
    try {
      hit = group.match.test(text);
    } catch (_) {
      hit = false;
    }
    if (hit) {
      matched++;
      for (const name of group.tools) picked.add(name);
    }
  }
  if (matched === 0) {
    for (const name of AWARENESS_TOOLS) picked.add(name);
  }
  return [...picked];
}

/**
 * Markdown block naming the tools attached to this request. Names only —
 * full descriptions already ride with the schemas, so repeating them
 * would just burn tokens. The fallback persona embeds this per request
 * so the prompt never advertises tools that were routed out.
 */
function toolListSection(toolNames) {
  const names = [...new Set((toolNames || []).filter((n) => typeof n === 'string' && n))];
  if (names.length === 0) {
    return 'No tools are attached to this request — answer directly from context and memory, without calling anything.';
  }
  return `You have access to these custom tools right now (and no others):\n${names.map((n) => `- ${n}`).join('\n')}`;
}

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
    case 'read_journal_entry': {
      const id = _text(a.id || a.entry_id || a.entryId);
      const title = _text(a.title);
      if (!id && !title) return { ok: false, error: 'id or title required' };
      return { ok: true };
    }
    case 'search_journal_entries':
      return { ok: true };
    case 'cancel_reminder': {
      if (!_text(a.id || a.reminder_id) && !_text(a.title)) {
        return { ok: false, error: 'id or title required' };
      }
      return { ok: true };
    }
    case 'edit_journal_entry': {
      if (!_text(a.id || a.entry_id) && !_text(a.title)) {
        return { ok: false, error: 'id or title required' };
      }
      if (a.content !== undefined && _text(a.content).length > 5000) {
        return { ok: false, error: 'content too long (max 5000)' };
      }
      return { ok: true };
    }
    case 'delete_journal_entry':
    case 'delete_calendar_event':
    case 'delete_bucket_item':
      if (!_text(a.id) && !_text(a.title)) return { ok: false, error: 'id or title required' };
      return { ok: true };
    case 'update_calendar_event': {
      if (!_text(a.id) && !_text(a.title)) return { ok: false, error: 'id or title required' };
      const d = a.date || a.start_date;
      if (d !== undefined && !_isValidDateString(d)) {
        return { ok: false, error: `Invalid date: ${_text(d)}` };
      }
      return { ok: true };
    }
    case 'complete_bucket_item':
      if (!_text(a.id) && !_text(a.title)) return { ok: false, error: 'id or title required' };
      return { ok: true };
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
    case 'browse_web': {
      // Resume path needs only the run_id from a RUNNING result.
      if (_text(a.run_id)) return { ok: true };
      if (!isValidHttpUrl(a.url)) return { ok: false, error: 'No valid http(s) URL provided' };
      if (!_text(a.goal)) return { ok: false, error: 'No goal provided' };
      if (_text(a.goal).length > 2000) return { ok: false, error: 'Goal too long (max 2000)' };
      return { ok: true };
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
const clampSearchJournalLimit = (v) => clampBounded(v, 5, 1, 20);
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
 * Whether `create_reminder` would store a usable `remindAtTs`.
 * Mirrors the executor by delegating to the shared date parser.
 */
function isReminderSchedulable(raw, nowMs = Date.now()) {
  const text = _text(raw);
  if (!text) return false;
  try {
    // eslint-disable-next-line global-require
    const { parseReminderDate } = require('./motchi_core.js');
    return parseReminderDate(text, nowMs) !== null;
  } catch (_) {
    if (!Number.isNaN(new Date(text).getTime())) return true;
    return /tomorrow/i.test(text);
  }
}

// ── Fast-path single-tool intents ─────────────────────────────────
// Zero-arg, read-only asks whose tool result IS the answer. When the
// whole message matches, the chat handler pre-executes the tool and
// lets the model answer from the result with no tools attached — one
// Firestore read + one LLM call instead of ~7 block reads + memory
// select + a tool loop. Deliberately narrow: anchored patterns,
// conjunction + multi-sentence + length guards reject anything
// compound, which falls through to the normal loop. Trivia is NOT
// here on purpose: "quiz us" deserves the interactive canvas, not
// a text answer.
const FAST_PATH_INTENTS = [
  {
    match: /^(what('s| is) (our|my|the) (level|xp|rank)|what level are we( on| at)?|show (our|my|the) (level|xp|rank)|how much xp do (we|i) have)[?!\s.]*$/i,
    tool: 'get_xp_stats',
  },
  {
    match: /^give (us|me) (today's|todays) recap[?!\s.]*$/i,
    tool: 'get_today_recap',
  },
  {
    match: /^(today's|todays) recap[?!\s.]*$|^recap (of |for )?today[?!\s.]*$/i,
    tool: 'get_today_recap',
  },
  {
    match: /^(list|show|what are) (my|our|all|the) reminders[?!\s.]*$/i,
    tool: 'list_reminders',
  },
  {
    match: /^what patterns do you see in our moods[?!\s.]*$/i,
    tool: 'get_relationship_insights',
  },
];

const FAST_PATH_BLOCKERS = /\b(and|then|also|plus|after that|followed by|before that)\b|[;+]|\n/i;

// ── Plan follow-through ─────────────────────────────────────────
// When Motchi presents a plan with an offer ("want me to add this to
// the calendar?"), a bare yes means EXECUTE — but "yes" carries no
// keywords, so normal routing would send core tools only and the model
// couldn't act. With the previous assistant text showing an offer, a
// bare affirmation keeps the write tools its plan may need.
const FOLLOW_THROUGH_TOOLS = [
  'add_calendar_event',
  'update_calendar_event',
  'get_calendar_events',
  'create_reminder',
  'list_reminders',
  'add_bucket_item',
  'create_journal_entry',
  'add_trip',
  'log_habit',
  'add_to_watchlist',
  'send_sanctuary_message',
  'send_note_to_partner',
];

const BARE_YES_RE = /^(yes|yeah|yep|yup|sure|ok|okay|do it|go ahead|please do|sounds good|perfect|yes please|yes do it|yeah do it|ok do it|let'?s do it)[!.,\s]*$/i;
const BARE_YES_BLOCKERS = /\b(and|but|also|then|plus|except|instead|later)\b/i;
const OFFER_MARKERS_RE = /calendar|schedul|remind|bucket|journal|trip|habit|watchlist|sanctuary|tell (her|him|them|clair|khent)|shall i|want me to|should i|i('ll| can) (add|create|save|book|plan|schedule|remind|send)/i;

function isBareYes(message) {
  const text = String(message || '').trim();
  if (!text || text.length > 40) return false;
  if (BARE_YES_BLOCKERS.test(text)) return false;
  return BARE_YES_RE.test(text);
}

function hasOffer(prevAssistantText) {
  return OFFER_MARKERS_RE.test(String(prevAssistantText || ''));
}

/** Whole-message fast-path match, or null to use the normal loop. */
function matchFastPath(message) {
  const text = String(message || '').trim();
  if (!text || text.length > 120) return null;
  if (FAST_PATH_BLOCKERS.test(text)) return null;
  // A second sentence means a second ask.
  if (/[.!?]\s*[A-Za-z]/.test(text)) return null;
  for (const intent of FAST_PATH_INTENTS) {
    if (intent.match.test(text)) return { tool: intent.tool, args: {} };
  }
  return null;
}

module.exports = {
  TOOL_TIMEOUT_MS,
  MAX_TOOL_ROUNDS,
  TOOL_NAMES,
  FAST_PATH_INTENTS,
  matchFastPath,
  FOLLOW_THROUGH_TOOLS,
  isBareYes,
  hasOffer,
  CORE_TOOLS,
  AWARENESS_TOOLS,
  TOOL_GROUPS,
  selectToolNames,
  toolListSection,
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
  clampSearchJournalLimit,
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
