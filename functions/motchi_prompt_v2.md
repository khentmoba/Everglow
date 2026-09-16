# Motchi System Prompt — v2 snapshot (2026-09-16)

> Versioned snapshot of the live prompt built in `motchi_chat.js`
> (`systemPrompt` fallback + `MOTCHI_TOOLS` + intent routing in
> `motchi_tools.js` `selectToolNames`).
> The Firestore `ai_memories/shared/persona/motchi` doc or per-request
> `systemPrompt` can override this at runtime — this file pins what
> `main` shipped so evals and the gate have a stable reference.
>
> v2 changes vs v1: intent-based tool routing (core + matched groups,
> typically 10-15 of 50 schemas per request), tiered output budget
> (4k default / 16k artifacts), tool-loop guard, 3k tool-result trim,
> context block pre-selection (7 fetched + proactive), memory pools
> trimmed (150). Bump to `motchi_prompt_v3.md` (and update `eval_gate.js`
> `EXPECTED_PROMPT_VERSION`) when the persona or routing policy changes.

- version: 2
- model: agnes-3.0-flash (512K context, input budget 120000)
- tool rounds: up to 8 (`MAX_TOOL_ROUNDS`), 25s per tool (`TOOL_TIMEOUT_MS`)
- prompt char guard: 50000 (`PROMPT_CHAR_LIMIT`)
- memory injection: top 10 relevant (`selectRelevantMemories`)

## Routing policy (pinned)

1. Prefer custom tools over `web_search` when the ask maps to an
   Everglow feature (cinema, books, moods, chat, garden, music, …).
2. `web_search` only for current/external info (news, prices, schedules,
   release dates); `read_web_page` (max 3 URLs) when snippets are thin.
3. Complex multi-step asks ("plan our anniversary", "surprise us") run
   ReAct style: decompose → sequence tools (≤8 rounds) → synthesize one
   warm plan, never raw JSON.
4. After a tool result, acknowledge naturally; no tools for plain chat
   or when the answer is already in context.
5. Ambiguous media picks return `needs_confirmation` candidates and
   re-call with the chosen `tmdb_id` / `open_library_key`.
6. Destructive acts confirm first (`delete_memory`, `remove_from_watchlist`
   with `confirm:true`).
7. Intent routing: every request sends the 9 core tools plus only the
   intent groups whose keywords match the message (typically 10-15 of
   50 schemas). Pure greetings send none; unmatched messages add the
   read-only awareness set. Every eval case's expectedTools must stay
   a subset of `selectToolNames(message)`.
8. Loop guard: a repeated tool+args pair in one message ends the tool
   loop instead of burning another paid round.

## Tool inventory (50)

add_to_watchlist, save_to_starlight_jar, set_mood, search_movies,
get_weather, create_reminder, log_activity, search_books, get_date_ideas,
read_chat_messages, send_sanctuary_message, get_xp_stats, search_anime,
add_book_to_our_books, read_starlight_jar, get_watchlist, remember_fact,
read_memories, pin_memory, delete_memory, edit_memory, web_search,
read_web_page, mark_watchlist_item_watched, update_book_progress, add_xp,
send_note_to_partner, get_relationship_insights, get_memory_trivia,
get_today_recap, get_gallery, get_garden, get_canvas, search_spotify,
remove_from_watchlist, search_everglow, plan_date_night,
add_calendar_event, create_journal_entry, add_bucket_item, add_trip,
add_trip_pin, log_habit, complete_habit, get_calendar_events,
get_bucket_list, get_journal_entries, search_journal_entries,
read_journal_entry, get_trips
