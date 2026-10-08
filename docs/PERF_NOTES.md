# Everglow performance — verified scope and limits

## Status

The original target remains **unverified**: sustained ≥55 FPS, <5% jank,
zero presentation drops on every key phone screen, and first interactive
<2.5s on throttled 3G. Do not close that goal from synthetic desktop readings.
The active app-wide optimization audit is recorded in `docs/PERF_AUDIT.md`.
It corrects avoidable work while keeping those device acceptance targets open.

The earlier 138,580ms slow3G, 0ms boot-freeze, 991ms fully-offline and
9.9–19.2% “phone-representable” claims are withdrawn. The cold driver did not
apply its requested shaping, the boot observer was lost on navigation, page-only
offline left the service worker online, and a desktop CPU multiplier was never
calibrated against a phone. Uncompressed file sizes are not wire-transfer sizes.
The old all-zero benchmark could also pass without Flutter or actual scrolling.

There is no guarantee that the app has no issues. CI verifies specific checks;
real-device and authenticated feature behavior still need matching evidence.

## Changes retained

- Phones (viewport shortest side below 600 logical pixels, including landscape)
  now keep the dashboard's ambient backdrop and header decoration still, and
  use still shared/anime loading placeholders. This is Khent's requested
  automatic lighter-effects policy; tablets retain motion. It does not change
  render resolution, media playback, or image decode paths.
- Shared loading shimmer detaches from inactive `TickerMode` pages and pauses
  outside the resumed app lifecycle. Regression checks failed on both paths
  before the change and pass afterwards. `test/phone_ambient_motion_test.dart`
  checks that phone decoration schedules no continuing animation frames and
  that tablet motion returns after resizing. These are scheduling checks, not
  measurements of battery use or iPhone presentation FPS.
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

### Fast dashboard fling follow-up (candidate)

`DeferredSection` now honors Flutter's deferred-loading velocity heuristic
while scrolling and retries when scrolling stops. Regression tests prevent new
card mounts during fast phone/tablet flings, including a pending reveal timer;
idle jumps and existing cards are unchanged. Three-run local release swipe
comparisons did not establish an overall timing gain (some readings worsened).
Landing work and actual phone/Safari behavior remain unverified. Details and
raw diagnostic results: `docs/pr-proof/dashboard-fast-scroll/README.md`.

### Cold dashboard font follow-up (candidate)

Khent's first #496 preview check still found lag. Cold CPU profiles of local
and deployed builds showed repeated CanvasKit typeface setup as new Noto fonts
arrived. The theme now uses two small bundled 2D emoji/symbol fallbacks (323,936
raw bytes total), preserving existing text fonts and normal fallback for other
characters. In three matching local release runs (430px / DPR 2 / CPU 4), Noto
requests dropped from 8 to 1 per run and first-down worst reported frames moved
from 850/1136/1070ms to 329/252/545ms. These are desktop diagnostics, not a phone
calibration, presentation FPS or first-interactive verdict. Other phases still
include stalls (one after first-up long task was 600ms); Safari/native/live
content and the original device target remain open. Provenance, regeneration
and full results: `docs/fonts/README.md` and
`docs/pr-proof/dashboard-cold-fonts/README.md`.

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

## Extended phone optimization (PR #494)

The phone policy now covers shared shelves, anime airing tickers, decorative
emblems/presence dots, manga loading pulses, guardian idle floating and jukebox
card/vinyl effects. Phones show still decoration and manually swipe shelves;
tablet/desktop motion remains available. Active media playback and tap actions
are separate from this ambient-motion policy.

Saved anime collections and playlist details now use lazy sliver grids rather
than eager grids inside another scroll view. In the synthetic 414 x 896 widget
check in `test/full_phone_optimization_test.dart`, the 100-card shared shelf
initially built 5 cards (95% fewer than the reproduced 100), and a 200-item anime
collection mounted 6 cards instead of 200 (97% fewer). Horizontal and vertical
scroll checks reached later cards while retaining a bounded mounted collection.
These are widget-count reductions, not measured whole-app memory or FPS gains.

`AppNetworkImage` now applies existing decode bounds to bundled assets with a
known display/cache size and respects the existing web `sizeddecode=0` rollback.
Unknown display sizes keep their natural resolution. Remote web decoding stays
on its existing implementation. Partner presence and doodle indicators retain
their stream between freshness timer rebuilds instead of resubscribing each time.

Desktop browser timing is not an iPhone 11 result. An attempted benchmark against
an unstamped raw Flutter build was rejected by the harness; it is not valid speed
evidence. The real-phone acceptance targets above remain open until an installed
Safari/PWA before/after recording is available. This pass does not establish a
whole-app percentage gain, battery saving, or guaranteed 60 FPS.

### Inactive timer and Jukebox follow-up

Partner presence/doodle freshness timers now stop when the app is not resumed
or their page disables `TickerMode`. Returning refreshes the timestamp immediately
and retains the existing presence stream. Unrevealed dashboard sections pause
their 400ms safety-net and delayed reveal timers while inactive, then schedule
a geometry check on return. The foreground safety net remains in place.
`test/shared/widgets/partner_indicator_activity_test.dart` checks that a hidden
or inactive page does not rebuild from freshness ticks, resumes immediately,
and still creates only two presence streams across both indicators.
`test/deferred_section_test.dart` checks immediate resume and retains the existing
no-scroll geometry recovery and programmatic-scroll regression checks.

The Jukebox ambient controller continuously notified an entrance-only builder;
its glow widgets were already cached in the builder's child and did not move on
those ticks. That unnecessary loop is removed. The idle header no longer starts
a pulse when nobody is playing, and phone leaderboard shimmer/sparkle decoration
stays still. `test/features/jukebox/jukebox_idle_motion_test.dart` verifies that
the idle phone Jukebox settles, and leaderboard effects resume on tablet resize.
These checks establish stopped scheduling/rebuild work, not device FPS or battery
percentages. Remote thumbnail URLs were inspected and already have bounded CDN
variants; this follow-up does not reduce image sharpness or render resolution.

### App-wide audit follow-up

The remaining phone decoration in Garden, Starlight, entry-door breathing and
petals, anime badges, Motchi streaming/tool indicators, countdown separators,
partner mood hearts, music leaderboard badges, optional shared backdrop petals,
and player status/loading overlays now stops its continuous animation loops.
Finite door unlocking, plant growth, streamed replies, and playback updates
remain functional. `test/remaining_phone_motion_test.dart` checks phone settling,
door unlocking, plant growth, hidden petals and tablet motion restoration;
`test/features/anime/animex_motchi_sidebar_test.dart` checks thinking and replying
updates without ongoing phone indicator frames.

Manga Currently Reading now builds cards lazily and computes the merged list
once per build. This is a structural change; no populated authenticated manga
performance measurement was taken. Other audited Books/Gallery/Chat lists
already build on demand and retain their existing behavior.

Marking the current presence user offline now cancels the heartbeat timer.
Returning restarts the heartbeat and touches the existing session rather than
orphaning it. Against the previous service,
`test/core/services/presence_heartbeat_test.dart` observes four extra writes in
six minutes offline; with the fix the write count stays unchanged, then advances
again after resuming. This is a synthetic service check, not a battery estimate.

Jukebox also pauses its Last.fm polling and reconnect timer while the app is
inactive. Returning refreshes immediately, recovering a failed stream if needed,
while an in-flight guard prevents overlapping polls.
`test/features/jukebox/jukebox_provider_test.dart` verifies unchanged fetch/listen
counts during a hidden interval and resumed polling/reconnection afterwards.
Existing live/idle cadence, stream replay and disposal tests continue to pass.
The statistics provider's one-minute/ten-minute refresh timers also pause while
inactive, and it avoids creating timers if initialization finishes after
disposal. `test/features/jukebox/music_stats_provider_test.dart` checks that
eleven hidden minutes produce no additional recent/top-track fetches, then
recent tracks refresh on return while the existing leaderboard stays visible.

### Startup route loading follow-up

A matching stamped release comparison defers Dashboard/Letterbox, Cinema/player,
Anime, Manga home, Jukebox and Books entry/detail/reader/categories through the
existing DeferredRouteLoader, with its loading and retry states. Query arguments
and missing-extra guards are retained. First visits fetch the relevant chunks;
this reduces initial code, not total code needed to visit every feature.

Initial main.dart.js shrank from 6,873,114 to 4,822,468 bytes (29.84%), or from
1,985,566 to 1,401,243 bytes with deterministic gzip (29.43%). Exact hashes and
sizes are in docs/pr-proof/pr-494/startup-artifacts.json. Both builds include the
other current audit fixes and use AGENT_MODE/EG_PERF_BENCH; this comparison
isolates the route-loading follow-up rather than the entire PR against main.

One cold desktop trace per version, 430 x 932 at DPR 2 and CPU throttle 4,
observed main-script evaluation at 2,085ms before and 1,490ms after. This is a
single diagnostic observation, not a statistically established timing gain.
The corresponding one-run grid benchmark still FAILS its strict full-session
200ms long-task budget: worst long task 2,067ms before and 1,514ms after.
The trace associates the dominant startup task with main-script evaluation;
first layout/rendering also remains expensive. No budget was relaxed or failure
hidden. Scroll movement was observed in both runs. Rolling frame-meter FPS is
not display FPS and cannot predict Clair's iPhone frame rate.

Reports: docs/pr-proof/pr-494/startup-before-bench.md and
 docs/pr-proof/pr-494/startup-after-bench.md; trace summaries:
 docs/pr-proof/pr-494/startup-before-trace.json and
 docs/pr-proof/pr-494/startup-after-trace.json. These are local dirty release
artifacts based on d0155111, stamped 6.1.0+1-d0155111; source hashes distinguish
versions. Windows / RTX 4070 headless Chrome is not an iPhone calibration.
Real-device first-interactive, sustained FPS, heat and battery targets stay open.

### Manga chapter wait follow-up

The final repeat-controller audit found ChapterLoadingStage still repainting
its page illustration and waiting copy every frame on phones during a fetch.
It now uses the same AppMotion phone/reduced-motion policy and stops while
TickerMode disables its page. Chapter title, subtitle and a still waiting
illustration/copy remain visible; chapter fetching itself is unchanged.
The new test in test/features/manga/chapter_loading_stage_test.dart fails
against the prior widget because the phone keeps requesting frames, then
passes with the fix; tablet motion and inactive-page restoration are checked.
This proves stopped scheduling during chapter waits, not chapter download
speed, presentation FPS or battery savings.
