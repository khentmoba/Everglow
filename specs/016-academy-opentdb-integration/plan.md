# Implementation Plan: Everglow Academy OpenTDB Integration

**Branch**: `016-academy-opentdb-integration` | **Date**: 2026-05-11 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/016-academy-opentdb-integration/spec.md`

## Summary

Upgrade Everglow Academy to automatically fetch trivia questions from the Open Trivia Database (OpenTDB) API. The implementation focuses on a robust `TriviaApiService` that handles session tokens (via `SharedPreferences`), rate limiting (exponential backoff), and HTML entity decoding. New questions are mapped to internal categories and stored in Firestore with content-hash IDs to prevent duplicates, ensuring a seamless and infinite study experience.

## Technical Context

**Language/Version**: Dart (Flutter)
**Primary Dependencies**: `html_unescape`, `shared_preferences`, `crypto`, `http`, `cloud_firestore`
**Storage**: Firestore (`AcademyQuestion` collection), `SharedPreferences` (session token)
**Testing**: Flutter Unit/Widget tests
**Target Platform**: Flutter Web
**Project Type**: Web Application
**Performance Goals**: API response + mapping < 2s; Token reset < 5s
**Constraints**: OpenTDB rate limit (1 req/5s), background trigger (< 10 unanswered)
**Scale/Scope**: Automated replenishment (50 questions per fetch)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Privacy-First Design**: PASS. Trivia content is public data; session tokens are non-sensitive and stored locally.
- **High-Fidelity & Modern Aesthetics**: PASS. Implementation includes "cute" themed loading animations and premium text decoding.
- **Real-Time & Persistent Engagement**: PASS. Supports real-time 1v1 synchronization and automated database replenishment.
- **Scalable Archival Structure**: PASS. Uses Firestore for scalable question storage with duplicate prevention via content hashing.
- **Evolving Core**: PASS. Modular `TriviaApiService` allows for future expansion or swapping of trivia sources.

## Project Structure

### Documentation (this feature)

```text
specs/016-academy-opentdb-integration/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # OpenTDB API & package research
├── data-model.md        # Firestore schema & mapping
├── quickstart.md        # Implementation guide
├── contracts/
│   └── trivia_api_service.md # Service interface
└── checklists/
    └── requirements.md  # Quality validation
```

### Source Code (repository root)

```text
lib/features/academy/
├── models/
│   └── academy_question.dart  # [MODIFY] Added diff, source, hash logic
├── services/
│   ├── trivia_api_service.dart # [NEW] OpenTDB client & mapping
│   └── academy_sync_service.dart # [NEW] Auto-fill & Firestore logic
└── presentation/
    └── widgets/
        └── trivia_loading_overlay.dart # [NEW] Cute loading animation
```

**Structure Decision**: Single-feature module under `lib/features/academy/` to maintain modularity and ease of 1v1 synchronization testing.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |
