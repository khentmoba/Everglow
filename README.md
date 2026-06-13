# Everglow

[![Latest Release](https://img.shields.io/github/v/release/khentmoba/Everglow?style=flat-square&label=latest&color=rgba(194,24,91,0.6))](https://github.com/khentmoba/Everglow/releases/latest)
[![Deploy Status](https://img.shields.io/github/actions/workflow/status/khentmoba/Everglow/deploy.yml?style=flat-square&label=deploy)](https://github.com/khentmoba/Everglow/actions/workflows/deploy.yml)
[![Firebase Hosting](https://img.shields.io/badge/hosted%20on-firebase-FFCA28?style=flat-square&logo=firebase)](https://everglow-1c6db.web.app)

A private digital relationship scrapbook built with Flutter Web for **Khent** and **Clair**.

Everglow tracks your relationship journey through gamified experiences, shared activities, and daily engagement — all wrapped in a warm, animated interface.

## Live Site

**[everglow-1c6db.web.app](https://everglow-1c6db.web.app)**

## Latest Release

> **v4.0.0** — Manga Reader, Play Zone Expansion, WebGL Games & UI Polish
> [View full changelog →](https://github.com/khentmoba/Everglow/releases/latest)

**v4.0.0 — The Manga & WebGL Games Update:**

1. **Manga Reader Feature**:
   - **Feature**: Brand-new `MangaLibraryScreen` and custom `MangaSearchModal` interacting with the MangaDex API.
   - **Feature**: `MangaDetailsDrawer` showing summaries, tags, and reading progress.
   - **Feature**: `MangaReaderScreen` built for side-by-side or vertical scroll with zoom controls and chapter transitions.
   - **Feature**: Manga Preview widget on the main dashboard showing trending or recently read items.

2. **Play Zone Expansion & 3D WebGL Games**:
   - **Feature**: Integrated **Masked Special Forces**, a fully featured 3D WebGL action game.
   - **Feature**: Added **Table Tennis World Tour** tournament game.
   - **Feature**: Added **Fun Race 3D** (featuring Solo Gauntlet and 1v1 lobby matchmaking).
   - **Feature**: Added **1v1 Match** matchmaking lobbies.

3. **Cloud Function Proxy & Architecture**:
   - **Feature**: Configured custom Cloud Functions to act as a secure CORS bypass proxy for third-party API fetches.

4. **UI/UX Polish**:
   - **Feature**: Expanded gesture overlays for starting games (Table Tennis, Fun Race 3D, HexGL) to cover the entire viewport, fixing tap-to-start issues.

_Previous releases: [v3.2.0 "Books & Cinematic"](https://github.com/khentmoba/Everglow/releases/tag/v3.2.0) · [v3.1.0 "Live & Cinematic"](https://github.com/khentmoba/Everglow/releases/tag/v3.1.0) · [v3.0.0 "Cinematic & Performance"](https://github.com/khentmoba/Everglow/releases/tag/v3.0.0) · [All releases →](https://github.com/khentmoba/Everglow/releases)_

---

## Features

| Feature | Description | Version |
|---------|-------------|---------|
| **Gateway** | Animated passcode entry door (0221 = Clair, 0938 = Khent, 9132 = Breyan, 8080 = Octagram) | 1.0.0 / 3.0.0 |
| **Dashboard** | Main hub with anniversary counter, XP, and all feature cards | 1.0.0 |
| **Heartbeat** | Daily mood tracking with partner status indicators | 1.0.0 |
| **Guardian** | Animated cat mascot with random messages and mood prompts | 1.0.0 |
| **Sanctuary** | Private real-time couple's chat | 1.0.0 |
| **Daily Bloom** | Virtual garden that grows with daily visits | 1.0.0 |
| **Date Randomizer** | 1000+ date ideas — shake to discover | 1.0.0 |
| **Cinema** | Shared movie/TV watch list powered by TMDB | 1.0.0 |
| **Starlight Jar** | Drop gratitude notes and memories into a virtual jar | 1.1.0 |
| **Canvas** | Collaborative drawing with real-time sync | 1.1.0 |
| **Academy** | Trivia game with 8 categories, solo study and 1v1 challenges | 1.1.0 |
| **Jukebox** | Live music status from Last.fm for both partners | 1.1.0 |
| **XP System** | Gamified levels, streaks, and sound effects | 1.1.0 |
| **Play Zone** | Games hub with Melody Tiles + HexGL Drift | 1.2.0 |
| **Trending Carousel** | Auto-playing PageView carousel for trending titles | 1.5.0 |
| **Genre Browsing** | Browse by genre (Action, Comedy, Horror, Romance, etc.) | 1.5.0 |
| **Now Showing** | Movies currently in Philippine cinemas + newly released | 1.5.0 |
| **Cast & Reviews** | Cast profiles and user reviews in media details drawer | 1.5.0 |
| **Similar Titles** | "More Like This" recommendations in episode drawer | 1.5.0 |
| **PH Streaming Rankings** | Philippines trending tab uses `watch_region=PH` (Netflix-PH style) | 1.5.2 |
| **Multi-Provider Video** | VidFast, VixSrc, Videasy, 2Embed, etc. with sandbox iframe | 1.5.3 |
| **Melody Tiles** | Native rhythm game tapping falling petals to produce piano melodies + XP awards | 2.0.0 |
| **HexGL Drift** | Futuristic 3D WebGL racing game with Solo Time Trial and 1v1 Ghost Replay Challenges | 2.1.0 |
| **Song Selection** | Melody Tiles track selector with difficulty, note count, high score, and best streak trackers | 2.1.0 |
| **Cinematic Dark Luxury UI** | Floating pill nav, hero carousel, shimmer skeletons, medal badges, gradient overlays, glass-feel reviews | **3.0.0** |
| **Piano Tiles Rewrite** | `Ticker`+`CustomPainter` engine, pre-warmed audio pool, expanded 4-song library | **3.0.0** |
| **Breyan Cinema Access** | Passcode 9132 lands directly on Cinema with isolated watchlist data | **3.0.0** |
| **Octagram Cinema Access** | Passcode 8080 lands directly on Cinema with the cinema-only chip set | **3.0.0** |
| **HexGL Boot Fixes** | No-cache iframe, immediate `ready`, progress messages, surface iframe errors | **3.0.0** |
| **Live Presence** | `PresenceService` 15 s heartbeat + online/doodle freshness windows; flips offline on `pagehide` / `beforeunload` | **3.1.0** |
| **Partner Presence Indicator** | Pulsing green dot in Sanctuary chat header ("Clair is active" / "Active 5m ago") | **3.1.0** |
| **Partner Doodle Indicator** | Live "Clair is doodling ✨ 12s" banner on the Canvas screen | **3.1.0** |
| **Trailer Player** | `HTMLIFrameElement` YouTube embed with autoplay / muted / loop / `pointer-events: none` | **3.1.0** |
| **Cinema Hover Trailers** | Desktop poster hover scales 1.15×, drops rose-glow, and plays the looping trailer | **3.1.0** |
| **Cinema Carousel Trailers** | Trending hero swaps the still backdrop for the live trailer 2.5 s after the page settles | **3.1.0** |
| **Episode Drawer Trailer** | Floating "Watch Trailer" button on the cinematic hero backdrop | **3.1.0** |
| **Our Cinema Glass UI** | Glassmorphic cards with deep-rose border, 24 px shadow lift, and "Watched Together 💞" gradient pill | **3.1.0** |
| **Our Cinema Hover Trailers** | Hover-to-play trailers on every list row with a "TRAILER" green pill | **3.1.0** |
| **Add to Our Cinema** | `+` header button + empty-state CTA open `TMDBSearchModal` with `initialScope: 'ours'` | **3.1.0** |
| **Videasy Autoplay Params** | `?autoplay=true` for movies, `?autoplay=true&nextButton=true&episodeSelector=true` for TV | **3.1.0** |
| **Our Books Feature** | Full books section with Open Library API, search, discovery, in-app reader, and shared couple list | **3.2.0** |
| **In-App Reader** | `ReaderScreen` fetches plain text from Internet Archive, parses chapters, renders via `flutter_html` | **3.2.0** |
| **Our Books Shared List** | Firestore-backed `our_books` collection with per-partner status tracking | **3.2.0** |
| **Instant Carousel Trailers** | Zero-delay trailer playback with full-slide prefetch; auto-rotate extended to 18 s | **3.2.0** |
| **Enhanced Poster Hover** | 1.5× poster scale (up from 1.15×) with `Alignment.topCenter` and faster easing | **3.2.0** |
| **Mobile Trailer Auto-Play** | Episode drawer auto-plays trailer on mobile (muted) | **3.2.0** |
| **Play Zone HTML Games** | Added Table Tennis World Tour, Fun Race 3D, and 1v1 Match games | **3.3.0** |
| **Lobby Multiplay** | Matchmaking & multiplayer room-sharing via Firestore | **3.3.0** |
| **Consolidated Watchlist** | Personal & couple Cinema lists merged into single Firestore schema | **3.3.0** |
| **Manga Reader** | Full MangaDex API library, search modal, detail drawers, and multi-page reader view | **3.4.0** |
| **Masked Special Forces** | Integrated 3D WebGL action shooter game into Play Zone | **3.4.0** |
| **Cloud Function Proxy** | CORS bypass proxy cloud handler for external API requests | **3.4.0** |
| **Play Zone Start Gestures** | Full-screen gesture overlays for starting games, improving tap-to-start reliability | **4.0.0** |

## Tech Stack

- **Framework:** Flutter (Web)
- **Backend:** Firebase (Auth, Firestore, Storage, Hosting)
- **State Management:** Provider
- **External APIs:** TMDB, Open Library (Books), OpenTDB (Trivia), Last.fm
- **Real-Time Presence:** Firestore `presence/{uid}` collection with 15 s heartbeat
- **Trailer Playback:** YouTube IFrame Player API via `dart:ui_web` + `package:web`
- **Multiplayer:** Firestore real-time snapshots for HexGL time-trial challenges

## Project Structure

```
lib/
  main.dart                     # Entry point, Provider setup (incl. PresenceService)
  core/
    audio/                      # Sound effects (just_audio)
    config/                     # EnvConfig with hardcoded API key fallbacks
    constants/                  # API keys
    models/                     # Shared models (PresenceStatus)
    theme/                      # Dusk Petal romantic palette
  features/
    entry/                      # Passcode gateway (Clair, Khent, Breyan, Octagram)
    dashboard/                  # Main hub + heartbeat lifecycle
    heartbeat/                  # Daily mood tracking
    guardian/                   # Animated cat mascot
    academy/                    # Trivia game
    books/                      # Book discovery & reader (Open Library API)
    cinema/                     # Movie watch list (TMDB, multi-provider, trailers)
      presentation/widgets/     # TrailerPlayer, EpisodeDrawer, TMDBSearchModal
    chat/                       # Private couple chat
    starlight_jar/              # Gratitude jar
    canvas/                     # Collaborative drawing + doodle presence
    daily_bloom/                # Virtual garden
    date_randomizer/            # Date idea generator
    xp/                         # Gamification system
    jukebox/                    # Music sync
    play_zone/                  # Games hub
      piano_tiles/              # Melody Tiles (Ticker+CustomPainter engine)
      hexgl/                    # HexGL Drift (HTML5 3D WebGL racing)
  services/                     # Core Firebase services (Auth, Storage, Presence, ...)
  shared/widgets/               # PartnerPresenceIndicator, PartnerDoodleIndicator, ...
scripts/
assets/
  data/                         # Seed JSON files (trivia, date ideas)
  images/                       # Logo and milestone photos
  audio/piano/                  # Reference piano samples (a, c, e, f)
web/
  hexgl/                        # HexGL embed HTML (no-cache)
CHANGELOG.md                    # Full release-by-release history (v1.0.0 → v3.2.0)
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

Auto-deploys to Firebase Hosting on push to `main` via GitHub Actions.

The workflow:
1. Builds Flutter web
2. Generates changelog from commits
3. Deploys to Firebase Hosting
4. Creates a GitHub Release

## Release History

The full release-by-release history is in [CHANGELOG.md](./CHANGELOG.md). Highlights:

- **v4.0.0** — Play Zone Start Gestures, Gesture Overlay Enhancements
- **v3.4.0** — Manga Reader (MangaDex API Integration), Masked Special Forces Game, Cloud Function Proxy
- **v3.3.0** — Play Zone Games (Table Tennis, Fun Race 3D, 1v1 Match), Watchlist Consolidation
- **v3.2.0** — Our Books (Open Library Integration, In-App Reader), Instant Carousel Trailers, Mobile Trailer Polish
- **v3.1.0** — Live Presence, Hover-to-Play Trailers, Our Cinema Glass UI
- **v3.0.0** — Cinematic Cinema Overhaul, Piano Tiles Rewrite, Breyan + Octagram Access
- **v2.1.0** — Play Zone Overhaul (HexGL Drift + Song Selection)
- **v2.0.0** — Mobile Optimization & Bloat Cleanup
- **v1.5.3** — Cinema: Real Iframe Fix + Provider Cleanup + Popup-Ad Sandbox
- **v1.5.2** — Philippines Trending: Real Streaming Rankings
- **v1.5.1** — Sandbox Bypass Hardening + Cinema & UI Polish
- **v1.5.0** — Cinema Overhaul (genre, cast, reviews, carousel, trending)
- **v1.4.0** — Cinema: multi-provider video player + episode drawer
- **v1.3.0** — Racing Game: auto-respawn + professional touch UI
- **v1.2.0** — Play Zone: Midnight Drive racing game
- **v1.1.0** — Starlight Jar, Canvas, Academy, Jukebox, XP system
- **v1.0.0** — Initial public release (Gateway, Dashboard, Heartbeat, Guardian, Sanctuary, Daily Bloom, Date Randomizer, Cinema)

See [all releases](https://github.com/khentmoba/Everglow/releases) for the full changelog.

## License

Private — for Khent and Clair only.
