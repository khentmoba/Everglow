# Tasks: Heartbeat Sync

**Input**: Design documents from `/specs/014-heartbeat-sync/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Tests**: Tests are NOT requested in the specification, so we will focus on implementation and manual verification as defined in the spec.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- All paths are relative to the repository root.
- Feature logic lives in `lib/features/heartbeat/`.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Create project structure at lib/features/heartbeat/
- [x] T002 [P] Configure Firestore collection "moods" and required indexes in Firebase Console (noted in quickstart.md)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Create UserMood model in lib/features/heartbeat/data/models/user_mood.dart
- [x] T004 [P] Implement MoodService for Firestore interactions in lib/features/heartbeat/data/services/mood_service.dart
- [x] T005 [P] Register MoodService in the global dependency injection/provider setup (main.dart)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Daily Mood Check-In (Priority: P1) 🎯 MVP

**Goal**: Allow users to submit their daily mood through the Everglow Guardian or a manual button.

**Independent Test**: Log in as a user who hasn't checked in today; Guardian should prompt for mood. Selection should persist to Firestore.

### Implementation for User Story 1

- [x] T006 [P] [US1] Create MoodController for UI state management in lib/features/heartbeat/presentation/controllers/mood_controller.dart
- [x] T007 [P] [US1] Design HeartEmoji widget with bouncy animations in lib/features/heartbeat/presentation/widgets/heart_emoji.dart
- [x] T008 [US1] Implement MoodPicker widget with 5 heart options in lib/features/heartbeat/presentation/widgets/mood_picker.dart
- [x] T009 [US1] Add triggerMoodCheckIn method to GuardianController in lib/features/guardian/presentation/controllers/guardian_controller.dart
- [x] T010 [US1] Integrate MoodPicker into the EverglowGuardian overlay in lib/features/guardian/presentation/widgets/everglow_guardian.dart
- [x] T011 [US1] Add logic to check for daily mood on app entry and trigger Guardian prompt if missing

**Checkpoint**: User Story 1 is functional. Users can submit moods and they are persisted correctly.

---

## Phase 4: User Story 2 - Partner Mood Visibility (Priority: P1)

**Goal**: Display the partner's most recent mood on the dashboard in real-time.

**Independent Test**: Submit a mood as one user; verify the partner's dashboard updates with the correct color/pulsing indicator.

### Implementation for User Story 2

- [x] T012 [P] [US2] Create PartnerStatusIndicator widget in lib/features/heartbeat/presentation/widgets/partner_status_indicator.dart
- [x] T013 [US2] Implement real-time listener for partner mood in lib/features/heartbeat/data/services/mood_service.dart
- [x] T014 [US2] Add PartnerStatusIndicator to the DashboardAppBar or DashboardScreen in lib/features/dashboard/presentation/screens/dashboard_screen.dart

**Checkpoint**: User Story 2 is functional. Partners can see each other's current emotional state.

---

## Phase 5: User Story 3 - Guardian Mood Awareness (Priority: P2)

**Goal**: The Guardian occasionally mentions the partner's mood in its thought bubbles.

**Independent Test**: Observe the Guardian's messages; verify that partner mood messages appear occasionally (approx. 1 in 5-10 messages).

### Implementation for User Story 3

- [x] T015 [US3] Add "mood_awareness" category support to GuardianService in lib/features/guardian/data/services/guardian_service.dart
- [x] T016 [US3] Update GuardianController to fetch and display partner mood messages in lib/features/guardian/presentation/controllers/guardian_controller.dart

**Checkpoint**: All user stories are functional. The Guardian is now aware of the sync.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T017 [P] Implement manual "Check-in" button on the dashboard in lib/features/dashboard/presentation/widgets/dashboard_actions.dart
- [x] T018 Ensure offline caching is working as expected (FR-007)
- [x] T019 Run final validation against quickstart.md and spec.md success criteria

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Can start immediately.
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all stories.
- **User Stories (Phase 3-5)**: Depend on Foundational completion. US1 and US2 can proceed in parallel. US3 depends on US2 (needs partner data).
- **Polish (Final Phase)**: Depends on all user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: Independent.
- **User Story 2 (P1)**: Independent (needs Foundational).
- **User Story 3 (P2)**: Depends on User Story 2 (data stream) and User Story 1 (message content context).

### Parallel Opportunities

- T001, T002 can run in parallel.
- T004, T005 can run in parallel.
- T006, T007 can run in parallel.
- US1 and US2 implementation can mostly run in parallel.

---

## Parallel Example: User Story 1

```bash
# Launch UI components for User Story 1 together:
Task: "Create MoodController for UI state management in lib/features/heartbeat/presentation/controllers/mood_controller.dart"
Task: "Design HeartEmoji widget with bouncy animations in lib/features/heartbeat/presentation/widgets/heart_emoji.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 & 2)

1. Complete Setup + Foundational.
2. Complete User Story 1 (Check-in).
3. Complete User Story 2 (Visibility).
4. **STOP and VALIDATE**: Real-time sync works between two users.

### Incremental Delivery

1. Foundation ready.
2. Add Check-in -> Test.
3. Add Visibility -> Test real-time sync.
4. Add Guardian Awareness -> Test personality integration.
5. Final Polish.
