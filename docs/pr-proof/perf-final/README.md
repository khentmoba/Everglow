# Final audit — proof

## Release build

`flutter build web --release --no-source-maps` succeeds.

| | value |
| --- | --- |
| `main.dart.js` | 6.46 MB |
| `build/web` total | 56 MB |
| `canvaskit.wasm` | 6.89 MB |
| deferred route chunks | 40 |

**Not comparable to the sizes recorded earlier in PERF_NOTES** (5.98MB / ~123MB):
those came from a different build wrapper (`tool/build_web.dart`, which stamps the CanvasKit CDN URL) and a different Flutter revision. Inventing a delta between them would be dishonest.

What *is* directly measurable — this pass adds no production weight:

```
$ grep -c perf-bench build/web/main.dart.js     # production build, no dart-define
0
$ # same grep, same file, sanity check that it works at all:
$ grep -c Everglow build/web/main.dart.js
41
$ # rebuild with the define:
$ grep -c perf-bench build/web/main.dart.js
3
```

The 528-line bench scene is fully tree-shaken out of production. Everything else
added ships only when `?perf=1` is passed.

## Final harness numbers

Throttled (4x CPU), 5 runs, `min` columns:

| scene | phase | build min | raster min | worst frame min | worst long task |
| --- | --- | --- | --- | --- | --- |
| shelves (dashboard shape) | idle | 2.67ms | 4.40ms | 12.9ms | 0ms |
| shelves | scroll | 3.06ms | 4.29ms | 14.1ms | 64ms |
| grid (browse shape) | idle | 1.66ms | 2.29ms | 10.2ms | 0ms |
| grid | scroll | 2.18ms | 3.52ms | 20.8ms | 0ms |

Full tables and noise bands: `docs/perf-baseline.md`, `docs/perf-baseline-unthrottled.md`.

**Before/after: the numbers did not move.** That is the honest result, and the
reason matters: the shared layer this goal set out to speed up had already been
optimised by the earlier ultra-perf pass and #440 — verified by reading the code,
not assumed. The one real defect found (Tonight's uncapped decode) is a static
asset decode, invisible to a scroll benchmark. There was no headroom left in the
thing being measured on this hardware.

## The bar, stated plainly

| contract item | status |
| --- | --- |
| no main-thread block over 200ms | **met** — worst long task 0–75ms, throttled and not |
| cold boot < 2.5s on a fast link | **met** — 1531ms median |
| cold boot < 2.5s on slow 3G | **NOT met** — 138,580ms; a ~13MB download over a 50KB/s link |
| every key screen >= 55 FPS, < 5% jank, 0 dropped | **NOT verified, and not verifiable here** |

The last row is the one that matters. Three structural reasons, not oversights:

1. **No unauthenticated path to any feature screen** — `app_router.dart` treats `/` as the only public route.
2. **The FPS/jank columns are meaningless in headless Chrome.** In the final run above, `grid`/scroll reports **0 FPS** while its build and raster figures are stable and sane: the page isn't vsync-capped, so frame rate wanders on a healthy build. The bench gates on build/raster/worst/long-task precisely because those are the trustworthy columns.
3. **A desktop GPU cannot speak for a DPR-3 phone.** Measured directly: the aurora painter, documented as "the single largest raster cost", moves this bench by 0.03ms.

So the smoothness claim now rests on `docs/PERF_PHONE_CHECK.md` — a ten-minute
procedure for reading the restored frame meter on an actual device, with the
bar, the readings table, and how to interpret each combination. Everything needed
to run it is shipped and reachable.

## No silent scope cuts

| not done | reason |
| --- | --- |
| per-screen FPS/jank on device | needs a phone; automated above, stated as unmet |
| ambience idle frame-rate throttle | real phone win, invisible here, risks choppy with no way to check |
| SW cache-first for the shell | fixes the 134s repeat boot; deploy semantics = Khent's call |
| removing the `kIsWeb ? null` avatar guard | obsolete on Chromium, unverified on Safari (grey avatar risk) |
| Creator Studio perf switches | deleted long ago; `?perf=1` covers it |
| shrinking `main.dart.js` further | deferred-route splitting already shipped; remaining bytes are framework/engine/CanvasKit |

Checks: `flutter analyze` clean · `flutter test` 1410 passed · all 14 guards pass · release web build succeeds.
