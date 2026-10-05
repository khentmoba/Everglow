---
name: everglow-ship
description: >
  The full agreed procedure for shipping an Everglow change: one task one
  branch, the checks to run before every PR, proof screenshots, the
  proof-over-confidence definition of done, and how to report honestly. Use
  when committing, opening a PR, merging, or when asked "is this done?".
  AGENTS.md keeps only the three rules that must never bend.
---

# Everglow ship

Agreed with Khent. `main` auto-deploys live to Clair, so every change
travels by PR with proof. The three rules that never bend stay in
AGENTS.md; this is everything else.

Written for EVERY agent (Pi, Codex, OpenCode, Antigravity). No
harness-specific tools required.

## 1. Start clean — one task, one branch, one folder

- First thing every session: run `git status --short --branch` and say
  what folder + branch you're on in your first reply.
- Never edit on `main`. `main` auto-deploys live to Clair.
- New task = new branch from latest `main` (`fix/...`, `feat/...`,
  `docs/...`, `style/...`). One task per branch. If the checkout has
  someone else's uncommitted changes, stop and move first — don't mix.
- Work in your own folder: if your harness supports git worktrees, use
  one per task and delete it once merged. (T3 agents: hidden folders
  live in `C:/Users/Admin/.t3/worktrees/Everglow/...`, never as
  `Everglow-xxx` next to the main folder. `C:/APPLICATIONS` keeps only
  the real projects.)
- End clean: commit, push, open PR. Don't leave uncommitted files or
  old folders behind.

### Keep history readable

- Tiny scoped commits, conventional style: `fix(dashboard): ...`.
- One fix per commit, so a bad deploy is easy to undo.
- Never "fix live by redeploying to see". Look locally first.
- Never add `continue-on-error` or hide a failure.

## 2. Before every PR — run the checks

Run these in order. Red locally means don't open the PR yet:

1. `flutter analyze`
2. `flutter test --exclude-tags="golden,network"` (golden PNGs render
   differently per platform; network tests hit live external sites and
   can't pass in sandboxes)
3. `dart tool/ci/check_*.dart` — the regression guards. List them
   first with `ls tool/ci/` and run each one. NEVER guess a guard
   name or invent a `dart tool/...` command: if the file isn't there,
   the command doesn't exist.
4. `flutter run -d chrome` — actually open the app and look at what
   you changed. A typo fix doesn't need this; anything visual does.
5. If you touched `functions/`: `cd functions`, then
   `npm run lint -- --max-warnings=25`, `npm test`, and
   `node eval_gate.js`.

CI runs all of the above plus a release web build, the perf harness,
and emulator security tests on every PR. If any CI check fails, stop
and fix it. Do not add `continue-on-error` or hide failures.

## 3. Every PR shows proof

- Save a screenshot of just the changed screen under
  `docs/pr-proof/pr-<number>/` (phone width ~430px, compressed).
- Repo is public: couple-only screens (chat, gallery, notes, garden,
  AI memories) use FAKE demo data only — never real couple data.
- Embed it in the PR body with a raw URL pinned to the commit SHA
  (branches get deleted, SHAs don't):
  `![what changed](https://raw.githubusercontent.com/khentmoba/Everglow/<sha>/docs/pr-proof/pr-<number>/shot.png)`
- Non-UI change (CI, docs, backend-only): honestly mark N/A, or add a
  shot of the preview booting logged-out.
- Check the auto-posted preview link (alive 12 hours) before asking
  Khent to review.

## Definition of done — proof over confidence

Pi agents get mechanical reminders of the first three rules from
`.pi/extensions/everglow_verify_gate.ts`, but every rule below applies
to every agent, with or without it. CI judges green output — these
rules judge honesty:

- No commit after code edits without running the checks in step 2.
- No PR without a proof screenshot in `docs/pr-proof/` (or an honest N/A).
- Never invent a verification command — `ls tool/ci/` first.
- Reproduce a bug before fixing it, then repeat the same steps after. If
  reproduction is blocked, say what is missing instead of guessing around it.
- A diagnosis must cite the code you actually read. An untested explanation
  is a hypothesis — call it one.
- Match the evidence to the claim: a screenshot proves looks, not behavior.
  Interaction claims need the steps actually clicked.
- Copy patterns only after checking they are not obsolete workarounds.
  Frequency is not correctness. Fix the cause, not the symptom.
- Keep the task's size: a typo fix does not launch the app, a small fix does
  not grow into a refactor. Unrelated debt gets a note, not a detour.
- Finish with the result, the checks you actually ran, where the evidence is,
  and what is still unverified. Worker-reported success you did not check
  yourself is not your evidence.
- When the same mistake keeps coming back, turn it into a lint, a CI guard,
  or a rule here — not another review comment.