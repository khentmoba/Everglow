# Implementation Plan: Everglow Guardian

**Branch**: `006-everglow-guardian` | **Date**: 2026-05-11 | **Spec**: [spec.md](file:///C:/APPLICATIONS/Everglow/specs/006-everglow-guardian/spec.md)
**Input**: Feature specification from `/specs/006-everglow-guardian/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Implement the Everglow Guardian, a persistent interactive character (cat) as a viewport overlay on the dashboard. It features idle animations (breathing/floating), a "Welcome" greeting, and tap-triggered reactions (jump, spin, heart particles). Messages are fetched from Firestore with local seeding to provide sweet, randomized companionship.

## Technical Context

**Language/Version**: Dart (Flutter 3.x)
**Primary Dependencies**: `cloud_firestore`, `provider`
**Storage**: Firebase Firestore (`guardian_messages` collection)
**Testing**: Flutter Widget Tests
**Target Platform**: Web (private application)
**Project Type**: Flutter Web Component
**Performance Goals**: 60 FPS animation smoothness
**Constraints**: Pure Flutter widgets only (no external animation engines)
**Scale/Scope**: Persistent dashboard overlay, randomized interaction reactions, Firestore-backed messaging system.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Privacy-First Design**: ✅ PASSED. The Guardian is a purely internal UI element within the authenticated dashboard.
- **High-Fidelity Aesthetics**: ✅ PASSED. Designs use soft pinks, white, bouncy animations, and particle effects.
- **Real-Time Engagement**: ✅ PASSED. Implements a persistent pet system with spontaneous real-time interactions.
- **Scalable Archival Structure**: ✅ PASSED. Messaging system uses a scalable Firestore collection.
- **Evolving Core**: ✅ PASSED. Built as a modular dashboard layer that can be expanded with more moods/messages.

## Project Structure

### Documentation (this feature)

```text
specs/006-everglow-guardian/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
lib/
├── features/
│   └── guardian/
│       ├── data/
│       │   ├── models/
│       │   │   └── guardian_message.dart
│       │   └── services/
│       │       └── guardian_service.dart
│       └── presentation/
│           ├── widgets/
│           │   ├── character/
│           │   │   └── cat_visuals.dart
│           │   ├── everglow_guardian.dart
│           │   └── thought_bubble.dart
│           └── controllers/
│               └── guardian_controller.dart
```

**Structure Decision**: Option 1: Single project (Flutter feature-based modular structure).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*No violations identified.*
