# Feature Specification: Everglow Guardian

**Feature Branch**: `006-everglow-guardian`  
**Created**: 2026-05-11  
**Status**: Draft  
**Input**: User description: "Build the Everglow Guardian feature for my private Flutter web app, 'Everglow.' This feature introduces a persistent, interactive digital pet that inhabits the dashboard and acts as the 'soul' of the sanctuary.  Directives for Implementation:1. Character Design & UI (EverglowGuardian Widget)Create a StatefulWidget called EverglowGuardian.The Visuals: Design a small, cute character (a cat) using pure Flutter widgets (like Container, CircleAvatar, or CustomPaint).The Aesthetic: The character must fit the 'Everglow' theme: use soft pinks, white, and a very 'bouncy' feel.  Persistence: The Guardian should be positioned as a Positioned widget in a Stack at the bottom-right of the dashboard, or as a persistent floating element that stays in view as the user scrolls.  2. Animations & State MachineIdle Animation: Use an AnimationController to give the Guardian a gentle 'breathing' or 'floating' up-and-down motion.  The Welcome: When the dashboard first loads (the 'blooming' transition), have the Guardian wave or scale up with a bounce to greet the user.  Interactive Taps: Wrap the Guardian in a GestureDetector. When tapped, trigger a cute reaction animation—like a high-jump, a spin, or a burst of tiny pink heart particles around it.  3. Communication (The Thought Bubble)Implement a small 'thought bubble' widget that occasionally appears above the Guardian.The Content: It should display short, sweet, randomly selected messages like 'Happy to see you!', 'Everything is pink today!', or 'I missed you, Clair!'.  The Logic: Use a Timer to show the bubble for 5 seconds every few minutes, or show it immediately after a tap interaction.  4. Layout IntegrationIntegrate the EverglowGuardian as a top-level layer in the Scaffold of the main dashboard so it remains visible regardless of the scroll position.  Ensure it does not block the interaction with the LetterboxView, RandomizerCard, or TimelineView.  Please ensure the code follows the established 'very pinky' global theme and utilizes high border radiuses and soft shadows for all elements."
## Clarifications

### Session 2026-05-11

- Q: Should the Guardian be pinned to the viewport or anchor to content? → A: Viewport Overlay (Floating)
- Q: Should messages be hardcoded or fetched from a service? → A: Firebase Firestore (with Local Seeding)
- Q: How should rapid tapping be handled? → A: Immediate Reset (Bouncy)
- Q: How should scaling be handled on mobile? → A: Static Small (Fixed Pixel Size)
- Q: How often should idle messages appear? → A: Occasional (Random 3-7 mins)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Interactive Companion (Priority: P1)

As a user, I want to interact with a cute character on my dashboard so that the sanctuary feels alive and responsive to my presence.

**Why this priority**: Interaction is the core value proposition of the Guardian feature, transforming it from a static decoration into a "soul."

**Independent Test**: Can be tested by tapping the character and observing the jump/spin/particle effects.

**Acceptance Scenarios**:

1. **Given** the dashboard is loaded, **When** I tap the Guardian character, **Then** it should immediately trigger a high-jump or spin animation.
2. **Given** I tap the Guardian, **When** the animation starts, **Then** tiny pink heart particles should burst around it.

---

### User Story 2 - Cheerful Greeting (Priority: P1)

As a user, I want the Guardian to greet me when I enter the sanctuary so that I feel immediately welcomed.

**Why this priority**: Sets the emotional tone of the application upon entry.

**Independent Test**: Can be tested by performing the "blooming" entry transition (e.g., entering the passcode) and watching the Guardian's entrance.

**Acceptance Scenarios**:

1. **Given** I am entering the dashboard via the blooming transition, **When** the components reveal, **Then** the Guardian should scale up with a bouncy effect and wave.

---

### User Story 3 - Gentle Presence (Priority: P2)

As a user, I want the Guardian to have a subtle idle motion so that it feels like a living being rather than a static image.

**Why this priority**: Enhances the "living sanctuary" aesthetic.

**Independent Test**: Can be tested by observing the character while idle on the dashboard.

**Acceptance Scenarios**:

1. **Given** the dashboard is open, **When** no interaction occurs, **Then** the Guardian should perform a gentle vertical "breathing" or floating motion.

---

### User Story 4 - Spontaneous Messages (Priority: P2)

As a user, I want the Guardian to speak to me occasionally through thought bubbles so that I receive unexpected moments of sweetness.

**Why this priority**: Adds depth to the character's personality and strengthens the emotional bond.

**Independent Test**: Can be tested by waiting for a few minutes on the dashboard or tapping the Guardian.

**Acceptance Scenarios**:

1. **Given** the dashboard is open, **When** a tap occurs or a few minutes pass, **Then** a small thought bubble should appear above the Guardian for 5 seconds.
2. **Given** the thought bubble is visible, **When** it contains text, **Then** it must display one of several randomized sweet messages.

---

### Edge Cases

- **Interaction Interference**: Handled via immediate animation reset to maintain high responsiveness.
- **Z-Order/Blocking**: How does the system ensure the Guardian doesn't cover critical buttons in the Timeline or Randomizer? (Should be positioned in a corner with a small hit-box).
- **Screen Resizing**: Character remains at a fixed pixel size pinned to the bottom-right relative to the viewport.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST implement an `EverglowGuardian` StatefulWidget.
- **FR-002**: Character MUST be designed using pure Flutter widgets (Container, CircleAvatar, etc.) representing a cute cat with a fixed small footprint (approx. 80x80px).
- **FR-003**: System MUST apply the 'Everglow' theme (soft pinks, white, high border radius, soft shadows).
- **FR-004**: System MUST position the Guardian as a persistent Viewport Overlay (top-level layer in the Dashboard Scaffold Stack) so it remains visible during scrolling.
- **FR-005**: System MUST provide an idle `AnimationController` for a floating/breathing effect.
- **FR-006**: System MUST trigger a "Welcome" animation (bounce scale + wave) upon initial dashboard load.
- **FR-007**: System MUST detect taps and trigger randomized reaction animations (jump, spin) with immediate reset on subsequent taps.
- **FR-008**: System MUST implement a particle system for pink heart bursts during interactions.
- **FR-009**: System MUST implement a `GuardianService` to fetch randomized messages from the `guardian_messages` Firestore collection.
- **FR-010**: System MUST automatically seed the Firestore collection with initial messages if empty.
- **FR-011**: System MUST manage message visibility (5s duration, randomized 3-7 min idle interval or immediate on-tap trigger).

### Key Entities *(include if feature involves data)*

- **GuardianState**: Represents the current mood or animation state (Idle, Greeting, Reacting, Speaking).
- **GuardianMessage**: Represents a message document with content and metadata.
- **GuardianService**: Manages Firestore interaction and local seeding logic.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Guardian is visible and persistent across all scroll states of the dashboard.
- **SC-012**: Tap interactions respond within 100ms with a visual change.
- **SC-003**: Thought bubbles appear at least once every 7 minutes during idle and always after a tap.
- **SC-004**: UI maintains 60fps during character animations and particle bursts on web.

## Assumptions

- **A-001**: The Guardian does not require persistent memory of its "mood" across sessions.
- **A-002**: "Pure Flutter widgets" excludes using external assets like Lottie or Rive for the character itself.
- **A-003**: The "soul of the sanctuary" implies the Guardian is always present on the main dashboard but not necessarily on auth screens.
- **A-004**: The hit-box for the Guardian is limited to its visual bounds to avoid blocking background interactions.
