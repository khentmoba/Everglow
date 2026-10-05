# Everglow performance — verified scope and limits

## Status

The original target remains **unverified**: sustained ≥55 FPS, <5% jank,
zero presentation drops on every key phone screen, and first interactive
<2.5s on throttled 3G. Do not close that goal from synthetic desktop readings.
The blocked goal stays paused; this cleanup repairs defects and bad evidence.

The earlier 138,580ms slow3G, 0ms boot-freeze, 991ms fully-offline and
9.9–19.2% “phone-representable” claims are withdrawn. The cold driver did not
apply its requested shaping, the boot observer was lost on navigation, page-only
offline left the service worker online, and a desktop CPU multiplier was never
calibrated against a phone. Uncompressed file sizes are not wire-transfer sizes.
The old all-zero benchmark could also pass without Flutter or actual scrolling.

There is no guarantee that the app has no issues. CI verifies specific checks;
real-device and authenticated feature behavior still need matching evidence.

## Changes retained

- `DeferredSection` defers offscreen dashboard content, with finite lists and
  coalesced geometry checks. Tests: `test/deferred_section_test.dart` and
  `test/core/perf/scroll_jank_benchmark_test.dart`.
- Dashboard decorative motion and marquees pause during scrolling. Marquees
  remain stopped while backgrounded, including when a pending settle timer fires;
  settle checks use current layout before resuming a newly visible row.
- Shared image wrappers provide loading/error behavior. Smaller TMDB requests
  reduce source-image bytes, but high-DPR/tablet sharpness still needs a visual check.
- Tonight thumbnails use `AppNetworkImage` with native decode widths of 240/400.
  **Its web branch does not pass those decode bounds**, so that change is not
  evidence of a web memory reduction.
- Bundled-image decode sizing defaults on, with persisted `?sizeddecode=0`
  rollback / `?sizeddecode=1` recovery. Khent's visual A/B report was “identical”;
  it was not a documented comprehensive Safari audit. A 512→108 bitmap has about
  22× fewer pixels; this is arithmetic, not measured whole-app RAM/GPU savings.
- Carousel hold is 20 seconds, a pacing choice rather than a measured speed win.

## Opt-in meter

`?perf=1` enables the diagnostic; `?perf=0` disables it. The preference persists.
`?dpr=2` selects a render scale after reload; NaN/infinities and values outside
1–3 are rejected in the shared validator, including saved values. Default DPR
and appearance are unchanged when no override is selected.

`lib/core/perf/frame_stats.dart` keeps recent build/raster averages in a
240-frame window and uncapped **session peaks/counts since reset**. It uses
`FrameTiming.totalSpan` for reported frame span rather than build+raster alone.
The HUD's “fps” is the rate of Flutter-reported frames, **not measured display
presentation FPS**. “over budget” is the session share exceeding a reference
60Hz budget, **not a count of actual dropped frames**. Low reported work can
coexist with a main-thread freeze or missing/unpresented frames.

The browser mirror `window.__everglowPerf` includes increasing `sampleSequence`,
`sessionFrames`, session worst build/raster/frame spans and `sessionOver200ms`.
`window.__everglowResetPerf()` immediately publishes an empty reset reading;
disabling the HUD clears the mirror and reset hook. No HUD timer or timing
callback is registered while the meter is disabled; the runtime feature still
has compiled code weight.

Use `docs/PERF_PHONE_CHECK.md` for a diagnostic spot-check. Full acceptance
needs display/presentation evidence and a browser main-thread trace as well.

## Automated tools

`tool/perf/_harness.mjs` shares a disposable Chrome launcher, static server and
CDP transport. No private browser profile or authenticated account is used.

`tool/perf/bench.mjs` drives `/perf-bench`, `/perf-bench/grid`, and
`/perf-bench/shelves-plain`. The routes are included only with
`--dart-define=EG_PERF_BENCH=true`. They compose real shared widgets over
**generated abstract posters**, not personal photos or real couple data.
They are structural proxies, not authenticated dashboard/cinema/chat coverage.

The benchmark requires the exact scene identity, actual changed Flutter scroll
offset via `window.__everglowBenchScroll()`, fresh nonzero meter samples and
full-session peaks. An animated screenshot or a zero-frame object is not proof
of scrolling/rendering. Long-task observers are installed in each new document;
missing observations, incomplete runs and >200ms tasks cannot silently pass.
Worst-case evidence covers every run; medians are summaries, not acceptance.

`tool/perf/measure_boot.mjs` measures **first Flutter frame**, not proven first
interactive. It applies actual CDP network conditions before cold navigation,
with declared latency, aggregate bandwidth, cache state and compression.
Repeat runs warm the production shell first and apply shaping to the worker too.
A first-frame event alone can fire even when the UI is unusable.

Typical commands (read `--help`/source for current flags):

```sh
node --test tool/perf/harness.test.mjs
node tool/perf/bench.mjs --build --runs 3
node tool/perf/measure_boot.mjs --runs 3 --profile slow3g
```

The browser tooling suites run manually for relevant changes, as required
by `AGENTS.md`, rather than on every PR. Set `PERF_REQUIRE_CHROME=1` when
running the harness suite so an unavailable browser cannot silently skip it.
`.github/workflows/browser_checks.yml` offers an opt-in Linux run. Ordinary
Quality still runs the deterministic service-worker tests on web builds and
the real app's browser-only Flutter tests for relevant changes. A green PR
check is not a performance measurement.

Desktop measurements apply to that rig/build/scene only. A 4× CPU throttle is
not a phone bound; headless FPS is not a real-device verdict. New synthetic
posters and stricter validation mean old tables cannot be compared as speed wins.

## Offline and updates

`tool/generate_sw.dart` already handles `main.dart.js?v=BUILD` cache-first with
the **full URL as cache key**. New version URLs miss that cache. Do not replace
that branch with blanket entrypoint cache-first behavior.

The cleanup adds network-first caching/fallback for the versioned boot-loader
path so a previously warmed shell can boot when **both page and worker** cannot
reach the network. Online loads still request fresh entrypoints. This is a
shell fallback, not an unconditional guarantee: first visits, missing/evicted
resources, authenticated services, deferred features not previously loaded,
and cross-origin resources may still require a network.

Page-only CDP offline emulation is insufficient evidence. Tests must disconnect
both targets and check that a fresh document paints the expected screen. Update
checks must also prove that new version queries fetch new core bytes online.

## Public proof and history

Public screenshots must contain synthetic/demo or approved stock data only.
The benchmark no longer references personal milestone photos; its old public
screenshots are replaced/removed at current HEAD. **Git history, old commit URLs,
PR revisions and forks can retain prior copies.** No destructive history rewrite
or force-push is part of this cleanup. Existing bundled personal assets predate
this benchmark and were not newly protected by a Firestore rule change.

A proof image verifies appearance at its tested viewport, not timing/privacy
permissions. Interaction claims need actual clicks or scroll-state evidence.

## Rules worth keeping

### Images

Use `AppNetworkImage` / `AppPosterImage`, not bare remote images. Provide error
fallbacks and proportional decode bounds on supported paths (roughly 240–300px
for small thumbnails, 350–400px posters, 560px heroes, 800–1200px details).
On web, check the chosen widget branch before claiming sized decoding; a
`cacheWidth` argument alone is insufficient. Full-resolution zooming readers
and photo viewers keep deliberate exceptions.

### Animation and layout

- No `setState` in ticker callbacks — use `ValueNotifier` / `AnimatedBuilder`
  or `CustomPaint(repaint:)`.
- Decorative layers use `RepaintBoundary`, `ExcludeSemantics`, `IgnorePointer`,
  background pause and a reduced-motion static state.
- Keep web blur bounded/disabled; offscreen animated sections stay deferred.
- Preserve appearance and pacing unless a device A/B supports the change.

### Live data and privacy

Keep finite realtime queries and logged errors; never add per-pointer Firestore
writes or shorten the 60-second presence heartbeat. Couple-only data remains
Khent+Clair only. Catalog/AI helpers use login tokens; keys stay server-side.
Rules were not changed by the cleanup; source inspection is not a complete
permissions test or a claim that every feature has passed a live-user audit.

### Verification

Before shipping: analyzer, Flutter tests, every existing regression guard,
Chrome look/interaction check and a release web build. Node fault controls must
reject invalid/missing readings and detect injected stalls; do not weaken bars
to make a report green. `tool/ci/check_perf_rules.dart` checks known per-frame
rebuild patterns; `tool/ci/check_perf_notes.dart` checks cited paths only.
Neither guard proves performance, image sharpness or privacy by itself.

Shipped scaffolding is not a speed improvement. State measured results,
evidence and limitations separately. Further optimization follows reliable
measurements and real-phone readings, not the withdrawn historical tables.
