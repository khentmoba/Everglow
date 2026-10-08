# Fast scrolling into unloaded cards

Khent clarified that the remaining lag happens when fast scrolling brings
several unloaded dashboard cards into view together, rather than just scrolling
over already-loaded content.

## Reproduction and smallest change

`test/deferred_section_test.dart` reproduced **six newly mounted sections in
one frame** after jumping into an unloaded part of the dashboard. Nearby reveal
timers share deadlines (phone delays are capped at 120ms), so velocity deferral
alone still releases a batch when the fling slows.

`DeferredSection` now grants one new mount per upcoming build frame. Others
retry after a frame, without another entrance delay, and recheck visibility,
velocity and page/app activity. Existing cards stay mounted. A mount already
granted before a renewed fling can finish; waiting cards remain deferred.
No new dependency, general queue, thread, network request or settings option.

The failing six-in-one-frame check now passes with at most one new section
per frame. The phone pair test explicitly verifies left and right mount in
separate frames while preserving their reserved total height. Existing fling
tests finish their initial staggered screen before measuring the fling; the
same no-new-mount assertion remains. New retry/fling and disposal checks cover
recovery and prevent retry frames continuing after removal.

## Release browser comparison

Both builds include the same-cat and font fixes. Windows, Flutter 3.44.4 /
Dart 3.12.2, Node 24.21.0, disposable Chrome, release CanvasKit, 430 x 932,
DPR 3, CPU rate 4, no network throttle. Three fresh profiles per build.

Build command:

```sh
flutter build web --release --no-pub --dart-define=AGENT_MODE=true --no-wasm-dry-run --source-maps
```

Serve `build/web` through the existing harness. Install `LONG_TASK_OBSERVER`
and a first-frame listener before navigating to `/?agent=dashboard&perf=1`.
Wait for `/dashboard`, first Flutter frame and perf mirror, then 200ms.
For first-down and first-up: reset mirror/tasks, perform eight 1,400px touch
swipes at 6,000px/s (x=215; y=740 down / 200 up), wait 750ms, flush and collect
perf/tasks. No prior warm traversal, CPU profiler or semantics in this run.
Raw rows: `card-burst-before.json` / `card-burst-after.json`.

| Phase | Worst reported frame before, ms | After, ms | Long tasks before | After |
| --- | --- | --- | --- | --- |
| First down | 399.1 / 410.6 / 344.6 | 419.5 / 393.7 / 343.0 | 14 / 14 / 17 | 27 / 23 / 29 |
| First up | 222.4 / 202.9 / 241.0 | 111.6 / 169.1 / 168.5 | 20 / 13 / 25 | 19 / 16 / 16 |

**Do not call this an overall smoothness win.** Return-scroll peaks improved
in all three runs, but first-down peaks did not clearly improve and its long-task
counts increased. Large first-scroll work (~343–420ms reported peaks) remains.
The widget test proves mount distribution, not that all async data/image work
is distributed or that Clair's phone meets a presentation-FPS target.
Desktop CPU throttling is not calibrated phone/Safari/PWA performance.

## Checks and appearance

- `flutter analyze`: no issues.
- `flutter test --exclude-tags="golden,network"`: all 1,530 tests passed.
- All 15 discovered Dart guards passed; `git diff --check` clean.
- Targeted deferred-section suite: 18 tests passed.
- Release browser: 430/810 screenshots of the real dashboard, demo data only,
  collapsed HUD, eight fast downward swipes then a 750ms landing wait.
  `card-burst-430.png` / `card-burst-810.png` show the unchanged header;
  `card-burst-landing-430.png` / `card-burst-landing-810.png` show loaded landing
  content. Screenshots are not speed proof. Phone retained still cat; tablet 3D.
- Impeccable detector: no findings for changed widget.
- Manual harness/offline tooling suites: N/A, no tooling/loader/worker changes.
- Actual phone burst-loading behavior and populated live-card timing remain
  unverified; keep the PR draft until Khent tests the updated preview.
