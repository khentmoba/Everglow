---
name: everglow-pr
description: >
  Opening a PR, committing a change, or merging in Everglow, and any
  "is this done?" judgement. `main` auto-deploys live to Clair, so this
  carries the branch rules, the checks that must pass first, the proof
  screenshot, and the PR body shape: summary, before/after evidence, and
  whether the merge is a one-way or two-way door.
---

# Everglow PR

Agreed with Khent. `main` auto-deploys live to Clair, so every change
travels by PR with proof. The three rules that never bend stay in
AGENTS.md; this is everything else.

Written for EVERY agent (Pi, Codex, OpenCode, Antigravity). No
harness-specific tools required.

## 1. Start clean — one task, one branch, one folder

- First thing every session: run `git status --short --branch` and say
  what folder + branch you're on in your first reply.
- Never edit on `main`. `main` auto-deploys live to Clair.
- New task = new branch from `origin/main`, never the local `main`
  ref: it goes stale and nothing fetches it (it was 381 commits behind
  once). Run `git fetch origin && git checkout -b <branch> origin/main`.
  Prefixes: `fix/...`, `feat/...`, `docs/...`, `style/...`.
  One task per branch. If the checkout has
  someone else's uncommitted changes, stop and move first — don't mix.
- Work in your own folder: if your harness supports git worktrees, use
  one per task. Before cleanup, follow `docs/WORKTREE_CLEANUP.md` and use
  `node tool/remove_worktree.mjs`; keep folders owned by unsettled threads.
  (T3 agents: hidden folders
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

0. **Code hygiene:** Run the `no-comments` skill (load its discovered global path; fallback `C:/Users/Admin/.agents/skills/no-comments/SKILL.md`) to remove redundant comments only within the task diff. Preserve constraints and tool directives; propose behavioral changes separately.
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
5. If you touched `functions/`: `cd functions`, then `npm ci` and
   `npm run verify` (the same lint, tests, syntax, eval, and production audit
   gate used by Quality and deployment).

CI runs every deterministic deployment prerequisite on every PR: app
analysis/tests, a release web build, Dart guards, and the shared backend
`npm run verify` gate (including the production dependency audit). Main
deploys the whole application even for docs-only changes. The PR diff
selects extra browser-only app tests and privacy emulator coverage.
Unknown inputs or an unavailable diff run the full set.
If any selected CI check fails, stop and fix it. Do not add
`continue-on-error` or hide failures.

Run the relevant manual browser tooling checks required by `AGENTS.md`
before requesting review, and record their results or blockers in the PR.
Performance-tool controls and the real-browser offline check are opt-in;
ordinary Quality success does not prove that those browser checks passed.

## 3. Every PR shows proof

- Save a screenshot of just the changed screen under
  `docs/pr-proof/pr-<number>/` (phone width ~430px, compressed).
- Treat every screenshot as if the repo were public: couple-only screens
  (chat, gallery, notes, garden, AI memories) use FAKE demo data only —
  never real couple data. The repo is private today, but a repo can be
  made public by one settings change, and a leaked photo cannot be
  un-leaked.
- **Agent Mode for Proof Screenshots & Verification:**
  - Directly open any destination across the entire site via query parameter: `/?agent=anime`, `/?agent=manga`, `/?agent=books`, `/?agent=cinema`, `/?agent=dashboard`, etc., or by appending `?agent=1` to any deep link.
  - Or click any of the 1-click fast-jump destination chips on the doorway launchpad (Cinema, Anime, Mangacelestia, Books, Dashboard, Sanctuary, Gallery, Journal, Tonight, Play Zone, etc.).
  - In Agent Mode, password gates are bypassed and all couple surfaces automatically render safe in-memory demo fixtures.
  - Use the floating Agent HUD at the bottom across all 20 surfaces to jump between screens or switch profiles (`Khent ⇄ Clair ⇄ Cinema`). Click the minimize button (`—`) on the HUD before snapping the proof screenshot.
- **iPhone Home Screen changes** (status bar, bottom strip, installed
  launch): Chrome cannot prove these. Serve the local release build on the LAN
  (e.g. `python -m http.server 8752 --directory build/web` — note `serve()` in
  `tool/perf/_harness.mjs` is loopback-only) and ask Khent to open
  `http://<pc-lan-ip>:8752/screen_test.html` in Safari and follow that page's
  install steps (the live site blocks agent mode, so it cannot be used for
  this). Its dedicated launch page restores demo mode even with fresh iOS
  storage; ordinary `?agent=` links do not guarantee an installed launch. Until
  he confirms, say "unverified on iPhone" and keep the PR draft. Give him only
  steps you have seen on that screen.
- Embed it in the PR body with a raw URL pinned to the commit SHA
  (branches get deleted, SHAs don't):
  `![what changed](https://raw.githubusercontent.com/khentmoba/Everglow/<sha>/docs/pr-proof/pr-<number>/shot.png)`
- **That image will not render, because the repo is private.** GitHub's
  image proxy cannot authenticate, so `raw.githubusercontent.com` answers
  404 for every file here — the embed shows Khent a broken image. Keep it
  anyway: `tool/ci/pr_contract.mjs` requires the raw embed and checks the
  file exists at that SHA. Then put a signed-in link directly under it, so
  the proof is actually viewable:
  `If that image does not render: this repo is private, so GitHub's image proxy cannot fetch a raw.githubusercontent.com URL. Open [docs/pr-proof/pr-<number>/shot.png](https://github.com/khentmoba/Everglow/blob/<sha>/docs/pr-proof/pr-<number>/shot.png?raw=true) while signed in to GitHub instead.`
- Non-UI change (CI, docs, backend-only): honestly mark N/A, or add a
  shot of the app booting logged-out from your local build.
- **There are no PR previews.** No channel deploys and no preview link is
  posted. Prove a frontend change from a local release build instead:
  `flutter build web --release`, serve `build/web` on a spare port, and drive
  it in headless Chrome with `?agent=1`. Say in the PR body that the shot came
  from a local build, and never imply a preview proved it.

## 4. Write the PR body

Four sections, no preamble. Khent should be able to read the body and
know whether to merge without opening a single file.
Use `.github/pull_request_template.md`. Quality checks its required fields
on PR creation, code pushes, body edits, and draft changes. Keep blocked
proof or verification in a draft; visual proof cannot be N/A because capture failed.

All PR titles and bodies must follow the **unslop** skill (load its discovered global path; fallback `C:/Users/Admin/.agents/skills/unslop/SKILL.md`).

### Summary — the smallest thing that makes the change obvious

Pick ONE view. Never list every file.

Logic or state change, as plain steps:

```text
onSave(letter)
  if text is unchanged
    return the cached draft
  write to Firestore
  return the fresh draft
```

UI change, as a widget tree with the state that actually matters:

```text
<TogetherScreen>            lib/features/together/presentation/routes/
  TogetherZone()
    PosterRail()            lib/shared/widgets/shelf/
    _isLoading              // guards the grey-cover bug
```

File layout or a wide refactor, as a shallow tree:

```text
lib/features/notes/
  data/     # Firestore, snapshot stream
  routes/   # the screen
```

When the shape already exists and the point is what moved, use a diff:

```diff
 <ShelfRow>
   <PosterTile>
+    <WatchBadge />
   <TitleText>
```

### Evidence — before and after

Screenshots are the best proof when the change is visual. Before and
after, both real, both taken from this branch. Execution output is next
best: show the check that fails before the fix and passes after.

Match the evidence to the claim. A screenshot proves how it LOOKS, not
that it WORKS. If you claim a tap, a scroll, or a sync works, show the
steps or say plainly that you only proved the look. No exceptions.
Inspect each image: it must show the changed screen, not the gateway.
Record `Analysis:`, `Tests:`, `Guards:`, and `Browser:` as `passed - details`
or `N/A - reason`. Record `Review:` as `independent - reviewer` or `self - why no independent review ran`. If a reviewer fails (quota, timeout), write `self` and say so; never delete the line. Include commands, counts, and applicable server/manual
browser checks. CI validates declarations and pinned files, not their truth.

### Merge Danger — call it honestly

Say whether this is a one-way or two-way door, and how far the blast
reaches. A two-way door is cheap to walk back, so say so — it makes
review fast. A one-way door needs Khent to look properly.

- **Two-way door** (safe to undo): a layout fix, a copy change, a new
  read-only screen. `git revert` and you are back.
- **One-way door** (hard or impossible to undo): anything that changes
  what already exists for Clair — Firestore documents or rules, a
  `functions/` change, a released version, deleted data, a migration.
  These reach a live user on merge.

Assess the **Blast radius** following the **blast-radius** skill (load its discovered global path; fallback `C:/Users/Admin/.agents/skills/blast-radius/SKILL.md`):
do not guess or speculate. State the **one core safety fact** the change depends on. Report the verification level reached (1-5) and paste the proof, or write **Unproven**.

One-liners are fine:

```markdown
**Door:** one-way
**Blast radius:** every couple-only note loses its old `body` field
unless `functions/` backfills it first. (Proven, level 4: migration dry-run passed)
```

On a one-way door, add one sentence on what happens if this is wrong
and how to undo it. That sentence is what lets Khent say yes.

### Still to do — what outlives the thread

List what Khent must do or check after merge: change a password, test on
the iPhone, try a phone-to-PC handoff. Write `None` if nothing. A final
chat reply disappears when the thread settles; the PR body stays.

## Definition of done — proof over confidence

Pi agents get mechanical reminders of the first three rules from
`.pi/extensions/everglow_verify_gate/index.ts`, but every rule below applies
to every agent, with or without it. CI judges green output — these
rules judge honesty:

- No commit after code edits without running the checks in step 2.
- No PR without a proof screenshot in `docs/pr-proof/` (or an honest N/A).
- No PR without a Merge Danger line. Two-way door is a real answer; a
  missing line is not.
- Never invent a verification command — `ls tool/ci/` first.
- Reproduce a bug before fixing it, then repeat the same steps after, from
  both a fresh start and existing state (new chat and old chat, first load
  and later loads). If reproduction is blocked, say what is missing instead
  of guessing around it.
- A diagnosis must cite the code you actually read. An untested explanation
  is a hypothesis — call it one.
- Match the evidence to the claim: a screenshot proves looks, not behavior.
  Interaction claims need the steps actually clicked.
- A claim that a behavior works app-wide (copy, selection, focus, back) needs a check for each surface it claims: page, dialog, bottom sheet, phone and tablet. One surface passing does not prove the rest. Copy that worked on pages did not prove copy in popups (PR 556 needed PR 558).
- Copy patterns only after checking they are not obsolete workarounds.
  Frequency is not correctness. Fix the cause, not the symptom.
- Keep the task's size: a typo fix does not launch the app, a small fix does
  not grow into a refactor. Unrelated debt gets a note, not a detour.
- For performance work, reproduce and measure the target interaction before
  planning tooling. Report tooling repair separately from user-visible
  improvement. Keep an unmet device target open and name the missing evidence.
- Finish with the result, the checks you actually ran, where the evidence is,
  and what is still unverified. Worker-reported success you did not check
  yourself is not your evidence.
- When the same mistake keeps coming back across threads or sessions,
  turn it into an architecture change, a type constraint, or a CI guard
  (`tool/ci/check_<name>.dart`), not another review comment. Prose is the last resort, only when no machine check can catch it.
  The unified `retro` skill (and `correct`) exists for exactly this: run it
  to turn repeat mistakes into deterministic guards.
