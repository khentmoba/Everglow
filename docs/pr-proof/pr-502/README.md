# Unresolved installed-app edges

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

## CI recovery: missing event base

Quality runs 37884189853 and 37884211997 failed before app verification.
The shallow checkout contained merge `1e5476eb` onto current base `ad02e3d9`,
but the event's base was `33f560ee`, outside the downloaded history.
The PR contract's diff failed with `fatal: bad object`; no evidence or app
assertion failed. The check now fetches the event base only when absent.
Fetch errors still fail the job; no gate is skipped or weakened.

A disposable local Git repository with three commits and a depth-two clone
reproduced the same missing-base failure before the fix (one failed, two
passed contract tests). After the fix, all 26 contract/selection/worktree
checks passed. Analysis zero issues, all 1,533 app tests passed, and all 15
listed Dart guards passed again on Windows. Proof for this CI-only recovery
is the failing/passing regression, not another UI screenshot. Browser/build
wiring, app behavior, and the previously verified release build are unchanged.
Hosted CI and the refreshed screen-test preview remain pending.

Run 37884681787 caught a test-isolation mistake: the new CLI regression
inherited GitHub's `GITHUB_EVENT_PATH`, which took priority over its disposable
fixture argument. The test now explicitly sets that variable to its own event
file; production event selection is unchanged. Reproduced locally with an
inherited event referencing a commit absent from the fixture: one contract
test failed before, all 26 contract/selection/worktree tests passed after.
Analysis zero issues, all 1,533 app tests and all 15 guards passed again.
The hosted result is still pending; no CI-success claim.

## Query-free installation page

Khent confirms a new Home Screen launch starts at the password gate even
though the Safari link opens demo Dashboard. The earlier query/manifest
changes did not satisfy the physical-device outcome. This update no longer
relies on Safari state, query retention during installation, or the manifest's
query launch URL.

`/screen_test.html` is a separate static installation page. Safari stays on
that exact query-free address while adding the icon; Flutter does not start
there. Both the manifest ID and start URL point to that file. On a standalone
launch, the page explicitly replaces its location with the demo Dashboard
launch query. If standalone detection is unavailable, its visible Open demo
link activates the same test without a password. The normal manifest/login
and normal icon are untouched. This is a new screen-test install identity.

The install page and manifest revalidate hosting responses; the worker never
caches the install page or falls back to the normal app for that file. This
online-only diagnostic installer does not claim offline installation support.

Windows verification: analysis zero issues, all 1,533 app tests passed, all 15
Dart guards passed, ten bootstrap tests passed, and all 14 worker tests passed
with zero skipped, including disposable Chrome offline boot. The initial
worker run used a temp folder inside the repository, invalidating its isolated
build-stamp fixture; rerunning with the normal outside-repository temp folder
passed. The hosting guard rejected replacing the explicit index header with a
glob; index's existing rule was restored and the install page got its own rule.
The release build without the Agent Mode compile flag passed.

Local release browser: installation page stayed at its file URL with no
Flutter boot, correct query-free manifest, and no horizontal overflow at
430x932 or 820x1180. Inspected both captures; `screen-test-install.png` is
compressed phone proof. Cleared only local isolated demo browser storage,
clicked the actual Open demo link, then Screen edges: the full measurement
panel appeared without a password. Bootstrap tests replay a fresh standalone
launch for both iOS navigator detection and display-mode detection. These are
Chromium and synthetic checks, not a physical iPhone installation. The
mechanical HTML design check reported no findings. The bottom strip remains
unresolved and the PR stays draft until device measurements establish a fix.

## Physical result and reversible painting experiment

The installed screen-test launch now works on the reported iOS 26.6.1 device.
The private measurement screenshot reports screen 430x932, window and visual
viewport 430x873 (offset 0, scale 1), and all four HTML/body/host/Flutter-view
rectangles y=0..932. Safe insets are 59/34; installed CSS, black-translucent,
and cover fitting are active. The artwork reaches behind the clock while the
bottom strip remains. After landscape-to-portrait rotation and reopening the
report, all these values and the strip are unchanged. Device screenshots are
not published. These results disprove the shortened-layout-box explanation;
the synthetic before/after above is not a reproduction of this device failure.

Independent source review found that Flutter's custom host uses client size,
and its rasterizer/canvas use FlutterView physical size. CSS rectangles alone
cannot prove either canvas dimensions or compositor coverage. WebKit 301994
reports similar gaps but does not establish system ownership for this device.
A published Safari 26 fixed-layer painting example describes a slight-opacity
workaround: https://www.edoardolunardi.dev/blog/safari-26-and-the-strange-case-of-fixed-overlays.
It is not verified for installed iOS 26.6.1.

Screen measurement 2 adds engine logical size, host client size/embedding, and
the first canvas's CSS/backing size through Flutter's shadow root. It samples
the first Flutter view and canvas; full dimensions do not rule out other clipped
layers. Only installed demo sessions get Try paint workaround / Restore normal
paint while the report is open. This temporarily sets host opacity to 0.99;
restoring, closing the report, or removing the HUD clears it. Collapsing the HUD
keeps the selected probe so the screen can be observed. Nothing changes by
default, in ordinary tabs, or in normal accounts. This is an experiment, not
another claimed layout fix.

Windows: analysis zero issues, 1,533 app tests passed, all 15 Dart guards passed,
and release build passed without the Agent Mode flag. The dedicated Chrome
Flutter suite stalled at loading and timed out after 120 seconds with zero tests
completed; browser CI must verify the new reversible/installed-only regression.

Actual release app in T3 Chromium at 430x932 with untracked standalone/safe-area
and 873px window/visual-viewport simulation: engine and host client 430x932,
embedding custom-element, first canvas CSS 430x932 and backing 860x1864. Clicked
Screen edges and Try paint workaround; computed host opacity became 0.99 while
all sizes stayed unchanged. Restore normal paint returned opacity to 1. Enabled
again and closed the report; opacity returned to 1 and report disappeared.
Inspected `paint-probe.png`, fake-data phone proof of the toggle and measurements.
This simulation proves the new control and measurements, not Safari painting
or removal of the reported strip. A second read-only independent review found
no must-fix code defects, retaining browser-CI and physical-device requirements.
PR502 remains draft pending the actual before/on/restored device comparison.

## Paint experiment failed; initial metadata candidate

Khent reports the paint workaround did not remove the bottom strip at all.
The supplied restored/off-state screenshot confirms engine logical size and
host client size 430x932, custom-element embedding, first canvas CSS 430x932,
and canvas backing 1290x2796. Window and visual viewport remain 873px. The
reported failure rules out this opacity probe as a working correction; the
private screenshot is not published. Removed its button, state, setter,
stub, and test rather than leaving a failed experiment in the app. Retained
the renderer measurements.

The remaining targeted startup hypothesis is the original viewport policy:
index.html initially declared contain and changed to cover later in the head.
This candidate declares cover from the initial HTML metadata; the existing
head policy still changes ordinary browser tabs to contain before Flutter
starts. Installed launches no longer begin contained. No sizing, safe-inset,
status-bar, or renderer changes are stacked onto this experiment. We do not
know whether this changes native WebKit viewport allocation on iOS 26.6.1;
physical verification is still required.

Windows checks: ten bootstrap tests passed, including initial-cover metadata
and all four final viewport-policy modes (browser, iOS, standalone, fullscreen).
The new initial-policy assertions failed in four modes before the HTML change;
that is a policy regression test, not a Safari reproduction. Analysis zero
issues, all 1,533 app tests, all 15 guards, and all 14 worker tests passed (zero
skipped, real Chrome offline boot). Release build without the Agent Mode flag
and all 64 phone/tablet agent-smoke cases passed.

Local release Chrome: ordinary demo tab retains contain with a 430x932 view;
Screen edges opens and the failed opacity controls are absent. The temporary
installed-mode simulation at 430x932 with a deliberately 873px window/visual
viewport retains cover, full engine/client/canvas CSS dimensions, safe59/34,
and the readable report. Inspected `initial-cover.png`, compressed fake-data
phone evidence. Neither that synthetic screenshot nor the source assertions
prove the reported iOS gap is fixed. PR502 remains draft; no new install is
required to try the refreshed candidate once it is deployed.

## Initial metadata failed; independent plain-page control

The next private iPhone screenshot confirms the failed opacity button is gone,
so the updated UI loaded. The bottom strip is unchanged. Initial-cover metadata
is NOT a working correction. Engine/host/canvas CSS remain 430x932, backing
1290x2796, while window/visual height is 873; safe insets remain 59/34. This does
not prove whether native WebKit clipping or app compositing owns the strip.

A read-only review found no established both-edge fix in the history. The next
control isolates the app's rendering path instead of stacking more layout
changes. In the existing screen-test icon, **Screen edges → Open plain paint
control** navigates the SAME window to `/screen_test.html?paint=1`. This prevents
that page's normal installed-launch redirect. Manifest identity, scope, launch
URL, worker, and normal app metadata are unchanged; no reinstall is needed.

The control uses the exact installed viewport/status/theme/color-scheme metadata,
ordinary document flow, no fixed roots or overflow clipping, and no Flutter or
app scripts. A patterned `100vh` block labels its first and last 59 CSS pixels.
The report shows installed state, screen/window/visual dimensions and actual
block bounds; resize refreshes it. A distinct document background lets visible
STRIPES distinguish content paint from propagated background or system tint.
The demo-only button is further limited to explicit `screencheck=1` launches.
No report is sent anywhere, no data is loaded, and Return to demo app explicitly
reactivates isolated Agent Mode in the same window.

Physical comparison: app → control (screenshot without scrolling) → app.
- Pattern fills both edges AND the app strip returns: plain DOM can reach there
  in that session; narrow investigation to the app path or state it triggers.
- Same strip with Installed:true and a verified full-size pattern: Flutter and
  its fixed host are unnecessary to reproduce the failure. Stop resizing them;
  further diagnosis requires iPhone/WebKit inspection.
- Installed:false, changed bounds, or return also clears the strip: inconclusive.
  Navigation can change native allocation, so this control cannot prove an
  873px native drawable frame or distinguish host clipping from Flutter layers.

Windows, Flutter3.44.4/Dart3.12.2/Node24.21.0: analysis zero issues; all 1,533
VM/widget tests, all 15 listed Dart guards, 12 bootstrap tests, and 14 worker
checks passed (real disposable Chrome offline check, zero skipped). Release
build without the Agent Mode flag passed. The first worker invocation inherited
TEMP/TMP under this git checkout from the app-test workaround; fixture git
lookup appended the checkout commit and failed its version-only stamp assertion.
Rerunning with the normal OS temp directory outside git passed; no test or
production worker was changed, weakened, or skipped.

Actual release app, T3 Chromium, 430x932: clicked Screen edges and Open plain
paint control; the same tab reached the static page. Root/body are static with
visible overflow, pattern y=0..932, Installed:false (ordinary desktop tab), zero
Flutter views/canvases and no resource fetches. Inspected
`plain-paint-control.png`: labels and stripes reach both edges. Clicked Return
to demo app and verified its agent/screencheck launch URL. The VM tests cover
both installed/noninstalled paint branches, redirect suppression, exact metadata,
no app scripts/clipping styles, and refreshed bounds. These verify the control,
not native Safari painting. Existing release-app env-file404, early focus/layout
error, and denied fake XP/presence calls remain; no clean-console claim.

PR502 stays draft. CI deployment and the physical app/control/app comparison
are still pending; no both-edge or real-iPhone correction is claimed.

## Main sync after the CI-script conflict

Main now compares PR changes against the tested merge checkout's first parent,
not a potentially stale event base. Its implementation and regression supersede
this branch's earlier event-base fetch workaround, which was removed during the
merge. The regression retains an isolated GITHUB_EVENT_PATH and demonstrates
that an unavailable event base does not require fetching it. Both resolved
contract files match main; the screen diagnostic is unchanged.

Windows re-verification: analysis zero issues; all 1,567 VM/widget tests, all
15 listed Dart guards, and 38 Node contract/selection/worktree/bootstrap tests
passed, zero skipped. Release build without the Agent Mode flag passed. This
CI-only conflict resolution has no new visual proof; the inspected plain-page
proof above is unchanged. Hosted checks/deployment and physical iPhone outcome
remain pending; no device correction is claimed.

## Physical comparison: full plain page, shortened app; normal-flow candidate

Khent's physical iPhone app/control/app comparison is now complete. The plain
page reports Installed:true, screen/window/visual/pattern 430x932, visual
 offset0/scale1, pattern y=0..932. Stripes and the bottom label visibly reach both
edges. Returning to the app brings back the strip AND window/visual height873;
engine/host/canvas remain932, backing1290x2796, safe59/34. Private screenshots
are not published. This demonstrates full-height capability in the same installed
session, then a repeatable shortened app viewport. It does not isolate app CSS
from engine/startup behavior or prove which component changes native allocation.

The next smallest candidate matches the working control's document flow:
installed html/body become position:static with visible overflow, and the
100vh Flutter host becomes position:relative so it participates in body flow.
Clipping remains INSIDE the finite host and Flutter root. Ordinary browser
roots stay fixed/contained. No metadata, size constants, insets, engine flags,
new dependencies or guessed offsets are changed.

An independent read-only source review found this compatible with Flutter's
custom-element embedding, definite-height root and host resize observer. Its
full-page viewport replacement does not run in this installed custom-host path;
the shared resize nudge does not itself set viewport dimensions. No runtime
must-fix issue was found. The reviewer and local run caught a new test regex
matching the earlier combined-height rule instead of the separate host rule;
the guard was anchored to that rule, not weakened. The pre-change guard failed
on missing normal-flow roots; after the selector correction all13 tests pass.
These are configuration guards, not a reproduced Safari failure.

Windows re-verification: analysis zero issues, all1,567 VM/widget tests, all15
listed Dart guards, all13 bootstrap tests, all14 worker checks (real disposable
Chrome offline check, zero skipped), and release build without Agent Mode flag
passed. Physical keyboard opening/dismissal, iPhone rotation and the new both-edge
outcome remain unverified.

Actual release app in a fresh incognito T3 Chromium context, using an untracked
entry fixture to select standalone before startup: at430x932, root/body are
static/visible-overflow, host/view relative/hidden-overflow, all dimensions932
and document scrollHeight932. Clicked Screen edges; inspected
`normal-flow-candidate.png`, synthetic Dashboard with measured full-size renderer
and zero native safe insets. At932x430 and820x1180, all four bounds and document
scroll extents exactly match the resized viewport. Ordinary browser launch
restores fixed roots and contain with a full820x1180 view. The first local
attempt reused an unstamped cached core from an older raw Flutter build and
could not load a deferred Home library; removing only the isolated local demo
worker/caches and repeating in incognito loaded the actual Dashboard. No change
to production worker or private user state was made; no clean-console claim.

The screenshot and resize checks prove candidate selection, dimensions and demo
rendering in Chromium, NOT that it fixes the physical iPhone strip. The existing
screen-test icon can load this candidate without reinstalling after deployment.
PR502 remains draft pending that physical result and keyboard/rotation checks.

## CI recovery: new main browser test waits for a pending reply to settle

Quality37966712752 on candidate8df0577 failed one browser test: Motchi's
`agent session keeps composer enabled and allows clicking template message to
send`; 32 other Chrome tests passed, including both screen-edge tests. The
public job log/annotations provide only the generic failure, not its underlying
assertion/stack. No Chrome-startup or candidate-CSS failure is claimed.

CI tested merge3e0db29: maina1886458 plus candidate8df0577. The failing test came
from main's PR504 and was absent in the pre-merge local branch. Brought that same
main into this branch to examine the actual tested source. These widget-browser
tests do not load web/index.html, so the normal-flow CSS is not exercised by
this failing test.

The fake send sets loading:true, starts an unresolved reply future and displays
repeating thinking animations. Waiting for pumpAndSettle after Send conflicts
with that invariant. The source review identified the same issue; the existing
send/stop test uses pump after Send and settles only after stopping. Corrected
only this post-Send wait to pump, retaining BOTH request-count/message assertions
and all other interactions. No production behavior, animation, assertion or
browser suite was disabled. The original CI exception remains unavailable;
CI must confirm this source-grounded correction.

Windows focused reproduction with --platform chrome, the exact plain-name and
expanded reporter stalled at suite loading. It timed out after240 seconds with
ZERO tests completed; this is an environment/loading blocker, not a passing or
reproduced assertion. The fake pending-animation invariant is established by
source, not by that incomplete run. Analysis zero issues, all1,567 VM/widget
tests, all15 listed Dart guards and39 Node contract/selection/worktree/bootstrap
tests passed after the correction. Production CSS/diagnostics are unchanged;
no new visual proof is required for the test-only fix. The browser CI result
and physical iPhone candidate outcome remain pending.

## Passing CI and main's independent test correction

All six hosted checks passed on544497b, including the browser suite, and the
candidate preview deployed. Main then released6.2.0 and independently adopted
pump after Send plus an explicit Stop-generating tap before settling. Resolved
that overlapping test change by keeping main's complete version; the browser
test now exactly matches main. Candidate CSS and every diagnostic file are
unchanged. This does not cut a new release; it brings the existing main release
into the task branch.

Analysis zero issues, all1,567 VM/widget tests, all15 listed Dart guards
(including6.2.0 release sync), and39 Node tests passed again. No new visual proof
is needed for this test-only merge resolution. New-head CI/deployment and the
physical normal-flow result remain pending.
