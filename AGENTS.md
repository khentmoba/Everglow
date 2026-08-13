# Everglow — AGENTS.md

> Private digital relationship scrapbook — Flutter Web + Firebase, for Khent & Clair.

## Project
- **Stack:** Flutter Web (SDK ^3.11.3), Firebase (Auth / Firestore / Storage / Hosting / Functions), Provider, go_router.
- **Entry:** `lib/main.dart` — initializes Firebase, dotenv, Firestore persistence, then `EverglowApp` (MultiProvider → MaterialApp.router).
- **Version:** 6.0.0+1 (source of truth: `pubspec.yaml`).
- **Live:** <https://everglow-1c6db.web.app> — auto-deployed on push to `main` via `.github/workflows/deploy.yml`.

## Commands
| What | Command |
|------|---------|
| Install deps | `flutter pub get` |
| Run locally | `flutter run -d chrome` |
| Lint / analyze | `flutter analyze` (always before commit) |
| Test | `flutter test` |
| Build (release) | `flutter build web --release` |
| Build (CanvasKit) | `flutter build web --web-renderer canvaskit --release` (see `build_prod.bat`) |
| Deploy | `deploy.ps1` (builds + `firebase deploy --only functions,hosting`) |
| Functions emulator | `cd functions && npm run serve` |

## Architecture

```
lib/
  main.dart                  # Entry point, bootstrap, app shell
  core/
    audio/                   # Sound effects (just_audio)
    config/env_config.dart   # EnvConfig — reads from dotenv or compile-time env, hardcoded fallbacks
    constants/api_keys.dart  # TMDB / OpenLibrary API keys
    di/                      # Composition root (appProviders) + app shell (AppRoot)
    models/                  # Shared models (PresenceStatus)
    router/app_router.dart   # GoRouter composition root; feature routes live under each feature
    services/                # Core Firebase services (AuthService, PresenceService, StorageService, NotificationService)
    theme/                   # "Dusk Petal" design system (colors, typography, spacing, radius, elevation, motion, breakpoints)
    utils/                   # Firestore stream helpers, logger, connectivity
  features/
    entry/                   # Passcode gateway (0221=Clair, 0938=Khent, 9132=Breyan, 8080=Octagram)
    dashboard/               # Main hub — anniversary counter, milestone cards, feature previews
    heartbeat/               # Daily mood tracking (mood picker, partner status)
    guardian/                # Animated cat mascot with AI-powered messages
    academy/                 # Trivia game — 8 categories, solo study, 1v1 matches
    ai/                      # AI assistant (Groq API via SSE streaming), conversation repo, memory repo
    books/                   # Open Library discovery + in-app reader + shared "Our Books" list
    canvas/                  # Collaborative drawing (real-time Firestore sync)
    chat/                    # "Sanctuary" private couple chat (Firestore real-time)
    cinema/                  # Movie/anime watchlist — TMDB API, multi-provider video, trailers, episode drawer
    daily_bloom/             # Virtual garden that grows with daily visits
    date_randomizer/         # Date idea generator (1000+ ideas, shake gesture)
    jukebox/                 # Last.fm music sync, listen-along
    manga/                   # Manga library — MangaDex, Bato, Comick, Mangakakalot, Mangasee123
    play_zone/               # Games hub + Table Tennis (WebGL + Firestore multiplayer)
    starlight_jar/           # Gratitude notes jar
    watch_party/             # Watch party with WebRTC voice chat (ac-relay signaling server)
    xp/                      # XP/leveling system
  shared/
    utils/text_utils.dart    # stripMarkdown, extractTitles
    widgets/everglow/        # Design system: EverglowButton, EverglowCard, EverglowScaffold, etc.
    widgets/shelf/           # Cinema/books shelf UI: ShelfPosterCard, ShelfHeroCarousel, CinemaNavBar, etc.
  firebase_options.dart      # Generated Firebase config

web/                         # PWA manifest, index.html, favicon, service worker
functions/index.js           # Cloud Functions: proxyBookText, proxyMangaImage, proxyAI
ac-relay/server.js           # WebRTC signaling server for watch-party voice chat
```

### Feature layer convention (most features follow this):
`data/` (models + services) → `domain/` (models + repository interfaces, where used) → `presentation/` (screens + widgets + providers/controllers).

## Conventions

- **State management:** Provider (`ChangeNotifierProvider`, `Provider`, `Selector`). No Riverpod/Bloc.
- **Routing:** `go_router` — each feature owns its routes in `<feature>/presentation/routes/`, composed in `core/router/app_router.dart`. Complex objects passed via `extra`.
- **DI:** `core/di/app_providers.dart` is the composition root; `main.dart` should not wire feature services directly.
- **Theme:** Always use tokens from `core/theme/` (AppColors, AppTypography, AppSpacing, AppRadius, etc.) — never hardcode colors or spacing.
- **Shared widgets:** Prefer `shared/widgets/everglow/` components (EverglowButton, EverglowCard, EverglowScaffold, etc.) over bare Material widgets for UI consistency.
- **Assets:** Self-hosted Google Fonts (`assets/google_fonts/`), images in `assets/images/`, seed data in `assets/data/`. Runtime font fetching is disabled.
- **Naming:** Dart files use `snake_case`. Classes use `PascalCase`. Screen widgets end in `Screen` (e.g. `DashboardScreen`).
- **Imports:** Use relative imports (`../../features/...`) within lib/ — no package imports for internal files.
- **Firestore:** Always enable `print` logging on error paths. Use `.snapshots()` for real-time. Persistence is on globally.
- **Lint:** `flutter_lints` (package:flutter_lints/flutter.yaml). Run `flutter analyze` before committing — do not suppress lints without a comment.
- **Tests:** Minimal — `flutter test` runs unit tests under `test/`. New features don't strictly require tests, but core logic should have them.

## Notes

- **Secrets:** never commit real credentials, passcodes, or API keys. `assets/env.txt` is local-only and is **not** bundled into web builds; `deploy.ps1` and CI pass its values to `flutter` as `--dart-define` flags. See `.env.example`.
- **Security rules:** `firestore.rules` blocks anonymous users, requires a known `/users/{uid}` profile, and limits couple-only collections (chat, gallery, notes, cinema, canvas, garden, AI memories, etc.) to Khent and Clair. Every Cloud Function proxy requires a valid Firebase ID token.
- Do **not** read or expose `assets/env.txt` — it contains secrets (API keys, emails, passwords).
- Firebase emulators config is in `firebase.json` — ports 9099–9499.
- `deploy.ps1` auto-generates `web/sw.js` with a version-commit build stamp before deploying.
- The AI feature uses Groq (qwen/qwen3.6-27b) via SSE streaming — see memory docs for tuning details.
- ac-relay is a separate Node.js WebRTC signaling server, not deployed with Firebase — run independently if voice chat is needed.
