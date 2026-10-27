# Performance improvements: adaptive raster scaling & resilient network caching

## Scope

1. **Slow-Device Acceleration**:
   - **Adaptive Render Scale**: On high-DPR mobile devices (phones/touch screens with DPR >= 2.5) and budget devices (<= 4 cores or <= 4 GB RAM), `applyRenderScaleOverride` automatically caps backbuffer DPR to `2.0` on phones (and `1.75` on budget hardware). On a screen with native DPR 3.0 (e.g. 1290x2796), reducing DPR to 2.0 decreases the WebGL canvas pixel count to 860x1864 (1,603,040 pixels) — a **55.6% arithmetic reduction in pixel compositing** without changing layout geometry.
   - **Extended Ambient Motion Halting**: `AppMotion.reduceAmbientMotion` now automatically halts continuous decoration, shimmer skeletons, ticker loops, and ambient repaints on budget tablets and low-spec computers (`DeviceCapability.isLowEndDevice`), freeing up CPU cycles on 2–4 core hardware.
   - **Tuned Decoded Image Cache**: `PaintingBinding.instance.imageCache` is tightened from 96MB/220 images to 48MB/100 images on low-end hardware, preventing heap memory exhaustion and tab discard loops.
   - **Deferred Media Libraries on Boot with On-Demand Loading**: In `web/index.html`, `__everglowIdleLoadMedia()` skips eager pre-downloading of ~700KB external media libraries (`hls.js`, `model-viewer.min.js`) on slow connections (`saveData` or 2G/3G) and low-end devices (<= 4 cores). When HLS playback (`HlsServerPlayer`) or 3D cat mascot (`CatVisuals`) starts, `__everglowEnsureMediaLibs()` is invoked on-demand with retry handling.

2. **Slow-Internet Acceleration & Resiliency**:
   - **Fast Network Cache (`FastNetworkCache`)**: Process-wide in-memory LRU cache with Stale-While-Revalidate support for TMDB discovery/details, OpenLibrary, Jikan, and MangaKatana. Repeated shelf browsing and tab transitions (Cinema ↔ Anime ↔ Books ↔ Manga) resolve in **0ms** from cache instead of stalling for seconds over high-latency connections. On network dropouts or timeouts, stale cached data is served seamlessly instead of showing blank screens or error banners. Explicit token refreshes (`katana_reader_viewers.dart`) pass `forceRefresh: true` to bypass cached chapter HTML and obtain fresh CDN links.
   - **Adaptive Network Quality (`NetworkQualityService`)**: Detects network effectiveType (`2g`, `3g`, `4g`), `saveData`, and high RTT (>500ms).
   - **Adaptive Image Downscaling (`TmdbImages`)**: On slow connections or low-end devices, `cardFor` resolves to `w185` (saving **78% of image bytes** and 4x decode memory per card) and `posterFor` resolves to `w342` (saving **64% of bytes**). Normalizes both relative paths and full TMDB CDN URLs produced by `mapResultToMediaItem` while keeping non-TMDB hosts untouched.

3. **Status and Limits**:
   - The device acceptance targets in `docs/PERF_NOTES.md` (sustained ≥55 FPS, <5% jank, zero presentation drops on key phone screens) remain open and unverified on real hardware. Arithmetic savings reduce fill-rate and wire load, but are not whole-app presentation FPS proofs.

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
