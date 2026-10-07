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

Ship through the `everglow-pr` skill
(`.agents/skills/everglow-pr/SKILL.md`) — before committing, opening a PR,
or merging, and for any "is this done?" judgement.

Three rules never bend, even if the skill is not loaded:

- **Never push to `main`.** It auto-deploys live to Clair. One task, one branch.
- **Run the checks before every PR** — `flutter analyze`,
  `flutter test --exclude-tags="golden,network"`, and every
  `dart tool/ci/check_*.dart`. `ls tool/ci/` first; never invent a guard name.
- **Every PR shows proof** — a screenshot in `docs/pr-proof/`, or an
  honest N/A. Fake demo data only, never real couple data.

### Agent Mode & Local Testing (Direct Navigation & Privacy-Safe Demo Data)

Agents and local developers do not need real credentials or passcodes to test Everglow across the ENTIRE site:

- **Direct URL Jumps:** Append `?agent=1` or `?agent=<destination>` directly to the URL (e.g. `/?agent=anime`, `/?agent=manga`, `/?agent=books`, `/?agent=cinema`, `/?agent=dashboard`, or `/manga?agent=1`). This unlocks an isolated simulated session and navigates directly to the target feature without password prompts or redirect bounce loops.
- **Doorway Agent Fast-Jump Launchpad:** When on the gateway door (`/`), the bottom dev bar provides 1-click fast-jumps to **every single section of Everglow**: Cinema, Anime, Mangacelestia, Books, Dashboard, Sanctuary, Gallery, Journal, Tonight, Play Zone, Academy, Garden, Starlight, Calendar, Trip Kit, Jukebox, Canvas, Bucket List, Money, and profile pickers (Khent, Clair, Cinema Guest).
- **Floating Agent HUD:** A floating toolbar is present at the bottom of the screen across the app in dev / agent mode. Click route chips across all 20 surfaces to instantly jump between features, or toggle profiles (`Khent ⇄ Clair ⇄ Cinema`). Click the minimize (`—`) button to collapse the HUD into a tiny pill for clean PR proof screenshots.
- **Privacy-Safe Demo Fixtures:** In Agent Mode, all couple-only features (milestones, notes, mood, starlight, bucket list, calendar, chat, tonight, journal, gallery, date ideas, guardian) automatically feed isolated in-memory mock demo data. Real couple data and private photos are never touched or exposed.

### Manual browser tooling checks

Agents must run the relevant checks below before requesting review. Use
Node 22+ and a disposable Chrome profile; these tools do not need a login
or real couple data. Ordinary app edits do not require these tool tests.

- **Performance tools:** when changing `tool/perf/`, `lib/core/perf/`,
  the performance bench routes/fixtures, or the manual browser workflow,
  set `PERF_REQUIRE_CHROME=1`, then run
  `node --test tool/perf/harness.test.mjs`. In PowerShell set it with
  `$env:PERF_REQUIRE_CHROME = '1'`. Unset it afterwards. Requiring Chrome
  prevents a missing browser from producing a passing skipped suite.
- **Offline/update behavior:** when changing `tool/generate_sw.dart`,
  `tool/build_stamp.dart`, `tool/build_web.dart`, `tool/service_worker_test.mjs`,
  web loaders/worker, hosting cache configuration, or the manual browser
  workflow, run `node tool/service_worker_test.mjs --browser`.
  CI also keeps the deterministic worker tests on relevant web builds.
- When changing Quality's browser/build wiring, run both tooling checks
  and the browser-only Flutter tests listed in `.github/workflows/quality.yml`.
- Record commands, pass/fail counts, and environment in the PR. If Chrome
  startup or another missing prerequisite blocks a run, state the blocker
  and what remains unverified. Do not claim a skipped or incomplete run
  proves browser behavior; investigate test/measurement failures.

The **Manual browser checks** workflow is an opt-in Linux alternative once
it exists on `main`: run
`gh workflow run browser_checks.yml --ref YOUR_BRANCH -f suite=all --repo khentmoba/Everglow`
(or select `performance` / `offline`). It never runs on ordinary PR updates.
When available, use T3's PR watcher for PR checks rather than polling.
These tooling checks validate the measuring tools and offline behavior;
claims about app speed still need measurements described in `docs/PERF_NOTES.md``.
For CI failures, runner recovery, and preview commands, see
[`docs/CI_TROUBLESHOOTING.md`](docs/CI_TROUBLESHOOTING.md).
Before removing a worktree, follow [`docs/WORKTREE_CLEANUP.md`](docs/WORKTREE_CLEANUP.md).

## Releases — keep the version, README, and GitHub in sync

Full procedure lives in the `everglow-release` skill
(`.agents/skills/everglow-release/SKILL.md`). Load it when cutting a release.

The rule that never bends: version, CHANGELOG, and README must agree,
or `tool/ci/check_release_sync.dart` fails the PR. The workflow publishes
only on a version bump — a merge with no bump does nothing.

## Watch-outs (learned from live breaks)

- **Privacy first:** couple-only data (chat, gallery, notes, garden, AI memories) is Khent + Clair only. Breyan / Octagram are movies-only. When touching Firestore or functions, re-check `firestore.rules` and keep TMDB / Last.fm / TokenHarbor keys server-side.
- **Main screen is fragile on web:** the Together zone broke live several times (grey cover, full-stack crash). Reproduce in Chrome first. Keep lists finite, avoid blur-over-big-area and pinned headers that jump.
- **Helpers need a login token:** the app never calls TMDB / Last.fm / AI models directly. It calls our cloud helpers with a Firebase login token. Don't add direct web calls or client keys.
- **Look locally before you look live:** never "fix live by redeploying to see". Details in the `everglow-pr` skill.

## Rules that matter

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
