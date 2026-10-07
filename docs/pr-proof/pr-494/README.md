# Extended phone optimization evidence

`lazy-library-widget.png` is a Flutter widget render at 430 x 932 logical pixels,
using the real `AnimeXGrid(sliver: true)` and 200 synthetic entries with empty
poster URLs. The header is a test fixture. It is not a screenshot of the complete
My List page or a Safari capture. It shows the card layout, not timing or behavior.

The reproducible behavior check is `test/full_phone_optimization_test.dart`:

- Before the shelf change, its 100-card phone fixture built all 100 cards. It now
  initially builds 5, and a horizontal drag reaches later cards.
- The existing eager 200-entry anime grid mounts all 200 poster cards. The new
  sliver version initially mounts 6, and a vertical drag keeps the mounted portion
  bounded. These are 95% and 97% fewer initial cards in these fixtures, respectively.
- Phone music-card, emblem, airing-ticker, presence-dot and vinyl fixtures stop
  requesting ongoing frames after settling. The emblem resumes on tablet resize
  and stops again after returning to phone dimensions.

The original dashboard browser before/after proof remains in
`../phone-motion/`; those images were captured during the earlier motion pass.
They do not depict the extended changes. New T3 browser captures returned a
duplicated/clipped canvas and were rejected as proof; the synthetic widget render
above is labeled explicitly. No real couple data was used.

Validation on Windows, Flutter 3.44.4 / Dart 3.12.2, Node 24.21.0:

- Analyzer: no issues.
- Flutter tests excluding golden/network: 1,504 passed.
- Follow-up timer/Jukebox verification: 1,508 tests passed, including hidden app,
  inactive-page freshness, immediate section recovery and idle Jukebox scheduling.
- All 15 discovered Dart guards: passed.
- `dart tool/build_web.dart -- --release --no-source-maps
  --dart-define=AGENT_MODE=true --dart-define=EG_PERF_BENCH=true`: passed.
- `node tool/agent_smoke.mjs build/web`: all 64 route-alias/viewport checks passed
  (32 aliases at 430px and 810px). Checks verify navigation, destination text,
  collapsed demo HUD and a painted Flutter canvas; they do not verify every
  feature interaction or authenticated playback.

An attempted benchmark using an unstamped raw Flutter build was rejected by
the harness and provides no valid speed evidence. Desktop frame-meter samples
also cannot establish iPhone presentation FPS. Real iPhone 11/Safari/PWA frame
times, heat, battery use and sustained playback remain unverified. The original
device acceptance target in `docs/PERF_NOTES.md` remains open.

## Follow-up timer and Jukebox checks

Before the follow-up, the partner activity test continued reading/building the
indicators during a hidden interval. Deferred sections also failed the immediate
resume expectation. The phone leaderboard effects kept scheduling frames.
After the fixes these checks pass, along with the idle phone Jukebox check.
Its fixture loads the bundled Outfit font to avoid test-font layout artifacts.

The rebuilt release app passed all 64 route/viewport checks again. In T3 Preview
at 430 x 932, setting the dashboard's observed semantics scroll container to
2000 revealed Today, Calendar, Letterbox and Garden content. A further jump to
6000 revealed Play and Jukebox content. These are programmatic browser scroll
checks, not touch-scroll timing or a Safari performance measurement.

The removed Jukebox ambient loop only notified the entrance builder; glow widgets
were stored in its cached child and did not move on those notifications. The
foreground dashboard geometry safety net remains enabled. No real presence
account, Spotify playback, lower render scale or live data migration was tested
or changed. Existing images above prove the earlier appearance; new timer tests
prove behavior. The latest follow-up browser log is `background-browser-smoke.log`.

The older 73f2701 run failed before app smoke assertions because Chrome endpoint
discovery/profile cleanup failed. The subsequent d015511 Quality run
37695744194 passed Flutter, web build and preview deployment. Its hosted
dashboard was opened at 430 × 932; a programmatic scroll revealed the demo
Today, Calendar, Letterbox and Garden sections. The current b3cdff55 pass has its own successful Quality run, recorded below.

## App-wide audit follow-up

`starlight-phone-widget.png` is an inspected 430 × 932 **Flutter widget render**
of the actual StarlightJarWidget with one synthetic note, bundled fonts/icons
and a test router. It depicts the still jar and visible search/category/action
controls. It is not a Safari or full application screenshot; the debug banner
belongs to the widget test. T3's duplicated/clipped screenshot remains rejected.

`test/remaining_phone_motion_test.dart` verifies still phone Garden, Starlight,
door breathing, anime badge, leaderboard and optional background petals; plant
growth/door unlocking still complete, hidden celebration petals stop, and
tablet motion returns. The existing anime-sidebar interaction test now verifies
thinking/replying updates without continuing phone indicator frames.

The presence heartbeat regression against the previous service expected five
writes after six minutes offline but observed nine. With the fix the count
stays five during that interval, then increases again on return while keeping
one session. These counts come from a recording Firestore double, with no
Firebase credentials or couple data. Manga's reading list now uses a native
lazy builder; no populated authenticated manga speed claim is made.

The app-wide source findings and unchanged existing optimizations are recorded
in `docs/PERF_AUDIT.md`. Device acceptance remains open in `docs/PERF_NOTES.md`.

Jukebox status and music statistics now pause their recurring fetch timers
while inactive. Status reconnects wait for return and refresh immediately;
the statistics fixture verifies eleven hidden minutes with unchanged fetch
counts and a resumed refresh. Existing replay, recovery, cadence, artwork and
disposal checks remain in the provider test suites. In-flight requests can
finish; this does not claim that all background network traffic is eliminated.

## Final local verification and startup evidence

The current full audit pass has no analyzer issues, 1,516 passing Flutter tests
(excluding golden/network), all 15 Dart guards passing, and a successful stamped
release build. Commands and environment are the same as above. The latest
route/viewport check output is audit-browser-smoke.log: all 64 checks passed
(32 aliases at 430px and 810px). T3 navigation/evaluation retries
timed out; hosted verification and capture used the explicitly authorized
fallback described below.

startup-artifacts.json records a 29.84% smaller initial script / 29.43% smaller
deterministic gzip after route deferral. Both artifacts include the other audit
fixes, so this measures the startup follow-up. The trace summaries observed
main-script evaluation of 2,085ms before and 1,490ms after in one cold desktop
run per version. One-run grid benchmark reports are also saved: BOTH FAIL the
200ms full-session long-task target (worst 2,067ms / 1,514ms). Scroll movement
was verified in both. No iPhone FPS or whole-app timing percentage follows from
these diagnostic desktop samples. See docs/PERF_NOTES.md for settings, source
hashes, dirty-build stamp limitations and the remaining device acceptance work.

## Hosted preview verification

Quality run 37701615817 succeeded for b3cdff5597520c5ec08cedcfc704dad33c5e2b24:
Flutter analysis/tests/guards/browser-only tests, release build, agent route
smoke checks and Firebase preview publication. CI checks out the synthetic
merge aa4b4d6bd66e5fbd5febb025aa6fb334ac191931, which includes that head; the
hosted main script carries its expected 6.1.0+1-aa4b4d6 stamp.
Preview: https://everglow-1c6db--pr-494-vvrrwwal.web.app (temporary).

T3 preview inspection eventually returned an explicit "No preview automation
host is available" error with "Do not retry" and permission to use a shell
headless browser. A temporary script derived from tool/agent_smoke.mjs then
used the existing disposable-Chrome harness against this hosted origin.
The first sweep failed seven canvas assertions: its readiness loop stopped
on matching semantics before a canvas appeared. Those failures are retained
in hosted-browser-first.log; they are not counted as a passing run.
The diagnostic rerun additionally required page.canvas in the existing
readiness condition, retaining the 30-second deadline and every assertion.
All 64 hosted route/viewport checks pass in this rerun; its output is
hosted-browser-ready.log. Screenshots wait another 1,500ms for the loading
overlay to finish. No repository
harness, CI assertion, budget, or app source was changed for this check.

hosted-dashboard-phone.png, hosted-garden-phone.png, hosted-starlight-phone.png
and hosted-cinema-phone.png are inspected 430 x 932 browser screenshots of
this hosted app using only agent-mode demo fixtures with its HUD collapsed.
The Garden and Starlight captures that showed a bootstrap splash were rejected
and recaptured after painting. Cinema posters have intentionally blank demo
artwork. These show the real pages, unlike the earlier labeled widget renders;
they do not prove Safari, touch-scroll timing or authenticated playback.
