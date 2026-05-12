# Feature Specification: Daily Bloom

**Feature Branch**: `007-daily-bloom`  
**Created**: 2026-05-11  
**Status**: Draft  
**Input**: User description: "Build the Daily Bloom feature for my private Flutter web app, Everglow. This feature is a gamified digital garden where a pink lily grows and flourishes based on user engagement (login streaks and notes read)."

## Clarifications

### Session 2026-05-11
- Q: Does every single note read increment the totalInteractions counter? → A: Every note read increments totalInteractions.
- Q: What is the exact logic for a "consecutive day"? → A: Calendar day based on user's local timezone.
- Q: Should there be visual feedback for every single interaction? → A: Subtle glow pulse on every interaction; petals on level-up.
- Q: Should the tooltip messages be static or evolve as the lily grows? → A: Dynamic messages that evolve with growth stages.
- Q: How should the system handle users who do not yet have a GardenStats record? → A: Auto-initialize with default stats on first dashboard visit.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Daily Engagement Tracking (Priority: P1)

As a user, I want my daily visits to be tracked so that I can see my progress and help my lily grow.

**Why this priority**: Core foundation of the gamification. Without tracking visits and streaks, the lily cannot grow.

**Independent Test**: Can be tested by logging in on multiple days and verifying the `streakCount` and `totalInteractions` increment in the database.

**Acceptance Scenarios**:

1. **Given** I am logged in, **When** I visit the dashboard, **Then** my `totalInteractions` should increment by 1.
2. **Given** I visited yesterday, **When** I visit today, **Then** my `streakCount` should increment by 1.
3. **Given** I missed a day, **When** I visit today, **Then** my `streakCount` should reset to 1.

---

### User Story 2 - Visual Lily Progression (Priority: P1)

As a user, I want to see my pink lily grow through different stages so that I feel rewarded for my engagement.

**Why this priority**: Primary visual appeal and purpose of the feature.

**Independent Test**: Can be tested by manually updating `streakCount` and `totalInteractions` in Firestore and verifying the lily's visual stage updates on the dashboard.

**Acceptance Scenarios**:

1. **Given** I have a new account (Stage 0), **When** I start interacting, **Then** I should see a small sprout in a pink pot.
2. **Given** I reach the required growth threshold, **When** the stage updates, **Then** I should see a smooth transition animation to the next stage (e.g., sprout -> bud).
3. **Given** I reach Stage 5, **When** I view the lily, **Then** I should see a magnificent, glowing pink lily in full bloom.

---

### User Story 3 - Interactive Feedback (Priority: P2)

As a user, I want to interact with my lily to see its status and feel a connection to it.

**Why this priority**: Enhances the "alive" feeling and provides feedback on growth progress.

**Independent Test**: Can be tested by tapping the lily and verifying the tooltip appears with the correct message.

**Acceptance Scenarios**:

1. **Given** the lily is displayed, **When** I tap on it, **Then** a rounded 'Status' bubble should appear.
2. **Given** the lily is "loved", **When** I tap on it, **Then** it should say 'Your lily is feeling loved! 🌸'.

---

### Edge Cases

- **Multiple visits per day**: Ensure `streakCount` only increments once per calendar day, while `totalInteractions` might increment per visit or per note read.
- **Offline access**: How the app handles interaction tracking when the user's connection is intermittent (assume Firestore offline persistence handles this).
- **Timezone shifts**: Ensure the "consecutive day" logic is robust across different user timezones.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST track user garden statistics in Firestore using a `GardenStats` model, auto-initializing a default record on the user's first visit if one does not exist.
- **FR-002**: System MUST increment `totalInteractions` every time the user visits the dashboard OR reads a note from the `Letterbox`.
- **FR-003**: System MUST calculate and update `streakCount` based on consecutive daily visits, defined by the calendar day in the user's local timezone.
- **FR-004**: System MUST define 5 distinct growth stages:
    - Stage 0-1: Small sprout in a pink pot.
    - Stage 2-3: Growing stem with a tightly closed bud.
    - Stage 4: Partially open lily with soft pink petals.
    - Stage 5: Glowing pink lily in full bloom.
- **FR-005**: System MUST trigger growth stage transitions based on the following `totalInteractions` thresholds:
    - Stage 1: 1 interaction
    - Stage 2: 5 interactions
    - Stage 3: 10 interactions
    - Stage 4: 20 interactions
    - Stage 5: 30 interactions

- **FR-006**: The `DailyBloom` widget MUST be integrated into the dashboard, positioned immediately after the `TimelineView`.
- **FR-007**: The lily MUST have a subtle 'breathing' or 'pumping' animation in its pot.
- **FR-008**: System MUST provide visual feedback:
    - EVERY interaction MUST trigger a subtle glow pulse or particle effect.
    - Level-up transitions MUST trigger a celebratory pulse and floating petal animation.
- **FR-009**: Tapping the lily MUST show a cute, rounded status tooltip with dynamic messages that evolve based on the current growth stage.

### Key Entities *(include if feature involves data)*

- **GardenStats**:
    - `currentStage` (int): The current visual stage of the lily (0-5).
    - `lastVisit` (DateTime): Timestamp of the last recorded interaction.
    - `streakCount` (int): Number of consecutive days visited.
    - `totalInteractions` (int): Cumulative count of visits and notes read.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can see their growth progress immediately upon dashboard load (under 1 second load time for the widget).
- **SC-002**: 100% of consecutive daily visits are accurately reflected in the `streakCount`.
- **SC-003**: Transitions between stages are visually smooth (60fps animations).
- **SC-004**: The 'breathing' animation remains consistent and does not impact application performance.

## Assumptions

- **A-001**: Users are authenticated before accessing the garden.
- **A-002**: Every note read interaction triggers a `totalInteractions` increment, enabling granular growth tracking.
- **A-003**: The 'Everglow' theme provides the necessary color palette (soft pinks, whites) and typography.
- **A-004**: The `TimelineView` exists and is a scrollable component on the main dashboard.
