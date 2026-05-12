# Tasks: Everglow Academy

**Input**: Design documents from `/specs/015-everglow-academy/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Create project structure in lib/features/academy/ per implementation plan
- [x] T002 [P] Configure confetti and other dependencies in pubspec.yaml

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

- [x] T003 [P] Create AcademyQuestion model in lib/features/academy/models/academy_question.dart
- [x] T004 [P] Create GameMatch model in lib/features/academy/models/game_match.dart
- [x] T005 Create base AcademyService with Firestore collection references in lib/features/academy/services/academy_service.dart
- [x] T006 [P] Implement question seeding helper in lib/features/academy/services/academy_service.dart
- [x] T007 Implement Study Points update logic in lib/features/academy/services/academy_service.dart

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Entering the Academy (Priority: P1) 🎯 MVP

**Goal**: Provide a prominent entrance to the Academy from the dashboard with smooth transitions.

**Independent Test**: Navigate to the dashboard, find the Academy card, and tap it to reach the Hub.

### Implementation for User Story 1

- [x] T008 [P] [US1] Implement AcademyPortalCard widget in lib/features/academy/widgets/academy_portal_card.dart
- [x] T009 [US1] Integrate AcademyPortalCard into the DashboardScreen in lib/features/dashboard/presentation/screens/dashboard_screen.dart
- [x] T010 [P] [US1] Create AcademyHubScreen placeholder in lib/features/academy/screens/academy_hub_screen.dart
- [x] T011 [US1] Implement custom PageRouteBuilder for fade/slide transition in lib/features/academy/screens/academy_hub_screen.dart

**Checkpoint**: User Story 1 functional - entrance and hub navigation working.

---

## Phase 4: User Story 3 - 1v1 Challenge (Priority: P1)

**Goal**: Implement real-time 1v1 matchmaking and synchronized game board.

**Independent Test**: Connect two users (Khent & Clair) to a match and verify score/question sync.

### Implementation for User Story 3

- [x] T012 [US3] Implement 1v1 matchmaking logic (find/create match) in lib/features/academy/services/academy_service.dart
- [x] T013 [P] [US3] Create GameBoardScreen with Firestore StreamBuilder in lib/features/academy/screens/game_board_screen.dart
- [x] T014 [P] [US3] Implement ScoreTracker widget in lib/features/academy/widgets/score_tracker.dart
- [x] T015 [US3] Implement "Fastest Finger" transactional answer submission in lib/features/academy/services/academy_service.dart
- [x] T016 [US3] Implement 2-second incorrect answer lockout logic in lib/features/academy/screens/game_board_screen.dart
- [x] T017 [US3] Implement matchmaking timeout (60s) with "Play Solo" prompt in lib/features/academy/screens/academy_hub_screen.dart

**Checkpoint**: User Story 3 functional - real-time 1v1 competition working.

---

## Phase 5: User Story 2 - Solo Study Mode (Priority: P2)

**Goal**: Provide a local game loop for individual practice and Study Points.

**Independent Test**: Start Solo mode, choose a category, and complete 10 questions.

### Implementation for User Story 2

- [x] T018 [P] [US2] Create SoloStudyScreen with local game state in lib/features/academy/screens/solo_study_screen.dart
- [x] T019 [US2] Implement category selection dialog/overlay in lib/features/academy/screens/academy_hub_screen.dart
- [x] T020 [US2] Implement random question fetching (filtered by category) in lib/features/academy/services/academy_service.dart
- [x] T021 [US2] Implement final score submission and Study Points update in lib/features/academy/screens/solo_study_screen.dart

**Checkpoint**: User Story 2 functional - individual practice loop working.

---

## Phase 6: User Story 4 - Victory Celebration (Priority: P3)

**Goal**: Celebrate match completion with a podium and rewards.

**Independent Test**: Complete a match and verify winner declaration and confetti.

### Implementation for User Story 4

- [x] T022 [P] [US4] Create PodiumScreen with winner/draw declaration in lib/features/academy/screens/podium_screen.dart
- [x] T023 [US4] Integrate confetti animations into PodiumScreen using the confetti package
- [x] T024 [US4] Implement 1v1 bonus Study Points awarding logic (50 for win, 25 for draw) in lib/features/academy/services/academy_service.dart

**Checkpoint**: User Story 4 functional - match conclusions are rewarding and festive.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T025 [P] Implement stale match auto-cleanup (30 min) in lib/features/academy/services/academy_service.dart
- [x] T026 Add bubbly animations to answer buttons in lib/features/academy/widgets/answer_button.dart
- [x] T027 [P] Perform final UI/UX audit against the "Digital Sanctuary" pink theme
- [x] T028 [P] Verify all success criteria in spec.md are met

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Can start immediately.
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories.
- **User Stories (Phase 3-6)**: All depend on Foundational phase.
- **Polish (Final Phase)**: Depends on all user stories being complete.

### Parallel Opportunities

- T003 and T004 (Models) can be done in parallel.
- US1 and US3 can be worked on in parallel once Foundation is ready.
- US2 can be worked on in parallel with US1/US3.

---

## Parallel Example: User Story 3

```bash
# Models and Widgets can start together:
Task: "Create GameBoardScreen with Firestore StreamBuilder in lib/features/academy/screens/game_board_screen.dart"
Task: "Implement ScoreTracker widget in lib/features/academy/widgets/score_tracker.dart"
```

---

## Implementation Strategy

### MVP First (US1 & US3)

1. Complete Phase 1 & 2 (Setup & Foundation).
2. Complete Phase 3 (US1 - Entrance).
3. Complete Phase 4 (US3 - 1v1 Heart).
4. **STOP and VALIDATE**: Verify the core competitive experience.

### Incremental Delivery

1. Foundation ready.
2. Add US1 (Dashboard entrance).
3. Add US3 (1v1 Matchmaking).
4. Add US2 (Solo Mode).
5. Add US4 (Celebration).
