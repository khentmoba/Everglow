# Everglow

A private digital relationship scrapbook built with Flutter Web for **Khent** and **Clair**.

Everglow tracks your relationship journey through gamified experiences, shared activities, and daily engagement — all wrapped in a warm, animated interface.

## Live Site

**[everglow-1c6db.web.app](https://everglow-1c6db.web.app)**

## Features

| Feature | Description |
|---------|-------------|
| **Gateway** | Animated passcode entry door (1111 = Clair, 2222 = Khent) |
| **Dashboard** | Main hub with anniversary counter, XP, and all feature cards |
| **Heartbeat** | Daily mood tracking with partner status indicators |
| **Guardian** | Animated cat mascot with random messages and mood prompts |
| **Academy** | Trivia game with 8 categories, solo study and 1v1 challenges |
| **Cinema** | Shared movie/TV watch list powered by TMDB |
| **Sanctuary** | Private real-time couple's chat |
| **Starlight Jar** | Drop gratitude notes and memories into a virtual jar |
| **Canvas** | Collaborative drawing with real-time sync |
| **Daily Bloom** | Virtual garden that grows with daily visits |
| **Date Randomizer** | 1000+ date ideas — shake to discover |
| **Jukebox** | Live music status from Last.fm for both partners |
| **XP System** | Gamified levels, streaks, and sound effects |

## Tech Stack

- **Framework:** Flutter (Web)
- **Backend:** Firebase (Auth, Firestore, Storage, Hosting)
- **State Management:** Provider
- **External APIs:** TMDB, OpenTDB (Trivia), Last.fm

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

# Install dependencies
flutter pub get

# Run locally
flutter run -d chrome
```

### Firebase Configuration

1. Place your Firebase admin SDK JSON in the project root:
   ```
   everglow-1c6db-firebase-adminsdk-*.json
   ```

2. The `firebase_options.dart` is pre-configured for the `everglow-1c6db` project.

3. To deploy:
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```

### Environment Variables

The TMDB API key is stored in `lib/core/constants/api_keys.dart`. Update it with your own key if needed.

## Project Structure

```
lib/
  main.dart                     # Entry point, Provider setup
  core/
    audio/                      # Sound effects (just_audio)
    constants/                  # API keys
    theme/                      # Gamified pink theme
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
  services/                     # Core Firebase services
  shared/widgets/               # Reusable UI components
assets/
  data/                         # Seed JSON files (trivia, date ideas)
  images/                       # Logo and milestone photos
```

## Deployment

Auto-deploys to Firebase Hosting on push to `main` via GitHub Actions.

The workflow:
1. Builds Flutter web
2. Generates changelog from commits
3. Deploys to Firebase Hosting
4. Creates a GitHub Release

## License

Private — for Khent and Clair only.
