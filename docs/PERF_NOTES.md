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
| Frame meter | `?perf=1` on the URL | Overlay with FPS, jank %, dropped %, and build/raster avg + worst. Tap it to reset the window — reset, scroll the screen you care about, read the numbers. |
| Render scale | `?dpr=2` | Renders at N device pixels per logical pixel instead of the browser DPR. Layout is unchanged (the engine measures the viewport in CSS px and divides by the same DPR); only the backbuffer resolution changes. **Needs a reload.** |

`?perf=0` turns the meter back off. Both settings persist
(`perf_settings.dart`). The in-app Creator Studio → System switches are **not**
back: they were removed in `cfa3c9c1` and the URL flags are all this pass
needs. Note the installed PWA cannot have its start URL edited, so to read the
meter *inside* the PWA, turn it on from a normal browser tab first — the
setting is remembered.

On web the meter also mirrors every reading to `window.__everglowPerf`, which is
what `tool/perf/bench.mjs` reads. That is how a headless run measures the app
instead of guessing: see `docs/perf-baseline.md`.

Reading the numbers: **build high** = widgets re-running every frame; **raster
high** = too many pixels (full-screen gradients, shadows, blurs, glyphs). iPhone
15 Pro Max reports DPR 3 = a 1290x2796 surface, so raster is the usual suspect
at that scale.

## Mobile smoothness pass (in progress)

Why: the dashboard is laggy and freezes on first load on an iPhone 15 Pro Max,
even though the visuals are fine. Measured causes, in order:

> **Re-verified against the code in the 2026-10 dashboard pass.** Every cause
> listed here is now fixed. Do not re-open one without a measurement.
>
> - **1 is fixed and mechanically pinned.** `DeferredSection` no longer has a
>   web branch that waits and then shows everything: it reads the section's
>   geometry against a real viewport and only reveals inside a preload margin,
>   with a scroll listener, a post-frame re-check and a 400ms safety net as
>   backstops. Reproduce with:
>   `flutter test test/deferred_section_test.dart test/core/perf/scroll_jank_benchmark_test.dart`
>   (8 tests, including "far-below sections stay unmounted until scrolled to",
>   "deferMs never mounts a section that is offscreen", and an initial-mount
>   ceiling of <= 4 sections). Those tests pass, so the laziness claim is
>   verified rather than assumed — which is what the old note needed.
> - **2 is fixed**: `DashboardAmbience` now pauses while the list scrolls (#440)
>   and `DashboardCursorGlow` deliberately does *not* start its controller at
>   init — it is created stopped and only started by `_handleHover`, which never
>   fires on a phone.
> - **4 is fixed**: skeletons share one ref-counted `EverglowShimmerScope`
>   controller, and each one repaints through a `CustomPaint(painter:)` with a
>   `repaint:` Listenable plus a `RepaintBoundary`, so no skeleton rebuilds.
> - **The sparkles widget file named in the "Shipped" list below no longer
>   exists** — that item's code was moved or deleted. Treat the note as stale,
>   and find the current implementation before citing it.

1. **Every dashboard section mounts on frame 1.** `SliverToBoxAdapter` mounts
   all of its children eagerly (verified: 20/20 in a probe test) and the whole
   dashboard is built from `SliverToBoxAdapter`s, so all ~25 sections — their
   Firestore streams, tickers, images and painters — exist from the first frame,
   even 8 screens below the fold. `DeferredSection` was meant to prevent this,
   but its `kIsWeb` branch only waits 0–700ms and then shows everything.
   — *fixed; see the re-verification note above.*
2. **Two full-screen painters tick forever on the dashboard**: `DashboardAmbience`
   (3 aurora ribbons drawn as 6 big gradient strokes, 14 petals × 3 ghost trails,
   and 6 freshly allocated gradient shaders per frame) and `DashboardCursorGlow`,
   which starts its 60fps loop at init even though it only draws on mouse hover.
   — *see the re-verification note above; both are fixed.*
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

5. **Sparkles halved** — *STALE: the widget this item names no longer exists
   in the tree. Kept as history; find the current implementation before citing.*
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

## Shared-layer pass (2026-10) — what the bench could and could not prove

With `tool/perf/bench.mjs` in place, the shared layer was A/B'd rather than
assumed. Result: **it is already in good shape**, and the one real defect found
was an image, not an animation.

### The ambience painter is not the cost this rig can see

`/perf-bench/shelves` vs `/perf-bench/shelves-plain` (identical scene, aurora
painter removed), 3 runs each, unthrottled, `min` columns:

| | build ms | raster ms | worst frame ms |
| --- | --- | --- | --- |
| shelves (with ambience) | 0.61 | 0.69 | 2.4 |
| shelves-plain (no ambience) | 0.58 | 0.68 | 2.6 |

A ~0.03ms build difference, well inside the noise band for that column. The
claim that `DashboardAmbience` is "the single largest raster cost" comes from
phone measurements on mobile Safari WebGL; on a desktop GPU the same strokes
cost under a millisecond. **So the headless bench cannot validate or refute
full-screen-effect work** — only the phone frame meter can. Do not spend a pass
optimising painters on the strength of this rig.

> The first version of this A/B was wrong and is worth recording: the bench
> built its image URLs with `Uri.base.resolve()`, which resolves against the
> *route*, so the nested `/perf-bench/shelves-plain` requested
> `/perf-bench/assets/...`, 404'd, and silently measured a scene with **no
> images at all** — which still produced a plausible table. The proof
> screenshot is what caught it. URLs are now built from the site root.

### Fixed: an uncapped decode in Tonight

`tonight_screen.dart` drew date-option thumbnails with a bare `Image.network`
and no `cacheWidth`, decoding every one at natural resolution (~3.5MB each per
the memory table above) to fill a **76px** slot. It now goes through
`AppNetworkImage` with `cacheWidth: 240` compact / `400` full. Same pixels on
screen — the decode is just sized to the display.

`check_image_fallback.dart` now enforces `cacheWidth` **per call site**, not per
file. A file-level check was tried first and silently passed a tampered file
because a *different* call in the same file had a `cacheWidth`; the guard now
reports the offending line and was verified to fail on the pre-fix version of
the file.

## Dashboard pass (2026-10) — structure verified, content still unmeasurable

The dashboard's four documented causes are all fixed in the current code, and
the one that mattered most is now pinned by tests that were run, not assumed
(see the re-verification note above). Two things follow.

### The bench's `shelves` scene stands in for the dashboard's *shape*

The dashboard cannot be loaded headlessly — it is behind auth and Firestore
data — but its structure is what costs frames: many `DeferredSection`s over a
full-screen ambience layer, poster shelves, a marquee, shimmer and pulse. The
`shelves` bench scene is exactly that shape, so it is the closest automated
proxy available. At 4x CPU throttle, `min` columns:

| phase | build ms | raster ms | worst frame ms | worst long task ms |
| --- | --- | --- | --- | --- |
| idle | 3.05 | 4.99 | 15.0 | 0 |
| scroll | 3.33 | 4.76 | 15.1 | 62 |

Read those as "the dashboard's shape is comfortable on a desktop GPU", which is
a weak claim by construction. The bench runs a desktop GPU with a fast CPU, and
the goal's bar (>= 55 FPS, < 5% jank on an iPhone) is a *device* claim about
real content, Firestore fan-out and DPR-3 raster. That still has to be read off
the phone frame meter.

### Deliberately not changed: the ambience idle frame rate

`DashboardAmbience` keeps painting a full screen continuously whenever the
dashboard is not scrolling, which is most of the time. Throttling its idle rate
would cut real phone work — but a slow aurora at a lower rate can read as
choppy, and **this rig cannot see the effect at all** (the A/B above moved
build by 0.03ms). Changing a decorative layer's cadence on the strength of an
unmeasurable guess, with no way to check how it looks on her phone, is exactly
the kind of change that should not be made unattended. It is left as a
candidate for a phone A/B, not a task.

## Cold-boot pass (2026-10) — the 2.5s bar is unreachable, and it is arithmetic

Measured with `node tool/perf/measure_boot.mjs` (3 runs each, median, link
shaped in the server). Three cases:

| case | first interactive | first paint | worst long task | vs 2.5s bar |
| --- | --- | --- | --- | --- |
| fast link, first visit | **1531ms** | 216ms | 0ms | **met** |
| slow3g (400kbit = 50KB/s), first visit | **138,580ms** | 212ms | 0ms | missed ~55x |
| slow3g, repeat visit (SW warm) | 134,033ms | **28ms** | 0ms | missed |

### Why the slow3g number cannot be fixed in code

To reach first frame in 2.5s over a 50KB/s link, the critical path has to be
at most **~125KB**. It is about **13MB**: `main.dart.js` is 6.5MB and
`canvaskit.wasm` a further ~6.9MB. The gap is ~100x, so no amount of code
tidying closes it — the app either downloads much less or the link is faster.
Recording it as an unmet goal rather than pretending otherwise.

Two things make this number pessimistic rather than representative:

- **Localhost shaping has no CDN cache.** Production builds fetch CanvasKit
  from the gstatic CDN (`tool/build_web.dart` pins the engine revision), which
  is shared across every Flutter site and very likely already in a phone's HTTP
  cache. Every byte here comes from one deliberately slow origin.
- **slow3g is 50KB/s, not 400KB/s.** That is DevTools' own definition, and the
  name reads like 400.

### What *is* protecting the experience

**First paint is fast in every case** — 216ms on a cold slow link, and 28ms on
a repeat visit, because the splash in `web/index.html` is inline HTML + inline
CSS and needs no downloaded bytes. Someone opening Everglow on a bad connection
sees Everglow almost immediately and waits behind it, instead of a white screen.
That is the part that is genuinely working, and it is worth more than the
first-frame number.

**No long main-thread task anywhere**: worst long task was 0ms in all nine
runs, against a 500ms bar. Boot does not jank; it waits.

### One real finding: repeat visits re-download the shell

The repeat case has FCP 28ms but first interactive 134s, which looks
contradictory until you read `tool/generate_sw.dart:273` — the SW is
**network-first** for `main.dart.js` (stamped `?v=BUILD`), so it revalidates the
shell over the network on every visit and only falls back to cache when
offline. On a fast link that costs nothing. On a 50KB/s link it costs the full
134s even though the bytes are already cached.

Cache-first for the versioned shell would fix that, and `?v=BUILD` plus the
build-stamp logic already exist to keep deploys propagating. **Not changed here:**
it alters deploy semantics, and deploy behaviour is Khent's call, not one to make
unattended while he is asleep. Recorded as the single highest-value cold-boot
change available.

### Three harness bugs this pass had to fix first

The existing script had never produced a trustworthy number, and each fix
changed the conclusion:

1. **It hardcoded `/usr/local/bin/google-chrome`**, so it only ever ran on the
   author's Linux box. Chrome is now located per platform (and the launcher is
   shared with `bench.mjs` via `tool/perf/_harness.mjs`, because two copies is
   how this happened).
2. **`Network.emulateNetworkConditions` is silently ignored by headless
   Chrome.** Asked for 400KB/s it delivered 6.77MB in 67ms (~98MB/s), so every
   "slow3g" number before this pass was measuring an unthrottled download and
   reporting it as slow. The link is now shaped in the static server, verified
   to deliver 50KB/s for a 400kbit request, with run-to-run spread of 0.05%.
3. **The static server sent `Cache-Control: no-store` and the cold run blocked
   `sw.js`**, so the service worker could never cache anything and the
   "repeat visit" silently measured two cold downloads (268s). Coldness is now
   guaranteed by the fresh profile alone, and the warm-up leg runs unshaped
   because the SW's own precache is ~13MB and would still be downloading at
   50KB/s when the measured leg began.

## Media shelves pass (2026-10) — clean on the rules, one stale workaround found

### Decode sizes across cinema / anime / manga / books: no violations

Every `cacheWidth` in the four inside features was swept against the size it
actually displays (values: cinema 150/300/520/720 + `isDesktop ? 1280 : 780`
backdrop; anime 150/320/400/560; manga 400; books 120/200/240/300/600/800).
Each is proportionate to its slot, and the one large value
(`isDesktop ? 1280 : 780`) is a full-bleed backdrop, where the table above
expects 800–1200. Nothing to fix.

The two documented deliberate keeps — the full-screen photo viewer and the manga
reader — are the only places allowed to decode at natural size, and
`check_image_fallback.dart` now enforces `cacheWidth` per call site (see the
shared-layer pass), so a new uncapped call fails CI rather than shipping.

### Real shelves cannot be measured headlessly; structural proxies can

Every real shelf is behind auth and Firestore data. What the bench *can* cover
is the shape those screens have in common — poster cards in rows and in a
browse grid. Unthrottled `min` columns:

| proxy | build ms | raster ms | worst frame ms |
| --- | --- | --- | --- |
| `shelves` scroll (shelf rows) | 0.60 | 0.70 | 2.7 |
| `grid` scroll (browse grid) | 0.40 | 0.79 | 4.0 |

Same caveat as the dashboard: a desktop GPU cannot speak to the >= 55 FPS
DPR-3 device bar. The per-screen verdict still comes from the phone meter.

### Found: a stale web workaround, left in place on purpose

Nine call sites size a bundled avatar decode like this:

```dart
cacheWidth: kIsWeb ? null : 108,   // 512x512 asset drawn in a 36px slot
cacheHeight: kIsWeb ? null : 108,
```

So on web — the platform Clair actually uses — the 512x512 avatar (1MB decoded)
is decoded at full size to fill a 36px slot that needs 108x108 (0.05MB). A ~20x
waste, on the AI chat surface, repeated across `motchi_widgets`,
`motchi_widgets_streaming`, `motchi_widgets_extra`, `motchi_sidebar_panel`,
`study_screen_bubbles`, `study_screen_builders` and the animex Motchi sidebar.

The guard came from `d6eb7ea5` ("eliminate remaining grey overlay on Together
zone"), a batch of web workarounds for SkWasm painting opaque grey — the same
commit also forced `DeferredSection` always-visible on web, a workaround that
has since been removed. So the pattern is exactly the kind of leftover that
outlives its cause. Two things say it is obsolete:

- A probe rendering the same asset side by side with `cacheWidth: 108` and
  `null` on the current engine **both render correctly** — no grey, no dimming
  (proof: `docs/pr-proof/probe-cw/`). The first attempt at that shot looked
  like a difference and was not; the avatar had been sitting under the
  translucent frame-meter HUD.
- `motchi_widgets_extra.dart:32` already uses `cacheWidth: 540` on a 180px slot
  with **no** `kIsWeb` guard. If `cacheWidth` were unsafe on web, that site
  would already be broken.

**RESOLVED — verified on Safari, shipped on.** (2026-10-04) Khent loaded the
preview on **Safari** — the platform this could not be tested from, and Clair's
actual browser — with `?sizeddecode=1` and `?sizeddecode=0` and reported the
avatars **identical**. The SkWasm grey problem this guard worked around is gone
on this engine, on both browsers.

So it is now the default: `PerfSettings.sizedAssetDecode` +
`sizedDecodeWidth()`, covering every bundled-image call site (chat bubble,
dashboard emblem, timeline photos, and all Motchi avatars via the single
`_MotchiAvatar` widget that #439 introduced). A 512x512 avatar decoding into a
36px slot was roughly 1MB; at 108px it is ~0.05MB.

`?sizeddecode=0` remains as a **kill switch**, persisted so it survives a PWA
launch — if this ever regresses it can be undone from a URL, no deploy needed.
Default off-web is unchanged, since those paths always used the sized decode.

This is the one perf claim in this file that rests on an actual phone reading
rather than a headless rig — see the note at the top of this file about why the
FPS numbers could never be.

## Chat / Motchi / gallery / journal pass (2026-10) — correct today, now enforced

### Privacy re-verified (no regression)

Nothing in this pass touched rules, but the contract asks for a check, so:
`gallery`, `notes`, `journal_entries`, `motchi_games`, `motchi_sessions`,
`temporary_chats`, `watch_party_chats` and every couple collection are gated on
`isCouple()`, which is `isRegistered() && hasCoupleIdentity() && username ==
request.auth.token.username` — not merely "signed in". `motchi_notes` and
`motchi_stats` are `allow read, write: if false`, i.e. server-only via the admin
SDK. Cinema-only profiles (Breyan / Octagram) still cannot reach any of it.

### The streaming path is already built the right way

`motchi_widgets_streaming.dart` drives its motion with `AnimatedBuilder`, and
its `setState` calls are discrete state (`_isListening`, `_hasText`, `_focused`)
rather than per-frame rebuilds. The gallery grid uses `AppNetworkImage` with
`cacheWidth: 440` (a tile is ~130–220px, so that is sized right), and the photo
viewer keeps its natural-size decode as a documented keep.

### What was missing: the rule had no enforcement

`docs/PERF_NOTES.md` states the rule plainly — *"No `setState` in ticker
callbacks — use `ValueNotifier`/`AnimatedBuilder`"* — and nothing checked it.
`tool/ci/check_perf_rules.dart` now does, and runs in CI.

Getting it to be trustworthy took three attempts, each of which mattered more
than the rule itself:

1. **First cut flagged 17 sites on a clean tree.** All were legitimate: a
   `FocusNode` listener, a `TextEditingController` listener, and
   `Timer.periodic` at 2200ms and 30s. A guard that cries wolf on working code
   gets ignored or deleted, so the rule was narrowed to shapes that really are
   frame-rate: a callback on a *known* `AnimationController`/`Ticker`, or a
   `Timer.periodic` whose period is <= 20ms.
2. **The narrowed guard still produced 4 false hits**, because its duration
   parser read `Duration(seconds: 1)` as 1 **millisecond** — an absent unit
   prefix means seconds. Every 1-second clock in the app became a phantom
   frame-rate violation.
3. **One more, from substring matching**: a method named `_startClockTicker()`
   contains `Ticker(`, so it read as a Ticker construction. Fixed with a
   negative lookbehind.

Final state: **0 hits across 620 files**, and it was verified to *fail* on an
injected 16ms timer, an injected 8ms timer, and a synthetic
`AnimationController.addListener(() => setState(...))` (each naming the right
file, line and owning variable).

Two things this turned up that are worth keeping in mind when reading the code:
`partner_presence_indicator` and `partner_doodle_indicator` both carry comments
about *previously* being 1s and 250ms tickers that rebuilt their subtrees far
more often than any label could change. The rule was already being applied by
hand; it just had nothing stopping the next person from undoing it.

### Streaming FPS remains unmeasurable here

"Chat and Motchi meet >= 55 FPS while a reply streams" needs auth, Firestore
history and a live AI backend. The bench covers the *shape* (poster/avatar rows
over a full-screen ambience) but cannot drive a real stream, and its FPS column
is meaningless in headless anyway. That bar is a phone check with
`?perf=1`, and it is now reachable rather than removed.

## Long-tail coverage (2026-10) — every feature accounted for

### The hard constraint: no feature screen is measurable headlessly

`app_router.dart` treats `/` as the only public path and bounces every other
route to the gateway when logged out. So **not one** feature screen can be
driven by the headless bench — not because the harness is incomplete, but
because there is no unauthenticated path to any of them. That is why the bar
for these screens is a phone check, and why the bench coverage in this document
is stated as *shape* coverage rather than per-screen numbers.

### What every feature does get: mechanical coverage

Five guards scan all of `lib/` (620 files, 528 of them under `lib/features/`)
on every PR, so a regression in any feature below fails CI whether or not
anyone can measure it:

| guard | what it blocks |
| --- | --- |
| `check_image_fallback.dart` | bare `Image.network` without `errorBuilder`, and without `cacheWidth` **per call site** |
| `check_stream_limits.dart` | unbounded `snapshots()` (would need a `limit()` or an explicit waiver) |
| `check_perf_rules.dart` | `setState` driven by a frame-rate callback |
| `check_perf_notes.dart` | `docs/PERF_NOTES.md` citing a path that no longer exists |
| `check_assets.dart` | bundled asset references that do not resolve |

### Inventory

| feature | dart files | bare `Image.network` | `snapshots()` | unbounded waivers |
| --- | --- | --- | --- | --- |
| academy | 15 | 0 | 3 | 0 |
| ai | 50 | 0 | 2 | 0 |
| anime | 48 | 0 | 0 | 0 |
| books | 35 | 0 | 5 | 0 |
| bucket_list | 9 | 0 | 3 | 0 |
| calendar | 12 | 0 | 4 | 0 |
| canvas | 7 | 0 | 2 | 0 |
| chat | 6 | 0 | 1 | 0 |
| cinema | 62 | 0 | 12 | 0 |
| daily_bloom | 18 | 0 | 2 | 0 |
| dashboard | 54 | 2 | 8 | 0 |
| date_randomizer | 5 | 0 | 0 | 0 |
| entry | 6 | 0 | 0 | 0 |
| gallery | 8 | 2 | 2 | 0 |
| guardian | 8 | 0 | 0 | 0 |
| heartbeat | 6 | 0 | 1 | 0 |
| journal | 8 | 0 | 5 | 0 |
| jukebox | 37 | 0 | 2 | 0 |
| manga | 41 | 1 | 5 | 0 |
| money | 5 | 0 | 2 | 0 |
| play_zone | 17 | 0 | 1 | 0 |
| starlight_jar | 9 | 0 | 2 | 0 |
| subs | 6 | 0 | 1 | 0 |
| tonight | 5 | 0 | 1 | 0 |
| trip_kit | 6 | 0 | 2 | 0 |
| watch_party | 33 | 0 | 8 | 0 |
| xp | 3 | 0 | 1 | 0 |

**Zero unbounded-stream waivers exist anywhere in the app**, so every
`snapshots()` in the list above is bounded — the `#36`/`#55` class cannot come
back without a deliberate, visible waiver.

The five remaining bare `Image.network` calls are all deliberate keeps, and the
photo-viewer and manga-reader files are on the guard's documented keep list:
`creator_memories_tab.dart` (x2, both with `cacheWidth` 200/600),
`photo_viewer_screen.dart` (x2, full-screen zoom) and
`reader_page_image.dart` (x1, manga pages read at high zoom).

### Directly examined during this pass

Beyond the mechanical coverage, these were read and measured rather than assumed:

| surface | what was done |
| --- | --- |
| dashboard | causes re-verified, laziness pinned by 8 passing tests |
| cinema / anime / manga / books | every `cacheWidth` swept against display size; no violations |
| chat / ai | streaming path confirmed to use `AnimatedBuilder`; privacy rules re-verified |
| gallery / journal | grid decode sizing confirmed (`AppNetworkImage`, `cacheWidth: 440`) |
| tonight | real defect found and fixed (uncapped decode into a 76px slot) |
| shared widgets | skeletons/cursor-glow/blur rules confirmed already in place |
| boot path | 3 runs x 3 profiles measured; link shaping rebuilt |

### Explicitly out of scope, with reasons

- **Per-feature FPS/jank numbers.** Unreachable headlessly (auth-gated), and a
  desktop GPU cannot produce a DPR-3 phone verdict anyway. Reachable only via
  the phone meter.
- **Full-screen painter frame rates.** Deliberately unchanged: measurable win on
  the phone, invisible on this rig (0.03ms), and a cadence change risks looking
  choppy with no way to check unattended.
- **Service-worker cache-first for the shell.** Would fix the 134s repeat-visit
  boot, but it changes deploy semantics — Khent's call.
- **The `kIsWeb ? null : N` avatar decode workaround.** Verified obsolete on
  Chromium, unverified on Safari, where the failure would be a visible grey
  avatar on Clair's phone.

## Final audit (2026-10)

### Release build

`flutter build web --release --no-source-maps` succeeds.

| | value |
| --- | --- |
| `main.dart.js` | 6.46 MB |
| `build/web` total | 56 MB |
| `canvaskit.wasm` | 6.89 MB |
| deferred route chunks | 40 |

These are **not** comparable to the sizes recorded earlier in this file (5.98MB /
~123MB): those came from a different build wrapper (`tool/build_web.dart`, which
stamps the CanvasKit CDN URL) and a different Flutter revision. Comparing them
would be inventing a delta. What *is* directly measurable is that this pass adds
no production weight:

> The 528-line bench scene is fully tree-shaken out of a production build.
> `grep -c perf-bench build/web/main.dart.js` returns **0** without the
> dart-define and **3** with it (and the same grep finds `Everglow` 41 times in
> the same file, so the zero is a real absence, not a broken search).

Everything else this pass adds to production is the restored frame meter, which
only mounts when `?perf=1` is passed.

### Final harness numbers

Throttled (4x CPU, the sensitive config), 5 runs, `min` columns — full tables and
noise bands in `docs/perf-baseline.md` and
`docs/perf-baseline-unthrottled.md`:

| scene | phase | build min | raster min | worst frame min | worst long task |
| --- | --- | --- | --- | --- | --- |
| shelves (dashboard shape) | idle | 2.67ms | 4.40ms | 12.9ms | 0ms |
| shelves | scroll | 3.06ms | 4.29ms | 14.1ms | 64ms |
| grid (browse shape) | idle | 1.66ms | 2.29ms | 10.2ms | 0ms |
| grid | scroll | 2.18ms | 3.52ms | 20.8ms | 0ms |

(Re-measured after the budget-share column was added; the build figures moved
inside the noise band, e.g. shelves/scroll 3.20ms vs 3.06ms. Full current tables
are in the two `docs/perf-baseline*.md` files.)

**Before/after: the numbers did not move, and that is the honest result.** The
shared layer this goal set out to speed up had already been optimised by the
earlier ultra-perf pass and #440 — verified by reading the code, not assumed. The
one real defect found (Tonight's uncapped decode) is a static asset decode and
therefore invisible to a scroll benchmark. Nothing here moved a number, because
there was no headroom left in the thing being measured on this hardware.

### What part of the bar *is* measurable, and what it says

FPS needs a display and a vsync, so it is out of reach headlessly. But the
**CPU-side half of a frame is not**: build time is CPU-bound, and
`Emulation.setCPUThrottlingRate` genuinely slows the CPU. So `build min /
16.7ms` is a phone-representable number, and the bench now reports it as a
column. At 4x CPU throttle:

| scene | phase | build min | **share of a 60fps frame** |
| --- | --- | --- | --- |
| shelves (dashboard shape) | idle | 2.79ms | **16.7%** |
| shelves | scroll | 3.20ms | **19.2%** |
| grid (browse shape) | idle | 1.65ms | **9.9%** |
| grid | scroll | 2.33ms | **14.0%** |

Read that as: **the app's own widget and layout work costs roughly a sixth to a
fifth of a phone's frame budget**, leaving ~81–86% for raster and platform work.
Two consequences worth having:

- It bounds where the remaining risk lives. It is **not** in rebuild loops —
  that class is now blocked in CI by `check_perf_rules.dart`. If a frame is
  ever going to blow its budget, it will be doing it in raster (pixels,
  gradients, shadows, glyphs) on the device, which is precisely what the phone
  meter reports as "raster high".
- It means the honest reading of the phone check is narrower than it looks: if
  the meter shows build low, no amount of further widget optimisation will help,
  and the work belongs in paint.

This is the closest thing to the goal bar that can be established without the
device, and it is a real bound rather than a restatement of the target.

### The bar: what is met, what is not, stated plainly

| contract item | status |
| --- | --- |
| no main-thread block over 200ms | **met** — worst long task 0–75ms across every run, throttled and not |
| cold boot interactive < 2.5s on a fast link | **met** — 1531ms median |
| cold boot interactive < 2.5s on slow 3G | **NOT met** — 138,580ms; unreachable in code, it is a ~13MB download over a 50KB/s link |
| every key screen >= 55 FPS, < 5% jank, 0 dropped | **NOT verified, and not verifiable on this rig** |

That last row is the important one. It is not met, and pretending otherwise
would defeat the purpose of the exercise. The reasons are structural, not
oversights:

1. **No unauthenticated path exists to any feature screen.** `app_router.dart`
   treats `/` as the only public route.
2. **The FPS and jank columns are meaningless in headless Chrome.** The final
   run above shows `grid`/scroll reporting **0 FPS** while its build and raster
   figures are stable and sane — the page is not vsync-capped, so the frame
   rate wanders on a perfectly healthy build. The bench's trustworthy columns
   are build, raster, worst frame and long task; those are what it gates on.
3. **A desktop GPU cannot speak for a DPR-3 phone**, where full-screen paint
   costs orders of magnitude more. Measured directly: the aurora painter, the
   documented "single largest raster cost", moves the bench by 0.03ms.

So the goal's smoothness claim rests on `docs/PERF_PHONE_CHECK.md` — a ten-minute
procedure for reading the restored frame meter on an actual device. Everything
needed to run it is shipped and reachable.

### No silent scope cuts

Everything deliberately not done, and why:

| not done | reason |
| --- | --- |
| per-screen FPS/jank on the device | needs a phone; automated above instead, stated as unmet |
| ambience idle frame-rate throttle | real phone win, invisible here (0.03ms), risks looking choppy with no way to check unattended |
| service-worker cache-first for the shell | fixes the 134s repeat-visit boot; changes deploy semantics, so it is Khent's call |
| removing the `kIsWeb ? null` avatar decode guard | verified obsolete on Chromium; unverified on Safari, where failure is a visible grey avatar on Clair's phone |
| Creator Studio → System perf switches | deleted long ago, not needed for URL-flag measurement; `?perf=1` covers it |
| reducing `main.dart.js` further | deferred-route splitting already shipped; source-map attribution in this file shows the win is modest and the remaining bytes are framework/engine/CanvasKit |

## Verify a perf change

- `flutter analyze <changed files>` (repo rule: always before commit).
- Headless (no device needed): `node tool/perf/bench.mjs --build` scrolls the
  fixed bench scenes at a 430x932 / DPR 3 viewport and rewrites
  `docs/perf-baseline.md`. Gate on the `min` columns and clear the spread in
  the noise band; ignore its FPS/jank columns, which headless cannot measure
  honestly.
- On the phone: open the page with `?perf=1`, reset the meter, scroll the
  screen you changed, and compare against the numbers in the PR. Raster
  should fall when pixels get cheaper, build when less re-runs per frame.
  This is the only place the ">= 55 FPS" bar can actually be judged.
- `flutter build web --release --no-source-maps` and compare
  `build/web/main.dart.js` bytes + `build/web/canvaskit/*` before/after.
- DevTools Network: confirm 3D/HLS scripts absent on cold gateway load,
  present after guardian/video visit. Confirm splash dismisses < first frame.
- DevTools Performance (4x CPU): scroll cinema/anime grids, watch for
  long frames from image decode (should drop after `cacheWidth`).
