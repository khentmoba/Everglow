# Recovering a failed Quality run

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
installed version. The existing shared-memory flag and ten-minute job timeout
remain in place.
