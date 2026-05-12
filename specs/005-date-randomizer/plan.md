# Implementation Plan: Date Randomizer

**Branch**: `005-date-randomizer` | **Date**: 2026-05-11 | **Spec**: [spec.md](file:///c:/APPLICATIONS/Everglow/specs/005-date-randomizer/spec.md)
**Input**: Feature specification from `/specs/005-date-randomizer/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

The Date Randomizer feature addresses the "what should we do today?" problem by providing a gamified interface for selecting relationship activities. Users will interact with a heart-shaped button that triggers a 1.5-second fast-spinning rotation animation before revealing a random date idea from a Firestore-backed collection (seeded with 1000+ ideas) in a bouncy, celebratory dialog.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Dart (Flutter ^3.11.3)  
**Primary Dependencies**: `cloud_firestore`, `animate_do`, `provider`, `google_fonts`, `dart:math`  
**Storage**: Firestore (`date_ideas` collection)  
**Testing**: `flutter test`  
**Target Platform**: Web (Responsive)
**Project Type**: Web Application  
**Performance Goals**: <100ms for random selection; 1.5s exactly for suspense animation.  
**Constraints**: Requires authenticated session; initial fetch should happen on dashboard load.  
**Scale/Scope**: 1 collection, 1 main widget, 1000+ data entries.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

1. **Privacy-First Design**: Feature MUST be implemented within the authenticated `DashboardScreen` area. (Pass)
2. **High-Fidelity Aesthetics**: MUST use `AppColors.primaryPink` (soft pink), 32.0 border radius, and `AnimateDo` for bouncy reveals. (Pass)
3. **Real-Time & Persistent**: Randomizer data is persisted in Firestore; seeding ensures persistence. (Pass)
4. **Scalable Archival**: Firestore collection model allows scaling beyond 1000 ideas. (Pass)
5. **Evolving Core**: Implemented as a modular widget (`RandomizerCard`) and service (`DateIdeaService`). (Pass)

## Project Structure

### Documentation (this feature)

```text
specs/005-date-randomizer/
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
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
lib/
├── features/
│   ├── date_randomizer/
│   │   ├── data/
│   │   │   ├── models/date_idea.dart
│   │   │   └── services/date_idea_service.dart
│   │   └── presentation/
│   │       ├── widgets/randomizer_card.dart
│   │       └── widgets/celebration_dialog.dart
├── core/
│   └── theme/app_colors.dart
assets/
└── data/date_ideas_seed.json

tests/
└── features/date_randomizer/
```

**Structure Decision**: Option 2: Feature-based folder structure under `lib/features/` to keep logic and UI cohesive.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | | |
