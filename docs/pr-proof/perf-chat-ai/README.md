# Chat / Motchi / gallery / journal — proof

## Privacy re-verified (contract item)

Nothing in this pass touched `firestore.rules`, but the contract asks for a
check:

| collection | rule |
| --- | --- |
| `gallery`, `notes`, `journal_entries`, `motchi_games`, `motchi_sessions` | `isCouple()` on read/write |
| `temporary_chats`, `watch_party_chats` | host/partner uid check |
| `motchi_notes`, `motchi_stats` | `allow read, write: if false` (server-only) |

`isCouple()` is `isRegistered() && hasCoupleIdentity() && username() ==
request.auth.token.username` — **not** merely "signed in", so Breyan / Octagram
(cinema-only) cannot reach any of it. No regression: no rule was modified.

## The streaming path was already built correctly

`motchi_widgets_streaming.dart` drives motion with `AnimatedBuilder`; its
`setState` calls are discrete state (`_isListening`, `_hasText`, `_focused`),
not per-frame rebuilds. The gallery grid uses `AppNetworkImage` with
`cacheWidth: 440` for a ~130–220px tile. The photo viewer keeps natural-size
decoding as a documented keep.

So the gap was not the code — it was that the rule protecting it was prose.

## Added: `check_perf_rules.dart`, wired into CI

`docs/PERF_NOTES.md` says *"No `setState` in ticker callbacks"* and nothing
enforced it. The guard now flags a `setState` inside a callback on a known
`AnimationController`/`Ticker`, or inside a `Timer.periodic` of ≤20ms.

**Before/after:** the first working draft reported **17 failures on a clean
tree**; the shipped guard reports **0 across 620 files**.

### Getting to zero honest false positives took three attempts

1. **17 hits, all legitimate** — a `FocusNode` listener, a
   `TextEditingController` listener, `Timer.periodic` at 2200ms and 30s. A guard
   that cries wolf on working code gets ignored or deleted, so the rule was
   narrowed to genuinely frame-rate shapes.
2. **4 remaining hits, all parser bugs** — the duration regex read
   `Duration(seconds: 1)` as 1 **millisecond** (an absent unit prefix means
   seconds), so every 1-second clock in the app became a phantom violation.
3. **1 remaining hit, substring matching** — a method named
   `_startClockTicker()` contains `Ticker(`, so it parsed as a Ticker
   construction. Fixed with a negative lookbehind.

### Verified it actually fails

| injected violation | result |
| --- | --- |
| 30s timer → `16ms` | caught at `partner_presence_indicator.dart:42` |
| 30s timer → `8ms` | caught at `partner_presence_indicator.dart:42` |
| synthetic `AnimationController.addListener(() => setState(...))` | caught, named the owning variable `_c` |

Each was reverted, and the guard passes clean after each revert.

### Two things this surfaced in existing code

`partner_presence_indicator` and `partner_doodle_indicator` both carry comments
about *previously* being 1s and 250ms tickers that rebuilt their subtrees far
more often than any label could change. The rule was already being applied by
hand — it just had nothing stopping the next person from undoing it.

## Streaming FPS remains unmeasurable here — stated, not claimed

"≥55 FPS while a reply streams" needs auth, Firestore history and a live AI
backend. The bench covers the shape (avatar/poster rows over a full-screen
ambience) but cannot drive a real stream, and its FPS column is meaningless in
headless regardless. That bar is a phone check with `?perf=1` — which this whole
pass made reachable again.

No screenshot: this PR changes a CI guard and documentation, and there is no
screen whose appearance it alters.

## Checks run

- `flutter analyze`: no issues.
- `flutter test`: 1410 passed.
- All 13 `dart tool/ci/check_*.dart` guards: pass (the new one included).
