# Sitewide performance baseline: Dashboard, Cinema, Anime, Mangacelestia, Books

The dashboard has had its own baseline since PR #588 (`perf-baseline.md`).
This file holds the before and after numbers for the places Clair moves
between most: the dashboard and the four media sections. Each section lists
what changed, what was measured, and what is still not proven.

Use these numbers as the next baseline to hold or beat. Re-run them on the
same machine and flags before comparing.

## How it was measured

- Rig: Windows 11 desktop, headless Chrome with CanvasKit, phone viewport
  `430x932 @3x`, CPU throttled `4x`. Isolated agent demo session, so no login
  and no couple data.
- Builds: `flutter build web --release --source-maps`, the same code as
  `--no-source-maps` plus maps. **Before** is `origin/main` at `acb7927c`
  with only the new route timing mark added, so both builds measure the same
  way. **After** is this branch.
- Navigation: `node tool/perf/probe_navigation.mjs --web-root DIR`. The
  dashboard settles for 6 s, then the probe opens Cinema, Anime,
  Mangacelestia and Books in turn, going back to the dashboard between each.
  Every section is opened twice: first visit, then revisit. Network is shaped
  to the harness `fast3g` preset after boot. The time runs from the route
  request to the end of the first frame that built the real screen; a
  loading spinner does not count. Before: 4 runs. After: 6 runs.
- Scrolling: `node tool/perf/probe_scroll.mjs --web-root DIR --screen NAME`.
  6 swipes down, 8 more down, 8 up. Each phase now resets the meter, so a
  worst frame belongs to its own phase. 2 runs per build, interleaved.
- Desktop headless Chrome is not an iPhone or Clair's tablet. These numbers
  compare two builds on one machine. They are not a phone FPS claim.

Raw JSON for every run: `docs/pr-proof/pr-599/raw/`.

## Navigation: dashboard to section (median ms, lower is better)

| Section | Visit | Before | After | Worst long task before → after |
| --- | --- | ---: | ---: | --- |
| Cinema | first | 276 | 198 | 385 → 238 ms |
| Cinema | revisit | 278 | 230 | 356 → 251 ms |
| Anime | first | 729 | 142 | 238 → 170 ms |
| Anime | revisit | 132 | 89 | 178 → 98 ms |
| Mangacelestia | first | 287 | 130 | 213 → 156 ms |
| Mangacelestia | revisit | 134 | 97 | 183 → 109 ms |
| Books | first | 260 | 66 | 170 → 92 ms |
| Books | revisit | 95 | 56 | 140 → 79 ms |

Per-run values:

| Section | Visit | Before runs | After runs |
| --- | --- | --- | --- |
| Cinema | first | 275, 282, 276, 247 | 198, 193, 195, 198, 224, 196 |
| Cinema | revisit | 267, 287, 278, 268 | 229, 259, 225, 248, 230, 214 |
| Anime | first | 715, 757, 729, 700 | 154, 138, 142, 132, 126, 146 |
| Anime | revisit | 139, 128, 132, 124 | 87, 93, 83, 83, 89, 123 |
| Mangacelestia | first | 284, 328, 287, 270 | 106, 114, 130, 137, 136, 104 |
| Mangacelestia | revisit | 132, 143, 134, 127 | 93, 91, 97, 106, 85, 101 |
| Books | first | 262, 260, 259, 260 | 66, 96, 66, 63, 68, 66 |
| Books | revisit | 95, 104, 87, 88 | 56, 53, 57, 56, 52, 49 |

The server is on the same machine, so the shaped network still downloads
faster than a real phone link. On a real connection the first-visit gap for
Anime, Mangacelestia and Books is likely larger, but that is not measured.

## Scrolling the home screen (2 runs each, per run)

| Section | Build | Worst frame ms | Worst build ms | Worst long task ms | Frames > 200 ms |
| --- | --- | --- | --- | --- | --- |
| Dashboard | before | 144, 147 | 61, 36 | 171, 168 | 0, 0 |
| Dashboard | after | 145, 133 | 43, 55 | 189, 149 | 0, 0 |
| Cinema | before | 218, 216 | 153, 154 | 247, 246 | 1, 1 |
| Cinema | after | 155, 166 | 142, 153 | 155, 167 | 0, 0 |
| Anime | before | 166, 152 | 117, 112 | 199, 172 | 0, 0 |
| Anime | after | 118, 125 | 89, 93 | 137, 147 | 0, 0 |
| Mangacelestia | before | 74, 75 | 42, 47 | 87, 93 | 0, 0 |
| Mangacelestia | after | 81, 98 | 50, 52 | 101, 105 | 0, 0 |
| Books | before | 80, 96 | 63, 86 | 114, 118 | 0, 0 |
| Books | after | 90, 86 | 79, 77 | 97, 116 | 0, 0 |

Mangacelestia's home screen code did not change, so a 3-run recheck was done.
Before: worst frame 107, 75, 89 ms. After: 85, 89, 128 ms. The ranges
overlap, so this is run-to-run noise, not a regression. Dashboard and Books
are also unchanged for scrolling and stay within noise.

## Per section

### Dashboard

- **Changed:** after the dashboard settles, it now downloads the code for
  Anime, Mangacelestia and Books one at a time, after Cinema (which it
  already fetched). It skips this on slow or data-saver connections, the same
  rule Cinema already used.
- **Effect:** the first open of each media section no longer waits on a
  download (see the navigation table). Dashboard scrolling is unchanged.
- **Cost:** about 40-280 KB of code per section before compression, fetched
  in the background on a good connection.

### Cinema

- **Changed:** scrolling past the top used to rebuild the whole Cinema
  screen, every rail included, for a flag only the desktop top bar reads.
  Now only that bar listens. Also benefits from the loading-flash fix below.
- **Effect:** the one Cinema scroll frame over 200 ms in each before run is
  gone. Worst long task during scrolling went from ~246 ms to ~161 ms.
  Opening Cinema went from 276 to 198 ms (first visit).

### Anime

- **Changed:** the home list threw a poster row away once it scrolled a few
  hundred pixels off screen, then rebuilt every card on the way back, and
  the row forgot how far it had been swiped sideways. Loaded rows now stay
  mounted. The spotlight trailer, the airing ticker and loading shimmer
  still unmount off screen, so nothing keeps animating out of sight.
- **Effect:** worst scroll frame 166/152 → 118/125 ms. First open from the
  dashboard 729 → 142 ms, because its code and fonts are now fetched ahead.
  A row Clair swiped sideways keeps its place when she scrolls back
  (`test/features/anime/animex_home_keep_alive_test.dart`, fails without
  the change).

### Mangacelestia

- **Changed:** code fetched ahead from the dashboard; loading-flash fix.
- **Effect:** first open 287 → 130 ms, revisit 134 → 97 ms. Scrolling
  unchanged (noise, see above).

### Books

- **Changed:** code fetched ahead from the dashboard; loading-flash fix.
- **Effect:** first open 260 → 66 ms, revisit 95 → 56 ms. Scrolling
  unchanged.

### Every section: no loading flash on a revisit

Every section page (`DeferredRouteLoader`) used to show its "Loading …"
spinner for one frame on every visit, even when its code was already
loaded, then build the real page on the next frame. A loaded section now
builds on the first frame. `test/core/router/deferred_route_test.dart`
covers first visit, revisit, warmed and failed loads. The old loader fails
the revisit check.

## Tried and dropped

- **Removing resting poster shadows** (Cinema, Anime, shared shelf,
  Mangacelestia, Books cards). Drawing is the largest share of frame time
  (about 34-41% of busy CPU while scrolling), so the blurred shadow under
  every poster was the first suspect. A test build without them showed no
  clear gain in average draw time (Cinema 5.9 → 4.7 ms, Anime 7.9 → 8.7 ms,
  Books 8.6 → 8.7 ms). Not worth the visual change, so the shadows stay.

## Tooling changes

- `tool/perf/probe_scroll.mjs`
  - `--screen dashboard|cinema|anime|manga|books` measures any media home.
  - Long tasks are now counted per phase. Before, every phase counted the
    whole session including the ~1.3 s boot task, so the PR #588 per-phase
    long-task counts include boot.
  - The meter resets per phase.
  - Resolves CPU profile names through source maps, deferred parts included.
  - Adds an "Everglow code on the stack" ranking.
  - Adds `--profiles DIR` to save raw `.cpuprofile` files.
- `tool/perf/probe_navigation.mjs` (new): times dashboard → section → back,
  first visit and revisit.
- `DeferredRouteLoader` records a `route:<label>` mark only while the frame
  meter (`?perf=1`) is on, which is what the navigation probe reads.

## Still not proven

- Real iPhone and tablet timing. Desktop CPU throttling is not calibrated to
  a phone.
- Real network first-open times. The probe server is on the same machine.
- Signed-in sections with real data. Anime loads live public catalogs in
  demo mode, so its rows can differ between runs.
- The original target in `PERF_NOTES.md` (sustained 55+ FPS, first
  interactive under 2.5 s on 3G) stays open.
