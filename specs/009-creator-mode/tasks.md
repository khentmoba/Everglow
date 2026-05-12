# Tasks: Creator Mode Admin Panel

**Input**: Design documents from `/specs/009-creator-mode/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Initialize `CreatorModal` widget structure in `lib/features/dashboard/presentation/widgets/creator_modal.dart`
- [X] T002 [P] Create `CreatorService` skeleton in `lib/features/dashboard/data/services/creator_service.dart`
- [X] T003 Ensure `image_picker` and `firebase_storage` dependencies are present in `pubspec.yaml`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Configure Firebase Storage rules for `milestones/` directory in `storage.rules` (if not already configured)
- [X] T005 [P] Implement base upload logic in `lib/features/dashboard/data/services/creator_service.dart`
- [X] T006 [P] Implement base Firestore save logic for Milestones and Notes in `lib/features/dashboard/data/services/creator_service.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Secure Access to Creator Mode (Priority: P1) 🎯 MVP

**Goal**: Ensure only Khent can see and access the Creator Panel via a discrete dashboard button.

**Independent Test**: Log in as 'clair' (1111) and verify the button is hidden; log in as 'khent' (2222) and verify the button appears and opens the modal.

### Implementation for User Story 1

- [X] T007 [US1] Implement `currentUser == 'khent'` conditional check in `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- [X] T008 [US1] Add a discrete heart icon or FloatingActionButton to `lib/features/dashboard/presentation/screens/dashboard_screen.dart` for admins
- [X] T009 [US1] Implement `showModalBottomSheet` trigger with rounded top corners (32.0) and pink theme in `DashboardScreen`
- [X] T010 [US1] Create basic `CreatorModal` layout with "Add Memory" and "Drop a Letter" TabBar in `lib/features/dashboard/presentation/widgets/creator_modal.dart`

**Checkpoint**: User Story 1 functional - Admin access is secure and modal opens.

---

## Phase 4: User Story 2 - Adding a Relationship Memory (Priority: P2)

**Goal**: Allow Khent to add new timeline memories with titles, descriptions, and picked images.

**Independent Test**: Use the "Add Memory" form to save a new milestone and verify it appears in the Living Archive timeline.

### Implementation for User Story 2

- [X] T011 [P] [US2] Implement "Add Memory" form UI (Title, Description, Date) in `lib/features/dashboard/presentation/widgets/creator_modal.dart`
- [X] T012 [P] [US2] Integrate `image_picker` to allow selecting a photo in `lib/features/dashboard/presentation/widgets/creator_modal.dart`
- [X] T013 [US2] Implement `uploadMemoryImage` and `saveMilestone` orchestration in `lib/features/dashboard/data/services/creator_service.dart`
- [X] T014 [US2] Add loading indicator on the "Save" button and disable interactions during submission in `CreatorModal`
- [X] T015 [US2] Implement success SnackBar and automatic modal closure upon successful save

**Checkpoint**: User Story 2 functional - Memories can be added directly from the app.

---

## Phase 5: User Story 3 - Dropping a Secret Letter (Priority: P2)

**Goal**: Allow Khent to drop future-locked letters into the Letterbox.

**Independent Test**: Use the "Drop a Letter" form to save a note and verify it appears as a locked envelope in the Letterbox.

### Implementation for User Story 3

- [X] T016 [P] [US3] Implement "Drop a Letter" form UI (Title, Content, Unlock Date) in `lib/features/dashboard/presentation/widgets/creator_modal.dart`
- [X] T017 [P] [US3] Add `showDatePicker` logic for selecting the `unlockDate` in `CreatorModal`
- [X] T018 [US3] Implement `saveHiddenNote` method in `lib/features/dashboard/data/services/creator_service.dart`
- [X] T019 [US3] Integrate "Drop a Letter" submission with loading state and success feedback in `CreatorModal`

**Checkpoint**: User Story 3 functional - Letters can be dropped for future unlocking.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [X] T020 [P] Wrap all `CreatorModal` forms in `SingleChildScrollView` to ensure mobile keyboard accessibility
- [X] T021 Apply bouncy animations and soft pink aesthetic to all TabBar transitions and button interactions
- [X] T022 Final code cleanup, removal of debug prints, and validation against `quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Phase 1 completion.
- **User Stories (Phase 3+)**: All depend on Phase 2 completion.
- **Polish (Final Phase)**: Depends on all user stories being complete.

### Parallel Opportunities

- T002 and T003 can run in parallel.
- T005 and T006 can run in parallel.
- Once Phase 2 is complete, US2 and US3 implementation can theoretically start in parallel if UI skeletons exist.
- Form UI tasks (T011, T016) can be worked on in parallel.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Setup and Foundational phases.
2. Implement Story 1: Admin access and Modal structure.
3. **STOP and VALIDATE**: Verify the button is hidden for 'clair' and opens the modal for 'khent'.

### Incremental Delivery

1. Deploy Story 1 (The Gateway).
2. Deploy Story 2 (Memory Creator).
3. Deploy Story 3 (Letter Dropper).
