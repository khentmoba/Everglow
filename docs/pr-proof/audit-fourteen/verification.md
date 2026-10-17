# Fourteen audit fixes

All checks and screenshots below use synthetic demo data. No live couple records,
photos, login codes, or local environment secrets were read or changed.

## What changed

1. Failed passcode guesses are counted in an awaited database transaction.
2. Removed the automatic cleanup that deleted Khent's legitimate watched entries.
3. Logout unregisters and revokes this device's push token before signing out.
4. Gallery deletion confirms file cleanup before removing its database record.
5. Trip list actions change items by ID against the latest transaction snapshot.
6. Failed trip saves keep the inputs open, show retry, and reject double submits.
7. Watchlist operations, shelf membership, optimistic state, couple merges, and
   On This Day use source + movie/TV type + catalog ID instead of bare numbers.
8. Journal/subscription editors write only changed fields. Overlapping journal
   text edits retain the draft and offer an explicit reload.
9. Fresh watch parties replace old stream/episode fields; absent server settings
   are deleted. Either partner can host a new ended/stale session, not steal an
   active one.
10. Motchi XP and stats use real Firebase account IDs; awards are transactional.
11. Academy joins, question refreshes, scoring, and winners have scoped rules.
    Legacy score fields still work. Match cleanup only deletes the caller's rows.
12. Push registration runs after verified login, not just before the login screen.
13. Phone/tablet tokens have separate private device records. The server sends to
    every registered device and removes invalid tokens.
14. Failed gallery metadata creation cleans the successfully uploaded objects.

No new dependencies or data migration were added. Previously deleted watch
history cannot be reconstructed by removing the bad cleanup.

## Before and after evidence

Before the room/history fixes, the three tests in
`watch_party_service_writes_test.dart` and `watch_history_safety_test.dart`
failed: old stream/subtitle fields survived, and the destructive startup cleanup
was reachable. All three pass after the fixes.

Additional regression tests exercise catalog collisions, transaction contention,
changed-field edits, retained drafts, rejected writes, double taps, push login /
logout races, gallery partial failures, and storage cleanup order. The journal
write-failure test asserts the actual rejected transaction error, not any exception.

## Final checks

Environment: Windows; Flutter 3.44.4 / Dart 3.12.2; Node 24.21.0; Java 21.0.10
from Android Studio's bundled JBR; installed Chrome with a disposable profile.
Production Functions use Node 22; the local Node test run used Node 24.

- `flutter analyze`: no issues.
- `flutter test --exclude-tags="golden,network"`: **1,698 passed**.
- Listed `tool/ci/`, then ran every `dart tool/ci/check_*.dart`: **16 passed**.
- `cd functions && npm run lint -- --max-warnings=25`: zero errors; 24 existing
  warnings, within the repository's limit.
- `cd functions && npm test`: **335 passed**, five emulator tests skipped here.
- `cd functions && node eval_gate.js`: passed.
- `firebase emulators:exec --only firestore,storage --config firebase.emulators.json
  --project demo-everglow "node --test functions/security_rules.emulator.test.js
  functions/push_rules.emulator.test.js"`: **5 passed, zero skips**. This covered
  couple/guest privacy, wrong device UID, scoped Academy writes and legacy scores,
  party host restart rules, and table tennis's existing access contract.
- `dart tool/build_web.dart -- --release --no-source-maps`: passed. Existing Wasm
  dry-run notices remain; this verifies the supported JavaScript web build.
- Impeccable detector on changed Cinema/Gallery/Trip UI: no findings.
- `git diff --check`: passed.

The first debug web-server attempt ran out of temporary disk space while writing
compiler sources. No unrelated files were deleted. The release build succeeded
and is the build used for the browser proof below.

## Browser proof

The release app was served locally with the existing `tool/perf/_harness.mjs`
static server and opened in disposable headless Chrome. Agent Mode navigated to
Trip Kit; the HUD was collapsed; New trip was opened; fictional title/destination
text was entered; then the viewport was changed from 430x932 to 820x1180.
Both screenshots were inspected: the editor and submit button fit on both sizes.

- [Phone editor](trip-phone.png)
- [Tablet editor](trip-tablet.png)

These images prove the form's appearance and the opening/typing interaction.
They do **not** prove live saving, concurrent devices, or notification delivery;
those failure cases were exercised with unit/widget fakes and database emulators.
Real iPhone/Safari, Android/tablet hardware, real FCM delivery, and live Firebase
configuration were not tested. The app's full browser-only Flutter suite was not
run locally; Quality selects it for this PR. No app-speed claim is made.

## Release and recovery

This changes live authorization and write behavior on merge, so it is a one-way
release boundary. Existing parent-document push tokens are intentionally ignored:
users must open the updated app to register each device. Old clients must refresh
before using the new token rules. Motchi preferences stay on the parent document.

If authorization or saves fail after release, revert the affected feature commit
and redeploy the matching client/functions/rules together. Reverting code cannot
restore already deleted files/history. No production records were migrated here.
