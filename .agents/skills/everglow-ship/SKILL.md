---
name: everglow-ship
description: >
  The command order for shipping an Everglow change: branch off main, run
  flutter analyze, flutter test, every dart tool/ci guard and a Chrome look,
  attach proof, open the PR, then report honestly. Use when committing,
  opening a PR, merging, or when asked "is this done?". AGENTS.md holds the
  rules; this is only the runbook.
---

# Everglow ship runbook

**Rules live in AGENTS.md, `## Workflow — how we ship`.** If the two ever
disagree, AGENTS.md wins. This file is just the sequence and the paths.

## 0. Branch before you type

```
git status --short --branch      # state your folder + branch in your first reply
git checkout main && git pull    # only when the tree is clean
git checkout -b <type>/<slug>    # one task, one branch
```

Someone else's uncommitted changes in the checkout? Stop and move them first.
Never commit on `main`.

## 1. Checks, in order — stop on red

```
flutter analyze
flutter test --exclude-tags="golden,network"
ls tool/ci/                      # then run each. never guess a guard name
dart tool/ci/<name>.dart
flutter run -d chrome            # only if the change is visual
```

Touched `functions/`? `cd functions`, then `npm run lint -- --max-warnings=25`,
`npm test`, `node eval_gate.js`.

## 2. Proof

One shot of just the changed screen into `docs/pr-proof/pr-<number>/`, fake
demo data only, embedded by SHA so it survives the branch being deleted:

```
![what changed](https://raw.githubusercontent.com/khentmoba/Everglow/<sha>/docs/pr-proof/pr-<number>/shot.png)
```

Docs-only or non-visual: mark it N/A honestly. A shot of the preview booting
logged-out is acceptable evidence that it still builds.

## 3. Land it

```
git push -u origin <branch>
gh pr create --base main --title "<type>(<scope>): <what>" --body-file <body>
```

Check the auto-posted preview link (12h) before asking Khent to review.

## 4. Report honestly

Name the checks you actually ran, where the evidence lives, and what is still
unverified. "The worker said it passed" is not evidence you checked.

Pi sessions only: `.pi/extensions/everglow_verify_gate.ts` mechanically blocks
commits with no verification run, PRs with no proof, and invented
`dart tool/...` names. Every other harness relies on the judgment above.