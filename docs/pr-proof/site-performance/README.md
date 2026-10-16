# Site performance fixes — 16 October 2026

This follow-up addresses all 14 findings in [the original audit](original-audit.md).
The baseline is commit `d7a3c6d1b7388ca173b37e7ffe8bf58b7f220a14`.
Changes use existing dependencies and platform APIs. No database migration,
rules change, image-quality reduction, or live-data access was needed.

| Finding | Change | Regression evidence |
| --- | --- | --- |
| 1. Startup fonts | Load the existing DM Sans and Bebas Neue assets before Anime/Motchi, rather than at the doorway. Other fonts and emoji fallbacks stay available at startup. | Matched release boot resource measurements and section screenshots. |
| 2. Duplicate engine download | Worker installation no longer precaches an unused local CanvasKit binary. Self-hosted engine requests retain on-demand caching. | Worker install and offline cache tests; real-browser offline/update suite. |
| 3. Canvas | Retain the saved-stroke subscription and completed artwork layer; repaint the active pen independently. Dispose retained Pictures. | Thirty pen updates preserve the painter and avoid screen rebuilds. |
| 4. Photo preparation | Browser image decode and asynchronous canvas JPEG encoding; native work uses an isolate. Preserve 1600/400 longest edges and JPEG quality 85. | Browser checks output dimensions, event-loop yielding, and corrupt-image fallback. |
| 5. Anime feeds | Publish each completed feed before the other requests finish; cache persistence runs afterwards. | A controlled slow row no longer blocks a completed row. |
| 6. Books feeds | Initial search skips unseen home feeds. Home rows appear independently when first visited. | Controlled feed/search tests. |
| 7. Documents | PDF work uses a native isolate or yields between browser pages. EPUB parsing yields between chapters, limits oversized expanded chapter text explicitly, and accepts binary proxy responses while retaining legacy JSON compatibility. | Complete-text/yield tests, malformed PDF checks, binary/legacy proxy test. |
| 8. Manga source selection | Start candidates together and return the highest-priority usable source without waiting for lower-priority failures. | Priority and held-fallback tests. |
| 9. Manga progress | Ignore unchanged scroll-page estimates; serialize saves and retain the latest pending page; flush on exit. | Shared writer coalescing, drain, failure, and queue-clearing tests. |
| 10. Table Tennis | Combine host paddle and ball in one update every 200ms; coalesce pending saves and discard stale queued work after reconnect. Transactions reject ended rooms. | Browser test holds a save across four ticks: only first and latest are written. |
| 11. Video proxy | Node stream pipeline respects backpressure and cancels upstream on disconnect. Upstream failures remain logged. | Slow-consumer, disconnect, and upstream-error tests. |
| 12. Music statistics | Start statistics when the section is used; suspend its timers while hidden and serialize refreshes. Keep global now-playing sync. | Provider lifecycle and inactive-surface tests. |
| 13. Spotify | Share initialization; own and remove browser listeners and timers; ignore late work after disposal and allow reconnect. | Browser initialization, reconnect, listener removal, and 51-minute timer check. |
| 14. Search races | Anime/Books discard obsolete search and pagination responses; invalidate requests as soon as typing changes. | Controlled responses arriving in reverse order. |

Verification also exposed an Anime loading-grid overflow. Skeleton cards now
use the actual tile width and the same poster/details height calculation as
loaded cards. The search regression exercises that loading state.

## Measurement scope

Windows, Flutter 3.44.4 / Dart 3.12.2, Node 24.21.0, disposable Chrome,
NVIDIA RTX 4070. Both release builds use `AGENT_MODE=true` and
`EG_PERF_BENCH=true`; these are diagnostic builds. The boot driver serves gzip,
uses a fresh profile per cold run, and bypasses the service worker. Its
`fast3g` profile is 150ms latency / 1600Kbps down / 750Kbps up.
Measurements run without concurrent builds or test suites.

| Cold doorway, three runs per profile | Before | After |
| --- | ---: | ---: |
| Local connection, median first Flutter frame | 2588.8ms | 2687.2ms |
| Shaped connection, median first Flutter frame | 30731.1ms | 29431.9ms |
| Initial script, gzip encoded response body | 1,437,055 bytes | 1,335,033 bytes |
| Initial script, uncompressed | 4,901,116 bytes | 4,547,846 bytes |
| Startup font response bodies | 1,427,856 bytes | 1,213,520 bytes |
| Worst boot long task, local connection | 304ms | 347ms |
| Worst boot long task, shaped connection | 286ms | 392ms |

Raw data: [before](boot-before.json), [after](boot-after.json). Initial script
gzip bytes fell 7.1%, and startup font bodies fell 15.0%. TTF/OTF bodies are
not gzipped by this local harness; actual hosting compression needs a separate
measurement. Local first frame is 3.8% slower in this sample; there is no
reproducible unthrottled timing win. An earlier exploratory build/run measured
1181.4ms, but this did not reproduce in the final clean run and is not used
as the result. An intervening run with a preview still open was discarded.
These six-run samples are not confidence intervals or predictions for
Clair's devices. Both profiles still fail the first-frame and 200ms long-task
bars. The shaped-link first frame improved 4.2% in this sample, while boot
long-task peaks increased. This supports a smaller-download claim, not an
overall smoothness claim. No acceptance threshold was relaxed.

Measured main-script SHA-256:
`821f72966eda62f595182f941a5ca3a616ac563835203c2ed7561318590df603`.
The build stamp uses the pre-commit base SHA because changes were measured
before committing. The after bytes are independently identified by this hash.

The shared-widget scrolling benchmark completed all nine runs (three each
of shelves, grid, and plain shelves at 430x932, DPR 3, CPU throttle 4x).
**All nine still fail** the strict 200ms full-session long-task budget:
worst tasks range from 1333ms to 1431ms, compared with 1421ms to 1888ms
before. These include startup/settle work. This is an outstanding target,
not a passing scroll-performance claim. No FPS aggregate is presented for
failed runs. Raw reports: [before](bench-before.md), [after](bench-after.md).
The benchmark uses shared widgets; it does not measure every changed feature.
It measured the intermediate diagnostic artifact with main-script SHA-256
`cf3735654b052b73c63b04bb93ce2c9ac8da27df230042fc4b8fa62c53082d80`,
before the final logging, search-filter, and chapter-transition safeguards.
The nine-run matrix was not repeated for those follow-ups. The boot results
and route screenshots above/below use the final artifact.

First Flutter frame is not populated-screen interactivity. Desktop CPU
throttling is not calibrated phone performance. Real iPhone/iPad Safari,
authenticated playback/upload/synchronization, and sustained device FPS
remain unverified. Large single PDF pages and EPUB chapter decoding can
still block between yields; this change does not claim to eliminate every
long task.

## Browser-test environment

Flutter 3.44.4's Windows browser-test server returned 404 for its bundled
CanvasKit assets and generated backslash-separated JavaScript test selectors
that lost their separators. An external temporary CDP interceptor served
the exact installed SDK assets and normalized only the generated HTML
`window.testSelector` path separators. Tests and app behavior were unchanged;
no SDK or repository workaround was installed. The Quality workflow runs
the same tests on Linux without this Windows workaround.

The deliberately corrupt-image test logs its expected decode error before
confirming the original-byte fallback.

## Checks

Selected output is retained in [verification.txt](verification.txt).

- `flutter analyze`: clean.
- `flutter test --exclude-tags="golden,network"`: 1,657 passed. Golden and
  live-network tests are excluded by the project workflow.
- All 15 existing `tool/ci/check_*.dart` guards: passed.
- Quality's full browser list: 54 passed. The three image/PDF/Spotify browser
  regressions were rerun after the final Spotify lifecycle guard: 3 passed.
- `PERF_REQUIRE_CHROME=1 node --test tool/perf/harness.test.mjs`: 24 passed,
  zero skipped. This verifies the measuring tools, not app speed.
- `node tool/service_worker_test.mjs --browser`: 15 passed, zero skipped.
- Functions lint: zero errors, 24 warnings within the existing 25-warning budget.
- Functions `npm test`: 329 total, 327 passed, two emulator-dependent rules
  tests skipped. No claim of rules-emulator verification is made.
- `node eval_gate.js`: passed.
- Stamped JavaScript release build: passed. Compiler Wasm dry-run warnings
  concern existing web interop; this does not claim Wasm compatibility.
- `node tool/agent_smoke.mjs build/web`: 64/64 aliases rendered at 430px/810px.
- A separate sweep reached 21 sections at 414px/820px: 42/42 arrivals with
  nonempty content and no captured runtime/console errors in the short
  observation windows. Raw output: [routes-after.json](routes-after.json).
  Forced CDP focus was disabled; the baseline audit documents its isolated
  Flutter focus-traversal exception. This does not prove device focus behavior.

## Screenshot proof

Screenshots use isolated agent sessions. Gallery art is synthetic; Anime
catalog art and Books titles are public catalog content. The HUD is collapsed
to a small pill in after screenshots. Books cover loading and authenticated
media/photo behavior are not proven by these images. The route sweep checks
arrival/rendering; interaction evidence comes from the targeted tests above.

| Surface | Phone, 414px | Tablet, 820px |
| --- | --- | --- |
| Anime | [Before](anime-before-414.jpg), [after](anime-after-414.jpg) | [Before](anime-before-820.jpg), [after](anime-after-820.jpg) |
| Books | [After](books-after-414.jpg) | [After](books-after-820.jpg) |
| Motchi | [After](motchi-after-414.jpg) | [After](motchi-after-820.jpg) |
| Gallery | [After](gallery-after-414.jpg) | [After](gallery-after-820.jpg) |

The T3 preview opened the app but snapshot inspection timed out twice with
`Preview automation snapshot timed out after 15000ms.` Screenshots and the
route sweep therefore use the documented disposable-Chrome workflow.
