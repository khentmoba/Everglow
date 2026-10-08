# Motchi Chat UI and UX proof

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
