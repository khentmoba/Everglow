# Motchi Chat UI and UX proof

## CI recovery after badge removal

Run 37918214902 passed 29 Chrome tests, including the 320px/1.6x composer
and absent-side-badge regressions. The permission/retry mic case failed:
its second tap hit the still-visible SnackBar instead of the mic. The
notice timer starts after its entrance animation, so the test now finishes
that animation before advancing the timeout, requires the notice gone,
and requires Stop voice input before testing disposal. App behavior is
unchanged. Linux Chrome must confirm the corrected test.

The same run compiled the release app but its smoke check could not start
Chrome; no destination assertions ran. The new CI run must verify that.
The PR-event run also failed before app checks because its recorded base
SHA differed from the checked-out merge base. The PR contract now compares
against the merge's first parent, as required by Quality's PR checkout.
A real temporary Git merge regression with an unavailable event base passes;
proof requirements are unchanged. All 24 selection/contract tests, local
analysis, 1,539 regular tests, 15 Dart guards and diff check passed.

## Remove redundant side status

Removed the thinking/replying badge beside Motchi's name from both the
initial thinking header and the streaming reply header, including its
unused animation widget. Avatar feedback, thinking dots, streaming caret,
and tool progress remain. Browser regressions now require both side labels
to be absent while preserving the existing progress-animation checks.

Local `flutter analyze`, all 1,539 regular tests, all 15 Dart guards and
`git diff --check` passed. A synthetic release fixture in disposable Chrome
was inspected at 430x900 and 810x1080; `reply-no-side-badge-phone.png` and
`reply-no-side-badge-tablet.png` show the live reply without the side badge.
No real data or AI calls; temporary fixture removed. Browser assertions
still require Linux CI; the previously documented Windows runner blocker
remains. This is a UI-only removal, not a change to Motchi's thinking mode.

## Composer overflow correction

Quality run 37865682012 failed the 320px / 1.6x text welcome test with
Canvas enabled: the composer Row overflowed by 41px. Secondary controls
now wrap in the available space; Dictate and Send remain on the right.
The regression also selects Deep, Fast, and Auto with Canvas active.

Local Windows Flutter 3.44.4: `flutter analyze` passed; all 1,539 regular
tests passed; all 15 listed Dart guards and `git diff --check` passed.
The browser suite could not start: local CanvasKit requests returned 404,
and the Windows test selector reported the test path without separators.
No browser-test pass is claimed; Linux CI must confirm the regression.

`composer-small-large-text.png` (320x1000) and
`composer-tablet-large-text.png` (810x1080) were captured and inspected
from a synthetic release fixture with 1.6x text. In disposable headless
Chrome, Add to message -> Canvas enabled its visible control. Both
screens retain Dictate and Send without clipping. This verifies release
layout, not Safari speech or the browser-test assertions. The temporary
fixture was removed; no Firebase, AI, or real couple data was used.


Release web previews in the isolated agent session (`/motchi?agent=clair`).
Only synthetic starter text is shown. No real conversation or private photo
is included. The collapsed lightning pill is the existing agent HUD.

- `before-phone.png`: baseline HEAD 1f043a39, 430 x 900 CSS pixels.
- `after-phone.png`: updated welcome and composer, 430 x 900.
- `phone-draft.png`: movie starter prepared as an editable draft, Deep selected.
- `tablet-history.png`: history drawer and visible failure/retry, 810 x 1080.
- `desktop.png`: sidebar open by default, 1280 x 900.

All attached images were inspected. Screenshots establish appearance;
the interaction checks below establish only the flows actually exercised.
The final timestamp ellipsis adjustment does not affect these empty-chat views.

## Verification

Windows, Flutter 3.44.4, Dart 3.12.2; collaborative Chrome preview.

- `flutter analyze --no-pub`: passed.
- `flutter test --no-pub --exclude-tags="golden,network"`: 1,533 passed,
  including all 10 sidebar tests.
- All 15 files listed by `Get-ChildItem tool/ci/check_*.dart`: passed after
  the final source edit.
- `git diff --check`: passed.
- `flutter build web --release --dart-define=AGENT_MODE=true --no-pub`: passed
  after the final source edit.
- Browser: inspected phone, tablet and desktop; clicked movie starter and
  confirmed an editable draft, opened reply modes and selected Deep, opened
  and closed history, clicked retry, and collapsed the desktop sidebar.
  Accessibility snapshots confirmed concealed background controls are excluded.

## Remaining verification

`flutter test --no-pub --platform chrome
test/features/ai/motchi_streaming_scroll_test.dart` stalled before executing
any tests. An unchanged test also stalled with Chrome and Edge. The Windows
Flutter test asset handler initially returned CanvasKit 404s; a temporary SDK
source diagnostic resolved those requests but the runner still stalled at
`+0: loading` and reached a 180-second deadline. The SDK source was restored.
Linux Quality CI must execute the browser suite before this PR leaves draft.

The credential-free release preview exercises the history error path.
Successful history switching/retry is covered by the fake repository tests;
successful AI generation, streaming and keyboard behavior remain pending the
browser suite. No real AI request was made during screenshot capture.

## First Linux CI result

Quality run 37839956474 executed the Chrome suite: 20 passed, 1 failed.
The failing case is `keeps the latest streamed reply in view`; its assertion
details were omitted by the reporter. Error logging was added to that test
without changing its assertions, so the next CI run can identify the cause.
The other Motchi browser cases passed, including responsive welcome/composer,
reply modes, editable starters, send/stop, IME/Shift handling, initial-load
recovery, navigation and the answering glow. Analysis, regular tests, guards,
web build and deployment also passed. The hosted preview opened Motchi correctly.
The regular 1,533 tests and 15 guards passed again after the diagnostic edit.

The diagnostic run 37841067036 exposed a premature assertion after tapping
Latest message: actual scroll offset 0, expected 3729. The test now gives the
post-frame scroll callback and the first animation tick separate frames before
advancing the 300 ms animation. The bottom-position assertion is unchanged,
and a further streamed chunk must remain followed. Browser confirmation is
pending the next Linux CI run.

Run 37842106545 revealed the second issue: after the scroll reached its
estimated bottom (3729), newly laid-out rows revised the maximum to 5969.
Motchi now follows scroll-metrics changes while following is active, suppresses
user-away detection during its own movement, and lets user scrolling interrupt
the animation. The regression now runs at 430, 810 and 1280 CSS pixels and
requires both a completed jump and continued following of the next chunk.
That run also had a separate Chrome-startup failure after successful release
compilation; the completed web job was retried without changing the harness.

Run 37843437021 passed release compilation, the complete agent smoke sweep,
deployment, and the tablet/desktop scroll cases. The phone case revealed that
the revised extent can shrink as well: offset 5969, maximum 5863. The metrics
follower now corrects distance from the bottom in either direction. The strict
phone assertion remains in place; final browser confirmation is pending CI.

Run 37844388999 confirmed all 23 Chrome tests, all 1,533 regular tests,
analysis, guards, release build and agent smoke sweep passed on 8d524ac7.

## Real chat from the preview

Agent mode has no Firebase sign-in token for real AI replies. Motchi now offers
`Sign in to chat` in that mode and disables sending until signed in. The action
disables agent mode, removes its URL parameter before logout can refresh the
router, and opens the normal login door with `/motchi` as the return destination.
Real accounts continue through the existing authenticated AI service.
The browser regression uses a fake auth service to verify the transition;
no passcode or real couple conversation is used for proof.

Quality run 37848133978 passed analysis, regular tests, all guards, the selected
Chrome suite including the new sign-in regression, release build, agent smoke
sweep and preview deployment on d24546f5.

The hosted preview was inspected at 430 x 900 CSS pixels. `preview-sign-in.png`
shows only the synthetic welcome, sign-in notice and disabled composer. Clicking
`Sign in to chat` opened the normal passcode door at `/?from=/motchi`, with no
agent parameter or redirect loop. No credentials were entered. Actual signed-in
AI generation remains unverified manually; real replies use the existing service.

## Tool activity and reply details polish

`tools-phone.png` (430 x 1000), `tools-tablet.png` (810 x 1080), and
`tools-live-phone.png` (430 x 900) show the actual Motchi widgets with synthetic
conversation, action receipts, cited memories, sources, and active tools. A
temporary Flutter entry point supplied fake repositories and auth; it made no
Firebase or AI requests and was removed after capture. The example.com and
example.org links are synthetic sources, not research supporting the demo reply.

Active tools wrap instead of hiding offscreen. Tool labels use readable text and
the existing icon family. Receipts separate action names, outcomes, and details;
failed, waiting, unscheduled, and unconfirmed outcomes retain their meaning.
Sources use full-width keyboard-accessible links. Thoughts have a keyboard/touch
toggle with a standard 48px target, and their content remains selectable markdown.

The collaborative browser reported an unavailable automation host, so capture
used disposable headless Chrome through the existing CDP harness. All three
images were inspected after the splash disappeared; the thoughts toggle was
clicked and its content collapsed. A 320px/1.6x text receipt regression passes.
Regular tests: 1,534 passed. All 15 guards and analysis passed. New Chrome
regressions cover wrapped tools/thoughts and source layout/invalid links; Linux CI
must verify those before this update leaves draft. No backend behavior changed.

Quality run 37851963595 passed regular tests, guards, analysis, release build,
agent smoke and deployment. Its Chrome suite passed 25 tests; only the new
320px/1.6x active-tools/thoughts test failed, and the reporter omitted the
underlying exception. The same synthetic release state was checked locally
at those exact dimensions/text scaling: all three tool labels appeared, the
thoughts target measured 48px, clicking it collapsed the notes, and no layout
error appeared in the browser console. The failing test now logs Flutter
exceptions synchronously, with all assertions unchanged, to obtain the missing
CI diagnostic. This local check does not substitute for a passing Chrome test.

Run 37853209914 identified a 79px overflow in the name/thinking-badge row at
`motchi_widgets_extra.dart:159`, not in the tool cards. Both the streaming reply
header and the initial thinking header now wrap their contents when needed.
The same large-text test also exercises the initial thinking state with no
reasoning text; its no-exception and 48px assertions remain intact. Linux browser
confirmation is pending. That run's web build compiled but Chrome startup failed
before the agent smoke sweep; no app assertion failed in that web job.

Quality run 37854024429 on 60e4b665 confirmed the header fix: all 26 Chrome
tests passed alongside 1,534 regular tests, analysis, 15 guards, release build,
agent smoke and preview deployment.

Motion follow-up: thought details and changing tool rows resize with the existing
220ms strong ease-out token; the thoughts chevron rotates over 160ms. Both honor
app and platform reduced-motion preferences. A synthetic release build was
opened in disposable Chrome at 430x900. Clicking collapse hid the notes, and
opening then closing again after 60ms settled collapsed. DOM sampling could not
measure the intermediate layout, so this does not prove transition timing.
The browser regression now asserts an intermediate height and immediate toggles
with reduced motion enabled; Linux CI confirmation remains pending. Local
analysis, 1,534 regular tests, all 15 guards and the synthetic release build passed.

Run 37855310834 passed 25 Chrome tests and the normal 80ms/finished size
assertions, then failed when reduced motion changed the thoughts size.
Flutter reported RenderAnimatedSize mutating during its own layout with a
zero-duration controller. Reduced motion now returns the child directly,
without a size-animation render object. The regression verifies notes appear
and disappear after a single pump, with no AnimatedSize ancestor and no
exception; normal-motion intermediate-height assertions remain unchanged.
Linux Chrome confirmation of this fix is pending.

Phone activity motion correction: the thinking dots, answering avatar, reply
badge, streaming caret/wave and tool-status pulse previously called
AppMotion.reduceAmbientMotion, which unconditionally freezes phone viewports.
They now honor app/platform reduced motion and TickerMode without freezing
active reply feedback based on screen size.

Disposable Chrome, synthetic release fixture, DPR 1: captured 14 frames with
120ms waits between captures at 430x900 and 810x900. The previous phone build's
first/eleventh frames were pixel-identical with reduced motion off. Updated
phone frame changes were bounded to (10,233)-(220,421); tablet changes to
(42,236)-(459,374), covering active indicators. With prefers-reduced-motion
emulated as reduce, updated phone frames were pixel-identical. Screens were
inspected and show synthetic chat/tool activity, not a gateway or private data.
The old fixture includes synthetic thought notes; the new fixture omits those,
so pixel comparisons are within each recording, not between different fixtures.

motion-phone.png is the inspected new phone screenshot. motion-phone.gif is
that same capture sequence replayed at 150ms per frame (sampled proof, not a
frame-rate measurement). The temporary entry point and capture script were
removed. Linux Chrome regressions now check thinking-dot/halo/caret motion at
430 and 810px, the tool pulse at 320px, and reduced-motion stillness. Browser CI
confirmation remains pending; the synthetic release build and analysis passed.

Standalone HTML game recovery: synthetic tests reproduced four failures before
this change (unfenced page, unlabeled page fence, incomplete stream, empty code
card). All 54 targeted parser/Markdown tests passed after. Complete standalone
HTML documents now use the existing canvas artifact parser, with its existing
size cap and opaque-origin sandbox. Explicit non-artifact code fences stay code;
partial standalone pages are hidden while streaming. Empty code blocks do not
render a blank code card.

Synthetic release proof at 430x900 in disposable Chrome (T3 host unavailable):
html-game-phone.png shows a game card plus prose without HTML/JavaScript text.
Clicked Play, then activated the synthetic Reveal a pair and Restart controls
inside the iframe: score was Moves: 0 -> Moves: 1 -> Moves: 0. The iframe
sandbox attribute remained allow-scripts. html-game-open-phone.png shows the
opened demo app after reset. Both screenshots inspected. These are synthetic
fixtures, not the user's screenshot or real conversation data. The supplied
screenshot does not expose the original opening fence, so exact original reply
format remains unverified; the reproduced failure shape is covered by tests.
Temporary fixture/capture files were removed. Local analysis and synthetic
release build passed; full tests/guards and Linux Chrome CI still pending.
Full local confirmation: flutter analyze --no-pub passed, 1,539 regular tests passed, all 15 actual Dart guards passed, and git diff --check passed. New hosted build/Chrome CI confirmation remains pending.

Voice input: voice-phone.png, voice-listening-phone.png and voice-draft-phone.png
were captured and inspected from a synthetic release fixture at 430x900 in
headless disposable Chrome after T3 reported its automation host unavailable.
Clicked Dictate message with a simulated Safari-prefixed SpeechRecognition API;
start ran immediately, Stop produced an editable draft and enabled Send.
Injected not-allowed and confirmed the permission notice and restored mic.
No real microphone, Apple permissions or physical iPhone were exercised.
Three browser regression tests cover appending to an existing draft, Stop,
permission recovery, cancellation on unmount and unsupported keyboard fallback.
Linux Chrome CI is pending for those tests. No new dependency or audio backend.
Voice local checks: analysis clean; 1,539 regular tests passed; all 15 guards passed; synthetic release build passed; diff check clean.
