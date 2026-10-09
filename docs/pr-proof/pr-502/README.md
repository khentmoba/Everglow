# Candidate for both installed-app edges

This replaces the opaque-status-bar fallback originally proposed in #502.
The goal is artwork behind the status bar AND no separate bottom strip.
Khent tested commit `2b24ad1` through a newly installed preview Home Screen
icon and reports that neither edge bleeds. The candidate has failed the
requested device outcome. It must not be treated as a solved iPhone issue.
Khent's Cinema screenshot confirms real artwork behind the system icons,
while a purple strip remains below the black navigation. Private device
screenshots are not copied into this public repository.

The candidate retains `black-translucent` and installed `viewport-fit=cover`.
It explicitly sizes `html`, `body`, and the installed Flutter host to `100vh`,
instead of anchoring their bottom to potentially shortened fixed bounds.
The installed class is selected before Flutter starts. Ordinary browser tabs
keep contained fitting and their existing fixed bounds. No iOS version or
device-height guesses, dependencies, or per-screen padding are introduced.

Flutter's custom-element dimensions provider reads the host's client height.
Previous full-screen fixes sized the document, but left that host on fixed
`inset: 0` bounds. This is a testable sizing hypothesis, not an established
diagnosis of the physical Safari bug.

A similar root-sizing report is described in
[OpenChamber #2287](https://github.com/openchamber/openchamber/issues/2287).
[WebKit #301994](https://bugs.webkit.org/show_bug.cgi?id=301994) also includes
reports of system-owned gaps. The current evidence does not establish which
mechanism applies to this iPhone. A real device check remains necessary.

## Controlled before/after

Actual release app, synthetic Agent Mode data, T3 Chromium, 430 x 932 CSS pixels.
Both temporary untracked entry pages set `navigator.standalone=true` before
startup and simulate safe-area readings of 59px top and 34px bottom.

For BOTH before and after, an injected style deliberately creates a shortened
fixed containing block: `html { transform:translateZ(0); height:calc(100vh - 59px); }`.
This models the sizing failure in Chromium; it is not a Safari reproduction.

- Before uses #499's HTML (`33f560ee`): root, body, host, and Flutter view are
  873px tall in the 932px window. `dashboard-before.png` shows the 59px strip.
- After uses this candidate's HTML: all four measure 932px in the same test.
  The installed sizing rule takes precedence and the strip disappears in
  `dashboard-phone.png`.
- HUDs are collapsed through their actual control. PNGs are resized to CSS
  resolution and compressed without changing their content.

## Other local checks

- Cinema, 430 x 932: host and Flutter view fill the window. Back control is
  at y=69..117, clear of the simulated top inset. Navigation controls occupy
  y=836..898; their background continues through the bottom 34px to y=932.
- Cinema resized to 932 x 430: host and view become 932 x 430.
- Dashboard tablet, 820 x 1180: host and view become 820 x 1180.
- Ordinary browser launch: no installed class, viewport remains `contain`,
  and the Flutter view fills 430 x 932.
- Bucket List: opened New dream, focused the real Flutter input, and simulated
  a 300px visual-viewport keyboard overlap. The host stays 932px and the form's
  visible group shrinks from 720px to 519px. Restoring the viewport and blurring
  returns the group to 720px. No dream was saved. This proves synthetic inset
  propagation/dismissal, not a real iOS keyboard or submission.

## Verification and limits

Windows; Flutter 3.44.4, Dart 3.12.2, Node 24.21.0.

- `flutter analyze --no-pub`: zero issues.
- `flutter test --exclude-tags="golden,network" --no-pub --reporter=expanded`:
  1,530 passed with TEMP/TMP inside ignored `build/verification-temp`.
- Every listed `dart tool/ci/check_*.dart`: all 15 passed.
- `node --test tool/web_bootstrap_test.mjs`: 8 passed, including early installed
  class selection and shared document/host sizing configuration.
- `node tool/service_worker_test.mjs --browser`: 14 passed, zero skipped,
  including real disposable Chrome offline boot.
- `flutter build web --release --dart-define=AGENT_MODE=true --no-pub`: passed.

The preview still logs the existing early `didChangeViewFocus` RenderBox error,
missing local environment-file 404, and denied fake Agent Mode XP/presence
requests. No real environment file was read or copied; no clean-console claim.

## Device investigation

The demo HUD now has a **Screen edges** button. It captures the screen and
window dimensions, visual viewport, actual document/body/host/Flutter-view
bounds, safe insets, installed class, and viewport/status-bar metadata. The
report stays on the device, reads no user content, and makes no requests.
Close and reopen it after rotation to capture fresh measurements.

Diagnostics update checks: analysis has zero issues; all 1,530 VM/widget tests,
all 15 Dart guards, and all 8 bootstrap tests passed again. The local
`flutter test --platform chrome test/core/system/web_standalone_browser_test.dart
--no-pub --reporter=expanded` run launched Chrome but stalled at suite loading
and was stopped. No browser test passed in that run; CI must verify the added
short-host measurement regression.

The updated release build passed. In the actual release app at 430 x 932 in
T3 Chromium, clicked **Screen edges** and verified all displayed bounds against
the page; `screen-measurement.png` shows the complete panel with synthetic
Dashboard data. Clicked **Close measurement**, temporarily set the host to
top=10px/height=500px in the browser, then reopened the panel: it correctly
reported `#eg-app: y=10..510, h=500`. This proves fresh measurement and the
button interaction in an ordinary Chromium tab; it does not prove physical
Safari behavior or substitute for the interrupted browser test suite.

Hosted verification of `9a55896` found that the report was unreachable: CI
builds without `AGENT_MODE=true`, and the HUD had an extra local/compiled-only
gate even when an explicit demo session was active. The follow-up removes
that extra gate. The HUD remains hidden unless Agent Mode is active, as
requested via `?agent=...` or its saved demo session. Ordinary sessions still
hide every demo control. Verification must use a release build WITHOUT the
compile flag to match the preview.

CI also caught a browser-test assertion expecting `59.0 / 34.0`; browser Dart
reports the correct safe insets as `59 / 34`. The assertion is corrected,
with both actual host-bounds assertions retained.

Follow-up verification: `flutter analyze --no-pub` has zero issues; all 1,531
VM/widget tests, all 15 listed Dart guards, and all 8 bootstrap tests passed.
`flutter build web --release --no-pub` passed WITHOUT `AGENT_MODE=true`.
Served that build through a disposable Chrome hostname mapping
(`preview-check.test` to the local server), so the old localhost exception
cannot make the toolbar appear. Verified that an ordinary launch renders
without Screen edges, while `?agent=dashboard` shows the toolbar and its full
report. `screen-measurement.png` is now captured from that release-mode check
at 430 x 932, with fake data. Hosted preview verification awaits this commit's
deployment; the corrected browser regression still awaits CI.

This is diagnostic evidence, not another proposed layout fix. A screenshot
of the report together with both system edges will distinguish a shortened
Flutter host from a shortened browser viewport and identify whether the
installed metadata is active. Normal user UI does not show this control.

Keep the PR draft pending device measurements and a verified correction.
Chromium cannot prove iOS system-bar behavior. Both-edge bleed, physical
keyboard, and rotation remain unresolved on the reported iPhone.

## Installation correction after the missing-toolbar screenshot

The private iPhone screenshot has no demo HUD and shows normal account progress.
It also shows a distinct bottom strip; the background appears behind the status
icons. This does not establish which commit or browser bounds the icon used.
Do not copy the screenshot or account progress into this public repository.

The normal manifest has `start_url: "."`, which drops demo query parameters on
installed launch. Saved Safari demo preferences were an unreliable prerequisite
for reaching the measurement panel. An explicit `screencheck=1` link now selects
`manifest_screen.json` and the name **Everglow screen test**. That separate
manifest's launch URL always includes `agent=dashboard&screencheck=1`, so it
activates demo mode without transferred Safari preferences. Normal installs
retain the original manifest and start URL. Both manifests bypass worker caching
and revalidate hosting responses.

The bootstrap regression checks ordinary/agent-only/screen-test selection and
the demo launch parameters. Nine bootstrap tests, all 1,531 VM/widget tests,
and all 14 worker tests (zero skipped, real Chrome offline boot included)
passed. Analysis has zero issues; all 15 listed Dart guards passed.
`flutter build web --release --no-pub` passed. In T3 Chromium at 430 x 932,
cleared only the isolated local demo browser's state, then opened the screen-test
launch URL. Verified the selected manifest, its explicit demo launch URL, and
the install title **Everglow screen test**; the demo Dashboard and Screen edges
panel appeared without prior preferences. The refreshed proof image is from
that launch. This tests manifest selection and fresh-session launch, not iOS
installation. A physical iPhone launch is still required to verify the system
areas and the new installation flow.

## Screen-test URL lost during navigation

Khent reports that the newly added icon still opens without the diagnostic HUD.
The screenshot still shows a separate bottom strip. This is not a successful
installation test, and the private screenshot is not published.

The hosted root launch redirected to `/dashboard`, dropping both `agent` and
`screencheck` from the address. The manifest retained a demo start URL, but that
alone did not deliver the requested device outcome. The router now preserves
the launch query on screen-test gateway jumps; ordinary jumps are unchanged.
This repairs a demonstrated URL-loss bug, not a proven diagnosis of iOS's
installation behavior or the bottom strip.

Windows checks: analysis zero issues, 1,533 app tests passed, all 15 listed
Dart guards passed, nine bootstrap tests passed, and the release build passed
without the Agent Mode compile flag. The first combined verification command
hit its five-minute timeout during the build; a separate build completed with
exit zero. Two new tests cover retaining test parameters and ordinary jumps.

In the local release app, root launch became
`/dashboard?agent=dashboard&screencheck=1`. Opened that final URL in a separate
fresh origin, verified the screen-test manifest remained selected, and clicked
Screen edges: the complete measurement panel appeared. The inspected
`screen-query-reload.png` records this desktop Chromium check (1280x800), using
fake data; the earlier phone proof remains above. This does not prove iPhone
installation. The PR stays draft pending a physical measurement and bottom-edge
correction.
