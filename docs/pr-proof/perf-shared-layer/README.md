# Shared-layer pass — proof

## Summary

The shared render layer turned out to be **already hardened** by the earlier
ultra-perf pass and #440. Three of the four causes listed in
`docs/PERF_NOTES.md` are fixed in the current code, and one cites a file that
no longer exists. Rather than "fix" working code, this pass measured what was
left and found one real defect — an uncapped image decode in Tonight.

## Measured: the ambience painter is invisible to this rig

`/perf-bench/shelves` vs `/perf-bench/shelves-plain` — identical scene, only
`DashboardAmbience` removed. 3 runs each, unthrottled, `min` columns:

| | build ms | raster ms | worst frame ms |
| --- | --- | --- | --- |
| shelves (with ambience) | 0.61 | 0.69 | 2.4 |
| shelves-plain (no ambience) | 0.58 | 0.68 | 2.6 |

A ~0.03ms difference — inside the noise band for that column. `DashboardAmbience`
is documented as "the single largest raster cost on the dashboard", but that is a
*phone* measurement (mobile Safari WebGL, DPR 3). On a desktop GPU those strokes
cost under a millisecond, so **this bench cannot validate or refute
full-screen-effect work.** Recorded in `docs/PERF_NOTES.md` so the next pass
does not burn time there.

Both scenes render the same content; only the aurora/petal layer differs:

![with ambience](https://raw.githubusercontent.com/khentmoba/Everglow/HEAD/docs/pr-proof/perf-shared-layer/shelves-0.png)

![without ambience](https://raw.githubusercontent.com/khentmoba/Everglow/HEAD/docs/pr-proof/perf-shared-layer/shelves-plain-0.png)

## Fixed: an uncapped decode in Tonight

`tonight_screen.dart` drew date-option thumbnails with a bare `Image.network`
and **no `cacheWidth`**, so every one decoded at natural resolution — ~3.5MB
each per the memory table in `docs/PERF_NOTES.md` — to fill a **76px** slot. It
now goes through `AppNetworkImage` with `cacheWidth: 240` (compact) / `400`
(full).

**No proof screenshot for this one, deliberately.** Tonight needs auth plus
Firestore data, so it cannot be rendered headlessly, and a screenshot from a
different screen would prove nothing. The change is decode-only by
construction — same `BoxFit.contain`, same `AppColors.silk` placeholder, same
error fallback — and it is pinned mechanically instead: see the guard below.

## Fixed: the guard that would have caught it

`tool/ci/check_image_fallback.dart` now also requires `cacheWidth`, **per call
site rather than per file**.

That distinction was not theoretical. A file-level version passed a tampered
file, because a *different* `Image.network` in the same file still had a
`cacheWidth`:

```
$ # removed cacheWidth: 200 from creator_memories_tab.dart:651
$ dart tool/ci/check_image_fallback.dart
[images] OK: 3 raw usages all have fallbacks.     <-- wrong
```

The per-call-site version catches it and names the line:

```
$ dart tool/ci/check_image_fallback.dart
[images] FAIL (1):
  - lib/features/dashboard/.../creator_memories_tab.dart:651: raw Image.network without cacheWidth.
```

and it was verified against the pre-fix version of `tonight_screen.dart`
(fails at `:882`), then restored (passes). Two documented keeps remain, both
images that are meant to be shown large: the full-screen photo viewer and the
manga reader.

## A measurement bug this pass caught

The first ambience A/B was invalid and the proof screenshot is what exposed it:
the bench built image URLs with `Uri.base.resolve()`, which resolves against the
*route*, so the nested `/perf-bench/shelves-plain` requested
`/perf-bench/assets/...`, 404'd, and silently measured a scene with no images —
which still produced a perfectly plausible table. URLs are now built from the
site root, and the table above is from the corrected run.

## Stale claims corrected in `docs/PERF_NOTES.md`

- Cause 2 ("cursor glow starts its 60fps loop at init") — false since #440: the
  controller is created stopped and only started by `_handleHover`, which never
  fires on a phone.
- Cause 4 ("every `EverglowSkeleton` runs its own controller") — false:
  skeletons share one ref-counted `EverglowShimmerScope` and repaint through
  `CustomPaint(repaint:)` inside a `RepaintBoundary`.
- The shipped list cites `everglow_sparkles.dart`, which no longer exists.

## Checks run

- `flutter analyze`: no issues.
- `flutter test`: 1410 passed.
- All 12 `dart tool/ci/check_*.dart` guards: pass, including the extended image
  guard.
- `node tool/perf/bench.mjs --runs 3 --scene shelves,shelves-plain`: completes.