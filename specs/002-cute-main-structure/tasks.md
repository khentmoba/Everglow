---
description: "Task list for Cute Main Structure implementation"
---

# Tasks: Cute Main Structure

**Input**: Design documents from `specs/002-cute-main-structure/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and global styling structure

- [x] T001 Add `age_calculator` and required fonts (Quicksand/Bubblegum Sans) to `pubspec.yaml`
- [x] T002 Implement `AppTheme` globally in `lib/core/theme/app_theme.dart` (soft pink palette, CardTheme & ButtonTheme with 32px borderRadius)
- [x] T003 Apply `AppTheme` to the root `MaterialApp` in `lib/main.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create empty `DashboardScreen` scaffold in `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- [x] T005 Route the existing passcode success logic in `lib/features/entry/presentation/widgets/passcode_input.dart` to navigate to the new dashboard screen

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Enter Gateway & Blooming Transition (Priority: P1) 🎯 MVP

**Goal**: Experience a seamless, full-screen "blooming" visual transition into the main application so that the entry feels magical and cute.

**Independent Test**: Can be fully tested by entering '1111' in the gateway and observing the visual scaling and fading animation leading to the dashboard.

### Implementation for User Story 1

- [x] T006 [US1] Create `BloomingPageRoute` using `PageRouteBuilder` with `ScaleTransition` and `FadeTransition` in `lib/features/entry/presentation/transitions/blooming_page_route.dart`
- [x] T007 [US1] Update `passcode_input.dart` to use `BloomingPageRoute` instead of default routing

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Real-Time Anniversary Counter (Priority: P1)

**Goal**: See a real-time counter displaying the exact time we've been together (Years, Months, Days, Hours, Minutes, Seconds) ticking precisely down to the second.

**Independent Test**: Can be fully tested by viewing the dashboard and verifying that the counter increments every second and accurately calculates time from Feb 14, 2026.

### Implementation for User Story 2

- [x] T008 [P] [US2] Implement `AnniversaryCounter` value object with precise time calculation in `lib/features/dashboard/domain/models/anniversary_counter.dart`
- [x] T009 [P] [US2] Create `MetricCard` widget with soft pink background and `AnimatedSwitcher` for seconds in `lib/features/dashboard/presentation/widgets/metric_card.dart`
- [x] T010 [US2] Integrate `MetricCard` with a 1-second ticking Stream/Timer in `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Organic Main Dashboard Experience (Priority: P2)

**Goal**: A main dashboard that feels organic, soft, and playful with non-rigid layouts and an interactive cute primary action button.

**Independent Test**: Can be fully tested by navigating the dashboard and interacting with the primary action button to see the micro-animation.

### Implementation for User Story 3

- [x] T011 [P] [US3] Update `DashboardScreen` layout to an organic spaced-out list (e.g., staggered layout without rigid grids) in `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- [x] T012 [P] [US3] Add a heart-shaped `FloatingActionButton` that triggers a playful micro-animation (e.g., confetti burst or scale) on tap in `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

**Checkpoint**: All user stories should now be independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T013 Ensure all borders across new widgets strictly enforce the 32px minimum radius 
- [x] T014 Verify Back Navigation behavior: Dashboard correctly acts as the root route and system back button exits the app rather than returning to the lock screen

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2)
- **User Story 2 (P1)**: Can start after Foundational (Phase 2)
- **User Story 3 (P2)**: Can start after Foundational (Phase 2)

### Parallel Opportunities

- Foundational updates and Domain Model (`AnniversaryCounter`) [P] can be developed independently
- `MetricCard` UI widget [P] can be implemented in parallel with Domain logic
- Dashboard Layout and FAB micro-animations [P] can be parallelized

---

## Parallel Example: User Story 2

```bash
# Launch Domain model and UI widgets together:
Task: "Implement AnniversaryCounter value object with precise time calculation in lib/features/dashboard/domain/models/anniversary_counter.dart"
Task: "Create MetricCard widget with soft pink background and AnimatedSwitcher for seconds in lib/features/dashboard/presentation/widgets/metric_card.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 & 2)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Blooming Gateway)
4. Complete Phase 4: User Story 2 (Real-Time Counter)
5. **STOP and VALIDATE**: Test Gateway and Counter independently
6. Deploy/demo MVP

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Ready
3. Add User Story 2 → Test independently → Ready
4. Add User Story 3 → Test independently → Ready
5. Each story adds value without breaking previous stories
