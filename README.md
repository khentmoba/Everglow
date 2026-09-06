# Everglow

[![Latest Release](https://img.shields.io/github/v/release/khentmoba/Everglow?style=flat-square&label=latest&color=rgba(194,24,91,0.6))](https://github.com/khentmoba/Everglow/releases/latest)
[![Deploy Status](https://img.shields.io/github/actions/workflow/status/khentmoba/Everglow/deploy.yml?style=flat-square&label=deploy)](https://github.com/khentmoba/Everglow/actions/workflows/deploy.yml)
[![Firebase Hosting](https://img.shields.io/badge/hosted%20on-firebase-FFCA28?style=flat-square&logo=firebase)](https://everglow-1c6db.web.app)

A private digital relationship scrapbook built with Flutter Web for **Khent** and **Clair**.

Everglow tracks your relationship journey through gamified experiences, shared activities, daily engagement, and an AI companion — all wrapped in a warm, animated interface.

## Live Site

**[everglow-1c6db.web.app](https://everglow-1c6db.web.app)**

## Latest Release

> **v6.0.0** — Bucket List, Calendar, Gallery, Daily Bloom Overhaul, Push Notifications, AI Function Calling
> [View full changelog →](https://github.com/khentmoba/Everglow/releases/latest)

**v6.0.0 — The Relationship Hub Update:**

1. **Bucket List** — Shared couple bucket list with 6 categories (Travel, Experience, Food, Adventure, Milestone, Other), status tracking (Wished → Planned → Completed), and Firestore persistence.
2. **Calendar** — Shared couple calendar with date nights, anniversaries, reminders, recurring events, month grid view, and day detail sheets.
3. **Gallery** — Shared photo gallery with upload, captions, tags, full-screen viewer, and Firebase Storage.
4. **Daily Bloom Overhaul** — 5 plant types (Lily, Rose, Sunflower, Tulip, Sakura) with unique painters, seasonal bonuses, shared garden view, weather overlay, and plant picker.
5. **Push Notifications** — FCM-powered notifications with foreground stream, background handler, topic subscriptions, and in-app toast alerts.
6. **AI Function Calling** — Mochi AI can now interact with Firestore, TMDB, Open Library, and more via 11 callable tools.
7. **Dashboard Overhaul** — Calendar preview, gallery preview, relationship timeline, upcoming countdowns, and creator modal.
8. **New Cloud Functions** — MangaKakalot, MangaKatana, Comick, and anime image proxies for CORS bypass.

_Previous releases: [v5.3.0](https://github.com/khentmoba/Everglow/releases/tag/v5.3.0) · [v5.2.0](https://github.com/khentmoba/Everglow/releases/tag/v5.2.0) · [v5.0.0](https://github.com/khentmoba/Everglow/releases/tag/v5.0.0) · [v4.0.0](https://github.com/khentmoba/Everglow/releases/tag/v4.0.0) · [v3.4.0](https://github.com/khentmoba/Everglow/releases/tag/v3.4.0) · [All releases →](https://github.com/khentmoba/Everglow/releases)_

---

## Features

### Core

| Feature | Description | Version |
|---------|-------------|---------|
| **Gateway** | Animated passcode entry door (passcodes are configured via env, never hardcoded) | 1.0.0 / 3.0.0 |
| **Dashboard** | Main hub with anniversary counter, XP, preview cards, and all feature tiles | 1.0.0 / 6.0.0 |
| **Heartbeat** | Daily mood tracking with partner status indicators | 1.0.0 |
| **Guardian** | Animated cat mascot with random messages and mood prompts | 1.0.0 |
| **Sanctuary** | Private real-time couple's chat | 1.0.0 |
| **Daily Bloom** | Virtual garden with 5 plant types, seasonal bonuses, shared garden view, and weather overlay | 1.0.0 / **6.0.0** |
| **Date Randomizer** | 1000+ date ideas — shake to discover | 1.0.0 |
| **XP System** | Gamified levels, streaks, and sound effects | 1.1.0 |

### Relationship

| Feature | Description | Version |
|---------|-------------|---------|
| **Bucket List** | Shared couple bucket list with 6 categories, status tracking, and Firestore persistence | **6.0.0** |
| **Calendar** | Shared couple calendar with date nights, anniversaries, reminders, and recurring events | **6.0.0** |
| **Gallery** | Shared photo gallery with upload, captions, tags, and full-screen viewer | **6.0.0** |
| **Starlight Jar** | Drop gratitude notes and memories into a virtual jar | 1.1.0 / 6.0.0 |
| **Relationship Timeline** | Visual timeline of relationship milestones on the dashboard | **6.0.0** |
| **Upcoming Countdowns** | Countdown timers to next special day on the dashboard | **6.0.0** |
| **Journal** | Shared journal with locked/private entries and tags | **6.0.0** |

### Entertainment

| Feature | Description | Version |
|---------|-------------|---------|
| **Cinema** | Shared movie/anime watchlist powered by TMDB with multi-provider video, trailers, and genre browsing | 1.0.0 / 5.3.0 |
| **Anime** | Dedicated anime hub with Home (trending), Browse (20+ category chips), Library, Search, and TMDB/Jikan/AniList integration | 5.0.0 / 5.2.0 |
| **Manga** | Full manga library with MangaDex, Comick, MangaKakalot, and multi-page reader | 3.4.0 / 5.1.0 |
| **Books** | Book discovery (Open Library), in-app reader, and shared couple book list | 3.2.0 |
| **Jukebox** | Live music status from Last.fm for both partners | 1.1.0 |
| **Academy** | Trivia game with 8 categories, solo study, and 1v1 challenges | 1.1.0 |
| **Canvas** | Collaborative drawing with real-time Firestore sync | 1.1.0 |

### Play Zone

| Feature | Description | Version |
|---------|-------------|---------|
| **Play Zone Hub** | Games hub with Table Tennis World Tour, Fun Race 3D, and Masked Special Forces | 1.2.0 / 4.0.0 |
| **Table Tennis** | WebGL table tennis with solo and 1v1 multiplayer via Firestore | 3.3.0 |

### AI & Social

| Feature | Description | Version |
|---------|-------------|---------|
| **Mochi AI** | AI assistant with 11 callable tools — can manage watchlist, write notes, set moods, search movies/books/anime, check weather, create reminders, and more | 5.0.0 / **6.0.0** |
| **Watch Party** | Watch party with WebRTC voice chat via ac-relay signaling server | — |
| **Push Notifications** | FCM-powered notifications with topic subscriptions and in-app toasts | **6.0.0** |

### UI / UX

| Feature | Description | Version |
|---------|-------------|---------|
| **Dusk Petal Theme** | Romantic dark palette with Cormorant Garamond + Outfit typography | 3.0.0 |
| **Cinematic Cinema** | Floating pill nav, hero carousel, shimmer skeletons, medal badges, gradient overlays, glass-feel reviews | 3.0.0 |
| **Hover-to-Play Trailers** | Desktop poster hover scales + plays looping YouTube trailer | 3.1.0 |
| **Live Presence** | 15s heartbeat + online/doodle freshness windows | 3.1.0 |
| **Multi-Provider Video** | VidFast, VixSrc, Videasy, VidSrc with sandbox iframe | 1.5.3 / 5.3.0 |

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Framework** | Flutter Web (SDK ^3.11.3) |
| **Backend** | Firebase (Auth, Firestore, Storage, Hosting, Cloud Functions, FCM) |
| **State Management** | Provider (ChangeNotifierProvider, Selector) |
| **Routing** | go_router |
| **External APIs** | TMDB, Open Library, OpenTDB, Last.fm, Jikan, AniList, MangaDex, Comick, MangaKakalot, Mangasee123, Bato, Spotify |
| **Real-Time** | Firestore snapshots (chat, canvas, presence, watchlist, multiplayer) |
| **Voice Chat** | WebRTC via ac-relay signaling server |
| **AI** | Agnes 2.5 Flash via SSE streaming with 11 function-calling tools |
| **Cloud Functions** | Authenticated proxies (TMDB, Last.fm, Spotify, manga, anime, Open Library) + AI (Agnes) + schedules/triggers |
| **Notifications** | Firebase Cloud Messaging (FCM) with topic subscriptions |

---

## Project Structure

```
lib/
  main.dart                          # Entry point, Provider setup, NotificationService, PresenceService
  core/
    audio/                           # Sound effects (just_audio)
    config/env_config.dart          # EnvConfig — dotenv / --dart-define, debug-only fallbacks
    di/                              # Composition root (appProviders) + app shell (AppRoot)
    models/                          # Shared models (PresenceStatus)
    router/app_router.dart           # GoRouter composition root; feature routes under each feature
    services/                        # AuthService, PresenceService, StorageService, NotificationService
    system/                          # AppBootstrap, AppVersion, HealthService
    theme/                           # Dusk Petal design system (colors, typography, spacing, etc.)
    utils/                           # Logger, Firestore stream helpers, connectivity
  features/
    academy/                         # Trivia game — 8 categories, solo study, 1v1 matches
    ai/                              # Mochi AI assistant (Agnes 2.5 Flash + 11 function tools via apihub.agnes-ai.com)
    books/                           # Book discovery & reader (Open Library) + Our Books list
    bucket_list/                     # Shared bucket list kanban (todo / doing / done)
    calendar/                        # Shared calendar + date polls (Rallly-style voting)
    canvas/                          # Collaborative drawing (real-time Firestore sync)
    chat/                            # Sanctuary private couple chat (real-time)
    cinema/                          # Watchlist — TMDB, multi-provider video, trailers, episode drawer
    daily_bloom/                     # Virtual garden (5 plant types, seasonal, shared)
    dashboard/                       # Main hub — anniversary counter, milestone cards, previews
    date_randomizer/                 # Date idea generator (1000+ ideas, shake gesture)
    entry/                           # Passcode gateway (0221=Clair, 0938=Khent, 9132=Breyan, 8080=Octagram)
    gallery/                         # Photo gallery with map view + memories
    guardian/                        # Animated cat mascot with AI-powered messages
    heartbeat/                       # Daily mood tracking (mood picker, partner status)
    journal/                         # Shared journal with locked/private entries and tags
    jukebox/                         # Last.fm + Spotify sync, listen-along, insights
    manga/                           # Manga library — MangaDex, Bato, Comick, Mangakakalot, Mangasee123
    play_zone/                       # Games hub + Table Tennis (WebGL + Firestore multiplayer)
    starlight_jar/                   # Gratitude notes jar
    watch_party/                     # Watch party with WebRTC voice chat (ac-relay)
    xp/                              # XP/leveling system
  shared/
    utils/text_utils.dart            # stripMarkdown, extractTitles
    widgets/everglow/                # Design system: EverglowButton, EverglowCard, EverglowScaffold, etc.
    widgets/shelf/                   # Shelf UI: ShelfPosterCard, ShelfHeroCarousel, CinemaNavBar, etc.
  firebase_options.dart              # Generated Firebase config
functions/
  index.js                           # Cloud Functions: proxies + AI (Mochi) + scheduled tasks
ac-relay/
  server.js                          # WebRTC signaling server for watch-party voice chat
test/                                # Unit tests for calendar, canvas, dashboard, xp
```

## Getting Started

### Prerequisites

- Flutter SDK ^3.11.3
- Firebase CLI (`npm install -g firebase-tools`)
- A Firebase project with the services enabled

### Setup

```bash
# Clone the repository
git clone https://github.com/khentmoba/Everglow.git
cd Everglow

# Install Flutter dependencies
flutter pub get

# Run locally
flutter run -d chrome
```

### Full Build & Deploy

```bash
# 1. Build Flutter web
flutter build web --release

# 2. Deploy to Firebase
firebase deploy --only hosting
```

### Firebase Configuration

1. Place your Firebase admin SDK JSON in the project root:
   ```
   everglow-1c6db-firebase-adminsdk-*.json
   ```

2. The `firebase_options.dart` is pre-configured for the `everglow-1c6db` project.

## Deployment

Auto-deploys to **[everglow-1c6db.web.app](https://everglow-1c6db.web.app)** on every push to `main` via GitHub Actions.

The workflow:
1. Builds Flutter web
2. Generates cache-busting service worker
3. Deploys Cloud Functions
4. Deploys to Firebase Hosting

> **Note:** The GitHub Actions workflow expects a repository secret named `FIREBASE_SERVICE_ACCOUNT_EVERGLOW_1C6DB` containing a Firebase service account JSON key with the **Firebase Hosting Admin** role.

## Cloud Functions

| Function | Purpose |
|----------|---------|
| `proxyBookText` | CORS proxy for Open Library plain text fetching |
| `proxyMangaImage` | CORS proxy for MangaDex at-home image servers |
| `proxyMangaKakalotImage` | CORS proxy for MangaKakalot chapter pages |
| `proxyMangaKatana` | CORS proxy for MangaKatana chapter pages |
| `proxyMangaDex` | CORS proxy for MangaDex catalog API |
| `proxyComick` | CORS proxy for Comick catalog API |
| `proxyAnimeImage` | CORS proxy for anime CDN thumbnails (Crunchyroll, Funimation) |
| `proxyGalleryImage` | CORS proxy for gallery + Firebase Storage images |
| `proxyScanlation` / `proxyFetchHtml` / `proxyEmbed` | CORS proxies for scanlation sites + generic HTML/embed fetch |
| `proxyVideoStream` / `proxyWatchStream` | Video stream proxies with allow-list + SSRF guard |
| `proxyTmdb` | Authenticated TMDB proxy (server-side API key, ID-token required) |
| `proxyLastfm` | Authenticated Last.fm proxy (server-side API key) |
| `proxySpotifySearch` / `spotifyExchange` / `spotifyRefresh` / `spotifyCurrentlyPlaying` | Spotify OAuth + search + playback |
| `proxyAI` / `proxyAIv2` | Mochi AI proxy — Agnes 2.5 Flash (apihub.agnes-ai.com) via SSE streaming, 512K context, 11 tools |
| `agnesImage` | Agnes image generation proxy (`agnes-image-2.0-flash`) |
| `verifyPasscode` | Server-verified passcode login (Khent/Clair) |
| `health` | Public liveness + Firestore reachability |

## Release History

The full release-by-release history is in [CHANGELOG.md](./CHANGELOG.md). Highlights:

- **v6.0.0** — Bucket List, Calendar, Gallery, Daily Bloom Overhaul, Push Notifications, AI Function Calling
- **v5.3.0** — Anime Embed Support in Video Player, Provider Switching
- **v5.2.0** — AniList/Jikan Rich Anime Details, Anime Search Modal, Cinema Rewrite
- **v5.1.0** — Anime Browse Tab, MangaDex Catalog Proxy, Play Zone HUD Refactor
- **v5.0.0** — Anime Feature, MangaDex Image Proxy, Anime Dashboard Preview
- **v4.0.0** — Play Zone Start Gestures, Gesture Overlay Enhancements
- **v3.4.0** — Manga Reader (MangaDex API Integration), Masked Special Forces Game
- **v3.3.0** — Play Zone Games (Table Tennis World Tour), Watchlist Consolidation
- **v3.2.0** — Our Books (Open Library Integration, In-App Reader), Instant Carousel Trailers
- **v3.1.0** — Live Presence, Hover-to-Play Trailers, Our Cinema Glass UI
- **v3.0.0** — Cinematic Cinema Overhaul, Piano Tiles Rewrite, Breyan + Octagram Access
- **v2.1.0** — Play Zone Overhaul
- **v2.0.0** — Mobile Optimization & Bloat Cleanup
- **v1.5.x** — Cinema: trending, genres, multi-provider video, PH rankings
- **v1.0.0** — Initial release

See [all releases](https://github.com/khentmoba/Everglow/releases) for the full changelog.

## License

Private — for Khent and Clair only.
