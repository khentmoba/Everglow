# Implementation Plan: Everglow Canvas

**Branch**: `012-everglow-canvas` | **Date**: 2026-05-11 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/012-everglow-canvas/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Implementation of a shared, real-time digital whiteboard for Everglow. This feature uses Firebase Firestore to synchronize freehand drawings (strokes) between 'clair' and 'khent'. It features a "pinkish and very cute" aesthetic with a glassmorphism toolbar, pastel color palette, and a confirmation-gated canvas reset.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Flutter (Dart)
**Primary Dependencies**: `cloud_firestore`, `firebase_core`
**Storage**: Firebase Cloud Firestore (`canvas_strokes` collection)
**Testing**: `flutter test`
**Target Platform**: Flutter Web
**Project Type**: Flutter Web Application
**Performance Goals**: 60 FPS drawing, <500ms sync latency.
**Constraints**: Privacy-gated (restricted to clair/khent), normalized coordinate system.
**Scale/Scope**: 2 users, single shared canvas.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Gate: Privacy-First Design**: PASS. Implementation MUST verify user identity ('clair' or 'khent') before allowing access to the Canvas or its stream.
- **Gate: High-Fidelity Aesthetics**: PASS. Design uses the project's signature pink palette, glassmorphism, and smooth transitions.
- **Gate: Real-Time Engagement**: PASS. Firestore streams provide immediate visual feedback of shared activities.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
lib/
└── features/
    └── canvas/
        ├── models/
        │   └── doodle_stroke.dart
        ├── services/
        │   └── canvas_service.dart
        ├── screens/
        │   └── canvas_screen.dart
        └── widgets/
            ├── canvas_toolbar.dart
            └── canvas_painter.dart
```

**Structure Decision**: Single-feature modular structure under `lib/features/canvas/`, following the existing project pattern.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
