# PR checks and recovery

Quality uses `tool/ci/changes.mjs` to select work from the base-to-merge
diff, including deleted paths. Docs-only PRs run selection tests and the
cheap Dart guards; app analysis/tests, web builds, backend tests and privacy
emulators run for their relevant inputs. Unknown inputs and failed diff
discovery select everything. `workflow_dispatch` also runs full verification.

The guards share Flutter setup with app verification. The release web build
runs deterministic service-worker tests and uploads its artifact once;
same-repo frontend PRs deploy that artifact as a 12-hour preview. Forks
build without secret defines and never deploy previews. To request a preview
on another branch (once this workflow is on `main`), run:

```sh
gh workflow run quality.yml --ref YOUR_BRANCH -f preview=true --repo khentmoba/Everglow
```

Preview waits for cache tests and release compilation, independently of the
other selected checks. A working preview is not proof that all CI checks passed.

Performance-tool browser controls and the real-browser offline control are
manual, with required local checks documented in `AGENTS.md`. They are not
ordinary PR jobs. The opt-in workflow runs the two suites independently so
one failing suite cannot prevent the other from running:

```sh
gh workflow run browser_checks.yml --ref YOUR_BRANCH -f suite=all --repo khentmoba/Everglow
```

Backend dependency changes retain `npm audit`; the Dependency audit workflow
also checks `main` daily at 06:00 UTC for newly reported vulnerabilities.
Deployment/release workflows on `main` are unchanged.

Read the failed job's annotations and logs before changing code.

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

Inspect the PNG before using it as proof. Label it as a widget render in the
PR, rather than claiming it proves the browser interaction or live data flow.
