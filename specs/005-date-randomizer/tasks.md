# Tasks: Date Randomizer

**Input**: Design documents from `/specs/005-date-randomizer/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Create feature directory structure in `lib/features/date_randomizer/`
- [x] T002 [P] Create initial seed file in `assets/data/date_ideas_seed.json` with 1000+ ideas
- [x] T003 [P] Register assets directory in `pubspec.yaml`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core data layer and service infrastructure

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create `DateIdea` domain model in `lib/features/date_randomizer/data/models/date_idea.dart`
- [x] T005 [P] Implement `DateIdeaService` skeleton in `lib/features/date_randomizer/data/services/date_idea_service.dart`
- [x] T006 Implement JSON seeding logic in `DateIdeaService` using `WriteBatch`
- [x] T007 Implement Firestore fetch and random selection logic in `DateIdeaService`

**Checkpoint**: Foundation ready - data layer and seeding logic are functional.

---

## Phase 3: User Story 1 - Get a Random Date Idea (Priority: P1) 🎯 MVP

**Goal**: Allow users to spin a heart-shaped button and receive a random date idea in a celebratory dialog.

**Independent Test**: Press the heart button, observe 1.5s spin, and verify a date idea appears in a bouncy dialog with sparkles.

### Implementation for User Story 1

- [x] T008 [P] [US1] Create `CelebrationDialog` widget in `lib/features/date_randomizer/presentation/widgets/celebration_dialog.dart`
- [x] T009 [US1] Implement `RandomizerCard` with 1.5s fast-spinning heart animation in `lib/features/date_randomizer/presentation/widgets/randomizer_card.dart`
- [x] T010 [US1] Integrate `RandomizerCard` into the dashboard layout in `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- [x] T011 [US1] Implement result reveal logic connecting `RandomizerCard` to `DateIdeaService` and `CelebrationDialog`

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently.

---

## Phase 4: User Story 2 - Handling Empty Idea Collection (Priority: P2)

**Goal**: Inform the user gracefully if the date ideas collection is empty.

**Independent Test**: Clear Firestore `date_ideas` collection and verify a SnackBar appears after tapping the spin button.

### Implementation for User Story 2

- [x] T012 [US2] Implement empty list check in `DateIdeaService.getRandomIdea()`
- [x] T013 [US2] Update `RandomizerCard` to show the 'No date ideas yet!' SnackBar when an empty state is detected

**Checkpoint**: User Story 2 is functional and handles data absence gracefully.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Final refinements and verification

- [x] T014 [P] Refine "fast-spinning" rotation curves and speed in `RandomizerCard`
- [x] T015 [P] Adjust `ElasticOut` transition parameters for the `CelebrationDialog`
- [x] T016 [P] Add celebratory visual variety (circles/stars) to `CelebrationDialog`
- [x] T017 Final end-to-end verification of the 1000+ item performance
- [x] T018 Run `quickstart.md` validation steps

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 completion.
- **User Stories (Phase 3+)**: All depend on Phase 2 completion.
- **Polish (Final Phase)**: Depends on all user stories being complete.

### Parallel Opportunities

- T002 and T003 can run in parallel.
- T005 and T004 (partially) can run in parallel.
- Once Phase 2 is complete, US1 and US2 implementation can be started (though US2 is small).
- All Polish tasks (T014-T016) can run in parallel.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Setup and Foundational phases.
2. Complete User Story 1 (Phase 3).
3. **STOP and VALIDATE**: Verify the spin-to-reveal flow works with seeded data.

### Parallel Team Strategy

- Dev A: Data Layer (Phase 2)
- Dev B: UI Components (Phase 3: T008, T009)
- Dev C: Dashboard Integration (Phase 3: T010)
