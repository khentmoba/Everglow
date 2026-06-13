# Everglow

[![Latest Release](https://img.shields.io/github/v/release/khentmoba/Everglow?style=flat-square&label=latest&color=rgba(194,24,91,0.6))](https://github.com/khentmoba/Everglow/releases/latest)
[![Deploy Status](https://img.shields.io/github/actions/workflow/status/khentmoba/Everglow/deploy.yml?style=flat-square&label=deploy)](https://github.com/khentmoba/Everglow/actions/workflows/deploy.yml)
[![Firebase Hosting](https://img.shields.io/badge/hosted%20on-firebase-FFCA28?style=flat-square&logo=firebase)](https://everglow-1c6db.web.app)

A private digital relationship scrapbook built with Flutter Web for **Khent** and **Clair**.

Everglow tracks your relationship journey through gamified experiences, shared activities, and daily engagement — all wrapped in a warm, animated interface.

## Live Site

**[everglow-1c6db.web.app](https://everglow-1c6db.web.app)**

## Latest Release

> **v3.1.0** — Live Presence, Hover-to-Play Trailers & Our Cinema Glass UI
> [View full changelog →](https://github.com/khentmoba/Everglow/releases/latest)

**v3.1.0 — The Live & Cinematic Update:**

1. **Real-Time Presence Service**:
   - **Feature**: New `PresenceService` writes a 15 s heartbeat to Firestore `presence/{uid}` with `isOnline`, `lastSeen`, `isDoodling`, and `lastDoodleAt` so the partner can see exactly when you're around.
   - **Feature**: New `PartnerPresenceIndicator` widget renders a pulsing green dot in the Sanctuary chat header — "Clair is active" or "Active 5m ago" with second-level precision.
   - **Feature**: New `PartnerDoodleIndicator` overlay on the Canvas screen shows a live "Clair is doodling ✨ 12s" banner with an animated dot whenever the partner is actively drawing.
   - **Feature**: Dashboard wires the heartbeat into `WidgetsBindingObserver` and the browser's `pagehide` / `beforeunload` events — the user flips offline the moment they close the tab.

2. **Trailer Player + YouTube Integration**:
   - **Feature**: New `TrailerPlayer` widget uses a dedicated `HTMLIFrameElement` YouTube embed with `autoplay`, `muted`, `controls=0`, `loop=1`, `playlist={key}`, `enablejsapi=1`, `playsinline=1`, `modestbranding=1` and `pointer-events: none` so the iframe never blocks the parent gesture surface.
   - **Feature**: `TMDBService.fetchTrailerKey(tmdbId, mediaType)` hits `/{type}/{id}/videos` with a priority chain — official YouTube Trailer → any YouTube Trailer → any YouTube video — and caches the result per `mediaType_tmdbId`.
   - **Feature**: The trending hero carousel now swaps its still backdrop for the live, muted, looping YouTube trailer of the active card 2.5 s after the page settles.
   - **Feature**: Desktop hover on a poster tile scales it to 1.15×, drops a rose-glow shadow, and 600 ms later swaps the poster for the looping trailer preview.
   - **Feature**: A floating "Watch Trailer" button on the cinematic hero backdrop of the Episode Drawer opens a full trailer player with a "Close Trailer" pill.

3. **Our Cinema Glass UI + Couple Badges**:
   - **Feature**: Glassmorphic dark cards (`Color(0x2E2A1B3D)`) with deep-rose border + 24 px shadow lift on hover.
   - **Feature**: New "Watched Together 💞" gradient pill (Khent → Clair) replaces the per-user chips when both partners have watched. Otherwise two compact avatar pills (K / C) light up in their respective accent color.
   - **Feature**: Hover-to-play trailers on every list row with a "TRAILER" green pill that animates in while the trailer plays.
   - **Feature**: New `+` header button opens `TMDBSearchModal` with `initialScope: 'ours'`, pre-selecting the couple chip.
   - **Feature**: Empty "To Watch" state shows a glowing "Add a movie or series" CTA that jumps straight to the same modal.
   - **Feature**: `OurCinemaItem.toMediaItem()` adapter lets the shared list reuse the same `EpisodeDrawer` and watch flow as the personal Cinema screen.

4. **Videasy Provider Polish**:
   - **Feature**: `VideoPlayerScreen` now appends `?autoplay=true` for movies and `?autoplay=true&nextButton=true&episodeSelector=true` for TV when the selected provider is Videasy.

5. **Bug Fixes & Polish**:
   - **Fix**: Guardian particles now animate their position correctly — `AnimatedPositioned` owns the key, `IgnorePointer` is the child.
   - **Fix**: Guardian color uses `withValues(alpha:)` to silence the deprecation.
   - **Fix**: Episode drawer backdrop has a proper `errorBuilder` fallback.
   - **Fix**: Cinema carousel hero backdrop has a velvet fallback on image failure.
   - **Fix**: Sanctuary chat header now shows the live partner indicator instead of a static version stamp.
   - **Fix**: Stripped the UTF-8 BOM from `episode_drawer.dart` and tightened the `_trailerKey!` null assertion in the trailer stack.

_Previous releases: [v3.0.0 "Cinematic & Performance"](https://github.com/khentmoba/Everglow/releases/tag/v3.0.0) · [v2.1.0 "Play Zone Overhaul"](https://github.com/khentmoba/Everglow/releases/tag/v2.1.0) · [v2.0.0 "Mobile Optimization"](https://github.com/khentmoba/Everglow/releases/tag/v2.0.0) · [v1.5.3 "Real Iframe Fix"](https://github.com/khentmoba/Everglow/releases/tag/v1.5.3) · [v1.5.2 "PH Trending"](https://github.com/khentmoba/Everglow/releases/tag/v1.5.2) · [v1.5.1 "Sandbox Hardening"](https://github.com/khentmoba/Everglow/releases/tag/v1.5.1) · [v1.5.0 "Cinema"](https://github.com/khentmoba/Everglow/releases/tag/v1.5.0) · [v1.4.0 "Multi-Provider"](https://github.com/khentmoba/Everglow/releases/tag/v1.4.0) · [v1.3.0 "Racing Game"](https://github.com/khentmoba/Everglow/releases/tag/v1.3.0) · [v1.2.0 "Play Zone"](https://github.com/khentmoba/Everglow/releases/tag/v1.2.0) · [All releases →](https://github.com/khentmoba/Everglow/releases)_

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

## Tech Stack

- **Framework:** Flutter (Web)
- **Backend:** Firebase (Auth, Firestore, Storage, Hosting)
- **State Management:** Provider
- **External APIs:** TMDB, OpenTDB (Trivia), Last.fm
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
CHANGELOG.md                    # Full release-by-release history (v1.0.0 → v3.1.0)
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
