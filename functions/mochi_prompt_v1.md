# Mochi System Prompt — v1 snapshot (2026-09-03)

> Versioned snapshot of the live prompt built in `index.js`
> (`systemPrompt` fallback + `MOCHI_TOOLS`, ~line 1355+ and ~line 1589+).
> The Firestore `ai_memories/shared/persona/mochi` doc or per-request
> `systemPrompt` can override this at runtime — this file pins what
> `main` shipped so evals and the gate have a stable reference.
>
> Bump to `mochi_prompt_v2.md` (and update `eval_gate.js`
> `EXPECTED_PROMPT_VERSION`) when the persona or routing policy changes.

- version: 1
- model: agnes-2.5-flash (512K context, input budget 120000)
- tool rounds: up to 8 (`MAX_TOOL_ROUNDS`), 25s per tool (`TOOL_TIMEOUT_MS`)
- prompt char guard: 50000 (`PROMPT_CHAR_LIMIT`)
- memory injection: top 30 relevant (`selectRelevantMemories`)

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

## Tool inventory (48)

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
get_bucket_list, get_journal_entries, get_trips
