# Unblocking the WebAssembly renderer

## Why this exists

Khent reported that scrolling Everglow on his phone starts at **4-5 fps** for the
first few seconds and only then recovers to 47-60 fps. His on-device meter
(`?perf=1`) showed `build 0.8 / 3.0 ms` but `raster 2.7 / 72.0 ms` — so on a real
phone the Dart-side build work is already fine and the cost is **rasterization on
the main thread**.

A CDP trace of the real dashboard agreed: every scroll frame was a single
300-600 ms `RunTask` containing one `FireAnimationFrame`, while DOM `Paint`
totalled 63 ms and `Layout` 282 ms across the whole scroll.

Flutter's answer to main-thread rasterization is the `skwasm` renderer, which
draws off the main thread. `flutter build web --wasm` could not compile at all:

```
Error: The unavailable library 'dart:html' is imported through these packages
```

Four files used the legacy web libraries, which the WebAssembly compiler does
not provide.

## What changed

Behaviour-preserving migration of the four files from `dart:html` / `dart:js`
to `package:web` / `dart:js_interop`:

| file | was | now |
| --- | --- | --- |
| `lib/features/books/data/services/book_download_helper_web.dart` | `AnchorElement` | `web.HTMLAnchorElement` |
| `lib/features/ai/data/services/sse_streamer_web.dart` | `HttpRequest`, `document.on['visibilitychange']`, `window.requestAnimationFrame` | `web.XMLHttpRequest`, `addEventListener`, `web.window.requestAnimationFrame` |
| `lib/features/books/presentation/screens/reader_screen_web.dart` (+ its `part` `reader_screen_state_base.dart`) | `IFrameElement`, `Element` | `web.HTMLIFrameElement`, `web.Element` |
| `lib/features/ai/presentation/widgets/motchi_web_bridge_web.dart` | `dart:html` **and** `dart:js` (`JsObject`, `js.context`) | `package:web` + `dart:js_interop_unsafe` (`globalContext`, `callAsConstructorVarArgs`, `callMethodVarArgs`, `getProperty`/`setProperty`) |

`grep -rn "import 'dart:html'\|import 'dart:js'" lib/` now returns nothing.

Two real errors surfaced during the wasm build and were fixed:

- A JS callback cannot be an `async` function — its `Future` return type has no
  JS equivalent. The image-resize load handler is now a sync callback that
  detaches the async work with `unawaited`.
- `x is JSString` is not platform-consistent for interop types. Replaced with
  `isA<JSString>()`.

## Proof the blocker is gone

```
flutter build web --wasm --release
√ Built build\web_wasm
```

## Measured result (same scene, both builds)

Real dashboard via `?agent=dashboard&perf=1`, headless Chrome 430x932 @3x,
CPU throttled 4x, `node tool/perf/probe_scroll.mjs`, 2 passes.

| | CanvasKit | skwasm | change |
| --- | --- | --- | --- |
| first dashboard paint | 5800 ms | 3939 ms | -32% |
| worst frame | 613.2 ms | 130.3 ms | **-79%** |
| worst build | 444.8 ms | 22.8 ms | -95% |
| worst raster | 204.6 ms | 127.2 ms | -38% |
| frames over 200 ms | 8 | 0 | **-100%** |
| long tasks over 200 ms | 20 | 3 | -85% |
| worst long task | 1972 ms | 821 ms | -58% |
| frames over budget | 100% | 37.5% | -62.5 pts |
| avg build (first pass) | 44.91 ms | 3.53 ms | -92% |
| avg raster (first pass) | 49.78 ms | 16.52 ms | -67% |
| reported frames (first pass) | 73 | 185 | 2.5x |

### The renderer really was skwasm

The improvement is only meaningful if the wasm build actually ran skwasm rather
than its JavaScript fallback. Verified by network + globals on the same page:

```
globals: {"keys":["_flutter","_flutter_skwasmInstance"]}
loaded:  ['skwasm_heavy.wasm', 'skwasm_heavy.js', 'main.dart.wasm']
```

## No visual regression

![dashboard under skwasm](wasm-dashboard.png)

Real dashboard rendered by the wasm build at 430x932. Every one of the 64
agent destinations renders under it:

```
node tool/agent_smoke.mjs build/web_wasm   # exit 0, 64 rendered, 0 failed
```

## Checks run

```
flutter analyze                                     No issues found!
flutter test --exclude-tags="golden,network"        All tests passed! (+1854)
dart tool/ci/check_*.dart                           16/16 exit 0
PERF_REQUIRE_CHROME=1 node --test tool/perf/harness.test.mjs   24/24 pass
```

## Limits — read before enabling the renderer

This PR **does not change the deployed renderer**. `main` still builds with
CanvasKit, so nothing changes for Clair until a follow-up flips the build.

What is *not* validated, and why the flip is a separate decision:

- **Media playback.** The cinema player, `just_audio` and `flutter_webrtc`
  compile to wasm (the build would have failed otherwise) and every cinema
  route renders, but actual video/audio playback and WebRTC were not exercised
  — headless Chrome has no real media pipeline. Cinema matters to Clair, so this
  needs a real-device check before flipping.
- **Multi-threaded rasterization.** `skwasm` can use multiple threads only under
  cross-origin isolation (COOP/COEP). The numbers above are single-threaded,
  which is the conservative case.
- **Offline.** The service worker does not yet cache `main.dart.wasm` /
  `skwasm_heavy.wasm`; enabling the renderer needs that for offline boot.

Desktop headless Chrome is not an iPhone. These numbers compare two builds on
one rig; they are not a device FPS promise.

## Tooling added

- `tool/perf/probe_scroll.mjs` — scrolls the real dashboard in agent mode and
  reports per-phase frame/raster/long-task cost. Deliberately does **not** enable
  the accessibility tree: doing so rewrites a DOM semantics tree every scroll
  frame and measured as its own multi-second hotspot, swamping the result.
- `tool/perf/_sourcemap.mjs` — resolves minified `main.dart.js` positions from a
  CDP profile back to Dart source, so a hotspot can be named instead of guessed.

## Things that were ruled out

Recorded so the next attempt does not repeat them:

- **Deferred-section work.** Blocking *all* scroll-time Dart work (geometry
  checks and card mounts) changed nothing: worst frame 613 -> 660 ms.
- **Pixels.** At 1/9 the pixel count (dpr 1 vs 3) raster cost was unchanged, so
  the existing `?dpr=` knob cannot fix this.
- **RepaintBoundary on the five top dashboard slivers.** Correct in principle,
  measured at -2.6% median / +0.6% mean across 3 runs per build — inside the
  noise. Reverted rather than shipped as an unproven perf claim.
