# Everglow Web Performance Notes

Source of truth for what has been done and what comes next.
Goal: fast first paint, 60fps scroll, minimal Firestore/listeners cost.

## The rule that drives everything

**Flutter Web keeps no rendered layers.** The engine caches draw lists
(`CkPicture`), but every frame re-plays them into the WebGL surface — there is no
retained bitmap cache (`engine/.../layer/layer_tree.dart` only *mentions* a
raster cache; nothing implements it). Build and raster also share one thread.

So on web, frame cost = *what is on screen* + *what rebuilt this frame*, and a
smooth screen is one where build + raster fit in 16.7ms. Anything full-screen
(gradients, blurs, glows) is paid again on every single frame.

## Measuring on the phone (dev tooling)

The phone is the only place "the dashboard feels heavy" is true, and an
installed PWA can't have its start URL edited. So the switches live in the app:

| Switch | Where | What it does |
| --- | --- | --- |
| Frame meter | Creator Studio → System, or `?perf=1` | Overlay with FPS, jank %, dropped %, and build/raster avg + worst. Tap it to reset the window — reset, scroll the screen you care about, read the numbers. |
| Render scale | Creator Studio → System, or `?dpr=2` | Renders at N device pixels per logical pixel instead of the browser DPR. Layout is unchanged (the engine measures the viewport in CSS px and divides by the same DPR); only the backbuffer resolution changes. **Needs a reload.** |

Both persist (`perf_settings.dart`), so `?perf=1` typed once keeps working inside
the PWA afterwards. `?perf=0` turns the meter back off.

Reading the numbers: **build high** = widgets re-running every frame; **raster
high** = too many pixels (full-screen gradients, shadows, blurs, glyphs). iPhone
15 Pro Max reports DPR 3 = a 1290x2796 surface, so raster is the usual suspect
at that scale.

## Mobile smoothness pass (in progress)

Why: the dashboard is laggy and freezes on first load on an iPhone 15 Pro Max,
even though the visuals are fine. Measured causes, in order:

1. **Every dashboard section mounts on frame 1.** `SliverToBoxAdapter` mounts
   all of its children eagerly (verified: 20/20 in a probe test) and the whole
   dashboard is built from `SliverToBoxAdapter`s, so all ~25 sections — their
   Firestore streams, tickers, images and painters — exist from the first frame,
   even 8 screens below the fold. `DeferredSection` was meant to prevent this,
   but its `kIsWeb` branch only waits 0–700ms and then shows everything.
2. **Two full-screen painters tick forever on the dashboard**: `DashboardAmbience`
   (3 aurora ribbons drawn as 6 big gradient strokes, 14 petals × 3 ghost trails,
   and 6 freshly allocated gradient shaders per frame) and `DashboardCursorGlow`,
   which starts its 60fps loop at init even though it only draws on mouse hover.
3. **Blur and shadow are the expensive primitives** on mobile Safari WebGL: the
   background is 3 full-screen radial gradients, and most cards carry 1–2
   `BoxShadow(blurRadius: 14–25)`.
4. **Skeletons each own a ticker**: every `EverglowSkeleton` runs its own
   controller and rebuilds a `Container` with a new `LinearGradient` every frame,
   so a cold dashboard mounts dozens at once.

Note for Safari/iOS: the engine can't use the browser's image decoder there
(`ImageDecoder` is Chromium-only per the engine's own feature detection), so JPEG
posters decode in wasm on the main thread while scrolling. `canvasKitVariant:
"full"` is a no-op in this app (the smaller `chromium` variant is unreachable
because `index.html` deletes `Intl.v8BreakIterator`, and Safari lacks
`ImageDecoder`), so it is not a lever.

### Shipped (perf pass, v6.0.0)

1. **`web/index.html` — lazy media libs + instant splash**
   - `cat_3d_engine.js`, `model-viewer`, `hls.js` + `hls_bridge.js` no longer
     block first paint. They load once via `__everglowEnsureMediaLibs()`
     after `flutter-first-frame` (idle callback) or on demand.
   - `RoamingCat3DEngine.ensureRunning()` pokes the loader on guardian mount.
   - Inline dark splash (`#eg-splash`) kills the white flash and gives LCP
     feedback; dismissed on `flutter-first-frame` with a 12s safety net.
   - Preconnects moved to Firebase backends (critical path); CDNs are
     dns-prefetch only. `flutter_bootstrap.js` preloaded at high priority.
   - The `aria-hidden` platform-view fix is now burst-coalesced instead of
     once-per-mutation.

2. **Providers are lazy (`lib/core/di/app_providers.dart`)**
   - Only `AuthService` is eager (router needs it synchronously). Everything
     else constructs on first `read`/`watch` — after `Firebase.initializeApp`.
     Unused features (Spotify, Guardian AI, Jukebox stats) cost zero at start.

3. **`AppNetworkImage` (`lib/shared/widgets/app_network_image.dart`)**
   - Sized decode (`cacheWidth`), reserved space (no pop-in), shimmer-free
     lightweight placeholder, error fallback, `gaplessPlayback`,
     `RepaintBoundary`. Migrated: jikan/tmdb/ol search dialogs (200px),
     animex home hero (560px). See rules below before adding new images.

4. **Marquee no longer rebuilds 60x/sec (`everglow_marquee.dart`)**
   - Offset is a `ValueNotifier` under one `AnimatedBuilder` around the
     `Transform`; children build once. Ticker pauses on app background.

5. **Sparkles halved (`everglow_sparkles.dart`)**
   - Default count 20 -> 12 (capped at 24), zero-alpha circles skipped,
     ticker pauses on background, static single paint under reduced motion.

6. **Service worker (`tool/generate_sw.dart`, registered from `index.html`)**
   - Cache-first for shell + immutable assets (canvaskit/WASM/fonts/models),
     network-only for entry probes, network-first-with-bounded-cache for the
     rest. Old caches purged on activate. Regenerate via `dart tool/generate_sw.dart`
     (also runs inside `deploy.ps1`).
   - `web/flutter_bootstrap.js` is a custom bootstrap that loads Flutter with
     NO serviceWorkerSettings, so the deprecated Flutter shim worker never
     registers and can't flap against ours on the same scope. Do not add
     service-worker settings back without removing the `index.html`
     registration first. `/` is no-cache in `firebase.json` so deploys
     propagate past the HTTP cache.

## Image rules (all new code)

| Display width | `cacheWidth` | Widget |
| --- | --- | --- |
| <= 120px thumb | 240-300 | `AppNetworkImage` |
| 120-200px poster | 350-400 | `AppPosterImage` (default 400) |
| 280px hero | 560 | `AppNetworkImage` |
| Full-width/detail | 800-1200 | `AppNetworkImage` + `FilterQuality.medium` |

Never use bare `Image.network` for remote art. Migration is done except
deliberate keeps: readers/photo-viewer/gallery-grid (custom loading or
DPR-aware decode widths a fixed widget would regress), `KatanaNetworkImage`
(uses `WebHtmlElementStrategy.prefer` on purpose), and drawer/hero
backdrops with equivalent custom loading/error states.

## Firestore / realtime rules

- Every `snapshots()` needs `limit()` + error handling (`withFirestoreTimeout`
  in `core/utils/firestore_stream_utils.dart`). Dashboard sections must stay
  behind `DeferredSection` with staggered `deferMs`.
- Writes from gestures must throttle: canvas uses 100ms + movement epsilon +
  1.5s presence debounce — copy that pattern, do not write per-pointer-event.
- Presence heartbeat stays at 60s; do not shorten.

## Animation rules

- No `setState` in ticker callbacks — use `ValueNotifier`/`AnimatedBuilder`.
- Decorative layers: `RepaintBoundary` + `ExcludeSemantics` + `IgnorePointer`,
  pause on background, static under `AppMotion.reduced`.
- `BackdropFilter` is already disabled on web (`EverglowGlass`); keep it that
  way. Below-the-fold animated sections go in `DeferredSection`.

## Next huge wins (roadmap, not yet done)

1. **Deferred imports for heavy routes** — SHIPPED (this pass), measured honestly.
   Deferred via DeferredRouteLoader (lib/core/router/deferred_route.dart):
   play-zone games (chess/scribble/table-tennis/lobby), manga reader,
   watch-party player, voice-chat service (VoiceChatBootstrap), party
   downloads, budget, cookbook. Verified with release builds:
   main.dart.js 5.90MB -> 5.69MB with ~210KB across 13 *.part.js
   chunks. Source-map attribution showed why the win is modest: feature
   Dart is a minority of the bundle (cinema 155KB, manga 102KB, anime
   100KB, dashboard 92KB, books 87KB, ai 83KB mapped). The rest is
   framework/packages/engine glue plus canvaskit.wasm (~7MB, larger than
   the JS itself). So: keep deferring route-only screens when touched
   (pattern is cheap now), but do NOT expect 30-50% from code splitting
   alone. Blocked subtrees and why: books reader (shared with manga
   drawer/nav — needs cross-feature conversion), cinema/anime/jukebox
   (dashboard-preview coupled), episode drawer (dashboard coupled).
   Remeasured Sep 2026 (release, no source maps): main.dart.js 5.98MB
   + 15 deferred chunks (~290KB), fonts 1.15MB, milestones 2.63MB,
   build/web total ~123MB (canvaskit + engine dominate). Build green,
   so all recompressed assets and subset fonts resolve.

2. **Milestone photos -> JPEG** — SHIPPED. Milestones dir total
   ~10.9MB -> ~2.6MB: the five ~900KB PNGs became quality-82 JPEGs
   (refs updated, PNGs deleted) and the remaining 18 originals were
   recompressed at quality 80 (6.31MB -> 2.18MB, filenames unchanged).
   Verified visually; no transparency in these photos.
3. **Font subset** — SHIPPED: all 17 TTFs subset to latin + latin-ext
   (1.77MB -> 1.15MB, saves ~662KB). Family/weight names preserved,
   full suite green, no new golden diffs.
4. **Audit `snapshots()` + migrate images** — SHIPPED: watch-list caps,
   14 more caps on growth lists (read list, bookmarks, manga library,
   our books, notes, wiki, heatmap guard, milestones), doc/time-bounded
   queries left alone; image migration finished except deliberate keeps
   (see image rules). No new indexes needed (limit-only additions).
5. **Measure**: `flutter build web --release` then check `build/web` sizes;
   profile scroll FPS in Chrome DevTools Performance tab with CPU 4x
   throttling on cinema/anime grids and dashboard.

## Verify a perf change

- `flutter analyze <changed files>` (repo rule: always before commit).
- On the phone: Creator Studio → System → **Frame meter**, then reset it, scroll
  the screen you changed, and compare against the numbers in the PR. Raster
  should fall when pixels get cheaper, build when less re-runs per frame.
- `flutter build web --release --no-source-maps` and compare
  `build/web/main.dart.js` bytes + `build/web/canvaskit/*` before/after.
- DevTools Network: confirm 3D/HLS scripts absent on cold gateway load,
  present after guardian/video visit. Confirm splash dismisses < first frame.
- DevTools Performance (4x CPU): scroll cinema/anime grids, watch for
  long frames from image decode (should drop after `cacheWidth`).
