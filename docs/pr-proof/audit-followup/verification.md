# Audit follow-up verification

All data used by tests and screenshots is synthetic. No live account credentials
were read or rotated. No live deployment was performed.

## Findings addressed

1. Guest codes now go through `verifyPasscode`; guest emails/passwords/codes are
   removed from Flutter configuration and web-build inputs. Guest accounts keep
   their existing UID through the server's email lookup.
2. Shared authenticated helpers and the anime token gate require server-signed
   profile claims. Firestore denies self-created cinema profiles and old password
   tokens, including forged legacy profile documents.
3. Calendar writes and Canvas reads/writes bypass live Firebase in Agent Mode.
   The isolation test injects a Firestore boundary that throws on any access.
   Demo mutations deliberately do not persist; this is not a live-editing test.
4. Push failures return a delivery result. Reminders remain pending on temporary
   failures and record completed recipients before retrying the other partner.
5. Canvas grows its live query when full instead of hiding strokes after 300.
6. Canvas saves return the document ID; Undo deletes that ID and Redo keeps its
   newly saved ID. Failed Undo/Redo operations retain their history entries.
7. Storage upload validation is separate from owner-authorized deletion.
8. Spotify and Motchi use the same application-token helper/cache.
9. The unused `watchActiveRoomFor` query is removed.

## Checks run

Environment: Windows, Flutter 3.44.4 / Dart 3.12.2. Server and manual tooling
checks also ran under Node 22.23.3. Privacy emulators used local Java 21.0.10 and
`demo-everglow`, never the live project.

| Check | Result |
| --- | --- |
| `flutter analyze` | Passed; no issues |
| `flutter test --exclude-tags="golden,network" --reporter expanded` | 1,705 passed |
| Every `dart tool/ci/check_*.dart` (15 files, listed first) | Passed |
| Server ESLint, `--max-warnings=25` | Passed; 0 errors, 10 existing warnings |
| `node --test` in `functions/` under Node 22 | 355 passed; 5 emulator tests skipped in this command |
| `node eval_gate.js` under Node 22 | Passed |
| Firestore + Storage emulator security/push suites under Node 22 | 5 passed; no skips |
| `PERF_REQUIRE_CHROME=1 node --test tool/perf/harness.test.mjs` under Node 22 | 24 passed; no skips |
| `node tool/service_worker_test.mjs --browser` under Node 22 | 15 passed, including real offline Chrome; no skips |
| `flutter build web --release --no-source-maps` | Passed |
| Canvas persistence, Undo/Redo, and agent-isolation targeted rerun | 4 passed |

The emulator command was:

```sh
firebase emulators:exec --only firestore,storage --config firebase.emulators.json \
  --project demo-everglow \
  "npx --yes --package=node@22 node --test functions/security_rules.emulator.test.js functions/push_rules.emulator.test.js"
```

## Regression evidence

- Restoring the old Undo lookup inside the updated screen made the new widget
  regression fail: expected `['stroke-1']`, actual `[]`. It deleted A after B was
  erased. The fixed screen passes and verifies Redo's new ID too.
- Disabling query growth to restore the old 300-stroke behavior made the new
  persistence regression fail: expected 301 strokes, actual 300. The fixed
  service passes at 301 and remains live when the drawing grows to 600.
- These deliberate regressions were restored immediately; neither is in the diff.
- Server tests verify unapproved accounts stop before the catalog fetch, both
  guest codes issue signed profile tokens, and temporary push failures retry only
  the unfinished recipient.
- Emulator tests verify owner Storage deletion succeeds while partner/guest
  direct deletion is denied. Partner gallery deletion retains its server helper.

## Browser proof and remaining blocker

`canvas-phone.png` (430 x 900) and `canvas-tablet.png` (810 x 1080) are real local
release-browser screenshots of `/canvas?agent=1`, with the HUD minimized.
They prove initial layout only, not persistence, real login, or live sync.
The browser also logged an initial `didChangeViewFocus` / RenderBox layout error
while resizing before first paint, plus a denied synthetic presence lookup;
the Canvas screen subsequently rendered. Do not claim an error-free browser run.

The eight browser-only Flutter tests listed in Quality stalled at the initial
`loading` step locally. A separate single-file check of
`test/core/system/web_standalone_browser_test.dart` with headless Chrome also
failed to start within a 90-second process budget. The test processes and their
children were stopped. This is incomplete verification, not a passing suite.
Keep the PR draft until the browser-only suite is verified, for example on CI.

## Deployment and privacy

Before release, confirm all four server-side `*_PASSCODE` and `*_EMAIL` secrets
exist. Codes must be distinct and four digits. Hosting now waits for a successful
backend/rules deployment. Old password-based cinema sessions must log in again.
Treat previously shipped guest passwords as public and rotate them separately in
Firebase Auth. This change does not rotate live passwords or verify live codes.
