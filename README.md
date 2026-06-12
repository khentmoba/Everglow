# Everglow

A private digital relationship scrapbook built with Flutter Web for **Khent** and **Clair**.

Everglow tracks your relationship journey through gamified experiences, shared activities, and daily engagement — all wrapped in a warm, animated interface.

## Live Site

**[everglow-1c6db.web.app](https://everglow-1c6db.web.app)**

## Version History

### v1.2.0 — "Play Zone" (Current)

#### Midnight Drive Racing Game

A fully playable 3D desert racing game embedded directly in Everglow. Built with React Three Fiber, Three.js, and cannon-es physics.

- **Platform:** Web (React SPA embedded via iframe in Flutter)
- **Entry:** Dashboard → Play Zone → Midnight Drive
- **Physics:** Realistic 4-wheel raycast vehicle with independent suspension, steering, and weight transfer
- **Track:** Open-world desert environment with animated birds, clouds, water, and a train
- **Visual Effects:** Dust particles, skid marks, nitro boost flames, dynamic speedometer, and minimap

#### Mobile Touch Controls

Full on-screen touch overlay for mobile gameplay:
- **Left thumb:** Steering (left/right arrows) + honk
- **Right thumb:** Gas (large), Brake, and Nitro Boost buttons
- **Camera toggle:** Switch between chase cam, first-person, and bird's-eye view
- **Styling:** Glassmorphism with Everglow's Dusk Petal palette
- **Desktop:** Traditional keyboard controls still work (WASD + arrows)

#### 1v1 Multiplayer

Race against your partner in real-time:
- **Matchmaking:** Lobby system via Firestore (same 60s timeout pattern as Academy)
- **Position sync:** Each player writes their position to Firestore every 100ms
- **Ghost car:** Opponent appears as a solid translucent car with real physics collision
- **Results:** Side-by-side times, winner declaration with confetti celebration
- **XP Award:** 100 XP base (200 XP for sub-60s lap)

#### Play Zone Hub

New centralized games area accessible from the dashboard:
- **Portal Card:** Glassmorphism card with gamepad emblem and "ENTER PLAY ZONE" button
- **Extensible layout:** Built to accommodate future games alongside Midnight Drive
- **Mode selection:** Solo Practice (time trial) or 1v1 Race (matchmaking)

#### Visual & Theme Updates

- Complete restyle of the racing game UI to match Everglow's Dusk Petal palette (twilight backgrounds, roseQuartz text, deepRose accent)
- Google Fonts swapped: Outfit (body) + Cormorant Garamond (headings)
- Glassmorphism applied to all game overlays (clock, speedometer, leaderboard, help popup)
- Loading skeleton with pulsing glow animation
- Race completion celebration with falling petal/heart particles
- Score leaderboard backed by Firestore (replaced Supabase)

### v1.1.0 — "Gamified"

- Everglow Academy (trivia with 8 categories)
- Canvas (real-time collaborative drawing)
- Starlight Jar (gratitude notes)
- XP/leveling system
- Jukebox (Last.fm music sync)

### v1.0.0 — "Bloom"

- Initial release
- Gateway passcode entry door
- Dashboard with anniversary counter
- Heartbeat daily mood tracking
- Guardian cat mascot
- Cinema (TMDB watch list)
- Sanctuary private chat
- Daily Bloom virtual garden
- Date Randomizer
- Memory timeline

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
