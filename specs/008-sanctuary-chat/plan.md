# Implementation Plan: SanctuaryChat (Real-time Messaging)

**Branch**: `008-sanctuary-chat` | **Date**: 2026-05-11 | **Spec**: [spec.md](file:///c:/APPLICATIONS/Everglow/specs/008-sanctuary-chat/spec.md)
**Input**: Feature specification for real-time messaging and personalized gateway entry.

## Summary
Implement a real-time chat feature using Firebase Firestore, featuring custom-styled bubbles and a personalized entry gateway that differentiates users by passcode.

## Technical Context

**Language/Version**: Dart (Flutter SDK ^3.11.3)  
**Primary Dependencies**: `provider`, `cloud_firestore`, `animate_do`  
**Storage**: Firestore (`messages` collection)  
**Testing**: `flutter test`  
**Target Platform**: Flutter Web
**Project Type**: Flutter Web Application
**Performance Goals**: < 2s message latency, 60fps animations
**Constraints**: Mobile-first design (max 500px width), strict pink/cute aesthetic
**Scale/Scope**: 2 private users, real-time sync

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Privacy-First**: ✅ Passcode-gated access ('1111'/'2222').
- **High-Fidelity**: ✅ Pulsing heart loader, custom bubbles with tails, animate_do.
- **Real-Time**: ✅ Firestore Stream for messaging.
- **Scalable Archival**: ✅ Persistent Firestore collection.
- **Evolving Core**: ✅ Modular feature structure.

## Project Structure

### Documentation (this feature)

```text
specs/008-sanctuary-chat/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
└── quickstart.md        # Phase 1 output
```

### Source Code (repository root)

```text
lib/
├── features/
│   ├── auth/
│   │   └── presentation/
│   │       └── providers/
│   │           └── auth_provider.dart  # Updates to handle currentUser
│   ├── chat/
│   │   ├── domain/
│   │   │   └── models/
│   │   │       └── chat_message.dart
│   │   ├── data/
│   │   │   └── services/
│   │   │       └── chat_service.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── sanctuary_chat_screen.dart
│   │       └── widgets/
│   │           └── chat_bubble.dart
│   ├── entry/
│   │   └── presentation/
│   │       └── state/
│   │           └── gateway_state.dart  # Validation update
│   └── dashboard/
│       └── presentation/
│           └── screens/
│               └── dashboard_screen.dart # FAB addition
```

**Structure Decision**: Follows the existing feature-first modular structure.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | | |

## Verification Plan

### Automated Tests
- `flutter test tests/features/chat/chat_service_test.dart`
- `flutter test tests/features/chat/chat_message_model_test.dart`

### Manual Verification
1. Open two browser windows.
2. Login as 'Clair' (1111) in one, 'Khent' (2222) in other.
3. Send messages and verify real-time appearance and alignment.
4. Verify auto-scroll and pulsing loader.
