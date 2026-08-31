# Mochi Agent Architecture Plan — ARCHIVED (Implemented with Agnes)

> **Historical note (2026-08):** This plan was written for Groq (`openai/gpt-oss-120b` / `qwen/qwen3.6-27b`). Everglow has since migrated to **Agnes 2.5 Flash** via `https://apihub.agnes-ai.com` (`proxyAI`/`proxyAIv2` on Cloud Run, `AGNES_API_KEY`, 512K context, `AGNES_INPUT_TOKEN_BUDGET=120000`). `MOCHI_ARCHITECTURE_PLAN.md` is retained for context — phase checklists below map to the current Agnes implementation.


## Summary

Transform Mochi from a single-shot chatbot into a real agent with custom tool execution, an agentic loop, smarter memory, and proactive behavior. The model is now `agnes-2.5-flash` via Agnes (apihub.agnes-ai.com) — all improvements were architectural and are now live on `proxyAI`/`proxyAIv2`.

---

## Phase 1: Custom Function Calling + Agent Loop (HIGH IMPACT)

**Goal:** Mochi can *do things* — add movies, save notes, set moods, search TMDB, create reminders — via structured tool calls, not just talk.

### 1A. Tool Schemas (`functions/index.js`)

Define `MOCHI_TOOLS` array with OpenAI-compatible function schemas:

| Tool | Purpose | Writes to |
|------|---------|-----------|
| `add_to_watchlist` | Add movie/show to shared watchlist | `our_cinema` (via TMDB lookup) |
| `save_to_starlight_jar` | Save a gratitude note | `starlight_jar` |
| `set_mood` | Update user's mood | `moods` |
| `search_movies` | Search TMDB for titles | Read-only (TMDB API) |
| `get_weather` | Weather for date planning | Read-only (wttr.in) |
| `create_reminder` | Set a reminder | `reminders` (new collection) |
| `log_activity` | Log notable activity | `recent_activity` |

### 1B. Tool Executors (`functions/index.js`)

`executeTool(toolName, args, callerUid)` — async function that:
- Routes to the correct Firestore write / API call
- Returns a string result for the model to consume
- Handles errors gracefully (returns error string, not throw)

### 1C. Agent Loop (`functions/index.js`)

Replace the single Agnes call with a loop:

```
while (round < MAX_TOOL_ROUNDS = 5):
  call Agnes (apihub.agnes-ai.com) with stream: true
  accumulate response (content + tool_calls)
  if no tool_calls → stream content to client → DONE
  if tool_calls → execute each tool → append results → loop
```

- Only the **final** text response streams to the client
- Tool execution happens server-side (invisible to the client)
- `TOOL_TIMEOUT_MS = 15000` per tool
- `MAX_TOOL_ROUNDS = 5` prevents infinite loops

### 1D. SSE Streamer (minimal change)

The proxy absorbs all tool complexity — client still only sees `reasoning` and `content` deltas. Optional: add `tool_status` events for UX ("Mochi is searching...").

### 1E. System Prompt Update

Add tool awareness to Mochi's persona:
- When to use each tool
- "Always prefer custom tools over browser_search when the action maps to an Everglow feature"
- "After executing a tool, acknowledge the result naturally"

### Token Budget Adjustment

Tool schemas add ~1000 tokens. Increase `Agnes_INPUT_TOKEN_BUDGET` to 120000 (Agnes 2.5 Flash offers 512K context; tool schemas ~1K).

### Files Modified
| File | Change |
|------|--------|
| `functions/index.js` | Add `MOCHI_TOOLS`, `executeTool()`, rewrite streaming as agent loop, update persona |
| `lib/features/ai/domain/models/ai_conversation.dart` | Add `toolCalls` field to `AIMessage` (for persistence) |

---

## Phase 2: Memory Improvements (MEDIUM IMPACT)

**Goal:** Smarter memory — inject only relevant facts, decay stale ones, extract richer info.

### 2A. Selective Memory Retrieval (`functions/index.js`)

Instead of injecting all 50 memories, use TF-IDF keyword matching to select the top 15 relevant ones per query:

```
extractKeywords(text) → stop-word filtered keywords
memoryRelevanceScore(fact, queryKeywords) → overlap ratio
selectRelevantMemories(memories, userMessage, max=15) → ranked subset
```

Saves ~300 tokens per request.

### 2B. Memory Confidence + Decay (`ai_memory_repo.dart`)

Add to each memory document:
- `confidence` (0.0–1.0, starts at 1.0)
- `accessCount` (incremented when used in context)
- `lastAccessed` (timestamp)

Decay: if not accessed in 60 days, halve confidence. Filter out memories with confidence < 0.3.

### 2C. LLM-Powered Extraction (`ai_service.dart`)

Replace keyword-triggered extraction with always-on LLM extraction:
- Ask the model to extract ONE personal fact from every exchange
- Use `CATEGORY|FACT` format for auto-categorization
- Categories: fact, preference, dislike, goal, date, habit

### Files Modified
| File | Change |
|------|--------|
| `functions/index.js` | Add `selectRelevantMemories()`, modify prompt injection |
| `lib/features/ai/data/services/ai_memory_repo.dart` | Add `MemoryEntry` model, confidence/decay logic |
| `lib/features/ai/domain/repositories/ai_memory_repo_interface.dart` | Add `MemoryEntry` type |
| `lib/features/ai/data/services/ai_service.dart` | Replace `_extractAndSaveMemories` with LLM-powered version |

---

## Phase 3: Proactive Behavior (MEDIUM IMPACT)

**Goal:** Mochi initiates conversations — daily digest, mood check-ins, special day nudges.

### 3A. Daily Digest (8:00 AM PHT)

`mochiDailyDigest` — Cloud Scheduler → gather context → call Agnes for a short digest → FCM push to both users.

### 3B. Mood Check-In (8:00 PM PHT)

`mochiMoodCheckIn` — check who hasn't logged mood today → FCM nudge.

### 3C. Special Day Nudges (9:00 AM PHT)

`mochiSpecialDayNudge` — anniversary (Feb 14), birthdays (Oct 26, Feb 21) → FCM nudge within 7 days.

### 3D. Client-Side FCM (`notification_service.dart`)

New service: FCM permission, token management (saved to Firestore per-user), foreground message handling, notification tap routing.

### Files Modified
| File | Change |
|------|--------|
| `functions/index.js` | Add 3 scheduled functions |
| `lib/core/services/notification_service.dart` | New file: FCM init, token management, message handling |
| `lib/main.dart` | Initialize `NotificationService` |

---

## Phase 4: Response Validation + Self-Healing (LOW-MEDIUM IMPACT)

**Goal:** Verify movie titles against TMDB before sending. If hallucinated, auto-correct.

### 4A. Movie Title Validation (`functions/index.js`)

After the agent loop produces a final response, extract quoted/capitalized titles and search TMDB. Flag titles with zero results.

### 4B. Self-Healing Regeneration

If hallucinated titles found, append a correction message and re-call Agnes (1 extra round):
> "These titles don't exist on TMDB: X, Y. Please replace with real titles. Use search_movies tool."

### Files Modified
| File | Change |
|------|--------|
| `functions/index.js` | Add `validateMovieTitles()`, integrate into agent loop |

---

## Phase 5: LLM-Powered Session Summarization (LOW IMPACT)

**Goal:** Better session summaries for context continuity.

### 5A. Replace Local Summarization (`ai_conversation_repo.dart`)

Replace `_buildLocalSummary` (keyword extraction) with `_buildLLMSummary` (Agnes call). Runs only on session archival (~every 20 messages).

### 5B. Session Compression

When summarized sessions exceed 10, merge oldest 5 into a single meta-summary.

### Files Modified
| File | Change |
|------|--------|
| `lib/features/ai/data/services/ai_conversation_repo.dart` | Replace `_buildLocalSummary`, add `_compressOldSessions` |

---

## Implementation Order

```
Week 1-2: Phase 1 — Custom Tools + Agent Loop
  1A → 1B → 1C → 1D → 1E
  Unlocks everything else.

Week 3: Phase 2 — Memory Improvements
  2A → 2B → 2C

Week 4: Phase 3 — Proactive Behavior
  3A → 3B → 3C → 3D

Week 5: Phase 4 + 5 in parallel
  4A → 4B  |  5A → 5B
```

---

## Token Budget Impact

| Component | Current | After Phase 1 | After Phase 2 |
|-----------|---------|---------------|---------------|
| System prompt | ~3500 | ~3500 | ~3500 |
| Tool schemas | 0 | ~1000 | ~1000 |
| Memories | ~500 (all) | ~500 (all) | ~200 (15 relevant) |
| Conversation | ~2000 | ~2000 | ~2000 |
| **Total** | **~6000** | **~7000** | **~6700** |

Agnes 2.5 Flash offers 512K context — we're safe (budget 120K).

---

## Verification

### Phase 1
- [ ] `flutter analyze` — no new errors
- [ ] Ask Mochi "add Interstellar to our watchlist" → verify Firestore write
- [ ] Ask Mochi "save a note saying I love you" → verify Starlight Jar entry
- [ ] Ask Mochi "I'm feeling happy today" → verify mood logged
- [ ] Ask Mochi "what's the weather?" → verify weather response
- [ ] Streaming still works through the agent loop
- [ ] Max 5 tool rounds enforced

### Phase 2
- [ ] Ask about movies → verify only relevant memories injected (not all 50)
- [ ] Check old memories decay after 60 days
- [ ] Memory extraction runs on every exchange (not just keyword triggers)

### Phase 3
- [ ] Daily digest FCM received at 8:00 AM
- [ ] Mood check-in FCM received at 8:00 PM (only if no mood logged)
- [ ] Birthday/anniversary nudge received within 7 days

### Phase 4
- [ ] Ask Mochi for movie recommendations → verify real titles only
- [ ] If hallucinated title detected → verify self-healing correction

### Phase 5
- [ ] Session archive contains LLM-generated summary
- [ ] Old sessions compress into meta-summaries
