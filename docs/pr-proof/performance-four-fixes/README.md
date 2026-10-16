# Four targeted performance fixes

Environment: Windows, Flutter 3.44.4 / Dart 3.12.2, Node 24.21.0.
Base: cdf108ff. All examples use generated data, never personal photos or accounts.

## Before / after evidence

- Details: two concurrent calls followed by a repeat made three HTTP calls before;
  the same regression now expects one. Successful metadata is capped at 80 titles.
- Trailers: two concurrent calls made two HTTP calls before; now they share one.
  A successful empty trailer result is remembered; transient errors remain retryable
  at the service level. The trailer cache is also capped at 80 titles.
- Cinema Library entry started four unused Home-feed loads before; now it starts
  zero. First Home visit starts four; revisiting does not refetch; explicit refresh
  starts another four. The test invokes the same navigation callbacks as the tabs.
- Manga: generated 100-title HTML mounted all 100 Latest Updates cards before at
  both 430 x 932 and 810 x 932. Afterward, fewer than 15 are mounted initially and
  after scrolling to Demo 70. The same checks pass after selecting the Manga type.
  Desktop retains its existing two-column layout.
- Gallery: upload preparation now decodes the original once and makes both JPEGs
  from that image. A generated 1800 x 900 input produces 1600 x 800 and 400 x 200
  outputs. Corrupt bytes retain the original/no-thumbnail fallback. These are
  output and source-structure checks, not measured upload latency.

Before-fix regressions were run against the unchanged services and, separately,
HEAD's Manga screen plus Cinema's unconditional initial Home fetch (retaining
only its test injection). Details/trailer tests had 3 failures; Library/Manga
checks had 3 failures. Fixed implementations were restored before final checks.

## Verification

- Analysis: `flutter analyze --no-pub` passed, no issues.
- Full tests: `flutter test --exclude-tags="golden,network" --reporter expanded`
  passed: 1,645 tests in 2m52s.
- Guards: all 15 existing `tool/ci/check_*.dart` scripts passed (listed first,
  then invoked individually with Dart).
- Release build: `dart tool/build_web.dart -- --release --no-source-maps
  --dart-define=AGENT_MODE=true` passed. Flutter emitted existing WASM dry-run
  warnings about unsupported web libraries; the JavaScript release build passed.
- Browser: disposable Chrome through the existing `tool/perf/_harness.mjs`,
  served from `build/web` on localhost:8879. Four flows passed: Cinema Library
  -> Home at 430px; Manga Home -> Manga type -> wheel scroll at 430/810/1280px,
  all at height 932 and DPR 1. Semantic text changed after scrolling and later
  cards appeared; screenshots were inspected. The temporary runner was invoked
  with `node .dart_tool/performance_qa.mjs` and is not production app code.
  Manga HTML was supplied by an injected fetch fixture before app startup;
  Cinema used its built-in agent fixtures. No login or couple data was used.
  Screenshots prove rendering; request/card counts above come from regressions.
- Browser diagnostics: no uncaught JavaScript exceptions. Four navigation-time
  404s were for the intentionally absent local environment asset (not read or
  copied), and one vibration warning followed a semantic test click without a
  trusted gesture. See `browser-results.json`.
- T3 Preview fallback: two snapshots returned exactly `Preview automation
  snapshot timed out after 15000ms.` before using disposable Chrome.
- Runner correction: an initial browser pass expected Manga 0 after reload;
  scroll memory correctly restored later cards from the previous viewport.
  The final run resets only its disposable profile's Manga scroll preference
  before each new document. This was a test-setup correction, not an app fix.

Screenshots: `cinema-library-phone.png`, `cinema-home-phone.png`, `manga-430.png`,
`manga-810.png`, `manga-1280.png`, and matching `*-scrolled.png` views.
The Library shot retains the existing back-button/title overlap; navigation
layout is outside these data-loading changes.

No functions, Firestore rules, dependencies, versions, render scale, image quality,
or animation policy changed. No whole-app FPS, real-phone timing, battery, network
latency, or memory percentage is claimed. Physical iPhone/Safari acceptance remains
unverified. Service-worker/performance harness manual suites are not required:
their code, build wiring, and workflow were not changed.
