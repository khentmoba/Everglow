# Everglow Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-05-11

## Active Technologies
- Dart / Flutter Web + Flutter Material, Flutter Animations (001-cute-entry-gateway)
- N/A (Visual overlay only) (001-cute-entry-gateway)
- [e.g., Python 3.11, Swift 5.9, Rust 1.75 or NEEDS CLARIFICATION] + [e.g., FastAPI, UIKit, LLVM or NEEDS CLARIFICATION] (002-cute-main-structure)
- [if applicable, e.g., PostgreSQL, CoreData, files or N/A] (002-cute-main-structure)
- Dart (Flutter) + Flutter SDK, `age_calculator` (002-cute-main-structure)
- Dart 3.x, Flutter 3.x + Flutter SDK, `google_fonts` (if used), standard Flutter UI toolkit (`ListView`, `AlertDialog`, `GestureDetector`, etc.) (003-dynamic-letterbox)
- In-memory (dummy data) (003-dynamic-letterbox)
- Dart 3 / Flutter 3.x (SDK ^3.11.3 per pubspec.yaml) + `cloud_firestore ^5.0.1`, `google_fonts ^6.2.1` (Quicksand), `animate_do ^3.3.4`, `intl ^0.19.0` (004-living-archive-timeline)
- Cloud Firestore — top-level `milestones/{id}` collection (004-living-archive-timeline)
- Dart (Flutter ^3.11.3) + `cloud_firestore`, `animate_do`, `provider`, `google_fonts`, `dart:math` (005-date-randomizer)
- Firestore (`date_ideas` collection) (005-date-randomizer)
- Dart (Flutter 3.x) + `cloud_firestore`, `provider` (006-everglow-guardian)
- Firebase Firestore (`guardian_messages` collection) (006-everglow-guardian)
- Dart 3.x / Flutter 3.x (Web) + `cloud_firestore`, `firebase_auth`, `provider`, `flutter_animate` (or built-in animations) (007-daily-bloom)
- Firestore (`users/{uid}/garden_stats/stats`) (007-daily-bloom)
- Dart (Flutter SDK ^3.11.3) + `provider`, `cloud_firestore`, `animate_do` (008-sanctuary-chat)
- Firestore (`messages` collection) (008-sanctuary-chat)
- Dart 3.x / Flutter 3.x + `firebase_core`, `cloud_firestore`, `firebase_storage`, `image_picker` (009-creator-mode)
- Cloud Firestore (NoSQL), Firebase Storage (Media) (009-creator-mode)
- Dart 3.x (Flutter SDK) + `flutter`, `cloud_firestore`, `http` (to be added), `google_fonts`, `animate_do` (011-tmdb-cinema-integration)
- Cloud Firestore (`watch_list` collection) (011-tmdb-cinema-integration)
- Flutter (Dart) + `cloud_firestore`, `firebase_core` (012-everglow-canvas)
- Firebase Cloud Firestore (`canvas_strokes` collection) (012-everglow-canvas)
- Dart 3.x / Flutter 3.x (Web) + `cloud_firestore`, `firebase_core`, `provider` (013-starlight-jar)
- Firestore (`starlight_jar` collection) (013-starlight-jar)
- Flutter (Stable) + `cloud_firestore`, `provider`, `simple_animations` (or native Flutter animations) (014-heartbeat-sync)
- Firebase Firestore (`moods` collection) (014-heartbeat-sync)
- Flutter (Dart) 3.x + `firebase_core`, `cloud_firestore`, `confetti`, `google_fonts`, `provider` (or existing state management). (015-everglow-academy)
- Firebase Firestore (`active_matches`, `academy_questions`, `user_stats`). (015-everglow-academy)
- Dart (Flutter) + `html_unescape`, `shared_preferences`, `crypto`, `http`, `cloud_firestore` (016-academy-opentdb-integration)
- Firestore (`AcademyQuestion` collection), `SharedPreferences` (session token) (016-academy-opentdb-integration)
- Dart 3.x / Flutter 3.x + `flutter`, `cloud_firestore`, `google_fonts`, `just_audio` (SFX), `animate_do` (Animations) (018-gamified-pink-ui)
- Cloud Firestore (XP persistence) (018-gamified-pink-ui)

- React (Vite-based preferably) (main)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for React (Vite-based preferably)

## Code Style

React (Vite-based preferably): Follow standard conventions

## Recent Changes
- 018-gamified-pink-ui: Added Dart 3.x / Flutter 3.x + `flutter`, `cloud_firestore`, `google_fonts`, `just_audio` (SFX), `animate_do` (Animations)
- 017-everglow-jukebox: Added [e.g., Python 3.11, Swift 5.9, Rust 1.75 or NEEDS CLARIFICATION] + [e.g., FastAPI, UIKit, LLVM or NEEDS CLARIFICATION]
- 016-academy-opentdb-integration: Added Dart (Flutter) + `html_unescape`, `shared_preferences`, `crypto`, `http`, `cloud_firestore`


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
