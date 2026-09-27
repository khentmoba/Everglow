# PR-400 Proof — Ultra-Performance Pass

**Read [BENCHMARKS.md](BENCHMARKS.md) first.** It has the machine-read
before/after, the **three withdrawn sets of performance numbers**, and the
measured reason why this container cannot gate any timing claim at all.

## Headline finding: timing cannot be measured reliably here

I proposed retuning the three raster criteria to relative targets
(raster avg −8 %, worst frame −8 %, fps +20 %) from a 5-run median. **That
proposal is withdrawn.** Re-running at n=10 per build showed the thresholds were
fitted to the median of a noisy sample:

| Metric | base → opt | between | spread *inside* one build |
| :--- | --- | --- | --- |
| raster avg | 92.47 → 49.41 ms | 46.6 % | **95.5 %** |
| build avg | 33.09 → 15.13 ms | 54.3 % | **169.5 %** |
| fps | 9.20 → 14.96 | 62.7 % | **116.0 %** |
| worst frame | 674.85 → 405.70 ms | 39.9 % | **95.4 %** |

Within-build noise is as large as the between-build gap, two independent
campaigns disagree by 40 % on identical code, and the distribution is bimodal
(optimized raster: eight runs at ~49 ms, two at ~91 ms) with the mode flipping
between campaigns. A measurement whose noise floor exceeds its effect cannot
gate anything, so **no timing percentage is claimed**.

## Cold first paint: measured, sub-second in every profile

Unlike the scroll metrics, boot *is* reliably measurable here — the splash is
inline HTML + inline CSS, so it paints before the 6 MB shell is even requested.
`node tool/perf/measure_boot.mjs`, cache cleared, median of 3 runs:

| Network | first paint | Flutter first frame |
| :--- | --- | --- |
| localhost | **32 ms** | 1262 ms |
| Fast 3G | **248 ms** | > 15 s |
| Slow 3G | **728 ms** | > 15 s |

**Sub-second first paint: met everywhere** (272 ms of headroom on Slow 3G).
The *interactive* frame is the slow part, and the SW shell pre-warm is what
targets that on repeat visits.

## Verified, not claimed: route deferral

12 of 19 route modules, **25 of 41 routes = 61 %** (not the 90 % target), 35
deferred chunks. The 16 undeferred routes are dashboard-coupled — cinema, anime,
books and jukebox share widgets with the dashboard previews, so deferring them
moves code into a chunk the dashboard downloads immediately anyway. Excluding
those four: 25/29 = **86 %** of genuinely separable routes. Reported short
rather than rounded up.

## What is verified

Everything structural — not a wall-clock race — reproduces exactly:

| Claim | Evidence |
| :--- | :--- |
| Frame-1 mounts 20 → 3 (**85 % cut**) | `test/core/perf/scroll_jank_benchmark_test.dart` |
| Five ambient layers gate on scroll + lifecycle | ambience repaint capped at ~30 fps (`kAmbienceRepaintInterval`, asserted with an injected clock); emblem / shimmer / heart / marquee stop past their thresholds. A literal 0 fps frame is **not** shown — see the benchmarks doc for why |
| Ambient layer repaint capped at **~30 fps** (was 60) | `test/core/perf/repaint_throttle_test.dart` (deterministic, injected clock) |
| Texture memory **−81.6 %** (208.9 → 38.4 MB / 60 images) | `scroll_jank_benchmark_test.dart`, computed from the shipped `AppNetworkImage.resolveCacheWidth` at the two real call sites |
| Image cache bounded to **220 objects / 96 MB** | `lib/main.dart` |
| **14** screens off `context.watch<AuthService>()` | code |
| Streams **69/69** bounded | `dart tool/ci/check_stream_limits.dart` |
| **35** deferred chunks (was 25) | release build output |
| Cold first paint **32–728 ms** | `tool/perf/measure_boot.mjs` |
| `window.__everglowPerf` populates over CDP | `tool/perf/diagnose_perf_mirror.mjs` |
| CI green | analyze 0 · **1070/1070** tests · **12/12** guards |

## What changed

- **Lazy mounting** — `DeferredSection.preloadMargin` 900 → 280 px.
- **Ambient raster** — dusk-bloom layer repaints at ~30 fps instead of 60 (a
  `RepaintThrottle`, so the cap is testable without racing frame times); its
  24 s cycle moves under a pixel between frames.
- **Heavy blurs** — 3 ambient glow layers retuned 24–32 px → 18 px, one dropped
  at 0.06 alpha, on the Time Together locket, keepsakes cluster, countdown cards.
- **GPU layer isolation** — `RepaintBoundary` on `ShelfPosterCard`,
  `ShelfCard`, `ShelfAtmosphericBackdrop`, `EverglowCard`.
- **Idle freeze** — ambience, emblem, shimmer, heart, marquee gate on scroll
  offset and app lifecycle.
- **Granular rebuilds** — 14 broad `context.watch<AuthService>()` → `context.select`.
- **Sized decodes + bounded cache** — decodes clamped (**−81.6 %** texture
  memory); cache capped at 220 objects / 96 MB.
- **Deferred routes** — 5 more route-only screens: 25 → **35** chunks.
- **Boot** — SW registers on `DOMContentLoaded`, pre-warms the shell on
  `activate` (skipped on save-data/2g).
- **Measurement** — `window.__everglowPerf` now assigns through `globalThis`;
  the old `@JS() external set` threw in strict mode and its own `try/catch`
  swallowed it, so the on-device perf mirror had been silently dead.

## Limitations

- **No scroll-timing claim is made** (§headline). Chrome has no GPU driver here —
  `BENCHMARKS.md` §5 records four dead ends — and frames still cost ~116 ms.
- **Route deferral is 61 %, short of the 90 % target** (86 % of the routes that
  are actually separable). Reported as measured.
- One app-side lever was tried and **reverted**: trimming the background glow
  box (~46 % of gradient fill) breaks the bit-identical guarantee pinned by
  `everglow_background_test.dart`, and the brief is zero visual degradation.
- Screenshots use a temporary `/temp-preview` route mounting the real dashboard
  against a **fake** `AuthService` — no Firestore, no real couple data. Not
  committed.
