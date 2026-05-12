---
description: "Task list for cute-entry-gateway implementation"
---

# Tasks: cute-entry-gateway

**Input**: Design documents from `/specs/001-cute-entry-gateway/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Tests**: Tests are excluded as they were not explicitly requested in the feature specification.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 [P] Configure custom pinkish app theme in lib/core/theme/app_theme.dart

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T002 Create gateway state management (e.g., GatewayState enum and notifier) in lib/features/entry/presentation/state/gateway_state.dart

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Playful Entry Load (Priority: P1) 🎯 MVP

**Goal**: Present an overwhelmingly cute, pinkish environment where the primary entry element (lock/door) playfully animates into view on initial load.

**Independent Test**: Can be tested by loading the Gateway Page and verifying the initial pink aesthetic and the entry element's bounce/pop entrance animation.

### Implementation for User Story 1

- [x] T003 [P] [US1] Create animated lock widget structure in lib/features/entry/presentation/widgets/animated_lock.dart
- [x] T004 [US1] Implement bounce/pop entrance animation in lib/features/entry/presentation/widgets/animated_lock.dart
- [x] T005 [P] [US1] Create the main gateway page layout in lib/features/entry/presentation/pages/gateway_page.dart
- [x] T006 [US1] Integrate animated lock into gateway page for initial load state in lib/features/entry/presentation/pages/gateway_page.dart

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Passcode Authentication (Priority: P1)

**Goal**: Allow users to enter a passcode; trigger a cute shake/clear on error, or a celebratory unlock animation when '1111' is entered.

**Independent Test**: Can be tested by interacting with the passcode input, entering incorrect codes (should shake), and the correct code (should pop open).

### Implementation for User Story 2

- [x] T007 [P] [US2] Create playful passcode input widget in lib/features/entry/presentation/widgets/passcode_input.dart
- [x] T008 [US2] Implement passcode validation against '1111' in lib/features/entry/presentation/state/gateway_state.dart
- [x] T009 [US2] Implement error shake animation and input clearing for incorrect passcode in lib/features/entry/presentation/widgets/passcode_input.dart
- [x] T010 [US2] Implement lock popping open / swinging wide animation for successful passcode in lib/features/entry/presentation/widgets/animated_lock.dart
- [x] T011 [US2] Integrate passcode input and unlock state transitions into lib/features/entry/presentation/pages/gateway_page.dart

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Main Site Reveal Transition (Priority: P2)

**Goal**: Smoothly transition from the unlocked state to revealing the main site content dynamically without abrupt cuts (blooming or petal shower).

**Independent Test**: Can be tested by entering the correct passcode and observing the smooth petal shower/blooming transition.

### Implementation for User Story 3

- [x] T012 [P] [US3] Create petal shower / blooming animation widget in lib/features/entry/presentation/widgets/petal_shower.dart
- [x] T013 [US3] Implement smooth transition logic from unlocking to revealing site in lib/features/entry/presentation/state/gateway_state.dart
- [x] T014 [US3] Integrate the reveal transition effect into the main flow in lib/features/entry/presentation/pages/gateway_page.dart

**Checkpoint**: All user stories should now be independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T015 Code cleanup and ensuring absolute aesthetic compliance across all widgets in lib/features/entry/presentation/
- [x] T016 Run quickstart.md validation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2)
- **User Story 2 (P1)**: Integrates with US1's lock widget.
- **User Story 3 (P2)**: Integrates with US2's unlock state.

### Parallel Opportunities

- T003 and T005 can be worked on concurrently.
- T007 and T012 can be developed concurrently as isolated widgets.

---

## Parallel Example: User Story 1

```bash
# Launch layout and isolated widget structures concurrently
Task: "Create animated lock widget structure in lib/features/entry/presentation/widgets/animated_lock.dart"
Task: "Create the main gateway page layout in lib/features/entry/presentation/pages/gateway_page.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Verify the initial aesthetic and load animation.

### Incremental Delivery

1. Deliver Setup + Foundational.
2. Deliver US1 (Visual load).
3. Deliver US2 (Passcode Interaction & Validation).
4. Deliver US3 (Transitions).
