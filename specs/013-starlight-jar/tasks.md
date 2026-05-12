# Tasks: Starlight Jar

**Input**: Design documents from `/specs/013-starlight-jar/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Create feature directory structure in `lib/features/starlight_jar/`
- [x] T002 [P] Initialize boilerplate folders for models, services, and widgets in `lib/features/starlight_jar/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Implement `StarNote` model with fromFirestore/toMap in `lib/features/starlight_jar/domain/models/star_note.dart`
- [x] T004 Implement `StarlightService` with Firestore stream (limit 100) and `addStar` in `lib/features/starlight_jar/data/services/starlight_service.dart`
- [x] T005 [P] Setup `GlassJar` skeleton with BackdropFilter in `lib/features/starlight_jar/presentation/widgets/glass_jar.dart`
- [x] T006 [P] Setup `StarWidget` skeleton in `lib/features/starlight_jar/presentation/widgets/star_widget.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Dropping a Star (Priority: P1) 🎯 MVP

**Goal**: Allow users to write and drop a star into the jar with a falling animation.

**Independent Test**: Click "Drop a Star", enter text, submit, and see star fall into the jar.

### Implementation for User Story 1

- [x] T007 [P] [US1] Create `DropStarDialog` with text validation (disable submit if empty) in `lib/features/starlight_jar/presentation/widgets/drop_star_dialog.dart`
- [x] T008 [US1] Implement "Drop" animation logic in `lib/features/starlight_jar/presentation/widgets/star_widget.dart`
- [x] T009 [US1] Integrate `DropStarDialog` and `addStar` call in `lib/features/starlight_jar/presentation/screens/starlight_jar_widget.dart`
- [x] T010 [US1] Add "Drop a Star" floating button to `lib/features/starlight_jar/presentation/screens/starlight_jar_widget.dart`

**Checkpoint**: User Story 1 functional - stars can be added and animated into the jar.

---

## Phase 4: User Story 2 - Reading a Random Note (Priority: P2)

**Goal**: Tap the jar to trigger a shake animation and reveal a random note.

**Independent Test**: Tap jar, observe 1s shake, see star float out, read note, close dialog, star returns.

### Implementation for User Story 2

- [x] T011 [P] [US2] Implement "Shake" animation using `AnimationController` in `lib/features/starlight_jar/presentation/widgets/glass_jar.dart`
- [x] T012 [US2] Implement random note selection logic in `lib/features/starlight_jar/data/services/starlight_service.dart`
- [x] T013 [P] [US2] Create `NoteDisplayDialog` with "Close" button in `lib/features/starlight_jar/presentation/widgets/note_display_dialog.dart`
- [x] T014 [US2] Implement "Float Out" and "Return" animations for the selected star in `lib/features/starlight_jar/presentation/widgets/star_widget.dart`
- [x] T015 [US2] Wire up jar tap gesture to shake -> select -> float out -> display sequence in `lib/features/starlight_jar/presentation/screens/starlight_jar_widget.dart`

**Checkpoint**: User Story 2 functional - random notes can be retrieved via interaction.

---

## Phase 5: User Story 3 - Visual Piling & Persistence (Priority: P3)

**Goal**: Stars remain in a random "pile" at the bottom of the jar across sessions.

**Independent Test**: Add 5 stars, refresh app, verify they are all visible in a pile at the bottom.

### Implementation for User Story 3

- [x] T016 [US3] Implement piling coordinate logic (random distribution in bottom 20%) in `lib/features/starlight_jar/presentation/screens/starlight_jar_widget.dart`
- [x] T017 [US3] Connect `StarlightService` stream to `StarlightJarWidget` to render all existing stars.
- [x] T018 [US3] Ensure stars persist their random positions/rotations within the session to avoid "jumping" on rebuild.

**Checkpoint**: User Story 3 functional - jar remains populated with stored gratitude.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final refinements and integration into the main dashboard.

- [x] T019 [P] Refine glassmorphism frosty effect and border gradients in `lib/features/starlight_jar/presentation/widgets/glass_jar.dart`
- [x] T020 Integrate `StarlightJarWidget` as a centerpiece on the `DashboardScreen` (location: next to Daily Bloom).
- [x] T021 Perform final performance check with 100 stars (verify 60 FPS).
- [x] T022 Run quickstart.md validation steps.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 completion - BLOCKS all user stories.
- **User Stories (Phase 3+)**: All depend on Phase 2 completion.
- **Polish (Final Phase)**: Depends on all user stories being complete.

### Parallel Opportunities

- T002 can run in parallel with T001.
- T005, T006 can run in parallel with T003, T004.
- T007 [US1] and T013 [US2] can be developed in parallel as they are independent UI components.
- T011 [US2] and T008 [US1] can be developed in parallel.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 & 2.
2. Complete Phase 3 (User Story 1).
3. **VALIDATE**: Verify that a user can drop a star and it saves to Firestore.
4. If satisfied, proceed to Story 2.

### Incremental Delivery

1. Setup + Foundation -> Infrastructure ready.
2. Add US1 -> "Add" capability ready.
3. Add US2 -> "Read" capability ready.
4. Add US3 -> "Persistence/Visual" capability ready.
5. Polish -> Final aesthetic refinement.
