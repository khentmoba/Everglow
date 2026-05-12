# Implementation Plan: Daily Bloom

**Branch**: `007-daily-bloom` | **Date**: 2026-05-11 | **Spec**: [spec.md](file:///c:/APPLICATIONS/Everglow/specs/007-daily-bloom/spec.md)
**Input**: Feature specification from `/specs/007-daily-bloom/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Build the "Daily Bloom" gamified digital garden for the Everglow dashboard. This feature tracks user engagement (visits and notes read) in Firestore and visualizes progress through 5 growth stages of a pink lily. The implementation involves creating a `GardenStats` domain model, a Firestore-backed service for tracking interactions/streaks, and a high-fidelity animated Flutter widget integrated into the main dashboard.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x (Web)
**Primary Dependencies**: `cloud_firestore`, `firebase_auth`, `provider`, `flutter_animate` (or built-in animations)
**Storage**: Firestore (`users/{uid}/garden_stats/stats`)
**Testing**: Flutter widget tests, unit tests for streak logic
**Target Platform**: Web
**Project Type**: Web application feature
**Performance Goals**: 60 FPS for breathing and transition animations
**Constraints**: Privacy-first (user-scoped data), soft pink aesthetic
**Scale/Scope**: 5 growth stages, real-time stats tracking

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Rationale |
|-----------|--------|-----------|
| I. Privacy-First | ✅ PASS | Data is stored in user-scoped Firestore documents; access is gated by existing Auth. |
| II. High-Fidelity | ✅ PASS | Features breathing animations, pulse effects, and stage transitions matching Everglow aesthetic. |
| III. Real-Time | ✅ PASS | Uses Firestore listeners (or immediate updates) for interaction tracking and streak counts. |
| IV. Scalable | ✅ PASS | Modular architecture under `lib/features/daily_bloom` allows for future garden expansions. |
| V. Evolving | ✅ PASS | Gamification encourages long-term engagement and evolves with user activity. |

## Project Structure

### Documentation (this feature)

```text
specs/007-daily-bloom/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── checklists/          # Quality checklists
└── spec.md              # Feature specification
```

### Source Code (repository root)

```text
lib/
├── features/
│   ├── daily_bloom/
│   │   ├── data/
│   │   │   ├── models/            # GardenStats model
│   │   │   └── services/          # GardenService (Firestore)
│   │   ├── domain/
│   │   │   └── repository/        # Garden repository interface
│   │   └── presentation/
│   │       ├── widgets/           # DailyBloom widget, LilyPainter
│   │       └── providers/         # GardenProvider (State management)
├── services/
│   └── interaction_hook.dart      # Global hook for tracking visits/note reads
```

**Structure Decision**: Clean Architecture (Layered) within the `features/daily_bloom` directory to maintain consistency with existing features like `guardian` and `dashboard`.

## Complexity Tracking

*No violations detected.*
