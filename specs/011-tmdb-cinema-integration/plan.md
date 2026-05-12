# Implementation Plan: TMDB Cinema Integration

**Branch**: `011-tmdb-cinema-integration` | **Date**: 2026-05-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/011-tmdb-cinema-integration/spec.md`

## Summary

The goal is to upgrade the Everglow Cinema feature by integrating the TMDB API for media search and automated data entry. This will replace manual entry of movie/series details with a live search interface that persists selections to a dedicated Firestore `watch_list` collection.

## Technical Context

**Language/Version**: Dart 3.x (Flutter SDK)  
**Primary Dependencies**: `flutter`, `cloud_firestore`, `http` (to be added), `google_fonts`, `animate_do`  
**Storage**: Cloud Firestore (`watch_list` collection)  
**Testing**: `flutter_test` (unit tests for `TMDBService`)  
**Target Platform**: Web (Flutter Web)
**Project Type**: Web Application  
**Performance Goals**: Search results within 1.5 seconds (debounced)  
**Constraints**: personal-use, soft-pink aesthetic, personal TMDB API Key  
**Scale/Scope**: 1 new service, 1 new screen, 1 modal update

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Privacy-First Design**: ✅ The feature is gated within the authenticated dashboard and Creator Mode.
- **High-Fidelity & Modern Aesthetics**: ✅ Uses GridView with high border radiuses and `animate_do` for a premium feel.
- **Scalable Archival Structure**: ✅ Utilizes a dedicated Firestore collection for long-term media archiving.
- **Evolving Core**: ✅ Modular service design allows for future enhancements (e.g., reviews, ratings).

## Project Structure

### Documentation (this feature)

```text
specs/011-tmdb-cinema-integration/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── service_contract.md
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
lib/
├── features/
│   ├── cinema/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── media_item.dart
│   │   │   └── services/
│   │   │       └── tmdb_service.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── cinema_screen.dart
│   │       └── widgets/
│   │           ├── tmdb_search_modal.dart
│   │           └── media_poster_card.dart
├── core/
│   └── constants/
│       └── api_keys.dart
```

**Structure Decision**: Selected a feature-first structure under `lib/features/cinema` to maintain modularity and alignment with existing project patterns.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| New Service | TMDB API isolation | Direct calls in UI would violate separation of concerns. |
| Separate Collection | `watch_list` | Adding to `milestones` would pollute relationship memories with "to-watch" items. |
