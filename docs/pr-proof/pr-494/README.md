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

The previous commit's hosted web-build job compiled successfully but failed
before app smoke assertions: Chrome advertised an endpoint, then discovery timed
out, and profile cleanup failed. That CI browser failure is not a passing result
and prevented a new hosted preview. The PR remains draft until current CI and
hosted preview inspection are complete.
