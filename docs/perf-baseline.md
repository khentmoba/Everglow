# Benchmark baseline — previous report withdrawn

The old tables were produced by a driver that could accept zero-frame mirrors,
non-scrolling animated pages, missing boot observers and invalid cold network
shaping. They are not performance acceptance evidence or a before/after baseline.

A corrected run must use the new synthetic posters, fresh cumulative meter
samples, actual scene/scroll state and full-window long-task observations. See
`PERF_NOTES.md` and `pr-proof/perf-cleanup/README.md` for current verification.
Real-phone and authenticated-screen targets remain unverified.

## Current CanvasKit Dashboard Scroll Baseline (PR #588)

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

