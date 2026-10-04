# PR-440 Proof — PWA scroll-jank fix

## Problem

Scrolling Everglow as an installed PWA was laggy. On Flutter Web there is no
retained raster cache and build + raster share one thread, so every perpetual
animation steals frame budget from the scroll itself. The dashboard stacked
all of these at once:

- 4 auto-drifting shelf marquees repainting 60x/sec (each with a `ShaderMask`
  edge fade = a saveLayer per row per tick),
- the full-screen `DashboardAmbience` aurora/petal painter at ~30fps,
- title shimmer (`ShaderMask`), logo halo and heartbeat tickers,
- full-resolution `w500` posters / `w1280` backdrops decoded in wasm on the
  scroll thread for 124–230px cards,
- two full-screen backdrop gradients + double `BoxShadow` layers per card,
- ~20 `DeferredSection` geometry reads firing twice per scroll tick.

## Fix (same pixels, cheaper frames)

- Marquee drift, ambience, emblem, shimmer and pulse **pause while the list
  moves** and resume ~400ms after it settles (new
  `everglow_marquee_scroll_pause_test.dart` pins the marquee half).
- `DeferredSection` scroll checks collapse to one geometry read per frame.
- `ShelfAtmosphericBackdrop` paints bounded glow circles (same pattern as
  `EverglowBackground.glowRect`) instead of two full-screen gradients.
- Grid cards fetch `w342` (was `w500`) and continue-row backdrops `w780`
  (was `w1280`); one cheap shadow on web instead of two blurred layers.

## Proof

Fake demo data only (placeholder tiles, no network, logged-out temp route
reverted before merge). Phone width 430px, debug web-server:

- `shot-shelves-top-440.png` — shelves render exactly as before.
- `shot-shelves-after-drag-440.png` — same after a scroll gesture; nothing
  grey, nothing missing, marquees intact.

Console at capture: clean boot (`Everglow 6.1.0+1 ready`, backend health ok).
The `assets/env.txt` 404 is a debug-server double-prefix quirk, also present
without this change; release/served builds are unaffected.

## Checks run

- `flutter analyze` on all touched files: clean.
- Full `flutter test`: green (includes the new scroll-pause test).
- All `dart tool/ci/check_*.dart` guards: pass.

## Still to verify on device (needs Clair's phone)

Frame-meter numbers before/after: Creator Studio → System → frame meter,
reset, scroll the dashboard. Expect dropped-frame % to fall; raster should
drop hardest (fewer pixels + no competing tickers during the gesture).
