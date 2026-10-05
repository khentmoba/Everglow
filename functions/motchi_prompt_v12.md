# Motchi System Prompt — v12 snapshot (2026-10-01)

> Versioned snapshot of the live prompt (fallback `systemPrompt` in
> `motchi_chat.js` + `MOTCHI_TOOLS` in `motchi_tool_schemas.js` +
> intent routing in `motchi_tools.js` `selectToolNames`; executors in
> `motchi_exec_{media,memory,social,planning,insights}.js` via the
> `motchi_exec_tools.js` dispatcher).
> The Firestore `ai_memories/shared/persona/motchi` doc or per-request
> `systemPrompt` can override this at runtime — this file pins what
> `main` shipped so evals and the gate have a stable reference.
>
> v6 changes vs v5: new fast-path execution layer — whole-message
> zero-arg read-only asks (`get_xp_stats`, `get_today_recap`,
> `list_reminders`, `get_relationship_insights` via `matchFastPath`)
> skip the context + memory reads, pre-execute the tool, and answer
> from the result with no tools attached (one Firestore read + one
> LLM call). Trivia stays out on purpose: "quiz us" deserves the
> interactive canvas. Follow-through routing keeps plan write tools
> on a bare yes to an offer. Four edit tools close the gaps:
> `edit_bucket_item`, `edit_habit`, `edit_reminder`, `edit_trip`
> (63 tools total).
>
> v7 changes vs v6: read/write routing split — intent groups attach
> read tools on match and write tools only when an action-verb
> trigger (`writeMatch`, else global `WRITE_INTENT_RE`) hits, so
> read-only asks stop carrying write schemas (avg attached 9.9 →
> 5.9, schema tokens −43%, recall stays 100% on all 67 eval cases).
> Core shrinks to `read_memories` + `add_xp`; `set_mood`,
> `save_to_starlight_jar`, `remember_fact` move to their intent
> groups (mood/starlight/memory) and join `FOLLOW_THROUGH_TOOLS`
> so offered plans still execute on a bare yes. Context blocks go
> adaptive: keyword hits up to 7, defaults fill only to 4 (was:
> always 7), cutting cold-turn Firestore reads ~10 → ~7. Fast-path
> grows 4 → 7 asks (watchlist, calendar, starlight reads join),
> each answering in one read + one LLM call. Bump to
> `motchi_prompt_v8.md` (and update `eval_gate.js`
> `EXPECTED_PROMPT_VERSION`) when the persona or routing policy
> changes.
>
> v8 changes vs v7: Motchi finally knows what day it is — the
> proactive context block always leads with a Philippine-time date
> line (countdowns moved to PHT too, so birthdays never flip a day
> early). Memory reads got cheaper and smarter: fetched facts are
> cached 90s (invalidated on every write) and stored embeddings now
> ride into ranking, so the remote query vector actually matches
> semantically instead of being discarded; casual asks skip the
> embedding round-trip. The recommend intent group also attaches
> `search_movies` + `get_date_ideas`, so bare asks like "suggest
> something for tonight" can act. Plain chat carries a slim canvas
> pointer (~0.7KB) instead of the full guide (~2.5KB); explicit
> artifact asks — plus a bare yes to an offered quiz/game — still
> get the full guide.
>
> v9 changes vs v8: context-aware routing — when the current message
> names no group, the previous user turn lends its topics, and
> third-person pronouns (it/that/this) union context with the current
> match; write gating always reads the current message only.
> Eval set grows to 134 with paraphrase coverage (every tool now
> has 2+ phrasings); 15 routing gaps the paraphrases exposed are
> fixed (movie watching/queue/stick/take-off, chat send/note,
> memory cues + corrections, recap summarize, calendar schedule
> predicate + clock-time reads + push-to-time, bucket list verbs,
> trip shifts, web links). Reminder dates gain weekday names,
> tmrw, noon/midnight, dayparts, and "in N days at H". Loop
> guard is a pure tested helper (`dropRepeatCalls`). New
> `motchi_failure_corpus` (160 cases) pins validation, fast-path,
> routing, follow-through, and schedulability at 100%.
>
> v11 changes vs v10: archival recall — new `search_sessions` tool
> (past-tense recall group) searches the 12 freshest
> `motchi_sessions` docs for what was said before, so "what did we
> talk about last week" finally works (66 tools). Nightly sweep
> gains a Mem0-style merge pass (`findDuplicateGroups`: cosine ≥
> 0.93 + same subject/relation; survivor = pinned, confidence,
> oldest; max 5 groups/night, never deletes pinned). Eval set grows
> to 140 with session-recall + profile coverage. Tool calls harden:
> `normalizeToolArgs` (trim/coerce/alias/enum) runs pre-validation,
> validation errors carry a `fix` hint, and transient throws get one
> retry. Eval gate scores routing: reachability, group-name typos,
> fast-path zero-arg, recall, and attached-schema cap (24). Core
> memory: new `save_profile_note` tool (confirm-gated) writes pinned
> `profile` facts that ride an always-on ## About Them block via
> `selectCoreProfileNotes` (shared cache, zero extra reads) instead
> of ranking (67 tools). Bump to
> `motchi_prompt_v12.md` (and update `eval_gate.js`
> `EXPECTED_PROMPT_VERSION`) when the persona or routing policy
> changes.

- version: 12
- model: glm-5.3-flash (1M context, input budget 120000)
- tool rounds: up to 8 (`MAX_TOOL_ROUNDS`), 25s per tool (`TOOL_TIMEOUT_MS`)
- prompt char guard: 50000 (`PROMPT_CHAR_LIMIT`)
- memory injection: server-owned, relevant facts only, max 10 / 2000 chars (`selectPromptMemories`)
- gallery vision: max 3 thumbnails per round (`VISION_IMAGES_PER_ROUND`)

## v10: lean memory and context
- Chat no longer loads/uploads the client Memory Book. Server candidates
  retain metadata: 150 recent facts + up to 20 old pins, cached 90s.
- General explanations skip memory retrieval. Personal requests receive
  matching facts plus at most two core pins; broad personal paraphrases
  retain a small fallback. Missing details use read_memories, not guesses.
- Context fetches keyword hits only; vague personal questions retain two
  awareness blocks. Date and verified identity stay available.
- Dynamic context reaches saved/custom personas as well as the fallback.
- All memory vectors are local 64-dim; saves and the nightly sweep use
  zero embedding API calls (legacy remote-space vectors still rank via
  local recompute).
- Numeric request diagnostics record model calls, retries, tool rounds,
  repairs, preparation/first-token timing, and prompt/context/memory sizes.
- Core tools are 5 since #418 (`read_memories`, `add_xp`, `web_search`,
  `read_web_page`, `browse_web`); the runtime tool list renders for every
  persona, including the cached Firestore one.

## Routing policy (pinned)

1. Prefer custom tools over `web_search` when the ask maps to an
   Everglow feature (cinema, books, moods, chat, garden, music, …).
2. `web_search` only for current/external info (news, prices, schedules,
   release dates); `read_web_page` (max 3 URLs) when snippets are thin;
   `browse_web` only when a page needs interaction or reads as blocked.
3. Complex multi-step asks ("plan our anniversary", "surprise us") run
   ReAct style: decompose → sequence tools (≤8 rounds) → synthesize one
   warm plan, never raw JSON.
4. After a tool result, acknowledge naturally — naming what was saved
   or found in visible text, never leaving a preamble ending with ":"
   hanging with no list after it; no tools for plain chat or when the
   answer is already in context.
5. Ambiguous picks return `needs_confirmation` candidates and re-call
   with the chosen id (`tmdb_id` / `open_library_key` / doc id).
6. Destructive acts confirm first (`delete_memory`,
   `remove_from_watchlist`, `cancel_reminder`, `delete_journal_entry`,
   `delete_calendar_event`, `delete_bucket_item` with `confirm:true`).
7. Intent routing: every request sends the 5 core tools
   (`read_memories`, `add_xp`, `web_search`, `read_web_page`,
   `browse_web`) plus only the intent groups whose
   keywords match the message — reads always, writes only when the
   group's action-verb trigger matches (typically 4-8 of 67
   schemas). Pure greetings send none; unmatched messages add the
   read-only awareness set. Every eval case's expectedTools must stay
   a subset of `selectToolNames(message)`. When the message names no
   group, the previous user turn lends its topics; it/that/this
   unions context with the current match; writes gate on current.
   Calendar clock-time matches attach reads only, unless a
   reschedule verb (move/shift/push/…) or calendar noun is present.
8. Loop guard: a repeated tool+args pair in one message ends the tool
   loop instead of burning another paid round.
9. The persona's tool list renders per request from the attached
   tools only (names; descriptions ride with the schemas).
10. Gallery vision: `get_gallery(include_images:true)` only when they
    ask about photo contents; thumbnails attach to the next round as
    image input, never as text.
11. Dangling-list repair: when the accumulated reply ends with ":" and
    the round carried no tool calls, both answer paths spend at most
    one continuation nudge asking for just the promised list.
12. Fast-path: a whole-message zero-arg read-only ask matching
    `matchFastPath` (assistant only, never thinking/artifacts) skips
    context + memory reads, pre-executes its one tool, and appends a
    synthetic assistant+tool pair answered with no tools attached.
    Anchored patterns + conjunction/multi-sentence/length guards;
    anything compound falls through to the normal loop.
13. Follow-through: a bare affirmation (`isBareYes`) keeps the write
    set (`FOLLOW_THROUGH_TOOLS`) only when the previous assistant
    message shows an offer (`hasOffer`) — so "yes" executes the
    plan using details Motchi already named, and never asks twice.
14. Date awareness: the proactive context block always leads with the
    Philippine-time date line, and birthday/anniversary countdowns
    are computed in PHT — Motchi can reason about weekends,
    tomorrows, and countdowns on every turn.
15. Canvas tiers: plain chat carries the slim canvas pointer (fence
    names + compact shapes); explicit artifact asks, artifact
    follow-ups, and a bare yes to an offered quiz/game/flashcards
    upgrade to the full guide for the build turn.

## Tool inventory (67)

add_to_watchlist, save_to_starlight_jar, set_mood, search_movies,
get_weather, create_reminder, list_reminders, cancel_reminder,
log_activity, search_books, get_date_ideas, read_chat_messages,
send_sanctuary_message, get_xp_stats, search_anime,
add_book_to_our_books, read_starlight_jar, get_watchlist, remember_fact,
read_memories, pin_memory, delete_memory, edit_memory, web_search,
read_web_page, mark_watchlist_item_watched, update_book_progress, add_xp,
browse_web,
send_note_to_partner, get_relationship_insights, get_memory_trivia,
get_today_recap, get_gallery, get_garden, get_canvas, search_spotify,
remove_from_watchlist, search_everglow, plan_date_night,
add_calendar_event, create_journal_entry, add_bucket_item, add_trip,
add_trip_pin, log_habit, complete_habit, get_calendar_events,
get_bucket_list, get_journal_entries, search_journal_entries,
read_journal_entry, get_trips, edit_journal_entry, delete_journal_entry,
update_calendar_event, delete_calendar_event, complete_bucket_item,
delete_bucket_item, edit_bucket_item, edit_habit, edit_reminder,
edit_trip, get_subscriptions, add_subscription, search_sessions,
save_profile_note, request_tools, propose_choices

## v12: memory explanations and honest execution

- Runtime trust instructions apply to every non-light-chat persona. When a
  saved fact shapes a reply, explain its relevance and cite [[memory:ID]].
  Only IDs from this turn's retrieved/core/read_memories facts are accepted;
  unknown IDs never become memory cards. The UI hides citation syntax.
- Preferences belong to their explicitly named subject, not their author.
  Never generalize Clair's or Khent's preferences to both. Core notes can
  change; offer corrections through the existing edit_memory tool.
- Receipts come from tool results, not generated prose. Every executed step
  is done, waiting, failed, unscheduled, or unknown. Persist these with the
  reply, including non-streaming, cancellation, and interrupted requests.
- A plan is not a saved action. Separate saved steps from pending ones and
  offer to finish only unfinished work. Verify unknown writes before retry.
- Write tools are never automatically retried after a throw/timeout: they
  may still complete. Read tools retain their bounded transient retry.
- Prompt snapshot successor is v13 when this contract changes again.
