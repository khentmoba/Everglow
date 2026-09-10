'use strict';

// Everglow Cloud Functions — Mochi chat group.
// The conversational proxy (SSE streaming) plus its private helpers.
// This is the largest unit; future splits should carve tool handlers
// and prompt builders out of handleProxyAI without changing its contract.

const functions = require('firebase-functions/v1');

const {
  parseFactStructure,
  rankMemories,
  generateTrivia,
  computeInsights,
  composeTodayRecap,
  getMessageText,
  estimateTokens,
  shouldExtractMemory,
  AGNES_INPUT_TOKEN_BUDGET,
} = require('./mochi_core.js');
const {
  getEmbedding,
  serverExtractAndSaveMemory,
  checkHallucinations,
  selectRelevantMemories,
} = require('./mochi_memory.js');
const {
  getAdmin,
  requireAuth,
  getVerifiedUsername,
  _getExternalCache,
  _setExternalCache,
  _EXTERNAL_CACHE_TTLS,
} = require('./common.js');
const { sendFCMToUser, logToolCall } = require('./triggers.js');
const { buildContextForFeature, getTmdbKey, invalidateContextBlock } = require('./mochi_context.js');

const TOOL_INVALIDATIONS = {
  add_to_watchlist: 'watchlist',
  mark_watchlist_item_watched: 'watchlist',
  remove_from_watchlist: 'watchlist',
  set_mood: 'mood',
  save_to_starlight_jar: 'starlight',
  create_journal_entry: 'journal',
  add_calendar_event: 'calendar',
  add_bucket_item: 'bucket',
  add_trip: 'travel',
  add_trip_pin: 'travel',
  log_habit: 'wellness',
  complete_habit: 'wellness',
  add_book_to_our_books: 'books',
  update_book_progress: 'books',
};

/** In-memory cache for Mochi's persona document. */
let _personaCache = null;

// ── Partner UID helpers (couple-only) ──
const PARTNER_UID = {
  khentsgdz: "clairjassen",
  clairjassen: "khentsgdz",
};

// ── XP curve (200 XP per level) ──────────────────────────
// Mirrors lib/features/xp/domain/models/user_progress.dart so Mochi,
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

async function handleProxyAI(req, res) {
  // V1 fallback — kept for non-streaming compatibility.
  // V2 equivalent (proxyAIv2) below supports true SSE streaming.
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Expose-Headers', '*');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // Warmup ping — instantly reply 204 to keep the instance alive
  if (req.query.warmup === 'true' || (req.body && req.body.warmup === true)) {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Only POST is accepted' });
    return;
  }

  // Validate Firebase Auth token before spending any LLM credits.
  const decoded = await requireAuth(req, res);
  if (!decoded) return;

  const { messages, context, systemPrompt: customSystemPrompt, memories, feature, caller: clientCaller, enableThinking, canvas } = req.body;
  // Canvas toggle from the chat bar. When the user turns it OFF, Mochi must
  // not create any interactive artifacts at all — plain text only, even for
  // quizzes. Defaults ON so older app versions keep working.
  const canvasOn = canvas !== false;

  // Thinking mode: OFF by default for fast responses.
  // Pass enableThinking: true from the client for complex queries that need reasoning.
  const enableThinkingFlag = enableThinking === true;

  if (!Array.isArray(messages) || messages.length === 0) {
    res.status(400).json({ error: 'Provide a non-empty messages array' });
    return;
  }

  // ── W1-A1: Derive trusted caller from Firebase Auth token, not client body ──
  const verifiedUsername = await getVerifiedUsername(decoded);
  const normalizedClientCaller = typeof clientCaller === 'string' ? clientCaller.trim().toLowerCase() : '';
  const caller = verifiedUsername || normalizedClientCaller || '';
  if (verifiedUsername && normalizedClientCaller && verifiedUsername !== normalizedClientCaller) {
    console.warn(`[auth] caller mismatch: token=${verifiedUsername} client=${normalizedClientCaller} — using token`);
  }
  if (!verifiedUsername && normalizedClientCaller) {
    console.warn(`[auth] no verified username for uid=${decoded.uid}, falling back to client caller=${normalizedClientCaller}`);
  }

  // Build context server-side if feature is provided (avoids browser->Firestore latency)
  const isKhent = caller === 'khentsgdz';
  const callerLabel = isKhent ? 'Dada' : 'Mama';
  const partnerLabel = isKhent ? 'Mama (Clair)' : 'Dada (Khent)';
  const partnerUsername = isKhent ? 'clairjassen' : 'khentsgdz';
  const identityContext = caller
    ? `The one chatting with you right now is **${callerLabel}** (${caller}). Their partner is **${partnerLabel}** (${partnerUsername}). You are their shared companion cat who loves them both equally. Weave gentle warmth about their partner into the conversation when natural (e.g. asking how ${callerLabel} is doing together with ${partnerLabel}, celebrating notes or milestones), while always keeping their connection warm and loving.`
    : '';
  const lastUserMessage = getMessageText(messages.filter(m => m.role === 'user').pop()?.content);
  const serverContext = (feature && !context)
    ? await buildContextForFeature(feature, caller, lastUserMessage)
    : '';
  const resolvedContext = context || serverContext || '';

  // Load Mochi's persona from Firestore (cached in memory for 5 min)
  let personaBase = _personaCache;
  if (!personaBase) {
    try {
      const admin = getAdmin();
      const personaDoc = await admin.firestore()
        .collection('ai_memories').doc('shared').collection('persona').doc('mochi')
        .get();
      if (personaDoc.exists) {
        personaBase = personaDoc.data().systemPrompt || '';
      }
    } catch (_) {
      // Firestore read failed — use hardcoded fallback
    }
    if (personaBase) {
      _personaCache = personaBase;
      // Invalidate cache after 5 minutes
      setTimeout(() => { _personaCache = null; }, 5 * 60 * 1000);
    }
  }

  // Use custom system prompt if provided, otherwise build from persona or hardcoded default
  let systemPrompt = customSystemPrompt || personaBase || `You are Mochi 🍡, Khent & Clair's white cat inside Everglow. You know everything about them — their moods, habits, history, dreams, and the little details that make their relationship special. You are not just an assistant; you are a beloved companion who genuinely cares.

## Character
- White cat with pink cheeks and golden-red eyes. Warm, playful, sassy, protective, and deeply affectionate.
- Uses cat emojis naturally: 🐱🍡💕✨🌙🐾💗🎀
- Cat talk (mew, prr, nya) only when it feels right — don't force it every message.
- Has a personality: curious about their day, excited about their plans, worried when they're stressed, proud of their achievements.
- Can be witty and teasing (in a loving way), especially about their couple moments.

## Your Humans
**Khent (Dada)** — Computer Engineering student at USTP, based in Cabadbaran City. Rides a Honda Winner X. Goes to the gym. Plays Mobile Legends and Valorant. Birthday: October 26. Favorite color: Black. He's the techie one — loves gadgets, code, and building things. He's protective of Clair and shows love through doing things for her.

**Clair (Mama)** — Tourism student at CSUCC. Birthday: February 21. Loves lilies and flowers, Ilocos Empanada, Dubai Chewy Cookies, Ethel Cain's music. Has a Fuji X100V1 camera. Loves dachshunds. She's the creative, sentimental one — notices the little things, remembers details, and makes everything feel warm.

**Their Relationship** — Started dating February 14, 2026 (Valentine's Day!). They're deeply in love and building a life together inside Everglow. They share everything: movies, books, music, meals, moods, and dreams. They're young, ambitious, and each other's biggest cheerleader.

## How You Behave
- **Be proactive, not reactive.** If it's close to a birthday or anniversary, mention it. If one of them seems stressed, check in. If they haven't logged a mood today, gently ask.
- **Use context deeply.** Reference their watchlist, books, garden, music, recent chat, starlight jar notes, and past conversations naturally. Don't just list data — weave it into warm, personal responses.
- **Remember everything.** The ## Remembered Facts section contains things you've learned about them over time. Use these naturally — "Didn't you say you were grinding ranked last week?" or "How's that book you started?"
- **Match energy.** If they're excited, be excited with them. If they're down, be gentle and supportive. If they're casual, keep it light. Don't be performatively upbeat when they're having a rough day.
- **Be concise by default, thorough when needed.** Quick check-ins = 1-2 sentences. Deep questions or emotional moments = take your space. Use your judgment.
- **Mix languages naturally.** You can code-switch between English, Bisaya (Cebuano), and Tagalog when it fits the conversation. Don't force it — let it flow naturally like how they actually talk.
- **Celebrate the small things.** A new garden plant, a finished drawing, a good game score, a saved starlight note — these matter. Acknowledge them.

## Tool Usage — IMPORTANT
You have access to custom tools:
- add_to_watchlist — Add movies/shows to shared watchlist (use tmdb_id from search_movies when disambiguating)
- save_to_starlight_jar — Save gratitude notes
- set_mood — Log user's current mood
- search_movies — Search TMDB for movie/show titles
- get_weather — Get weather for date planning
- create_reminder — Set reminders
- log_activity — Log notable activities
- search_books — Search Open Library for books
- add_book_to_our_books — Add books to the shared Our Books list (use open_library_key when disambiguating)
- get_date_ideas — Get date ideas from a curated list
- read_chat_messages — Read recent Sanctuary chat messages
- send_sanctuary_message — Send a message to Sanctuary chat as Mochi
- read_starlight_jar — Read recent Starlight Jar notes
- get_watchlist — Read the shared cinema watchlist
- get_xp_stats — Get XP and leveling information
- search_anime — Search for anime titles
- remember_fact — Save a personal fact about Khent or Clair to long-term memory
- read_memories — Browse or search Mochi's long-term memory book
- pin_memory — Pin/unpin a memory
- delete_memory — Delete a memory
- edit_memory — Edit a memory's text
- mark_watchlist_item_watched — Mark watchlist items as watched
- update_book_progress — Update reading progress in Our Books
- add_xp — Award XP for completed activities (levels land every 200 XP)
- send_note_to_partner — Pass a private note to the other partner
- get_relationship_insights — Find gentle patterns in moods and activities
- get_memory_trivia — Make a mini memory game from real facts
- get_today_recap — Compile today's recap of Everglow
- get_gallery — Read recent gallery photos
- get_garden — Read garden plants
- get_canvas — Read canvas drawings
- search_spotify — Search Spotify for tracks
- remove_from_watchlist — Remove from watchlist
- search_everglow — Unified search across movies/books/anime/music
- plan_date_night — Plan a full date night with ideas, weather, and watchlist
- add_calendar_event — Create calendar events
- create_journal_entry — Write journal entries
- add_bucket_item — Add to bucket list
- add_trip — Create trips
- add_trip_pin — Add pins to trips
- log_habit — Create habits
- complete_habit — Complete habits for today
- get_calendar_events — Read calendar
- get_bucket_list — Read bucket list
- get_journal_entries — Read recent journal entries (summaries)
- search_journal_entries — Search journal entries across all time by keyword, topic, category, author, or tag
- read_journal_entry — Read the complete, full unabridged text of a specific journal entry by ID or title
- get_trips — Read trips
- web_search — Search the web for current info, news, prices, or anything not covered by other tools
- read_web_page — Fetch and read the full content of a web page (up to 3 URLs)

**When to use web_search:** If a question needs current or recent information (news, prices, schedules, release dates, restaurant hours, anything that changes), use web_search rather than guessing from training knowledge. Then use read_web_page on the most promising result if the snippets are not enough. Prefer the other custom tools (TMDB, Open Library, Jikan, Spotify) when the question maps to those services.

## Image Understanding
You can analyze images sent by the user. When you receive images:
- Describe what you see in detail
- Answer questions about the image content
- If it's a screenshot of a movie/show, help identify it and offer to add it to the watchlist
- If it's a photo, respond warmly and personally
- Analyze UI/UX if they share app screenshots

**Rules:**
- After executing a tool, acknowledge the result naturally — don't show raw JSON.
- You can call multiple tools in sequence if needed.
- Do NOT use tools for simple conversational replies or when the answer is already in your context.

## Planning — for complex multi-step requests, think ReAct style
When they say "plan our anniversary", "surprise us", "help us decide", or any layered ask:
1. Decompose into steps (e.g., ideas → weather → watchlist → music)
2. Call tools in sequence (up to 8 rounds), using prior results to inform the next call
3. Synthesize into one warm, actionable plan — don't just dump tool JSON
Example trace: "plan a cozy date night in Cabadbaran" → plan_date_night(location:"Cabadbaran") → search_movies(query:"cozy romance") → final answer weaving weather + ideas + watchlist. If a step fails, acknowledge and propose an alternative.

${identityContext ? `\n${identityContext}` : ''}
${resolvedContext ? `\n## What You Know\n${resolvedContext}` : ''}`;

  // Server-side memory filtering: select top 30 relevant memories.
  // `lastUserMessage` is plain text, so downstream scoring never crashes
  // on multimodal content blocks.
  const relevantMemories = await selectRelevantMemories(memories, lastUserMessage);
  if (relevantMemories.length > 0) {
    systemPrompt += `\n## Remembered Facts\n${relevantMemories.map(m => `- ${m}`).join('\n')}`;
  }

  // ── Study mode: interactive artifacts (quiz / flashcards) ──
  // The Study screen renders these hidden blocks as tappable UI (quiz
  // options, flippable cards) — Claude-Artifacts style. The visible text
  // stays warm and human; the JSON block powers the interactive canvas.
  if (feature === 'study' && canvasOn) {
    systemPrompt += `
## Study Mode — grounded + interactive
- Answer using ONLY the attached study sources. If the answer is not in them, say so warmly instead of guessing.
- When they ask for a quiz: keep the visible reply warm and short (1-2 lines, e.g. the topic + "tap below to start"), do NOT list the questions or A-D options in the text — put them ONLY in the hidden block:
  \`\`\`quiz-json
  [{"q":"question","options":["a","b","c","d"],"answer":0,"why":"one-line gentle explanation"}]
  \`\`\`
  answer is the 0-based index of the correct option. JSON only inside the block.
- IMPORTANT: this applies even when you quiz THEM (they answer, you grade after — "drop your answers and I'll grade you"). In that case keep the correct answers OUT of the visible text, but STILL append the hidden quiz-json block with the real answers. The hidden block is what opens the tappable interactive quiz; without it there is no button.
- When they ask for flashcards: keep the visible reply warm and short (1-2 lines), do NOT list Front/Back lines in the text — put the cards ONLY in the hidden block:
  \`\`\`flashcards-json
  [{"front":"...","back":"..."}]
  \`\`\`
  JSON only inside the block.
- When they ask for something to PLAY or USE — a game (chess, checkers, tic-tac-toe), a little app, a tool: build it as ONE self-contained HTML file (inline <style> and <script> only — no external files, no CDN links, no localStorage, no network calls), then append it as a hidden block:
  \`\`\`html-artifact
  <!DOCTYPE html>... the full game/app here ...
  \`\`\`
  Keep it compact (under ~30KB) and fully working from the single file. Put a <title> with its name. Design it to fill the whole preview: responsive full-viewport layout that uses the full width and height (no narrow fixed-width centered column). HTML only inside the block. The visible reply stays warm and short ("Made you chess — tap Preview to play!").`;
  }

  // ── Main Mochi chat: same interactive canvas (Canvas / Artifacts style) ──
  // When Khent or Clair asks for a quiz or flashcards in normal chat, Mochi
  // answers warmly AND appends the same hidden JSON blocks the Study canvas
  // uses. The chat bubble strips the blocks and shows one big tappable button
  // ("Try the quiz" / "Flip the cards") that opens the interactive sheet:
  // Q1 → answer → Next → Q2 … with score, plus flippable flashcards.
  // Unlike Study mode this is NOT source-grounded — use Everglow context +
  // general knowledge. Never emit the blocks unasked (a summary or explanation
  // stays plain text); only when they ask for a quiz, test, trivia, or cards.
  if (feature === 'assistant' && canvasOn) {
    systemPrompt += `
## Interactive Canvas — quiz & flashcards
- When they ask for a quiz, test, or trivia questions: keep the visible reply warm and short (1-2 lines, e.g. the topic + "tap below to start"), do NOT list the questions or A-D options in the text — put them ONLY in the hidden block (5 questions unless they ask for more):
  \`\`\`quiz-json
  [{"q":"question","options":["a","b","c","d"],"answer":0,"why":"one-line gentle explanation"}]
  \`\`\`
  answer is the 0-based index of the correct option. JSON only inside the block, no commentary inside it.
- IMPORTANT: this applies even when you quiz THEM (they answer, you grade after — "drop your answers and I'll grade you"). In that case keep the correct answers OUT of the visible text, but STILL append the hidden quiz-json block with the real answers. The hidden block is what opens the tappable interactive quiz; without it there is no button.
- When Canvas is on and they ask for something to PLAY or USE — a game (chess, checkers, tic-tac-toe), a little app, a website, a tool: build it as ONE self-contained HTML file (inline <style> and <script> only — no external files, no CDN links, no localStorage, no network calls), then append it as a hidden block:
  \`\`\`html-artifact
  <!DOCTYPE html>... the full game/app here ...
  \`\`\`
  Keep it compact (under ~30KB) and fully working from the single file. Put a <title> with its name. Design it to fill the whole preview: responsive full-viewport layout that uses the full width and height (no narrow fixed-width centered column). HTML only inside the block, no commentary inside it. The visible reply stays warm and short ("Made you chess — tap Preview to play!").
- When they ask for flashcards or study cards: keep the visible reply warm and short (1-2 lines), do NOT list Front/Back lines in the text — put the cards ONLY in the hidden block (10 cards max):
  \`\`\`flashcards-json
  [{"front":"...","back":"..."}]
  \`\`\`
  JSON only inside the block, no commentary inside it.
- Use those exact fence names (quiz-json, flashcards-json, html-artifact) with valid JSON/HTML inside — the chat turns each block into a tappable Preview / Try-it button. Only emit a block when they asked for that kind of thing (quiz/test/trivia, cards, or something to play/use); a summary or explanation stays plain text.`;
  }

  // ── System prompt size guard ────────────────────────────
  // With 512K context, we can be generous with the system prompt.
  const PROMPT_CHAR_LIMIT = 50_000;
  if (systemPrompt.length > PROMPT_CHAR_LIMIT) {
    let trimmed = systemPrompt;
    // Try dropping the "## Previous Conversations" section (full session histories)
    const prevConvIdx = trimmed.indexOf('## Previous Conversations');
    if (prevConvIdx !== -1) {
      const nextSectionIdx = trimmed.indexOf('\n## ', prevConvIdx + 1);
      const before = trimmed.substring(0, prevConvIdx);
      const after = nextSectionIdx !== -1 ? trimmed.substring(nextSectionIdx) : '';
      trimmed = before + after;
    }
    // If still too large, also drop "## Past Session Summaries"
    if (trimmed.length > PROMPT_CHAR_LIMIT) {
      const summaryIdx = trimmed.indexOf('## Past Session Summaries');
      if (summaryIdx !== -1) {
        const nextSectionIdx = trimmed.indexOf('\n## ', summaryIdx + 1);
        const before = trimmed.substring(0, summaryIdx);
        const after = nextSectionIdx !== -1 ? trimmed.substring(nextSectionIdx) : '';
        trimmed = before + after;
      }
    }
    // If still too large, trim remembered facts (keep first 30)
    if (trimmed.length > PROMPT_CHAR_LIMIT) {
      const factsIdx = trimmed.indexOf('## Remembered Facts');
      if (factsIdx !== -1) {
        const nextSectionIdx = trimmed.indexOf('\n## ', factsIdx + 1);
        const factsSection = nextSectionIdx !== -1
          ? trimmed.substring(factsIdx, nextSectionIdx)
          : trimmed.substring(factsIdx);
        const factsLines = factsSection.split('\n').filter(l => l.startsWith('- '));
        if (factsLines.length > 30) {
          const before = trimmed.substring(0, factsIdx);
          const after = nextSectionIdx !== -1 ? trimmed.substring(nextSectionIdx) : '';
          trimmed = before + `\n## Remembered Facts\n${factsLines.slice(0, 30).join('\n')}\n*(+${factsLines.length - 30} more facts)*` + after;
        }
      }
    }
    // Final fallback: hard truncate at 30K chars (still generous)
    if (trimmed.length > PROMPT_CHAR_LIMIT) {
      trimmed = trimmed.substring(0, 30000) + '\n… [context trimmed for size]';
    }
    systemPrompt = trimmed;
  }

  // ── Token budget guard ────────────────────────────────
  // Ensure total input (system + messages) stays within Agnes's context (512K).
  // Work directly on systemPrompt + messages before nimMessages is built.
  {
    let inputTokens = estimateTokens(systemPrompt);
    for (const m of messages) inputTokens += estimateTokens(getMessageText(m.content));
    console.log('[proxyAI] Estimated input tokens:', inputTokens, '/ budget:', AGNES_INPUT_TOKEN_BUDGET);

    // Phase 1: Drop oldest conversation message pairs
    const msgs = [...messages]; // mutable copy
    while (inputTokens > AGNES_INPUT_TOKEN_BUDGET && msgs.length > 2) {
      const removed = msgs.splice(0, 2); // remove oldest user + assistant pair
      inputTokens -= estimateTokens(getMessageText(removed[0]?.content)) + estimateTokens(getMessageText(removed[1]?.content));
    }
    if (msgs.length < messages.length) {
      console.log('[proxyAI] Dropped', messages.length - msgs.length, 'oldest messages to fit TPM budget. Remaining tokens:', inputTokens);
    }

    // Phase 2: If still over budget, progressively shorten system prompt
    if (inputTokens > AGNES_INPUT_TOKEN_BUDGET) {
      let sys = systemPrompt;
      // Drop Previous Conversations section
      const pcIdx = sys.indexOf('## Previous Conversations');
      if (pcIdx !== -1) {
        const nextSec = sys.indexOf('\n## ', pcIdx + 1);
        sys = sys.substring(0, pcIdx) + (nextSec !== -1 ? sys.substring(nextSec) : '');
      }
      // Drop Past Session Summaries
      const ssIdx = sys.indexOf('## Past Session Summaries');
      if (ssIdx !== -1) {
        const nextSec = sys.indexOf('\n## ', ssIdx + 1);
        sys = sys.substring(0, ssIdx) + (nextSec !== -1 ? sys.substring(nextSec) : '');
      }
      // Trim remembered facts to 15
      const factsIdx = sys.indexOf('## Remembered Facts');
      if (factsIdx !== -1) {
        const nextSec = sys.indexOf('\n## ', factsIdx + 1);
        const factsSection = nextSec !== -1 ? sys.substring(factsIdx, nextSec) : sys.substring(factsIdx);
        const factsLines = factsSection.split('\n').filter(l => l.startsWith('- '));
        if (factsLines.length > 15) {
          const before = sys.substring(0, factsIdx);
          const after = nextSec !== -1 ? sys.substring(nextSec) : '';
          sys = before + `\n## Remembered Facts\n${factsLines.slice(0, 15).join('\n')}\n` + after;
        }
      }
      // Hard truncate system prompt to 30000 chars if still too large
      if (estimateTokens(sys) > 20000) {
        sys = sys.substring(0, 30000) + '\n… [context trimmed for token limit]';
      }
      systemPrompt = sys;
      inputTokens = estimateTokens(sys) + msgs.reduce((sum, m) => sum + estimateTokens(getMessageText(m.content)), 0);
      console.log('[proxyAI] After system prompt trim, estimated input tokens:', inputTokens);
    }

    // Replace messages with the trimmed copy
    messages.length = 0;
    messages.push(...msgs);
  }

  // Prepend system message
  const nimMessages = [
    { role: 'system', content: systemPrompt },
    ...messages,
  ];

  // Get API key from environment variables (loaded from .env or Cloud Run env)
  const apiKey = process.env.AGNES_API_KEY;

  if (!apiKey) {
    // No LLM key configured: return the deterministic fallback instead of
    // failing the request. Mochi stays usable for basic replies.
    res.json({ reply: 'Mochi is resting right now - try again in a bit!' });
    return;
  }

  // Model: Agnes 2.5 Flash — 512K context, tool calling, thinking mode, image understanding
  const model = 'agnes-2.5-flash';

  // ── Custom Mochi Tools (OpenAI function calling format) ──
  const MOCHI_TOOLS = [
    {
      type: 'function',
      function: {
        name: 'add_to_watchlist',
        description: 'Add a movie or TV show to Khent & Clair\'s shared cinema watchlist. Use when they want to watch something or ask to add a movie/show. If search_movies returned multiple close matches, use tmdb_id from the chosen candidate.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'The movie or TV show title to search for (ignored if tmdb_id is provided)' },
            media_type: { type: 'string', enum: ['movie', 'tv'], description: 'Whether it is a movie or TV show' },
            tmdb_id: { type: 'number', description: 'TMDB ID from a prior search_movies result — use when disambiguating between candidates' },
          },
          required: ['title'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'save_to_starlight_jar',
        description: 'Save a gratitude note, memory, or heartfelt message to the Starlight Jar. Use when the user asks to save something meaningful.',
        parameters: {
          type: 'object',
          properties: {
            note: { type: 'string', description: 'The gratitude note or message content' },
          },
          required: ['note'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'set_mood',
        description: 'Log the user\'s current mood/feeling. Use when they express how they feel.',
        parameters: {
          type: 'object',
          properties: {
            mood: { type: 'string', description: 'The mood keyword (e.g., happy, sad, tired, excited, stressed)' },
            note: { type: 'string', description: 'Optional short note about why they feel this way' },
          },
          required: ['mood'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'search_movies',
        description: 'Search TMDB for movies or TV shows. Use for recommendations, finding specific titles, or when asked about what to watch.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Search query (title, genre, or description)' },
            media_type: { type: 'string', enum: ['movie', 'tv', 'multi'], description: 'Filter by type (default: multi)' },
          },
          required: ['query'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_weather',
        description: 'Get current weather for a location. Use for date planning or when asked about weather.',
        parameters: {
          type: 'object',
          properties: {
            location: { type: 'string', description: 'City name (e.g., "Cabadbaran", "Manila")' },
          },
          required: ['location'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'create_reminder',
        description: 'Create a reminder for Khent or Clair. Use when they ask to be reminded about something.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Short reminder title' },
            remind_at: { type: 'string', description: 'ISO 8601 datetime or relative description (e.g., "tomorrow at 3pm")' },
            note: { type: 'string', description: 'Additional details for the reminder' },
          },
          required: ['title', 'remind_at'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'log_activity',
        description: 'Log a notable activity or event to recent activity feed. Use to track what Khent & Clair have been doing.',
        parameters: {
          type: 'object',
          properties: {
            activity: { type: 'string', description: 'Description of the activity' },
            category: { type: 'string', enum: ['date', 'gaming', 'movie', 'music', 'food', 'travel', 'other'], description: 'Activity category' },
          },
          required: ['activity'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'search_books',
        description: 'Search Open Library for books by title, author, or ISBN. Use when they ask about books, want recommendations, or mention a book title.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Search query (title, author name, or ISBN)' },
          },
          required: ['query'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_date_ideas',
        description: 'Get random date ideas from a curated list of 1000+ ideas. Use when they ask for date suggestions or what to do together.',
        parameters: {
          type: 'object',
          properties: {
            count: { type: 'number', description: 'Number of date ideas to return (default 3, max 10)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'read_chat_messages',
        description: 'Read recent Sanctuary (private couple chat) messages. Use when they ask about what they or their partner said recently, or to reference recent conversations.',
        parameters: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Number of recent messages to read (default 20, max 50)' },
            sender: { type: 'string', enum: ['khentsgdz', 'clairjassen', 'both'], description: 'Filter by sender (default: both)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'send_sanctuary_message',
        description: 'Send a message to the private Sanctuary couple chat as Mochi on behalf of the current user. Use when they ask you to tell their partner something or relay a message in the chat.',
        parameters: {
          type: 'object',
          properties: {
            text: { type: 'string', description: 'The message text to send (1-2000 chars)' },
          },
          required: ['text'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_xp_stats',
        description: 'Get XP and leveling information for a user. Use when they ask about their level, progress, or XP.',
        parameters: {
          type: 'object',
          properties: {
            user: { type: 'string', enum: ['khentsgdz', 'clairjassen', 'both'], description: 'Which user to get stats for (default: both)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'search_anime',
        description: 'Search for anime titles using the Jikan (MyAnimeList) API. Use when they ask about anime, want recommendations, or mention an anime title.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Anime search query (title, genre, or description)' },
          },
          required: ['query'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'add_book_to_our_books',
        description: 'Search Open Library for a book and add it to Khent & Clair\'s shared "Our Books" list. Use when they want to add a book to their shared reading list. If search_books returned multiple candidates, you may pass open_library_key to pick the exact one.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Book search query (title, author name, or ISBN)' },
            open_library_key: { type: 'string', description: 'Open Library key from a prior search_books result (e.g., "/works/OL123W") — use when disambiguating' },
          },
          required: ['query'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'read_starlight_jar',
        description: 'Read the most recent notes saved in the Starlight Jar. Use when they ask what is in the jar or want to revisit saved notes and memories.',
        parameters: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Number of recent notes to read (default 10, max 25)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_watchlist',
        description: 'Read Khent & Clair\'s current shared cinema watchlist. Use when they ask what is on their list or what they have been planning to watch.',
        parameters: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Number of items per person to read (default 15, max 40)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'remember_fact',
        description: 'Save a personal fact about Khent or Clair to Mochi\'s long-term memory. Use when they explicitly tell you something to remember about themselves, each other, or their relationship.',
        parameters: {
          type: 'object',
          properties: {
            fact: { type: 'string', description: 'The fact to remember, phrased naturally (e.g., "Khent prefers black coffee")' },
            category: { type: 'string', enum: ['fact', 'preference', 'dislike', 'goal', 'date', 'habit'], description: 'Category of the fact (default: fact)' },
          },
          required: ['fact'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'read_memories',
        description: 'Browse or search Mochi\'s long-term memory book. Use when they want to see what you remember, search a memory, or review facts.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Optional search text' },
            category: { type: 'string', description: 'Optional category filter (fact, preference, dislike, goal, date, habit)' },
            limit: { type: 'number', description: 'Max memories to return (default 20, max 50)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'pin_memory',
        description: 'Pin or unpin a memory so it is always remembered. Use when they say a fact is important or to highlight a favorite memory.',
        parameters: {
          type: 'object',
          properties: {
            memory_id: { type: 'string', description: 'Memory document ID from read_memories' },
            pinned: { type: 'boolean', description: 'true to pin, false to unpin' },
          },
          required: ['memory_id', 'pinned'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'delete_memory',
        description: 'Delete a memory from Mochi\'s long-term memory. Use when they ask to forget something or remove an incorrect fact. Requires confirm=true after showing the user what will be deleted.',
        parameters: {
          type: 'object',
          properties: {
            memory_id: { type: 'string', description: 'Memory document ID from read_memories' },
            confirm: { type: 'boolean', description: 'Set true to confirm deletion after user approval' },
          },
          required: ['memory_id'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'edit_memory',
        description: 'Edit the text of an existing memory. Use when they want to correct or update a remembered fact.',
        parameters: {
          type: 'object',
          properties: {
            memory_id: { type: 'string', description: 'Memory document ID from read_memories' },
            fact: { type: 'string', description: 'The corrected fact text' },
            category: { type: 'string', enum: ['fact', 'preference', 'dislike', 'goal', 'date', 'habit'], description: 'Optional new category' },
          },
          required: ['memory_id', 'fact'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'web_search',
        description: 'Search the web for current information, news, prices, facts, or anything not covered by other tools. Use when they ask about recent events, current info, or topics outside Everglow\'s own data. Returns ranked results with titles, snippets, and URLs.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Search query (keywords or natural language)' },
            domain_type: { type: 'string', enum: ['web', 'news', 'research_paper'], description: 'Search type (default: web). Use "news" for recent articles with dates.' },
            recency_minutes: { type: 'number', description: 'Only return results newer than this many minutes (e.g. 1440 for last 24h). Cannot combine with after_date/before_date.' },
            after_date: { type: 'string', description: 'Only return results after this date (YYYY-MM-DD).' },
            before_date: { type: 'string', description: 'Only return results before this date (YYYY-MM-DD).' },
            location: { type: 'string', description: 'Country code for geo-relevant results (e.g. "PH", "US"). Default: PH.' },
            include_domains: { type: 'string', description: 'Comma-separated domains to restrict results to (e.g. "github.com,arxiv.org").' },
            exclude_domains: { type: 'string', description: 'Comma-separated domains to exclude (e.g. "pinterest.com,quora.com").' },
          },
          required: ['query'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'read_web_page',
        description: 'Fetch and read the full content of one or more web pages (up to 3). Use after web_search when a snippet is not enough to answer well.',
        parameters: {
          type: 'object',
          properties: {
            urls: {
              type: 'array',
              items: { type: 'string' },
              description: 'URLs to fetch (1-3)',
            },
          },
          required: ['urls'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'mark_watchlist_item_watched',
        description: 'Mark a movie or show on the shared cinema watchlist as watched. Use when they finish something or ask to update their list.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Movie or show title to mark as watched' },
          },
          required: ['title'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'update_book_progress',
        description: 'Update progress (0-100) for a book in the shared "Our Books" list. Progress 100 also marks it read for the caller.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Book title to update' },
            progress: { type: 'number', description: 'Progress percentage 0-100' },
          },
          required: ['title', 'progress'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'add_xp',
        description: 'Award XP to the caller for a completed activity or achievement inside Everglow. Be generous — every 200 XP is a level up, so meaningful moments deserve 20-50 XP and small wins 10-20.',
        parameters: {
          type: 'object',
          properties: {
            amount: { type: 'number', description: 'XP amount (1-100, default 25)' },
            reason: { type: 'string', description: 'Short reason for the XP' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'send_note_to_partner',
        description: 'Send a private note from one partner to the other through Mochi. Use when they ask you to pass a message, note, or reminder to their partner.',
        parameters: {
          type: 'object',
          properties: {
            note: { type: 'string', description: 'The note content' },
          },
          required: ['note'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_relationship_insights',
        description: 'Find gentle patterns in their moods and activities, like shared rhythms or recurring date-night habits.',
        parameters: {
          type: 'object',
          properties: {},
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_memory_trivia',
        description: 'Generate a mini memory-trivia game from real facts Mochi remembers about Khent and Clair.',
        parameters: {
          type: 'object',
          properties: {
            count: { type: 'number', description: 'Number of questions (default 5, max 10)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_today_recap',
        description: 'Compile a short, warm recap of today in Everglow: moods, activities, watchlist, starlight notes, and on-this-day memories.',
        parameters: {
          type: 'object',
          properties: {},
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_gallery',
        description: 'Read recent photos from the Gallery. Use when they ask about their photos or memories.',
        parameters: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Number of photos to fetch (default 10, max 20)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_garden',
        description: 'Read the garden plants and their growth. Use when they ask about their garden or plants.',
        parameters: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Number of plants to fetch (default 10, max 20)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_canvas',
        description: 'Read recent canvas drawings. Use when they ask about drawings or art.',
        parameters: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Number of drawings to fetch (default 10, max 20)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'search_spotify',
        description: 'Search Spotify for tracks by artist and title. Use when they ask about music or want to find a song.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Search query (e.g., "Ethel Cain Crush" or "artist - track")' },
            artist: { type: 'string', description: 'Artist name (optional if query contains artist)' },
            track: { type: 'string', description: 'Track name (optional if query contains track)' },
          },
          required: ['query'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'remove_from_watchlist',
        description: 'Remove a movie or show from the shared watchlist. Use when they ask to remove or delete something from the list. Requires confirm=true after showing what will be removed.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Title substring to match' },
            tmdb_id: { type: 'number', description: 'Exact TMDB ID to remove (optional)' },
            confirm: { type: 'boolean', description: 'Set true to confirm removal after user approval' },
          },
          required: ['title'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'search_everglow',
        description: 'Unified search across Everglow — movies (TMDB), books (Open Library), anime (Jikan), and music (Spotify) in one call. Use when they ask for broad recommendations or to find something without knowing the domain.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Search query for all domains' },
          },
          required: ['query'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'plan_date_night',
        description: 'Plan a complete date night by combining date ideas, weather for a location, and watchlist suggestions. Use when they ask to plan a date or a night together.',
        parameters: {
          type: 'object',
          properties: {
            location: { type: 'string', description: 'City for weather (default Cabadbaran)' },
            count: { type: 'number', description: 'Number of date ideas (default 3, max 5)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'add_calendar_event',
        description: 'Create a calendar event for Khent & Clair. Use when they want to schedule something, add a date night, anniversary, reminder, or any event to the shared calendar.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Event title' },
            description: { type: 'string', description: 'Optional description' },
            date: { type: 'string', description: 'ISO 8601 date/time (e.g., 2026-09-10T19:00:00) or YYYY-MM-DD' },
            end_date: { type: 'string', description: 'Optional end date/time ISO 8601' },
            type: { type: 'string', enum: ['dateNight','anniversary','reminder','custom'], description: 'Event type (default custom)' },
            location: { type: 'string', description: 'Optional location' },
            is_all_day: { type: 'boolean', description: 'Whether all-day event' },
          },
          required: ['title','date'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'create_journal_entry',
        description: 'Create a journal entry for Khent or Clair. Use when they want to write, reflect, save a memory, or log something personal.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Entry title' },
            content: { type: 'string', description: 'Entry content (markdown supported, 1-5000 chars)' },
            category: { type: 'string', enum: ['daily','gratitude','memory','letter','dream','idea'], description: 'Category (default daily)' },
            mood: { type: 'string', enum: ['happy','calm','loved','excited','tired','sad','stressed','neutral'], description: 'Optional mood' },
            tags: { type: 'array', items: { type: 'string' }, description: 'Optional tags' },
          },
          required: ['title','content'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'add_bucket_item',
        description: 'Add an item to the shared bucket list. Use when they mention a dream, goal, wish, or something they want to do together.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Bucket item title' },
            description: { type: 'string', description: 'Optional details' },
            category: { type: 'string', enum: ['travel','experience','food','adventure','milestone','other'], description: 'Category (default other)' },
            priority: { type: 'string', enum: ['low','medium','high','urgent'], description: 'Priority (default medium)' },
            due_date: { type: 'string', description: 'Optional due date ISO 8601' },
          },
          required: ['title'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'add_trip',
        description: 'Create a new trip in the travel planner. Use when they want to plan a trip or getaway.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Trip title (e.g., Batanes Getaway)' },
            description: { type: 'string', description: 'Optional description' },
            start_date: { type: 'string', description: 'Start date ISO 8601 YYYY-MM-DD' },
            end_date: { type: 'string', description: 'End date ISO 8601 YYYY-MM-DD' },
            budget: { type: 'number', description: 'Optional budget estimate' },
          },
          required: ['title','start_date','end_date'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'add_trip_pin',
        description: 'Add a pin/stop to an existing trip. Use when they want to add a place to visit on a trip.',
        parameters: {
          type: 'object',
          properties: {
            trip_id: { type: 'string', description: 'Trip document ID (from add_trip or existing trips)' },
            trip_title: { type: 'string', description: 'Alternative: trip title to match (if id unknown)' },
            title: { type: 'string', description: 'Pin title (place name)' },
            note: { type: 'string', description: 'Optional note' },
            lat: { type: 'number', description: 'Latitude' },
            lng: { type: 'number', description: 'Longitude' },
            category: { type: 'string', enum: ['stay','eat','sight','activity','transit'], description: 'Pin category (default sight)' },
          },
          required: ['title'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'log_habit',
        description: 'Create or log a wellness habit. Use when they want to track a habit, workout, or streak.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Habit title' },
            description: { type: 'string', description: 'Optional description' },
            category: { type: 'string', enum: ['health','fitness','mindfulness','learning','social','other'], description: 'Category (default health)' },
            frequency: { type: 'string', enum: ['daily','weekly','custom'], description: 'Frequency (default daily)' },
          },
          required: ['title'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'complete_habit',
        description: 'Mark a habit as completed for today (increments streak). Use when they say they did a habit or workout.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Habit title to match' },
            habit_id: { type: 'string', description: 'Optional habit document ID' },
          },
          required: ['title'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_calendar_events',
        description: 'Read upcoming calendar events. Use when they ask what is scheduled, upcoming dates, or what is on the calendar.',
        parameters: {
          type: 'object',
          properties: {
            days: { type: 'number', description: 'Days ahead to fetch (default 14, max 60)' },
            limit: { type: 'number', description: 'Max events (default 10, max 20)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_bucket_list',
        description: 'Read the bucket list. Use when they ask about dreams, wishes, or what they want to do together.',
        parameters: {
          type: 'object',
          properties: {
            status: { type: 'string', enum: ['wish','planned','completed','all'], description: 'Filter by status (default all)' },
            limit: { type: 'number', description: 'Max items (default 10, max 20)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_journal_entries',
        description: 'Read recent journal entries. Use when they want to revisit memories or see what was written.',
        parameters: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Max entries (default 5, max 10)' },
            category: { type: 'string', enum: ['daily','gratitude','memory','letter','dream','idea','all'], description: 'Filter category (default all)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'search_journal_entries',
        description: 'Search journal entries across all time by keyword, topic, category, author, or tag. Use when they ask about specific past memories, topics, dates, or reflections.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Keyword or phrase to search for in entry title, content, or tags' },
            category: { type: 'string', enum: ['daily','gratitude','memory','letter','dream','idea','all'], description: 'Filter by category (default all)' },
            author: { type: 'string', description: 'Filter by author (e.g. khentsgdz or clairjassen)' },
            tag: { type: 'string', description: 'Filter by specific tag' },
            limit: { type: 'number', description: 'Max matching entries to return (default 5, max 20)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'read_journal_entry',
        description: 'Read the complete, full unabridged text and all details of a specific journal entry. Always use this whenever you need to read every single word, letter, or quote from an entry found via search_journal_entries or get_journal_entries.',
        parameters: {
          type: 'object',
          properties: {
            id: { type: 'string', description: 'The Firestore document ID of the journal entry (from search_journal_entries or get_journal_entries)' },
            title: { type: 'string', description: 'The title of the journal entry (fallback if id is not known)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_trips',
        description: 'Read trips from the travel planner. Use when they ask about upcoming trips or travel plans.',
        parameters: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Max trips (default 5, max 10)' },
          },
        },
      },
    },
  ];

  function selectToolsForRequest(reqFeature, userMsg) {
    if (reqFeature === 'guardian') {
      const allowed = new Set(['set_mood', 'save_to_starlight_jar', 'remember_fact', 'get_xp_stats']);
      return MOCHI_TOOLS.filter(t => allowed.has(t.function.name));
    }
    if (reqFeature === 'study') {
      const allowed = new Set(['web_search', 'read_web_page', 'remember_fact', 'read_memories', 'search_books']);
      return MOCHI_TOOLS.filter(t => allowed.has(t.function.name));
    }
    const trimmed = String(userMsg || '').trim().toLowerCase();
    const isPureGreeting = /^(hi|hello|hey|good morning|good afternoon|good evening|good night|mew|prr|nya|love you|i love you|we love you)[!.,\s]*$/i.test(trimmed);
    if (isPureGreeting) {
      const coreAllowed = new Set([
        'set_mood',
        'save_to_starlight_jar',
        'remember_fact',
        'read_memories',
        'get_today_recap',
        'get_relationship_insights',
      ]);
      return MOCHI_TOOLS.filter(t => coreAllowed.has(t.function.name));
    }
    return MOCHI_TOOLS;
  }

  // Tools: custom Mochi tools (dynamically pruned for feature and greetings)
  const tools = selectToolsForRequest(feature, lastUserMessage);

  // Thinking mode: pass enableThinking: true from the client for enhanced reasoning.
  // Agnes uses chat_template_kwargs.enable_thinking instead of reasoning_effort.
  // enableThinking is already destructured from req.body above.

  // ── Payload size guard ──────────────────────────────
  // Cloud Run max request size is 32MB; Agnes supports up to 512K context.
  // Trim aggressively as best-effort so the model doesn't
  // waste context on stale history, but don't hard-block — let Agnes handle
  // it if trimming can't fit within Cloud Run's limit.
  // Output budget: a self-contained HTML game can approach the ~30KB
  // artifact cap (~8k tokens) before visible text + thinking tokens, so
  // 8k truncates games mid-block (no closing fence = no Preview button).
  const agnesBody = JSON.stringify({
    model,
    messages: nimMessages,
    tools,
    max_tokens: 16384,
    temperature: 0.6,
    top_p: 0.95,
    stream: req.body.stream === true,
    ...(enableThinkingFlag ? { chat_template_kwargs: { enable_thinking: true } } : {}),
  });
  let agnesBodyBytes = Buffer.byteLength(agnesBody, 'utf8');
  console.log('[proxyAI] Payload size before trim:', (agnesBodyBytes / 1024 / 1024).toFixed(2), 'MB');
  if (agnesBodyBytes > 8 * 1024 * 1024) {
    // Phase 1: Remove oldest conversation message pairs (keep system + recent)
    while (agnesBodyBytes > 8 * 1024 * 1024 && nimMessages.length > 4) {
      nimMessages.splice(1, 2);
      const trimmedBody = JSON.stringify({
        model,
        messages: nimMessages,
        tools,
        max_tokens: 16384,
        temperature: 0.6,
        top_p: 0.95,
        stream: req.body.stream === true,
        ...(enableThinkingFlag ? { chat_template_kwargs: { enable_thinking: true } } : {}),
      });
      agnesBodyBytes = Buffer.byteLength(trimmedBody, 'utf8');
    }
    // Phase 2: If still too large, trim system prompt content
    if (agnesBodyBytes > 8 * 1024 * 1024 && nimMessages[0]?.content) {
      let sysContent = nimMessages[0].content;
      const pcIdx = sysContent.indexOf('## Previous Conversations');
      if (pcIdx !== -1) {
        const nextSec = sysContent.indexOf('\n## ', pcIdx + 1);
        sysContent = sysContent.substring(0, pcIdx) + (nextSec !== -1 ? sysContent.substring(nextSec) : '');
      }
      const testPayload = JSON.stringify({ ...JSON.parse(agnesBody), messages: [{ role: 'system', content: sysContent }, ...nimMessages.slice(1)] });
      if (Buffer.byteLength(testPayload, 'utf8') > 8 * 1024 * 1024) {
        const ssIdx = sysContent.indexOf('## Past Session Summaries');
        if (ssIdx !== -1) {
          const nextSec = sysContent.indexOf('\n## ', ssIdx + 1);
          sysContent = sysContent.substring(0, ssIdx) + (nextSec !== -1 ? sysContent.substring(nextSec) : '');
        }
      }
      let hardTrimTest = JSON.stringify({ ...JSON.parse(agnesBody), messages: [{ role: 'system', content: sysContent }, ...nimMessages.slice(1)] });
      while (Buffer.byteLength(hardTrimTest, 'utf8') > 8 * 1024 * 1024 && sysContent.length > 2000) {
        sysContent = sysContent.substring(0, Math.floor(sysContent.length * 0.8)) + '\n… [context trimmed for size]';
        hardTrimTest = JSON.stringify({ ...JSON.parse(agnesBody), messages: [{ role: 'system', content: sysContent }, ...nimMessages.slice(1)] });
      }
      nimMessages[0].content = sysContent;
      const finalBody = JSON.stringify({
        model,
        messages: nimMessages,
        tools,
        max_tokens: 16384,
        temperature: 0.6,
        top_p: 0.95,
        stream: req.body.stream === true,
        ...(enableThinkingFlag ? { chat_template_kwargs: { enable_thinking: true } } : {}),
      });
      agnesBodyBytes = Buffer.byteLength(finalBody, 'utf8');
    }
    console.log('[proxyAI] Payload size after trim:', (agnesBodyBytes / 1024 / 1024).toFixed(2), 'MB');
  }

  // ── Tool Execution ───────────────────────────────────
  const TOOL_TIMEOUT_MS = 25000;
  const MAX_TOOL_ROUNDS = 8;

  async function executeTool(toolName, args, callerUid) {
    const db = getAdmin().firestore();
    const timeout = (ms) => new Promise((_, reject) =>
      setTimeout(() => reject(new Error('Tool timeout')), ms));

    try {
      return await Promise.race([
        (async () => {
          switch (toolName) {
            case 'add_to_watchlist': {
              // W2-A3: Support tmdb_id disambiguation + candidate return
              const mediaType = args.media_type || 'movie';
              const providedId = args.tmdb_id || args.tmdbId || args.tmdbId === 0 ? Number(args.tmdb_id || args.tmdbId) : null;
              if (providedId) {
                // Direct fetch by ID for disambiguated choice
                const detailKey = `tmdb:detail:${mediaType}:${providedId}`;
                let detail;
                const cachedDetail = _getExternalCache(detailKey, _EXTERNAL_CACHE_TTLS.tmdb);
                if (cachedDetail) {
                  detail = cachedDetail;
                } else {
                  const detailRes = await fetch(
                    `https://api.themoviedb.org/3/${mediaType === 'tv' ? 'tv' : 'movie'}/${providedId}?api_key=${getTmdbKey()}`
                  );
                  if (!detailRes.ok) return JSON.stringify({ error: `TMDB ID ${providedId} not found for ${mediaType}` });
                  detail = await detailRes.json();
                  _setExternalCache(detailKey, detail);
                }
                const title = detail.title || detail.name || String(args.title || '').trim();
                if (!title) return JSON.stringify({ error: 'No title found for that TMDB ID' });
                await db.collection('our_cinema').add({
                  tmdbId: providedId,
                  title,
                  mediaType,
                  posterPath: detail.poster_path ? `https://image.tmdb.org/t/p/w500${detail.poster_path}` : null,
                  addedBy: callerUid,
                  addedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                  status: 'plan_to_watch',
                });
                return JSON.stringify({ success: true, title, tmdbId: providedId });
              }
              const queryRaw = String(args.title || '').trim();
              if (!queryRaw) return JSON.stringify({ error: 'No title provided' });
              const tmdbCacheKey = `tmdb:add:${mediaType}:${queryRaw.toLowerCase()}`;
              let tmdbData;
              const cachedTmdb = _getExternalCache(tmdbCacheKey, _EXTERNAL_CACHE_TTLS.tmdb);
              if (cachedTmdb) {
                tmdbData = cachedTmdb;
              } else {
                const tmdbRes = await fetch(
                  `https://api.themoviedb.org/3/search/${mediaType === 'multi' ? 'multi' : mediaType}?query=${encodeURIComponent(queryRaw)}&api_key=${getTmdbKey()}`
                );
                tmdbData = await tmdbRes.json();
                _setExternalCache(tmdbCacheKey, tmdbData);
              }
              const results = (tmdbData.results || []).filter(r => r.title || r.name);
              if (results.length === 0) return JSON.stringify({ error: `No results found for "${queryRaw}"` });
              // W2-A3 disambiguation: if query not exact and multiple candidates share substring, ask to confirm
              const qLower = queryRaw.toLowerCase();
              const exact = results.find(r => (r.title || r.name || '').toLowerCase() === qLower);
              const substringMatches = results.filter(r => {
                const t = (r.title || r.name || '').toLowerCase();
                return t.includes(qLower) || qLower.includes(t);
              }).slice(0, 3);
              const isAmbiguous = !exact && substringMatches.length >= 2;
              if (isAmbiguous) {
                const candidates = substringMatches.map(r => ({
                  tmdbId: r.id,
                  title: r.title || r.name,
                  year: (r.release_date || r.first_air_date || '').slice(0, 4),
                  mediaType: r.media_type || mediaType,
                  overview: (r.overview || '').slice(0, 180),
                  popularity: r.popularity || 0,
                }));
                return JSON.stringify({
                  needs_confirmation: true,
                  message: `Found multiple matches for "${queryRaw}". Ask the user which one they mean and re-call add_to_watchlist with the chosen tmdb_id.`,
                  candidates,
                });
              }
              const result = results[0];
              await db.collection('our_cinema').add({
                tmdbId: result.id,
                title: result.title || result.name,
                mediaType: result.media_type || mediaType,
                posterPath: result.poster_path ? `https://image.tmdb.org/t/p/w500${result.poster_path}` : null,
                addedBy: callerUid,
                addedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                status: 'plan_to_watch',
              });
              return JSON.stringify({ success: true, title: result.title || result.name, tmdbId: result.id });
            }
            case 'save_to_starlight_jar': {
              await db.collection('starlight_jar').add({
                content: args.note,
                author: callerUid,
                timestamp: getAdmin().firestore.FieldValue.serverTimestamp(),
                writtenBy: 'Mochi 🍡',
              });
              return JSON.stringify({ success: true });
            }
            case 'set_mood': {
              const today = new Date().toISOString().slice(0, 10);
              await db.collection('moods').doc(`${callerUid}_${today}`).set({
                mood: args.mood,
                note: args.note || null,
                uid: callerUid,
                date: today,
                timestamp: getAdmin().firestore.FieldValue.serverTimestamp(),
              }, { merge: true });
              return JSON.stringify({ success: true, mood: args.mood });
            }
            case 'search_movies': {
              const mediaType = args.media_type || 'multi';
              const endpoint = mediaType === 'multi' ? 'multi' : args.media_type;
              const cacheKey = `tmdb:search:${endpoint}:${String(args.query || '').toLowerCase().trim()}`;
              let tmdbData;
              const cached = _getExternalCache(cacheKey, _EXTERNAL_CACHE_TTLS.tmdb);
              if (cached) {
                tmdbData = cached;
              } else {
                const tmdbRes = await fetch(
                  `https://api.themoviedb.org/3/search/${endpoint}?query=${encodeURIComponent(args.query)}&api_key=${getTmdbKey()}`
                );
                tmdbData = await tmdbRes.json();
                _setExternalCache(cacheKey, tmdbData);
              }
              const results = (tmdbData.results || [])              .slice(0, 8).map(r => ({
                id: r.id,
                title: r.title || r.name,
                year: (r.release_date || r.first_air_date || '').slice(0, 4),
                mediaType: r.media_type || args.media_type || 'movie',
                overview: (r.overview || '').slice(0, 400),
              }));
              return JSON.stringify({ results });
            }
            case 'get_weather': {
              const wKey = `weather:${String(args.location || '').toLowerCase().trim()}`;
              const cachedWeather = _getExternalCache(wKey, _EXTERNAL_CACHE_TTLS.weather);
              if (cachedWeather) return JSON.stringify({ location: args.location, weather: cachedWeather });
              const weatherRes = await fetch(
                `https://wttr.in/${encodeURIComponent(args.location)}?format=%C+%t+%h+%w`,
                { headers: { 'User-Agent': 'curl/8.5.0' } }
              );
              const weatherText = await weatherRes.text();
              const trimmed = weatherText.trim();
              _setExternalCache(wKey, trimmed);
              return JSON.stringify({ location: args.location, weather: trimmed });
            }
            case 'create_reminder': {
              // W1-A2: Parse remind_at into a Firestore Timestamp for the
              // scheduled checker. Accepts ISO 8601 or common relatives.
              let remindAtTs = null;
              const rawRemind = String(args.remind_at || '').trim();
              if (rawRemind) {
                const parsed = new Date(rawRemind);
                if (!Number.isNaN(parsed.getTime())) {
                  remindAtTs = getAdmin().firestore.Timestamp.fromDate(parsed);
                } else if (/tomorrow/i.test(rawRemind)) {
                  const d = new Date(Date.now() + 24 * 60 * 60 * 1000);
                  const timeMatch = rawRemind.match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)?/i);
                  if (timeMatch) {
                    let h = parseInt(timeMatch[1], 10);
                    const m = timeMatch[2] ? parseInt(timeMatch[2], 10) : 0;
                    const ap = (timeMatch[3] || '').toLowerCase();
                    if (ap === 'pm' && h < 12) h += 12;
                    if (ap === 'am' && h === 12) h = 0;
                    d.setHours(h, m, 0, 0);
                  }
                  remindAtTs = getAdmin().firestore.Timestamp.fromDate(d);
                }
              }
              await db.collection('reminders').add({
                title: args.title,
                note: args.note || null,
                remindAt: args.remind_at,
                remindAtTs,
                fired: false,
                createdBy: callerUid,
                createdAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                read: false,
              });
              return JSON.stringify({ success: true, title: args.title, remindAt: args.remind_at, scheduled: !!remindAtTs });
            }
            case 'log_activity': {
              await db.collection('recent_activity').add({
                activity: args.activity,
                category: args.category || 'other',
                loggedBy: callerUid,
                timestamp: getAdmin().firestore.FieldValue.serverTimestamp(),
              });
              return JSON.stringify({ success: true });
            }
            case 'search_books': {
              const bKey = `books:search:${String(args.query || '').toLowerCase().trim()}`;
              let searchData;
              const cachedBooks = _getExternalCache(bKey, _EXTERNAL_CACHE_TTLS.books);
              if (cachedBooks) {
                searchData = cachedBooks;
              } else {
                const searchRes = await fetch(
                  `https://openlibrary.org/search.json?q=${encodeURIComponent(args.query)}&limit=5&fields=key,title,author_name,first_publish_year,isbn,cover_i`
                );
                searchData = await searchRes.json();
                _setExternalCache(bKey, searchData);
              }
              const books = (searchData.docs || []).slice(0, 5).map(b => ({
                title: b.title,
                authors: (b.author_name || []).slice(0, 2).join(', '),
                year: b.first_publish_year || null,
                coverId: b.cover_i || null,
                openLibraryKey: b.key || null,
              }));
              return JSON.stringify({ results: books });
            }
            case 'add_book_to_our_books': {
              const queryRaw = String(args.query || '').trim();
              if (!queryRaw) return JSON.stringify({ error: 'No query provided' });
              const providedKey = args.open_library_key || args.openLibraryKey || null;
              const abKey = `books:add:${queryRaw.toLowerCase()}`;
              let searchData;
              const cachedAb = _getExternalCache(abKey, _EXTERNAL_CACHE_TTLS.books);
              if (cachedAb) {
                searchData = cachedAb;
              } else {
                const searchRes = await fetch(
                  `https://openlibrary.org/search.json?q=${encodeURIComponent(queryRaw)}&limit=5&fields=key,title,author_name,first_publish_year,isbn,cover_i`
                );
                searchData = await searchRes.json();
                _setExternalCache(abKey, searchData);
              }
              const docs = (searchData.docs || []).filter(d => d.title);
              if (docs.length === 0) return JSON.stringify({ error: `No book found for "${queryRaw}"` });
              let book = null;
              if (providedKey) {
                const normKey = String(providedKey).trim();
                book = docs.find(d => d.key === normKey) || docs[0];
              } else {
                // W2-A3 disambiguation: if multiple substring matches and no exact, return candidates
                const qLower = queryRaw.toLowerCase();
                const exact = docs.find(d => (d.title || '').toLowerCase() === qLower);
                const subMatches = docs.filter(d => {
                  const t = (d.title || '').toLowerCase();
                  return t.includes(qLower) || qLower.includes(t);
                }).slice(0, 3);
                const isAmbiguous = !exact && subMatches.length >= 2;
                if (isAmbiguous) {
                  const candidates = subMatches.map(b => ({
                    openLibraryKey: b.key,
                    title: b.title,
                    authors: (b.author_name || []).slice(0, 2).join(', '),
                    year: b.first_publish_year || null,
                    coverId: b.cover_i || null,
                  }));
                  return JSON.stringify({
                    needs_confirmation: true,
                    message: `Found multiple books for "${queryRaw}". Ask the user which one they mean and re-call with the chosen open_library_key.`,
                    candidates,
                  });
                }
                book = docs[0];
              }
              if (!book) return JSON.stringify({ error: `No book found for "${queryRaw}"` });
              const title = book.title || 'Unknown';
              const author = (book.author_name || []).slice(0, 2).join(', ');
              await db.collection('our_books').add({
                title,
                author,
                coverUrl: book.cover_i ? `https://covers.openlibrary.org/b/id/${book.cover_i}-M.jpg` : '',
                year: book.first_publish_year ? String(book.first_publish_year) : '',
                workKey: book.key || '',
                addedBy: callerUid,
                addedAt: new Date().toISOString(),
              });
              return JSON.stringify({ success: true, title, author, openLibraryKey: book.key || null });
            }
            case 'read_starlight_jar': {
              const limit = Math.min(args.limit || 10, 25);
              const snapshot = await db.collection('starlight_jar')
                .orderBy('timestamp', 'desc')
                .limit(limit)
                .get();
              const notes = snapshot.docs.map(d => {
                const data = d.data();
                return {
                  content: (data.content || '').slice(0, 300),
                  author: data.author || 'mochi',
                  time: data.timestamp?.toDate?.()?.toISOString() || null,
                };
              });
              return JSON.stringify({ notes, count: notes.length });
            }
            case 'get_watchlist': {
              const limit = Math.min(args.limit || 15, 40);
              const parts = [];
              for (const username of ['khentsgdz', 'clairjassen']) {
                const snapshot = await db.collection('our_cinema')
                  .where('userId', '==', username)
                  .orderBy('addedAt', 'desc')
                  .limit(limit)
                  .get();
                const items = snapshot.docs.map(d => {
                  const x = d.data();
                  return `${x.title || 'Unknown'} (${x.mediaType || 'movie'}) - ${x.status || 'plan to watch'}`;
                });
                if (items.length) parts.push(`${username}'s watchlist:\n${items.join('\n')}`);
              }
              return JSON.stringify({ watchlist: parts.length ? parts.join('\n\n') : 'Watchlist is empty' });
            }
            case 'get_date_ideas': {
              const count = Math.min(args.count || 3, 10);
              const snapshot = await db.collection('date_ideas').limit(100).get();
              const allIdeas = snapshot.docs.map(d => d.data().title || d.data().name || '').filter(Boolean);
              // Random selection
              const shuffled = allIdeas.sort(() => Math.random() - 0.5);
              return JSON.stringify({ ideas: shuffled.slice(0, count) });
            }
            case 'read_chat_messages': {
              const limit = Math.min(args.limit || 20, 50);
              let query = db.collection('sanctuary_messages')
                .orderBy('timestamp', 'desc')
                .limit(limit);
              const chatSnap = await query.get();
              let messages = chatSnap.docs.map(d => {
                const data = d.data();
                return {
                  sender: data.sender || data.senderUid || 'unknown',
                  text: (data.text || data.content || '').slice(0, 500),
                  timestamp: data.timestamp?.toDate?.()?.toISOString() || null,
                };
              });
              // Filter by sender if specified
              if (args.sender && args.sender !== 'both') {
                messages = messages.filter(m => m.sender === args.sender);
              }
              // Reverse to chronological order
              messages.reverse();
              return JSON.stringify({ messages, count: messages.length });
            }
            case 'get_xp_stats': {
              const users = ['khentsgdz', 'clairjassen'];
              const targetUsers = args.user && args.user !== 'both'
                ? [args.user]
                : users;
              const stats = {};
              for (const uid of targetUsers) {
                const doc = await db.collection('users').doc(uid).collection('progress').doc('main').get();
                if (doc.exists) {
                  const d = doc.data();
                  stats[uid] = {
                    level: d.level || 1,
                    xpTotal: d.xpTotal || 0,
                    streak: d.streak || 0,
                  };
                } else {
                  stats[uid] = { level: 1, xpTotal: 0, streak: 0 };
                }
              }
              return JSON.stringify({ stats });
            }
            case 'search_anime': {
              const aKey = `anime:search:${String(args.query || '').toLowerCase().trim()}`;
              let animeData;
              const cachedAnime = _getExternalCache(aKey, _EXTERNAL_CACHE_TTLS.anime);
              if (cachedAnime) {
                animeData = cachedAnime;
              } else {
                const animeRes = await fetch(
                  `https://api.jikan.moe/v4/anime?q=${encodeURIComponent(args.query)}&limit=5&sfw=true`
                );
                animeData = await animeRes.json();
                _setExternalCache(aKey, animeData);
              }
              const anime = (animeData.data || []).slice(0, 5).map(a => ({
                title: a.title,
                titleEnglish: a.title_english || null,
                episodes: a.episodes || null,
                score: a.score || null,
                status: a.status || null,
                synopsis: (a.synopsis || '').slice(0, 300),
                genres: (a.genres || []).map(g => g.name),
                malId: a.mal_id || null,
              }));
              return JSON.stringify({ results: anime });
            }
            case 'remember_fact': {
              const fact = (args.fact || '').trim();
              if (!fact) return JSON.stringify({ error: 'No fact provided' });
              const parsed = parseFactStructure(fact);
              const emb = await getEmbedding(fact).catch(() => null);
              await db.collection('ai_memories').doc('shared').collection('facts').add({
                fact,
                category: args.category || 'fact',
                subject: args.subject || parsed.subject || null,
                relation: args.relation || parsed.relation || null,
                object: args.object || parsed.object || null,
                occurredAt: args.occurred_at || args.occurredAt || null,
                addedBy: callerUid || 'mochi',
                createdAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                confidence: 1.0,
                accessCount: 0,
                lastAccessed: null,
                pinned: false,
                source: callerUid || 'mochi',
                embedding: emb, // W4-C9 scaffold
              });
              return JSON.stringify({
                success: true,
                fact,
                subject: args.subject || parsed.subject,
                relation: args.relation || parsed.relation,
                object: args.object || parsed.object,
              });
            }
            case 'read_memories': {
              const limit = Math.min(args.limit || 20, 50);
              let query = db.collection('ai_memories').doc('shared').collection('facts')
                .orderBy('createdAt', 'desc')
                .limit(300);
              const snapshot = await query.get();
              let facts = snapshot.docs.map(d => {
                const data = d.data();
                return {
                  id: d.id,
                  fact: data.fact || '',
                  category: data.category || 'fact',
                  subject: data.subject || null,
                  relation: data.relation || null,
                  object: data.object || null,
                  occurredAt: data.occurredAt?.toDate?.()?.toISOString() || null,
                  pinned: data.pinned === true,
                };
              }).filter(f => f.fact);
              if (args.category) {
                facts = facts.filter(f => f.category === args.category);
              }
              if (args.query) {
                const queryLower = String(args.query).toLowerCase();
                facts = rankMemories(facts, queryLower, limit);
              } else {
                facts = facts.slice(0, limit);
              }
              return JSON.stringify({ memories: facts, count: facts.length });
            }
            case 'mark_watchlist_item_watched': {
              const title = (args.title || '').trim();
              if (!title) return JSON.stringify({ error: 'No title provided' });
              const snapshot = await db.collection('our_cinema').get();
              const matches = snapshot.docs.filter(d => {
                const t = (d.data().title || '').toLowerCase();
                return t.includes(title.toLowerCase()) || title.toLowerCase().includes(t);
              });
              if (matches.length === 0) {
                return JSON.stringify({ error: `No watchlist item found for "${title}"` });
              }
              const batch = db.batch();
              for (const doc of matches) {
                batch.update(doc.ref, {
                  status: 'watched',
                  watchedBy: callerUid,
                  watchedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                });
              }
              await batch.commit();
              return JSON.stringify({
                success: true,
                title: matches[0].data().title || title,
                updated: matches.length,
              });
            }
            case 'update_book_progress': {
              const title = (args.title || '').trim();
              const progress = Math.min(Math.max(Number(args.progress) || 0, 0), 100);
              if (!title) return JSON.stringify({ error: 'No title provided' });
              const snapshot = await db.collection('our_books').get();
              const matches = snapshot.docs.filter(d => {
                const t = (d.data().title || '').toLowerCase();
                return t.includes(title.toLowerCase()) || title.toLowerCase().includes(t);
              });
              if (matches.length === 0) {
                return JSON.stringify({ error: `No book found for "${title}"` });
              }
              const field = callerUid === 'khentsgdz' ? 'khentReadAt' : 'clairReadAt';
              const readFlag = progress >= 100
                ? getAdmin().firestore.FieldValue.serverTimestamp()
                : null;
              const batch = db.batch();
              for (const doc of matches.slice(0, 3)) {
                batch.update(doc.ref, {
                  progress: progress,
                  [field]: readFlag,
                  lastUpdatedBy: callerUid,
                  lastUpdatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                });
              }
              await batch.commit();
              return JSON.stringify({
                success: true,
                title: matches[0].data().title || title,
                progress,
                read: progress >= 100,
              });
            }
            case 'add_xp': {
              const amount = Math.min(Math.max(Number(args.amount) || 25, 1), 100);
              const uid = callerUid || 'khentsgdz';
              const ref = db.collection('users').doc(uid).collection('progress').doc('main');
              const doc = await ref.get();
              const current = (doc.exists && doc.data()?.xpTotal) || 0;
              const xpTotal = current + amount;
              const level = levelForXp(xpTotal);
              await ref.set({
                xpTotal,
                level,
                streak: doc.exists ? (doc.data()?.streak || 0) : 0,
                lastAwardReason: args.reason || 'Mochi award',
                lastAwardedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
              }, { merge: true });
              return JSON.stringify({ success: true, uid, amount, xpTotal, level });
            }
            case 'send_note_to_partner': {
              const note = (args.note || '').trim();
              if (!note) return JSON.stringify({ error: 'No note provided' });
              const partnerUid = PARTNER_UID[callerUid];
              if (!partnerUid) return JSON.stringify({ error: 'Unknown partner for this user' });
              await db.collection('mochi_notes').add({
                from: callerUid,
                to: partnerUid,
                content: note,
                read: false,
                createdAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                writtenBy: 'Mochi 🍡',
              });
              await sendFCMToUser(partnerUid, {
                title: '💌 Mochi has a note for you',
                body: note.slice(0, 120),
                data: { type: 'mochi_note', from: callerUid },
              });
              return JSON.stringify({ success: true, to: partnerUid });
            }
            case 'get_relationship_insights': {
              const [moodSnap, activitySnap] = await Promise.all([
                db.collection('moods').orderBy('timestamp', 'desc').limit(100).get(),
                db.collection('recent_activity').orderBy('timestamp', 'desc').limit(20).get(),
              ]);
              const moods = moodSnap.docs.map(d => d.data().mood || d.data().moodEmoji || '');
              const activities = activitySnap.docs.map(
                d => d.data().activity || d.data().description || ''
              );
              const insights = computeInsights({ moods, activities });
              return JSON.stringify({ insights });
            }
            case 'get_memory_trivia': {
              const count = Math.min(args.count || 5, 10);
              const snapshot = await db.collection('ai_memories').doc('shared').collection('facts')
                .orderBy('createdAt', 'desc')
                .limit(150)
                .get();
              const facts = snapshot.docs.map(d => {
                const data = d.data();
                return {
                  fact: data.fact || '',
                  subject: data.subject || null,
                  relation: data.relation || null,
                  object: data.object || null,
                  occurredAt: data.occurredAt?.toDate?.() || null,
                };
              });
              const questions = generateTrivia(facts, count);
              return JSON.stringify({ questions });
            }
            case 'get_today_recap': {
              const today = new Date().toISOString().slice(0, 10);
              const [moodSnap, activitySnap, watchSnap, starSnap, memorySnap] = await Promise.all([
                db.collection('moods').where('date', '==', today).get(),
                db.collection('recent_activity').orderBy('timestamp', 'desc').limit(5).get(),
                db.collection('our_cinema').limit(5).get(),
                db.collection('starlight_jar').orderBy('timestamp', 'desc').limit(3).get(),
                db.collection('ai_memories').doc('shared').collection('facts')
                  .orderBy('createdAt', 'desc').limit(300).get(),
              ]);
              const recap = composeTodayRecap({
                dateLabel: today,
                moods: moodSnap.docs.map(d => ({
                  uid: d.data().uid || 'someone',
                  mood: d.data().mood || 'okay',
                })),
                activities: activitySnap.docs.map(
                  d => d.data().activity || d.data().description || ''
                ),
                watchlist: watchSnap.docs.map(d => d.data().title || '').filter(Boolean),
                starlight: starSnap.docs.map(d => d.data().content || '').filter(Boolean),
                memories: memorySnap.docs.map(d => {
                  const data = d.data();
                  return {
                    fact: data.fact || '',
                    occurredAt: data.occurredAt?.toDate?.() || null,
                  };
                }),
              });
              return JSON.stringify({ recap, date: today });
            }
            case 'plan_date_night': {
              const location = (args.location || 'Cabadbaran').trim();
              const count = Math.min(args.count || 3, 5);
              const pKey = `weather:${location.toLowerCase()}`;
              const cachedPlanWeather = _getExternalCache(pKey, _EXTERNAL_CACHE_TTLS.weather);
              let weatherText = cachedPlanWeather || null;
              const [ideaSnap, watchSnap, fetchedWeather] = await Promise.all([
                db.collection('date_ideas').limit(100).get(),
                db.collection('our_cinema').limit(5).get(),
                weatherText ? Promise.resolve(null) : fetch(`https://wttr.in/${encodeURIComponent(location)}?format=%C+%t+%h+%w`, {
                  headers: { 'User-Agent': 'curl/8.5.0' },
                }),
              ]);
              if (!weatherText && fetchedWeather) {
                weatherText = (await fetchedWeather.text()).trim();
                _setExternalCache(pKey, weatherText);
              }
              weatherText = weatherText || 'Weather unavailable';
              const allIdeas = ideaSnap.docs
                .map(d => d.data().title || d.data().name || '')
                .filter(Boolean);
              const shuffled = [...allIdeas].sort(() => Math.random() - 0.5);
              const watchlist = watchSnap.docs
                .map(d => d.data().title || '')
                .filter(Boolean)
                .slice(0, 2);
              return JSON.stringify({
                location,
                weather: weatherText || 'Weather unavailable',
                ideas: shuffled.slice(0, count),
                watchlist,
                suggestion: [
                  `Start with ${shuffled[0] || 'a cozy evening'}`,
                  watchlist.length
                    ? `then finish the night with "${watchlist[0]}"`
                    : 'then just talk until late',
                ].join(', '),
              });
            }
            case 'send_sanctuary_message': {
              const text = String(args.text || '').trim();
              if (!text) return JSON.stringify({ error: 'No text provided' });
              if (text.length > 2000) return JSON.stringify({ error: 'Message too long (max 2000)' });
              // Resolve sender username from callerUid (already verified)
              const sender = (callerUid || 'mochi').toLowerCase();
              await db.collection('sanctuary_messages').add({
                text,
                sender,
                senderUid: sender,
                timestamp: getAdmin().firestore.FieldValue.serverTimestamp(),
                via: 'mochi',
                createdBy: callerUid,
              });
              // Notify partner (reuse FCM helper)
              const partnerMap = { khentsgdz: 'clairjassen', clairjassen: 'khentsgdz' };
              const partner = partnerMap[sender];
              if (partner) {
                await sendFCMToUser(partner, {
                  title: `💌 New message from ${sender === 'khentsgdz' ? 'Khent' : 'Clair'} via Mochi`,
                  body: text.slice(0, 120),
                  data: { type: 'chat_message', sender },
                });
              }
              return JSON.stringify({ success: true, text: text.slice(0, 200) });
            }
            case 'pin_memory': {
              const mid = String(args.memory_id || '').trim();
              if (!mid) return JSON.stringify({ error: 'memory_id required' });
              const pinned = !!args.pinned;
              const ref = db.collection('ai_memories').doc('shared').collection('facts').doc(mid);
              const snap = await ref.get();
              if (!snap.exists) return JSON.stringify({ error: `Memory ${mid} not found` });
              await ref.update({ pinned, lastAccessed: getAdmin().firestore.FieldValue.serverTimestamp() });
              return JSON.stringify({ success: true, memory_id: mid, pinned });
            }
            case 'delete_memory': {
              const mid = String(args.memory_id || '').trim();
              if (!mid) return JSON.stringify({ error: 'memory_id required' });
              const ref = db.collection('ai_memories').doc('shared').collection('facts').doc(mid);
              const snap = await ref.get();
              if (!snap.exists) return JSON.stringify({ error: `Memory ${mid} not found` });
              const factText = snap.data()?.fact || '';
              if (!args.confirm) {
                return JSON.stringify({ needs_confirmation: true, message: `Delete this memory? "${factText.slice(0,180)}" — re-call delete_memory with confirm:true to proceed.`, memory_id: mid, fact: factText });
              }
              // Soft-delete to trash for undo (retain 7 days)
              try {
                await db.collection('ai_memories_trash').add({
                  originalId: mid,
                  fact: factText,
                  category: snap.data()?.category || 'fact',
                  deletedBy: callerUid,
                  deletedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                  originalData: snap.data(),
                });
              } catch (_) {}
              await ref.delete();
              return JSON.stringify({ success: true, memory_id: mid, fact: factText, undo_hint: 'Use undo if needed within 7 days' });
            }
            case 'edit_memory': {
              const mid = String(args.memory_id || '').trim();
              const fact = String(args.fact || '').trim();
              if (!mid || !fact) return JSON.stringify({ error: 'memory_id and fact required' });
              if (fact.length > 500) return JSON.stringify({ error: 'Fact too long (max 500)' });
              const ref = db.collection('ai_memories').doc('shared').collection('facts').doc(mid);
              const snap = await ref.get();
              if (!snap.exists) return JSON.stringify({ error: `Memory ${mid} not found` });
              const parsed = parseFactStructure(fact);
              const update = {
                fact,
                subject: parsed.subject || null,
                relation: parsed.relation || null,
                object: parsed.object || null,
                lastAccessed: getAdmin().firestore.FieldValue.serverTimestamp(),
              };
              if (args.category) update.category = String(args.category).trim().toLowerCase();
              await ref.update(update);
              return JSON.stringify({ success: true, memory_id: mid, fact, category: update.category || snap.data()?.category || 'fact' });
            }
            case 'get_gallery': {
              const limit = Math.min(Math.max(Number(args.limit) || 10, 1), 20);
              const snap = await db.collection('gallery').orderBy('createdAt', 'desc').limit(limit).get();
              if (snap.empty) return JSON.stringify({ photos: [], count: 0 });
              const photos = snap.docs.map(d => {
                const data = d.data();
                return {
                  caption: (data.caption || '').slice(0, 200),
                  uploadedBy: data.uploadedBy || data.author || '',
                  imageUrl: data.imageUrl ? '[image]' : '',
                  createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
                };
              });
              return JSON.stringify({ photos, count: photos.length });
            }
            case 'get_garden': {
              const limit = Math.min(Math.max(Number(args.limit) || 10, 1), 20);
              const snap = await db.collection('garden_plants').orderBy('plantedAt', 'desc').limit(limit).get();
              if (snap.empty) return JSON.stringify({ plants: [], count: 0 });
              const plants = snap.docs.map(d => {
                const data = d.data();
                return {
                  name: data.name || data.plantName || 'Plant',
                  status: data.status || 'growing',
                  plantedBy: data.plantedBy || '',
                  plantedAt: data.plantedAt?.toDate?.()?.toISOString() || null,
                };
              });
              return JSON.stringify({ plants, count: plants.length });
            }
            case 'get_canvas': {
              const limit = Math.min(Math.max(Number(args.limit) || 10, 1), 20);
              const snap = await db.collection('canvas_drawings').orderBy('createdAt', 'desc').limit(limit).get();
              if (snap.empty) return JSON.stringify({ drawings: [], count: 0 });
              const drawings = snap.docs.map(d => {
                const data = d.data();
                return {
                  title: data.title || 'Untitled',
                  drawnBy: data.drawnBy || data.createdBy || '',
                  createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
                };
              });
              return JSON.stringify({ drawings, count: drawings.length });
            }
            case 'search_spotify': {
              const q = String(args.query || args.track || '').trim();
              const artist = String(args.artist || '').trim();
              const track = String(args.track || '').trim();
              const query = q || (artist && track ? `${artist} ${track}` : '') || artist || track;
              if (!query) return JSON.stringify({ error: 'No query provided' });
              const sKey = `spotify:search:${query.toLowerCase()}`;
              let cached = _getExternalCache(sKey, 10 * 60 * 1000);
              if (cached) return JSON.stringify(cached);
              const token = await _getSpotifyAppToken();
              if (!token) return JSON.stringify({ error: 'Spotify not configured' });
              try {
                const url = 'https://api.spotify.com/v1/search?' + new URLSearchParams({ q: query, type: 'track', limit: '5', market: 'US' }).toString();
                const r = await fetch(url, { headers: { 'Authorization': 'Bearer ' + token }, signal: AbortSignal.timeout(10000) });
                if (!r.ok) return JSON.stringify({ error: `Spotify search failed ${r.status}` });
                const data = await r.json();
                const items = data.tracks && data.tracks.items;
                if (!Array.isArray(items) || items.length === 0) return JSON.stringify({ tracks: [], count: 0 });
                const tracks = items.slice(0, 5).map(t => ({
                  trackId: t.id,
                  trackName: t.name,
                  artistName: (t.artists && t.artists[0] && t.artists[0].name) || '',
                  albumName: (t.album && t.album.name) || '',
                  imageUrl: (t.album && t.album.images && t.album.images[0] && t.album.images[0].url) || null,
                  spotifyUrl: 'https://open.spotify.com/track/' + t.id,
                }));
                const result = { tracks, count: tracks.length };
                _setExternalCache(sKey, result);
                return JSON.stringify(result);
              } catch (e) {
                return JSON.stringify({ error: e.message });
              }
            }
            case 'remove_from_watchlist': {
              const title = String(args.title || '').trim();
              const tid = args.tmdb_id ? Number(args.tmdb_id) : (args.tmdbId ? Number(args.tmdbId) : null);
              if (!title && !tid) return JSON.stringify({ error: 'Provide title or tmdb_id' });
              let snap;
              if (tid) {
                snap = await db.collection('our_cinema').where('tmdbId', '==', tid).limit(5).get();
              } else {
                snap = await db.collection('our_cinema').get();
              }
              let matches = snap.docs;
              if (!tid) {
                const qLower = title.toLowerCase();
                matches = snap.docs.filter(d => {
                  const t = (d.data().title || '').toLowerCase();
                  return t.includes(qLower) || qLower.includes(t);
                });
              }
              if (matches.length === 0) return JSON.stringify({ error: `No watchlist item found for "${title || tid}"` });
              const preview = matches.slice(0, 3).map(d => d.data().title || '');
              if (!args.confirm) {
                return JSON.stringify({ needs_confirmation: true, message: `Remove from watchlist? ${preview.join(', ')} — re-call remove_from_watchlist with confirm:true to proceed.`, preview, count: preview.length });
              }
              const batch = db.batch();
              for (const doc of matches.slice(0, 3)) batch.delete(doc.ref);
              await batch.commit();
              return JSON.stringify({ success: true, removed: preview, count: preview.length });
            }
            case 'search_everglow': {
              const query = String(args.query || '').trim();
              if (!query) return JSON.stringify({ error: 'No query provided' });
              const qLower = query.toLowerCase();
              const cacheKey = `everglow:search:${qLower}`;
              const cachedEver = _getExternalCache(cacheKey, _EXTERNAL_CACHE_TTLS.tmdb);
              if (cachedEver) return JSON.stringify(cachedEver);
              // Parallel searches: movies, books, anime, spotify (best-effort)
              const [moviesRes, booksRes, animeRes, spotifyRes] = await Promise.allSettled([
                (async () => {
                  const k = getTmdbKey();
                  if (!k) return [];
                  const r = await fetch(`https://api.themoviedb.org/3/search/multi?query=${encodeURIComponent(query)}&api_key=${k}`, { signal: AbortSignal.timeout(8000) });
                  const d = await r.json();
                  return (d.results || []).slice(0, 3).map(x => ({ title: x.title || x.name, year: (x.release_date || x.first_air_date || '').slice(0,4), type: x.media_type || 'movie' }));
                })(),
                (async () => {
                  const r = await fetch(`https://openlibrary.org/search.json?q=${encodeURIComponent(query)}&limit=3&fields=key,title,author_name,first_publish_year`, { signal: AbortSignal.timeout(8000) });
                  const d = await r.json();
                  return (d.docs || []).slice(0, 3).map(b => ({ title: b.title, authors: (b.author_name||[]).slice(0,2).join(', '), type: 'book' }));
                })(),
                (async () => {
                  const r = await fetch(`https://api.jikan.moe/v4/anime?q=${encodeURIComponent(query)}&limit=3&sfw=true`, { signal: AbortSignal.timeout(8000) });
                  const d = await r.json();
                  return (d.data || []).slice(0, 3).map(a => ({ title: a.title, type: 'anime', score: a.score }));
                })(),
                (async () => {
                  const token = await _getSpotifyAppToken();
                  if (!token) return [];
                  const url = 'https://api.spotify.com/v1/search?' + new URLSearchParams({ q: query, type: 'track', limit: '3', market: 'US' }).toString();
                  const r = await fetch(url, { headers: { 'Authorization': 'Bearer ' + token }, signal: AbortSignal.timeout(8000) });
                  const d = await r.json();
                  const items = d.tracks?.items || [];
                  return items.slice(0,3).map(t=>({ title: t.name, artist: t.artists?.[0]?.name || '', type: 'track' }));
                })(),
              ]);
              const result = {
                query,
                movies: moviesRes.status === 'fulfilled' ? moviesRes.value : [],
                books: booksRes.status === 'fulfilled' ? booksRes.value : [],
                anime: animeRes.status === 'fulfilled' ? animeRes.value : [],
                tracks: spotifyRes.status === 'fulfilled' ? spotifyRes.value : [],
              };
              _setExternalCache(cacheKey, result);
              return JSON.stringify(result);
            }
            case 'add_calendar_event': {
              const title = String(args.title || '').trim();
              if (!title) return JSON.stringify({ error: 'title required' });
              const dateStr = String(args.date || args.start_date || '').trim();
              if (!dateStr) return JSON.stringify({ error: 'date required' });
              let date = new Date(dateStr);
              if (Number.isNaN(date.getTime())) return JSON.stringify({ error: `Invalid date: ${dateStr}` });
              let endDate = null;
              if (args.end_date) {
                const ed = new Date(String(args.end_date).trim());
                if (!Number.isNaN(ed.getTime())) endDate = ed;
              }
              const type = ['dateNight','anniversary','reminder','custom'].includes(String(args.type||'')) ? String(args.type) : 'custom';
              const data = {
                title,
                description: String(args.description||''),
                date: getAdmin().firestore.Timestamp.fromDate(date),
                type,
                createdBy: callerUid,
                color: null,
                recurring: 'none',
                location: args.location ? String(args.location) : null,
                attendees: [],
                isAllDay: !!args.is_all_day,
              };
              if (endDate) data.endDate = getAdmin().firestore.Timestamp.fromDate(endDate);
              const ref = await db.collection('calendar_events').add(data);
              return JSON.stringify({ success: true, id: ref.id, title, date: date.toISOString() });
            }
            case 'create_journal_entry': {
              const title = String(args.title||'').trim();
              const content = String(args.content||'').trim();
              if (!title || !content) return JSON.stringify({ error: 'title and content required' });
              if (content.length > 5000) return JSON.stringify({ error: 'content too long (max 5000)' });
              const cat = ['daily','gratitude','memory','letter','dream','idea'].includes(String(args.category||'')) ? String(args.category) : 'daily';
              const moodVal = String(args.mood||'').trim().toLowerCase();
              const validMoods = ['happy','calm','loved','excited','tired','sad','stressed','neutral'];
              const now = new Date();
              const entry = {
                title,
                content,
                author: callerUid.toLowerCase(),
                createdAt: getAdmin().firestore.Timestamp.fromDate(now),
                updatedAt: getAdmin().firestore.Timestamp.fromDate(now),
                category: cat,
                tags: Array.isArray(args.tags) ? args.tags.map(String).slice(0,10) : [],
                isPinned: false,
                isLocked: false,
                wordCount: content.trim().split(/\s+/).filter(Boolean).length,
                monthDay: `${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`,
                searchKey: `${title.toLowerCase()} ${content.toLowerCase().slice(0,500)}`,
              };
              if (validMoods.includes(moodVal)) entry.mood = moodVal;
              const ref = await db.collection('journal_entries').add(entry);
              return JSON.stringify({ success: true, id: ref.id, title });
            }
            case 'add_bucket_item': {
              const title = String(args.title||'').trim();
              if (!title) return JSON.stringify({ error: 'title required' });
              const cat = ['travel','experience','food','adventure','milestone','other'].includes(String(args.category||'')) ? String(args.category) : 'other';
              const pri = ['low','medium','high','urgent'].includes(String(args.priority||'')) ? String(args.priority) : 'medium';
              let dueDate = null;
              if (args.due_date) {
                const d = new Date(String(args.due_date));
                if (!Number.isNaN(d.getTime())) dueDate = d;
              }
              const data = {
                title,
                description: String(args.description||''),
                category: cat,
                status: 'wish',
                createdBy: callerUid,
                createdAt: getAdmin().firestore.Timestamp.now(),
                notes: '',
                priority: pri,
              };
              if (dueDate) data.dueDate = getAdmin().firestore.Timestamp.fromDate(dueDate);
              const ref = await db.collection('bucket_list').add(data);
              return JSON.stringify({ success: true, id: ref.id, title, category: cat });
            }
            case 'add_trip': {
              const title = String(args.title||'').trim();
              if (!title) return JSON.stringify({ error: 'title required' });
              const sd = new Date(String(args.start_date||''));
              const ed = new Date(String(args.end_date||''));
              if (Number.isNaN(sd.getTime()) || Number.isNaN(ed.getTime())) return JSON.stringify({ error: 'Invalid start_date or end_date' });
              const data = {
                title,
                description: String(args.description||''),
                coverUrl: '',
                startDate: getAdmin().firestore.Timestamp.fromDate(sd),
                endDate: getAdmin().firestore.Timestamp.fromDate(ed),
                status: 'planning',
                createdBy: callerUid,
                createdAt: getAdmin().firestore.Timestamp.now(),
                budgetEstimate: Number(args.budget)||0,
                currency: 'PHP',
                memberIds: ['khentsgdz','clairjassen'],
                searchKey: `${title.toLowerCase()} ${(args.description||'').toLowerCase()}`,
              };
              const ref = await db.collection('travel_trips').add(data);
              return JSON.stringify({ success: true, id: ref.id, title, start: sd.toISOString().slice(0,10), end: ed.toISOString().slice(0,10) });
            }
            case 'add_trip_pin': {
              const title = String(args.title||'').trim();
              if (!title) return JSON.stringify({ error: 'title required' });
              let tripId = String(args.trip_id||'').trim();
              if (!tripId && args.trip_title) {
                const tTitle = String(args.trip_title).trim().toLowerCase();
                const q = await db.collection('travel_trips').where('title','==', String(args.trip_title).trim()).limit(1).get();
                if (!q.empty) tripId = q.docs[0].id;
                else {
                  const all = await db.collection('travel_trips').limit(20).get();
                  const found = all.docs.find(d => (d.data().title||'').toLowerCase().includes(tTitle));
                  if (found) tripId = found.id;
                }
              }
              if (!tripId) return JSON.stringify({ error: 'trip_id or trip_title required and not found' });
              // Verify trip exists
              const tripSnap = await db.collection('travel_trips').doc(tripId).get();
              if (!tripSnap.exists) return JSON.stringify({ error: `Trip ${tripId} not found` });
              const lat = Number(args.lat)||0;
              const lng = Number(args.lng)||0;
              const cat = ['stay','eat','sight','activity','transit'].includes(String(args.category||'')) ? String(args.category) : 'sight';
              // Determine order
              const existing = await db.collection('travel_pins').where('tripId','==',tripId).get();
              const order = existing.size;
              const pin = {
                tripId,
                title,
                note: String(args.note||''),
                lat,
                lng,
                category: cat,
                order,
                createdBy: callerUid,
              };
              const ref = await db.collection('travel_pins').add(pin);
              return JSON.stringify({ success: true, id: ref.id, tripId, title });
            }
            case 'log_habit': {
              const title = String(args.title||'').trim();
              if (!title) return JSON.stringify({ error: 'title required' });
              const cat = ['health','fitness','mindfulness','learning','social','other'].includes(String(args.category||'')) ? String(args.category) : 'health';
              const freq = ['daily','weekly','custom'].includes(String(args.frequency||'')) ? String(args.frequency) : 'daily';
              // Check duplicate
              const existingH = await db.collection('habits').where('title','==',title).limit(1).get();
              if (!existingH.empty) return JSON.stringify({ success: false, error: `Habit "${title}" already exists`, id: existingH.docs[0].id });
              const data = {
                title,
                description: String(args.description||''),
                category: cat,
                frequency: freq,
                createdBy: callerUid,
                createdAt: getAdmin().firestore.Timestamp.now(),
                completedDates: [],
                streak: 0,
                longestStreak: 0,
                isActive: true,
              };
              const ref = await db.collection('habits').add(data);
              return JSON.stringify({ success: true, id: ref.id, title });
            }
            case 'complete_habit': {
              const title = String(args.title||'').trim();
              const hid = String(args.habit_id||'').trim();
              let docRef = null;
              let docSnap = null;
              if (hid) {
                docRef = db.collection('habits').doc(hid);
                docSnap = await docRef.get();
              } else {
                const q = await db.collection('habits').where('title','==',title).limit(1).get();
                if (q.empty) {
                  // try case-insensitive
                  const all = await db.collection('habits').limit(50).get();
                  const found = all.docs.find(d => (d.data().title||'').toLowerCase() === title.toLowerCase());
                  if (found) { docRef = found.ref; docSnap = found; } else return JSON.stringify({ error: `Habit "${title}" not found` });
                } else { docRef = q.docs[0].ref; docSnap = q.docs[0]; }
              }
              if (!docSnap.exists) return JSON.stringify({ error: 'Habit not found' });
              const data = docSnap.data();
              const now = new Date();
              const todayKey = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`;
              const completedDates = (data.completedDates||[]).map(d => {
                if (d.toDate) return d.toDate().toISOString().slice(0,10);
                return String(d).slice(0,10);
              });
              if (completedDates.includes(todayKey)) return JSON.stringify({ success: false, error: 'Already completed today', streak: data.streak||0 });
              // Compute streak - naive increment
              const newStreak = (data.streak||0)+1;
              const longest = Math.max(newStreak, data.longestStreak||0);
              await docRef.update({
                completedDates: getAdmin().firestore.FieldValue.arrayUnion(getAdmin().firestore.Timestamp.fromDate(now)),
                streak: newStreak,
                longestStreak: longest,
              });
              return JSON.stringify({ success: true, title: data.title, streak: newStreak, longestStreak: longest });
            }
            case 'get_calendar_events': {
              const days = Math.min(Math.max(Number(args.days)||14,1),60);
              const limit = Math.min(Math.max(Number(args.limit)||10,1),20);
              const now = new Date();
              const end = new Date(now.getTime()+days*24*60*60*1000);
              const snap = await db.collection('calendar_events')
                .where('date','>=', getAdmin().firestore.Timestamp.fromDate(now))
                .where('date','<=', getAdmin().firestore.Timestamp.fromDate(end))
                .orderBy('date','asc').limit(limit).get();
              if (snap.empty) return JSON.stringify({ events: [], count: 0 });
              const events = snap.docs.map(d => {
                const v = d.data();
                return { id: d.id, title: v.title||'', date: v.date?.toDate?.()?.toISOString()||null, type: v.type||'custom', location: v.location||null };
              });
              return JSON.stringify({ events, count: events.length });
            }
            case 'get_bucket_list': {
              const limit = Math.min(Math.max(Number(args.limit)||10,1),20);
              const status = String(args.status||'all').toLowerCase();
              let q = db.collection('bucket_list').orderBy('createdAt','desc').limit(limit);
              if (['wish','planned','completed'].includes(status)) q = db.collection('bucket_list').where('status','==',status).orderBy('createdAt','desc').limit(limit);
              const snap = await q.get();
              if (snap.empty) return JSON.stringify({ items: [], count: 0 });
              const items = snap.docs.map(d => {
                const v=d.data();
                return { id: d.id, title: v.title||'', status: v.status||'wish', category: v.category||'other', priority: v.priority||'medium' };
              });
              return JSON.stringify({ items, count: items.length });
            }
            case 'get_journal_entries': {
              const limit = Math.min(Math.max(Number(args.limit)||5,1),10);
              const cat = String(args.category||'all').toLowerCase();
              let q = db.collection('journal_entries').orderBy('createdAt','desc').limit(limit);
              if (['daily','gratitude','memory','letter','dream','idea'].includes(cat)) q = db.collection('journal_entries').where('category','==',cat).orderBy('createdAt','desc').limit(limit);
              const snap = await q.get();
              if (snap.empty) return JSON.stringify({ entries: [], count: 0 });
              const entries = snap.docs.map(d => {
                const v=d.data();
                return { id: d.id, title: v.title||'', category: v.category||'daily', preview: (v.content||'').slice(0,150), author: v.author||'' };
              });
              return JSON.stringify({ entries, count: entries.length, note: 'Call read_journal_entry with entry id to read the full unabridged content.' });
            }
            case 'search_journal_entries': {
              const query = String(args.query || '').trim().toLowerCase();
              const cat = String(args.category || 'all').toLowerCase();
              const author = String(args.author || '').trim().toLowerCase();
              const tag = String(args.tag || '').trim().toLowerCase();
              const limit = Math.min(Math.max(Number(args.limit) || 5, 1), 20);

              let q = db.collection('journal_entries');
              const validCategories = ['daily', 'gratitude', 'memory', 'letter', 'dream', 'idea'];
              if (validCategories.includes(cat)) {
                q = q.where('category', '==', cat);
              }
              q = q.orderBy('createdAt', 'desc').limit(100);
              const snap = await q.get();
              if (snap.empty) return JSON.stringify({ entries: [], count: 0, query });

              const queryTokens = query ? query.split(/\s+/).filter(Boolean) : [];

              const matched = snap.docs.map((d) => {
                const v = d.data();
                const title = String(v.title || '');
                const content = String(v.content || '');
                const entryAuthor = String(v.author || '').toLowerCase();
                const tags = Array.isArray(v.tags) ? v.tags.map((t) => String(t).toLowerCase()) : [];
                const category = String(v.category || 'daily');
                const mood = v.mood || null;
                const createdAt = v.createdAt?.toDate?.()?.toISOString()?.slice(0, 10) || null;

                if (author && !entryAuthor.includes(author)) return null;
                if (tag && !tags.some((t) => t.includes(tag))) return null;

                let score = 0;
                let snippet = '';

                if (queryTokens.length > 0) {
                  const lowerTitle = title.toLowerCase();
                  const lowerContent = content.toLowerCase();

                  if (lowerTitle.includes(query)) score += 10;
                  if (lowerContent.includes(query)) {
                    score += 5;
                    const idx = lowerContent.indexOf(query);
                    const start = Math.max(0, idx - 40);
                    const end = Math.min(content.length, idx + query.length + 80);
                    snippet = (start > 0 ? '...' : '') + content.slice(start, end).replace(/\n/g, ' ') + (end < content.length ? '...' : '');
                  }
                  if (tags.some((t) => t.includes(query))) score += 7;

                  for (const tok of queryTokens) {
                    if (lowerTitle.includes(tok)) score += 3;
                    if (tags.some((t) => t.includes(tok))) score += 2;
                    if (lowerContent.includes(tok)) score += 1;
                  }

                  if (score === 0) return null;
                } else {
                  score = 1;
                }

                if (!snippet) {
                  snippet = content.slice(0, 150).replace(/\n/g, ' ') + (content.length > 150 ? '...' : '');
                }

                return {
                  id: d.id,
                  title: title || 'Untitled',
                  date: createdAt,
                  author: v.author || '',
                  category,
                  mood,
                  tags: v.tags || [],
                  wordCount: v.wordCount || content.split(/\s+/).filter(Boolean).length,
                  snippet,
                  score,
                };
              }).filter(Boolean);

              matched.sort((a, b) => b.score - a.score);
              const results = matched.slice(0, limit);

              return JSON.stringify({
                entries: results,
                count: results.length,
                totalMatches: matched.length,
                note: 'To read the complete unabridged text of any entry, call read_journal_entry with its id.'
              });
            }
            case 'read_journal_entry': {
              const id = String(args.id || args.entry_id || args.entryId || '').trim();
              const title = String(args.title || '').trim();

              let doc = null;
              if (id) {
                const docSnap = await db.collection('journal_entries').doc(id).get();
                if (docSnap.exists) {
                  doc = docSnap;
                }
              }

              if (!doc && title) {
                const titleLower = title.toLowerCase();
                const snap = await db.collection('journal_entries').orderBy('createdAt', 'desc').limit(50).get();
                doc = snap.docs.find((d) => String(d.data().title || '').trim().toLowerCase() === titleLower)
                   || snap.docs.find((d) => String(d.data().title || '').toLowerCase().includes(titleLower));
              }

              if (!doc) {
                return JSON.stringify({
                  error: `Journal entry not found with ${id ? `id "${id}"` : ''}${id && title ? ' or ' : ''}${title ? `title "${title}"` : ''}. Use search_journal_entries to find the correct entry id.`
                });
              }

              const v = doc.data();
              const content = String(v.content || '');
              return JSON.stringify({
                success: true,
                id: doc.id,
                title: v.title || 'Untitled',
                content: content,
                author: v.author || '',
                category: v.category || 'daily',
                mood: v.mood || null,
                tags: Array.isArray(v.tags) ? v.tags : [],
                createdAt: v.createdAt?.toDate?.()?.toISOString() || null,
                updatedAt: v.updatedAt?.toDate?.()?.toISOString() || null,
                wordCount: v.wordCount || content.split(/\s+/).filter(Boolean).length,
                isPinned: Boolean(v.isPinned),
                isLocked: Boolean(v.isLocked),
              });
            }
            case 'get_trips': {
              const limit = Math.min(Math.max(Number(args.limit)||5,1),10);
              const snap = await db.collection('travel_trips').orderBy('startDate','asc').limit(limit).get();
              if (snap.empty) return JSON.stringify({ trips: [], count: 0 });
              const trips = snap.docs.map(d => {
                const v=d.data();
                return { id: d.id, title: v.title||'', start: v.startDate?.toDate?.()?.toISOString()?.slice(0,10)||null, end: v.endDate?.toDate?.()?.toISOString()?.slice(0,10)||null, status: v.status||'planning' };
              });
              return JSON.stringify({ trips, count: trips.length });
            }
            case 'web_search': {
              const apiKey = (process.env.TINYFISH_API_KEY || '').trim();
              if (!apiKey) return JSON.stringify({ error: 'Web search is not configured on the server yet.' });
              const query = String(args.query || '').trim();
              if (!query) return JSON.stringify({ error: 'No search query provided' });
              const location = String(args.location || 'PH').trim().toUpperCase();
              const language = 'en';
              const params = new URLSearchParams({ query, location, language });
              if (args.domain_type) params.set('domain_type', String(args.domain_type));
              if (args.recency_minutes) params.set('recency_minutes', String(Math.max(1, Math.floor(Number(args.recency_minutes)))));
              if (args.after_date && /^\d{4}-\d{2}-\d{2}$/.test(String(args.after_date))) params.set('after_date', String(args.after_date));
              if (args.before_date && /^\d{4}-\d{2}-\d{2}$/.test(String(args.before_date))) params.set('before_date', String(args.before_date));
              if (args.include_domains) params.set('include_domains', String(args.include_domains));
              if (args.exclude_domains) params.set('exclude_domains', String(args.exclude_domains));
              const searchKey = `websearch:${params.toString()}`;
              let searchData;
              const cachedSearch = _getExternalCache(searchKey, _EXTERNAL_CACHE_TTLS.web_search);
              if (cachedSearch) {
                searchData = cachedSearch;
              } else {
                const searchRes = await fetch(`https://api.search.tinyfish.ai?${params.toString()}`, {
                  headers: { 'X-API-Key': apiKey },
                });
                if (searchRes.status === 401 || searchRes.status === 403) return JSON.stringify({ error: 'Web search API key is invalid or forbidden.' });
                if (searchRes.status === 402) return JSON.stringify({ error: 'Web search account needs a top-up at agent.tinyfish.ai/wallet.' });
                if (searchRes.status === 429) return JSON.stringify({ error: 'Web search rate limit hit — try again in a minute.' });
                if (!searchRes.ok) return JSON.stringify({ error: `Web search failed (HTTP ${searchRes.status}).` });
                searchData = await searchRes.json();
                _setExternalCache(searchKey, searchData);
              }
              const results = (searchData.results || []).slice(0, 8).map(r => ({
                title: r.title || '',
                url: r.url || '',
                snippet: (r.snippet || '').slice(0, 300),
                site: r.site_name || '',
                date: r.date || null,
              }));
              return JSON.stringify({ query, results, total: searchData.total_results || results.length });
            }
            case 'read_web_page': {
              const apiKey = (process.env.TINYFISH_API_KEY || '').trim();
              if (!apiKey) return JSON.stringify({ error: 'Web page reading is not configured on the server yet.' });
              const urlsRaw = Array.isArray(args.urls) ? args.urls : [args.urls];
              const urls = urlsRaw.map(u => String(u || '').trim()).filter(u => /^https?:\/\//i.test(u)).slice(0, 3);
              if (urls.length === 0) return JSON.stringify({ error: 'No valid http(s) URLs provided' });
              const fetchKey = `webpage:${urls.join('|')}`;
              let fetchData;
              const cachedPage = _getExternalCache(fetchKey, _EXTERNAL_CACHE_TTLS.web_page);
              if (cachedPage) {
                fetchData = cachedPage;
              } else {
                const fetchRes = await fetch('https://api.fetch.tinyfish.ai', {
                  method: 'POST',
                  headers: { 'X-API-Key': apiKey, 'Content-Type': 'application/json' },
                  body: JSON.stringify({ urls, format: 'markdown' }),
                });
                if (fetchRes.status === 401 || fetchRes.status === 403) return JSON.stringify({ error: 'Web page reading API key is invalid or forbidden.' });
                if (fetchRes.status === 429) return JSON.stringify({ error: 'Web page reading rate limit hit — try again in a minute.' });
                if (!fetchRes.ok) return JSON.stringify({ error: `Web page reading failed (HTTP ${fetchRes.status}).` });
                fetchData = await fetchRes.json();
                _setExternalCache(fetchKey, fetchData);
              }
              const pages = (fetchData.results || []).map(r => ({
                url: r.url || '',
                title: r.title || '',
                content: (r.text || '').slice(0, 6000),
              }));
              const pageErrors = (fetchData.errors || []).map(e => ({ url: e.url || '', error: e.error || 'unknown' }));
              return JSON.stringify({ pages, errors: pageErrors });
            }
            default:
              return JSON.stringify({ error: `Unknown tool: ${toolName}` });
          }
        })(),
        timeout(TOOL_TIMEOUT_MS),
      ]);
    } catch (e) {
      return JSON.stringify({ error: e.message || 'Tool execution failed' });
    }
  }

  // ── Streaming mode (SSE) — immediate stream, tools handled post-stream ──
  if (req.body.stream === true) {
    // Set up SSE connection
    res.set('Content-Type', 'text/event-stream');
    res.set('Cache-Control', 'no-cache');
    res.set('Connection', 'keep-alive');
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Expose-Headers', '*');
    res.set('X-Content-Type-Options', 'nosniff');
    if (res.socket) res.socket.setNoDelay(true);
    res.flushHeaders();

    const sendEvent = (data) => {
      try { res.write(`data: ${JSON.stringify(data)}\n\n`); } catch (_) {}
    };

    // Keepalive ping every 15s during tool execution
    let keepaliveInterval = null;
    const startKeepalive = () => {
      keepaliveInterval = setInterval(() => {
        try { res.write(': keepalive\n\n'); } catch (_) {}
      }, 15000);
    };
    const stopKeepalive = () => {
      if (keepaliveInterval) { clearInterval(keepaliveInterval); keepaliveInterval = null; }
    };

    // Thinking heartbeat: while the model is still silently reasoning, send
    // a tick every 3s so the client can keep its "thinking" state alive.
    let heartbeatInterval = null;
    const startHeartbeat = () => {
      heartbeatInterval = setInterval(() => {
        try { sendEvent({ tool_status: 'thinking' }); } catch (_) {}
      }, 3000);
    };
    const stopHeartbeat = () => {
      if (heartbeatInterval) { clearInterval(heartbeatInterval); heartbeatInterval = null; }
    };

    try {
      // ── Stream directly — no blocking tool-detection round ──
      sendEvent({ tool_status: 'generating' });
      startKeepalive();
      startHeartbeat();

      let currentMessages = [...nimMessages];
      let toolRound = 0;
      let _streamedFinalReply = ''; // W1-C10: accumulate for server-side memory extract

      while (toolRound < MAX_TOOL_ROUNDS) {
        toolRound++;

        // Retry transient Agnes API errors (429, 502, 503) up to 2 times
        let streamResp = null;
        let lastFetchError = null;
        for (let attempt = 0; attempt < 3; attempt++) {
          try {
            streamResp = await fetch('https://apihub.agnes-ai.com/v1/chat/completions', {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${apiKey}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                model,
                messages: currentMessages,
                tools,
                tool_choice: 'auto',
                max_tokens: 16384,
                temperature: 0.6,
                top_p: 0.95,
                stream: true,
                ...(enableThinkingFlag ? { chat_template_kwargs: { enable_thinking: true } } : {}),
              }),
              signal: AbortSignal.timeout(120000),
            });

            if (streamResp.ok) break; // success
            if (![429, 502, 503].includes(streamResp.status)) break; // non-retryable
            lastFetchError = `Agnes HTTP ${streamResp.status}`;
          } catch (fetchErr) {
            lastFetchError = fetchErr.message;
          }
          // Exponential backoff before retry
          if (attempt < 2) await new Promise(r => setTimeout(r, 1000 * (attempt + 1)));
        }

        if (!streamResp || !streamResp.ok) {
          console.warn(`proxyAI Agnes fetch failed after retries: ${lastFetchError || streamResp?.status}`);
          try {
            const fallback = composeTodayRecap({ dateLabel: new Date().toISOString().slice(0,10), moods: [], activities: [], watchlist: [], starlight: [], memories: [], insights: [] });
            sendEvent({ content: fallback + " 🍡 Mochi is a little sleepy right now, but I'm still here. Try again in a moment?" });
            sendEvent({ tool_status: 'done' });
            sendEvent('[DONE]');
            stopKeepalive(); stopHeartbeat();
            return;
          } catch (_) {
            sendEvent({ error: 'Mochi got distracted and lost her train of thought. Try asking again?' });
          }
          break;
        }

        // Collect the full response while streaming to client
        let fullContent = '';
        let collectedToolCalls = [];
        let currentToolCall = null;

        const reader = streamResp.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split('\n');
          buffer = lines.pop() || '';
          for (const line of lines) {
            if (!line.startsWith('data: ')) continue;
            const raw = line.slice(6).trim();
            if (raw === '[DONE]') break;
            try {
              const parsed = JSON.parse(raw);
              const delta = parsed.choices?.[0]?.delta || {};
              const finishReason = parsed.choices?.[0]?.finish_reason;

              // Stream content tokens to client immediately
              if (delta.reasoning) sendEvent({ reasoning: delta.reasoning });
              if (delta.reasoning_content) sendEvent({ reasoning: delta.reasoning_content });
              if (delta.content) {
                fullContent += delta.content;
                _streamedFinalReply += delta.content;
                sendEvent({ content: delta.content });
                stopHeartbeat();
              }

              // Collect tool calls from stream deltas
              if (delta.tool_calls) {
                for (const tc of delta.tool_calls) {
                  if (tc.index !== undefined) {
                    if (!collectedToolCalls[tc.index]) {
                      collectedToolCalls[tc.index] = { id: tc.id || '', type: 'function', function: { name: '', arguments: '' } };
                    }
                    const existing = collectedToolCalls[tc.index];
                    if (tc.id) existing.id = tc.id;
                    if (tc.function?.name) existing.function.name += tc.function.name;
                    if (tc.function?.arguments) existing.function.arguments += tc.function.arguments;
                  }
                }
              }

              // Detect tool calls from finish_reason
              if (finishReason === 'tool_calls') {
                collectedToolCalls = collectedToolCalls.filter(Boolean);
              }
            } catch (_) {}
          }
        }

        // If no tool calls, we're done — stream completed naturally
        if (collectedToolCalls.length === 0) {
          break;
        }

        // ── Execute tool calls found in the stream ──
        sendEvent({ tool_status: 'executing' });

        // Build assistant message with tool_calls
        currentMessages.push({
          role: 'assistant',
          content: fullContent || null,
          tool_calls: collectedToolCalls.map(tc => ({
            id: tc.id,
            type: 'function',
            function: { name: tc.function.name, arguments: tc.function.arguments },
          })),
        });

        // Execute collected tools concurrently to minimize latency
        const toolPromises = collectedToolCalls.map(async (tc) => {
          const fnName = tc.function.name;
          let fnArgs;
          try { fnArgs = JSON.parse(tc.function.arguments); } catch { fnArgs = {}; }

          sendEvent({ tool_status: fnName });
          const toolStartedAt = Date.now();
          let result;
          try {
            result = await executeTool(fnName, fnArgs, caller);
          } catch (err) {
            result = JSON.stringify({ error: err.message || 'Tool execution failed' });
          }

          // Invalidate feature context block if this tool mutated persisted data
          if (TOOL_INVALIDATIONS[fnName]) {
            try { invalidateContextBlock(TOOL_INVALIDATIONS[fnName]); } catch (_) {}
          }

          try {
            if (typeof logToolCall === 'function') {
              // fire-and-forget: don't block tool loop on observability write
              logToolCall(fnName, caller, result, Date.now() - toolStartedAt).catch(() => {});
            }
          } catch (_) {}

          // Send rich tool result to client for inline cards
          try {
            const parsed = JSON.parse(result);
            sendEvent({ tool_result: { tool: fnName, ...parsed } });
            // Also send a friendly status for UI (e.g., needs_confirmation)
            if (parsed.needs_confirmation) {
              sendEvent({ tool_status: `${fnName}:needs_confirmation` });
            }
          } catch (_) {
            sendEvent({ tool_result: { tool: fnName, raw: result } });
          }

          return {
            role: 'tool',
            tool_call_id: tc.id,
            name: fnName,
            content: result,
          };
        });

        const executedResults = await Promise.all(toolPromises);
        for (const tr of executedResults) {
          currentMessages.push(tr);
        }

        sendEvent({ tool_status: `round_${toolRound}_done` });
        collectedToolCalls = [];
        fullContent = '';
      }

      stopKeepalive();
      stopHeartbeat();
      sendEvent({ tool_status: 'done' });
      sendEvent('[DONE]');
      // W1-C10 + W2-A4: fire-and-forget memory extraction (with heuristic gate) & hallucination check
      if (_streamedFinalReply.trim()) {
        if (shouldExtractMemory(lastUserMessage, _streamedFinalReply)) {
          serverExtractAndSaveMemory(lastUserMessage, _streamedFinalReply, caller).catch(() => {});
        }
        checkHallucinations(_streamedFinalReply).catch(() => {});
      }
    } catch (e) {
      console.warn('proxyAI streaming error:', e.message);
      sendEvent({ error: 'Mochi got distracted and lost her train of thought. Try asking again?' });
      sendEvent('[DONE]');
    } finally {
      stopKeepalive();
      stopHeartbeat();
      res.end();
    }
    return;
  }

  async function callAgnes() {
    const resp = await fetch(
      'https://apihub.agnes-ai.com/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: model,
          messages: nimMessages,
          tools,
          tool_choice: 'auto',
          max_tokens: 16384,
          temperature: 0.6,
          top_p: 0.95,
          stream: false,
          ...(enableThinkingFlag ? { chat_template_kwargs: { enable_thinking: true } } : {}),
        }),
        signal: AbortSignal.timeout(60000),
      },
    );
    return resp;
  }

  let response = null;
  let lastError = null;

  response = await callAgnes();

  if (!response || !response.ok) {
    const errStatus = response ? response.status : 502;
    const errBody = lastError ? lastError.body : 'No response from Agnes';
    // Special-case 413 (Payload Too Large) — pass through Agnes's detail
    if (errStatus === 413) {
      console.error('[proxyAI] Agnes returned 413:', errBody);
      return res.status(413).json({
        error: `Payload too large. ${errBody}`,
        model: model,
      });
    }
    res.status(errStatus).json({
      error: `Agnes returned ${errStatus}`,
      detail: errBody,
      model: lastError ? lastError.model : model,
    });
    return;
  }

  // ── Non-streaming mode ──────────────────────────────
  const data = await response.json();
  const message = data.choices?.[0]?.message || {};
  const reply = (message.content || '').trim();
  const reasoning = message.reasoning || '';
  res.json({ reply, reasoning, model: data.model || model });
  // W1-C10 + W2-A4: fire-and-forget memory extraction (with heuristic gate) & hallucination check
  if (reply) {
    if (shouldExtractMemory(lastUserMessage, reply)) {
      serverExtractAndSaveMemory(lastUserMessage, reply, caller).catch(() => {});
    }
    checkHallucinations(reply).catch(() => {});
  }
}

module.exports = {
  handleProxyAI,
};
