# Tasks: Relationship Scrapbook Timeline

**Input**: Design documents from `/specs/main/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md

**Tests**: Tests are NOT requested for this visual implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create project structure per implementation plan
- [ ] T002 Initialize Vite project and install `firebase`, `framer-motion`, `lucide-react`
- [ ] T003 [P] Configure global styles and "Modern Nostalgia" theme (colors/fonts) in `src/index.css`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Firebase integration and base UI components

- [ ] T004 Implement Firebase configuration and service exports in `src/firebase/config.js`
- [ ] T005 [P] Create base `Polaroid` component wrapper in `src/components/ui/Polaroid.jsx`

**Checkpoint**: Infrastructure ready - Firebase services and base styling are operational.

---

## Phase 3: User Story 1 & 5 - Auth and View Timeline (Priority: P1) 🎯 MVP

**Goal**: Authenticate users and display a list of relationship memories.

**Independent Test**: Log in with credentials and see a list of pre-seeded memories from Firestore.

### Implementation for User Story 1 & 5

- [ ] T006 [US1] Create minimalist Login screen in `src/components/auth/Login.jsx`
- [ ] T007 [US1] Implement `useMemories` hook for real-time memory fetching in `src/hooks/useMemories.js`
- [ ] T008 [US1] Create vertical timeline container in `src/components/scrapbook/Timeline.jsx`
- [ ] T009 [US1] Implement basic polaroid card rendering in `src/components/scrapbook/TimelineCard.jsx`
- [ ] T010 [US1] Connect Auth guard and main layout in `src/App.jsx`

**Checkpoint**: MVP complete - Users can log in and view their timeline.

---

## Phase 4: User Story 6 & 7 - Full CRUD and Image Uploads (Priority: P2)

**Goal**: Allow users to manage their memories and upload high-fidelity photos.

**Independent Test**: Add a new memory with an image and see it appear in the timeline. Edit or delete to verify sync.

### Implementation for User Story 6 & 7

- [ ] T011 [P] [US6] Add CRUD operations (add/update/delete) to `src/hooks/useMemories.js`
- [ ] T012 [US6] Create memory creation/editing form in `src/components/scrapbook/MemoryForm.jsx`
- [ ] T013 [US7] Implement Firebase Storage upload logic for images in `src/components/scrapbook/MemoryForm.jsx`
- [ ] T014 [US6] Add "Edit/Delete" interaction buttons to `src/components/scrapbook/TimelineCard.jsx`

---

## Phase 5: User Story 2 & 3 - Interaction and Filtering (Priority: P2)

**Goal**: Support long stories and easy navigation via grouping and filtering.

**Independent Test**: Expand a "See More" section and filter memories by a specific year or category.

### Implementation for User Story 2 & 3

- [ ] T015 [P] [US2] Implement expandable "See More" toggle for descriptions in `src/components/scrapbook/TimelineCard.jsx`
- [ ] T016 [P] [US3] Create filter chips for Year and Category in `src/components/scrapbook/FilterBar.jsx`
- [ ] T017 [US3] Update `src/components/scrapbook/Timeline.jsx` to render prominent Year Headers and group cards.

---

## Phase 6: User Story 4 - Visual Polish (Priority: P3)

**Goal**: Smooth animations for the "Modern Nostalgia" premium experience.

**Independent Test**: Scroll down the timeline and watch polaroids fade in; items should shift smoothly during CRUD.

### Implementation for User Story 4

- [ ] T018 [P] [US4] Add Framer Motion `whileInView` fade-in effects to `src/components/scrapbook/TimelineCard.jsx`
- [ ] T019 [US4] Implement `LayoutGroup` transitions for smooth list reordering in `src/components/scrapbook/Timeline.jsx`

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Refinement and production readiness

- [ ] T020 Optimize image loading with blur-up or skeletons
- [ ] T021 Final CSS refinement for mobile responsive edge cases in `src/index.css`
- [ ] T022 [P] Clean up Firebase configuration for production usage

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup & Foundational**: MUST complete Phase 1 and 2 first.
- **US1 (MVP)**: Primary target after foundation.
- **US6/7 (CRUD)**: Can start after the basic timeline is visible.
- **US2/3 & US4**: Interaction and Polish can run in parallel with or after CRUD.

### Parallel Opportunities

- T003 (CSS), T005 (Polaroid UI), and T011 (CRUD Logic) can be worked on independently.
- Once the foundation is solid, logic (`useMemories`) and UI (`TimelineCard`) can be developed simultaneously.

---

## Implementation Strategy

### MVP First
1. Setup structure and Firebase.
2. Build Login + View Timeline (Static data first).
3. Connect to Firestore.

### Leveling Up
1. Add Uploads and CRUD.
2. Add Grouping and Filters.
3. Finish with high-fidelity animations.
