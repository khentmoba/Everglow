# Benchmark baseline — TypeScript React & Legacy Flutter

> **Note:** Pre-PR #588 synthetic/broken driver tables were withdrawn and are not performance acceptance evidence. The active baseline below is for **TypeScript React** (`react/`); PR #588 and PR #599 **Flutter CanvasKit** figures are retained strictly as **legacy** historical reference. Real-phone and authenticated-screen targets remain unverified.

## Current TypeScript React Dashboard Baseline (Post-Migration)

Measured on `react/dist` (`npm --prefix react run build`, commit `47721a17`) in agent mode (`/?agent=dashboard`) with headless Chrome via `tool/perf/_harness.mjs` at `430x932 @3x`, CPU throttled `4x` (3 boot runs, 2 scroll runs). Raw samples: `docs/pr-proof/react-perf-baseline/raw/react-boot-scroll.json`.

| Metric | Value (React) | Legacy Flutter (PR #588) |
| --- | --- | --- |
| First dashboard mount/paint (`4x` CPU) | `1,679.4 ms` | `6,536 ms` |
| Boot worst long task (`4x` CPU) | `635 ms` | `1,508 ms` |
| Long tasks > 200 ms (boot + scroll) | `4` (`4` boot + `0` scroll) | `19` (whole session: boot + scroll) |
| Unthrottled desktop boot (`1x` CPU) | `556.1 ms` (`155 ms` worst LT, `0` > 200 ms) | — |
| Cold boot (`4x` CPU + `fast3g`) | `5,561.5 ms` (`4,716.5 ms` load) | — |
| Initial JS (`index-*.js`) | `2,526.5 kB` raw (`709.4 kB` gzip) | `4,822.5 kB` (`main.dart.js` only) |
| Scroll worst frame (`4x` CPU) | `115.5 / 119.2 ms` (avg `10.0 ms`, p95 `38.5 ms`) | `425.8 ms` *(PR #599: `145 / 133 ms`)* |
| Scroll frames > 200 ms | `0 / 0` | `4` |
| Scroll worst long task (`4x` CPU) | `51 / 54 ms` (`0` > 200 ms) | — |

## Legacy Flutter CanvasKit Dashboard Scroll Baseline (PR #588)

Measured on the real dashboard in agent mode (`/?agent=dashboard&perf=1`)
with headless Chrome CanvasKit at `430x932 @3x`, CPU throttled `4x`, default
`2500 ms` settle before the first swipe:

```sh
flutter build web --release --no-source-maps
node tool/perf/probe_scroll.mjs --web-root build/web --dpr 3 --throttle 4 --passes 2
```

| Metric | Value (Baseline to hold/beat) |
| --- | --- |
| First dashboard paint | `6536 ms` |
| Worst frame | `425.8 ms` |
| Worst build | `329.9 ms` |
| Worst raster | `211.0 ms` |
| Frames > 200 ms | `4` |
| Worst long task | `1508 ms` |
| Long tasks > 200 ms | `19` (18 in `first-down`, +1 in `repeat-down-1`, 0 in `repeat-up`) |
| Frame counts (`first-down` / `repeat-down-1` / `repeat-up`) | `74` / `122` / `134` |

Notes for future comparisons:
- Run on the same machine/browser/build flags when comparing before/after.
- Desktop headless Chrome with `4x` CPU throttle is a regression baseline,
  not a real-phone FPS guarantee.
- The per-phase long-task counts above came from a probe that counted the
  whole session, boot included. The probe now counts each phase on its own.
- Cinema, Anime, Mangacelestia, Books and dashboard-to-section navigation
  have their own before/after baseline in `perf-baseline-sitewide.md`.
