# Everglow — AGENTS.md

You : youre the agent who will help work with khent to develop this project.
Khent : the person who is talking to you and the one who is working with you to help develop this project.
Clair : the girlfriend of Khent, shes the user of this project, so basically this project is all for her and well be doing our utmost to better enhance her experience here in this project and develop this project to our full ability.

# Everglow

A private love-letter app for Khent and Clair.
Live at https://everglow-1c6db.web.app. Version in `react/package.json`.

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
- **Trust the code over the docs.** Docs, READMEs and these notes can go stale; the code already has features the docs never mention. Check the real files before you decide anything, and when you catch a doc that no longer matches the code, say it in one line: `Stale doc: <path> says X, code does Y.`
- The rest of this document is meant to help you navigate the codebase and make changes effectively. Think of these instructions less as "hard rules", more as "good defaults". The developer's preferences should be able to override anything here.

## Where things live

* Start: `react/src/main.tsx` - starts service worker registration, then renders `react/src/App.tsx`.
* Firebase & Auth: `react/src/core/services/` (`firebase.ts`, `auth.ts`, `notifications.ts`).
* Pages & Routes: `react/src/App.tsx` wires all routes cleanly to feature modules under `react/src/features/<name>/`.
* Looks: use `react/src/core/theme/` for colors and spacing (`colors.ts`, `paint.ts`, `typography.ts`). Use `react/src/shared/widgets/` for buttons, cards, and UI primitives. Never hardcode colors.
* Features: small self-contained modules under `react/src/features/`, with services and React components alongside each other. Motchi lives under `react/src/features/ai/`; the floating companion lives under `react/src/features/guardian/`.
* Helpers: `react/src/core/` holds app-wide agent mode, router memory, viewport/update services, and audio/TTS helpers. Services that need logout cleanup listen to the `everglow:logout` window event instead of importing `authService` (importing `authService` from feature services causes circular-init mount crashes).
* Shelf widgets: `react/src/shared/widgets/shelf/` is media browsing UI shared by cinema/anime/books (posters, carousels).
* Server: `functions/` talks to movies, music, and AI (`index.js` only wires modules together). The app never calls those sites directly.
* Streaming Worker: `cloudflare/` hosts the HLS streaming Worker (`cloudflare/src/worker.js`, `cloudflare/src/anime.js`). `cloudflare/src/anime.js` re-exports from `functions/hls_player.js`, so any edit to `functions/hls_player.js` must also run `npm --prefix cloudflare test`. Test new stream providers through `wrangler dev --remote` (or `npm --prefix cloudflare run smoke`) before wiring them — residential IPs pass where Cloudflare's edge gets 403.
* Rules: `firestore.rules` decides who sees what.

## Workflow — how we ship (agreed with Khent)

Ship through the `everglow-pr` skill
(`.agents/skills/everglow-pr/SKILL.md`) — before committing, opening a PR,
or merging, and for any "is this done?" judgement. Review passes also enforce
[`CODING_STANDARDS.md`](CODING_STANDARDS.md).

Three rules never bend, even if the skill is not loaded:

- **Never push to `main`.** It auto-deploys live to Clair. One task, one branch.
- **Run the checks before every PR** — `node tool/ci/verify_all.mjs` (or individually: `npm --prefix react run typecheck`, `npm --prefix react run lint`,
  `npm --prefix react run build`, `npm --prefix react test`,
  `node tool/ci/run_checks.mjs`, `node tool/agent_smoke.mjs react/dist`,
  and `node --test tool/ci/*.test.mjs`).
- **Every PR shows proof** — a screenshot in `docs/pr-proof/`, or an
  honest N/A. Fake demo data only, never real couple data. Capture with
  `node tool/capture_proof.mjs --route "<route>" --viewport phone --out docs/pr-proof/pr-<number>/<name>.png`
  (or `--pack <manifest.json>` for multi-shot packs; `agent=1&hud=0` is auto-added unless `--no-agent`) instead of ad-hoc Playwright scripts.

### Agent mode (testing without logins)

Add `?agent=1` or `?agent=<alias>` to any URL (`/?agent=cinema`,
`/manga?agent=1`) to start a simulated session and land on that page, no
passcode. Aliases live in `react/src/core/agent/agentMode.ts`.

- The floating HUD jumps between pages and switches profiles
  (Khent, Clair, Cinema guest). Add `&hud=0` to hide it for proof screenshots.
- Couple-only features read in-memory demo data from
  `react/src/core/agent/fixtures.ts`. Real couple data and private photos
  stay untouched, so agent mode is the place for proof screenshots.

### Browser checks

`npm --prefix react test` drives a real headless Chrome against `react/dist`
(build first; Node 22+; it refuses a stale build; set `CHROME_PATH` if
Chrome isn't found). It covers the shell, the offline service worker
(`react/tools/shell.test.mjs`, built by `buildServiceWorkerSource` in
`react/vite.config.ts`), the players, and media regressions.
`node tool/agent_smoke.mjs react/dist` checks `react/dist` freshness and visits
every agent destination in disposable headless Chrome (checking mount, fallback
text, and runtime errors). Pass one route alias as a third argument to reproduce
a single destination, then rerun the full sweep.

Record commands, pass/fail counts, and environment in the PR. When Chrome or
another prerequisite blocks a run, name the blocker and what stays unverified.
To rerun these on Linux, dispatch
`gh workflow run browser_checks.yml --ref YOUR_BRANCH -f suite=all --repo khentmoba/Everglow`
(or `shell` / `smoke`); ordinary PR updates never start it. Speed claims need
measurements, not passing tests. CI failures and runner recovery:
[`docs/CI_TROUBLESHOOTING.md`](docs/CI_TROUBLESHOOTING.md). Removing a
worktree: [`docs/WORKTREE_CLEANUP.md`](docs/WORKTREE_CLEANUP.md).

## Releases — keep the version, README, and GitHub in sync

Full procedure lives in the `everglow-release` skill
(`.agents/skills/everglow-release/SKILL.md`). Load it when cutting a release.

The rule that never bends: `react/package.json`, the newest CHANGELOG entry,
and README must agree, or the release check in `tool/ci/run_checks.mjs`
fails the PR. The workflow publishes only on a version bump; a merge with
no bump does nothing.

## Watch-outs (learned from live breaks)

- **Privacy first:** couple-only data (chat, gallery, notes, garden, AI memories) is Khent + Clair only. Breyan / Octagram are movies-only. Cinema is shared with family guests, so keep its words neutral: no couple or romance framing. When touching Firestore or functions, re-check `firestore.rules` and keep TMDB / Last.fm / TokenHarbor keys server-side.
- **Main screen is fragile on web:** the Together zone broke live several times (grey cover, full-stack crash). Reproduce in Chrome first. Keep lists finite, avoid blur-over-big-area and pinned headers that jump.
- **Helpers need a login token:** the app never calls TMDB / Last.fm / AI models directly. It calls our cloud helpers with a Firebase login token. Don't add direct web calls or client keys.
- **Look locally before you look live:** never "fix live by redeploying to see". Details in the `everglow-pr` skill.
- **Hidden contracts** (stream proxies removed on purpose, legacy photo paths, the desktop bridge, OAuth scopes, the low-end motion gate): `docs/ARCHITECTURE.md` §6.5.
- **Redesigns keep the identity:** read `DESIGN.md` first. Improve page bodies, not just shared headers, and show the difference in before/after shots.
- **Score loops stop:** an AI score alone never means done — run an independent diff review by round 5 (before polishing past 8.5) and stop after 3 flat rounds within ±0.3 instead of pushing to 18–20 rounds.

## Shell

- Claude and Pi run Git Bash (tool: `bash`); OpenCode and Antigravity run Windows PowerShell 5.1 (where `&&`, `grep`, `rg`, `sed`, and `head` fail — use `;`, `git grep`, `Select-String`, and `node` scripts).
- Write files with the Write/Edit tools, never `cat <<EOF` or script heredocs (they mangle quotes and backslashes).
- In a fresh worktree run `node tool/ci/verify_all.mjs --install` (or `npm --prefix react ci`, `npm --prefix functions ci`, `npm --prefix cloudflare ci`) before running checks or tests.

## Rules that matter

* Never commit passcodes, keys, or secrets. `assets/env.txt` is local only - do not read it or copy it.
* Agents never create service-account keys, deploy temporary or diagnostic rules to production, run `wrangler deploy` by hand (merging deploys the Worker), or change IAM, even to fix a live outage. Ask Khent first.
* Login codes are checked on the server. Do not put them in the file.
* Keyless public catalogs (Open Library, Jikan) go through `proxyCatalog` with a login token when signed in. No direct third-party fetches from the client except `proxyBookText` candidates and cover/thumbnail `<img>` URLs.
* Live data is a `Source` from `react/src/core/utils/liveSource.ts`
  (`snapshots`, `withFirestoreTimeout`), read in components with `useSource`.
  Services keep state and expose `subscribe()`; no state libraries.
  On failure, call `Logger.e` (`react/src/core/system/logger.ts`) so it
  shows in release builds too.
* Imports inside `react/src/` are relative, like `../../core/theme/colors`.
* Components are PascalCase `.tsx`; routed pages end in `Page`. Services and
  helpers are camelCase `.ts`.

## How to talk

* Plain and simple words. No jargon unless Khent asks.
* Say what happened, why it matters for Clair, and what to do next.
* Put results and numbers in plain text in the reply first; a chart or HTML page is extra, never the only copy.
* Keep answers in a way that a normal human would be able to understand properly.
