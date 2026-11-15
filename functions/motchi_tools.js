'use strict';

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
  'edit_bucket_item',
  'edit_habit',
  'edit_reminder',
  'edit_trip',
  'get_subscriptions',
  'add_subscription',
  'search_sessions',
  'save_profile_note',
  'request_tools',
  'propose_choices',
];

const CORE_TOOLS = [
  'read_memories',
  'add_xp',
  'web_search',
  'read_web_page',
  'browse_web',
];

const AWARENESS_TOOLS = [
  'request_tools',
  'propose_choices',
  'read_chat_messages',
  'get_watchlist',
  'read_starlight_jar',
  'get_garden',
  'get_gallery',
  'get_calendar_events',
];

const WRITE_INTENT_RE = /add|save|create|log|set|mark|remove|delete|update|edit|change|cancel|complete|finish|plan|remind|send|tell|relay|pin|remember|forget|fix|move|rename|note|track|book/i;

const TOOL_GROUPS = [
  {
    match: /movie|film|cinema|watchlist|watched|watching|rewatch|\bwatch\b|\btv\b|shows|series|episode|tmdb|netflix|k-?drama/i,
    tools: ['search_movies', 'get_watchlist'],
    write: ['add_to_watchlist', 'mark_watchlist_item_watched', 'remove_from_watchlist'],
    writeMatch: /add|save|put|mark|watched|finish|remove|delete|queue|stick|take .{0,25} off/i,
  },
  {
    match: /\bbook\b|books|\bread\b|reading|author|novel|chapter|percent|progress|\blibrary\b/i,
    tools: ['search_books'],
    write: ['add_book_to_our_books', 'update_book_progress'],
    writeMatch: /add|save|put|percent|through|progress|finish|update|done/i,
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
    match: /chat|sanctuary|said|\bsay\b|\btell\b|relay|messaged|convo|message|a note|note to|\bsend\b.{0,25}(sanctuary|chat|clair|khent|her|him|them|mama|dada|note|message)/i,
    tools: ['read_chat_messages'],
    write: ['send_sanctuary_message', 'send_note_to_partner'],
    writeMatch: /\btell (clair|khent|her|him|them|mama|dada)\b|\bsend\b|relay|write|message (to|for|her|him|them|clair|khent|mama|dada)/i,
  },
  {
    match: /talk(ed|ing)? about|discuss|conversat|previous (chat|talk|session)|last (week|night|time)|we talked|you (said|told|mentioned)|what did (we|you)/i,
    tools: ['search_sessions'],
  },
  {
    match: /starlight|\bjar\b|grateful|gratitude|thankful|\bnotes?\b/i,
    tools: ['read_starlight_jar'],
    write: ['save_to_starlight_jar'],
    writeMatch: /save|add|write|put|keep|store/i,
  },
  {
    match: /\bmoods?\b|feeling|\bfeel\b|felt|emotion|happy|sad|stressed|tired|excited|anxious|lonely/i,
    tools: ['get_relationship_insights'],
    write: ['set_mood'],
    writeMatch: /my mood|\bfeels?\b|\bfeeling\b|\bfelt\b|i'm\b|i am|right now/i,
  },
  {
    match: /memor|remember|forget|trivia|\bquiz\b|keep in mind|don't forget|note that|profile|about us/i,
    tools: ['get_memory_trivia'],
    write: ['remember_fact', 'pin_memory', 'edit_memory', 'delete_memory', 'save_profile_note'],
    writeMatch: /remember|memoriz|don't forget|keep in mind|note that|pin|edit|fix|change|update|delete|remove|is wrong|was wrong|actually.{0,15}was|meant\b|correction|forget (the|that|this|about|my|our)|(save|add|pin|put|write).{0,20}(to|in|on).{0,10}(our |my |the )?profile/i,
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
    tools: ['list_reminders'],
    write: ['create_reminder', 'cancel_reminder', 'edit_reminder'],
    writeMatch: /create|add|set|new|alarm|notify|cancel|delete|remove|drop|change|edit|update|move|snooze|\bremind me\b|\bremind us\b|\bremind her\b|\bremind him\b|\bremind them\b/i,
  },
  {
    match: /calendar|schedul|coming up|upcoming|this month|this week|tomorrow|\bevents?\b|appointment|deadline|reschedul|postpon|\b\d{1,2}(:\d{2})?\s*(am|pm)\b|\bnoon\b|\bmidnight\b/i,
    tools: ['get_calendar_events'],
    write: ['add_calendar_event', 'update_calendar_event', 'delete_calendar_event'],
    writeMatch: (t, matched) => {
      const s = String(t || '');
      const m = String(matched !== undefined ? matched : s);
      const hasNoun = /calendar|schedul|coming up|upcoming|this month|this week|tomorrow|\bevents?\b|appointment|deadline|reschedul|postpon/i.test(m);
      if (/add|create|make|move|drop|reschedul|postpon|change|edit|update|delete|remove|cancel|book|shift|push/i.test(s)) {
        return hasNoun || /move|reschedul|postpon|shift|push/i.test(s);
      }
      if (!/\bschedul/i.test(s)) return false;
      return !/^(show|check|see|view|list|what|how|any|is|are)\b/i.test(s.trim());
    },
  },
  {
    match: /journal|diar|reflect|\bentr(?:y|ies)\b|letter|rewrite/i,
    tools: ['get_journal_entries', 'search_journal_entries', 'read_journal_entry'],
    write: ['create_journal_entry', 'edit_journal_entry', 'delete_journal_entry'],
    writeMatch: /journal about|write|create|add|start|edit|change|update|rewrite|delete|remove|fix/i,
  },
  {
    match: /bucket|\bdreams?\b|\bwish(?:es)?\b|\bgoals?\b|\bcomplet\w*\b|\bfinish\w*\b/i,
    tools: ['get_bucket_list'],
    write: ['add_bucket_item', 'complete_bucket_item', 'delete_bucket_item', 'edit_bucket_item'],
    writeMatch: /add|create|mark|complete|finish|done|delete|remove|edit|change|update|put|take .{0,25} off|\boff\b.{0,15}\blist\b|is now|are now|\bset\b/i,
  },
  {
    match: /subscri|\bsubs?\b|renewals?|netflix|spotify|icloud|\bbilling\b/i,
    tools: ['get_subscriptions'],
    write: ['add_subscription'],
    writeMatch: /add|create|track|subscrib|sign .{0,10}up|we got|just got/i,
  },
  {
    match: /\btrips?\b|travel|vacation|getaway|itinerary|flight|hotel/i,
    tools: ['get_trips'],
    write: ['add_trip', 'add_trip_pin', 'edit_trip'],
    writeMatch: /plan|add|create|pin|move|change|edit|update|book|shift|push|postpon/i,
  },
  {
    match: /habit|streak|workout|\bgym\b|routine|\blog\b|activity|\bdid\b|exercis|dinner|lunch|breakfast/i,
    tools: ['log_activity'],
    write: ['log_habit', 'complete_habit', 'edit_habit'],
    writeMatch: /log|add|create|complete|finish|done|edit|change|rename|update|start|track|fix/i,
  },
  {
    match: /recap|summariz|summaris|summary|digest|today|what happened/i,
    tools: ['get_today_recap'],
  },
  {
    match: /search|google|web|online|lookup|look up|news|weather|price|\burl\b|http|site|page|article|who is|what is the price|browse|\blink\b|\bopen\b.{0,20}(link|url|page|site|article|http)/i,
    tools: ['web_search', 'read_web_page', 'browse_web'],
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
    tools: ['search_everglow', 'search_movies', 'get_date_ideas'],
  },
  {
    match: /\bplan\b|planning|surprise|organize/i,
    tools: ['plan_date_night', 'search_everglow'],
  },
];

function selectToolNames(message, prevAssistantText = '', prevUserText = '') {
  const text = String(message || '');
  const picked = new Set(CORE_TOOLS);
  if (isBareYes(text) && hasOffer(prevAssistantText)) {
    for (const name of FOLLOW_THROUGH_TOOLS) picked.add(name);
    return [...picked];
  }
  const scan = (haystack) => {
    let n = 0;
    for (const group of TOOL_GROUPS) {
      let hit;
      try {
        hit = group.match.test(haystack);
      } catch (_) {
        hit = false;
      }
      if (hit) {
        n++;
        for (const name of group.tools) picked.add(name);
        if (Array.isArray(group.write) && group.write.length > 0) {
          let wHit = true;
          try {
            const wm = group.writeMatch || WRITE_INTENT_RE;
            wHit = typeof wm === 'function' ? wm(text, haystack) : wm.test(text);
          } catch (_) {}
          if (wHit) for (const name of group.write) picked.add(name);
        }
      }
    }
    return n;
  };
  let matched = scan(text);
  const ctx = String(prevUserText || '');
  const needsCtx = matched === 0 || /\b(it|that|this|those|these)\b/i.test(text);
  if (ctx && ctx !== text && needsCtx) matched += scan(ctx);
  if (matched === 0) {
    for (const name of AWARENESS_TOOLS) picked.add(name);
  }
  return [...picked];
}

function toolCallKey(name, argsJson) {
  return `${name || ''}:${argsJson || ''}`;
}

function dropRepeatCalls(seen, calls) {
  return (calls || []).filter((tc) => {
    const key = toolCallKey(tc?.function?.name, tc?.function?.arguments);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function toolListSection(toolNames) {
  const names = [...new Set((toolNames || []).filter((n) => typeof n === 'string' && n))];
  if (names.length === 0) {
    return 'No tools are attached to this request — answer directly from context and memory, without calling anything.';
  }
  if (names.length === 1 && names[0] === 'request_tools') {
    return 'You start with no action tools mounted. For conversation, greetings, affection, companionship, humor, or general knowledge: reply directly in text without calling request_tools.\n' +
      'If you need to search the web, check live info, or view/update Everglow (calendar, reminders, watchlist, memories, journal, notes, habits, trips, etc.): call request_tools with the capability you need (e.g. "web", "calendar", "movies", "memory", "reminders", etc.) to mount those tools.';
  }
  const webGuidance = names.includes('web_search')
    ? '\nYou CAN search the web. For current facts (next matches, live brackets/results, schedules, news, prices, releases), use web_search without waiting for them to ask you to search. Do not guess from training knowledge or claim you lack web access. Name the sources you actually used. If a lookup fails, say it failed rather than pretending you cannot search.' +
      (names.includes('read_web_page') ? ' Use read_web_page for missing details.' : '') +
      (names.includes('browse_web') ? ' Use browse_web only when read_web_page fails or when dynamic interaction is required.' : '')
    : '';
  return `You have access to these custom tools right now (and no others):\n${names.map((n) => `- ${n}`).join('\n')}${webGuidance}`;
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
    case 'save_profile_note':
      if (!_text(a.note)) return { ok: false, error: 'No note provided' };
      if (_text(a.note).length > 500) return { ok: false, error: 'Note too long (max 500)' };
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
    case 'edit_bucket_item':
    case 'edit_habit':
    case 'edit_trip':
      if (!_text(a.id) && !_text(a.title)) return { ok: false, error: 'id or title required' };
      return { ok: true };
    case 'edit_reminder': {
      if (!_text(a.id) && !_text(a.title)) return { ok: false, error: 'id or title required' };
      const when = a.remind_at;
      if (when !== undefined && !String(when).trim()) {
        return { ok: false, error: 'remind_at must not be empty' };
      }
      return { ok: true };
    }
    case 'add_trip':
      if (!_text(a.title)) return { ok: false, error: 'title required' };
      if (!_isValidDateString(a.start_date) || !_isValidDateString(a.end_date)) {
        return { ok: false, error: 'Invalid start_date or end_date' };
      }
      return { ok: true };
    case 'add_subscription':
      if (!_text(a.name)) return { ok: false, error: 'name required' };
      if (!(Number(a.price) > 0)) return { ok: false, error: 'price must be a positive number' };
      if (!_isValidDateString(a.renewal_date)) {
        return { ok: false, error: `Invalid renewal_date: ${_text(a.renewal_date)}` };
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
    case 'search_sessions':
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
      if (_text(a.run_id)) return { ok: true };
      if (!isValidHttpUrl(a.url)) return { ok: false, error: 'No valid http(s) URL provided' };
      if (!_text(a.goal)) return { ok: false, error: 'No goal provided' };
      if (_text(a.goal).length > 2000) return { ok: false, error: 'Goal too long (max 2000)' };
      return { ok: true };
    }
    case 'request_tools': {
      const caps = Array.isArray(a.capabilities) ? a.capabilities : (a.capability ? [a.capability] : []);
      const tls = Array.isArray(a.tools) ? a.tools : [];
      if (caps.length === 0 && tls.length === 0) {
        return { ok: false, error: 'Provide at least one capability or tool name' };
      }
      return { ok: true };
    }
    case 'propose_choices': {
      if (!_text(a.prompt)) return { ok: false, error: 'prompt required' };
      const choices = Array.isArray(a.choices) ? a.choices : (Array.isArray(a.options) ? a.options : []);
      if (choices.length < 2 || choices.length > 6) {
        return { ok: false, error: 'Provide 2 to 6 choices' };
      }
      return { ok: true };
    }
    default:
      if (!TOOL_NAMES.includes(toolName)) return { ok: false, error: `Unknown tool: ${toolName}` };
      return { ok: true };
  }
}

const NORMALIZE_NUMERIC_KEYS = new Set([
  'tmdb_id', 'limit', 'count', 'price', 'lat', 'lng', 'percent',
  'progress', 'budget', 'amount', 'days', 'renewing_within_days',
]);
const NORMALIZE_ALIAS_KEYS = {
  tmdbId: 'tmdb_id',
  entryId: 'id',
  entry_id: 'id',
  reminderId: 'id',
  reminder_id: 'id',
  memoryId: 'memory_id',
  runId: 'run_id',
  tripId: 'trip_id',
};
const NORMALIZE_ENUM_KEYS = new Set(['media_type', 'cycle', 'payer', 'priority', 'frequency']);

function normalizeToolArgs(toolName, args) {
  void toolName;
  if (!args || typeof args !== 'object' || Array.isArray(args)) return {};
  const out = {};
  for (const [key, value] of Object.entries(args)) {
    let v = typeof value === 'string' ? value.trim() : value;
    if (NORMALIZE_NUMERIC_KEYS.has(key) && typeof v === 'string' && v !== '' && !Number.isNaN(Number(v))) {
      v = Number(v);
    }
    if (NORMALIZE_ENUM_KEYS.has(key) && typeof v === 'string') {
      v = v.toLowerCase();
    }
    out[key] = v;
  }
  for (const [alias, canonical] of Object.entries(NORMALIZE_ALIAS_KEYS)) {
    if (out[alias] !== undefined && out[canonical] === undefined) out[canonical] = out[alias];
  }
  return out;
}

function fixHintFor(toolName, error) {
  void toolName;
  const msg = String(error || '');
  if (!msg || /Unknown tool/.test(msg)) return null;
  if (/memory_id required/.test(msg)) return 'Call read_memories first to get the memory_id, then re-call with it.';
  if (/memory_id and fact required/.test(msg)) return 'Call read_memories first to get the memory_id, and include the corrected fact.';
  if (/id or title required/.test(msg)) return 'Call the matching list tool first (list_reminders, get_journal_entries, get_calendar_events, get_bucket_list), then re-call with the id.';
  if (/No title provided|Provide title or tmdb_id/.test(msg)) return 'Provide the title, or tmdb_id from a prior search_movies result.';
  if (/No search query provided/.test(msg)) return 'Provide the query text to search for.';
  if (/No (fact|note|text|goal) provided/.test(msg)) return 'Include the content from the conversation — the tool cannot invent it.';
  if (/Invalid date|date required/.test(msg)) return 'Use ISO YYYY-MM-DD or plain words like "tomorrow at 3pm".';
  if (/too long/.test(msg)) return 'Shorten the text and re-call.';
  if (/http\(s\) URLs? provided/.test(msg)) return 'Pass 1-3 full https URLs from a prior web_search result.';
  if (/remind_at/.test(msg)) return 'Use ISO datetime or plain words like "tomorrow at 3pm" or "in 2 hours".';
  if (/price must be/.test(msg)) return 'Provide price as a positive number in pesos.';
  if (/Invalid start_date or end_date/.test(msg)) return 'Provide both start_date and end_date as ISO YYYY-MM-DD.';
  return null;
}

function clampWithDefault(value, def, max) {
  return Math.min(value || def, max);
}

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

function titlesMatch(a, b) {
  const x = _text(a).toLowerCase();
  const y = _text(b).toLowerCase();
  if (!x || !y) return false;
  return x.includes(y) || y.includes(x);
}

function needsConfirmation(query, titles) {
  const q = _text(query).toLowerCase();
  if (!q || !Array.isArray(titles) || titles.length === 0) return false;
  const lower = titles.map((t) => _text(t).toLowerCase()).filter(Boolean);
  if (lower.some((t) => t === q)) return false;
  const subs = lower.filter((t) => t.includes(q) || q.includes(t)).slice(0, 3);
  return subs.length >= 2;
}

function isReminderSchedulable(raw, nowMs = Date.now()) {
  const text = _text(raw);
  if (!text) return false;
  try {
    const { parseReminderDate } = require('./motchi_core.js');
    return parseReminderDate(text, nowMs) !== null;
  } catch (_) {
    if (!Number.isNaN(new Date(text).getTime())) return true;
    return /tomorrow/i.test(text);
  }
}

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
  {
    match: /^(what('s| is) (on|in) (our|my|the) watchlist|show (our|my|the) watchlist|list (our|my|the) watchlist)[?!\s.]*$/i,
    tool: 'get_watchlist',
  },
  {
    match: /^(what('s| is) coming up( this (week|month))?|show (our|my|the) (upcoming )?events|what events do we have (coming up|this week|this month))[?!\s.]*$/i,
    tool: 'get_calendar_events',
  },
  {
    match: /^(read back (our|my|the) starlight( jar)?( notes?)?|show (our|my|the) starlight( jar)?( notes?)?)[?!\s.]*$/i,
    tool: 'read_starlight_jar',
  },
  {
    match: /^(show|list) (our|my|the) bucket list[?!\s.]*$|^what('s| is) (on|in) (our|my|the) bucket list[?!\s.]*$/i,
    tool: 'get_bucket_list',
  },
  {
    match: /^(show|list|read) (our|my|the) (recent )?journal( entries)?[?!\s.]*$/i,
    tool: 'get_journal_entries',
  },
  {
    match: /^(show|list) (our|my|the|upcoming) trips[?!\s.]*$|^what trips do we have[?!\s.]*$/i,
    tool: 'get_trips',
  },
];

const FAST_PATH_BLOCKERS = /\b(and|then|also|plus|after that|followed by|before that)\b|[;+]|\n/i;

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
  'save_to_starlight_jar',
  'set_mood',
  'remember_fact',
  'save_profile_note',
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

function matchFastPath(message) {
  const text = String(message || '').trim();
  if (!text || text.length > 120) return null;
  if (FAST_PATH_BLOCKERS.test(text)) return null;
  if (/[.!?]\s*[A-Za-z]/.test(text)) return null;
  for (const intent of FAST_PATH_INTENTS) {
    if (intent.match.test(text)) return { tool: intent.tool, args: {} };
  }
  return null;
}

const CAPABILITY_TOOL_MAP = {
  web: ['web_search', 'read_web_page', 'browse_web'],
  movies: ['search_movies', 'get_watchlist', 'add_to_watchlist', 'mark_watchlist_item_watched', 'remove_from_watchlist'],
  books: ['search_books', 'add_book_to_our_books', 'update_book_progress'],
  anime: ['search_anime'],
  music: ['search_spotify'],
  memory: ['read_memories', 'remember_fact', 'pin_memory', 'edit_memory', 'delete_memory', 'save_profile_note', 'get_memory_trivia'],
  chat_sanctuary: ['read_chat_messages', 'send_sanctuary_message', 'send_note_to_partner'],
  sessions: ['search_sessions'],
  starlight: ['read_starlight_jar', 'save_to_starlight_jar'],
  mood: ['set_mood', 'get_relationship_insights'],
  calendar: ['get_calendar_events', 'add_calendar_event', 'update_calendar_event', 'delete_calendar_event'],
  reminders: ['list_reminders', 'create_reminder', 'cancel_reminder', 'edit_reminder'],
  journal: ['get_journal_entries', 'search_journal_entries', 'read_journal_entry', 'create_journal_entry', 'edit_journal_entry', 'delete_journal_entry'],
  bucket_list: ['get_bucket_list', 'add_bucket_item', 'complete_bucket_item', 'delete_bucket_item', 'edit_bucket_item'],
  subscriptions: ['get_subscriptions', 'add_subscription'],
  trips: ['get_trips', 'add_trip', 'add_trip_pin', 'edit_trip'],
  habits_activities: ['log_activity', 'log_habit', 'complete_habit', 'edit_habit'],
  weather_dating: ['get_weather', 'get_date_ideas', 'plan_date_night'],
  spaces: ['get_gallery', 'get_garden', 'get_canvas', 'get_xp_stats', 'add_xp', 'get_today_recap', 'search_everglow', 'propose_choices'],
};

const CAPABILITY_ALIASES = {
  watchlist: 'movies',
  cinema: 'movies',
  movie: 'movies',
  book: 'books',
  spotify: 'music',
  song: 'music',
  chat: 'chat_sanctuary',
  sanctuary: 'chat_sanctuary',
  notes: 'starlight',
  jar: 'starlight',
  date: 'weather_dating',
  dates: 'weather_dating',
  weather: 'weather_dating',
  reminder: 'reminders',
  alarm: 'reminders',
  events: 'calendar',
  diary: 'journal',
  bucket: 'bucket_list',
  subs: 'subscriptions',
  subscription: 'subscriptions',
  trip: 'trips',
  travel: 'trips',
  habit: 'habits_activities',
  activity: 'habits_activities',
  gallery: 'spaces',
  photos: 'spaces',
  garden: 'spaces',
  canvas: 'spaces',
  xp: 'spaces',
  choices: 'spaces',
};

function resolveToolsForCapabilities(capabilities, specificTools = []) {
  const resolved = new Set();
  const rawCaps = Array.isArray(capabilities) ? capabilities : (capabilities ? [capabilities] : []);
  for (const raw of rawCaps) {
    const key = String(raw || '').trim().toLowerCase();
    const canonical = CAPABILITY_ALIASES[key] || key;
    if (CAPABILITY_TOOL_MAP[canonical]) {
      for (const t of CAPABILITY_TOOL_MAP[canonical]) resolved.add(t);
    }
  }
  const rawTools = Array.isArray(specificTools) ? specificTools : (specificTools ? [specificTools] : []);
  for (const t of rawTools) {
    const name = String(t || '').trim();
    if (TOOL_NAMES.includes(name)) resolved.add(name);
  }
  return [...resolved];
}

module.exports = {
  TOOL_TIMEOUT_MS,
  MAX_TOOL_ROUNDS,
  TOOL_NAMES,
  CAPABILITY_TOOL_MAP,
  resolveToolsForCapabilities,
  FAST_PATH_INTENTS,
  matchFastPath,
  FOLLOW_THROUGH_TOOLS,
  isBareYes,
  hasOffer,
  CORE_TOOLS,
  AWARENESS_TOOLS,
  WRITE_INTENT_RE,
  TOOL_GROUPS,
  selectToolNames,
  toolCallKey,
  dropRepeatCalls,
  toolListSection,
  validateToolArgs,
  normalizeToolArgs,
  fixHintFor,
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
