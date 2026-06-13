# Everglow

[![Latest Release](https://img.shields.io/github/v/release/khentmoba/Everglow?style=flat-square&label=latest&color=rgba(194,24,91,0.6))](https://github.com/khentmoba/Everglow/releases/latest)
[![Deploy Status](https://img.shields.io/github/actions/workflow/status/khentmoba/Everglow/deploy.yml?style=flat-square&label=deploy)](https://github.com/khentmoba/Everglow/actions/workflows/deploy.yml)
[![Firebase Hosting](https://img.shields.io/badge/hosted%20on-firebase-FFCA28?style=flat-square&logo=firebase)](https://everglow-1c6db.web.app)

A private digital relationship scrapbook built with Flutter Web for **Khent** and **Clair**.

Everglow tracks your relationship journey through gamified experiences, shared activities, and daily engagement — all wrapped in a warm, animated interface.

## Live Site

**[everglow-1c6db.web.app](https://everglow-1c6db.web.app)**

## Latest Release

> **v3.0.0** — Cinematic Cinema Overhaul, Piano Tiles Rewrite & Breyan Access
> [View full changelog →](https://github.com/khentmoba/Everglow/releases/latest)

**v3.0.0 — The Cinematic & Performance Update:**

1. **Cinematic Dark Luxury Cinema UI/UX**:
   - **Feature**: Complete Cinema screen rebuild with floating pill nav bar, animated active tab indicator, and 320px hero carousel with 4-stop cinematic gradient + shadow bloom.
   - **Feature**: Chapter-style section headers (accent bar + Cormorant Garamond title typography).
   - **Feature**: Shimmer skeleton loading replaces the spinner while TMDB data fetches.
   - **Feature**: Press-scale poster tiles with bottom fade overlay for a tactile feel.
   - **Feature**: Medal rank badges (gold/silver/bronze glow rings) on trending rankings.
   - **Feature**: Rich watchlist grid with gradient overlays and colored glowing status badges per item.
   - **Feature**: Episode drawer rebuilt with 280px cinematic hero backdrop, 5-star visual rating embedded in the backdrop, and per-genre distinct colored chips.
   - **Feature**: Gradient play button with rose-glow shadow, large-numeral episode tiles, and colored cast avatar rings with glass-feel review cards.

2. **Piano Tiles — Full Engine Rewrite**:
   - **Feature**: Brand-new renderer using `Ticker` + `ValueNotifier` + a single GPU-friendly `CustomPainter` (`PianoBoardPainter`) that paints all four lanes in one pass — zero per-frame widget rebuilds.
   - **Feature**: Beat-locked scrolling, miss-tolerance grace window, and tap-pulse ripples.
   - **Feature**: O(1) tap resolution against the next pending note via per-lane `GestureDetector`s.
   - **Performance**: New `PianoAudioService` pre-warms a pool of `AudioPlayer`s per MIDI note, pre-loads the nearest reference sample (`a.wav`, `c.wav`, `e.wav`, `f.wav`), and pitch-shifts via `setSpeed`. Taps fire-and-forget on the hot path with zero awaits for near-instant response.
   - **Feature**: Lazy fallback that prepares an unprepared note on demand if the song touches a pitch outside the pre-warm pool.
   - **Feature**: Expanded song library — *Twinkle Twinkle Little Star*, *Ode to Joy*, *Für Elise*, and *Canon in D (C-Major)* — with per-song tempo and difficulty (`Easy` / `Medium` / `Hard`).

3. **Breyan (Cinema-Only) Access**:
   - **Feature**: New passcode `9132` signs in as **Breyan**, a cinema-only sibling account. They land directly on the Cinema screen and have isolated watchlist data so the partner-only data stays private.
   - **Feature**: Gateway passcode `9132` is accepted in addition to `1111` (Clair) and `2222` (Khent).
   - **Feature**: `AuthService.loginWithPasscode('breyan')` is registered with `isCinemaOnlyUser` flag for future permission gates.
   - **Feature**: Idempotent `migrateWatchListOwnership()` runs on every login to backfill `userName` on legacy watchlist documents.

4. **HexGL Drift Embed Boot Fixes**:
   - **Fix**: Iframe no longer deadlocks on "Initializing 3D engine..." — hidden HexGL overlay in embed mode, auto-call `tryBootEmbed()` on iframe load, and defer `hexGL.start()` behind `startEmbedRace()`.
   - **Fix**: `postToParent('ready')` now fires as soon as the HexGL instance is created (so the Flutter overlay shows "Tap anywhere to start" right away) instead of waiting for every asset to download.
   - **Feature**: New `progress` messages surface texture/geometry load progress in the spinner, and a `loaded` message marks the race as fully ready.
   - **Fix**: `web/hexgl/index.html` is now marked `no-cache` to bust the 1-hour Firebase Hosting CDN cache; a `v=3` cache-buster is appended to the Flutter iframe src.
   - **Fix**: Uncaught errors and unhandled rejections inside the iframe are surfaced to the parent so future load failures show a real message instead of an infinite spinner.

5. **Auth & Gateway Hardening**:
   - **Fix**: Gateway passcode login no longer fails when Firebase env credentials are empty — `EnvConfig` now hardcodes TMDB, Last.fm, Clair, Khent, and Breyan fallbacks.
   - **Feature**: `EnvConfig.missingRequired()` lists every missing credential for quick diagnostics.

_Previous releases: [v2.1.0 "Play Zone Overhaul"](https://github.com/khentmoba/Everglow/releases/tag/v2.1.0) · [v2.0.0 "Mobile Optimization"](https://github.com/khentmoba/Everglow/releases/tag/v2.0.0) · [v1.5.3 "Real Iframe Fix"](https://github.com/khentmoba/Everglow/releases/tag/v1.5.3) · [v1.5.2 "PH Trending"](https://github.com/khentmoba/Everglow/releases/tag/v1.5.2) · [v1.5.1 "Sandbox Hardening"](https://github.com/khentmoba/Everglow/releases/tag/v1.5.1) · [v1.5.0 "Cinema"](https://github.com/khentmoba/Everglow/releases/tag/v1.5.0) · [v1.4.0 "Multi-Provider"](https://github.com/khentmoba/Everglow/releases/tag/v1.4.0) · [v1.3.0 "Racing Game"](https://github.com/khentmoba/Everglow/releases/tag/v1.3.0) · [v1.2.0 "Play Zone"](https://github.com/khentmoba/Everglow/releases/tag/v1.2.0) · [All releases →](https://github.com/khentmoba/Everglow/releases)_

---

## Features

| Feature | Description | Version |
|---------|-------------|---------|
| **Gateway** | Animated passcode entry door (1111 = Clair, 2222 = Khent, 9132 = Breyan) | 1.0.0 / 3.0.0 |
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
| **HexGL Boot Fixes** | No-cache iframe, immediate `ready`, progress messages, surface iframe errors | **3.0.0** |

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
    config/                     # EnvConfig with hardcoded API key fallbacks
    constants/                  # API keys
    theme/                      # Dusk Petal romantic palette
  features/
    entry/                      # Passcode gateway (Clair, Khent, Breyan)
    dashboard/                  # Main hub
    heartbeat/                  # Daily mood tracking
    guardian/                   # Animated cat mascot
    academy/                    # Trivia game
    cinema/                     # Movie watch list (TMDB, multi-provider)
    chat/                       # Private couple chat
    starlight_jar/              # Gratitude jar
    canvas/                     # Collaborative drawing
    daily_bloom/                # Virtual garden
    date_randomizer/            # Date idea generator
    xp/                         # Gamification system
    jukebox/                    # Music sync
    play_zone/                  # Games hub
      piano_tiles/              # Melody Tiles (Ticker+CustomPainter engine)
      hexgl/                    # HexGL Drift (HTML5 3D WebGL racing)
  services/                     # Core Firebase services
  shared/widgets/               # Reusable UI components
scripts/
assets/
  data/                         # Seed JSON files (trivia, date ideas)
  images/                       # Logo and milestone photos
  audio/piano/                  # Reference piano samples (a, c, e, f)
web/
  hexgl/                        # HexGL embed HTML (no-cache)
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

- **v3.0.0** — Cinematic Cinema Overhaul, Piano Tiles Rewrite, Breyan Access
- **v2.1.0** — Play Zone Overhaul (HexGL Drift + Song Selection)
- **v2.0.0** — Mobile Optimization & Bloat Cleanup
- **v1.5.3** — Cinema: Real Iframe Fix + Provider Cleanup + Popup-Ad Sandbox
- **v1.5.2** — Philippines Trending: Real Streaming Rankings
- **v1.5.1** — Sandbox Bypass Hardening + Cinema & UI Polish
- **v1.5.0** — Cinema Overhaul (genre, cast, reviews, carousel, trending)
- **v1.4.0** — Cinema: multi-provider video player + episode drawer
- **v1.3.0** — Racing Game: auto-respawn + professional touch UI
- **v1.2.0** — Play Zone: Midnight Drive racing game

See [all releases](https://github.com/khentmoba/Everglow/releases) for the full changelog.

## License

Private — for Khent and Clair only.
