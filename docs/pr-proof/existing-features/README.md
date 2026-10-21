# Existing feature improvements

All screenshots use the isolated agent session and synthetic artwork. No real couple data, photos, credentials, or live account writes were used.

## Checks

- Windows, Flutter 3.47.7 / Dart 3.13.5, Node 24.21.0, disposable headless Chrome 155.0.8059.85.
- `flutter analyze`: no issues.
- `flutter test --exclude-tags="golden,network"`: 1,753 passed.
- Listed `tool/ci/`, then ran all 15 existing `check_*.dart` guards: all passed.
- `flutter build web --release --no-pub --dart-define=AGENT_MODE=true`: passed. Existing WebAssembly dry-run incompatibility notices remain; the JavaScript release build succeeded.
- Impeccable detector on the five changed UI targets: no findings.
- `git diff --check`: passed.

## Browser evidence

Served the release build with the existing `serve` helper in `tool/perf/_harness.mjs`. The debug web-server launch was attempted first, but the custom bootstrap requested `main.dart.js` with a text/html response. T3 Preview initially worked, then repeatedly returned `Preview automation snapshot timed out after 15000ms.` Continued in disposable Chrome through the repository's CDP harness. The final fresh browser session recorded no JavaScript exceptions or error console calls.

Checked at 430 x 932 and 810 x 932 CSS pixels:

1. Tonight: expanded preferences, chose 45 minutes and Go out, then found three picks. The shared summary changed and the cards became nearby outdoor activities. `tonight-before-phone.png` is the actual prior UI; the other Tonight images show the implemented UI.
2. Heartbeat: opened today's check-in, selected Need some quiet and a mood. Opened the partner's check-in and acknowledged Keep me company. The acknowledgement button changed to its sent state.
3. Wish to plan: opened the demo Tokyo wish, chose Plan this, selected a date, and verified the calendar form carried the wish title, description, and both attendees. Calendar persistence is covered by transaction tests, not this demo form.
4. Wish to memory: opened the completed cake wish and chose Keep this memory. Selected a synthetic gallery photo, entered and saved a personal contribution, then followed Original wish back to the matching wish details. The screenshots show the linked photo, separate spaces for Khent and Clair, and saved feedback.
5. Cinema: the agent catalogue rendered. Agent watchlists intentionally stay empty, so the new resume sheet's five actions and its layouts are covered by eight widget tests. External playback, source retry, and real phone-to-tablet progress synchronization were not exercised in the demo browser.

## Data safety

`shared_memory_flow_test.dart` calls the real calendar and journal services against a network-free Firestore boundary. It verifies an atomic wish/event save, duplicate-plan rejection, failed-commit rollback, stable memory identity across wish and calendar entry points, separate partner contributions, preserved links during journal edits, and the photo cap. Existing journal concurrency and locked-entry tests also pass.

The new fields are optional. There is no backfill, collection migration, rules change, or backend deployment in this change. Newly saved fields remain in Firestore if the client is reverted. Live account sync and physical phone/tablet behavior still need a normal account check after merge.
