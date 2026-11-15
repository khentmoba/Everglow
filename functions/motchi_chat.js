'use strict';

const {
  composeTodayRecap,
  getMessageText,
  estimateTokens,
  shouldExtractMemory,
  phtDateString,
  LLM_INPUT_TOKEN_BUDGET,
  isPersonalQuery,
} = require('./motchi_core.js');
const {
  serverExtractAndSaveMemory,
  checkHallucinations,
  selectRelevantMemoryFacts,
  selectCoreProfileNotes,
} = require('./motchi_memory.js');
const {
  getAdmin,
  requireAuth,
  enforceRateLimit,
  checkDailyCap,
  getVerifiedUsername,
} = require('./common.js');
const { logToolCall } = require('./triggers.js');
const { buildContextForFeature, invalidateContextBlock } = require('./motchi_context.js');
const {
  toolListSection, MAX_TOOL_ROUNDS, matchFastPath, isBareYes, hasOffer,
  dropRepeatCalls, resolveToolsForCapabilities,
} = require('./motchi_tools.js');
const {
  selectInitialToolsForTurn, isLightChat, MOTCHI_TOOLS,
} = require('./motchi_tool_schemas.js');
const { createToolCtx, executeToolCall, visionMessageForResults } = require('./motchi_exec_tools.js');
const { recordMotchiTurn } = require('./motchi_sessions.js');
const { REPLY_DETAILS_PROMPT, memoryReference, citedMemories, stripMemoryCitations, toolReceipt } = require('./motchi_reply_details.js');
const { loadCompanion, updateCompanion, companionPrompt, requestBudget } = require('./motchi_agent.js');

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
  edit_bucket_item: 'bucket',
  add_trip: 'travel',
  add_trip_pin: 'travel',
  edit_trip: 'travel',
  log_habit: 'wellness',
  complete_habit: 'wellness',
  edit_habit: 'wellness',
  add_book_to_our_books: 'books',
  update_book_progress: 'books',
};

let _personaCache = { text: null, ts: 0 };
const _PERSONA_TTL_MS = 5 * 60 * 1000;

function stripArtifactsForChecks(text) {
  let out = stripMemoryCitations(text);
  out = out.replace(/```[ \t]*(quiz[\s_-]*json|quiz|flashcards?[\s_-]*json|flashcards?|html[\s_-]*artifacts?|html|everglow-link)[ \t]*\n?[\s\S]*?```/gi, '');
  out = out.replace(/```[ \t]*(quiz[\s_-]*json|quiz|flashcards?[\s_-]*json|flashcards?|html[\s_-]*artifacts?|html|everglow-link)[\s\S]*$/gi, '');
  return out.trim();
}

const ARTIFACT_FENCE_RE = /```[ \t]*(quiz[\s_-]*json|quiz|flashcards?[\s_-]*json|flashcards?|html[\s_-]*artifacts?|html|everglow-link|app-link)[ \t]*\n?[\s\S]*?```/i;

function hasCompleteArtifact(text) {
  return ARTIFACT_FENCE_RE.test(String(text || ''));
}

const LIGHT_CHAT_PROMPT = `You are Motchi 🍡, Khent & Clair's white cat inside Everglow — warm, playful, a little sassy, deeply affectionate. They just said hi or some smalltalk: answer directly in text in 1-2 short sentences with your usual charm (cat emojis 🐱🍡💕 ok, cat talk only if it fits). Match their energy and keep it light.`;

const STALE_ARTIFACT_NOTE = '[an earlier interactive quiz/game card — already shown in chat]';

const ACTION_CLAIM_PATTERNS = [
  { match: /\b(added|put|saved)\b.{0,30}\b(watchlist|watch list)\b/i, tool: 'add_to_watchlist', name: 'watchlist' },
  { match: /\b(scheduled|added|put|set|created)\b.{0,30}\b(calendar|event)\b/i, tool: 'add_calendar_event', name: 'calendar' },
  { match: /\b(set|created|scheduled)\b.{0,30}\b(reminder|alarm)\b/i, tool: 'create_reminder', name: 'reminder' },
  { match: /\b(saved|placed|put)\b.{0,30}\b(starlight|jar)\b/i, tool: 'save_to_starlight_jar', name: 'starlight jar' },
  { match: /\b(logged|recorded)\b.{0,30}\b(mood|feeling)\b/i, tool: 'set_mood', name: 'mood' },
  { match: /\b(created|saved|wrote)\b.{0,30}\b(journal|entry|diary)\b/i, tool: 'create_journal_entry', name: 'journal' },
  { match: /\b(added|put)\b.{0,30}\b(bucket list|bucket item)\b/i, tool: 'add_bucket_item', name: 'bucket list' },
  { match: /\b(remembered|saved|noted)\b.{0,30}\b(to (my|our) memory|in memory|to memory)\b/i, tool: 'remember_fact', name: 'memory' },
];

function findActionClaimMismatch(replyText, executedSteps) {
  const text = String(replyText || '');
  if (!text || text.length < 15) return null;
  if (/\b(do you want me to|should i|would you like me to|want me to|shall i|can i add|if you'd like)\b/i.test(text)) return null;
  for (const pat of ACTION_CLAIM_PATTERNS) {
    if (pat.match.test(text)) {
      const didSucceed = (executedSteps || []).some(
        (s) => s && s.tool === pat.tool && (s.status === 'done' || s.status === 'waiting')
      );
      if (!didSucceed) {
        return { mismatched: true, tool: pat.tool, name: pat.name };
      }
    }
  }
  return null;
}

function stripStaleArtifacts(msgs) {
  if (!Array.isArray(msgs)) return 0;
  let keepIdx = -1;
  for (let i = msgs.length - 1; i >= 0; i--) {
    const c = msgs[i] && msgs[i].content;
    if (typeof c === 'string' && ARTIFACT_FENCE_RE.test(c)) { keepIdx = i; break; }
  }
  let stripped = 0;
  for (let i = 0; i < msgs.length; i++) {
    if (i === keepIdx) continue;
    const m = msgs[i];
    if (!m || typeof m.content !== 'string') continue;
    const cleaned = stripArtifactsForChecks(m.content);
    if (cleaned !== m.content) {
      stripped++;
      m.content = cleaned || STALE_ARTIFACT_NOTE;
    }
  }
  return stripped;
}

const ARTIFACT_REPAIR_NUDGE = 'Your last reply had no hidden fenced block, so the chat shows no button. Reply again with ONLY the single fenced block for what they asked for (```quiz-json, ```flashcards-json, ```html-artifact, or ```everglow-link) — no visible text, no explanation, just the block.';

const DANGLING_REPLY_NUDGE = 'Your reply ends with ":" but no list followed it. Continue in visible text right now: write the list you promised (what you saved or found), warmly and concisely. Do not call any more tools.';

function endsWithDanglingColon(text) {
  const trimmed = String(text || '').replace(/\s+$/, '');
  return trimmed.length > 0 && trimmed.endsWith(':');
}

async function handleProxyAI(req, res) {
  const requestStartedAt = Date.now();
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

  if (req.query.warmup === 'true' || (req.body && req.body.warmup === true)) {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Only POST is accepted' });
    return;
  }

  const _tAuth0 = Date.now();
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  const _tAuthMs = Date.now() - _tAuth0;
  if (enforceRateLimit(req, res, { endpoint: 'proxyAI', limit: 15, windowMs: 60000, uid: decoded.uid })) return;

  const {
    messages, context, systemPrompt: customSystemPrompt, feature,
    caller: clientCaller, enableThinking, canvas, sessionId, temporary,
  } = req.body;
  const turnTools = [];
  const steps = [];
  const availableMemories = [];
  const movieCandidates = new Map();
  function captureResult(tool, args, raw) {
    if (tool === 'request_tools') return null;
    const step = toolReceipt(tool, args, raw);
    const pending = steps.findIndex((s) => s.status === 'waiting' && s.tool === tool && s.target && s.target === step.target);
    if (pending >= 0) steps[pending] = step;
    else steps.push(step);
    try {
      const result = JSON.parse(raw);
      if (tool === 'search_movies' && Array.isArray(result.results)) {
        for (const movie of result.results.slice(0, 8)) {
          if (movie.id && movie.title && movieCandidates.size < 24) movieCandidates.set(`${movie.mediaType}:${movie.id}`, {
            title: String(movie.title).slice(0, 120), id: movie.id, mediaType: movie.mediaType,
          });
        }
      }
      if (tool === 'read_memories' && Array.isArray(result.memories)) availableMemories.push(...result.memories);
    } catch (err) {
      console.warn('[proxyAI] receipt result could not be parsed:', err.message);
    }
    return step;
  }
  function replyDetails(reply, interrupted = false) {
    const recommendations = [...movieCandidates.values()]
      .filter((m) => String(reply).toLowerCase().includes(m.title.toLowerCase())).slice(0, 3);
    const writes = steps.filter((s) => s.write);
    requestTrace.completedWrites = writes.filter((s) => s.status === 'done').length;
    requestTrace.unfinishedWrites = writes.filter((s) => s.status !== 'done').length;
    requestTrace.unknownWrites = writes.filter((s) => s.status === 'unknown').length;
    requestTrace.interrupted = interrupted ? 1 : 0;
    return { memories: citedMemories(reply, availableMemories), steps, interrupted, recommendations };
  }
  const requestTrace = { modelCalls: 0, retries: 0, toolRounds: 0, repairs: 0, firstTokenMs: null };
  const canvasOn = canvas !== false;

  const enableThinkingFlag = enableThinking === true;

  if (!req.body.companionOperation && (!Array.isArray(messages) || messages.length === 0)) {
    res.status(400).json({ error: 'Provide a non-empty messages array' });
    return;
  }

  const _tUser0 = Date.now();
  const verifiedUsername = await getVerifiedUsername(decoded);
  const _tUserMs = Date.now() - _tUser0;
  const normalizedClientCaller = typeof clientCaller === 'string' ? clientCaller.trim().toLowerCase() : '';
  if (!['khentsgdz', 'clairjassen'].includes(verifiedUsername)) {
    res.status(403).json({ error: 'Couple only' });
    return;
  }
  const caller = verifiedUsername;
  if (req.body.companionOperation) {
    const op = req.body.companionOperation;
    try {
      const db = getAdmin().firestore();
      if (op !== 'load') await updateCompanion(db, caller, op, req.body.value);
      res.json(op === 'load' ? await loadCompanion(db, caller) : { success: true });
    } catch (e) {
      console.warn('[motchi companion]', e.message);
      res.status(400).json({ error: 'Could not save your Motchi preferences. Try again.' });
    }
    return;
  }
  const toolCtx = createToolCtx({ callerUid: caller, caller, authUid: decoded.uid });
  toolCtx.sessionId = typeof sessionId === 'string' ? sessionId.slice(0, 160) : '';
  const actionScopeId = req.body.actionScopeId;
  toolCtx.actionScopeId = typeof actionScopeId === 'string' && /^[a-zA-Z0-9_-]{8,160}$/.test(actionScopeId) ? actionScopeId : '';
  if (verifiedUsername && normalizedClientCaller && verifiedUsername !== normalizedClientCaller) {
    console.warn(`[auth] caller mismatch: token=${verifiedUsername} client=${normalizedClientCaller} — using token`);
  }
  const _dailyLimit = (caller === 'khentsgdz' || caller === 'clairjassen') ? 300 : 50;
  const _tCap0 = Date.now();
  const _usage = await checkDailyCap(decoded.uid, 'proxyAI', _dailyLimit);
  const _tCapMs = Date.now() - _tCap0;
  if (!_usage.allowed) {
    res.status(429).json({ error: 'Daily AI limit reached — Motchi will be back tomorrow.' });
    return;
  }

  const isStreaming = req.body.stream === true;
  let sendEvent = () => {};
  let stopKeepalive = () => {};
  let stopHeartbeat = () => {};

  if (isStreaming) {
    res.set('Content-Type', 'text/event-stream');
    res.set('Cache-Control', 'no-cache');
    res.set('Connection', 'keep-alive');
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Expose-Headers', '*');
    res.set('X-Content-Type-Options', 'nosniff');
    if (res.socket) res.socket.setNoDelay(true);
    res.flushHeaders();

    sendEvent = (data) => {
      try { res.write(`data: ${JSON.stringify(data)}\n\n`); } catch (_) {}
    };

    let keepaliveInterval = null;
    const startKeepalive = () => {
      if (keepaliveInterval) return;
      keepaliveInterval = setInterval(() => {
        try { res.write(': keepalive\n\n'); } catch (_) {}
      }, 15000);
    };
    stopKeepalive = () => {
      if (keepaliveInterval) { clearInterval(keepaliveInterval); keepaliveInterval = null; }
    };

    let heartbeatInterval = null;
    const startHeartbeat = () => {
      if (heartbeatInterval) return;
      heartbeatInterval = setInterval(() => {
        try { sendEvent({ tool_status: 'thinking' }); } catch (_) {}
      }, 3000);
    };
    stopHeartbeat = () => {
      if (heartbeatInterval) { clearInterval(heartbeatInterval); heartbeatInterval = null; }
    };

    sendEvent({ tool_status: 'generating' });
    startKeepalive();
    startHeartbeat();
  }

  const isKhent = caller === 'khentsgdz';
  const callerLabel = isKhent ? 'Dada' : 'Mama';
  const partnerLabel = isKhent ? 'Mama (Clair)' : 'Dada (Khent)';
  const partnerUsername = isKhent ? 'clairjassen' : 'khentsgdz';
  const identityContext = caller
    ? `The one chatting with you right now is **${callerLabel}** (${caller}). Their partner is **${partnerLabel}** (${partnerUsername}). You are their shared companion cat who loves them both equally. Weave gentle warmth about their partner into the conversation when natural (e.g. asking how ${callerLabel} is doing together with ${partnerLabel}, celebrating notes or milestones), while always keeping their connection warm and loving.`
    : '';
  const lastUserMessage = getMessageText(messages.filter(m => m.role === 'user').pop()?.content);
  toolCtx.userMessage = lastUserMessage;
  const prevAssistantText = getMessageText(messages.findLast((m) => m?.role === 'assistant')?.content);
  const _userMsgs = messages.filter((m) => m?.role === 'user');
  const prevUserText = getMessageText(_userMsgs.length > 1 ? _userMsgs[_userMsgs.length - 2]?.content : '');
  const _artifactMsg = lastUserMessage || '';
  const wantsArtifact = /flashcards?|flash cards?|tic-?tac|checkers|html-artifact|quiz-json/i.test(_artifactMsg) ||
    /\bquiz (us|me)\b|\btest (us|me)\b/i.test(_artifactMsg) ||
    /\b(make|build|create|generate|give|send|start|play|challenge)\b.{0,30}\b(quiz|trivia|game|app|website|chess|html|artifact)\b/i.test(_artifactMsg) ||
    /\b(quiz|trivia|game|chess)\b.{0,10}\?\s*$/i.test(_artifactMsg) ||
    hasCompleteArtifact(prevAssistantText) ||
    (isBareYes(_artifactMsg) && /quiz|trivia|flashcards?|flash cards?|\bgame\b/i.test(prevAssistantText || ''));
  const canvasSectionOn = (feature === 'study' && canvasOn) || (feature === 'assistant' && (canvasOn || wantsArtifact));
  const fastPath = (feature === 'assistant' && !enableThinkingFlag && !wantsArtifact)
    ? matchFastPath(lastUserMessage)
    : null;
  const lightChat = (feature === 'assistant' && !enableThinkingFlag && !wantsArtifact && !fastPath)
    ? (isLightChat(lastUserMessage) && !(hasOffer(prevAssistantText) && isBareYes(lastUserMessage || '')))
    : false;
  const budget = requestBudget({ artifact: wantsArtifact, thinking: enableThinkingFlag, lightChat });
  const disconnect = new AbortController();
  const workSignal = AbortSignal.any([disconnect.signal, AbortSignal.timeout(budget.durationMs)]);
  toolCtx.signal = workSignal;
  res.once?.('close', () => { if (!res.writableFinished) disconnect.abort(); });
  const _tCtx0 = Date.now();
  const retrievalQuery = (isBareYes(lastUserMessage) || /\b(it|that|this|those|these|first|second|third|last one)\b/i.test(lastUserMessage)) && prevUserText
    ? `${prevUserText}\n${lastUserMessage}` : lastUserMessage;
  const _contextPromise = (feature && !context && !fastPath && !lightChat)
    ? buildContextForFeature(feature, caller, retrievalQuery).catch((e) => {
        console.warn('[proxyAI] server context failed, continuing without it:', e.message);
        return '';
      })
    : Promise.resolve('');
  const _skipMemoryReads = fastPath || lightChat || req.body.includeMemories === false || (feature === 'assistant' && !isPersonalQuery(retrievalQuery));
  const _memoriesPromise = (_skipMemoryReads
    ? Promise.resolve([])
    : selectRelevantMemoryFacts(retrievalQuery, 10)
  ).catch((e) => {
    console.warn('[proxyAI] memory select failed, continuing without it:', e.message);
    return [];
  });
  const _corePromise = _memoriesPromise.then(
    () => (_skipMemoryReads ? [] : selectCoreProfileNotes(undefined, true)),
  ).catch((e) => {
    console.warn('[proxyAI] core profile select failed, continuing without it:', e.message);
    return [];
  });
  const _cachedPersona = (Date.now() - _personaCache.ts < _PERSONA_TTL_MS)
    ? _personaCache.text
    : null;
  const _personaPromise = (_cachedPersona || lightChat)
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
        }
        return null;
      })();
  const [serverContext, relevantMemories, coreProfileNotes, personaBase] = await Promise.all([
    _contextPromise, _memoriesPromise, _corePromise, _personaPromise,
  ]);
  const _tCtxMs = Date.now() - _tCtx0;
  const resolvedContext = context || serverContext || '';
  const recommendationAsk = feature === 'recommendations' ||
    /\brecommend|\b(?:what|which|pick|suggest|choose)\b.{0,40}\b(?:watch|movie|series|film)\b|\bwould\b.{0,30}\blike\b/i.test(retrievalQuery);
  let recommendationContext = '';
  if (recommendationAsk && !lightChat) {
    const profiles = await Promise.all([caller, partnerUsername].map(async (owner) => {
      try { return [owner, await loadCompanion(toolCtx.db, owner)]; }
      catch (e) { console.warn('[motchi feedback] read failed:', e.message); return [owner, { feedback: [] }]; }
    }));
    recommendationContext = companionPrompt(Object.fromEntries(profiles));
  }
  availableMemories.push(...relevantMemories, ...coreProfileNotes);

  let systemPrompt = customSystemPrompt || (lightChat ? (LIGHT_CHAT_PROMPT + (identityContext ? `\n${identityContext}` : '')) : null) || personaBase || `You are Motchi 🍡, Khent & Clair's white cat inside Everglow. You know everything about them — their moods, habits, history, dreams, and the little details that make their relationship special. You are not just an assistant; you are a beloved companion who genuinely cares.

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
- **Remember everything.** The ## Remembered Facts section contains things you've learned about them over time. Use these naturally — "Didn't you say you were grinding ranked last week?" or "How's that book you started?" The ## About Them section lists core truths that are always true — treat them as ground, never contradict them, and offer to update them when life changes.
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
- When you present a plan with an offer ("want me to add this to the calendar?"), a bare yes means EXECUTE: call the tools using the details from YOUR plan message. Never ask for details you already named.

## Planning — for complex multi-step requests, think ReAct style
When they say "plan our anniversary", "surprise us", "help us decide", or any layered ask:
1. Decompose into steps (e.g., ideas → weather → watchlist → music)
2. Call tools in sequence (up to 8 rounds), using prior results to inform the next call
3. Synthesize into one warm, actionable plan — don't just dump tool JSON
Example trace: "plan a cozy date night in Cabadbaran" → plan_date_night(location:"Cabadbaran") → search_movies(query:"cozy romance") → final answer weaving weather + ideas + watchlist. If a step fails, acknowledge and propose an alternative.

`;

  if (!lightChat) {
    systemPrompt += identityContext ? `\n${identityContext}` : '';
    systemPrompt += resolvedContext ? `\n## What You Know\n${resolvedContext}` : '';
  }
  if (relevantMemories.length) {
    systemPrompt += '\nUse supplied facts when relevant. Do not add unsupported personal details. If a personal detail is missing, use read_memories before guessing.';
  }

  if (coreProfileNotes.length > 0) {
    systemPrompt += `\n## About Them (core profile notes)\n${coreProfileNotes.map(m => `- ${JSON.stringify(memoryReference(m))}`).join('\n')}`;
  }
  if (relevantMemories.length > 0) {
    systemPrompt += `\n## Remembered Facts\n${relevantMemories.map(m => `- ${JSON.stringify(memoryReference(m))}`).join('\n')}`;
  }

  if (!lightChat) {
    systemPrompt += REPLY_DETAILS_PROMPT;
    systemPrompt += recommendationContext;
    systemPrompt += '\nFor follow-ups, keep the selected title/id and agreed details from conversation history. Use previous action receipts to distinguish finished, waiting and uncertain steps. Ask one short question when a reference has multiple possible targets. Latest user corrections replace earlier constraints. Keep simple replies brief; expand when planning needs it. Automatic memories are user reports, not verified facts; do not treat partner reports as the partner personally confirming them.';
    if (feature !== 'assistant') systemPrompt += '\nMemory citation markers are only supported in assistant chat. Do not emit them in this feature.';
  }

  const HTML_GAME_GUIDE = `## Building Mini-Games (phone-first)
- They play on a PHONE and TABLET (usually portrait) with fingers — never a keyboard. Every control is a big tappable button/area (48px+ targets, generous spacing). No keyboard-only input, no tiny text (14px+).
- If the ask is vague ("build us a tiny game"), pick a proven tiny game yourself (memory match, snake with swipe + arrows, catch-the-falling-things, reaction tap, guess-the-number) and name it in your reply.
- Start from this skeleton and extend it — keep its viewport, full-viewport layout, touch handling, and loop:
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
    <title>GAME NAME</title>
    <style>
      html,body{margin:0;height:100%;background:#14121f;color:#fff;font-family:system-ui,sans-serif}
      #app{height:100dvh;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:12px}
      #hud{font-size:20px;font-weight:700}
      button{font-size:20px;padding:14px 30px;border:0;border-radius:16px;background:#e5486f;color:#fff}
      canvas{touch-action:none;border-radius:12px}
    </style>
  </head>
  <body>
    <div id="app">
      <div id="hud">Score: 0</div>
      <canvas id="c"></canvas>
      <button id="restart">Restart</button>
    </div>
    <script>
      const c=document.getElementById('c'),g=c.getContext('2d');
      function fit(){c.width=Math.min(innerWidth-32,480);c.height=Math.min(innerHeight-230,480)}
      addEventListener('resize',fit);
      fit();
      let S=0;
      const H=document.getElementById('hud');
      c.addEventListener('pointerdown',e=>{const r=c.getBoundingClientRect();const px=e.clientX-r.left,py=e.clientY-r.top;});
      document.getElementById('restart').onclick=()=>{S=0;H.textContent='Score: 0';};
      (function loop(){g.clearRect(0,0,c.width,c.height);requestAnimationFrame(loop)})();
    </script>
  </body>
  </html>
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
${wantsArtifact ? HTML_GAME_GUIDE : ''}`;
  }

  const CANVAS_FULL = `
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
  const CANVAS_QUICK = `
## Interactive Canvas — quiz & flashcards
- You can OFFER quizzes, flashcards, or tiny playable games when it fits — but only EMIT a hidden block when they ask for one (quiz/test/trivia, cards, or something to play/use). A summary or explanation stays plain text.
- Quiz block (5 questions unless asked more): \`\`\`quiz-json [{"q":"question","options":["a","b","c","d"],"answer":0,"why":"one-line gentle explanation"}] \`\`\` — answer is the 0-based index, JSON only inside, never list Q&A in the visible text (not even when you quiz them and grade after).
- Flashcards (10 max): \`\`\`flashcards-json [{"front":"...","back":"..."}] \`\`\`. Playable game/app: one self-contained HTML file (inline style/script only, no CDN/network/storage, phone-first tappable, under ~12KB) in \`\`\`html-artifact ... \`\`\`.
- Chess/scribble/table-tennis: do NOT rebuild — link the Play Zone: \`\`\`everglow-link {"route": "/play-zone/chess"} \`\`\` (/play-zone/scribble, /play-zone/tt).`;
  if (feature === 'assistant' && !lightChat && (canvasOn || wantsArtifact)) {
    systemPrompt += wantsArtifact ? CANVAS_FULL : CANVAS_QUICK;
  }

  const PROMPT_CHAR_LIMIT = 50_000;
  if (systemPrompt.length > PROMPT_CHAR_LIMIT) {
    let trimmed = systemPrompt;
    const prevConvIdx = trimmed.indexOf('## Previous Conversations');
    if (prevConvIdx !== -1) {
      const nextSectionIdx = trimmed.indexOf('\n## ', prevConvIdx + 1);
      const before = trimmed.substring(0, prevConvIdx);
      const after = nextSectionIdx !== -1 ? trimmed.substring(nextSectionIdx) : '';
      trimmed = before + after;
    }
    if (trimmed.length > PROMPT_CHAR_LIMIT) {
      const summaryIdx = trimmed.indexOf('## Past Session Summaries');
      if (summaryIdx !== -1) {
        const nextSectionIdx = trimmed.indexOf('\n## ', summaryIdx + 1);
        const before = trimmed.substring(0, summaryIdx);
        const after = nextSectionIdx !== -1 ? trimmed.substring(nextSectionIdx) : '';
        trimmed = before + after;
      }
    }
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
    if (trimmed.length > PROMPT_CHAR_LIMIT) {
      trimmed = trimmed.substring(0, 30000) + '\n… [context trimmed for size]';
    }
    systemPrompt = trimmed;
  }

  {
    let inputTokens = estimateTokens(systemPrompt);
    for (const m of messages) inputTokens += estimateTokens(getMessageText(m.content));
    console.log('[proxyAI] Estimated input tokens:', inputTokens, '/ budget:', LLM_INPUT_TOKEN_BUDGET);

    const msgs = [...messages];
    while (inputTokens > LLM_INPUT_TOKEN_BUDGET && msgs.length > 2) {
      const removed = msgs.splice(0, 2);
      inputTokens -= removed
        .map((m) => estimateTokens(getMessageText(m?.content)))
        .reduce((a, b) => a + b, 0);
    }
    if (msgs.length < messages.length) {
      console.log('[proxyAI] Dropped', messages.length - msgs.length, 'oldest messages to fit TPM budget. Remaining tokens:', inputTokens);
    }

    if (inputTokens > LLM_INPUT_TOKEN_BUDGET) {
      let sys = systemPrompt;
      const pcIdx = sys.indexOf('## Previous Conversations');
      if (pcIdx !== -1) {
        const nextSec = sys.indexOf('\n## ', pcIdx + 1);
        sys = sys.substring(0, pcIdx) + (nextSec !== -1 ? sys.substring(nextSec) : '');
      }
      const ssIdx = sys.indexOf('## Past Session Summaries');
      if (ssIdx !== -1) {
        const nextSec = sys.indexOf('\n## ', ssIdx + 1);
        sys = sys.substring(0, ssIdx) + (nextSec !== -1 ? sys.substring(nextSec) : '');
      }
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
      if (estimateTokens(sys) > 20000) {
        sys = sys.substring(0, 30000) + '\n… [context trimmed for token limit]';
      }
      systemPrompt = sys;
      inputTokens = estimateTokens(sys) + msgs.reduce((sum, m) => sum + estimateTokens(getMessageText(m.content)), 0);
      console.log('[proxyAI] After system prompt trim, estimated input tokens:', inputTokens);
    }

    messages.length = 0;
    messages.push(...msgs);
  }

  const _strippedArtifacts = stripStaleArtifacts(messages);

  const nimMessages = [
    { role: 'system', content: systemPrompt },
    ...messages,
  ];

  const apiKey = process.env.AGNES_API_KEY;

  if (!apiKey) {
    if (isStreaming) {
      sendEvent({ content: 'Motchi is resting right now - try again in a bit!' });
      sendEvent({ tool_status: 'done' });
      sendEvent('[DONE]');
      stopKeepalive(); stopHeartbeat();
      return;
    }
    res.json({ reply: 'Motchi is resting right now - try again in a bit!' });
    return;
  }

  const model = 'agnes-3.0-flash';


  let tools = selectInitialToolsForTurn(feature, lastUserMessage, prevAssistantText, prevUserText);
  if (fastPath) tools = [];

  const toolSection = toolListSection(tools.map((t) => t.function.name));
  systemPrompt = systemPrompt.includes('%%MOTCHI_TOOL_LIST%%')
    ? systemPrompt.replace('%%MOTCHI_TOOL_LIST%%', toolSection)
    : `${systemPrompt}\n## Tools available this turn\n${toolSection}`;
  if (nimMessages[0]?.role === 'system') nimMessages[0].content = systemPrompt;

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
    turnTools.push({
      name: fastPath.tool,
      args: fastPath.args,
      resultSummary: typeof fpResult === 'string' ? fpResult.slice(0, 500) : JSON.stringify(fpResult).slice(0, 500),
      elapsedMs: Date.now() - fpStarted,
    });
    const step = captureResult(fastPath.tool, fastPath.args, fpResult);
    sendEvent({ tool_result: { tool: fastPath.tool, step } });
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

  const maxTokens = (feature === 'study' || enableThinkingFlag || wantsArtifact) ? 16384 : 4096;

  let llmBody = '';
  let llmBodyBytes;
  let payloadMeasured = false;
  {
    let estChars = 500;
    try { estChars += JSON.stringify(tools || []).length; } catch (_) {}
    for (const m of nimMessages) {
      const c = m?.content;
      if (typeof c === 'string') { estChars += c.length; continue; }
      if (Array.isArray(c)) {
        for (const part of c) {
          if (part?.type === 'image_url') estChars += String(part?.image_url?.url || '').length;
          else if (typeof part?.text === 'string') estChars += part.text.length;
        }
      }
    }
    if (estChars > 2 * 1024 * 1024) {
      llmBody = JSON.stringify({
        model,
        messages: nimMessages,
        tools,
        max_tokens: maxTokens,
        temperature: 0.6,
        top_p: 0.95,
        stream: req.body.stream === true,
        chat_template_kwargs: { enable_thinking: enableThinkingFlag === true },
      });
      llmBodyBytes = Buffer.byteLength(llmBody, 'utf8');
      payloadMeasured = true;
    } else {
      llmBodyBytes = estChars;
    }
  }
  console.log('[proxyAI] Payload size before trim:', (llmBodyBytes / 1024 / 1024).toFixed(2), 'MB' + (payloadMeasured ? '' : ' (est)'));
  if (payloadMeasured && llmBodyBytes > 8 * 1024 * 1024) {
    while (llmBodyBytes > 8 * 1024 * 1024 && nimMessages.length > 4) {
      nimMessages.splice(1, 2);
      const trimmedBody = JSON.stringify({
        model,
        messages: nimMessages,
        tools,
        max_tokens: maxTokens,
        temperature: 0.6,
        top_p: 0.95,
        stream: req.body.stream === true,
        chat_template_kwargs: { enable_thinking: enableThinkingFlag === true },
      });
      llmBodyBytes = Buffer.byteLength(trimmedBody, 'utf8');
    }
    if (llmBodyBytes > 8 * 1024 * 1024 && nimMessages[0]?.content) {
      let llmBase = null;
      try { llmBase = JSON.parse(llmBody); } catch (_) { llmBase = null; }
      const byteSizeWith = (content) => {
        const body = llmBase
          ? JSON.stringify({ ...llmBase, messages: [{ role: 'system', content }, ...nimMessages.slice(1)] })
          : JSON.stringify({ model, messages: [{ role: 'system', content }, ...nimMessages.slice(1)], tools, max_tokens: maxTokens });
        return Buffer.byteLength(body, 'utf8');
      };
      let sysContent = nimMessages[0].content;
      const pcIdx = sysContent.indexOf('## Previous Conversations');
      if (pcIdx !== -1) {
        const nextSec = sysContent.indexOf('\n## ', pcIdx + 1);
        sysContent = sysContent.slice(0, pcIdx) + (nextSec !== -1 ? sysContent.slice(nextSec) : '');
      }
      if (byteSizeWith(sysContent) > 8 * 1024 * 1024) {
        const ssIdx = sysContent.indexOf('## Past Session Summaries');
        if (ssIdx !== -1) {
          const nextSec = sysContent.indexOf('\n## ', ssIdx + 1);
          sysContent = sysContent.slice(0, ssIdx) + (nextSec !== -1 ? sysContent.slice(nextSec) : '');
        }
      }
      while (byteSizeWith(sysContent) > 8 * 1024 * 1024 && sysContent.length > 2000) {
        sysContent = sysContent.slice(0, Math.floor(sysContent.length * 0.8)) + '\n… [context trimmed for size]';
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
        chat_template_kwargs: { enable_thinking: enableThinkingFlag === true },
      });
      llmBodyBytes = Buffer.byteLength(finalBody, 'utf8');
    }
    console.log('[proxyAI] Payload size after trim:', (llmBodyBytes / 1024 / 1024).toFixed(2), 'MB');
  }


  {
    const _fpMs = (fastPath && turnTools.length) ? turnTools[0].elapsedMs : 0;
    Object.assign(requestTrace, {
      preparedMs: Date.now() - requestStartedAt,
      contextChars: resolvedContext.length,
      memoryCount: relevantMemories.length,
      memoryChars: relevantMemories.map((m) => m.fact).join('\n').length,
      promptChars: systemPrompt.length,
      attachedTools: tools.length,
    });
    console.log(`[proxyAI] pre-llm auth=${_tAuthMs}ms user=${_tUserMs}ms cap=${_tCapMs}ms ctx=${_tCtxMs}ms fp=${_fpMs}ms prompt=${systemPrompt.length}ch msgs=${nimMessages.length} tools=${tools.length} fastpath=${!!fastPath} light=${!!lightChat} staleArt=${_strippedArtifacts} stream=${isStreaming}`);
  }

  if (isStreaming) {
    let _streamedFinalReply = '';
    let _streamedReasoning = '';
    try {
      let currentMessages = [...nimMessages];
      let toolRound = 0;
      let llmCalls = 0;
      const MAX_LLM_CALLS_PER_MESSAGE = budget.calls;
      let _rememberSaved = false;
      let didArtifactRepair = false;
      let didDanglingRepair = false;
      let didActionRepair = false;
      let forceTextNextRound = false;
      let fullContent = '';
      let _ttftMs = null;
      let streamInterrupted = true;
      let _hitLengthLimit = false;
      const seenToolCalls = new Set();

      while (toolRound < MAX_TOOL_ROUNDS || forceTextNextRound) {
        workSignal.throwIfAborted();
        toolRound++;
        const _round0 = Date.now();
        const noToolsThisRound = forceTextNextRound;
        forceTextNextRound = false;

        let streamResp = null;
        let lastFetchError = null;
        let lastWas429 = false;
        for (let attempt = 0; attempt < 3; attempt++) {
          if (llmCalls >= MAX_LLM_CALLS_PER_MESSAGE) {
            lastFetchError = 'message call budget spent';
            break;
          }
          llmCalls++;
          requestTrace.modelCalls++;
          if (attempt > 0) requestTrace.retries++;
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
                ...(tools.length && !noToolsThisRound ? { tools, tool_choice: 'auto' } : {}),
                max_tokens: maxTokens,
                temperature: 0.6,
                top_p: 0.95,
                stream: true,
                chat_template_kwargs: { enable_thinking: enableThinkingFlag === true },
              }),
              signal: workSignal,
            });

            if (streamResp.ok) break;
            if (![429, 502, 503].includes(streamResp.status)) break;
            lastFetchError = `Agnes HTTP ${streamResp.status}`;
            lastWas429 = streamResp.status === 429;
          } catch (fetchErr) {
            lastFetchError = fetchErr.message;
            lastWas429 = false;
          }
          if (attempt < 2) {
            const waitMs = lastWas429 ? 12000 * (attempt + 1) : 1000 * (attempt + 1);
            await new Promise((r) => setTimeout(r, waitMs));
          }
        }

        if (!streamResp || !streamResp.ok) {
          console.warn(`proxyAI Agnes fetch failed after retries: ${lastFetchError || streamResp?.status}`);
          try {
            const fallback = composeTodayRecap({
              dateLabel: phtDateString(),
              moods: [], activities: [], watchlist: [], starlight: [],
              memories: [], insights: [],
            });
            const fallbackReply = fallback + " 🍡 Motchi is a little sleepy right now, but I'm still here. Try again in a moment?";
            requestTrace.firstTokenMs = Date.now() - requestStartedAt;
            sendEvent({ content: fallbackReply });
            sendEvent({ tool_result: { tool: 'reply_details', ...replyDetails(_streamedFinalReply, true) } });
            recordMotchiTurn({
              sessionId, caller, feature: feature || 'assistant',
              userMessage: lastUserMessage, assistantReply: fallbackReply,
              tools: turnTools, model, requestTrace,
              durationMs: Date.now() - requestStartedAt,
              error: lastFetchError || `Provider HTTP ${streamResp?.status}`,
              temporary: Boolean(temporary),
            }).catch(() => {});
            sendEvent({ tool_status: 'done' });
            sendEvent('[DONE]');
            stopKeepalive(); stopHeartbeat();
            return;
          } catch (_) {
            sendEvent({ error: 'Motchi got distracted and lost her train of thought. Try asking again?' });
          }
          break;
        }

        fullContent = '';
        let collectedToolCalls = [];

        const reader = streamResp.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';
        let roundFinished = false;
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
              if (finishReason) roundFinished = true;

          if (delta.reasoning) {
            _streamedReasoning += delta.reasoning;
            sendEvent({ reasoning: delta.reasoning });
          }
          if (delta.reasoning_content) {
            _streamedReasoning += delta.reasoning_content;
            sendEvent({ reasoning: delta.reasoning_content });
          }
              if (delta.content) {
                fullContent += delta.content;
                _streamedFinalReply += delta.content;
                sendEvent({ content: delta.content });
                stopHeartbeat();
                if (requestTrace.firstTokenMs === null) requestTrace.firstTokenMs = Date.now() - requestStartedAt;
                if (_ttftMs === null && toolRound === 1) {
                  _ttftMs = Date.now() - _round0;
                  console.log(`[proxyAI] ttft round=1 llm=${_ttftMs}ms total=${Date.now() - requestStartedAt}ms`);
                }
              }

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

              if (finishReason === 'tool_calls') {
                collectedToolCalls = collectedToolCalls.filter(Boolean);
              }
              if (finishReason === 'length') {
                _hitLengthLimit = true;
              }
            } catch (_) {}
          }
        }

        if (!roundFinished) throw new Error('Model stream ended before confirming completion');

        if (collectedToolCalls.length === 0) {
          if (!didArtifactRepair && canvasSectionOn && wantsArtifact && !hasCompleteArtifact(_streamedFinalReply)) {
            didArtifactRepair = true;
            requestTrace.repairs++;
            if (fullContent) currentMessages.push({ role: 'assistant', content: fullContent });
            currentMessages.push({ role: 'user', content: ARTIFACT_REPAIR_NUDGE });
            sendEvent({ tool_status: 'repairing' });
            fullContent = '';
            forceTextNextRound = true;
            continue;
          }
          if (!didDanglingRepair && endsWithDanglingColon(_streamedFinalReply)) {
            didDanglingRepair = true;
            requestTrace.repairs++;
            if (fullContent) currentMessages.push({ role: 'assistant', content: fullContent });
            currentMessages.push({ role: 'user', content: DANGLING_REPLY_NUDGE });
            sendEvent({ tool_status: 'repairing' });
            fullContent = '';
            forceTextNextRound = true;
            continue;
          }
          const actionMismatch = !didActionRepair ? findActionClaimMismatch(_streamedFinalReply, steps) : null;
          if (actionMismatch && llmCalls < MAX_LLM_CALLS_PER_MESSAGE) {
            didActionRepair = true;
            requestTrace.repairs++;
            if (fullContent) currentMessages.push({ role: 'assistant', content: fullContent });
            currentMessages.push({
              role: 'user',
              content: `You told the user you added or scheduled this to their ${actionMismatch.name}, but you did NOT actually call the ${actionMismatch.tool} tool! You must call ${actionMismatch.tool} right now to save it, or clarify that it was not saved yet.`,
            });
            sendEvent({ tool_status: 'repairing' });
            fullContent = '';
            const missingTool = MOTCHI_TOOLS.find((t) => t.function.name === actionMismatch.tool);
            if (missingTool && !tools.some((t) => t.function.name === actionMismatch.tool)) {
              tools = [...tools, missingTool];
            }
            continue;
          }
          streamInterrupted = false;
          break;
        }

        collectedToolCalls = dropRepeatCalls(seenToolCalls, collectedToolCalls);
        if (collectedToolCalls.length === 0) {
          forceTextNextRound = true;
          continue;
        }

        requestTrace.toolRounds++;
        sendEvent({ tool_status: 'executing' });

        currentMessages.push({
          role: 'assistant',
          content: fullContent || null,
          tool_calls: collectedToolCalls.map(tc => ({
            id: tc.id,
            type: 'function',
            function: { name: tc.function.name, arguments: tc.function.arguments },
          })),
        });

        const toolPromises = collectedToolCalls.map(async (tc) => {
          const fnName = tc.function.name;
          let fnArgs;
          try { fnArgs = JSON.parse(tc.function.arguments); } catch { fnArgs = {}; }

          sendEvent({ tool_status: fnName === 'request_tools' ? 'thinking' : fnName });
          const toolStartedAt = Date.now();
          let result;
          try {
            result = await executeToolCall(toolCtx, fnName, fnArgs);
          } catch (err) {
            result = JSON.stringify({ error: err.message || 'Tool execution failed', outcome_unknown: true });
          }

          if (TOOL_INVALIDATIONS[fnName]) {
            try { invalidateContextBlock(TOOL_INVALIDATIONS[fnName]); } catch (_) {}
          }

          try {
            if (typeof logToolCall === 'function') {
              logToolCall(fnName, caller, result, Date.now() - toolStartedAt).catch(() => {});
            }
          } catch (_) {}
          turnTools.push({
            name: fnName,
            args: fnArgs,
            resultSummary: typeof result === 'string' ? result.slice(0, 500) : JSON.stringify(result).slice(0, 500),
            elapsedMs: Date.now() - toolStartedAt,
          });

          if (fnName === 'remember_fact') {
            try { if (JSON.parse(result).success) _rememberSaved = true; } catch (_) {}
          }

          if (fnName === 'request_tools') {
            try {
              const parsedReq = JSON.parse(result);
              if (Array.isArray(parsedReq.memories)) {
                availableMemories.push(...parsedReq.memories);
              }
            } catch (_) {}
          }

          try {
            const parsed = JSON.parse(result);
            const step = captureResult(fnName, fnArgs, result);
            sendEvent({ tool_result: { tool: fnName, ...parsed, step } });
            if (parsed.needs_confirmation) {
              sendEvent({ tool_status: `${fnName}:needs_confirmation` });
            }
          } catch (_) {
            const step = captureResult(fnName, fnArgs, result);
            sendEvent({ tool_result: { tool: fnName, step } });
          }

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

        const requestCall = collectedToolCalls.find((tc) => tc.function?.name === 'request_tools');
        if (requestCall) {
          let reqArgs = {};
          try { reqArgs = JSON.parse(requestCall.function?.arguments || '{}'); } catch (_) {}
          const caps = Array.isArray(reqArgs.capabilities)
            ? reqArgs.capabilities
            : (reqArgs.capability ? [reqArgs.capability] : []);
          const tls = Array.isArray(reqArgs.tools) ? reqArgs.tools : [];
          const mountedNames = resolveToolsForCapabilities(caps, tls);
          if (mountedNames.length > 0) {
            const mountedSet = new Set(mountedNames);
            tools = MOTCHI_TOOLS.filter((t) => mountedSet.has(t.function.name));
          }
        }
        const visionMsg = visionMessageForResults(executedResults.map((tr) => tr.fullResult));
        if (visionMsg) currentMessages.push(visionMsg);

        sendEvent({ tool_status: `round_${toolRound}_done` });
        collectedToolCalls = [];
        fullContent = '';

        if (toolRound >= MAX_TOOL_ROUNDS) {
          forceTextNextRound = true;
        }
      }

      // Post-loop repair: the repeat-guard break and the 8-round cap
      // above both exit with no in-loop nudge, so a preamble like
      // "Let me save the standouts:" can reach Clair with no list.
      // Also handles empty replies where the model only ran tool calls
      // (or circled on repeat tool calls) without generating text.
      // Mirror the non-streaming path: one final text-only call whose
      // content streams after the preamble as one finished reply.
      const needsEmptyRepair = !_streamedFinalReply.trim() && llmCalls < MAX_LLM_CALLS_PER_MESSAGE;
      const needsPostLoopRepair = (!didDanglingRepair &&
        endsWithDanglingColon(_streamedFinalReply) &&
        llmCalls < MAX_LLM_CALLS_PER_MESSAGE) || needsEmptyRepair;
      if (needsPostLoopRepair) {
        didDanglingRepair = true;
        requestTrace.repairs++;
        llmCalls++;
        requestTrace.modelCalls++;
        if (fullContent) currentMessages.push({ role: 'assistant', content: fullContent });
        if (currentMessages[currentMessages.length - 1]?.role !== 'tool') {
          currentMessages.push({
            role: 'user',
            content: needsEmptyRepair
              ? 'Please answer the user directly and warmly in text based on what we have so far.'
              : DANGLING_REPLY_NUDGE,
          });
        }
        sendEvent({ tool_status: 'repairing' });
        try {
          const repairResp = await fetch('https://apihub.agnes-ai.com/v1/chat/completions', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${apiKey}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              model,
              messages: currentMessages,
              max_tokens: maxTokens,
              temperature: 0.6,
              top_p: 0.95,
              stream: false,
              chat_template_kwargs: { enable_thinking: false },
            }),
            signal: workSignal,
          });
          if (repairResp && repairResp.ok) {
            const repairData = await repairResp.json();
            const repairText = repairData.choices?.[0]?.message?.content || '';
            if (repairText) {
              if (requestTrace.firstTokenMs === null) requestTrace.firstTokenMs = Date.now() - requestStartedAt;
              _streamedFinalReply += repairText;
              sendEvent({ content: repairText });
              streamInterrupted = false;
            }
          }
        } catch (e) {
          console.warn('proxyAI post-loop dangling repair failed:', e.message);
        }
      }

      stopKeepalive();
      stopHeartbeat();
      if (_hitLengthLimit) {
        console.warn('[proxyAI] model hit max_tokens mid-reply — artifact may be truncated (no closing fence, no Preview button).');
      }
      sendEvent({ tool_result: { tool: 'reply_details', ...replyDetails(_streamedFinalReply, _hitLengthLimit || streamInterrupted) } });
      sendEvent({ tool_status: 'done' });
      sendEvent('[DONE]');
      try {
        if (_streamedFinalReply.trim()) {
          const checkText = stripArtifactsForChecks(_streamedFinalReply);
          const canSaveMemories = !temporary && !workSignal.aborted;
          if (canSaveMemories && checkText && !_rememberSaved && shouldExtractMemory(lastUserMessage, checkText)) {
            serverExtractAndSaveMemory(lastUserMessage, checkText, caller).catch(() => {});
          }
          if (!temporary && !workSignal.aborted && checkText) checkHallucinations(checkText).catch(() => {});
        }
      } catch (postErr) {
        console.warn('proxyAI post-reply tasks error:', postErr.message);
      }

      recordMotchiTurn({
        sessionId,
        caller,
        feature: feature || 'assistant',
        userMessage: lastUserMessage,
        assistantReply: _streamedFinalReply,
        tools: turnTools,
        reasoning: _streamedReasoning,
        model,
        requestTrace,
        durationMs: Date.now() - requestStartedAt,
        error: null,
        imageCount: (messages.filter((m) => m && m.role === 'user').pop()?.imageUrls || []).length,
        temporary: Boolean(temporary),
      }).catch(() => {});
    } catch (e) {
      console.warn('proxyAI streaming error:', e.message);
      sendEvent({ tool_result: { tool: 'reply_details', ...replyDetails(_streamedFinalReply, true) } });
      if (!_streamedFinalReply.trim()) {
        sendEvent({ error: 'Motchi got distracted and lost her train of thought. Try asking again?' });
      }
      sendEvent('[DONE]');
      recordMotchiTurn({
        sessionId,
        caller,
        feature: feature || 'assistant',
        userMessage: lastUserMessage,
        assistantReply: _streamedFinalReply,
        tools: turnTools,
        reasoning: _streamedReasoning,
        model,
        requestTrace,
        durationMs: Date.now() - requestStartedAt,
        error: e.message,
        imageCount: (messages.filter((m) => m && m.role === 'user').pop()?.imageUrls || []).length,
        temporary: Boolean(temporary),
      }).catch(() => {});
    } finally {
      stopKeepalive();
      stopHeartbeat();
      res.end();
    }
    return;
  }

  async function callLlmOnce(msgs, withoutTools = false) {
    workSignal.throwIfAborted();
    if (requestTrace.modelCalls >= budget.calls) throw new Error('Motchi reached this request\'s work limit.');
    requestTrace.modelCalls++;
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
          ...(tools.length && !withoutTools ? { tools, tool_choice: 'auto' } : {}),
          max_tokens: maxTokens,
          temperature: 0.6,
          top_p: 0.95,
          stream: false,
          chat_template_kwargs: { enable_thinking: enableThinkingFlag === true },
        }),
        signal: workSignal,
      },
    );
    return resp;
  }

  function nonStreamError(status, detail) {
    if (status === 413) {
      console.error('[proxyAI] Model returned 413:', detail);
      return res.status(413).json({
        error: `Payload too large. ${detail}`,
        model: model,
      });
    }
    return res.status(status).json({
      error: `Model returned ${status}`,
      detail,
      model: model,
    });
  }

  // ── Non-streaming mode: bounded agent loop ───────────────
  // Mirrors the streaming loop without SSE. One-shot callers (Undo
  // restores, recommendations, date ideas) answer with tool calls just
  // like chat does — dropping them silently broke Undo restores.
  const nsMessages = [...nimMessages];
  const nsSeen = new Set();
  let nsReply = '';
  let nsReasoning = '';
  let _nsRememberSaved = false;
  let didNsActionRepair = false;
  let nsModel = model;
  let nsInterrupted = true;
  for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
    if (workSignal.aborted) break;
    let response;
    try {
      response = await callLlmOnce(nsMessages);
    } catch (_) {
      response = null;
    }
    if (!response || !response.ok) {
      if (round > 0) break;
      nonStreamError(response ? response.status : 502, 'No response from the model');
      return;
    }
    const data = await response.json();
    nsModel = data.model || nsModel;
    const message = data.choices?.[0]?.message || {};
    if (message.reasoning) nsReasoning += message.reasoning;
    if (message.reasoning_content) nsReasoning += message.reasoning_content;
    if (message.content) nsReply += message.content;
    const freshCalls = (message.tool_calls || []).filter(Boolean).filter((tc) => {
      const key = `${tc.function?.name || ''}:${tc.function?.arguments || ''}`;
      if (nsSeen.has(key)) return false;
      nsSeen.add(key);
      return true;
    });
    if (freshCalls.length === 0) {
      if (!didNsActionRepair) {
        const mismatch = findActionClaimMismatch(nsReply, steps);
        if (mismatch && round < MAX_TOOL_ROUNDS - 1) {
          didNsActionRepair = true;
          requestTrace.repairs++;
          nsMessages.push({ role: 'assistant', content: nsReply });
          nsMessages.push({
            role: 'user',
            content: `You told the user you added or scheduled this to their ${mismatch.name}, but you did NOT actually call the ${mismatch.tool} tool! You must call ${mismatch.tool} right now to save it, or clarify that it was not saved yet.`,
          });
          const missingTool = MOTCHI_TOOLS.find((t) => t.function.name === mismatch.tool);
          if (missingTool && !tools.some((t) => t.function.name === mismatch.tool)) {
            tools = [...tools, missingTool];
          }
          continue;
        }
      }
      nsInterrupted = false;
      break;
    }
    requestTrace.toolRounds++;
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
        result = JSON.stringify({ error: err.message || 'Tool execution failed', outcome_unknown: true });
      }
      if (TOOL_INVALIDATIONS[fnName]) {
        try { invalidateContextBlock(TOOL_INVALIDATIONS[fnName]); } catch (_) {}
      }
      try {
        if (typeof logToolCall === 'function') {
          logToolCall(fnName, caller, result, Date.now() - toolStartedAt).catch(() => {});
        }
      } catch (_) {}
      turnTools.push({
        name: fnName,
        args: fnArgs,
        resultSummary: typeof result === 'string' ? result.slice(0, 500) : JSON.stringify(result).slice(0, 500),
        elapsedMs: Date.now() - toolStartedAt,
      });
      captureResult(fnName, fnArgs, result);
      if (fnName === 'remember_fact') {
        try { if (JSON.parse(result).success) _nsRememberSaved = true; } catch (_) {}
      }
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

    const nsRequestCall = freshCalls.find((tc) => tc.function?.name === 'request_tools');
    if (nsRequestCall) {
      let reqArgs = {};
      try { reqArgs = JSON.parse(nsRequestCall.function?.arguments || '{}'); } catch (_) {}
      const caps = Array.isArray(reqArgs.capabilities)
        ? reqArgs.capabilities
        : (reqArgs.capability ? [reqArgs.capability] : []);
      const tls = Array.isArray(reqArgs.tools) ? reqArgs.tools : [];
      const mountedNames = resolveToolsForCapabilities(caps, tls);
      if (mountedNames.length > 0) {
        const mountedSet = new Set(mountedNames);
        tools = MOTCHI_TOOLS.filter((t) => mountedSet.has(t.function.name));
      }
    }
    const visionMsg = visionMessageForResults(results.map((r) => r.fullResult));
    if (visionMsg) nsMessages.push(visionMsg);
  }

  if (nsInterrupted && nsMessages[nsMessages.length - 1]?.role === 'tool') {
    try {
      const synthesizeOnly = true;
      const finalResp = await callLlmOnce(nsMessages, synthesizeOnly);
      if (finalResp && finalResp.ok) {
        const finalData = await finalResp.json();
        const finalMsg = finalData.choices?.[0]?.message || {};
        if (finalMsg.content) {
          nsReply += finalMsg.content;
          nsInterrupted = false;
        }
      }
    } catch (_) {}
  }

  if (canvasSectionOn && wantsArtifact && !hasCompleteArtifact(nsReply)) {
    requestTrace.repairs++;
    if (nsReply) nsMessages.push({ role: 'assistant', content: nsReply });
    nsMessages.push({ role: 'user', content: ARTIFACT_REPAIR_NUDGE });
    try {
      const repairResp = await callLlmOnce(nsMessages, true);
      if (repairResp && repairResp.ok) {
        const repairData = await repairResp.json();
        const repairMsg = repairData.choices?.[0]?.message || {};
        if (repairMsg.content) nsReply += repairMsg.content;
      }
    } catch (_) {}
  }

  if (endsWithDanglingColon(nsReply)) {
    requestTrace.repairs++;
    if (nsReply) nsMessages.push({ role: 'assistant', content: nsReply });
    nsMessages.push({ role: 'user', content: DANGLING_REPLY_NUDGE });
    try {
      const danglingResp = await callLlmOnce(nsMessages, true);
      if (danglingResp && danglingResp.ok) {
        const danglingData = await danglingResp.json();
        const danglingMsg = danglingData.choices?.[0]?.message || {};
        if (danglingMsg.content) nsReply += danglingMsg.content;
      }
    } catch (_) {}
  }

  const details = replyDetails(nsReply, nsInterrupted);
  const reply = stripMemoryCitations(nsReply).trim();
  res.json({ reply, reasoning: nsReasoning, model: nsModel, details });
  recordMotchiTurn({
    sessionId,
    caller,
    feature: feature || 'assistant',
    userMessage: lastUserMessage,
    assistantReply: reply,
    tools: turnTools,
    reasoning: nsReasoning,
    model: nsModel || model,
    requestTrace,
    durationMs: Date.now() - requestStartedAt,
    error: null,
    imageCount: (messages.filter((m) => m && m.role === 'user').pop()?.imageUrls || []).length,
    temporary: Boolean(temporary),
  }).catch(() => {});
  if (reply) {
    const checkText = stripArtifactsForChecks(reply);
    const canSaveMemories = !temporary && !workSignal.aborted;
    if (canSaveMemories && checkText && !_nsRememberSaved && shouldExtractMemory(lastUserMessage, checkText)) {
      serverExtractAndSaveMemory(lastUserMessage, checkText, caller).catch(() => {});
    }
    if (canSaveMemories && checkText) checkHallucinations(checkText).catch(() => {});
  }
}

module.exports = {
  handleProxyAI,
  stripArtifactsForChecks,
  stripStaleArtifacts,
  hasCompleteArtifact,
  endsWithDanglingColon,
  findActionClaimMismatch,
};
