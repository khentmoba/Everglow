# Everglow

[![Latest Release](https://img.shields.io/github/v/release/khentmoba/Everglow?style=flat-square&label=latest&color=rgba(194,24,91,0.6))](https://github.com/khentmoba/Everglow/releases)
[![Deploy Status](https://img.shields.io/github/actions/workflow/status/khentmoba/Everglow/deploy.yml?style=flat-square&label=deploy)](https://github.com/khentmoba/Everglow/actions/workflows/deploy.yml)
[![Firebase Hosting](https://img.shields.io/badge/hosted%20on-firebase-FFCA28?style=flat-square&logo=firebase)](https://everglow-1c6db.web.app)

A private digital relationship scrapbook built with Flutter Web for **Khent** and **Clair**.

Everglow tracks your relationship journey through gamified experiences, shared activities, and daily engagement — all wrapped in a warm, animated interface.

## Live Site

**[everglow-1c6db.web.app](https://everglow-1c6db.web.app)**

## Latest Release

> **v2.1.0** — Play Zone Overhaul: HexGL Drift & Melody Tiles Song Selection
> [View full changelog →](https://github.com/khentmoba/Everglow/releases/latest)

**v2.1.0 — The Futuristic Drift & Song Selection Update:**

1. **HexGL Drift Integration (HTML5 3D Racing)**:
   - **Feature**: Replaced old racing/shooter games with HexGL Drift, a fast-paced 3D WebGL futuristic racing game embedded directly into the Play Zone hub.
   - **Solo Time Trial**: Players can race against the clock to set their personal best times on the Cityscape track.
   - **Challenge Partner**: Race against your partner's best ghost replay, stored dynamically on Firebase Firestore.
   - **Full Replay & Ghost System**: Syncs the driver's exact input path and position data to recreate a smooth ghost replay for the partner to compete against.
   - **Optimized Mobile Touch HUD**: Seamless custom overlay that translates touch gestures on mobile screens to steering, drifting, and boosting.

2. **Melody Tiles Song Selection**:
   - **Feature**: Replaced the immediate start of the rhythm game with a beautiful, themed song selection screen.
   - **Track Library**: Browse through custom tracks with details on artist, difficulty (Easy, Medium, Hard), and note count.
   - **High Score & Streak Tracking**: Persists and displays local high scores and best streaks per song.

3. **Codebase & Asset Cleanup**:
   - **Feature**: Removed unused legacy components (AssaultCube/AssaultZone and old Three.js racing game) from the Flutter codebase and repository assets, drastically reducing the package and deployment footprint.

_Previous releases: [v2.0.0 "Mobile Optimization"](https://github.com/khentmoba/Everglow/releases/tag/v2.0.0) · [v1.5.3 "Real Iframe Fix"](https://github.com/khentmoba/Everglow/releases/tag/v1.5.3) · [v1.5.2 "PH Trending"](https://github.com/khentmoba/Everglow/releases/tag/v1.5.2) · [v1.5.1 "Sandbox Hardening"](https://github.com/khentmoba/Everglow/releases/tag/v1.5.1) · [v1.5.0 "Cinema"](https://github.com/khentmoba/Everglow/releases/tag/v1.5.0) · [v1.3.0 "Racing Game"](https://github.com/khentmoba/Everglow/releases/tag/v1.3.0) · [v1.2.0 "Play Zone"](https://github.com/khentmoba/Everglow/releases/tag/v1.2.0) · [v1.1.0 "Gamified"](https://github.com/khentmoba/Everglow/releases/tag/v1.1.0) · [v1.0.0 "Bloom"](https://github.com/khentmoba/Everglow/releases/tag/v1.0.0) · [All releases →](https://github.com/khentmoba/Everglow/releases)

---

### v2.0.0 Changelog Summary

**v2.0.0 — Mobile Optimization & Bloat Cleanup:**
1. **Melody Tiles (Piano Tiles)**:
   - **Feature**: Rhythm game added to the Play Zone hub. Tap falling dark petals in rhythm to play notes.
   - **Audio Note System**: Loaded with high-quality note sounds (`a.wav`, `c.wav`, `e.wav`, `f.wav`) that play with zero latency upon tapping.
   - **Gamification**: Includes streak counters, score multipliers, high-score tracking, and automatically awards XP via the XP system.
2. **Cinema Refactoring & Enhancements**:
   - **Feature**: Substantial updates to `cinema_screen.dart`, `episode_drawer.dart`, and `media_poster_card.dart` to optimize the media browse list, TMDB ratings lookup, and detail card animations.
3. **Dashboard & Auth Enhancements**:
   - **Feature**: Improved passcode authentication routing, anniversary countdown precision, and styled feature navigation cards.

---

### v1.5.3 Changelog Summary

**v1.5.3 - Cinema: Real Iframe Fix + Provider Cleanup + Popup-Ad Sandbox:**
- **Iframe bypass**: Registered through `dart:ui_web.platformViewRegistry` with ad-blocking `sandbox` tags that allow script execution but block window redirects.
- **Provider Audit**: Reordered defaults so VidFast and VixSrc (ad-free) sit at the top. Removed 6 dead/blocked providers and patched 7 base URLs.

## Features

| Feature | Description | Version |
|---------|-------------|---------|
| **Gateway** | Animated passcode entry door (1111 = Clair, 2222 = Khent) | 1.0.0 |
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
| **Play Zone** | Games hub with Melody Tiles + HexGL Drift | **1.2.0** |
| **Trending Carousel** | Auto-playing PageView carousel for trending titles | **1.5.0** |
| **Genre Browsing** | Browse by genre (Action, Comedy, Horror, Romance, etc.) | **1.5.0** |
| **Now Showing** | Movies currently in Philippine cinemas + newly released | **1.5.0** |
| **Cast & Reviews** | Cast profiles and user reviews in media details drawer | **1.5.0** |
| **Similar Titles** | "More Like This" recommendations in episode drawer | **1.5.0** |
| **PH Streaming Rankings** | Philippines trending tab uses `watch_region=PH` (Netflix-PH style) | **1.5.2** |
| **Melody Tiles** | Native rhythm game tapping falling petals to produce piano melodies + XP awards | **2.0.0** |
| **HexGL Drift** | Futuristic 3D WebGL racing game with Solo Time Trial and 1v1 Ghost Replay Challenges | **2.1.0** |
| **Song Selection** | Melody Tiles track selector with difficulty, note count, high score, and best streak trackers | **2.1.0** |

## Tech Stack

- **Framework:** Flutter (Web)
- **Backend:** Firebase (Auth, Firestore, Storage, Hosting)
- **State Management:** Provider
- **External APIs:** TMDB, OpenTDB (Trivia), Last.fm
- **Multiplayer:** Firestore real-time snapshots for HexGL time-trial challenges

## Project Structure

```
lib/
  main.dart                     # Entry point, Provider setup
  core/
    audio/                      # Sound effects (just_audio)
    constants/                  # API keys
    theme/                      # Dusk Petal romantic palette
  features/
    entry/                      # Passcode gateway
    dashboard/                  # Main hub
    heartbeat/                  # Daily mood tracking
    guardian/                   # Animated cat mascot
    academy/                    # Trivia game
    cinema/                     # Movie watch list
    chat/                       # Private couple chat
    starlight_jar/              # Gratitude jar
    canvas/                     # Collaborative drawing
    daily_bloom/                # Virtual garden
    date_randomizer/            # Date idea generator
    xp/                         # Gamification system
    jukebox/                    # Music sync
    play_zone/                  # Games hub (Melody Tiles, HexGL Drift)
  services/                     # Core Firebase services
  shared/widgets/               # Reusable UI components
scripts/
assets/
  data/                         # Seed JSON files (trivia, date ideas)
  images/                       # Logo and milestone photos
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

## License

Private — for Khent and Clair only.
