# Fast dashboard scrolling — candidate fix

## What changed

`DeferredSection` now uses Flutter's existing deferred-loading velocity
heuristic while a scroll activity is running. Nearby new cards wait while
scrolling is fast; already mounted cards stay in place. Slow scrolling keeps
normal preloading. The same guard is checked when a reveal timer fires.
`isScrollingNotifier` schedules the landing check even if stopping changes no
pixels. Idle programmatic jumps remain immediate rather than using their
one-frame implied velocity. Page/app recovery and the safety-net timer remain.
No new scheduler, dependency, image-quality change or data change.

## Before / after regression

Two tests fail against #495's production widget:

```text
fast fling at 430 / 810 (6000 logical px/s)
  before: 3 / 2 additional cards mounted while moving fast
  after:  0 / 0 additional cards mounted while moving fast
  stop without moving another pixel -> landing cards mount
```

A third test covers a reveal timer already pending when the fling starts.
Existing tests retain skipped-card return, idle jumps, initial phone preloading,
phone delay bounds, lifecycle recovery and repaint reuse coverage.

Commands / environment:

- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --exclude-tags="golden,network" --no-pub`: passed, 1,525 tests.
- `flutter test test/deferred_section_test.dart --no-pub`: passed, 15 tests.
- All 15 discovered `dart tool/ci/check_*.dart`: passed.
- `flutter build web --release --no-pub --dart-define=AGENT_MODE=true --no-wasm-dry-run`: passed before and after.
- Windows, Flutter 3.44.4 / Dart 3.12.2, Node 24.21.0, disposable Chrome,
  synthetic Agent Mode only. No real credentials or couple data.

## Release browser reproduction

Served `build/web` locally. T3 Preview navigation succeeded but snapshot and
JavaScript inspection timed out. Used the existing `tool/perf/_harness.mjs`
Chrome launcher/CDP transport with disposable profiles for local measurements.
No browser tooling or manual workflow code was modified.

For each version, three fresh runs at each width (430 / 810 x 932, DPR 1):

1. Open `/?agent=dashboard&perf=1`; wait for the meter and enable semantics.
2. Wait 2.5 seconds, reset the diagnostic meter and long-task list.
3. Send seven real CDP touch scroll gestures: center x, y=740,
   yDistance=-1400, speed=6000. These are successive swipes, not one continuous
   ballistic fling. Each gesture's landing can still mount cards.
4. Wait one second; record scroll offsets, visible demo text, full-session
   frame readings and browser long tasks. Confirm real offset exceeds 2000px.
5. Send eight upward touch gestures (y=200, yDistance=1400, speed=6000),
   wait one second and record return offsets. The dashboard returned to zero
   in every run; inspect the largest active dashboard scroll surface, since
   tablet semantics also exposes nested scroll nodes at zero.

Raw records: `before.json`, `after.json`. The screenshots are separate after
runs with `perf=0`, HUD collapsed, after a slower 1900px swipe and a two-second
wait. They show stacked phone / side-by-side tablet cards, not timing evidence.
An initial clean-capture attempt could not locate the collapse button by its
ARIA label; locating its semantics text and sending a real mouse click worked.

## Timing result — not an established improvement

Full-session worst reported frame spans (ms), three runs each:

| Width | Before | After |
| --- | --- | --- |
| 430 | 170.6, 254.5, 170.2 | 205.8, 199.7, 202.9 |
| 810 | 187.8, 238.0, 178.3 | 208.9, 243.5, 236.0 |

Worst browser long tasks (ms):

| Width | Before | After |
| --- | --- | --- |
| 430 | 171, 257, 171 | 207, 201, 203 |
| 810 | 196, 245, 180 | 209, 244, 236 |

These raw release builds / unthrottled desktop diagnostics do **not** establish
an overall speed gain; some readings worsened. Landing work remains expensive,
and tablet animations remain active. Different deferred/revealed card heights
also produced different final scroll extents. The meter measures Flutter
scheduling, not display presentation FPS. This is not a stamped benchmark,
phone calibration, or proof of smooth Safari flings with populated live cards.

Keep this candidate draft pending an actual phone check or stronger matching
interaction evidence. The proven improvement is avoiding new mounts during
fast ballistic motion in regression tests, not faster whole-session timing.
App-only change: server, worker and performance-tool control suites do not apply.
