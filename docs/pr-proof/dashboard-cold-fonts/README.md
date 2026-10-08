# Cold dashboard font setup — follow-up to the failed phone check

Khent tested the first #496 preview and reported that it was still laggy,
especially around first load. The original velocity-only fix remains a draft;
this follow-up addresses a separate, measured source of first-use work.

## Diagnosis and change

Cold CPU profiles of both local Flutter 3.44.4 and the deployed 3.47.6 preview
showed repeated CanvasKit `Typeface.MakeTypefaceFromData` work. As cards first
appeared, the browser downloaded six Noto Color Emoji subsets plus symbols/CJK
fallbacks. The engine's font collection registers downloaded fallback fonts and
re-registers its existing fonts. This is a contributor, not proof that fonts
explain every stall on Khent's phone.

A controlled diagnostic blocked the Noto font requests in a disposable browser.
That reduced some pauses but broke missing-character rendering; **it is not
part of the shipped change**. The implementation instead bundles small,
licensed 2D emoji/symbol subsets and adds them to the theme's fallback list.
Existing text families and ordinary fallback for uncovered characters remain.
There is no engine monkeypatch, disabled font fetching, new wait overlay,
resolution reduction, or removed emoji. FontTools/Brotli are development-only
asset-generation tools, not app dependencies.

`docs/fonts/README.md` records provenance, licenses and regeneration. Running
`python tool/subset_ui_fonts.py` twice produced identical SHA-256 hashes:

- Emoji: 154 code points / 317,484 bytes, SHA-256
  `69b210eb194a1387f71ab514ddc3092cf70d93e31af6a4e54db58af436c6af19`.
- Symbols: 8 code points / 6,452 bytes, SHA-256
  `6a0601d60023c7b4d0bb2ca9a2ae99682c22cab51d2a92e1eba08b86d49769a5`.

The added raw font data is 323,936 bytes. This is not its compressed wire size.

## Matching local cold-scroll diagnostics

Three fresh disposable Chrome runs per version, 430 x 932, DPR 2, CPU throttle
4, raw release build, safe Agent Mode. CPU 4 is **not a phone calibration**.
Baseline was commit `805ca2fd`; the final after build differs by font assets,
manifest entries and theme fallback wiring. Same local server / Flutter 3.44.4
engine, same gesture sequence. No network shaping or blocked URLs in these
matching before/after runs. Both include the prior #496 velocity gate.

The exact procedure was:

1. Install a buffered browser long-task observer and first-Flutter-frame marker
   before navigation; start Chrome's CPU profiler.
2. Open `/?agent=dashboard&perf=1`; poll until the dashboard URL, first-frame
   marker and meter exist, then wait one second. Accessibility semantics remain
   **off** during measurement. This readiness condition is not a verified
   first-interactive measurement; raw `headerVisibleMs` is a historical field
   name for that sampled readiness time, not proof of visible/clickable header.
3. Record startup; reset the meter and long-task list.
4. Send eight real CDP touch gestures (x=215, y=740, yDistance=-1400,
   speed=6000), wait one second and record first-down.
5. Repeat eight upward gestures (y=200, yDistance=1400, speed=6000), then
   another down/up cycle, resetting before each phase.
6. Record resource timings and stop the profiler. In run 1, take screenshots
   after each scroll reading: first/warm down show lower Books/Academy/Play
   content and return shows the dashboard header, so real movement occurred.

`before.json` / `after.json` retain all three runs and all five phases. Browser
resources show **8 external Noto font requests before / 1 after** in each run.
The remaining emoji fallback request is not suppressed. Uncommon live text can
still request more fonts. Earlier semantics-on diagnostics were not used here:
activating semantics introduced additional DOM/layout work into the measurement.

Worst reported frame span (ms), three runs:

| Phase | Before | Final after |
| --- | --- | --- |
| Startup | 1121.6, 1174.3, 1012.3 | 904.1, 948.2, 925.9 |
| First down | 850.3, 1135.7, 1069.9 | 329.1, 251.8, 544.9 |
| First up | 1107.3, 195.0, 373.0 | 238.7, 599.1, 268.0 |
| Second down | 1260.3, 65.8, 47.6 | 67.4, 65.5, 94.1 |
| Second up | 63.6, 62.2, 64.0 | 52.0, 50.5, 37.6 |

The worst browser long task during first-down was 851/1158/1071ms before and
330/253/549ms after. Other phases still include stalls; one first-up after run
had a 600ms long task. No budget is relaxed or failure hidden. Results are
local diagnostic evidence, not a statistically established device speed gain,
60 FPS claim, stamped benchmark, or all-site acceptance. Meter FPS is Flutter
frame scheduling, not display presentation FPS. Startup's large frame remains;
actual first-interactive, Safari, native platforms, populated live cards and
uncommon emoji/languages remain unverified.

## Regression and release proof

`test/core/theme/emoji_font_fallback_test.dart` fails with the original theme
wiring (effective fallback list is null), and passes after: plain, token-styled
and inline text inherit both fallbacks while the original primary families stay.
It checks wiring, not rasterized glyph coverage; the release browser checks
show colored hearts/flowers, letterbox text and decorative symbols intact.

The 430 / 810 x 932 screenshots are separate final release runs at DPR 1,
`perf=0`, HUD collapsed, after a slower 1900px swipe and a two-second wait.
They show the real dashboard with synthetic fixtures only, not timing proof.
No real couple photos or credentials were used. The matching timing runs remain
DPR 2 / CPU 4; do not confuse them with these unthrottled appearance captures.

Verification (Windows, Dart 3.12.2, Node 24.21.0):

- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --exclude-tags="golden,network" --no-pub`: passed, 1,526 tests.
- All 15 discovered `dart tool/ci/check_*.dart`: passed.
- `flutter build web --release --no-pub --dart-define=AGENT_MODE=true --no-wasm-dry-run`: passed.
- Impeccable detector on `app_typography.dart`: no findings.
- Asset generation: two matching outputs; pinned source hashes verified.

No backend, worker/loader, performance harness or browser workflow code changed,
so their opt-in tooling suites are not applicable. Draft until the updated
preview is checked on the target phone; the prior phone report is not withdrawn.
