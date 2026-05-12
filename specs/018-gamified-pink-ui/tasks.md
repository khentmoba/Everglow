# Tasks: Gamified Pink UI Modernization

**Input**: Design documents from `/specs/018-gamified-pink-ui/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and core theme setup.

- [x] T001 Add `just_audio` dependency to `pubspec.yaml`
- [x] T002 [P] Create directory structure: `lib/core/theme/`, `lib/core/audio/`, `lib/features/xp/`
- [x] T003 Define `AppTheme` with glassmorphism tokens in `lib/core/theme/app_theme.dart`
- [x] T004 Implement `AudioService` for SFX management in `lib/core/audio/audio_service.dart`



## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure required for all user stories.

- [x] T005 [P] Create `UserProgress` model in `lib/features/xp/domain/models/user_progress.dart`
- [x] T006 Implement `XPService` for Firestore persistence in `lib/features/xp/data/services/xp_service.dart`
- [x] T007 Create `GlassContainer` shared widget with fallback logic in `lib/shared/widgets/glass_container.dart`
- [x] T008 [P] Implement `CircuitryPainter` for background patterns in `lib/shared/widgets/circuitry_painter.dart`

**Checkpoint**: Foundation ready - UI overhaul and gamification logic can now begin.

---

## Phase 3: User Story 1 - Immersive Visual Refresh (Priority: P1) 🎯 MVP

**Goal**: Implement the core "Gamified Pink" aesthetic with shifting gradients and frosted glass panels across all main screens.

**Independent Test**: Navigate through Dashboard, Archive, and Academy; verify shifting pink-to-peachy-magenta gradients and frosted glass cards are visible.

### Implementation for User Story 1

- [x] T009 [P] [US1] Update `AppTheme` to include shifting gradient logic in `lib/core/theme/app_theme.dart`
- [x] T010 [US1] Overhaul `DashboardScreen` background with shifting gradients and circuitry in `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- [x] T011 [US1] Apply `GlassContainer` and iridescent outlines to all Dashboard cards in `lib/features/dashboard/presentation/widgets/`
- [x] T012 [US1] Update global typography to use semi-futuristic rounded fonts in `lib/core/theme/app_theme.dart`

**Checkpoint**: Core visual identity established.

---

## Phase 4: User Story 2 - High-Fidelity Interaction (Priority: P2)

**Goal**: Add textured icons, micro-animations, and audio feedback to all interactive elements.

**Independent Test**: Tap buttons to trigger ripple effects, bouncy animations, and subtle SFX; observe particle effects on the Academy button.

### Implementation for User Story 2

- [x] T013 [P] [US2] Implement `AnimatedEmblem` for textured icons with neon outlines in `lib/shared/widgets/animated_emblem.dart`
- [x] T014 [US2] Implement `BouncyButton` widget with ripple and bounce effects in `lib/shared/widgets/bouncy_button.dart`
- [x] T015 [US2] Redesign "Enter Academy" as a portal button in `lib/features/academy/widgets/academy_portal_card.dart`
- [x] T016 [US2] Integrate `AudioService` triggers for button taps and XP gains across the app

**Checkpoint**: App feels "alive" with interactive feedback.

---

## Phase 5: User Story 3 - Detailed Screen Specifics (Priority: P3)

**Goal**: Implement feature-specific themed elements like the digital roulette, film-reel borders, and the glowing numeric lock matrix.

**Independent Test**: Open "Our Cinema" to see film borders; use the Lock Screen to see the glowing matrix; view the XP progress bar on the Dashboard.

### Implementation for User Story 3

- [x] T017 [P] [US3] Redesign "Spin for a Date" as a digital roulette wheel in `lib/features/date_randomizer/presentation/widgets/randomizer_card.dart`
- [x] T018 [P] [US3] Implement film-reel borders for Living Archive in `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T019 [US3] Overhaul Lock Screen with glowing numeric matrix in `lib/features/entry/presentation/widgets/passcode_input.dart`
- [x] T020 [US3] Implement `XPProgressBar` widget in `lib/features/xp/presentation/widgets/xp_progress_bar.dart`

**Checkpoint**: All feature-specific overhauls complete.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T021 [P] Fine-tune animation easing curves and iridescent glow intensities
- [ ] T022 Verify "Reduced Motion" accessibility sync across all animated widgets
- [ ] T023 Run `quickstart.md` validation and perform final performance profiling on Flutter Web

---

## Dependencies & Execution Order

### Phase Dependencies
- **Phase 1 & 2**: MUST be completed before any User Story work.
- **US1 (Phase 3)**: Should be completed first to establish the global look and feel.
- **US2 (Phase 4)**: Can proceed once `GlassContainer` (T007) is ready.
- **US3 (Phase 5)**: Depends on `XPService` (T006) and `AppTheme` (T003).

### Parallel Opportunities
- Setup tasks (T001-T004) can run in parallel.
- Foundational model (T005) and Painter (T008) can run in parallel.
- Once Foundation is complete, US1, US2, and US3 can proceed in parallel across their respective feature directories.
