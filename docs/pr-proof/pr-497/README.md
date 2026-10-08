# Installed-app screen edges

These screenshots show the actual release build in T3's Chromium preview,
using isolated Agent Mode fixtures. No private couple records or photos were
used. Phone viewport: 430 x 932; tablet viewport: 820 x 1180.

For this layout check only, a temporary, untracked HTML entry in build/web
set navigator.standalone to true and supplied synthetic CSS safe-area readings
of 59px at the top and 34px at the bottom. It then restored the normal route
before Flutter started. This exercises the installed-app render host and the
shared MediaQuery bridge. It does not emulate Safari or draw iOS status icons.

- cinema-phone.png: the canvas fills 430 x 932; navigation controls occupy
  y=836..898, and their black background continues to y=932.
- dashboard-phone.png: the background fills both system areas while the
  action buttons clear the synthetic status bar.
- dashboard-tablet.png: the same shared handling at tablet width.

The reported gap could not be reproduced on a physical iPhone here. The
suspected cause is Flutter's iOS full-page document measurement, which is
replaced with its supported host-element measurement for installed apps.
Physical Safari Add to Home Screen verification remains required.

The dedicated Flutter browser test suite stalled at loading with both Chrome
and Chrome Headless Shell 154, including a WebAssembly retry. Diagnostics
confirmed two Windows Flutter 3.44.4 runner faults: CanvasKit requests return
404 because its handler checks a slash path after converting to Windows
separators, and the generated HTML test selector loses its unescaped folder
separators. No assertions ran; these attempts are not counted as passing.
The suite is now included in Quality's Linux browser-test command. The release
app rendered successfully in the collaborative Chromium preview.

After review, keyboard handling keeps the host full-window and publishes the
visible-viewport overlap through MediaQuery.viewInsets instead of shrinking
the HTML host. The browser regression test focuses a real Flutter text field,
simulates the keyboard viewport shrinking, and checks that a bottom action
moves above it while the canvas size stays unchanged, then returns on dismissal.
Node bootstrap tests verify the host is no longer resized by JavaScript.

In the release preview, opened Bucket List's new-dream sheet and focused its
Flutter text field. A synthetic 300px visual-viewport overlap kept the host
at 932px while the sheet's visible content area reduced from 720px to 519px;
restoring the viewport restored the original form layout. No form was saved.
This checks inset propagation and dismissal, not a real iOS keyboard or the
form's submit action. The dedicated regression checks the bottom action.

The preview also logged an early didChangeViewFocus RenderBox error in both
full-page and installed-host runs, plus permission-denied messages for fake
Agent Mode presence/XP IDs. Neither prevented the captured screens from
rendering. Those pre-existing logs are not evidence of a clean console.
