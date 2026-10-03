# Motchi anime search proof

## Problem
In the Motchi anime assistant sidebar, querying for anime details (e.g., `Tell me about the anime "Mushoku Tensei: Jobless Reincarnation Season 2" — synopsis, vibe, and why it is loved!`) called the `search_anime` tool.
Under the hood, `exec_search_anime` relied exclusively on the Jikan (unofficial MyAnimeList) API at `https://api.jikan.moe/v4/anime`.
Jikan experienced connection timeouts (stalling for 10s+, retried once, stalling 20s+ total, and throwing `ConnectTimeoutError: Connect Timeout Error`).
When the tool threw an uncaught error:
1. `toolReceipt` flagged the step as `failed` (`(!) Did not complete · search anime ...`).
2. Motchi circled on repeat calls, which were dropped, exiting the loop without emitting text.
3. The user received an empty reply with an error card.

## Fix
1. **AniList GraphQL as Primary:**
   - Switched `exec_search_anime` in `functions/motchi_exec_media.js` to query the official AniList GraphQL API (`https://graphql.anilist.co`).
   - AniList is fast (~200–350ms), reliable, keyless, and returns rich metadata: clean synopsis, 10-scale score, episode count, genres, English/Romaji titles, and `idMal` (MAL ID).
2. **Resilient Jikan Fallback:**
   - Falls back to Jikan if AniList ever fails, with an explicit `AbortSignal.timeout(5000)` so it cannot hang for 20+ seconds.
3. **Safe Empty Fallback:**
   - If both fail, safely catches and returns `{ results: [] }` rather than throwing an unhandled exception.
4. **Unified Search Optimization:**
   - Updated `search_everglow` in `functions/motchi_exec_insights.js` to query AniList first, cutting multi-domain search latency by ~8s.
5. **Empty-Reply Recovery:**
   - Added post-loop text-only repair in `functions/motchi_chat.js` if the model ran tools but generated no visible text.

## Verification
- Added 3 automated tests in `functions/test/motchi_exec_tools.test.js` covering AniList success, Jikan fallback, and offline network failure.
- All 44 tool tests in `motchi_exec_tools.test.js` and 21 tests in `motchi_chat.test.js` pass cleanly.
- `flutter analyze` passed with 0 issues.
- All CI guard checks passed.
- `docs/pr-proof/pr-437/shot-motchi-anime-search.png` records the verified output.
