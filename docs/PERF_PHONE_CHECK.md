# Phone performance spot-check

This is a diagnostic, **not proof of zero dropped frames or every main-thread
stall**. The original ≥55 FPS / <5% jank / zero presentation drops / ≤200ms block
and <2.5s throttled-3G interactive targets remain unverified.

## Enable the meter

Open the desired screen with `?perf=1` (use `&perf=1` if it already has a query).
For example: `https://everglow-1c6db.web.app/dashboard?perf=1`.
The diagnostic appears bottom-left; drag it out of the way. `?perf=0` turns it
off. Preferences persist, though Safari-tab/installed-PWA storage sharing can
vary: check that the panel actually appears in the PWA rather than assuming it.

![synthetic phone-size meter example](pr-proof/perf-cleanup/shelves-phone.png)

This is a **desktop Chrome phone-size preview with fake content**, not an iPhone
measurement. Your numbers are expected to differ.

- `fps`: recent rate of **reported Flutter frames**, not display-presented FPS.
- `over budget`: session share of reported spans over a reference 16.7ms budget.
  This is not actual display jank or dropped-frame counting.
- `build` / `raster`: recent average / recent worst in a 240-frame window.
- `session`: worst reported full frame span since reset; `f`: uncapped count
  since reset. These no longer forget an early hitch when the window fills.
- DPR: actual layout/render ratio. `?dpr=2` is an optional lower-resolution A/B,
  not the normal-device acceptance test. Invalid/non-finite values are ignored.

## Capture a diagnostic reading

1. Write device, browser/version, installed PWA or tab, refresh rate if known,
   and network/cache state. Use normal device DPR for the main check.
2. Scroll to the top; double-tap the meter to reset the **session**.
3. Scroll down for 10 seconds and back for 10. Note visible stalls and when they
   occur. Capture numbers/video during movement: idle FPS can legitimately be low.
4. Record the session worst after the pass and repeat once. Do not replace a
   failed pass with its best run or interpret low build cost as “nothing froze”.
5. Test idle motion, background→resume, shelf taps and streaming interactions
   separately. Screenshots alone do not prove the interaction worked.

| screen | reported FPS during movement | session over-budget % | session worst ms / frames | visible stalls / response | repeat |
| --- | --- | --- | --- | --- | --- |
| Dashboard | | | | | |
| Cinema grid / shelf | | | | | |
| Anime browse | | | | | |
| Manga / Books library | | | | | |
| Chat history | | | | | |
| Motchi reply streaming | | | | | |
| Idle shelf / background→resume | | | | | |

## What is needed for acceptance

Use a real-device browser performance trace / supported presentation tooling to
measure presented FPS, skipped frames and **all main-thread blocks**. Keep the
full test window and worst case, not a rolling screenshot or median. Compare
visible interaction/video with trace events; the Flutter mirror alone cannot
prove the original device targets. A first-frame event is not proven first
interactive; test that a visible control actually responds.

Cold 3G needs verified aggregate bandwidth/latency, actual encoded transfer
bytes, a fresh cache/profile and clickable UI timing. The previous 138,580ms
number and “boot waits, never janks” conclusion are withdrawn: the driver and
observer had faults. No replacement phone timing has been supplied yet.

A warmed shell may reopen offline if the required resources remain cached. It
is not guaranteed on a first visit, after eviction, or for network-dependent
features. Automated offline proof must disable **both page and service-worker
network**, since page-only emulation can leave the worker online.

Report the screen, full device/network details, readings, what was actually
clicked/scrolled, and whether the stall repeated. See `PERF_NOTES.md` for scope.
