# Implementation Plan: Creator Mode Admin Panel

**Branch**: `009-creator-mode` | **Date**: 2026-05-11 | **Spec**: [spec.md](file:///c:/APPLICATIONS/Everglow/specs/009-creator-mode/spec.md)
**Input**: Feature specification from `/specs/009-creator-mode/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

The Creator Mode is a hidden administrative interface for the Everglow app, visible only to 'khent'. It allows for the real-time addition of relationship memories and secret letters. The technical approach involves a `showModalBottomSheet` triggered by a gated icon button, using `image_picker` and `firebase_storage` for media handling, and direct Firestore integration for data persistence.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x  
**Primary Dependencies**: `firebase_core`, `cloud_firestore`, `firebase_storage`, `image_picker`  
**Storage**: Cloud Firestore (NoSQL), Firebase Storage (Media)  
**Testing**: Manual UI verification + Firestore data integrity checks  
**Target Platform**: Flutter Web  
**Project Type**: Web Application  
**Performance Goals**: < 2s for submission feedback, 60fps animations  
**Constraints**: Privacy-gated (Passcode '2222'), Mobile-first (max 500px), Scrollable forms  
**Scale/Scope**: Admin-only tool, 2 primary forms, Firestore/Storage integration

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Privacy-First Design**: ✅ Verified. Access is strictly gated by `currentUser` state logic.
- **High-Fidelity & Modern Aesthetics**: ✅ Verified. Modal uses glassmorphism-lite, pink themes, and custom TabBar styling.
- **Real-Time & Persistent Engagement**: ✅ Verified. Submissions trigger immediate UI updates via Firestore streams.
- **Scalable Archival Structure**: ✅ Verified. Extends existing `Milestone` and `HiddenNote` schema.
- **Evolving Core**: ✅ Verified. Implemented as a modular widget (`CreatorModal`) to prevent dashboard clutter.

## Project Structure

### Documentation (this feature)

```text
specs/009-creator-mode/
├── plan.md              # This file
├── research.md          # Decision log (Image Picker, TabBar, Scrolling)
├── data-model.md        # Entities: Milestone, HiddenNote
├── quickstart.md        # Setup & Usage guide
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── spec.md              # Feature specification
```

### Source Code (repository root)

```text
lib/
├── features/
│   ├── dashboard/
│   │   ├── presentation/
│   │   │   ├── widgets/
│   │   │   │   ├── creator_modal.dart    [NEW] Modular admin panel widget
│   │   │   │   └── dashboard_screen.dart [MODIFY] Add gated admin icon
│   │   │   └── screens/
│   │   └── data/
│   │       └── services/
│   │           └── creator_service.dart   [NEW] Handle Firestore/Storage logic
└── services/
    └── auth_service.dart [EXISTING] Reference for currentUser
```

**Structure Decision**: Single project structure within the existing Flutter feature-based architecture (`features/dashboard`).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*No violations detected. The design adheres strictly to the Digital Sanctuary Constitution.*
