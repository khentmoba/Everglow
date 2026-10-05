# Everglow — AGENTS.md

You : youre the agent who will help work with khent to develop this project.
Khent : the person who is talking to you and the one who is working with you to help develop this project.
Clair : the girlfriend of Khent, shes the user of this project, so basically this project is all for her and well be doing our utmost to better enhance her experience here in this project and develop this project to our full ability.

# Everglow

A private love-letter app for Khent and Clair.
Live at https://everglow-1c6db.web.app. Version in `pubspec.yaml`.

Clair is the one we are building for. Everything should feel warm,
simple, and obvious to her. Clair mainly uses Phone and a Tablet so always make sure that its perfect on those.

## Khent's note (how to work)

- I like ambitious ideas, simple systems, and software that feels obvious.
- Do not preserve complexity just because it already exists. Do not introduce machinery because it looks architecturally impressive.
- Understand the real constraint, then fight for the smallest model that makes the correct behavior unsurprising.
- Channel both "measure twice, cut once" and "yagni". Fight scope creep.
- Try to honor the dev's intent in both a minimal and realistic fashion.
- Clair loves watching movies and series so the cinema is an important factor to us and i think netflix has basically the best experience people can have while watching so thats exactly why we made it netflix inspired.
- Overall this is all for Clair and Me so the idea here is that this is a couple site for us two in which this is basically the software kind of core for "us" so we will iterate and improve this as time goes by with the core purpose of this website as something a couple (me and clair) would basically need and love to have, like a software proof of the existence of our love,
- The rest of this document is meant to help you navigate the codebase and make changes effectively. Think of these instructions less as "hard rules", more as "good defaults". The developer's preferences should be able to override anything here.

## Where things live

* Start: `lib/main.dart` - starts Firebase, then opens `EverglowApp`.
* Setup: `lib/core/di/app_providers.dart` - this is where services are created. Do not add setup in `main.dart`.
* Pages: `lib/core/router/app_router.dart` just joins pages together. Each feature keeps its own pages under `lib/features/<name>/presentation/routes/`.
* Looks: use `lib/core/theme/` for colors and spacing (`app_colors.dart` for UI, `app_art.dart` for decorative art). Use `lib/shared/widgets/everglow/` for buttons and cards. Never hardcode colors.
* Features: about 30 small parts under `lib/features/`. Full list is in `README.md`. Each one is `data/` -> `presentation/`, plus `domain/` only when it needs repository interfaces or shared models.
* Helpers: `lib/core/utils/` is app-wide (logging, streams, connectivity). `lib/shared/utils/` is data helpers (proxies, pagination, text, images).
* Shelf widgets: `lib/shared/widgets/shelf/` is media browsing UI shared by cinema/anime/books (posters, carousels). Everything else shared goes in `everglow/`.
* Server: `functions/` talks to movies, music, and AI (`index.js` only wires modules together). The app never calls those sites directly.
* Rules: `firestore.rules` decides who sees what. |

## Workflow — how we ship (agreed with Khent)

Written for EVERY agent (Pi, Codex, Antigravity, etc.). Follow it
exactly as written — no Pi-only tools required.

### 1. Start clean — one task, one branch, one folder

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

### 2. Before every PR — run the checks

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

### 3. Every PR shows proof

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

### Definition of done — proof over confidence

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

## Releases — keep the version, README, and GitHub in sync

Releases publish automatically, but ONLY when the version number
changes. The old automation released every deploy with date tags and
cluttered the page, so Khent removed it (see `4b451a2`). The current
`release.yml` workflow is different: it watches `pubspec.yaml` on `main`
and cuts exactly one tag + GitHub Release per version, using the
CHANGELOG entry as the notes. Merges without a version bump do nothing.

Cut a release when user-visible fixes or features have piled up, or when
Khent asks for one. One release PR per version:

1. Pick the next version: patch (`6.1.1`) for fixes, minor (`6.2.0`) for
   features, major (`7.0.0`) for big changes.
2. Bump it in BOTH `pubspec.yaml` (`version: X.Y.Z+N`) and
   `lib/core/system/app_version.dart` (`current`).
3. Add a `## [X.Y.Z] - YYYY-MM-DD - Nickname` section on top of
   `CHANGELOG.md`. Write for Clair: short, warm, grouped by what she
   will notice. The workflow publishes this text as-is, so proofread it.
4. Update `README.md`: the `Latest Release` section mirrors the new
   CHANGELOG entry, and `Release History` gains one linked line
   (`.../releases/tag/vX.Y.Z`). Move the old latest into the history list.
5. Open the release PR. Checks must pass, including the release-sync
guard (`tool/ci/check_release_sync.dart` fails the PR when the version,
CHANGELOG, and README disagree).
6. Merge. The release workflow tags the merge commit and publishes the
GitHub Release by itself — nothing to run by hand.
7. Open the releases page and confirm the new version shows, with the
README badge following it. If the workflow ever fails, publish by hand
as fallback: `git tag vX.Y.Z main && git push origin vX.Y.Z`, then
`gh release create vX.Y.Z --title "vX.Y.Z — Nickname" --notes-file <entry>`.

Rules: never add release steps to `deploy.yml` (releases trigger on
version bumps, not on every deploy). Never date-based tags
(`v2026.06.12` was deleted for this reason). Never move a published
tag — if a release is wrong, cut a new patch version instead.


## Watch-outs (learned from live breaks)

- **Privacy first:** couple-only data (chat, gallery, notes, garden, AI memories) is Khent + Clair only. Breyan / Octagram are movies-only. When touching Firestore or functions, re-check `firestore.rules` and keep TMDB / Last.fm / TokenHarbor keys server-side.
- **Main screen is fragile on web:** the Together zone broke live several times (grey cover, full-stack crash). Reproduce in Chrome first. Keep lists finite, avoid blur-over-big-area and pinned headers that jump.
- **Helpers need a login token:** the app never calls TMDB / Last.fm / AI models directly. It calls our cloud helpers with a Firebase login token. Don't add direct web calls or client keys.
- **History should stay readable:** tiny scoped commits (`fix(dashboard): ...`). One fix per commit so a bad deploy is easy to undo. No "fix live by redeploying to see" — look locally first.

## Web Search Policy (persistent user preference)

- Free first. TinyFish costs money (search $0.005/query, fetch $0.001/url, agent $0.016/step) from Khent's wallet, so do NOT use it by default. Same for any tool that shares the `TINYFISH_API_KEY`.
- Default to whatever free tools your harness gives you:
  - Quick search / research / docs / current info: built-in web search (Pi: `google_search`).
  - Read pages, click, fill forms, check Everglow live: built-in browser control (Pi: `agent_browser`), or plain `curl` via bash for simple pages.
- Only use the TinyFish CLI when free tools fail (bot protection, bulk structured JSON extraction, or geo-targeted results via `tinyfish search query --location --language`).
- Ask Khent first before any `tinyfish agent run` / `browser session` — those burn wallet fastest.
- Note: Motchi (Clair's AI) also uses TinyFish server-side for web search. Leave it for now, revisit if wallet drains.

## Rules that matter

* Only Khent and Clair see couple things like chat, photos, notes, garden, and AI memories. Breyan and Octagram only get movies.
* The app never talks to TMDB, Last.fm, or AI directly. It calls our server helpers with a login token. Keys stay on the server.
* Never commit passcodes, keys, or secrets. `assets/env.txt` is local only - do not read it or copy it.
* Login codes are checked on the server. Do not put them in the file.
* Keyless public catalogs (Open Library, Jikan) go through `proxyCatalog` with a login token when signed in. No direct third-party fetches from the client except `proxyBookText` candidates and cover/thumbnail `<img>` URLs.
* For live data use `.snapshots()`. If something fails, leave a `Logger.e` so we can see it in release too (raw `print` is banned by `avoid_print`).
* Use Provider only. No Riverpod, no Bloc.
* Use relative imports inside `lib/`, like `../../features/...`.
* Dart files are `snake_case`. Screens end in `Screen`.

## How to talk

* Plain and simple words. No jargon unless Khent asks.
* Say what happened, why it matters for Clair, and what to do next.
* Keep answers in a way that a normal human would be able to understand properly.
