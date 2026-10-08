# Dashboard scroll fixes

Only synthetic Agent Mode fixtures were used. The screenshots show the actual
release dashboard at 430 x 932 and 810 x 932, with the Agent HUD collapsed.
They are desktop Chrome captures, not phone/Safari recordings.

## Before / after regression evidence

The first three new tests in `test/deferred_section_test.dart` failed against
the merged #494 code before the production changes:

- A pending section mounted after a jump past it. It now stays unmounted and
  loads when the user returns.
- Ten scroll steps repainted unchanged artwork ten times. The section's
  repaint boundary now reuses that artwork with zero additional paints.
- A phone section still waited 700ms. Its delay is now bounded to 120ms.

Two further checks verify phone preloading 350px below the viewport and a
stacked pair reserving both card heights plus its 12px gap. Placeholders remain
estimates: live content and text size can still change the finished height.
Far-away sections remain deferred; lifecycle recovery and programmatic jumps
retain their regression coverage.

## Verification

- Analysis: `flutter analyze --no-pub` passed, no issues.
- Tests: `flutter test --exclude-tags="golden,network" --no-pub` passed,
  1,522 tests. The focused deferred-section and pair-layout run passed 15 tests.
- Guards: all 15 discovered `tool/ci/check_*.dart` commands passed.
- Build: `flutter build web --release --no-pub --dart-define=AGENT_MODE=true --no-wasm-dry-run` passed.
- Browser: disposable Chrome, 430/810px widths, DPR 1. At each width, 24 real
  wheel events moved down the dashboard; the lower Books/Academy/Play content
  appeared. Another 24 upward wheel events returned to the header at offset 0.
  Phone reached 9,960px; tablet reached 7,200px. The cards were inspected after
  returning and scrolling down again.

T3 Preview initially rendered the page but later returned an explicit
automation-host-unavailable error permitting a shell browser fallback. The
fallback used the existing `tool/perf/_harness.mjs` launcher/server/CDP client
and a disposable profile. The first fallback attempt completed phone scroll
assertions but failed screenshot saving due to reading the CDP response at the
wrong level; correcting the diagnostic script produced the complete passing run.

Environment: Windows, Flutter 3.44.4 / Dart 3.12.2, Node 24.21.0.
No backend, worker, performance harness, or browser workflow changes; their
opt-in tooling suites are not required for this app-only change.

## Performance limits

`browser-results.json` records the observed offsets, lower-page demo text and
the existing meter's diagnostic readings. This is one unthrottled desktop run
of a raw release build, not a stamped performance benchmark or an A/B timing
comparison. Its rolling FPS is not display presentation FPS.

The measured scroll interval still included worst reported frames of 167.5ms
on the phone-sized viewport and 209.8ms on the tablet-sized viewport. These
changes do not claim all stalls are eliminated, a percentage speed gain, or
60 FPS on a real phone. Actual phone/Safari scrolling with populated live cards
remains unverified and needs Khent's device check.

No render resolution, image quality, stored data or database rules changed.
