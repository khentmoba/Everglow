# pr-573 — cold-load critical path

No visual change: both fixes are network/ordering behaviour, so the rendered
screens are byte-identical and only the time until they appear changes. The
screenshot is here to show the boot still works after `web/index.html` gained
five `modulepreload` links — the gateway door renders normally, no blank
screen, no missing fonts.

## Measured cold, two runs each, fresh Chrome profile, SW bypassed, cache disabled

`tool/perf/probe_cold_load.mjs` records every resource including cross-origin
ones, which the existing boot harness omits.

| | Before | After |
| --- | ---: | ---: |
| Firebase SDK request start | ~1230ms | 39-59ms |
| Firebase SDK per-module duration | 88-243ms | 130-179ms |
| First Flutter frame | 1712ms | 1254 / 1259ms |

## Ruled out by measurement

- CanvasKit variant: the engine picks the full 7.28MB wasm because
  `hasImageCodecs()` is false (`ImageDecoder` undefined), regardless of
  `canvasKitVariant`. Patching to `"auto"` and restoring
  `Intl.v8BreakIterator` still requested the full wasm.
- `onSnapshotsInSync` prewarm: cold 704ms vs prewarm 797ms. No gain.
- "25 listeners x one round trip each": measured false. Six listeners
  attaching together settle within 11ms of each other; Firestore pipelines
  concurrent targets and the first screen costs one round trip.

## Journal cache-first

`test/features/journal/journal_preview_cache_test.dart` runs against a
collection whose `snapshots()` never emits and requires the first event within
2s, so it fails if anything reaches Firestore before the cached frame.
