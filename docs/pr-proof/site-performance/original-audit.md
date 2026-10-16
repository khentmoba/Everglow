# Everglow performance audit — 16 October 2026

What this repo does: Everglow is a private Flutter web app for Khent and Clair, with shared memories, chat, books, manga, cinema, anime, games, and music. This audit assumes two active couple users, occasional cinema guests, phone/tablet browsers, and collections that grow over time. It does not assume thousands of concurrent users.

This is a read-only performance audit of commit d7a3c6d1b7388ca173b37e7ffe8bf58b7f220a14. No application code, settings, dependencies, database rules, or live data were changed. Generated builds and temporary diagnostic files are local only.

## Measurement baseline

Environment: Windows, Flutter 3.44.4 / Dart 3.12.2, Node 24.21.0, disposable headless Chrome. Release build uses AGENT_MODE=true and EG_PERF_BENCH=true, so it is a diagnostic build rather than a byte-identical production build. Synthetic CPU/network/viewport settings do not represent a calibrated iPhone.

Build command: `dart tool/build_web.dart -- --release --no-source-maps --dart-define=AGENT_MODE=true --dart-define=EG_PERF_BENCH=true` — PASS. Five web interop files prevent a Wasm build according to the compiler's dry run; this does not prevent the JavaScript release build. Migrating renderers is an experiment, not a proven improvement.

Cold doorway measurements: three runs for each profile, fresh browser profiles, service worker bypassed, gzip served by the repository harness. A first Flutter frame is not a measurement of usable controls or a populated dashboard.

- Unthrottled local connection: first frame 2,554.7 / 2,588.8 / 2,698.1 ms; median 2,588.8 ms. Worst observed browser long task: 304 ms.
- Shaped connection: 150 ms latency, 1,600 Kbps download, 750 Kbps upload. First frame 30,704.7 / 30,731.1 / 30,869.7 ms; median 30,731.1 ms. Worst observed browser long task: 286 ms.
- Both profiles completed 3/3 runs and failed the existing first-frame <2.5s and long-task <=200ms bars. No thresholds were relaxed.
- Main script: 4,901,116 uncompressed bytes, 1,437,055 encoded response-body bytes in these runs.
- Font responses: 1,427,856 encoded body bytes per run across 17 text-font files and two icon fonts. The local harness does not gzip TTF/OTF. Actual hosting compression must be measured separately before predicting deployed wire savings.
- Earlier exploratory boot runs overlapped test startup. They were discarded; the results above are the subsequent runs without those tests running.

Raw boot evidence: `boot-before.json`. The boot CLI was called through its exported `main` to save the returned JSON; its `--out` argument is not implemented. Source: `tool/perf/measure_boot.mjs`.

## Should fix — ordered by likely usefulness

### 1. Reduce the fonts downloaded before the doorway opens

**What this is:** `pubspec.yaml:69` declares all app text-font families and weights globally. Resource timing confirms that even a cold doorway fetches all 17 files plus icons.

**Problem:** Fonts add 1.43 MB of encoded response bodies in the local trace. Cinema/anime and letter-writing fonts ride along before those sections are opened. This is a measured payload cost, not a projected FPS gain.

**Fix:** First audit actual glyph and weight use, then subset the existing font assets while preserving required languages, emoji, and symbols. Load section-only families on demand where that removes them from Flutter's global startup font list. Keep the current small emoji fallbacks; previous profiling showed why they exist. Compare matched builds and check phone/tablet screenshots before changing typography.

**If we skip it:** Cold visits keep paying for typography from screens Clair has not opened.

### 2. Stop precaching a second CanvasKit engine on CDN builds

**What this is:** `tool/build_web.dart:25` chooses an engine-pinned gstatic CanvasKit URL. `tool/generate_sw.dart:206` independently precaches `/canvaskit/canvaskit.wasm` during worker installation, and its fetch handler ignores cross-origin engine requests.

**Problem:** With the normal CDN build, the worker downloads a local engine file that the page's loader does not use. The current local full engine is 7,229,467 raw bytes, 2,928,391 bytes with the harness's gzip. These are artifact sizes; the additional production wire transfer was not measured. This worker work is excluded from the cold boot baseline above.

**Fix:** Make engine caching follow the actual build configuration. For CDN builds, remove the unrelated local precache; retain correct self-hosted fallback and offline behavior. Also deduplicate `warmCoreShell()` against an in-flight core fetch if a network trace confirms overlap. Run the repository's browser worker/update tests for this change.

**If we skip it:** First worker installation can use bandwidth and storage for an engine that does not serve the app.

### 3. Keep Canvas subscriptions and cached drawing layers stable

**What this is:** `lib/features/canvas/presentation/screens/canvas_screen.dart:125` constructs a fresh saved-strokes stream inside `build()`. Pointer movement calls screen-level `setState()` at line 324. Each rebuild also constructs a new `CanvasPainter` at line 150.

**Problem:** Drawing repeatedly replaces the stream and its listener. The painter's grid and completed-stroke caches are instance fields (`canvas_painter.dart:16`), so those caches also start empty on each new painter. A longer drawing means more history processing during the very gesture that needs to stay responsive. This does not prove a new billed Firestore read for every pointer event; SDK caching affects that.

**Fix:** Store the saved-strokes stream in state, replacing it only on retry/query changes. Drive the active-stroke paint with a notifier and keep the completed drawing layer stable between history changes. Give cached Pictures an explicit owner and disposal path.

**If we skip it:** Each pen gesture keeps causing unrelated subscription, widget, and completed-drawing work.

### 4. Move photo preparation away from the browser UI thread

**What this is:** `gallery_service.dart:121` calls `prepareUploadImages()` synchronously. That function decodes an original image, resizes twice, and JPEG-encodes both outputs (`:188`, `:212`). The shared picker supplies original web image bytes without dimension bounds (`lib/shared/utils/pick_image_bytes.dart:19`).

**Problem:** Selecting a normal high-resolution phone photo can block input and painting during upload preparation. Setting an uploading flag immediately before synchronous work does not ensure that the loading UI paints first. Full and thumbnail uploads also run sequentially.

**Fix:** On web, use browser image decoding/canvas resizing, with a worker if measurement still shows blocking; on native, use an isolate. Match orientation, JPEG quality, and the existing 1600/400px outputs. Upload independent outputs together with the current thumbnail-failure fallback. Merely wrapping the existing work in `async` or web `compute()` is insufficient.

**If we skip it:** The upload dialog can appear frozen before upload networking even begins.

### 5. Show each anime home feed when it completes

**What this is:** `animex_home_page.dart:133` starts five feeds together. `_fetchRow()` updates `_rows` and persists data at line 191, but does not rebuild the page; `_load()` calls `setState()` only after all feeds finish at line 169.

**Problem:** A successful trending hero can remain behind a loading placeholder while an unrelated feed is still waiting. Existing cached content helps repeat visits, but does not remove the fresh-load barrier. Controller notifications may incidentally expose data earlier; that is not a dependable completion signal.

**Fix:** Publish each completed row immediately, then persist cache data without making rendering wait for it. Coalesce the five whole-cache writes if profiling shows storage serialization matters. Keep the independent error states.

**If we skip it:** One slow provider response delays visible content that has already arrived.

### 6. Books loads unseen home feeds and ties visible rows together

**What this is:** `books_screen_state_base.dart:44` starts home fetching even when an initial search query opens the search tab. At line 110, popular/recent rows wait for one combined future. Popular itself combines Open Library and Gutenberg (`book_catalog_service.dart:250`).

**Problem:** A search deep link starts unrelated catalog requests. On the home tab, a slow Gutenberg request can also hold back an already available recent-books row.

**Fix:** Start home feeds on the first home visit, as Cinema already does. Publish popular and recent rows independently. A later refinement can progressively merge popularity providers if that preserves the intended ranking.

**If we skip it:** Search opens spend bandwidth on hidden shelves, and the home page waits for its slowest provider.

### 7. EPUB and PDF processing still performs large synchronous passes

**What this is:** `epub_service.dart:97` synchronously parses the downloaded archive and chapter HTML. Its proxy returns base64 JSON, then the client decodes and copies bytes (`:134`, `:137`; `functions/media_proxy_books.js`). `study_doc_service.dart:145` extracts all PDF text synchronously, up to the allowed 10 MB PDF input.

**Problem:** Large readable documents occupy the browser UI thread and create several temporary copies. EPUB base64 expands the pre-compression representation by roughly one-third; that is not a claim of one-third greater compressed wire traffic. Plain-text book splitting already yields between phases, so it should not be treated as an unoptimized identical path.

**Fix:** Return binary EPUB bytes with metadata in headers, removing JSON/base64 and the unnecessary copy. Move expensive parsing/extraction to a web worker or a genuinely incremental path, and bound expanded archive work. Keep full study material available; silently truncating it would change the feature.

**If we skip it:** Opening large EPUBs or study PDFs can freeze the loading screen even after download finishes.

### 8. The older manga reader waits for unsuccessful fallback sources

**What this is:** `manga_reader_screen.dart:307` deliberately waits for every source future, then picks the first usable result in priority order. Individual attempts have 15-second timeouts and may search several alternate titles.

**Problem:** A good highest-priority result can already be available while an unrelated lower-priority source holds the reader for its remaining timeout. `Future.timeout()` also does not cancel the underlying request chain.

**Fix:** Resolve in priority order while allowing attempts to run concurrently: return a usable result once all higher-priority candidates are settled, without awaiting lower priorities. Stop unnecessary fallback work where supported, and retain source/page-count validation.

**If we skip it:** Successful chapters can sit on the loading screen until failing sources finish. This applies to `/manga/reader` and the older details drawer, not the main Katana reader opened from MangaCelestia.

### 9. The older manga reader repeatedly saves the same page while scrolling

**What this is:** `manga_reader_screen.dart:83` runs on every scroll update. At line 101 it saves whenever the estimated page is divisible by five, rather than only when entering a new page/checkpoint.

**Problem:** Many updates within estimated page 0, 5, 10, and so on call the same persistence operation repeatedly. The whole screen also rebuilds and asks to precache the same neighbours even when the page estimate did not change.

**Fix:** Return early when the estimated page is unchanged. Track the last saved checkpoint, coalesce in-flight progress writes, and flush the latest position on chapter change/exit. Follow the main Katana reader's existing changed-page guard.

**If we skip it:** A slow swipe over one checkpoint can produce repeated writes and repeated UI work. This is again the older reader, not the current Katana reader.

### 10. Table Tennis sends competing transactions for fast game state

**What this is:** `tt_bridge_service.dart:69` and `:74` create separate 200ms paddle/ball timers. Host paddle changes and ball changes can both call `writeHostState()`. Both players' writers transact against the same room document (`tt_multiplayer_service.dart:113`, `:140`).

**Problem:** During an active rally the host can start up to ten state transactions per second and the guest up to five. Each reads the shared document before writing, and the callers do not await or coalesce in-flight operations. Slow connections can accumulate stale work and transaction retries. This is a code-derived upper cadence, not a measured live write rate.

**Fix:** Use one host tick carrying the latest paddle+ball state, and a single in-flight operation with only the newest pending state. Preserve ownership and ordering checks. Revisit the transport only if a two-device rally still fails latency requirements; a transport rewrite is not the first fix.

**If we skip it:** Network latency and shared-document contention can make paddle/ball sync less responsive while doing more backend work.

### 11. Video proxy loops do not respect slow clients

**What this is:** `functions/media_proxy_video.js:171` and `functions/anime.js:906`, `:990` repeatedly call `res.write()` without checking its return value. They also do not abort the upstream reader when the downstream client disconnects.

**Problem:** When an upstream download is faster than Clair's connection, the response can keep queuing bytes in server memory. Leaving a player can leave the upstream transfer running until completion/timeout.

**Fix:** Use Node's standard stream pipeline with backpressure, and propagate downstream close/abort to the upstream fetch. Preserve range/status/playlist rewriting behavior. Cover a slow consumer and an early disconnect in a focused test.

**If we skip it:** Slow playback connections can use unnecessary server memory and transfer bytes after playback has stopped.

## Nice to have / lower priority

### 12. Stop music-statistics refreshes when their surface is unused

**What this is:** `app_providers.dart:81` keeps MusicStatsProvider at app scope. Once instantiated by the dashboard, its minute/ten-minute timers run while the application is foregrounded (`music_stats_provider.dart:140`).

**Problem:** Going from the dashboard to Cinema does not dispose the provider or pause statistics refreshes. Application-background pause already exists and passes tests; route visibility is a separate missing signal. Periodic callbacks also have no shared in-flight guard across resume/refresh paths.

**Fix:** Tie statistics refresh activity to actual statistics consumers while retaining the cached values. Add an in-flight guard. Keep global now-playing sync where the product needs it; that separate service serves a real purpose.

**If we skip it:** Long movie sessions can refresh unseen leaderboards and artwork in the background of the foreground app.

### 13. Spotify's timer and browser listeners have no cleanup owner

**What this is:** `spotify_player_service_web.dart:149` creates an unretained periodic timer. Window listeners are anonymous at lines 47, 115, 128, and 136. `disposePlayer()` disconnects the JS player but cancels neither, and there is no service `dispose()` override.

**Problem:** The current root provider normally lasts for the app lifetime, so this is not evidence of a route-by-route leak today. However, disconnect/disposal cannot release these resources; overlapping initialization can also register multiple completion/player setup paths because initialization has no shared in-flight future.

**Fix:** Retain and cancel the timer/listeners, make initialization single-flight, and connect cleanup to service disposal. Keep normal background music playback working.

**If we skip it:** Reinitialization or future provider-scope changes can accumulate callbacks and token refresh work. The 50-minute cadence makes this lower urgency than startup/reader fixes.

### 14. Ignore outdated Anime and Books search responses

**What this is:** `animex_search_page.dart:62` and `books_screen_state_base.dart:142` debounce typing but accept any completed request. The Books load-more path also appends without checking whether the query/filter changed.

**Problem:** Search A can finish after search B and replace B's cards; an old load-more page can be appended to a new search. That paints/decodes discarded content and makes Clair repeat a search. Cinema already uses a request version to avoid this.

**Fix:** Copy Cinema's small request-version pattern, captured with the query/filter/page state. Cancel superseded network requests only where the current HTTP client supports it; response guards alone solve stale painting.

**If we skip it:** Rapid searches can show older results and waste work rendering them. No live slow-provider reproduction was run; the ordering case follows directly from the unguarded async methods.

## Coverage and things already working

All 27 feature areas were inventoried. Inspection covered entry/bootstrap/router/provider setup; dashboard/deferred sections; Cinema feeds/player/progress/poster healing; Anime home/search/shelves/library; both manga readers and their services; Books feeds/search/text/EPUB; Gallery grids/uploads/viewer; Motchi streaming/study/context; Canvas; Watch Party/voice; Jukebox/status/stats/Spotify; and the bounded data paths for Sanctuary, Journal, Garden, Starlight, Calendar, Bucket List, Tonight, Money, Subscriptions, Trips, Academy, XP, mood, guardian, and date ideas. Shared image/shelf/motion/stream helpers, worker generation, hosting headers, build tooling, Cloud Function entry points, catalog/image/media proxies, and AI context queries were also inspected. This was path-based inspection, not a claim to have read every line in every file.

Good existing choices retained in the recommendations:

- Providers construct unused services lazily. Many heavy routes already defer code. Health and push initialization do not block first frame.
- Dashboard sections defer new mounts, keep finite collections, and pause phone decoration. These areas have targeted regressions.
- Shared phone shelves and saved anime item grids build on demand. The playlist collection index still uses a shrink-wrapped grid, but there is no evidence of enough playlists at this app's expected load to rank it as a current bottleneck.
- Chat's live window is 50 messages, Gallery starts at 40 photos with 6 preview items, journal has a bounded live window plus older-page loading, and Calendar shares its upcoming listener. Money uses a month range and grows its query to preserve accurate totals; a blanket cap would silently break totals.
- Gallery stores 400px thumbnails and max-1600px viewer images. TMDB helpers have bounded CDN variants. Web remote decode bounds remain deliberately disabled for known texture failures; re-enabling them blindly is not a safe optimization.
- Cinema publishes completed home rows independently and writes playback progress in a coalesced path. Main Katana reader has changed-page guards and lazy image viewers.
- Presence pauses its heartbeat offline; music polls pause when the whole app is hidden. Motchi uses per-draft notifiers and trimmed regular-chat history; server context reads are selected, bounded, cached, and parallelized.
- No dependency upgrades, renderer migration, extra cache framework, or backend region move is justified solely by this audit. Cache hits, function cold starts, and upstream timings need authenticated traces before changing infrastructure.

## Verification and limits

The targeted Flutter run passed 85 tests across phone lazy construction, deferred sections, gallery upload/viewer helpers, EPUB parsing, Katana reader, PDF extraction, and music-provider lifecycle. Injected-error tests log expected Firebase/offline failures; passing tests do not prove production backend latency.

Command: `flutter test --exclude-tags=golden,network test/full_phone_optimization_test.dart test/deferred_section_test.dart test/features/books/epub_service_test.dart test/features/gallery/gallery_upload_delete_test.dart test/features/manga/katana_reader_test.dart test/features/ai/study_doc_test.dart test/features/jukebox/music_stats_provider_test.dart test/features/jukebox/jukebox_provider_test.dart`.

T3 preview navigation opened, but two consecutive snapshots failed with `Preview automation snapshot timed out after 15000ms.` The attempted resize reported a 414px setting with a stale 1280px measured viewport, so it is not counted as phone evidence. Subsequent checks use the repository's disposable Chrome/CDP harness.

Not checked: real iPhone/iPad Safari or installed PWA presentation FPS, battery/heat/OS memory termination; authenticated Firestore/storage timings and read bills; deployed compression/cache headers; two-device playback/voice/game synchronization; sustained third-party video behavior; every nested route/detail/edit/error state; every backend schedule/tool implementation. No real couple credentials/data were used. A fresh local build skips live persistence in agent mode, so it cannot close authenticated performance questions.

Verdict: Start with startup fonts/engine downloads, Canvas's repeated work, and independent feed rendering. Then handle large-document/photo processing and the older reader's avoidable waits/writes. Establish matched iPhone and tablet before/after traces before claiming overall speed, FPS, memory, heat, or battery gains.

## Additional evidence from this audit

### Focused reproductions

Two temporary probes passed: `flutter test --no-pub C:/Users/Admin/AppData/Local/Temp/everglow_audit_probes_test.dart`.

- A controlled AnimeXHomePage test completed its trending request while leaving four other feeds pending. The hero still had no items. Completing the other four futures made the already-fetched hero appear. This reproduces finding 5 without an external API or personal data.
- A generated 4032x3024 JPEG passed through the real `GalleryService.prepareUploadImages()` function. The synchronous call took 780ms in this single Dart VM sample and generated both sizes. This is a diagnostic example of synchronous work, not browser/iPhone timing; the route smoke sweep ran concurrently and the sample is not a controlled performance baseline.

### Synthetic scrolling benchmark

Command: `node tool/perf/bench.mjs --runs 3 --scene shelves,grid,shelves-plain --out C:/Users/Admin/AppData/Local/Temp/everglow-performance-bench.md`.

430x932 CSS viewport, DPR 3, CPU throttle 4, NVIDIA RTX 4070 via ANGLE/D3D11. All nine runs produced fresh meter samples and actual changed scroll offsets. All nine failed the existing 200ms full-session browser long-task budget; none was missing or silently skipped.

Worst browser long tasks per run:

- Shelves: 1,432 / 1,520 / 1,456ms.
- Grid: 1,421 / 1,435 / 1,888ms.
- Shelves without the optional shared background: 1,725 / 1,615 / 1,637ms.

These are full-session maxima including startup/settling, not isolated swipe latency. No new CPU trace was collected to attribute each task to a specific function. The plain scene also failed, which does not support claiming that simply removing that backdrop solves the budget. No before/after code comparison was performed. HUD rolling FPS is not display/presentation FPS and is not used as a phone speed claim here.

Raw rows: `bench-before.json`. Full harness report: `bench-before.md`.

The older manga progress writer also performs a query lookup before each update (`mangakakalot_service.dart:434`), so finding 9 repeats a read-plus-write sequence, not merely a local preference save.

### Route sweep and a focus-emulation diagnostic

The initial sweep reached 21 main routes at 414x896 and 820x896 (DPR 2): 42/42 produced nonempty app semantics and no missing-route/error page. However, every initial run logged `Bad state: RenderBox was not laid out` with a shared Flutter focus-traversal stack. These must not be called console-clean passes.

A separate dashboard probe collected errors before and after enabling semantics. The errors already existed before accessibility inspection. A follow-up A/B changed only CDP's `Emulation.setFocusEmulationEnabled`: forced focus OFF produced zero errors on normal load and after enabling semantics; forced focus ON reproduced the same layout exception. This isolates a focus-emulation-dependent startup issue, not its application/Flutter root cause. It is not attributed to 42 separate page defects, and does not establish that real-device focus behavior is correct.

The original sweep is retained as `before-routes-focus-on.json`; the focus A/B is `before-focus-probe.json`; the earlier timing-of-semantics probe is `before-semantics-probe.json`. The cold/scroll timing harness also uses forced focus, so its observations remain diagnostics under that configuration. No timing bar is relaxed or failed run converted to a pass. The route sweep is repeated without forced focus and written to `before-routes.json`.

Screenshots are synthetic-agent views, with the agent HUD visible. The demo Cinema art is deliberately empty; these images verify rendering at a viewport, not live media quality, network loading, or frame rate. Basic route arrival is not proof of nested interactions, playback, editing, or every error path.

Final focus-off route result: **42/42 route arrivals produced nonempty app content; zero missing-route pages, zero captured runtime/console errors** during the short observation windows. These are 21 routes at both 414x896 and 820x896, DPR 2: Dashboard, Cinema, Anime, MangaCelestia, Books, Sanctuary, Gallery, Journal, Tonight, Calendar, Garden, Starlight, Play Zone, Academy, Trips, Canvas, Bucket List, Money, Jukebox, Subscriptions, and Motchi. Ordinary app editing/playback was not exercised by this sweep. Existing widget tests and the synthetic benchmark provide separate interaction evidence.

The startup font finding was cross-checked against the installed Flutter engine source: `C:/dev/flutter/bin/cache/flutter_web_sdk/lib/_engine/engine/initialization.dart:154` awaits renderer initialization and `_downloadAssetFonts()` together; line 219 awaits loading the asset font manifest. Thus these global font declarations are on the engine initialization path, not merely speculative offscreen assets.

Final verification count: release build PASS; 85 existing targeted tests PASS; 2 focused audit probes PASS; 42 corrected route smoke observations with no captured console errors; 6/6 cold-load measurements complete but both profile verdicts FAIL; 9/9 scrolling measurements complete but FAIL the full-session long-task bar. No full analyzer/test/CI-guard shipping gate was run because no source change or PR was made. `git status --short` remained empty.
