# Everglow — AGENTS.md

You : youre the agent who will help work with khent to develop this project.
Khent : the person who is talking to you and the one who is working with you to help develop this project.
Clair : the girlfriend of Khent, shes the user of this project, so basically this project is all for her and well be doing our utmost to better enhance her experience here in this project and develop this project to our full ability.

# Everglow

A private love-letter app for Khent and Clair.
Live at https://everglow-1c6db.web.app. Version in `pubspec.yaml`.

Clair is the one we are building for. Everything should feel warm,
simple, and obvious to her.

## Khent's note (how to work)

- I like ambitious ideas, simple systems, and software that feels obvious.
- Do not preserve complexity just because it already exists. Do not introduce machinery because it looks architecturally impressive.
- Understand the real constraint, then fight for the smallest model that makes the correct behavior unsurprising.
- Channel both "measure twice, cut once" and "yagni". Fight scope creep.
- Try to honor the dev's intent in both a minimal and realistic fashion.
- The rest of this document is meant to help you navigate the codebase and make changes effectively. Think of these instructions less as "hard rules", more as "good defaults". The developer's preferences should be able to override anything here.

## Where things live

* Start: `lib/main.dart` - starts Firebase, then opens `EverglowApp`.
* Setup: `lib/core/di/app_providers.dart` - this is where services are created. Do not add setup in `main.dart`.
* Pages: `lib/core/router/app_router.dart` just joins pages together. Each feature keeps its own pages under `lib/features/<name>/presentation/routes/`.
* Looks: use `lib/core/theme/` for colors and spacing. Use `lib/shared/widgets/everglow/` for buttons and cards. Never hardcode colors.
* Features: about 30 small parts under `lib/features/`. Full list is in `README.md`. Each one is `data/` -> `domain/` -> `presentation/`.
* Server: `functions/index.js` talks to movies, music, and AI. The app never calls those sites directly.
* Rules: `firestore.rules` decides who sees what. |

## Workflow — how we ship (agreed with Khent)

- Never push straight to `main`. `main` auto-deploys live to Clair.
- One small branch per fix or feature, then open a PR and merge only when checks pass.
- Keep it tiny: one topic per PR. No giant mixed PRs (routes + AI + voice + design in one go).
- Before every PR: run `flutter analyze`, run `flutter test`, and open the app in Chrome (`flutter run -d chrome`) to look at what you changed.
- If functions or hosting checks fail, stop and fix. Do not add `continue-on-error` or hide failures.
- Leave the tree clean: commit or drop your work, don't leave uncommitted files behind.


## Watch-outs (learned from live breaks)

- **Privacy first:** couple-only data (chat, gallery, notes, garden, AI memories) is Khent + Clair only. Breyan / Octagram are movies-only. When touching Firestore or functions, re-check `firestore.rules` and keep TMDB / Last.fm / Agnes keys server-side.
- **Main screen is fragile on web:** the Together zone broke live several times (grey cover, full-stack crash). Reproduce in Chrome first. Keep lists finite, avoid blur-over-big-area and pinned headers that jump.
- **Helpers need a login token:** the app never calls TMDB / Last.fm / Agnes directly. It calls our cloud helpers with a Firebase login token. Don't add direct web calls or client keys.
- **History should stay readable:** tiny scoped commits (`fix(dashboard): ...`). One fix per commit so a bad deploy is easy to undo. No "fix live by redeploying to see" — look locally first.

## Web Search Policy (persistent user preference)

- For ANY web-related searching, fetching, research, docs lookup, current info, source-backed answers, or browser automation, always use the $use-tinyfish skill at C:/Users/Admin/.agents/skills/use-tinyfish/SKILL.md (TinyFish CLI / TinyFish MCP tools).
- Do NOT use native web search unless TinyFish is unavailable - if fallback happens, explicitly note it.
- Follow the skill routing: search -> fetch -> agent -> browser, lightest tool first.

## Rules that matter

* Only Khent and Clair see couple things like chat, photos, notes, garden, and AI memories. Breyan and Octagram only get movies.
* The app never talks to TMDB, Last.fm, or AI directly. It calls our server helpers with a login token. Keys stay on the server.
* Never commit passcodes, keys, or secrets. `assets/env.txt` is local only - do not read it or copy it.
* Login codes are checked on the server. Do not put them in the file.
* For live data use `.snapshots()`. If something fails, leave a `print` so we can see it.
* Use Provider only. No Riverpod, no Bloc.
* Use relative imports inside `lib/`, like `../../features/...`.
* Dart files are `snake_case`. Screens end in `Screen`.

## How to talk

* Plain and simple words. No jargon unless Khent asks.
* Say what happened, why it matters for Clair, and what to do next.
* Keep answers in a way that a normal human would be able to understand properly.
