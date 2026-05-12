# Tasks: Everglow Guardian

**Input**: Design documents from `/specs/006-everglow-guardian/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Tests**: Tests are NOT requested in the specification, so no test tasks are included.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- Paths follow the modular Flutter feature structure defined in `plan.md`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Create project structure for `lib/features/guardian/` per implementation plan
- [x] T002 Register `assets/data/guardian_messages_seed.json` in `pubspec.yaml`
- [x] T003 [P] Create the initial `assets/data/guardian_messages_seed.json` with sample sweet messages

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Implement `GuardianMessage` model in `lib/features/guardian/data/models/guardian_message.dart`
- [x] T005 [P] Implement `GuardianService` with Firestore interaction and seeding in `lib/features/guardian/data/services/guardian_service.dart`
- [x] T006 Initialize `GuardianService` in the dashboard initialization sequence

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Interactive Companion (Priority: P1) 🎯 MVP

**Goal**: Implement the core character visuals and tap interactions.

**Independent Test**: Character is visible at the bottom-right and performs a jump/spin when tapped.

### Implementation for User Story 1

- [x] T007 [P] [US1] Implement `CatVisuals` (pure Flutter widgets) in `lib/features/guardian/presentation/widgets/character/cat_visuals.dart`
- [x] T008 [P] [US1] Create `GuardianController` to manage animation states in `lib/features/guardian/presentation/controllers/guardian_controller.dart`
- [x] T009 [US1] Build `EverglowGuardian` widget with `GestureDetector` in `lib/features/guardian/presentation/widgets/everglow_guardian.dart`
- [x] T010 [US1] Implement reaction animations (Jump/Spin) and heart particle effects in `EverglowGuardian`
- [x] T011 [US1] Integrate `EverglowGuardian` as a viewport overlay in `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Cheerful Greeting (Priority: P1)

**Goal**: Guardian greets the user with a bounce and wave on entry.

**Independent Test**: Character performs the scale-up bounce and wave animation when the dashboard first loads.

### Implementation for User Story 2

- [x] T012 [US2] Implement "Welcome" greeting animation (bounce scale + wave) in `lib/features/guardian/presentation/widgets/everglow_guardian.dart`
- [x] T013 [US2] Trigger the greeting animation during the dashboard entry transition in `lib/features/guardian/presentation/controllers/guardian_controller.dart`

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Gentle Presence (Priority: P2)

**Goal**: Guardian performs a subtle idle animation loop.

**Independent Test**: Character gently floats or "breathes" up and down while the dashboard is open.

### Implementation for User Story 3

- [x] T014 [US3] Implement idle "Breathing/Floating" animation loop in `lib/features/guardian/presentation/widgets/everglow_guardian.dart`

**Checkpoint**: Guardian feels "alive" even when not interacting.

---

## Phase 6: User Story 4 - Spontaneous Messages (Priority: P2)

**Goal**: Guardian displays sweet messages in a thought bubble occasionally or on tap.

**Independent Test**: A thought bubble appears for 5 seconds every 3-7 minutes or immediately after tapping the character.

### Implementation for User Story 4

- [x] T015 [P] [US4] Implement `ThoughtBubble` widget in `lib/features/guardian/presentation/widgets/thought_bubble.dart`
- [x] T016 [US4] Implement message randomization logic and timer (3-7 mins) in `lib/features/guardian/presentation/controllers/guardian_controller.dart`
- [x] T017 [US4] Integrate `ThoughtBubble` into the `EverglowGuardian` layout and manage its visibility state

**Checkpoint**: All user stories should now be independently functional

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T018 Optimize animation performance for 60fps consistency on web
- [x] T019 [P] Add unit tests for `GuardianService` in `test/features/guardian/guardian_service_test.dart`
- [x] T020 Run `quickstart.md` validation to ensure everything works as expected

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories.
- **User Stories (Phase 3+)**: All depend on Foundational phase completion.
- **Polish (Final Phase)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: Core visuals and positioning. No dependencies on other stories.
- **User Story 2 (P2)**: Depends on US1 character structure for animations.
- **User Story 3 (P3)**: Depends on US1 character structure for idle state.
- **User Story 4 (P4)**: Depends on US1 for tap trigger and service for messages.

### Parallel Opportunities

- T003 (JSON seed) can be created in parallel with project structure T001.
- T005 (Service) can be developed in parallel with T004 (Model).
- T007 (Visuals) and T008 (Controller) can be developed in parallel.
- T015 (ThoughtBubble) can be developed in parallel with other US4 tasks.

---

## Parallel Example: User Story 1

```bash
# Launch character design and controller logic in parallel:
Task: "Implement CatVisuals (pure Flutter widgets) in lib/features/guardian/presentation/widgets/character/cat_visuals.dart"
Task: "Create GuardianController to manage animation states in lib/features/guardian/presentation/controllers/guardian_controller.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1 (Interactive Companion)
4. **STOP and VALIDATE**: Verify character appears and reacts to taps.

### Incremental Delivery

1. Foundation ready.
2. Add Interactive Companion -> MVP ready.
3. Add Cheerful Greeting -> Entrance experience improved.
4. Add Gentle Presence -> Character feels alive.
5. Add Spontaneous Messages -> Complete personality delivered.
