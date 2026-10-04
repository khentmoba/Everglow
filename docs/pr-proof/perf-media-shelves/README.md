# Media shelves — proof

## Decode-size sweep: clean

Every `cacheWidth` in cinema / anime / manga / books was checked against the
size it actually displays:

| feature | values found |
| --- | --- |
| cinema | 150, 300, 520, 720, `isDesktop ? 1280 : 780` (backdrop) |
| anime | 150, 320, 400, 560 |
| manga | 400 |
| books | 120, 200, 240, 300, 600, 800 |

Each is proportionate to its slot, and the only large one is a full-bleed
backdrop, where the table in `docs/PERF_NOTES.md` expects 800–1200. **No
violations, so nothing was changed here.**

The two deliberate keeps (full-screen photo viewer, manga reader) are the only
places allowed to decode at natural size, and `check_image_fallback.dart` now
enforces `cacheWidth` **per call site**, so a new uncapped call fails CI.

## Real shelves cannot be measured headlessly

Every real shelf is behind auth and Firestore data. What the bench covers is
their common shape. Unthrottled `min` columns:

| proxy | build ms | raster ms | worst frame ms |
| --- | --- | --- | --- |
| `shelves` scroll (shelf rows) | 0.60 | 0.70 | 2.7 |
| `grid` scroll (browse grid) | 0.40 | 0.79 | 4.0 |

A desktop GPU cannot speak to the ≥55 FPS DPR-3 device bar, so the per-screen
verdict still comes from the phone meter.

## Found: a stale web workaround (not changed)

Nine call sites decode a bundled **512×512** avatar at full size to fill a
**36px** slot on web:

```dart
cacheWidth: kIsWeb ? null : 108,
```

That's ~1MB decoded where 108×108 (0.05MB) would do — a ~20x waste, on the AI
chat surface. The guard came from `d6eb7ea5`, a batch of SkWasm grey-overlay
workarounds that also forced `DeferredSection` always-visible on web — a
workaround since removed. Two things say it is obsolete:

**1. A probe on the current engine renders correctly both ways.** The same
asset side by side with `cacheWidth: 108` and `null`:

![cacheWidth probe](https://raw.githubusercontent.com/khentmoba/Everglow/HEAD/docs/pr-proof/perf-media-shelves/cachewidth-probe.png)

Worth recording how this nearly went wrong: the first capture looked like
`cacheWidth: 108` rendered dimmed, which would have "confirmed" the workaround
was still needed. It had not — the avatar was sitting underneath the
translucent frame-meter HUD, because the shot was taken with `?perf=1`. Re-shot
without the meter, both tiles render identically.

**2. A sibling site already does it unguarded.** `motchi_widgets_extra.dart:32`
uses `cacheWidth: 540` on a 180px slot with no `kIsWeb` guard. If `cacheWidth`
were unsafe on web, that site would already be broken.

### Why it is still not changed

The probe ran on **Chromium**. Clair's phone is **Safari**, where the engine
cannot use the browser's image decoder (`ImageDecoder` is Chromium-only) and
falls back to wasm decoding. If `cacheWidth` renders badly there, the result is
a visible grey avatar in Motchi's chat bubbles on the one device that cannot be
checked from this environment.

A 20x saving on a *static* asset decode is not worth that risk being taken
unattended. Left as a phone A/B for Khent, with the evidence already gathered.

## Checks run

- `flutter analyze`: no issues.
- `flutter test`: 1410 passed.
- All 12 `dart tool/ci/check_*.dart` guards: pass, including the per-call-site
  `cacheWidth` rule.
- Probe build was a throwaway: the bench route was reverted after the capture
  and `flutter analyze` is clean on it.
