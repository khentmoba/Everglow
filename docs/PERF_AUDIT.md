# Phone optimization audit — PR #494

This audit follows Khent's choice of automatic lighter effects for phones.
The policy uses the viewport's shortest side below 600 logical pixels, also
covering landscape phones, and respects reduced motion. Tablets retain their
ambient motion. Completion means correcting the identified avoidable work and
verifying the affected behavior; it does not mean proving the theoretical
maximum speed or replacing the real-device acceptance targets in PERF_NOTES.md.

| Area | Evidence and action | Remaining limit |
| --- | --- | --- |
| Dashboard rendering | Still phone backdrop/header, bounded radial glows, deferred sections with immediate resume recovery. Existing pixel test compares bounded and full-screen glows. | Full-page headless samples did not establish a frame-rate gain. |
| Continuous decoration | Stop phone loops in skeletons, emblems, presence dots, Garden, Starlight, door breathing/petals, anime badges, Motchi indicators, countdown separators, music cards and leaderboard badges. Keep finite action feedback and actual data updates. | Scheduling tests prove stopped loops, not battery or heat savings. |
| Growing collections | Shared phone shelves and anime tickers build on demand; saved anime grids use lazy slivers. Manga Currently Reading now uses ListView.builder and computes its merged list once per build. | Synthetic shared shelf/grid counts are measured; no populated authenticated manga timing was recorded. |
| Existing lazy lists | Inspected Books library/list views, Gallery main/search grids and Sanctuary chat's ListView.builder. Chat subscribes to the latest 50 messages; Gallery main stream caps at 40 and dashboard preview at 6. | Source inspection and route smoke checks do not cover every saved-data interaction. |
| Images | Known-size bundled assets use existing decode bounds and rollback. Gallery already stores 400px thumbnails and a max-1600px viewer image. TMDB helpers already request bounded CDN variants. | Keep remote web decode behavior; high-DPR Safari image quality and whole-app memory remain device checks. |
| Startup | Providers already construct unused services lazily. Secondary routes already defer many features. A desktop trace found about 2.09s in main.dart.js evaluation at 4× CPU throttling; the follow-up defers Dashboard/Letterbox, Cinema/player, Anime, Manga home, Jukebox and Books entry/detail/reader/categories using the existing route loader. Initial script is 29.84% smaller (29.43% gzip); matching source hashes and diagnostic reports are recorded in the proof directory. | Both desktop benchmark runs fail the strict 200ms full-session long-task budget; mobile first-interactive remains unverified. |
| Guardian | Cat initialization is delayed 1.5s, dashboard autoRotate is false. The bundled 283,308-byte GLB has one mesh and zero animation tracks; no speculative model replacement. | Platform-view GPU behavior still needs Safari profiling. |
| Background work | Partner freshness/reveal timers pause while inactive. Presence cancels its offline heartbeat and resumes the existing session; its regression fails against the previous service. Jukebox pauses Last.fm status/statistics polling and reconnect timers while hidden, refreshes on return, and prevents overlapping status polls. | OS suspension and rapid real-device background/foreground transitions need device testing. |
| Cinema and music | Stop decorative player/status/loader and Jukebox loops on phones. Existing playback progress writer coalesces cloud writes over 15s, flushes pending progress, and serializes saves. Up Next's finite countdown and media synchronization are retained. | Authenticated playback, third-party iframe performance and sustained battery use are unverified. |
| Cleanup and safety | Reviewed cancellation/disposal on changed timers, controllers, streams and platform views. No backend, database rule, migration, rendering-resolution change or new dependency. | Repo guards are targeted static checks, not a proof that every runtime path is perfect. |

Regression evidence is in `test/remaining_phone_motion_test.dart`,
`test/core/services/presence_heartbeat_test.dart`,
`test/features/anime/animex_motchi_sidebar_test.dart`, and the earlier tests
listed in `docs/pr-proof/pr-494/README.md`.

Local analysis, 1,516 tests, all 15 guards, stamped release build and 64 agent
route/viewport checks pass. Quality run 37701615817 succeeds for b3cdff55,
including browser-only memory/bridge/streaming tests and preview publication.
The hosted CI merge aa4b4d6 is inspected with synthetic demo data. Full-page
phone screenshots and the first failed capture/readiness attempt are retained
in docs/pr-proof/pr-494/. T3's automation host became explicitly unavailable;
its suggested disposable headless fallback used the repository harness.

Real iPhone 11 Safari/PWA presentation FPS, frame drops, battery, heat, and
sustained playback remain open. A 30-to-60 FPS improvement or whole-app percent
gain cannot be inferred from stopped animation controllers or fewer mounted
cards.
