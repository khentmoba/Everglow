# Everglow

[![Latest Release](https://img.shields.io/github/v/release/khentmoba/Everglow?style=flat-square&label=latest&color=rgba(194,24,91,0.6))](https://github.com/khentmoba/Everglow/releases)
[![Deploy Status](https://img.shields.io/github/actions/workflow/status/khentmoba/Everglow/deploy.yml?style=flat-square&label=deploy)](https://github.com/khentmoba/Everglow/actions/workflows/deploy.yml)
[![Firebase Hosting](https://img.shields.io/badge/hosted%20on-firebase-FFCA28?style=flat-square&logo=firebase)](https://everglow-1c6db.web.app)

A private digital relationship scrapbook built with Flutter Web for **Khent** and **Clair**.

Everglow tracks your relationship journey through gamified experiences, shared activities, and daily engagement — all wrapped in a warm, animated interface.

## Live Site

**[everglow-1c6db.web.app](https://everglow-1c6db.web.app)**

## Latest Release

> **v1.5.0** — Cinema Overhaul: genre browsing, cast & reviews, carousel, trending rankings
> [View full changelog →](https://github.com/khentmoba/Everglow/releases/latest)

**Cinema Overhaul:**
- Redesigned home screen: trending carousel with autoplay, Global/Philippines trending rankings
- Now Showing in Cinema and Newly Released sections (PH region)
- Genre-based browsing rows (Action, Comedy, Horror, Romance, Drama, Animation, Mystery, Sci-Fi, etc.)
- Episode drawer expanded: cast section with profile photos, user reviews with ratings, "More Like This" recommendations, genre chips, runtime display
- Sandbox bypass script injected into video player to prevent "Please Disable Sandbox" errors on streaming providers
- `backdropPath` and `year` fields added to `MediaItem` model
- Refactored TMDB service with `_mapResultToMediaItem()` helper, added `fetchNowPlaying()`, `fetchUpcoming()`, `fetchGenreList()`, `discoverByGenre()`, `fetchCredits()`, `fetchReviews()`, `fetchSimilar()`

**Racing Game (Midnight Drive):**
- Added Reverse (REV) button to mobile touch controls
- Fixed forward/backward vehicle direction logic (was inverted)
- Smarter respawn system: tracks `lastCheckpointIndex` for progressive waypoint matching, uses exact waypoint rotation
- Zeroed angular velocity for stable respawns

_Previous releases: [v1.4.0 "Cinema"](https://github.com/khentmoba/Everglow/releases/tag/v1.4.0) · [v1.3.0 "Racing Game"](https://github.com/khentmoba/Everglow/releases/tag/v1.3.0) · [v1.2.0 "Play Zone"](https://github.com/khentmoba/Everglow/releases/tag/v1.2.0) · [v1.1.0 "Gamified"](https://github.com/khentmoba/Everglow/releases/tag/v1.1.0) · [v1.0.0 "Bloom"](https://github.com/khentmoba/Everglow/releases/tag/v1.0.0) · [All releases →](https://github.com/khentmoba/Everglow/releases)

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
| **Play Zone** | Games hub with Midnight Drive racing game | **1.2.0** |
| **Midnight Drive** | 3D desert racing game with touch controls + 1v1 multiplayer | **1.2.0** |
| **Trending Carousel** | Auto-playing PageView carousel for trending titles | **1.5.0** |
| **Genre Browsing** | Browse by genre (Action, Comedy, Horror, Romance, etc.) | **1.5.0** |
| **Now Showing** | Movies currently in Philippine cinemas + newly released | **1.5.0** |
| **Cast & Reviews** | Cast profiles and user reviews in media details drawer | **1.5.0** |
| **Similar Titles** | "More Like This" recommendations in episode drawer | **1.5.0** |
| **Reverse Gear** | Reverse button for racing game mobile touch controls | **1.5.0** |

## Tech Stack

- **Framework:** Flutter (Web)
- **Backend:** Firebase (Auth, Firestore, Storage, Hosting)
- **State Management:** Provider
- **External APIs:** TMDB, OpenTDB (Trivia), Last.fm
- **Racing Game:** React 18 + Three.js + @react-three/fiber + cannon-es physics (Vite build, iframe-embedded)
- **Multiplayer:** Firestore real-time snapshots + transactions for race matchmaking

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
    play_zone/                  # Games hub (Midnight Drive racing game)
  services/                     # Core Firebase services
  shared/widgets/               # Reusable UI components
racing-game/                    # Standalone React + Three.js racing game
  src/
    App.tsx                     # Root component, 3D canvas + physics
    Bridge.tsx                  # postMessage bridge to Flutter
    controls/                   # Keyboard + Touch input handlers
    models/                     # Vehicle, track, ghost car, physics
    effects/                    # Particles, audio, cameras
    ui/                         # HUD, intro, finished screen, leaderboard
    store.ts                    # Zustand game state
    firebase-data.ts            # Firestore scores (replaces Supabase)
    styles.css                  # Everglow-themed Dusk Petal CSS
scripts/
  build-racing-game.ps1         # Automated build + copy pipeline
assets/
  data/                         # Seed JSON files (trivia, date ideas)
  images/                       # Logo and milestone photos
```

## Getting Started

### Prerequisites

- Flutter SDK ^3.11.3
- Firebase CLI (`npm install -g firebase-tools`)
- Node.js 18+ (for building the racing game)
- A Firebase project with the services enabled

### Setup

```bash
# Clone the repository
git clone https://github.com/khentmoba/Everglow.git
cd Everglow

# Install Flutter dependencies
flutter pub get

# Install racing game dependencies
cd racing-game
npm install --legacy-peer-deps
cd ..

# Run locally
flutter run -d chrome
```

### Full Build & Deploy

```bash
# 1. Build the racing game
cd racing-game
npm install --legacy-peer-deps
node node_modules/vite/bin/vite.js build
cd ..

# 2. Copy racing game to Flutter web build directory
Copy-Item -Recurse -Force racing-game/dist/* build/web/racing/

# 3. Build Flutter web
flutter build web --release

# 4. Deploy to Firebase
firebase deploy --only hosting
```

Or use the automated script:
```bash
.\scripts\build-racing-game.ps1
flutter build web --release
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
1. Builds the racing game (Vite)
2. Copies assets to Flutter build directory
3. Builds Flutter web
4. Generates changelog from commits
5. Deploys to Firebase Hosting
6. Creates a GitHub Release

## License

Private — for Khent and Clair only.
