# Perf harness proof

## Why this exists

Every real screen in Everglow sits behind Firebase Auth and live Firestore
data, so a headless run had nothing to scroll and nothing to measure. The
previous attempt at this (`tool/perf/measure_scroll.mjs`) was deleted in
`cfa3c9c1` along with the frame meter it read, and `docs/PERF_NOTES.md` kept
describing a tool that no longer existed in the tree.

So this restores the meter and rebuilds the rig around it, plus adds a
deterministic bench scene that a headless run can actually drive.

## What ships

- **Frame meter restored** (`lib/core/perf/`): `FrameStats`, the HUD, the
  render-scale override, and the `window.__everglowPerf` JS mirror that makes
  the numbers readable by a script instead of off a screenshot. Enabled with
  `?perf=1`.
- **A real bug in that meter, fixed.** `FrameStats.frameCount` is capped at the
  240-frame window, so the HUD differenced it across ticks to compute FPS.
  Once the window filled, that delta was permanently `240 - 240 = 0` and the
  FPS readout read **0 forever** — which is why the deleted harness had to read
  numbers by eye. `totalFrames` is now a monotonic counter, with a regression
  test in `test/core/perf/frame_stats_test.dart`.
- **`tool/perf/bench.mjs`**: builds with `--dart-define=EG_PERF_BENCH=true`,
  serves `build/web`, drives each scene over CDP at 430x932 / DPR 3 with 4x CPU
  throttle, and writes `docs/perf-baseline.md`.
- **`/perf-bench`** (`lib/core/perf/perf_bench_route.dart`): fixed-content scenes
  built from the *real* shared widgets (`DashboardAmbience`, `ShimmerTitle`,
  `PulseHeart`, `EverglowMarquee`, `DeferredSection`, `ShelfPosterCard`) over
  the 23 photos already in the app bundle. Compiled in only under the
  dart-define, so production builds tree-shake it — the guard is a
  compile-time constant.

## Proof

`shelves-0.png` — the bench route rendering at DPR 3 with the restored meter
overlay live in the corner (270 fps, build 0.5/1.6ms, raster 0.8/1.1ms,
worst 2.4ms, 240 frames, dpr 3.00):

![shelves bench](https://raw.githubusercontent.com/khentmoba/Everglow/HEAD/docs/pr-proof/perf-harness/shelves-0.png)

Those milestone photos are not new exposure: all 23 JPEGs already ship inside
the built web bundle and are publicly downloadable from the deployed site.

## Three ways this harness caught itself lying

Each of these produced numbers that looked completely healthy while describing
the wrong thing, so each now fails the run instead:

1. **Measured the wrong screen.** Navigating to `/perf-bench/shelves` — a path
   that was never registered — bounced through the auth redirect to the login
   gateway. The meter is mounted app-wide, so it reported a confident 78 fps
   for a passcode screen. The bench now asserts it is still on `/perf-bench`
   after navigation.
2. **Measured a page that never moved.** A scroll window that produced an
   identical screenshot to the idle window was being reported as a scroll
   result. The bench now fingerprints the page before and after and refuses to
   report a scroll pass that did not move.
3. **Asserted the wrong hardware.** The first draft claimed raster was
   SwiftShader software rendering. It is not — the recorded renderer is
   `ANGLE (NVIDIA RTX 4070, D3D11)`, a real GPU. The harness now reports the
   renderer it actually got instead of assuming one.

## Numbers, and what they are worth

Full tables and the noise band are in `docs/perf-baseline.md`
(throttled) and `docs/perf-baseline-unthrottled.md` (stable reference).

The honest summary: **this rig cannot judge the goal's ">= 55 FPS on Clair's
iPhone" bar.** It has a desktop GPU and no steady vsync, so its FPS column
wanders on a healthy build and jank sits at 0%. What it *can* do is compare
two builds of the same scene, which is the regression net this pass needs.
The device verdict still comes from the on-phone frame meter (`?perf=1`), which
this PR makes reachable again.

## Checks run

- `flutter analyze`: no issues.
- `flutter test`: 1410 passed (was 1390; +20 restored meter tests, +2 new for
  the FPS regression).
- All 12 `dart tool/ci/check_*.dart` guards: pass.
- `node tool/perf/bench.mjs --build --runs 5`: completes and writes the table.