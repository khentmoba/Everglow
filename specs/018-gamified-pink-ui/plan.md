# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

The "Gamified Pink" UI Modernization overhauls the entire Everglow application from a flat pastel aesthetic to a layered, high-fidelity experience using glassmorphism, shifting gradients, and micro-animations. Key technical additions include a Firestore-backed XP persistence system, a dynamic theme engine with performance fallbacks, and subtle audio feedback for interactions.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Dart 3.x / Flutter 3.x  
**Primary Dependencies**: `flutter`, `cloud_firestore`, `google_fonts`, `just_audio` (SFX), `animate_do` (Animations)  
**Storage**: Cloud Firestore (XP persistence)  
**Testing**: Flutter Test (Widget and Integration)  
**Target Platform**: Flutter Web (Mobile-constrained max 500px)
**Project Type**: Mobile Web App  
**Performance Goals**: 60 FPS animations, <16ms interaction latency  
**Constraints**: Privacy-gated (Firebase Auth), Mobile-first layout, Performance fallback for low-end hardware  
**Scale/Scope**: 5 Main Screens (Dashboard, Archive, Academy, Chat, Lock), 2 concurrent users

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Gate: Privacy-First Design
- [x] Ensure `UserProgress` data in Firestore is properly scoped to the user's UID and protected by security rules.
- [x] Verify no sensitive relationship metadata is exposed in the new UI components without auth.

### Gate: High-Fidelity & Modern Aesthetics
- [x] UI MUST implement glassmorphism tokens (blur, opacity, border) consistently.
- [x] Animations MUST use eased curves for a "bouncy" feel.
- [x] Custom fonts MUST be integrated and tested for readability against gradient backgrounds.

### Gate: Evolving Core (Modularity)
- [x] Theme tokens MUST be defined in a centralized `AppTheme` class or similar for easy updates.
- [x] XP logic MUST be decoupled from the UI to allow for future expansion of level-up rewards.

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
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout

```text
lib/
├── core/
│   ├── theme/           # [NEW] Gamified Pink theme tokens & fallback logic
│   └── audio/           # [NEW] Subtle SFX management
├── features/
│   ├── xp/              # [NEW] Firestore XP persistence & logic
│   ├── dashboard/       # [MOD] Overhauled cards & roulette
│   ├── academy/         # [MOD] Portal & selection elements
│   ├── archive/         # [MOD] Film-reel borders
│   └── lock/            # [MOD] Numeric matrix & handle
└── shared/
    └── widgets/         # [MOD] Glassmorphism containers & textured icons
```

**Structure Decision**: A feature-first Flutter structure. Global theme tokens and audio management live in `core/`, while specific UI overhauls are handled within their respective feature directories. The `xp` logic is introduced as a new feature module.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
