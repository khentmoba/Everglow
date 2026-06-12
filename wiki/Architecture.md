# Architecture

## Design Philosophy

Everglow uses a **feature-first architecture** with clean separation of concerns. Each feature is self-contained with its own screens, widgets, services, and models.

## Project Structure

```
lib/
  main.dart                          # Entry point
  firebase_options.dart              # Firebase config (web only)
  theme.dart                         # Legacy theme (polaroid/cream)
  
  core/
    audio/audio_service.dart         # Sound effects (just_audio)
    constants/api_keys.dart          # TMDB API key
    theme/app_theme.dart             # Active gamified pink theme
    utils/seed_first_date.dart
  
  services/                          # Core Firebase services
    auth_service.dart                # Firebase Auth + session
    database_service.dart            # Legacy Firestore CRUD
    storage_service.dart             # Firebase Storage uploads
  
  screens/                           # Legacy screens
    login_screen.dart
    timeline_screen.dart
    add_memory_form.dart
  
  shared/widgets/                    # Reusable UI components
    gamified_background.dart
    circuitry_painter.dart
    glass_container.dart
    bouncy_button.dart
    animated_emblem.dart
  
  features/                          # Feature modules (15 total)
    entry/                           # Passcode gateway
    dashboard/                       # Main hub
    heartbeat/                       # Daily mood tracking
    guardian/                        # Animated cat mascot
    academy/                         # Trivia game
    cinema/                          # Movie watch list
    chat/                            # Private couple chat
    starlight_jar/                   # Gratitude jar
    canvas/                          # Collaborative drawing
    daily_bloom/                     # Virtual garden
    date_randomizer/                 # Date idea generator
    xp/                              # Gamification system
    jukebox/                         # Music sync
```

## Feature Module Structure

Each feature follows this pattern:

```
features/example/
  presentation/
    screens/         # Full-page screens
    widgets/         # Feature-specific widgets
    controllers/     # State management (ChangeNotifier)
    providers/       # Provider wrappers
  data/
    services/        # Firestore/API interaction
    models/          # Data models
    repository/      # Repository pattern (optional)
  domain/
    models/          # Domain models (optional)
```

## State Management

**Provider** (ChangeNotifier-based) is used throughout:

```dart
// In main.dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthService()),
    ChangeNotifierProvider(create: (_) => JukeboxProvider()),
    ChangeNotifierProvider(create: (_) => GardenProvider()),
    ChangeNotifierProvider(create: (_) => GuardianController()),
    ChangeNotifierProvider(create: (_) => MoodController()),
    // ...
  ],
  child: MyApp(),
)
```

## Navigation Flow

```
GatewayPage (passcode gate)
  |
  |-- Passcode 1111 --> Auth as Clair
  |-- Passcode 2222 --> Auth as Khent
  |
  v
DashboardScreen (main hub)
  |
  |-- Chat button --> SanctuaryChatScreen
  |-- Canvas button --> CanvasScreen
  |-- Academy portal --> AcademyHubScreen
  |     |-- Solo Study --> SoloStudyScreen
  |     |-- 1v1 Challenge --> GameBoardScreen
  |-- Creator button (Khent only) --> CreatorModal
  |-- Feature cards --> Feature screens
```

## Data Flow

```
User Action
  |
  v
Widget (presentation)
  |
  v
Controller/Provider (state management)
  |
  v
Service (business logic)
  |
  v
Firestore/API (data layer)
```

## Firebase Collections

| Collection | Feature | Purpose |
|------------|---------|---------|
| `milestones` | Dashboard | Relationship milestones |
| `notes` | Dashboard | Hidden notes |
| `moods` | Heartbeat | Daily mood entries |
| `sanctuary_messages` | Chat | Couple's messages |
| `starlight_jar` | Starlight Jar | Gratitude notes |
| `canvas_strokes` | Canvas | Drawing strokes |
| `live_canvas` | Canvas | Real-time canvas state |
| `date_ideas` | Date Randomizer | Date ideas |
| `guardian_messages` | Guardian | Cat messages |
| `academy_questions` | Academy | Trivia questions |
| `active_matches` | Academy | 1v1 matches |
| `watch_list` | Cinema | Movie watch list |
| `users/{uid}/progress` | XP | User progress |
| `users/{uid}/garden_stats` | Daily Bloom | Garden state |

## Key Patterns

- **Repository Pattern** — Used in Daily Bloom for data abstraction
- **Service Layer** — All Firebase interactions go through services
- **Batch Writes** — Firestore batch operations for seeding data
- **Real-time Streaming** — Firestore snapshots for chat, canvas, music
- **Offline Persistence** — Firestore cache enabled with unlimited size
