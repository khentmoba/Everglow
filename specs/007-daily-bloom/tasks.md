# Tasks: Daily Bloom

**Input**: Design documents from `/specs/007-daily-bloom/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and directory structure

- [x] T001 Create feature directory structure in `lib/features/daily_bloom/` (data, domain, presentation)
- [x] T002 [P] Create empty `GardenProvider` in `lib/features/daily_bloom/presentation/providers/garden_provider.dart`
- [x] T003 [P] Add `GardenProvider` to `MultiProvider` in `lib/main.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core model and service infrastructure

- [x] T004 Create `GardenStats` model in `lib/features/daily_bloom/data/models/garden_stats.dart`
- [x] T005 [P] Create `GardenRepository` interface in `lib/features/daily_bloom/domain/repository/garden_repository.dart`
- [x] T006 Implement `GardenService` (Firestore) in `lib/features/daily_bloom/data/services/garden_service.dart`
- [x] T007 Implement repository implementation in `lib/features/daily_bloom/data/repository/garden_repository_impl.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin.

---

## Phase 3: User Story 1 - Daily Engagement Tracking (Priority: P1) 🎯 MVP

**Goal**: Track visits and note reads to increment interactions and maintain streaks.

**Independent Test**: Verify `streakCount` and `totalInteractions` increment in Firestore when navigating to the dashboard or opening a note.

### Implementation for User Story 1

- [x] T008 [US1] Implement `recordInteraction` logic in `lib/features/daily_bloom/data/services/garden_service.dart` (including streak calculation)
- [x] T009 [US1] Implement `GardenProvider` methods for recording visits and note reads in `lib/features/daily_bloom/presentation/providers/garden_provider.dart`
- [x] T010 [US1] Add `recordVisit` hook to `initState` in `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- [x] T011 [US1] Add `recordInteraction` hook to `markAsRead` in `lib/features/dashboard/data/services/letterbox_service.dart`

**Checkpoint**: User Story 1 functional - engagement is tracked in real-time.

---

## Phase 4: User Story 2 - Visual Lily Progression (Priority: P1)

**Goal**: Display the lily in the dashboard and animate its growth through 5 stages.

**Independent Test**: Manually update Firestore stats and verify the lily's visual stage updates with a smooth cross-fade.

### Implementation for User Story 2

- [x] T012 [P] [US2] Create `LilyPainter` or `LilyStageWidget` in `lib/features/daily_bloom/presentation/widgets/lily_stage_widget.dart` for rendering stages
- [x] T013 [P] [US2] Implement `DailyBloom` main widget in `lib/features/daily_bloom/presentation/widgets/daily_bloom.dart`
- [x] T014 [US2] Implement "breathing" animation using `TweenAnimationBuilder` in `lib/features/daily_bloom/presentation/widgets/daily_bloom.dart`
- [x] T015 [US2] Implement stage transition animations using `AnimatedSwitcher` in `lib/features/daily_bloom/presentation/widgets/daily_bloom.dart`
- [x] T016 [US2] Integrate `DailyBloom` widget into `lib/features/dashboard/presentation/screens/dashboard_screen.dart` after `TimelineView`

**Checkpoint**: User Story 2 functional - the lily is visible and growing.

---

## Phase 5: User Story 3 - Interactive Feedback (Priority: P2)

**Goal**: Provide visual feedback on interaction and show status tooltips.

**Independent Test**: Tap the lily to see the tooltip; observe the glow pulse when a note is read or the lily is tapped.

### Implementation for User Story 3

- [x] T017 [US3] Implement dynamic tooltip message logic based on `growthStage` in `lib/features/daily_bloom/presentation/widgets/daily_bloom.dart`
- [x] T018 [US3] Add rounded `StatusBubble` tooltip to the lily in `lib/features/daily_bloom/presentation/widgets/daily_bloom.dart`
- [x] T019 [US3] Implement subtle "glow pulse" or heart particle effect for interactions in `lib/features/daily_bloom/presentation/widgets/daily_bloom.dart`
- [x] T020 [US3] Trigger celebratory level-up animation (petal shower) when stage changes in `lib/features/daily_bloom/presentation/widgets/daily_bloom.dart`

**Checkpoint**: All user stories functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: UI refinement and performance verification

- [x] T021 Refine "Everglow" theme consistency (pinks, whites, border radiuses)
- [x] T022 Optimize animation performance for web
- [x] T023 Final validation against `quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 completion.
- **User Story 1 (Phase 3)**: Depends on Phase 2.
- **User Story 2 (Phase 4)**: Depends on Phase 1 (UI) and Phase 2 (Data). Can run partially in parallel with US1.
- **User Story 3 (Phase 5)**: Depends on Phase 4.

### Parallel Opportunities

- T002, T003 (Setup)
- T005, T007 (Foundational)
- T012, T013 (US2 UI)

---

## Implementation Strategy

### MVP First (US1 & US2 Foundations)

1. Complete Setup and Foundational phases.
2. Implement US1 (tracking) and the first stage of US2 (displaying the sprout).
3. **STOP and VALIDATE**: Verify visits are tracked and the sprout is visible on the dashboard.

### Incremental Delivery

1. Add growth stages to US2.
2. Add interactive feedback (US3).
3. Final polish.
