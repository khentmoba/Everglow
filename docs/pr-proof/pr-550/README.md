# Fix PWA zoom-in regression from adaptive device pixel ratio override

## Problem

After PR #548 ("perf(core): accelerate slow devices with adaptive DPR and cache catalogs for slow connections") was merged to `main`, users opening the Everglow PWA on high-DPR mobile devices (such as iPhones with native DPR 3.0) saw the entire application zoomed in / magnified by ~1.7x, causing layout elements (header pills, level bars, quick-access grid, overlay actions) to overflow and clip off the right and bottom edges of the screen.

## Root Cause

PR #548 added automatic DPR capping logic inside `lib/core/perf/render_scale_web.dart`'s `applyRenderScaleOverride`:
```dart
if (DeviceCapability.isLowEndDevice && nativeDpr > 1.75) {
  ui_web.debugOverrideDevicePixelRatio(1.75);
} else if (nativeDpr >= 2.5 && shortest < 600) {
  ui_web.debugOverrideDevicePixelRatio(2.0);
}
```
On iOS Safari, `navigator.hardwareConcurrency` is clamped to 4, which caused `DeviceCapability.isLowEndDevice` to evaluate to true. Because iPhones report a native DPR of 3.0, `applyRenderScaleOverride(null)` unconditionally executed `ui_web.debugOverrideDevicePixelRatio(1.75)`.

In Flutter Web, `debugOverrideDevicePixelRatio` is a testing utility that changes the framework-reported DPR. It does NOT decouple backbuffer resolution from CSS layout; instead, it alters Flutter's logical-to-physical coordinate mapping while the browser window remains at its native DPR 3.0. The mismatch between Flutter's overridden DPR (1.75) and Safari's native DPR (3.0) caused the browser to scale the canvas by `3.0 / 1.75 = 1.714x`, zooming in the entire PWA and clipping UI offscreen.

## Fix

1. In `lib/core/perf/render_scale_web.dart`:
   - Removed the automatic DPR override when `scale` is null.
   - Restored `applyRenderScaleOverride(scale)` to pass `scale` directly to `ui_web.debugOverrideDevicePixelRatio(scale)`. When `scale` is null (the default), passing `null` clears any override and preserves the browser's native DPR.
2. In `lib/core/perf/perf_settings.dart`:
   - Added `_isReset` helper to recognize `device`, `0`, `reset`, `auto`, `off`, `null` as explicit reset commands for `?dpr=`, clearing any saved scale from `SharedPreferences`.
3. In `test/core/perf/perf_settings_test.dart`:
   - Added regression test verifying that `?dpr=device`, `?dpr=0`, and `?dpr=reset` properly clear the saved scale setting.

## Proof shots

- `shot-430.png` — Real release web build running at 430px mobile phone viewport in Agent Mode with HUD collapsed, verifying header, level bar, quick access grid, and overlays fit the full viewport width with zero zoom-in.
- `shot-810.png` — Real release web build running at 810px tablet viewport with HUD collapsed, verifying clean tablet presentation.

## Local verification

- `flutter analyze`: clean (0 issues).
- `flutter test --exclude-tags="golden,network"`: 1,795 passed (0 failures).
- `dart tool/ci/check_*.dart`: all 15 CI regression guards passed.
- `node --test tool/ci/changes.test.mjs tool/ci/pr_contract.test.mjs tool/remove_worktree.test.mjs`: 27 passed.
- `node --test tool/service_worker_test.mjs tool/web_bootstrap_test.mjs`: 28 passed.
- `dart tool/build_web.dart -- --release --no-source-maps --dart-define=AGENT_MODE=true`: clean compilation.
- `node tool/agent_smoke.mjs build/web`: all 64 phone and tablet aliases rendered cleanly.
