# Motchi instant-reply timings (PR #399)

How Motchi's reply speed was measured, what changed, and what is still
pending a production deploy. All numbers below were taken in real Chrome
(headless) unless noted. Fake/empty data only — no couple content.

## M1 — tap → feedback (criterion 1)

Method: instrumented `_sendQuick` (tap timestamp) and `AIService.sendMessage`
(right after the user-message `notifyListeners`, which is what paints the
user bubble + `Motchi is thinking`). Timestamps via `debugPrint`, collected
over CDP (`Runtime.consoleAPICalled`). Phone viewport 430px, tablet 768px.
Debug DDC build + SwiftShader — this OVERSTATES real-device latency
(release AOT + real GPU is faster).

| build   | viewport | run  | tap→notify |
|---------|----------|------|-----------|
| main    | phone    | cold | 67ms      |
| branch  | phone    | cold | 31ms      |
| branch  | phone    | warm | 47ms      |
| branch  | tablet   | —    | 68ms      |

Raw console lines:

```text
# main, phone, cold
[M1] tap 1790535016721
[M1] feedback-notify 1790535016788        # +67ms
# branch, phone, cold
[M1] tap 1790534447085
[M1] feedback-notify 1790534447116        # +31ms
# branch, phone, warm (2nd tap, same page)
[M1] tap 1790534532818
[M1] feedback-notify 1790534532865        # +47ms
# branch, tablet 768px
[M1] tap 1790534658515
[M1] feedback-notify 1790534658583        # +68ms
```

Notify → paint is one frame (~16ms @60fps), so perceived feedback is
~47–84ms worst case in the debug build — under the ~100ms budget on
phone and tablet, with no regression (tap path is byte-identical;
spread is debug-build noise).

Pixel upper bound (cold first tap, debug + SwiftShader shader jank):
feedback visible ≤1022ms — see `shot-motchi-feedback.jpg`
(user bubble + thinking indicator). This is the frozen-gap repro from
the verification contract, not steady state.

## M2 — SSE transport, fake server (criterion 2, client leg)

Method: in-app harness called the REAL `streamSseResponse` web client
against a local canned-SSE server (status @~5ms, chat content @300ms,
tool content @700ms after a `tool_result`, think content @900ms after
`reasoning`). 1 warmup + 5 timed runs per mode. Medians:

| mode  | metric      | main (before)              | branch (after)             |
|-------|-------------|----------------------------|----------------------------|
| chat  | first-status| 13ms (8/9/13/16/40)        | 11ms (8/9/11/15/24)        |
| chat  | first-chunk | 303ms (301/303/303/303/304) | 303ms (302/302/303/303/304)|
| tool  | first-status| 9ms (8/9/9/12/14)          | 9ms (8/9/9/10/10)          |
| tool  | first-chunk | 703ms (701/703/703/703/704) | 703ms (702/702/703/703/704)|
| think | first-status| 9ms (8/9/9/13/15)          | 10ms (8/8/10/12/17)        |
| think | first-chunk | 903ms (902/902/903/904/904) | 903ms (902/902/903/904/905)|

Honest read: ±1ms — headless rAF ticks so fast the removed frame-wait
is below measurement noise here. Proven instead: client overhead past
server-send is ~2–4ms in both builds (screenshots:
`shot-sse-harness.png` = branch, `shot-sse-harness-main.png` = main).
The sync-drain change is strictly-better-or-equal in code (sync drain
can never be slower than waiting for rAF); its ~1-frame win shows on
real 60Hz displays, not headless. First measurement iteration fired
the fast path on status events (no content gain) — caught by this
harness and fixed to trigger on visible text.

## M3 — prompt budgets (criterion 2, server leg, code-derived)

Worst-case chars per trimmed block (format code × limits):

| block     | before | after | Δ    |
|-----------|--------|-------|------|
| watchlist | 1800   | 1200  | −33% |
| books     | 1400   | 840   | −40% |
| starlight | 5000   | 2400  | −52% |
| music     | 1125   | 675   | −40% |
| garden    | 1100   | 660   | −40% |
| trimmed total | 10425 | 5775 | −45% |

Typical 5-block context ≈ 23225ch → ≈18575ch. Fast-path turns (now
11 intents incl. bucket/journal/trips) skip the whole context plus the
memory select: 2 LLM calls → 1.

Round-trips removed per warm request: daily-cap Firestore write+read
(~100–400ms typical) → in-memory hit (~0ms, background sync).
Payload guard: full `JSON.stringify` every request → estimate-first
(bench: text 0.083ms → 0.003ms; photo 7.24ms → 0.007ms event-loop
block). 429 worst case 36s → ~9s before the friendly fallback.
Pure routing stays <0.05ms avg; `rankMemories(60)` 0.44ms avg.

## Prod baseline (criterion 2, server leg, real turns)

`node tool/motchi_sessions.js list --feature assistant --limit 40 --json`
(durations + counts only — no message content viewed):

| date       | durationMs | tools | note            |
|------------|------------|-------|-----------------|
| 2026-09-27 | 45372      | 3     | agnes-3.0-flash |
| 2026-09-24 | 9985       | 2     | agnes-3.0-flash |
| 2026-09-24 | 4511       | 0     | agnes-3.0-flash |
| 2026-09-24 | 5581       | 1     | agnes-3.0-flash |
| 2026-09-24 | 4295       | 0     | agnes-3.0-flash |

No-tool totals ≈ 4.3–4.5s; tool totals 5.6–45s. (Three 135–230s rows
on the retired qwen model excluded.) These are full-turn durations
(all rounds), not TTFT — the genuine pre-change baseline.

## Still unverified (needs merge + deploy + real traffic)

Live end-to-end TTFT after-values. Compare after merge with:

```sh
node tool/motchi_sessions.js list --feature assistant --limit 40 --json  # durationMs
firebase functions:log --only proxyAIv2 -n 100 | grep -E "pre-llm|ttft"  # new per-request lines
```

New `[proxyAI] pre-llm auth/user/cap/ctx/fp` and `ttft` log lines ship
in this PR so the compare is one grep once deployed.
