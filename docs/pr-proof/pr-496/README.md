# Phone guardian / warm dashboard scrolling

Continuation of draft #496 after Khent reported that the bundled-font preview
was much better, but fast scrolling was still slightly laggy after loading.

## Small change

Phones (including landscape) and reduced-ambient-motion users draw a bundled
still of the **same existing cat model**, rather than an embedded 3D viewer.
The still uses the existing default camera, transparent background and shadow.
Tablet/desktop 3D, tap reaction, long-press AI toggle and chat remain.
No render-scale change, new dependency, data/backend or loading-delay change.
The extra asset is 95,960 raw bytes; this is not its wire size.

`guardian-430.png` and `guardian-810.png` show the real release dashboard with
isolated demo fixtures, meter off and collapsed Agent HUD. The phone image
shows the still cat; the tablet image retains the original 3D model.
`guardian-chat-430.png` records the AI sheet opened from the phone cat after
long-press then tap. These images prove appearance/control access, not speed.
Earlier matching font-pass appearance is in
`../dashboard-cold-fonts/dashboard-430.png` at parent commit
`43e9361e79b94ddf1821f35d709bb6bfaa7a6345`.

## Measurements (not a phone verdict)

Windows, Flutter 3.44.4 / Dart 3.12.2, Node 24.21.0, disposable headless Chrome,
release CanvasKit, 430 x 932, DPR 3, 4x CPU throttling, no network throttling.
Two fresh profiles/build; both builds include the font/fling fixes.

Build command:

```sh
flutter build web --release --no-pub --dart-define=AGENT_MODE=true --no-wasm-dry-run --source-maps
```

Serve `build/web` with the existing `serve` helper from `tool/perf/_harness.mjs`;
open `/?agent=dashboard&perf=1` after `prepare`, with CPU rate 4 and
`LONG_TASK_OBSERVER` installed before navigation. Wait for `/dashboard`, first
Flutter frame and the perf mirror, then 2 seconds. Warm with eight 1,400px touch
swipes down at 1,800px/s, wait 2 seconds, do eight up, wait 2 seconds. Start the
CDP CPU profiler. In each of down/up/repeat-down/repeat-up, reset the perf mirror
and long-task array, perform eight 1,400px touch swipes at 6,000px/s (x=215,
y=740 for down, 200 for up), then wait 500ms and flush/read the mirror and
long tasks. Stop profiler after the four phases. No semantics during timing.
Raw rows are `warm-before.json` and `warm-after.json` (not a stamped benchmark).

| Phase | Worst reported frame before, ms | After, ms | Long tasks before | After |
| --- | --- | --- | --- | --- |
| Down | 96.0 / 159.8 | 116.2 / 114.4 | 22 / 20 | 14 / 18 |
| Up | 73.1 / 78.0 | 85.1 / 100.1 | 9 / 12 | 6 / 2 |
| Repeat down | 64.5 / 69.5 | 53.5 / 41.5 | 11 / 14 | 2 / 0 |
| Repeat up | 98.4 / 98.2 | 91.8 / 96.0 | 10 / 10 | 3 / 2 |

The repeated-down pass improved in both runs; repeated-pass long tasks also
fell. **Not every phase improved:** first-up peaks worsened and ~96ms reported
frames remain. Headless CPU throttling is not calibrated phone performance;
Flutter's reported frame span is not presentation FPS. Real phone/Safari/PWA,
populated live cards, uncommon fonts and sustained device targets stay open.

A diagnostic replacement with the old Motchi poster suggested the embedded
viewer was contributing; only the same-cat still ships. Clipping the backdrop
had mixed results and was reverted. No diagnostic defines ship.

## Verification

- Analysis: `flutter analyze` — no issues.
- Tests: `flutter test --exclude-tags="golden,network"` — 1,527 passed.
- New regression: `flutter test test/features/guardian/guardian_phone_visual_test.dart`
  — failed before on the old avatar/viewer, passes after. Loads the actual
  Outfit font; covers phone no-viewer, tap, long-press AI mode, chat input,
  tablet resize restoring 3D and landscape-phone resize removing it.
- Guards: all 15 discovered `dart tool/ci/check_*.dart` — passed.
- Browser: release swipes above; separate 430/810 appearance capture via CDP;
  collapsed HUD, clicked phone cat, long-pressed it and tapped to open AI sheet.
  DOM confirmed no `model-viewer` at phone width and one at tablet width.
- Extra browser-platform widget test: **incomplete**, not a pass. First attempt
  exceeded 120 seconds. One verbose retry exceeded 300 seconds after Chromium
  launched and the suite said "Running test suite", without any test assertion
  result. Native widget suite and release-browser interaction are separate
  evidence, not a substitute for that unfinished runner.
- Manual harness/offline tooling suites: N/A — no harness, worker, loader,
  browser workflow or bench route changes.
- Impeccable detector: one pre-existing bounce-easing warning (unchanged tap
  reaction); no new design finding. No unrelated redesign was made.

## Still-cat asset provenance

`assets/images/guardian_cat.png` is a 320 x 320 transparent PNG rendered locally
from bundled `assets/models/chibi_cat.glb` using existing model-viewer 3.5.0.
Set viewer width/height 320px, DPR 1, shadow-intensity 0.8, shadow-softness 1.0,
no auto-rotation, default camera/orientation and transparent background. After
`loaded` and a settled render, save `toDataURL('image/png')` as decoded base64.
No generated artwork, private photos or external model was introduced.
The image must be recaptured if this model/default camera is intentionally changed.

SHA-256:

- GLB: `cb3f6f7078c6160fe064368bd71a9afa70e71c7273915272a47fe4e49c920f89`
- PNG: `2fbe16ace630b9ea2a21f7b75e0df1c8925747d3e9309d49925a222de5f13bfd`
