# Implementation Plan: Heartbeat Sync

**Branch**: `014-heartbeat-sync` | **Date**: 2026-05-11 | **Spec**: [spec.md](file:///c:/APPLICATIONS/Everglow/specs/014-heartbeat-sync/spec.md)

## Summary

The **Heartbeat Sync** feature establishes a daily emotional check-in ritual for Khent and Clair. It utilizes a Firestore-backed real-time sync system to display each other's "Current Status" on the dashboard. The feature is integrated with the Everglow Guardian, which prompts users for their mood upon daily login and occasionally shares the partner's status through thought bubbles.

## Technical Context

**Language/Version**: Flutter (Stable)  
**Primary Dependencies**: `cloud_firestore`, `provider`, `simple_animations` (or native Flutter animations)  
**Storage**: Firebase Firestore (`moods` collection)  
**Testing**: `flutter_test`  
**Target Platform**: Flutter Web (Mobile-first)
**Project Type**: Web Application  
**Performance Goals**: <10s check-in flow, <5s cross-user sync  
**Constraints**: Offline-capable via Firestore persistence, pink/cute aesthetic consistency  
**Scale/Scope**: 2 dedicated users, high frequency daily interaction

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Privacy-First**: PASS. Mood data is shared only within the authenticated pair.
- **II. Aesthetics**: PASS. Custom heart emojis with glow/bounce animations will be used.
- **III. Real-Time**: PASS. Firestore snapshots will drive the dashboard sync.
- **IV. Scalability**: PASS. Firestore naturally handles the light data load of daily moods.
- **V. Evolving**: PASS. The system can be extended later for history/trends.

## Project Structure

### Documentation (this feature)

```text
specs/014-heartbeat-sync/
├── plan.md              # This file
├── research.md          # Research findings
├── data-model.md        # Data entities
└── quickstart.md        # Feature setup guide
```

### Source Code (repository root)

```text
lib/
├── features/
│   ├── heartbeat/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── user_mood.dart
│   │   │   └── services/
│   │   │       └── mood_service.dart
│   │   ├── presentation/
│   │   │   ├── controllers/
│   │   │   │   └── mood_controller.dart
│   │   │   └── widgets/
│   │   │       ├── mood_picker.dart
│   │   │       ├── heart_emoji.dart
│   │   │       └── partner_status_indicator.dart
```

**Structure Decision**: Standard feature-first structure used in Everglow.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
