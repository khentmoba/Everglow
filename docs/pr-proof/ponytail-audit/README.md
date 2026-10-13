# Ponytail audit fixes

All screenshots use synthetic agent fixtures. No credentials or real couple data were used.

## What changed

1. Money, Subscriptions, Trip Kit and Our Books return demo records and skip live/cache writes in agent mode.
2. Table-tennis guests can claim an empty seat once. Joining uses a transaction, and updates no longer require the nonexistent category field.
3. Money and subscription write errors reach their forms. Failed saves preserve entered details and allow retry; failed removals show an error.
4. Gallery can load older photos in batches of 40. Search visits every older page.
5. Partner notification triggers match the app's collections, author fields and navigation types. Invitations notify their named recipient.
6. XP initialization cannot overwrite an award that arrives before its commit.
7. Garden writes retry overlapping watering/plant changes without losing progress or the plant selection.
8. Money listens to the selected month's records and expands a full query until totals are complete. Rows are revealed 50 at a time.
9. Book/anime previews order by addedAt before their limit. Required composite indexes are included.
10. The unused StorageService and its provider registration are deleted.
11. Backend health reports 6.2.0+1, and the release guard checks the server version too.

## Verification

- Windows, Flutter/Dart from C:/dev/flutter, Node 24.21.0. Production Node target is 22.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --exclude-tags="golden,network"`: 1,596 passed.
- All 15 `dart tool/ci/check_*.dart` guards passed.
- `npm run lint -- --max-warnings=25`: passed, 24 existing warnings and no errors.
- `npm test -- --test-reporter=spec`: 323 passed, 2 emulator tests skipped in the ordinary run.
- `node eval_gate.js`: passed.
- Java 21.0.10 from Android Studio's bundled runtime; `npx --yes firebase-tools@15 emulators:exec --only firestore,storage --config firebase.emulators.json --project demo-everglow "node --test functions/security_rules.emulator.test.js"`: both tests passed, none skipped.
- The notification regression test fails on the original trigger code (`mood` versus `mood_update`), then passes on this branch. The new room emulator test fails on original rules with 403 versus 200, then passes on the fixed rules.
- `flutter build web --release --no-pub`: passed.

## Browser proof

T3 Preview snapshot calls timed out twice with `Preview automation snapshot timed out after 15000ms`. Validation used the repository's disposable Chrome/CDP harness, serving the release build at http://127.0.0.1:8752.

At both 430x932 and 810x932, Money, Gallery, Subscriptions, Trip Kit and Our Books rendered the expected demo screen without an error page. The HUD was collapsed. Money displayed the expected fictional balance of 1,750 pesos; tapping Add opened the spending form, and Escape closed it. The screenshots were inspected after capture.

- money-430.png: phone money summary and demo budget.
- money-810.png: tablet money summary.
- money-dialog-430.png: phone spending form opened by its Add control.
- gallery-430.png: phone gallery with synthetic artwork.

The 81-photo widget/query tests prove Load older photos requests the next batch and search reaches a record beyond the newest 50. The money dialog tests inject a failed save, check the amount/note remain, and retry successfully. Screenshots alone do not prove those failure cases.

Not verified: delivery to actual FCM devices, real phone/tablet simultaneous sessions, external catalog availability, and physical-device performance. Real couple records were not read or changed.
