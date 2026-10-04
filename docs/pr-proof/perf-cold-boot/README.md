# Cold-boot measurement — proof

## Headline: the goal's 2.5s bar is missed on slow3g, and it is arithmetic

`node tool/perf/measure_boot.mjs`, 3 runs each, median, link shaped in the
static server:

| case | first interactive | first paint | worst long task | vs 2.5s bar |
| --- | --- | --- | --- | --- |
| fast link, first visit | **1531ms** | 216ms | 0ms | **met** |
| slow3g (400kbit = 50KB/s), first visit | **138,580ms** | 212ms | 0ms | missed ~55x |
| slow3g, repeat visit (SW warm) | 134,033ms | **28ms** | 0ms | missed |

Run-to-run spread on the slow3g cold case: 138,563 / 138,580 / 138,630ms —
**0.05%**, so the number is reproducible rather than a lucky sample.

**Why it can't be closed in code.** First frame within 2.5s over a 50KB/s link
needs a critical path of at most ~125KB. It is about 13MB (`main.dart.js` is
6.5MB, `canvaskit.wasm` a further ~6.9MB). That is a ~100x gap, so it is not a
tidy-up opportunity — it is either a much smaller app or a faster link. Recorded
as unmet rather than dressed up.

Two reasons this is a worst case rather than a forecast:

- **No CDN cache in the rig.** Production fetches CanvasKit from the gstatic
  CDN (`tool/build_web.dart` pins the engine revision), shared across every
  Flutter site and very likely already in a phone's HTTP cache. Here every byte
  comes from one deliberately slow origin.
- **slow3g is 50KB/s, not 400KB/s.** That is DevTools' own definition; the name
  misleads.

## What is actually protecting Clair

- **First paint is fast in every case** — 216ms cold on the slow link, **28ms**
  on a repeat visit. The splash in `web/index.html` is inline HTML + inline CSS
  and needs zero downloaded bytes, so a bad connection shows Everglow almost
  immediately with the app loading behind it instead of a white screen.
- **No long main-thread task anywhere**: worst long task `0ms` across all nine
  runs against a 500ms bar. Boot waits; it does not jank. The `noFreezeOver500ms`
  half of this task's contract **passes**.

## One real finding: repeat visits re-download the shell

Repeat shows FCP 28ms but first interactive 134s. `tool/generate_sw.dart:273`
explains it — the SW is **network-first** for the versioned `main.dart.js`, so it
revalidates over the network every visit and only falls back to cache when
offline. On a fast link that costs nothing; at 50KB/s it costs the full 134s
despite the bytes already being cached.

Cache-first for the versioned shell would fix it, and `?v=BUILD` plus the
existing build-stamp logic already keep deploys propagating. **Not changed
here** — it alters deploy semantics, which is Khent's call, not something to
change unattended while he is asleep. It is recorded as the single
highest-value cold-boot change available.

## Three harness bugs that had to be fixed before any number was trustworthy

Each one changed the conclusion, which is why they are listed rather than
buried:

1. **Hardcoded `/usr/local/bin/google-chrome`** — the script had only ever run on
   the author's Linux box. Chrome is now located per platform, and both perf
   tools share one launcher (`tool/perf/_harness.mjs`); two copies is how this
   bug survived.
2. **`Network.emulateNetworkConditions` is silently ignored by headless
   Chrome.** Asked for 400KB/s, it delivered 6.77MB in 67ms (~98MB/s):

   ```
   throttled 400KB/s: 6773304 bytes in 67 ms = 98725 KB/s
   ```

   So every earlier "slow3g" number measured an *unthrottled* download and
   reported it as slow. The link is now shaped in the server, verified to
   deliver 50KB/s for a 400kbit request.
3. **The server sent `Cache-Control: no-store` and the cold run blocked
   `sw.js`**, so the service worker could never cache anything and the "repeat
   visit" was really two cold downloads (268s). Coldness now comes from the
   fresh profile alone, and the warm-up leg runs unshaped — the SW's precache is
   itself ~13MB and would still be downloading when the measured leg began.

## Checks run

- `flutter analyze`: no issues.
- `flutter test`: 1410 passed.
- All 12 `dart tool/ci/check_*.dart` guards: pass.
- `node tool/perf/measure_boot.mjs --runs 3 --profile slow3g` — reports
  `firstInteractiveUnder2500ms: NO`, `noLongTaskOver500ms: YES`, median recorded.
- `node tool/perf/measure_boot.mjs --runs 3 --profile none` — both `YES`.
- `node tool/perf/bench.mjs --runs 1` re-run after the `_harness.mjs` extraction
  to confirm the refactor did not disturb the scroll numbers (build 0.64ms,
  raster 0.74ms, unchanged).

No screenshot: this pass measures wall-clock timings on a local server, and there
is no screen to photograph. The numbers above are the evidence.