# Motchi web search completion & synthesis — proof

## Problem

When Motchi searched the web for multi-step queries (such as VCT Champions match results across multiple sites), the response stopped abruptly with:

```
What happened
Stopped before finishing — check the steps below.
✓ Done · web search ...
✓ Done · browse web ...
✓ Done · read web page ...
Help finish unfinished steps
```

Four distinct defects caused this:

1. **Exhausted Tool Budget Dropped Turn Without Synthesis (`functions/motchi_chat.js`)**:
   - `while (toolRound < MAX_TOOL_ROUNDS)`: on round 8 (`MAX_TOOL_ROUNDS = 8`), tool calls executed and results were pushed to `currentMessages`. The loop condition `8 < 8` evaluated to `false`, exiting immediately without calling the LLM to read round 8's results and stream the synthesized answer.
   - `streamInterrupted` remained `true` because it was only set to `false` when a round had zero tool calls inside the loop.
2. **Post-Loop Repair Bypassed & Broken (`functions/motchi_chat.js`)**:
   - Post-loop repair was skipped if any conversational preamble was streamed (`!_streamedFinalReply.trim()` was false) or if it didn't end with `:`.
   - When it did run, pushing `{ role: 'user' }` directly after a `{ role: 'tool' }` message violated the OpenAI / TokenHarbor chat completions schema, resulting in an unhandled API error.
   - Even when repair text arrived, `streamInterrupted` was never cleared to `false`.
3. **`browse_web` Polling Loop on Standard Pages (`functions/motchi_exec_insights.js`, `motchi_tools.js`)**:
   - When `browse_web` timed out after its 20s budget, `resumeHint` told the model `attempt ${attempt + 1} (up to 5 tries)`.
   - The model followed this hint and polled `browse_web` 3 times in a row on `vlr.gg`, burning 60 seconds and 3 of its 8 allowed rounds.
   - The system prompt suggested `browse_web for dynamic or blocked sites`, misleading the model to use browser automation instead of the fast `read_web_page` markdown fetcher on normal websites.
4. **False Alarm for Read-Only Interrupted Steps (`lib/features/ai/domain/motchi_reply_details.dart`)**:
   - `needsAttention` returned `true` whenever `interrupted == true`, even if all steps were informational reads (`write: false`).
   - For web searches, no state is half-saved, so "Help finish unfinished steps" prompted Clair to "finish" actions where nothing needed finishing.

## Fix

1. **Guaranteed Final Synthesis Turn (`functions/motchi_chat.js`)**:
   - Loop condition expanded to `while (toolRound < MAX_TOOL_ROUNDS || forceTextNextRound)`.
   - When `toolRound >= MAX_TOOL_ROUNDS` and tools were executed, `forceTextNextRound = true` is set.
   - The final round runs with tools detached (`noToolsThisRound = true`). The model receives all gathered tool results, cannot call further tools, streams the full answer to Clair, and cleanly sets `streamInterrupted = false`.
   - If the model circles on repeat tool calls (`dropRepeatCalls`), `forceTextNextRound = true` forces a text synthesis round instead of dropping the turn.
   - Post-loop repair now clears `streamInterrupted = false` when repair text arrives, and avoids invalid `tool -> user` message ordering.
   - Non-streaming mode mirrors this with a final text-only synthesis pass when ending on a tool message.
2. **Capped `browse_web` Retries (`functions/motchi_exec_insights.js`)**:
   - At attempt 2+, `exec_browse_web` explicitly instructs the model not to call `browse_web` again, and to answer immediately from what it has or use `web_search`/`read_web_page`.
3. **Clarified Web Tool Guidance (`functions/motchi_tools.js`, `motchi_tool_schemas.js`)**:
   - `read_web_page` is emphasized for reading page text (fast markdown extraction). `browse_web` is reserved strictly for interactive pages (clicks, forms) or when `read_web_page` returns blocked/empty content.
4. **Honest Attention State for Read-Only Searches (`lib/features/ai/domain/motchi_reply_details.dart`)**:
   - `needsAttention` only requires action if there were writes or unconfirmed steps (`write != false`). Pure read steps (like searches) do not show "Help finish unfinished steps".

## Verification

- `functions/motchi_chat.test.js` — 2 new tests verifying synthesis after exhausted tool rounds and circling repeat-call handling.
- `functions/test/motchi_exec_tools.test.js` — new test verifying `browse_web` retry capping at attempt 2.
- `test/features/ai/motchi_reply_details_test.dart` — new test verifying interrupted pure reads do not show "Help finish unfinished steps".
- `node eval_gate.js` — passes (67 tools, 140 eval cases, version 12 intact).
- `flutter analyze` — 0 issues.
- `flutter test test/features/ai/` — 123 tests passing.
- `dart tool/ci/check_*.dart` — all regression guards passing.

Proof screenshot at 430px phone width:
`docs/pr-proof/pr-456/shot-motchi-search-receipts-430.png`
