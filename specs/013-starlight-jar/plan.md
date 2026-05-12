# Implementation Plan: Starlight Jar

**Branch**: `013-starlight-jar` | **Date**: 2026-05-11 | **Spec**: [spec.md](file:///c:/APPLICATIONS/Everglow/specs/013-starlight-jar/spec.md)
**Input**: Feature specification from `/specs/013-starlight-jar/spec.md`

## Summary
The Starlight Jar is a digital gratitude vault for Everglow. It features a glassmorphic jar that collects "StarNotes" (persisted in Firestore). The feature includes high-fidelity animations for dropping stars from the top of the screen and a "shake-to-reveal" interaction to retrieve random gratitude notes.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x (Web)  
**Primary Dependencies**: `cloud_firestore`, `firebase_core`, `provider`  
**Storage**: Firestore (`starlight_jar` collection)  
**Testing**: Flutter Widget Tests & Manual Interaction Verification  
**Target Platform**: Web  
**Project Type**: Flutter Web Feature  
**Performance Goals**: 60 FPS while rendering 100 animated stars  
**Constraints**: Glassmorphism (BackdropFilter), 1s shake, 2s drop animation  
**Scale/Scope**: Limit to 100 most recent stars for performance

## Constitution Check

*GATE: Passed. Feature aligns with Privacy-First, High-Fidelity, and Real-Time engagement principles.*

- **Privacy**: Author attribution ('khent'/'clair') is handled via existing `currentUser` state.
- **Aesthetics**: Glassmorphism and custom animations meet the "premium experience" requirement.
- **Real-Time**: Firestore streams ensure both users see stars drop in real-time.

## Project Structure

### Documentation (this feature)

```text
specs/013-starlight-jar/
├── plan.md              # This file
├── research.md          # Implementation decisions and animation logic
├── data-model.md        # StarNote entity definition
├── quickstart.md        # Testing and verification steps
├── checklists/
│   └── requirements.md  # Quality validation
└── spec.md              # Feature specification
```

### Source Code (repository root)

```text
lib/features/starlight_jar/
├── data/
│   └── services/
│       └── starlight_service.dart   # Firestore stream & addStar
├── domain/
│   └── models/
│       └── star_note.dart           # StarNote model
└── presentation/
    ├── widgets/
    │   ├── glass_jar.dart           # CustomPaint/Glassmorphism jar
    │   ├── star_widget.dart         # Animated star icon
    │   └── drop_star_dialog.dart    # Input dialog
    └── screens/
        └── starlight_jar_widget.dart # Main entry point for dashboard integration
```

**Structure Decision**: A dedicated feature folder `lib/features/starlight_jar/` following the project's established pattern (similar to `012-everglow-canvas`).

## Complexity Tracking

*No violations detected.*
