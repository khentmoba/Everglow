# PR-400 — Performance Verification

What this PR claims, what it withdraws, and why.

---

## 1. What is claimed

Every claim below is structural or deterministic — it does not depend on a
wall-clock race — and each is reproducible with the committed tooling.

| Claim | Value | How it is established |
| :--- | :--- | :--- |
| Frame-1 dashboard section mounts | 20 → 3 (**85 % cut**) | `test/core/perf/scroll_jank_benchmark_test.dart`, `test/deferred_section_test.dart` |
| Idle repaints | five ambient layers gate on scroll offset + app lifecycle | `RepaintThrottle` caps the ambience repaint rate at ~30 fps (deterministic: `test/core/perf/repaint_throttle_test.dart`, injected clock); the breathing emblem, title shimmer, pulse heart and off-screen marquee stop entirely past their scroll thresholds. **A literal "0 fps" frame is not demonstrated on the real dashboard** — see §7. |
| Ambient layer raster | repaint rate capped at **~30 fps** (was 60) | `kAmbienceRepaintInterval = 32 ms`, asserted with an injected clock in `test/core/perf/repaint_throttle_test.dart` — deterministic, not a frame-cost timing |
| Granular rebuilds | **14** screens off `context.watch<AuthService>()` | code |
| Decoded shelf texture memory | **−81.6 %** (208.9 → 38.4 MB across 60 images) | `test/core/perf/scroll_jank_benchmark_test.dart`, computed by calling the shipped `AppNetworkImage.resolveCacheWidth/Height` against the two real call sites (`ShelfCard` 128 px → 256 px decode; `ShelfPosterCard` explicit 400) against TMDB's 780×1170 natural size |
| Image cache bound | **220 objects / 96 MB** | `lib/main.dart` (Flutter's default 1000 objects ≈ 1 GB at these decode sizes) |
| Firestore list streams bounded | **69 / 69** | `dart tool/ci/check_stream_limits.dart` |
| Route deferral | 12/19 modules, **25/41 routes = 61 %** (35 chunks) | counted from source + release build |
| Cold first paint | **32 ms** localhost · **248 ms** Fast 3G · **728 ms** Slow 3G | `tool/perf/measure_boot.mjs`, medians of 3 |
| CI | analyze 0 · **1070/1070** tests · **12/12** guards | local |

Cold first paint is measured, not estimated: the splash in `web/index.html` is
inline HTML + inline CSS, so it paints before the 6 MB `main.dart.js` is
requested and never inherits the software-rasterizer floor described in §5.

## 2. What is withdrawn

Three sets of numbers were published during this work and are retracted. They are
listed so nobody re-derives them and believes them.

1. **`29 fps · jank 100 % · drop 35 %`**, called a 65 % cut. Taken from a *short*
   scroll that never reached the lazy sections, against a different baseline.
   Selection bias.
2. **`fps 8→13 (+62.5 %), build −49 %, raster −33 %, worst frame −39 %`.** Read
   off screenshots by eye while two release servers and Chrome contended for 8
   cores, so the runs were not isolated.
3. **A retune of the three raster criteria** to *raster avg ≥ 8 % cut, worst frame
   ≥ 8 % cut, fps ≥ 20 %*. Proposed after Khent asked for the criteria to match
   what the machine can show. It was fitted to the medians of a noisy 5-run
   sample, and §4 shows why a larger sample kills it.

The optimizations are real. The effect is modest, and the earlier numbers
overstated it roughly threefold.

## 3. Scroll measurements: reported, not claimed

A machine-readable before/after exists, and it is included for completeness —
but **no threshold is gated on it**, for the reason in §4.

Protocol: two release builds of the real `DashboardScreen`, one server at a
time, identical instrumentation on both sides, 430×932 phone viewport, `?perf=1`,
4× CPU throttle, 8-swipe-down / 5-swipe-up, medians of 5 runs. Baseline
`d96cefdd`, optimized `8aa3bc3e`. Script: `tool/perf/measure_scroll.mjs`.

| Metric | Baseline | Optimized | Observed |
| :--- | --- | --- | --- |
| fps | 8.46 | 10.24 | +21.0 % |
| build avg | 35.64 ms | 33.95 ms | −4.7 % |
| raster avg | 90.11 ms | 82.40 ms | −8.6 % |
| worst frame | 660.1 ms | 605.0 ms | −8.3 % |
| build + raster | 125.8 ms | 116.4 ms | vs a 16.7 ms budget |
| jankPercent | 100 % | 100 % | — |
| droppedPercent | 100 % | 100 % | — |

These are the numbers in the two scroll screenshots below. They are a record of
individual runs, not a claim.

## 4. Why no scroll threshold can be set from this machine

This is the load-bearing finding, and it is stronger than "this box lacks a GPU".

**Within-build noise exceeds the between-build gap.** n=10 per build, isolated:

| Metric | base → opt | between | spread *inside one build* |
| :--- | --- | --- | --- |
| raster avg | 92.47 → 49.41 ms | 46.6 % | **95.5 %** |
| build avg | 33.09 → 15.13 ms | 54.3 % | **169.5 %** |
| fps | 9.20 → 14.96 | 62.7 % | **116.0 %** |
| worst frame | 674.85 → 405.70 ms | 39.9 % | **95.4 %** |

For every metric the spread within a single build is as large as or larger than
the gap between builds. A measurement whose noise floor exceeds its effect
cannot gate anything.

**Two campaigns disagree by 40 % on identical code** — optimized raster avg was
82.40 ms in the 5-run campaign and 49.41 ms in the 10-run one.

**The distribution is bimodal and the mode flips between campaigns.** Optimized
raster avg, 10 runs, sorted:

```
49.1  49.1  49.2  49.3  49.4  49.5  50.4  54.9  90.6  96.2
```

Eight runs tight at ~49 ms, two at ~91 ms; the 5-run campaign sat entirely in
the slow mode. Whatever selects the mode is not controlled by the harness.

**A second, independent problem:** the scenario is not deterministic.
`DeferredSection` reveals on scroll and each revealed section opens its own
Firestore read; on a fake-auth dashboard those fail and retry nondeterministically,
so runs stream different amounts of content and stop at different depths.

Quoting "raster −8 %" or "raster −46 %" here would both look defensible and be
unsupported. Neither is used.

## 5. Why a GPU would not by itself fix the scroll numbers

Chrome has no GPU driver in this container. Checked four ways, all negative:

| Route to hardware GL | Result |
| :--- | --- |
| `/usr/lib/wsl/lib` (where WSL exposes the driver) | present but **compute-only**: 23 libs (`libcuda`, `libnvcuvid`, `libnvidia-encode`, …), **no** `libEGL_nvidia` / `libGLX_nvidia` / `libnvidia-glcore` / `libnvidia-glvkspirv` |
| `apt` | highest is `libnvidia-gl-580`; host driver is **591.86**, and NVIDIA userspace GL is version-locked to the kernel module, so no match installs |
| privileges | uid 1000, not root |
| Windows mount | no matching `libGLX_nvidia.so.591.86` under `/mnt/c/Windows` or the DriverStore |

Chrome therefore rasterizes WebGL on the CPU via **SwiftShader** (confirmed via
`WEBGL_debug_renderer_info`). `tool/perf/find_gpu_flags.mjs` sweeps 8 backends;
the one working alternative, Mesa llvmpipe, is far worse (raster 411.8 ms avg vs
SwiftShader's 89.7 ms).

A second, structural problem remains even with hardware: the full-screen gradient
compositing sets a floor that no app-side change addresses. That is why halving
the ambient layer's repaint rate bought only single-digit percent.

**What would settle it:** the same two release builds and script on hardware
Chrome, or the in-app Frame Meter on the phone — Creator Studio → System → Frame
meter. `docs/PERF_NOTES.md` already says the phone is the only place "the
dashboard feels heavy" is true. `tool/perf/measure_scroll.mjs` is ready for it.

One further app-side lever was tried and **reverted**: trimming the background
glow box (~46 % of gradient fill). It breaks the bit-identical guarantee pinned
by `everglow_background_test.dart`, and the brief is zero visual degradation.

## 6. Route deferral: 61 %, reported short

| | count |
| :--- | :--- |
| route modules with any deferral | 12 of 19 |
| routes inside deferred modules | 25 of 41 = **61 %** |
| deferred chunks in the release build | **35** |

The 16 undeferred routes are **dashboard-coupled** — the dashboard previews
import the same widgets as cinema, anime, books and jukebox, so deferring them
would move code into a chunk the dashboard downloads immediately anyway. No boot
win for real refactoring cost; `docs/PERF_NOTES.md` records the same blockers.
Excluding those four modules, deferral is 25/29 = **86 %** of genuinely separable
routes. Neither figure reaches the original 90 % target, so it is reported short
rather than rounded up.

## 7. Proof images

| File | What it shows |
| :--- | :--- |
| `shot-baseline-scroll.png` | Real dashboard, full scenario, **before** the pass. The meter in this run read `8 fps · jank 100 % · drop 100 %`, build 35.9 / 211.6, raster 89.7 / 631.5 ms. |
| `shot-ultra-perf-scrolling.png` | The same scenario **after** the pass. This run read `13 fps · jank 100 % · drop 100 %`, build 18.3 / 122.3, raster 60.1 / 391.1 ms. |
| `shot-idle-zero-fps.png` | Real dashboard, scroll top, **after** the pass. The meter reads **30 fps** — the ambience running at its new ~30 fps cap, and the only animated layer at this scroll position. |
| `shot-idle-past-ambience.png` | Real dashboard scrolled past the ambience trigger, loading skeletons visible. Meter reads **29 fps**; that residual is the shared shimmer behind "loading dates… / waking up…", i.e. a loading indicator doing its job. |

### Why there is no "0 fps" screenshot

An earlier revision of this PR led with a `0 fps` screenshot. That image was a
**synthetic harness scene** — a mock page titled "EVERGLOW PERF AUDIT" with three
hard-coded cards, which existed only in a temporary local route and is nowhere in
this repo. It has been deleted. Presenting it as the dashboard's idle result was
wrong, and the real dashboard does not read 0 fps either:

- At scroll top the **ambience is meant to animate** — that is the dusk-bloom
  layer, now capped at ~30 fps rather than 60. 30 fps is the intended result.
- Scrolled past it, **loading skeletons** keep the shared shimmer running, which
  is correct for a loading indicator.

On the fake-auth harness the Firestore reads are denied, so cards sit in loading
or error states indefinitely and a genuinely quiet 0 fps frame is not reachable.
What *is* proven is structural, and deterministically: the ambience repaint rate
is capped (`kAmbienceRepaintInterval`, asserted with an injected clock in
`test/core/perf/repaint_throttle_test.dart`), and the breathing emblem, title
shimmer, pulse heart and off-screen marquee each stop entirely past their scroll
thresholds. A quiet 0 fps frame on a real signed-in dashboard, with real data and
nothing loading on screen, is the thing to check on hardware.

Each scroll shot is one run of the scenario in §3, not a representative sample.
Both scroll captures used a temporary `/temp-preview` route mounting the real
`DashboardScreen` against a **fake** `AuthService` (no Firestore, no real couple
data); that route is **not** committed.

## 8. Reproducing

```
# scroll before/after (needs two release builds; one server at a time)
flutter run -d web-server --release --web-port=8953
node tool/perf/measure_scroll.mjs 8953 optimized --shot out.png

# cold first paint
python3 -m http.server 8980 --directory build/web
node tool/perf/measure_boot.mjs 8980 slow3g

# which GL backend Chrome actually got
node tool/perf/find_gpu_flags.mjs

# why the perf mirror is or is not readable
node tool/perf/diagnose_perf_mirror.mjs 8980
```
