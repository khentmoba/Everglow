# PR checks and recovery

## Private photos return 403 after a rules deployment

`storage.rules` checks the signed-in user's Firestore profile. The Firebase
Storage service agent needs `roles/firebaserules.firestoreServiceAgent` on the
project so these cross-service reads can run. Without it, valid couple logins
also receive 403 for archive and gallery photos.

Check the project's IAM policy for that role on
`service-220334592353@gcp-sa-firebasestorage.iam.gserviceaccount.com`.
Restore the cross-service permission through Firebase's rules setup if missing;
keep the profile and token checks in `storage.rules`. After a repair, verify
authorized access and denied guest/anonymous access. Allow time for IAM changes
to propagate. The October 21, 2026 incident was resolved by restoring this role.

## PR verification

Quality uses `tool/ci/changes.mjs` to select work from the base-to-merge
diff, including deleted paths. Every PR runs app analysis/tests, a release
web build, Dart guards, and backend verification including the production
dependency audit. Every main push deploys the whole application, so even
docs-only PRs must verify those prerequisites. Only extra browser and privacy
emulator coverage is selected from the diff. Unknown inputs and failed diff
discovery select everything. `workflow_dispatch` also runs full verification.

The guards share Flutter setup with app verification. The release web build
runs deterministic service-worker tests and uploads its artifact once. No PR
deploys a preview channel: proof screenshots come from a local release build
(`flutter build web --release`) driven in headless Chrome, which is what the
proof workflow in the `everglow-pr` skill does. Nothing about a PR is
reachable on the internet until it merges and `main` deploys.

The release build also runs `node tool/agent_smoke.mjs build/web` in
disposable Chrome. It visits every agent alias at 430px and 810px, starting
with a saved Journal location, and checks the destination URL and rendered
screen with the HUD collapsed. This proves navigation and initial rendering;
it does not prove catalog availability, playback, editing, or live sync.
Use Node 22+ and installed Chrome locally. Pass an alias as a third argument
to reproduce one failure, then rerun the complete sweep after fixing it.

Ready PRs also run `tool/ci/pr_contract.mjs` on body edits. Use the PR
template, record actual check results, and pin screenshots to the commit
containing them. The guard checks declarations and files, not whether a
claimed test ran. Keep incomplete verification in a draft.

Performance-tool browser controls and the real-browser offline control are
manual, with required local checks documented in `AGENTS.md`. They are not
ordinary PR jobs. The opt-in workflow runs the two suites independently so
one failing suite cannot prevent the other from running:

```sh
gh workflow run browser_checks.yml --ref YOUR_BRANCH -f suite=all --repo khentmoba/Everglow
```

Quality and deployment both install the committed backend lockfile with
`npm ci` and run `npm run verify` in `functions/` (lint, tests, syntax, eval
gate, and production dependency audit). The Dependency audit workflow also
checks `main` daily at 06:00 UTC for newly reported vulnerabilities.

PRs #543–#545 merged successfully but deployment stopped on the same
`body-parser` advisory (GHSA-27r3-jxmh-p828). Frontend PRs had skipped the
backend audit. Updating the lockfile and making these prerequisites mandatory
closes that gap; `tool/ci/deploy_parity.test.mjs` guards against recurrence.
A green PR verifies the candidate merge at that time. Firebase outages,
credential changes, newly published advisories, or subsequent base changes
can still fail a later deployment; green checks cannot guarantee those.

Read the failed job's annotations and logs before changing code.

## Flutter version mismatch

`pubspec.yaml` → `environment.flutter` pins the SDK used by all Flutter
workflows via `flutter-version-file`. Check `flutter --version` locally
before diagnosing a CI-only analysis or compilation failure. Install that
same SDK version on the PC; change the pin and local SDK together when
upgrading. Do not downgrade CI just to match an old local installation.

## Profile login rollout

All four profiles now use the server's `verifyPasscode` endpoint. Never put
profile emails, passwords, or codes in Flutter build arguments or client assets.
The deployment requires `CLAIR_PASSCODE`, `KHENT_PASSCODE`, `BREYAN_PASSCODE`,
`OCTAGRAM_PASSCODE` and the matching four `*_EMAIL` secrets on the server.
Use four different four-digit codes; duplicate codes fail closed.

Deploy the functions and rules before the client. Hosting now waits for the
backend deployment to succeed. Existing guest accounts keep their Firebase UID
(and saved data) because the server finds them by their configured email.
Old password-based guest sessions are signed out and must enter their code again.
Guest accounts cannot read couple data.

Treat any guest password shipped by an older web build as public. Rotate those
passwords in Firebase Auth outside this code change; do not paste them in a PR.
No live credentials are changed by the tests or the code review.

## A job never acquired a runner

PR #476 had eleven jobs with no assigned runner and zero executed steps.
Their annotation was `The job was not acquired by Runner of type hosted even
after multiple attempts`. These jobs never reached checkout or tests.

For that specific failure, rerun only the failed jobs. Replace `RUN_ID` with
the failed workflow run's numeric ID:

```sh
gh run rerun RUN_ID --failed --repo khentmoba/Everglow
```

Read every other failure first: `--failed` also reruns jobs that failed tests.
Do not change application code, weaken a check, or add `continue-on-error` to
work around runner assignment. If assignment repeatedly fails, investigate
GitHub Actions availability and runner provisioning before retrying again.

## Chrome did not become ready

The performance launcher makes at most two startup attempts, each with a fresh
temporary profile and a ten-second discovery deadline. It stops the failed
process before deleting its profile and starting another. A retry warning
includes the first failure; a final failure includes both attempts.

Inspect the Chrome stderr tail, exit code or signal, endpoint advertisement,
version/page readiness and last discovery error. If the process cannot be
stopped or its profile cannot be removed, the launcher retains the profile and
refuses another attempt.

The retry applies only before Chrome becomes ready. Boot, navigation, missing
measurements, deliberate freeze controls and performance-budget failures are
never retried. The Quality jobs use `ubuntu-24.04` to avoid an automatic OS
migration; this pin does not guarantee runner availability or freeze Chrome's
installed version. The existing shared-memory flag remains in place, and the
manual browser jobs have ten-minute timeouts. A passing ordinary Quality run
does not establish that a manual browser suite passed.

## Cinema screenshot proof when Preview or debug Chrome stalls

Start with T3 Preview's status and open tools. A missing automation host is a
T3 runtime problem, not an Everglow compilation failure. Do not keep relaunching
the app to repair that host. If Preview works but debug Chrome waits for its
debugger connection, serve a release build using the existing SPA server:

```powershell
flutter build web --release --dart-define=AGENT_MODE=true
node --input-type=module -e "import { serve } from './tool/perf/_harness.mjs'; await serve('build/web', 8752);"
```

Open `http://127.0.0.1:8752/cinema?agent=1` for the simulated couple profile,
or `/cinema?agent=cinema` for the guest profile. The server supports direct
routes and reloads. Cinema's demo catalogue and drawer metadata use fictional
records without Firebase tokens or TMDB requests. Artwork uses the normal
empty-image fallback. Demo watchlists stay empty and never persist actions;
this mode does not verify real accounts, watchlist synchronization, or playback.

When browser screenshot capture is unavailable, the production drawer can be
rendered and exported by its regression test:

```powershell
flutter test --dart-define=PR_PROOF_PATH=C:/Users/Admin/AppData/Local/Temp/cinema-drawer.png test/features/cinema/agent_drawer_capture_test.dart
```

Choose an existing output directory. The test verifies chip bounds at 430px,
loads the app fonts, and exports an image of the actual `EpisodeDrawer`.
Both `RenderRepaintBoundary.toImage` and `Image.toByteData` run inside
`tester.runAsync`; raw RGBA pixels are encoded with the already-installed
`image` package. Awaiting renderer futures in the fake async zone can hang.
Use a bounded animation pump: the recommendation loader can keep animating,
so `pumpAndSettle` is not a suitable screenshot readiness condition here.

## Windows `flutter test --platform chrome` never loads the suite

On Windows, `flutter test --platform chrome <file>` can print `Running test suite`
and then report nothing, even for a one-line test. It can also end with
`Connection closed before test suite loaded`.

Cause, verified on Flutter 3.47.7 (Dart 3.13.5), Windows 11, Chrome 157. The test
page requests CanvasKit from `/canvaskit/chromium/canvaskit.js` and
`canvaskit.wasm`. Both return 404, the app fails to start, and the runner never
receives "loaded". In `flutter_tools` (`lib/src/test/flutter_web_platform.dart`,
`_localCanvasKitHandler`), `path.fromUri` returns `canvaskit\chromium\canvaskit.js`
on Windows, which never matches the `canvaskit/` prefix. Linux is not affected.
Upstream: flutter/flutter#193505 (open).

To confirm, attach DevTools to the test Chrome and look for 404s on
`canvaskit/chromium/canvaskit.*`.

Treat a local Windows browser-suite run as not run. The browser-only files in
Quality's `flutter` job are verified on Linux, and that result is authoritative
when the diff selects the browser step. `flutter test -d chrome` is not a
substitute: it runs on the Flutter tester, not in a browser.

Inspect the PNG before using it as proof. Label it as a widget render in the
PR, rather than claiming it proves the browser interaction or live data flow.
