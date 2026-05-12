# Implementation Plan: Dynamic Letterbox

**Branch**: `003-dynamic-letterbox` | **Date**: 2026-05-08 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/003-dynamic-letterbox/spec.md`

## Summary

The Dynamic Letterbox is a new UI component for the main dashboard that displays a horizontal scrolling list of digital envelopes (HiddenNotes). These envelopes have three distinct states: locked (sealed with a countdown), unread unlocked (glowing and inviting), and read unlocked (visually indicating it was opened). Unlocked notes display a cute, scrollable dialog with a handwritten-style font when opened, while locked notes trigger a playful rejection alert.

## Technical Context

**Language/Version**: Dart 3.x, Flutter 3.x  
**Primary Dependencies**: Flutter SDK, `google_fonts` (if used), standard Flutter UI toolkit (`ListView`, `AlertDialog`, `GestureDetector`, etc.)  
**Storage**: In-memory (dummy data)  
**Testing**: Flutter test (`testWidgets`)  
**Target Platform**: Web (primarily), with responsive design for mobile.  
**Project Type**: Flutter Web Application  
**Performance Goals**: 60 fps for animations, dialog load time < 0.5s.  
**Constraints**: Must match the global cute design system (rounded corners, soft shadows).  
**Scale/Scope**: 1 UI Component (`LetterboxView`), 1 Data Model (`HiddenNote`), 1 Dialog Widget.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Privacy-First Design**: Passed. This component displays dummy data currently, but respects the private dashboard environment.
- **II. High-Fidelity & Modern Aesthetics**: Passed. The design calls for soft shadows, high border radiuses, and smooth scale-in animations.
- **III. Real-Time & Persistent Engagement**: Passed. The notes are time-locked, providing engagement based on current time.
- **IV. Scalable Archival Structure**: Passed. The component is modular and can eventually hook into the archive system.
- **V. Evolving Core**: Passed. Built modularly to sit directly below the MetricCard.

## Project Structure

### Documentation (this feature)

```text
specs/003-dynamic-letterbox/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
lib/
├── features/
│   └── dashboard/
│       ├── domain/
│       │   └── models/
│       │       └── hidden_note.dart
│       └── presentation/
│           ├── widgets/
│           │   ├── letterbox_view.dart
│           │   ├── note_card.dart
│           │   └── note_dialog.dart
│           └── pages/
│               └── dashboard_page.dart (to update)
```

**Structure Decision**: The component belongs in the `dashboard` feature slice since it's placed directly below the `MetricCard` on the main dashboard. The data model goes in `domain/models/`, and the widgets in `presentation/widgets/`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations.
