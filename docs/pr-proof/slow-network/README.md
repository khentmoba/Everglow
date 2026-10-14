# Slow-connection first pass

All images and test records are synthetic. No couple records or photos were
read. Local Windows Chrome checks used the agent sandbox.

## Behavior evidence

- Before the stream fix, three new regression tests failed: parent rebuilds
  listened twice instead of once; an unavailable error removed loaded rows;
  changing sources retained the previous source's text. All now pass.
- Shared-list tests preserve the same mounted Scrollable and its 300px offset
  after an injected unavailable error at 430px and 810px. Retry remains tappable.
  Permission denial, source replacement, and null document updates remove old
  content. First-load loading/empty/error tests also pass.
- Gallery tests retain one query creation through UI rebuilds, replace it for
  Load More (40 -> 80), and reuse one map request through tab changes.
- The viewer HTTP fake observes only the selected full-photo request on open.
  Dragging to the next page loads that photo. Existing delete/rollback tests pass.
- A delayed XP fake confirms the journal write, dialog dismissal, and draft
  clearing finish while XP remains unresolved. A later XP rejection is logged
  without an uncaught error. Rejected entry writes still retain words and drafts.

## Commands and results

- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub --exclude-tags="golden,network" --reporter expanded`:
  passed, 1,612 tests. A first run overlapped a final source edit and failed the
  newly added null-update regression; the complete final-source rerun passed.
- Listed `tool/ci/`, then ran every existing `check_*.dart`: 15 passed, 0 failed.
- `flutter test --no-pub --dart-define=EG_SLOW_PROOF_DIR=docs/pr-proof/slow-network
  test/shared/widgets/everglow/everglow_stream_view_test.dart --reporter expanded`:
  9 passed; captured the shared-widget error state with bundled fonts loaded.
- `dart tool/build_web.dart -- --release --no-source-maps
  --dart-define=AGENT_MODE=true`: passed. Final compile 88.3s on Windows;
  this is build time, not user loading time. Dirty local source was stamped
  `6.2.0+1-20b011fa`. Existing wasm compatibility dry-run warnings remain;
  this verification used the JavaScript release build.
- `flutter run -d chrome --web-port=8766 --dart-define=AGENT_MODE=true
  --web-browser-flag=--headless=new`: launched with Flutter's disposable profile.
- Impeccable's scoped mechanical detector returned no findings.

## Browser inspection and interactions

T3's collaborative Chrome browser inspected the release app at
`http://127.0.0.1:8765/?agent=gallery` and `/?agent=journal`, at 430 x 932 and
810 x 932. Accessibility was enabled and the agent HUD collapsed for proof.

Checked the gallery grid, opened a demo photo (1 / 3), returned via Back,
switched to Week on tablet width, opened a new journal entry, entered synthetic
title/content, and pressed Save. The dialog closed and the journal remained
visible. Agent saving is simulated; the delayed/rejected write and XP behavior
is established by the fakes above, not by this browser save.

The first release page loads recorded a missing local environment asset (no
secrets were supplied) and `RenderBox was not laid out` during
`WidgetsBindingObserver.didChangeViewFocus`, before the initial page settled.
Both pages subsequently rendered and the tested interactions added no errors.
The debug Chrome capture did not report that error. The startup warning is
recorded rather than calling the release console clean; baseline attribution
and real-device startup remain unverified. GPU ReadPixels diagnostics also
appeared during capture and are not an app-speed measurement.

## Images

- `gallery-phone.png`: actual release-browser grid, 430px CSS width.
- `gallery-week-tablet.png`: actual release-browser Week view, 810px CSS width.
- `journal-phone.png`: actual release-browser journal after the simulated save.
- `live-list-network-error-430.png` and `live-list-network-error-810.png`:
  Flutter widget renders of the shared live-list component in a synthetic
  harness, with a real injected error. These are not screenshots of a live
  authenticated gallery or journal.

No backend, database rules, service-worker source, or performance harness was
changed, so their conditional manual browser/tooling suites do not apply.
Actual slow-network timings, iPhone/Safari behavior, durable offline saving,
historical thumbnail backfill, and third-party streaming remain unverified.
