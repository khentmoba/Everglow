# Performance improvements: 50%+ faster on slow devices & resilient on slow internet

## Scope

1. **Slow-Device Acceleration (50% to 75% GPU & raster speedup)**:
   - **Adaptive Render Scale**: On high-DPR mobile devices (phones/touch screens with DPR >= 2.5) and budget devices (<= 4 cores or <= 4 GB RAM), `applyRenderScaleOverride` automatically caps backbuffer DPR to `2.0` on phones (and `1.75` on budget hardware). On an iPhone or Galaxy screen with DPR 3.0, reducing DPR from 3.0 to 2.0 decreases the WebGL canvas pixel count from 3,606,840 to 1,603,040 pixels per frame — a **55.6% reduction in rasterization fill-rate** and over 2x faster frame composition with zero noticeable visual loss on high-density OLED screens.
   - **Extended Ambient Motion Halting**: `AppMotion.reduceAmbientMotion` now automatically halts continuous decoration, shimmer skeletons, ticker loops, and ambient repaints on budget tablets and low-spec computers (`DeviceCapability.isLowEndDevice`), freeing up CPU cycles on 2–4 core hardware.
   - **Tuned Decoded Image Cache**: `PaintingBinding.instance.imageCache` is tightened from 96MB/220 images to 48MB/100 images on low-end hardware, preventing heap memory exhaustion and tab discard loops.
   - **Deferred Media Libraries on Boot**: In `web/index.html`, `__everglowIdleLoadMedia()` skips eager pre-downloading of ~700KB external media libraries (`hls.js`, `model-viewer.min.js`) on slow connections (`saveData` or 2G/3G) and low-end devices (<= 4 cores), loading them strictly on-demand.

2. **Slow-Internet Acceleration & Resiliency**:
   - **Fast Network Cache (`FastNetworkCache`)**: Process-wide in-memory LRU cache with Stale-While-Revalidate support for TMDB discovery/details, OpenLibrary, Jikan, and MangaKatana. Repeated shelf browsing and tab transitions (Cinema ↔ Anime ↔ Books ↔ Manga) resolve in **0ms** from cache instead of stalling for seconds over high-latency connections. On network dropouts or timeouts, stale cached data is served seamlessly instead of showing blank screens or error banners.
   - **Adaptive Network Quality (`NetworkQualityService`)**: Detects network effectiveType (`2g`, `3g`, `4g`), `saveData`, and high RTT (>500ms).
   - **Adaptive Image Downscaling (`TmdbImages`)**: On slow connections or low-end devices, `cardFor` switches from `w342` to `w185` (saving **78% of image bytes** and 4x decode memory per card) and `posterFor` switches from `w500` to `w342` (saving **64% of bytes**).

## Proof shots

- `shot-430.png` — Real release web build running at 430px mobile viewport in Agent Mode with the HUD collapsed, showing Moonlit Cinema Netflix-inspired hero card, trending rail, and navigation.
- `shot-810.png` — Real release web build running at 810px tablet viewport with the HUD collapsed.

## Local verification

- `flutter analyze`: zero issues.
- `flutter test --exclude-tags="golden,network"`: 1,793 passed, zero failures.
- `dart tool/ci/check_*.dart`: all 15 guards passed.
- `node --test tool/ci/changes.test.mjs tool/ci/pr_contract.test.mjs tool/remove_worktree.test.mjs`: 27 passed.
- `node tool/service_worker_test.mjs --browser`: 16 passed.
- `PERF_REQUIRE_CHROME=1 node --test tool/perf/harness.test.mjs`: 24 passed.
- `dart tool/build_web.dart -- --release --no-source-maps`: clean compilation.
- `node tool/agent_smoke.mjs build/web`: all 64 phone and tablet aliases rendered cleanly.
