# Idle dashboard frames (PR 603)

JS release builds, headless Chrome, 430x932 @3x, CPU 4x, `?agent=dashboard&perf=1`.
Frames drawn per 5 s window, 8 windows, page left idle:

| Build | Frames per 5 s |
|---|---|
| Before (main) | 25, 57, 73, 52, 121, 62, 62, 49 |
| After | 25, 15, 13, 12, 47, 15, 16, 14 |

The first window is page load. The 47 is an idle section warm-up.

Scroll probe (`tool/perf/probe_scroll.mjs --screen dashboard`), first-down phase, 2 runs each:

| Build | Worst frame | Worst build | Avg build |
|---|---|---|---|
| Before | 144.6 / 143.3 ms | 70.5 / 44.0 ms | 12.1 / 10.3 ms |
| After | 126.9 / 141.7 ms | 43.7 / 46.2 ms | 9.0 / 9.8 ms |

Same within noise: this change targets idle time, not scrolling.
