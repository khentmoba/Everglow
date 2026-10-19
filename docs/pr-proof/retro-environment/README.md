# All-thread retro: environment fixes

Nonvisual change. Screenshot proof: N/A. No Flutter screen, manifest, service
worker, account data, or credentials changed. The SDK pin uses the version
already verified in the previous successful deployment: Flutter 3.47.7.
The PC was upgraded from 3.44.4 to match. The four lockfile changes are
Flutter test/SDK dependencies resolved by `flutter pub get`.

## Scope

- All Flutter workflows read the one exact version in `pubspec.yaml`.
- The shipping skill points to the existing `/screen_test.html` install
  page. The earlier retro missed this existing fix; another manifest
  change would duplicate it. Real iPhone confirmation remains required
  for future changes to installed-app behavior.
- Bug verification covers fresh and existing state.
- Helper agents default to Luna; Cinema copy stays neutral for family.
- Ready PRs require an explicit `Still to do` section. Empty headings
  and template comments fail. Drafts can still report blockers honestly.

## Windows checks

Environment: Flutter 3.47.7 stable, Dart 3.13.5, Node 24.21.0, installed
Google Chrome with disposable test profiles.

- `flutter analyze`: zero issues.
- `flutter test --exclude-tags="golden,network"`: 1,705 passed.
- `ls tool/ci/`, then every `dart tool/ci/check_*.dart`: all 15 passed.
- `node --test tool/ci/changes.test.mjs tool/ci/pr_contract.test.mjs tool/remove_worktree.test.mjs`:
  27 passed, zero skipped.
- Red/green proof: the current four PR-contract tests against the original
  `pr_contract.mjs` produced two failures (missing follow-ups were accepted).
  Against this branch all four pass, including CLI and comment-only cases.
- `PERF_REQUIRE_CHROME=1 node --test tool/perf/harness.test.mjs`:
  24 passed, zero skipped. The environment override applied to that command
  only; it is not left set.
- `node tool/service_worker_test.mjs --browser`: 15 passed, zero skipped.
- `node --test tool/service_worker_test.mjs tool/web_bootstrap_test.mjs`:
  27 passed, one expected browser opt-in skip. The explicit browser run above
  ran that control; this deterministic-only run is not browser proof.
- `dart tool/build_web.dart -- --release --no-source-maps`: passed.
- `node tool/agent_smoke.mjs build/web`: all 64 phone/tablet alias visits
  rendered at 430px and 810px. This proves release boot/navigation, not
  real-account playback, editing, sync, or iPhone installation.

The eight-file Flutter Chrome suite from Quality was attempted with verbose
logging and an outer 180-second timeout. Compilation and Chrome startup
completed, but no test loaded before the deadline (exit 124). The subsequent
`Connection closed before test suite loaded` messages came on termination;
they are not a proven root cause. Linux CI must verify this suite separately.
The Chrome tooling and release smoke successes do not replace it.

## Cleanup already applied outside the diff

- Enabled GitHub's `delete_branch_on_merge` setting.
- Deleted 322 stale remote branch refs: 220 reachable from `origin/main`,
  then 102 whose head SHA exactly matched a merged PR. Left unmatched or
  divergent branch heads untouched. Remote refs: 439 to 117 (including HEAD).
- Deleted 384 local branch refs: reachable from main or an exact merged-PR
  head. Kept `main` and every checked-out worktree branch. Local refs: 452
  to 68. No worktree folders were removed.
- Archived 41 imported placeholder, failed-start, or short interrupted
  threads. Archiving is reversible; threads were not deleted.

## Follow-ups with durable owners

- Khent: [rotate old guest-account passwords](https://github.com/khentmoba/Everglow/issues/529).
  No live credentials were changed. Do not post values or account details.
- Khent: [verify phone-to-PC anime resume](https://github.com/khentmoba/Everglow/issues/530)
  using Megavid, for both fresh and existing sessions.
- Agent follow-up: [investigate the Windows Flutter browser runner stall](https://github.com/khentmoba/Everglow/issues/531).

These are outstanding checks/actions, not outcomes claimed by this PR.
