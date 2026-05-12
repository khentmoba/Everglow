---
description: "Task list for Everglow Academy OpenTDB Integration"
---

# Tasks: Everglow Academy OpenTDB Integration

**Input**: Design documents from `/specs/016-academy-opentdb-integration/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Update `pubspec.yaml` with `html_unescape`, `crypto`, `shared_preferences`, and `http` dependencies
- [x] T002 [P] Create directory structure for `lib/features/academy/services/` and `lib/features/academy/presentation/widgets/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Implement `TriviaApiService` with session token persistence in `lib/features/academy/services/trivia_api_service.dart`
- [x] T004 Implement exponential backoff and retry logic for OpenTDB rate limits in `lib/features/academy/services/trivia_api_service.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Seamless Question Replenishment (Priority: P1) 🎯 MVP

**Goal**: Automatically fetch new questions when the database is low (< 10 unanswered).

**Independent Test**: Manually reduce Firestore question count for a category and verify background fetch triggers and populates 50 new items.

### Implementation for User Story 1

- [x] T005 [P] [US1] Update `AcademyQuestion` model to include SHA-256 hashing for Document IDs in `lib/features/academy/models/academy_question.dart`
- [x] T006 [US1] Implement `AcademySyncService` for auto-fill logic and Firestore ingestion in `lib/features/academy/services/academy_sync_service.dart`
- [x] T007 [US1] Integrate auto-fill trigger in `lib/features/academy/presentation/screens/academy_hub_screen.dart`

**Checkpoint**: User Story 1 fully functional and testable independently

---

## Phase 4: User Story 2 - High-Fidelity Trivia Experience (Priority: P2)

**Goal**: Decode HTML entities and correctly map OpenTDB categories to Everglow themes.

**Independent Test**: Verify questions in Firestore contain decoded text (no `&quot;`) and appear in the correct 'Engineering' or 'Tourism' hubs.

### Implementation for User Story 2

- [x] T008 [P] [US2] Implement `html_unescape` decoding in `TriviaApiService` mapping logic in `lib/features/academy/services/trivia_api_service.dart`
- [x] T009 [P] [US2] Implement category mapping (IDs 18, 19, 22, 23) in `TriviaApiService`
- [x] T010 [US2] Create themed `TriviaLoadingOverlay` widget in `lib/features/academy/presentation/widgets/trivia_loading_overlay.dart`

**Checkpoint**: User Story 2 functional; questions are premium and themed

---

## Phase 5: User Story 3 - Synchronized 1v1 Challenges (Priority: P3)

**Goal**: Ensure the host handles the fetch trigger to keep both players synced.

**Independent Test**: Start a 1v1 match and verify that only the host triggers the API call while the guest waits for the synced update.

### Implementation for User Story 3

- [x] T011 [US3] Implement host-authoritative check in `AcademySyncService.triggerAutoFill()` in `lib/features/academy/services/academy_sync_service.dart`
- [x] T012 [US3] Update 1v1 initialization flow to handle replenishment wait state in `lib/features/academy/presentation/screens/game_board_screen.dart`

**Checkpoint**: All user stories functional and synchronized

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and cleanup

- [x] T013 [P] Documentation updates and code cleanup across `lib/features/academy/`
- [x] T014 Run validation of all scenarios defined in `quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Can start immediately
- **Foundational (Phase 2)**: Depends on T001/T002 - BLOCKS all user stories
- **User Stories (Phase 3+)**: Depend on Foundational phase (T003/T004) completion

### User Story Dependencies

- **US1**: No dependencies on other stories
- **US2**: Independent, but relies on `TriviaApiService` mapping from Phase 2
- **US3**: Depends on US1 auto-fill logic completion (T006)

---

## Parallel Example: User Story 2

```bash
# Launch decoding and mapping implementation together:
Task: "Implement html_unescape decoding in TriviaApiService in lib/features/academy/services/trivia_api_service.dart"
Task: "Implement category mapping in TriviaApiService"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Setup & Foundational phases.
2. Complete US1 implementation.
3. **STOP and VALIDATE**: Test independent replenishment.

### Incremental Delivery

1. Setup + Foundation → Core API ready
2. Add US1 → Auto-fill works (MVP)
3. Add US2 → Content quality improved
4. Add US3 → 1v1 fully synchronized
