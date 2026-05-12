# Tasks: Everglow Canvas

**Input**: Design documents from `/specs/012-everglow-canvas/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Create project structure for `lib/features/canvas/` (data, domain, presentation subfolders)
- [x] T002 [P] Initialize boilerplate folders for models, services, screens, and widgets

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

- [x] T003 Implement `DoodleStroke` model with fromFirestore/toMap in `lib/features/canvas/domain/models/doodle_stroke.dart`
- [x] T004 Implement `CanvasService` with Firestore stream and save functions in `lib/features/canvas/data/services/canvas_service.dart`
- [x] T005 [P] Setup `CanvasPainter` skeleton in `lib/features/canvas/presentation/widgets/canvas_painter.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Real-Time Collaborative Drawing (Priority: P1) 🎯 MVP

**Goal**: Users can draw freehand on a shared canvas and see each other's doodles in real-time.

**Independent Test**: Open two browser instances; draw in one and verify the stroke appears in the other automatically.

### Implementation for User Story 1

- [x] T006 [US1] Implement `CanvasPainter` logic for rendering normalized points in `lib/features/canvas/presentation/widgets/canvas_painter.dart`
- [x] T007 [US1] Create `CanvasScreen` with `GestureDetector` to capture pan events in `lib/features/canvas/presentation/screens/canvas_screen.dart`
- [x] T008 [US1] Implement active stroke state and normalization logic in `CanvasScreen`
- [x] T009 [US1] Integrate `CanvasService` stream into `CanvasScreen` to display remote strokes
- [x] T010 [US1] Implement persistence trigger on `onPanEnd` in `CanvasScreen` using `CanvasService`
- [x] T011 [US1] Add navigation button to `lib/features/dashboard/presentation/screens/dashboard_screen.dart` with brush icon

**Checkpoint**: User Story 1 is functional and testable independently (MVP).

---

## Phase 4: User Story 2 - Cute Creative Toolbar (Priority: P2)

**Goal**: Users can choose pastel colors and switch between Pen and Eraser tools.

**Independent Test**: Toggle between Pen and Eraser; change colors and verify drawing behavior updates.

### Implementation for User Story 2

- [x] T012 [P] [US2] Create pill-shaped `CanvasToolbar` with glassmorphism in `lib/features/canvas/presentation/widgets/canvas_toolbar.dart`
- [x] T013 [US2] Implement tool selection state (Pen/Eraser) and color palette in `CanvasToolbar`
- [x] T014 [US2] Integrate `CanvasToolbar` into `CanvasScreen` and pass state to the painter
- [x] T015 [US2] Implement hit detection for Eraser in `lib/features/canvas/data/services/canvas_service.dart` (Option A: Permanent Removal)

**Checkpoint**: User Story 2 is functional and integrated.

---

## Phase 5: User Story 3 - Canvas Reset (Priority: P3)

**Goal**: Users can clear the entire canvas for all participants after confirmation.

**Independent Test**: Click 'Clear Canvas', confirm, and verify the canvas is wiped for all connected users.

### Implementation for User Story 3

- [x] T016 [US3] Add 'Clear Canvas' button to `CanvasToolbar`
- [x] T017 [US3] Implement confirmation `AlertDialog` in `CanvasScreen`
- [x] T018 [US3] Implement `clearAllStrokes` using `WriteBatch` in `lib/features/canvas/data/services/canvas_service.dart`

**Checkpoint**: All user stories are now independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements and advanced optimizations.

- [x] T019 [P] Implement distance-based point filtering in `CanvasScreen`
- [x] T020 [P] Implement path simplification (RDP algorithm) in `lib/features/canvas/data/services/canvas_service.dart`
- [x] T021 [P] Implement local Undo/Redo state in `CanvasScreen`
- [x] T022 Refine glassmorphism shadow (high border radius 32.0) and transitions

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup. BLOCKS all user stories.
- **User Stories (Phase 3+)**: Depend on Foundational completion.
- **Polish (Final Phase)**: Depends on all user stories.

### Parallel Opportunities

- T001 and T002 can be done together.
- T005 [P] can be started during Foundation phase.
- T012 [P] can be implemented in parallel with Story 1 work if UI/UX is separated.
- T019-T021 can be done in parallel during Polish.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Setup + Foundational.
2. Implement US1 (T006-T011).
3. **STOP and VALIDATE**: Test real-time sync in two windows.
4. If successful, proceed to US2.
