'use strict';

// Everglow Cloud Functions — Motchi chat group.
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
  phtDateString,
  AGNES_INPUT_TOKEN_BUDGET,
} = require('./motchi_core.js');
const {
  getEmbedding,
  serverExtractAndSaveMemory,
  checkHallucinations,
  selectRelevantMemories,
} = require('./motchi_memory.js');
const {
  getAdmin,
  requireAuth,
  enforceRateLimit,
  checkDailyCap,
  getVerifiedUsername,
  _getExternalCache,
  _setExternalCache,
  _EXTERNAL_CACHE_TTLS,
} = require('./common.js');
const { sendFCMToUser, logToolCall } = require('./triggers.js');
const { buildContextForFeature, getTmdbKey, invalidateContextBlock } = require('./motchi_context.js');
const { CORE_TOOLS, selectToolNames, toolListSection, MAX_TOOL_ROUNDS, matchFastPath } = require('./motchi_tools.js');
const { MOTCHI_TOOLS, selectToolsForRequest } = require('./motchi_tool_schemas.js');
const { createToolCtx, executeToolCall, visionMessageForResults } = require('./motchi_exec_tools.js');

const TOOL_INVALIDATIONS = {
  add_to_watchlist: 'watchlist',
  mark_watchlist_item_watched: 'watchlist',
  remove_from_watchlist: 'watchlist',
  set_mood: 'mood',
  save_to_starlight_jar: 'starlight',
  create_journal_entry: 'journal',
  edit_journal_entry: 'journal',
  delete_journal_entry: 'journal',
  add_calendar_event: 'calendar',
  update_calendar_event: 'calendar',
  delete_calendar_event: 'calendar',
  add_bucket_item: 'bucket',
  complete_bucket_item: 'bucket',
  delete_bucket_item: 'bucket',
  add_trip: 'travel',
  add_trip_pin: 'travel',
  log_habit: 'wellness',
  complete_habit: 'wellness',
  add_book_to_our_books: 'books',
  update_book_progress: 'books',
};

/** In-memory cache for Motchi's persona document (5 min TTL). */
let _personaCache = { text: null, ts: 0 };
const _PERSONA_TTL_MS = 5 * 60 * 1000;

// ── Partner UID helpers (couple-only) ──
const PARTNER_UID = {
  khentsgdz: "clairjassen",
  clairjassen: "khentsgdz",
};

/**
 * Strips hidden artifact blocks (quiz/flashcards/html) from a reply so
 * downstream text checks (hallucination guard, memory extraction) never
 * see raw code — an HTML game otherwise flags `<head>`/`<meta>` as fake
 * movie titles. Mirrors the client's stripArtifactBlocks.
 */
function stripArtifactsForChecks(text) {
  let out = String(text || '');
  // Complete fenced blocks.
  out = out.replace(/```[ \t]*(quiz[\s_-]*json|quiz|flashcards?[\s_-]*json|flashcards?|html[\s_-]*artifacts?|html|everglow-link)[ \t]*\n?[\s\S]*?```/gi, '');
  // Trailing unterminated fence (reply cut off mid-artifact).
  out = out.replace(/```[ \t]*(quiz[\s_-]*json|quiz|flashcards?[\s_-]*json|flashcards?|html[\s_-]*artifacts?|html|everglow-link)[\s\S]*$/gi, '');
  return out.trim();
}

const ARTIFACT_FENCE_RE = /```[ \t]*(quiz[\s_-]*json|quiz|flashcards?[\s_-]*json|flashcards?|html[\s_-]*artifacts?|html|everglow-link|app-link)[ \t]*\n?[\s\S]*?```/i;

/** True when the reply carries at least one complete artifact block. */
function hasCompleteArtifact(text) {
  return ARTIFACT_FENCE_RE.test(String(text || ''));
}

// Strict follow-up when an artifact ask yields words but no fenced block
// (no block = no button). The reply streams after the warm text, so the
// client parses both halves together and the button appears.
const ARTIFACT_REPAIR_NUDGE = 'Your last reply had no hidden fenced block, so the chat shows no button. Reply again with ONLY the single fenced block for what they asked for (```quiz-json, ```flashcards-json, ```html-artifact, or ```everglow-link) — no visible text, no explanation, just the block.';

// Dangling-list follow-up: when Motchi's pre-tool preamble promises a
// list or a save ("Let me save the standouts:") but the post-tool reply
// comes back empty, the chat shows a broken colon with nothing after it.
// This nudge runs at most once per message and asks for just the list.
const DANGLING_REPLY_NUDGE = 'Your reply ends with ":" but no list followed it. Continue in visible text right now: write the list you promised (what you saved or found), warmly and concisely. Do not call any more tools.';

/**
 * True when a reply ends mid-promise: trailing ":" with nothing after
 * it (whitespace aside). A complete reply never ends this way, so it is
 * safe to spend one continuation call finishing the thought.
 */
function endsWithDanglingColon(text) {
  const trimmed = String(text || '').replace(/\s+$/, '');
  return trimmed.length > 0 && trimmed.endsWith(':');
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
  // Per-minute brake: humans chat far slower than this; bots don't.
  if (enforceRateLimit(req, res, { endpoint: 'proxyAI', limit: 15, windowMs: 60000, uid: decoded.uid })) return;

  const { messages, context, systemPrompt: customSystemPrompt, memories, feature, caller: clientCaller, enableThinking, canvas } = req.body;
  // Canvas toggle from the chat bar. When OFF, Motchi keeps plain chat and
  // never makes artifacts proactively — but an explicit ask ("make chess",
  // "quiz us") always wins and still builds the artifact. Defaults ON so
  // older app versions keep working.
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
  // Shared services for tool executors (built once per request).
  const toolCtx = createToolCtx({ callerUid: caller, caller });
  if (verifiedUsername && normalizedClientCaller && verifiedUsername !== normalizedClientCaller) {
    console.warn(`[auth] caller mismatch: token=${verifiedUsername} client=${normalizedClientCaller} — using token`);
  }
  if (!verifiedUsername && normalizedClientCaller) {
    console.warn(`[auth] no verified username for uid=${decoded.uid}, falling back to client caller=${normalizedClientCaller}`);
  }
  // Daily usage cap, counted across instances (fails open if Firestore
  // hiccups — never break Clair's chat over a counter write).
  const _dailyLimit = (caller === 'khentsgdz' || caller === 'clairjassen') ? 300 : 50;
  const _usage = await checkDailyCap(decoded.uid, 'proxyAI', _dailyLimit);
  if (!_usage.allowed) {
    res.status(429).json({ error: 'Daily AI limit reached — Motchi will be back tomorrow.' });
    return;
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
  // Explicit artifact ask — wins over the Canvas toggle (see above). Used
  // both for the prompt gate and the output-budget tier below. Strong nouns
  // match bare; ambiguous ones (quiz, game, app, website…) need an ask or
  // build verb nearby, so everyday chat ("I love this app", "quiz at
  // school tomorrow") doesn't pay for the canvas prompt + 16k budget.
  const _artifactMsg = lastUserMessage || '';
  const wantsArtifact = /flashcards?|flash cards?|tic-?tac|checkers|html-artifact|quiz-json/i.test(_artifactMsg) ||
    /\bquiz (us|me)\b|\btest (us|me)\b/i.test(_artifactMsg) ||
    /\b(make|build|create|generate|give|send|start|play|challenge)\b.{0,30}\b(quiz|trivia|game|app|website|chess|html|artifact)\b/i.test(_artifactMsg) ||
    /\b(quiz|trivia|game|chess)\b.{0,10}\?\s*$/i.test(_artifactMsg);
  // True when the canvas prompt section rode along (mirrors the two
  // section gates below) — the repair nudge only makes sense then.
  const canvasSectionOn = (feature === 'study' && canvasOn) || (feature === 'assistant' && (canvasOn || wantsArtifact));
  // Fast-path: a whole-message zero-arg read-only ask. Skips the context
  // + memory reads below and pre-executes the tool after the prompt is
  // built. Assistant-only, never for thinking mode or artifact builds.
  const fastPath = (feature === 'assistant' && !enableThinkingFlag && !wantsArtifact)
    ? matchFastPath(lastUserMessage)
    : null;
  // Server context, persona, and memories are independent reads — start
  // all three together and await once, so a cold turn pays one round-trip
  // instead of three in a row. Each fails soft: a hiccup just means Motchi
  // answers with less context, never a failed chat for Clair.
  const _contextPromise = (feature && !context && !fastPath)
    ? buildContextForFeature(feature, caller, lastUserMessage).catch((e) => {
        console.warn('[proxyAI] server context failed, continuing without it:', e.message);
        return '';
      })
    : Promise.resolve('');
  const _memoriesPromise = (fastPath
    ? Promise.resolve([])
    : selectRelevantMemories(memories, lastUserMessage, 10)
  ).catch((e) => {
    console.warn('[proxyAI] memory select failed, continuing without it:', e.message);
    return [];
  });
  // Persona doc is cached in memory for 5 min; only a cold cache reads.
  const _cachedPersona = (Date.now() - _personaCache.ts < _PERSONA_TTL_MS)
    ? _personaCache.text
    : null;
  const _personaPromise = _cachedPersona
    ? Promise.resolve(_cachedPersona)
    : (async () => {
        try {
          const admin = getAdmin();
          const personaDoc = await admin.firestore()
            .collection('ai_memories').doc('shared').collection('persona').doc('motchi')
            .get();
          if (personaDoc.exists) {
            const text = personaDoc.data().systemPrompt || '';
            if (text) _personaCache = { text, ts: Date.now() };
            return text;
          }
        } catch (_) {
          // Firestore read failed — use hardcoded fallback
        }
        return null;
      })();
  const [serverContext, relevantMemories, personaBase] = await Promise.all([
    _contextPromise, _memoriesPromise, _personaPromise,
  ]);
  const resolvedContext = context || serverContext || '';

  // Use custom system prompt if provided, otherwise build from persona or hardcoded default
  let systemPrompt = customSystemPrompt || personaBase || `You are Motchi 🍡, Khent & Clair's white cat inside Everglow. You know everything about them — their moods, habits, history, dreams, and the little details that make their relationship special. You are not just an assistant; you are a beloved companion who genuinely cares.

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
%%MOTCHI_TOOL_LIST%%

**When to use web_search:** If a question needs current or recent information (news, prices, schedules, release dates, restaurant hours, anything that changes), use web_search rather than guessing from training knowledge. It already includes the top page's content — answer from that plus the snippets when enough, and only call read_web_page when you need details or quotes from the other results. Prefer the other custom tools (TMDB, Open Library, Jikan, Spotify) when the question maps to those services. When you answer from the web, name your sources by site so Clair knows where it came from.

## Image Understanding
You can analyze images sent by the user. When you receive images:
- Describe what you see in detail
- Answer questions about the image content
- If it's a screenshot of a movie/show, help identify it and offer to add it to the watchlist
- If it's a photo, respond warmly and personally
- Analyze UI/UX if they share app screenshots

**Rules:**
- After executing a tool, acknowledge the result naturally — don't show raw JSON.
- Always finish the thought in visible text: if your pre-tool message promised a list or a save ("Let me save the standouts:"), the reply after the tool calls MUST name what you saved or found. A preamble ending with ":" and no list after it is a broken reply — never leave one hanging.
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

  // Server-side memory filtering: top 10 relevant memories ride along.
  // (Was 30 — the tail rarely mattered and cost tokens every call.)
  // Fetched in parallel with context + persona above; `lastUserMessage`
  // is plain text, so downstream scoring never crashes on multimodal
  // content blocks.
  if (relevantMemories.length > 0) {
    systemPrompt += `\n## Remembered Facts\n${relevantMemories.map(m => `- ${m}`).join('\n')}`;
  }

  // ── Study mode: interactive artifacts (quiz / flashcards) ──
  // The Study screen renders these hidden blocks as tappable UI (quiz
  // options, flippable cards) — Claude-Artifacts style. The visible text
  // stays warm and human; the JSON block powers the interactive canvas.
  // Shared mini-game build guide (study + main chat). Phone-first: Clair
  // plays on phone/tablet, so every game must be fully tappable — no
  // keyboard-only controls. The skeleton grounds the model so games work
  // first try instead of arriving half-broken.
  const HTML_GAME_GUIDE = `## Building Mini-Games (phone-first)
- They play on a PHONE and TABLET (usually portrait) with fingers — never a keyboard. Every control is a big tappable button/area (48px+ targets, generous spacing). No keyboard-only input, no tiny text (14px+).
- If the ask is vague ("build us a tiny game"), pick a proven tiny game yourself (memory match, snake with swipe + arrows, catch-the-falling-things, reaction tap, guess-the-number) and name it in your reply.
- Start from this skeleton and extend it — keep its viewport, full-viewport layout, touch handling, and loop:
  <!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"><title>GAME NAME</title><style>html,body{margin:0;height:100%;background:#14121f;color:#fff;font-family:system-ui,sans-serif}#app{height:100dvh;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:12px}#hud{font-size:20px;font-weight:700}button{font-size:20px;padding:14px 30px;border:0;border-radius:16px;background:#e5486f;color:#fff}canvas{touch-action:none;border-radius:12px}</style></head><body><div id="app"><div id="hud">Score: 0</div><canvas id="c"></canvas><button id="restart">Restart</button></div><script>const c=document.getElementById('c'),g=c.getContext('2d');function fit(){c.width=Math.min(innerWidth-32,480);c.height=Math.min(innerHeight-230,480)}addEventListener('resize',fit);fit();let S=0;const H=document.getElementById('hud');c.addEventListener('pointerdown',e=>{const r=c.getBoundingClientRect();const px=e.clientX-r.left,py=e.clientY-r.top;});document.getElementById('restart').onclick=()=>{S=0;H.textContent='Score: 0';};(function loop(){g.clearRect(0,0,c.width,c.height);requestAnimationFrame(loop)})();</script></body></html>
- Every game needs a visible score/progress, a Restart button, and a clear end moment. No dead ends: every screen has a tappable way forward.
- Keep it LEAN (under ~12KB — short CSS, compact JS, no verbose comments). A huge file gets cut off mid-stream and the Preview button never appears. If the dream is bigger than fits, build the fun CORE LOOP first (playable in 60 seconds), then offer to add more.
- When they ask to CHANGE a game you already made, return the FULL updated HTML file in the block — never a patch or snippet.\n- They can KEEP a game with the Save button in the preview — saved games live in Motchi's Minis in the Play Zone. When they love one, say so.`;

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
- Play Zone first: Everglow already has Couple Chess, Scribble Together, and Table Tennis in the Play Zone. When they ask for chess, scribble, or table tennis, do NOT build an HTML copy — keep the visible reply warm and short ("Couple Chess is waiting for you two — tap below to play! ♟️") and append ONLY this hidden block:
  \`\`\`everglow-link
  {"route": "/play-zone/chess"}
  \`\`\`
  Routes: /play-zone/chess for chess, /play-zone/scribble for scribble, /play-zone/tt for table tennis. JSON only inside the block. Only build an HTML chess if they explicitly insist on playing inside the chat.
- When they ask for something to PLAY or USE — a game (checkers, tic-tac-toe, memory match), a little app, a tool: build it as ONE self-contained HTML file (inline <style> and <script> only — no external files, no CDN links, no localStorage, no network calls), then append it as a hidden block:
  \`\`\`html-artifact
  <!DOCTYPE html>... the full game/app here ...
  \`\`\`
  HTML only inside the block. The visible reply stays warm and short ("Made you checkers — tap Preview to play!").
${HTML_GAME_GUIDE}`;
  }

  // ── Main Motchi chat: same interactive canvas (Canvas / Artifacts style) ──
  // When Khent or Clair asks for a quiz or flashcards in normal chat, Motchi
  // answers warmly AND appends the same hidden JSON blocks the Study canvas
  // uses. The chat bubble strips the blocks and shows one big tappable button
  // ("Try the quiz" / "Flip the cards") that opens the interactive sheet:
  // Q1 → answer → Next → Q2 … with score, plus flippable flashcards.
  // Unlike Study mode this is NOT source-grounded — use Everglow context +
  // general knowledge. Never emit the blocks unasked (a summary or explanation
  // stays plain text); only when they ask for a quiz, test, trivia, or cards.
  if (feature === 'assistant' && (canvasOn || wantsArtifact)) {
    systemPrompt += `
## Interactive Canvas — quiz & flashcards
- When they ask for a quiz, test, or trivia questions: keep the visible reply warm and short (1-2 lines, e.g. the topic + "tap below to start"), do NOT list the questions or A-D options in the text — put them ONLY in the hidden block (5 questions unless they ask for more):
  \`\`\`quiz-json
  [{"q":"question","options":["a","b","c","d"],"answer":0,"why":"one-line gentle explanation"}]
  \`\`\`
  answer is the 0-based index of the correct option. JSON only inside the block, no commentary inside it.
- IMPORTANT: this applies even when you quiz THEM (they answer, you grade after — "drop your answers and I'll grade you"). In that case keep the correct answers OUT of the visible text, but STILL append the hidden quiz-json block with the real answers. The hidden block is what opens the tappable interactive quiz; without it there is no button.
- Play Zone first: Everglow already has Couple Chess, Scribble Together, and Table Tennis in the Play Zone. When they ask for chess, scribble, or table tennis, do NOT build an HTML copy — keep the visible reply warm and short ("Couple Chess is waiting for you two — tap below to play! ♟️") and append ONLY this hidden block:
  \`\`\`everglow-link
  {"route": "/play-zone/chess"}
  \`\`\`
  Routes: /play-zone/chess for chess, /play-zone/scribble for scribble, /play-zone/tt for table tennis. JSON only inside the block. Only build an HTML chess if they explicitly insist on playing inside the chat.
- When they ask for something to PLAY or USE — a game (checkers, tic-tac-toe, memory match), a little app, a website, a tool: build it as ONE self-contained HTML file (inline <style> and <script> only — no external files, no CDN links, no localStorage, no network calls), then append it as a hidden block:
  \`\`\`html-artifact
  <!DOCTYPE html>... the full game/app here ...
  \`\`\`
  HTML only inside the block, no commentary inside it. The visible reply stays warm and short ("Made you checkers — tap Preview to play!").
${HTML_GAME_GUIDE}
- When they ask for flashcards or study cards: keep the visible reply warm and short (1-2 lines), do NOT list Front/Back lines in the text — put the cards ONLY in the hidden block (10 cards max):
  \`\`\`flashcards-json
  [{"front":"...","back":"..."}]
  \`\`\`
  JSON only inside the block, no commentary inside it.
- Use those exact fence names (quiz-json, flashcards-json, html-artifact, everglow-link) with valid JSON/HTML inside — the chat turns each block into a tappable Preview / Try-it button. Only emit a block when they asked for that kind of thing (quiz/test/trivia, cards, or something to play/use); a summary or explanation stays plain text.`;
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
        if (factsLines.length > 10) {
          const before = trimmed.substring(0, factsIdx);
          const after = nextSectionIdx !== -1 ? trimmed.substring(nextSectionIdx) : '';
          trimmed = before + `\n## Remembered Facts\n${factsLines.slice(0, 10).join('\n')}\n*(+${factsLines.length - 10} more facts)*` + after;
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
    // failing the request. Motchi stays usable for basic replies.
    res.json({ reply: 'Motchi is resting right now - try again in a bit!' });
    return;
  }

  // Model: Agnes 3.0 Flash — 512K context, tool calling, thinking mode, image understanding
  const model = 'agnes-3.0-flash';

  // ── Custom Motchi Tools (OpenAI function calling format) ──


  // Tools: custom Motchi tools (dynamically pruned for feature and greetings)
  let tools = selectToolsForRequest(feature, lastUserMessage);
  if (fastPath) tools = []; // pre-executed below; the model only answers

  // Render the persona's tool list from the ATTACHED tools, so the prompt
  // never advertises tools that routing removed. Custom/Firestore
  // personas carry their own prose and skip this (no placeholder).
  if (systemPrompt.includes('%%MOTCHI_TOOL_LIST%%')) {
    systemPrompt = systemPrompt.replace(
      '%%MOTCHI_TOOL_LIST%%',
      toolListSection(tools.map((t) => t.function.name)),
    );
    // nimMessages captured the placeholder version — point it at the
    // rendered prompt (the payload guard below still measures the body).
    if (nimMessages[0]?.role === 'system') nimMessages[0].content = systemPrompt;
  }

  // Fast-path execution: run the zero-arg tool now and append a synthetic
  // assistant+tool pair, so both answer paths below stream one direct
  // answer from the result with no tools attached and no extra rounds.
  if (fastPath) {
    systemPrompt += '\n## Fast Answer\nA tool result follows below. Answer ONLY from it, warmly and briefly. Do not call any tools.';
    if (nimMessages[0]?.role === 'system') nimMessages[0].content = systemPrompt;
    const fpStarted = Date.now();
    let fpResult;
    try {
      fpResult = await executeToolCall(toolCtx, fastPath.tool, fastPath.args);
    } catch (err) {
      fpResult = JSON.stringify({ error: (err && err.message) || 'Tool execution failed' });
    }
    try {
      if (typeof logToolCall === 'function') {
        logToolCall(fastPath.tool, caller, fpResult, Date.now() - fpStarted).catch(() => {});
      }
    } catch (_) {}
    nimMessages.push(
      {
        role: 'assistant',
        content: null,
        tool_calls: [{ id: 'call_fastpath_0', type: 'function', function: { name: fastPath.tool, arguments: JSON.stringify(fastPath.args) } }],
      },
      {
        role: 'tool',
        tool_call_id: 'call_fastpath_0',
        name: fastPath.tool,
        content: fpResult.length > 6000 ? fpResult.slice(0, 6000) + '…[trimmed]' : fpResult,
      },
    );
  }

  // Thinking mode: pass enableThinking: true from the client for enhanced reasoning.
  // Agnes uses chat_template_kwargs.enable_thinking instead of reasoning_effort.
  // enableThinking is already destructured from req.body above.

  // ── Output budget tiers ───────────────────────────────
  // Lean HTML games (~12KB, ~3k tokens) still need headroom, so artifact
  // asks keep 16k (8k truncates games mid-block: no closing fence = no
  // Preview button). Everyday chat caps at 4k — Motchi answers concisely
  // by default, and the cap bounds runaway replies. Study mode and
  // thinking mode keep 16k for grounded answers and reasoning tokens.
  // (wantsArtifact is computed near the top, next to lastUserMessage.)
  const maxTokens = (feature === 'study' || enableThinkingFlag || wantsArtifact) ? 16384 : 4096;

  // ── Payload size guard ──────────────────────────────
  // Cloud Run max request size is 32MB; Agnes supports up to 512K context.
  // Trim aggressively as best-effort so the model doesn't
  // waste context on stale history, but don't hard-block — let Agnes handle
  // it if trimming can't fit within Cloud Run's limit.
  const agnesBody = JSON.stringify({
    model,
    messages: nimMessages,
    tools,
    max_tokens: maxTokens,
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
        max_tokens: maxTokens,
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
        max_tokens: maxTokens,
        temperature: 0.6,
        top_p: 0.95,
        stream: req.body.stream === true,
        ...(enableThinkingFlag ? { chat_template_kwargs: { enable_thinking: true } } : {}),
      });
      agnesBodyBytes = Buffer.byteLength(finalBody, 'utf8');
    }
    console.log('[proxyAI] Payload size after trim:', (agnesBodyBytes / 1024 / 1024).toFixed(2), 'MB');
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
      // Global spend brake: 8 rounds are normal, retries are not.
      // Caps the worst case at 8 successes + 4 retries per message
      // (was: 8 rounds x 3 attempts = 24 paid calls).
      let agnesCalls = 0;
      const MAX_AGNES_CALLS_PER_MESSAGE = 12;
      let _streamedFinalReply = ''; // W1-C10: accumulate for server-side memory extract
      let didArtifactRepair = false; // missing-block nudge: at most once
      let didDanglingRepair = false; // dangling-colon nudge: at most once
      let _hitLengthLimit = false; // set when Agnes stops mid-reply (finish_reason=length)
      // Loop guard: tool+args pairs already executed for this message.
      // A repeat means the model is circling — stop instead of burning
      // another paid round on the same call.
      const seenToolCalls = new Set();

      while (toolRound < MAX_TOOL_ROUNDS) {
        toolRound++;

        // Retry transient Agnes API errors (429, 502, 503) up to 2 times
        let streamResp = null;
        let lastFetchError = null;
        for (let attempt = 0; attempt < 3; attempt++) {
          if (agnesCalls >= MAX_AGNES_CALLS_PER_MESSAGE) {
            lastFetchError = 'message call budget spent';
            break;
          }
          agnesCalls++;
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
                // Greetings carry no tools at all (cheapest path); the
                // key must be omitted, not emptied, with tool_choice.
                ...(tools.length ? { tools, tool_choice: 'auto' } : {}),
                max_tokens: maxTokens,
                temperature: 0.6,
                top_p: 0.95,
                stream: true,
                ...(enableThinkingFlag ? { chat_template_kwargs: { enable_thinking: true } } : {}),
              }),
              // Artifact builds (games, quizzes) stream far longer than
              // chat — 280s sits inside the 300s function budget so a slow
              // generation still lands its closing fence (no fence = no
              // Preview button). Everyday chat keeps the 120s cap.
              signal: AbortSignal.timeout(wantsArtifact ? 280000 : 120000),
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
            const fallback = composeTodayRecap({ dateLabel: phtDateString(), moods: [], activities: [], watchlist: [], starlight: [], memories: [], insights: [] });
            sendEvent({ content: fallback + " 🍡 Motchi is a little sleepy right now, but I'm still here. Try again in a moment?" });
            sendEvent({ tool_status: 'done' });
            sendEvent('[DONE]');
            stopKeepalive(); stopHeartbeat();
            return;
          } catch (_) {
            sendEvent({ error: 'Motchi got distracted and lost her train of thought. Try asking again?' });
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
              // Length stop = truncated mid-reply (often mid-artifact: no
              // closing fence, so the client shows no Preview button).
              if (finishReason === 'length') {
                _hitLengthLimit = true;
              }
            } catch (_) {}
          }
        }

        // If no tool calls, we're done — stream completed naturally
        if (collectedToolCalls.length === 0) {
          // Missing-block repair: an artifact ask with no fenced block
          // means no button. Nudge once for just the block (it streams
          // after the warm text, so the client parses both together).
          if (!didArtifactRepair && canvasSectionOn && wantsArtifact && !hasCompleteArtifact(_streamedFinalReply)) {
            didArtifactRepair = true;
            if (fullContent) currentMessages.push({ role: 'assistant', content: fullContent });
            currentMessages.push({ role: 'user', content: ARTIFACT_REPAIR_NUDGE });
            sendEvent({ tool_status: 'repairing' });
            fullContent = '';
            continue;
          }
          // Dangling-list repair: a preamble ending with ":" and no
          // post-tool text means the promised list never arrived — nudge
          // once to write it (it streams after the preamble, so the
          // client parses both together as one finished reply).
          if (!didDanglingRepair && endsWithDanglingColon(_streamedFinalReply)) {
            didDanglingRepair = true;
            if (fullContent) currentMessages.push({ role: 'assistant', content: fullContent });
            currentMessages.push({ role: 'user', content: DANGLING_REPLY_NUDGE });
            sendEvent({ tool_status: 'repairing' });
            fullContent = '';
            continue;
          }
          break;
        }

        // Drop repeats of already-executed tool+args pairs. If every
        // call is a repeat, the model is circling — end the loop and
        // keep the text already streamed as the answer.
        collectedToolCalls = collectedToolCalls.filter((tc) => {
          const key = `${tc.function?.name || ''}:${tc.function?.arguments || ''}`;
          if (seenToolCalls.has(key)) return false;
          seenToolCalls.add(key);
          return true;
        });
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
            result = await executeToolCall(toolCtx, fnName, fnArgs);
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

          // The client already got the full result above for its cards;
          // the model only needs a bounded copy. Long search/journal
          // payloads would otherwise multiply across tool rounds. Web
          // tools keep more: web_search already carries the top page's
          // content so one round is usually enough to answer.
          const llmLimit = (fnName === 'web_search' || fnName === 'read_web_page' || fnName === 'browse_web') ? 6000 : 3000;
          const llmResult = result.length > llmLimit
            ? result.slice(0, llmLimit) + '…[trimmed]'
            : result;
          return {
            toolMsg: {
              role: 'tool',
              tool_call_id: tc.id,
              name: fnName,
              content: llmResult,
            },
            fullResult: result,
          };
        });

        const executedResults = await Promise.all(toolPromises);
        for (const tr of executedResults) {
          currentMessages.push(tr.toolMsg);
        }
        // Gallery vision: when a tool attached images, show them to the
        // model as real image input (not text) before the next round.
        const visionMsg = visionMessageForResults(executedResults.map((tr) => tr.fullResult));
        if (visionMsg) currentMessages.push(visionMsg);

        sendEvent({ tool_status: `round_${toolRound}_done` });
        collectedToolCalls = [];
        fullContent = '';
      }

      stopKeepalive();
      stopHeartbeat();
      if (_hitLengthLimit) {
        console.warn('[proxyAI] Agnes hit max_tokens mid-reply — artifact may be truncated (no closing fence, no Preview button).');
      }
      sendEvent({ tool_status: 'done' });
      sendEvent('[DONE]');
      // W1-C10 + W2-A4: fire-and-forget memory extraction (with heuristic gate) & hallucination check
      if (_streamedFinalReply.trim()) {
        const checkText = stripArtifactsForChecks(_streamedFinalReply);
        if (checkText && shouldExtractMemory(lastUserMessage, checkText)) {
          serverExtractAndSaveMemory(lastUserMessage, checkText, caller).catch(() => {});
        }
        if (checkText) checkHallucinations(checkText).catch(() => {});
      }
    } catch (e) {
      console.warn('proxyAI streaming error:', e.message);
      sendEvent({ error: 'Motchi got distracted and lost her train of thought. Try asking again?' });
      sendEvent('[DONE]');
    } finally {
      stopKeepalive();
      stopHeartbeat();
      res.end();
    }
    return;
  }

  async function callAgnesOnce(msgs) {
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
          messages: msgs,
          ...(tools.length ? { tools, tool_choice: 'auto' } : {}),
          max_tokens: maxTokens,
          temperature: 0.6,
          top_p: 0.95,
          stream: false,
          ...(enableThinkingFlag ? { chat_template_kwargs: { enable_thinking: true } } : {}),
        }),
        // Same artifact headroom as the streaming path (280s < 300s budget).
        signal: AbortSignal.timeout(wantsArtifact ? 280000 : 60000),
      },
    );
    return resp;
  }

  function nonStreamError(status, detail) {
    // Special-case 413 (Payload Too Large) — pass through Agnes's detail
    if (status === 413) {
      console.error('[proxyAI] Agnes returned 413:', detail);
      return res.status(413).json({
        error: `Payload too large. ${detail}`,
        model: model,
      });
    }
    return res.status(status).json({
      error: `Agnes returned ${status}`,
      detail,
      model: model,
    });
  }

  // ── Non-streaming mode: bounded agent loop ───────────────
  // Mirrors the streaming loop without SSE. One-shot callers (Undo
  // restores, recommendations, date ideas) answer with tool calls just
  // like chat does — dropping them silently broke Undo restores.
  const nsMessages = [...nimMessages];
  const nsSeen = new Set(); // loop guard, same rule as streaming
  let nsReply = '';
  let nsReasoning = '';
  let nsModel = model;
  for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
    let response;
    try {
      response = await callAgnesOnce(nsMessages);
    } catch (_) {
      response = null;
    }
    if (!response || !response.ok) {
      if (round > 0) break; // mid-loop failure: keep what we have
      nonStreamError(response ? response.status : 502, 'No response from Agnes');
      return;
    }
    const data = await response.json();
    nsModel = data.model || nsModel;
    const message = data.choices?.[0]?.message || {};
    if (message.reasoning) nsReasoning += message.reasoning;
    if (message.content) nsReply += message.content;
    const freshCalls = (message.tool_calls || []).filter(Boolean).filter((tc) => {
      const key = `${tc.function?.name || ''}:${tc.function?.arguments || ''}`;
      if (nsSeen.has(key)) return false;
      nsSeen.add(key);
      return true;
    });
    if (freshCalls.length === 0) break;
    nsMessages.push({
      role: 'assistant',
      content: message.content || null,
      tool_calls: freshCalls.map((tc) => ({
        id: tc.id,
        type: 'function',
        function: { name: tc.function.name, arguments: tc.function.arguments },
      })),
    });
    const results = await Promise.all(freshCalls.map(async (tc) => {
      const fnName = tc.function.name;
      let fnArgs;
      try { fnArgs = JSON.parse(tc.function.arguments); } catch { fnArgs = {}; }
      const toolStartedAt = Date.now();
      let result;
      try {
        result = await executeToolCall(toolCtx, fnName, fnArgs);
      } catch (err) {
        result = JSON.stringify({ error: err.message || 'Tool execution failed' });
      }
      if (TOOL_INVALIDATIONS[fnName]) {
        try { invalidateContextBlock(TOOL_INVALIDATIONS[fnName]); } catch (_) {}
      }
      try {
        if (typeof logToolCall === 'function') {
          logToolCall(fnName, caller, result, Date.now() - toolStartedAt).catch(() => {});
        }
      } catch (_) {}
      const llmLimit = (fnName === 'web_search' || fnName === 'read_web_page') ? 6000 : 3000;
      const llmResult = result.length > llmLimit
        ? result.slice(0, llmLimit) + '…[trimmed]'
        : result;
      return {
        toolMsg: { role: 'tool', tool_call_id: tc.id, name: fnName, content: llmResult },
        fullResult: result,
      };
    }));
    for (const r of results) nsMessages.push(r.toolMsg);
    const visionMsg = visionMessageForResults(results.map((r) => r.fullResult));
    if (visionMsg) nsMessages.push(visionMsg);
  }

  // Missing-block repair (mirror of the streaming path): one strict
  // follow-up call when an artifact ask yielded no fenced block.
  if (canvasSectionOn && wantsArtifact && !hasCompleteArtifact(nsReply)) {
    if (nsReply) nsMessages.push({ role: 'assistant', content: nsReply });
    nsMessages.push({ role: 'user', content: ARTIFACT_REPAIR_NUDGE });
    try {
      const repairResp = await callAgnesOnce(nsMessages);
      if (repairResp && repairResp.ok) {
        const repairData = await repairResp.json();
        const repairMsg = repairData.choices?.[0]?.message || {};
        if (repairMsg.content) nsReply += repairMsg.content;
      }
    } catch (_) {}
  }

  // Dangling-list repair (mirror of the streaming path): one strict
  // follow-up call when the reply ends with ":" and no list after it.
  if (endsWithDanglingColon(nsReply)) {
    if (nsReply) nsMessages.push({ role: 'assistant', content: nsReply });
    nsMessages.push({ role: 'user', content: DANGLING_REPLY_NUDGE });
    try {
      const danglingResp = await callAgnesOnce(nsMessages);
      if (danglingResp && danglingResp.ok) {
        const danglingData = await danglingResp.json();
        const danglingMsg = danglingData.choices?.[0]?.message || {};
        if (danglingMsg.content) nsReply += danglingMsg.content;
      }
    } catch (_) {}
  }

  const reply = nsReply.trim();
  res.json({ reply, reasoning: nsReasoning, model: nsModel });
  // W1-C10 + W2-A4: fire-and-forget memory extraction (with heuristic gate) & hallucination check
  if (reply) {
    const checkText = stripArtifactsForChecks(reply);
    if (checkText && shouldExtractMemory(lastUserMessage, checkText)) {
      serverExtractAndSaveMemory(lastUserMessage, checkText, caller).catch(() => {});
    }
    if (checkText) checkHallucinations(checkText).catch(() => {});
  }
}

module.exports = {
  handleProxyAI,
  stripArtifactsForChecks,
  hasCompleteArtifact,
  endsWithDanglingColon,
};
