# Tasks: TMDB Cinema Integration

**Input**: Design documents from `/specs/011-tmdb-cinema-integration/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/service_contract.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Add `http: ^1.2.1` dependency to `pubspec.yaml`
- [x] T002 [P] Create API keys constant in `lib/core/constants/api_keys.dart`
- [x] T003 Create directory structure `lib/features/cinema/` with data and presentation subdirectories

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 [P] Implement `MediaItem` model with fromFirestore/toFirestore in `lib/features/cinema/data/models/media_item.dart`
- [x] T005 Create `TMDBService` skeleton with `http` client in `lib/features/cinema/data/services/tmdb_service.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Search & Find Media (Priority: P1) 🎯 MVP

**Goal**: Enable Khent to search for movies/TV shows via TMDB and see live results.

**Independent Test**: Open the search modal, type a query, and verify that a grid of posters appears after a short delay.

### Implementation for User Story 1

- [x] T006 [US1] Implement `searchMedia` logic with TMDB API call in `lib/features/cinema/data/services/tmdb_service.dart`
- [x] T007 [P] [US1] Create `TMDBSearchModal` base widget in `lib/features/cinema/presentation/widgets/tmdb_search_modal.dart`
- [x] T008 [US1] Implement rounded search `TextField` with `Timer` debounce in `lib/features/cinema/presentation/widgets/tmdb_search_modal.dart`
- [x] T009 [US1] Build `GridView.builder` to display search results in `lib/features/cinema/presentation/widgets/tmdb_search_modal.dart`
- [x] T010 [P] [US1] Create `MediaPosterCard` widget for search results in `lib/features/cinema/presentation/widgets/media_poster_card.dart`
- [x] T011 [US1] Add "Add Movie/Series" button to `CreatorModal` in `lib/features/dashboard/presentation/widgets/creator_modal.dart` to trigger the search modal

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently (searching and viewing results).

---

## Phase 4: User Story 2 - Add Media to Everglow (Priority: P1)

**Goal**: Allow adding a selected search result to the Firestore `watch_list` collection with a status.

**Independent Test**: Tap a search result, confirm the "Add to Everglow?" dialog, and verify the record appears in Firestore.

### Implementation for User Story 2

- [x] T012 [US2] Implement `saveToWatchList` with duplicate check (TMDB ID) in `lib/features/cinema/data/services/tmdb_service.dart`
- [x] T013 [US2] Create cute confirmation dialog with "To Watch" / "Watched" toggle in `lib/features/cinema/presentation/widgets/tmdb_search_modal.dart`
- [x] T014 [US2] Integrate `saveToWatchList` call into search result tap handler
- [x] T015 [US2] Add success/error SnackBar feedback and auto-close modal after successful save

**Checkpoint**: At this point, User Stories 1 and 2 should both work independently (searching and adding to Firestore).

---

## Phase 5: User Story 3 - View Cinema Collection (Priority: P2)

**Goal**: Display the saved watch list in a dedicated Cinema screen.

**Independent Test**: Navigate to the Cinema screen and see the list of posters for added items.

### Implementation for User Story 3

- [x] T016 [US3] Implement `getWatchListStream` in `lib/features/cinema/data/services/tmdb_service.dart`
- [x] T017 [US3] Create `CinemaScreen` widget in `lib/features/cinema/presentation/screens/cinema_screen.dart`
- [x] T018 [US3] Implement `StreamBuilder` and `GridView` to display the `watch_list` in `lib/features/cinema/presentation/screens/cinema_screen.dart`
- [x] T019 [US3] Add navigation to `CinemaScreen` from the dashboard (e.g., via a new card or icon)

**Checkpoint**: All user stories should now be independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T020 [P] Implement pink placeholder image for results with missing `poster_path`
- [x] T021 [P] Add loading indicators (CircularProgressIndicator) to the search grid and add-to-list action
- [x] T022 Handle "No results found" state in the search modal
- [x] T023 Final UI review to ensure "bouncy" animations (animate_do) and Everglow aesthetic

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories.
- **User Stories (Phase 3+)**: All depend on Foundational phase completion.
- **Polish (Final Phase)**: Depends on all user stories being complete.

### Parallel Opportunities

- T002 (API Keys) can run in parallel with T001 (Dependencies).
- T004 (Model) can run in parallel with T005 (Service skeleton).
- Once Foundational is done, UI (T007) and Logic (T006) for US1 can start in parallel.
- US3 development can start after T012 is implemented if there is sample data in Firestore.

---

## Parallel Example: User Story 1

```bash
# Launch logic and UI base for User Story 1 together:
Task: "Implement searchMedia logic with TMDB API call in lib/features/cinema/data/services/tmdb_service.dart"
Task: "Create TMDBSearchModal base widget in lib/features/cinema/presentation/widgets/tmdb_search_modal.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 & 2)

1. Complete Phase 1 & 2 (Setup & Foundation).
2. Complete Phase 3 (US1 - Searching).
3. Complete Phase 4 (US2 - Adding).
4. **STOP and VALIDATE**: Search for a movie, add it, and check Firestore.

### Incremental Delivery

1. Setup + Foundation → Core ready.
2. Add Search Modal (US1) → Demo searching.
3. Add Persistence (US2) → Demo saving.
4. Add View Screen (US3) → Full feature complete.
