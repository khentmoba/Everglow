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
