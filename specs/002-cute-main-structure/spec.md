# Feature Specification: Cute Main Structure

**Feature Branch**: `002-cute-main-structure`
**Created**: 2026-05-08
**Status**: Draft
**Input**: User description: "I need you to generate the Flutter code for the main application structure, focusing on a highly 'pinkish' and overwhelmingly cute aesthetic. I already have the basic passcode logic ('1111') set up. 1. The Global 'Cute' Theme (main.dart)..."

## Clarifications

### Session 2026-05-08

- Q: Navigation Stack Behavior → A: Replace the route entirely (back button exits the app)
- Q: Time Calculation Precision → A: Use a precise library for exact years/months/days, acting as a real-time living counter down to the second

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Enter Gateway & Blooming Transition (Priority: P1)

As a user, when I successfully enter the correct passcode, I want to experience a seamless, full-screen "blooming" visual transition into the main application so that the entry feels magical and cute.

**Why this priority**: The entry gateway transition is the primary entry point to the application and sets the aesthetic tone.

**Independent Test**: Can be fully tested by entering '1111' in the gateway and observing the visual scaling and fading animation leading to the dashboard.

**Acceptance Scenarios**:
1. **Given** the user is on the lock screen, **When** they enter the correct passcode ('1111'), **Then** the screen scales up filling with a pink background and smoothly fades into the main dashboard.

---

### User Story 2 - Real-Time Anniversary Counter (Priority: P1)

As a user, I want to see a real-time counter displaying the exact time we've been together (Years, Months, Days, Hours, Minutes, Seconds) so that I can playfully track the relationship duration.

**Why this priority**: The real-time counter is the core feature of the dashboard.

**Independent Test**: Can be fully tested by viewing the dashboard and verifying that the counter increments every second and accurately calculates time from the set anniversary.

**Acceptance Scenarios**:
1. **Given** the dashboard is loaded, **When** the counter ticks every second, **Then** the seconds digit animates with a "pop" or slide transition.
2. **Given** the dashboard is loaded, **When** viewing the metrics, **Then** Years, Months, Days, Hours, Minutes, and Seconds are accurately displayed based on the configured anniversary date.

---

### User Story 3 - Organic Main Dashboard Experience (Priority: P2)

As a user, I want a main dashboard that feels organic, soft, and playful with non-rigid layouts and interactive cute elements so that the experience remains overwhelmingly "cute."

**Why this priority**: Defines the layout and overall aesthetic post-entry.

**Independent Test**: Can be fully tested by navigating the dashboard and interacting with the primary action button.

**Acceptance Scenarios**:
1. **Given** the user is on the main dashboard, **When** they view the layout, **Then** elements are displayed in a spaced-out, non-rigid list rather than a strict grid.
2. **Given** the user is on the main dashboard, **When** they tap the heart-shaped primary action button, **Then** a playful visual effect (confetti or scale animation) is triggered.

## Edge Cases

- **Back Navigation**: The dashboard replaces the lock screen as the root route. Pressing the system back button on the dashboard will exit the app rather than returning to the lock screen.
- **Time Calculation Precision**: The relationship duration must be precisely calculated (accounting for leap years and month length variations) using a specialized library, not approximated, and ticking continuously down to the second.
- What happens if the anniversary date is set to the future?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a global aesthetic theme using a soft pink palette and a "cute" font.
- **FR-002**: System MUST apply a soft, rounded appearance with high border radius to all cards and buttons globally.
- **FR-003**: System MUST execute a two-step transition ("blooming" effect) from the lock screen to the dashboard upon passcode validation: a scale transition filling the screen, followed by a fade transition.
- **FR-004**: System MUST display a real-time tracking counter on the dashboard, calculated continuously from a hardcoded anniversary date down to the second.
- **FR-005**: System MUST animate the seconds digit visually on every tick.
- **FR-006**: System MUST layout the dashboard elements in an organic, free-flowing manner using spaced-out lists or staggered layouts without rigid grids.
- **FR-007**: System MUST include a heart-shaped primary action button that triggers a transient micro-animation (e.g., confetti burst) on tap.
- **FR-008**: System MUST calculate time since February 14, 2026.

### Key Entities *(include if feature involves data)*

- **Anniversary Counter**: Represents the elapsed time tracking metrics (Years, Months, Days, Hours, Minutes, Seconds) based on a configured start date.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The transition from lock screen to dashboard completes visually in under 2 seconds.
- **SC-002**: The real-time counter updates at exactly 1-second intervals with visible animation.
- **SC-003**: All primary action buttons and metric cards across the application apply the high border radius (e.g., 32px) without visual artifacts.

## Assumptions

- Passcode logic ('1111') is already implemented in the entry screen and can trigger the newly defined visual transition.
- The "anniversary date" is statically configured within the app and does not require a dynamic settings interface for this iteration.
- The initial layout will primarily house the metric card, leaving room for future features to be added to the organic list view.
