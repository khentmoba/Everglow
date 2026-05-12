# Feature Specification: Gamified Pink UI Modernization

**Feature Branch**: `018-gamified-pink-ui`  
**Created**: 2026-05-11  
**Status**: Draft  
**Input**: User description: "Modernize the entire Everglow app UI, moving away from a single, bland pastel pink color and into a layered, multi-dimensional 'Gamified Pink' aesthetic..."

## Clarifications

### Session 2026-05-11
- Q: XP Progress Bar Logic → A: Local Persistence (Firestore-backed)
- Q: Glassmorphism Performance Fallback → A: Automatic Fallback (Solid colors)
- Q: UI Theme Toggle → A: Permanent Overhaul (Classic UI deprecated)
- Q: Audio Feedback (SFX) → A: Subtle SFX (Muteable)
- Q: Accessibility Options → A: System Sync (Respect OS reduced motion/contrast)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Immersive Visual Refresh (Priority: P1)

As a user (Clair or Khent), I want to see a rich, multi-dimensional UI when I open the app so that the experience feels premium, gamified, and modern rather than flat and bland.

**Why this priority**: This is the core requirement. The entire request is about the visual overhaul.

**Independent Test**: Can be tested by navigating through all main screens (Dashboard, Living Archive, Academy, Lock Screen, Chat) and verifying the new gradients, frosted glass effects, and glowing borders are present.

**Acceptance Scenarios**:

1. **Given** the app is open, **When** I look at the background, **Then** I see a shifting pink-to-peachy-magenta gradient with integrated digital circuitry and star trail patterns.
2. **Given** any screen with cards (Dashboard, Academy), **When** I view the containers, **Then** they appear as floating, stacked frosted glass panels (semi-transparent blur) with glowing iridescent outlines.

---

### User Story 2 - High-Fidelity Interaction (Priority: P2)

As a user, I want buttons and icons to have detailed textures and micro-animations so that every interaction feels bouncy, satisfying, and "alive".

**Why this priority**: Enhances the gamified feel and user engagement, making the app feel like a high-quality game interface.

**Independent Test**: Can be tested by tapping buttons and observing ripple effects, particle effects (Academy), and pulsing indicators (Music cards).

**Acceptance Scenarios**:

1. **Given** the "Enter Academy" button, **When** I view it, **Then** it looks like an elaborate portal with particle effects and an electric pink glow.
2. **Given** any interactive element (buttons, cards), **When** I tap or press it, **Then** I see a soft ripple effect and the component feels "bouncy" in its movement.

---

### User Story 3 - Detailed Screen Specifics (Priority: P3)

As a user, I want specific screen elements (Roulette, Film Reel borders, Ornate handle) to have high-detail thematic designs so that the app feels like a cohesive "Digital Sanctuary".

**Why this priority**: Completes the thematic immersion for specific features and provides the "WOW" factor.

**Independent Test**: Can be tested by opening "Our Cinema", "Spin for a Date", and the "Lock Screen".

**Acceptance Scenarios**:

1. **Given** the Living Archive, **When** I view the borders, **Then** I see stylized film-reel patterns with glowing edges.
2. **Given** the Lock Screen, **When** I enter a code, **Then** the numbers appear as a glowing numeric matrix with rippling light effects on tap.
3. **Given** the Dashboard, **When** I see the "Spin for a Date" button, **Then** it looks like an elaborate digital roulette wheel with floating symbols and an iridescent shine.

---

### Edge Cases

- **Performance on Web**: Heavy use of `BackdropFilter` (frosted glass) and many simultaneous micro-animations may impact frame rates on low-end hardware. **Resolution**: System will detect frame rate drops and automatically fallback to semi-transparent solid colors (no blur) if necessary.
- **Text Readability**: Shifting gradients and glowing outlines must not compromise the readability of critical text (metrics, chat messages).
- **Responsive Scaling**: Ensuring that high-detail "emblem-buttons" and "portal-gates" scale correctly without losing their visual density on smaller screens.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST replace flat pink backgrounds with dynamic shifting pink-to-peachy-magenta gradients with subtle digital circuitry patterns.
- **FR-002**: System MUST implement a "Frosted Glass" (glassmorphism) design system for all main card containers, incorporating semi-transparent background blur.
- **FR-003**: System MUST add glowing iridescent outlines to all floating card panels.
- **FR-004**: System MUST update the typography system to use stylized, semi-futuristic rounded typefaces for all titles and key metrics.
- **FR-005**: System MUST implement micro-animations across the UI: pulsing "live" indicators on music cards, sparkles on successful actions, and tap ripple effects.
- **FR-006**: System MUST overhaul icons (Heart, Pen, Chat) to be detailed, textured emblems with glowing neon outlines.
- **FR-007**: System MUST redesign specific feature buttons as high-detail emblems: "Enter Academy" as a portal, "Spin for a Date" as a digital roulette.
- **FR-008**: System MUST implement the "Experience Points" (XP) progress bar that persists progress in Firestore.
- **FR-009**: System MUST ensure a global border radius of 32.0 or higher for all container elements.
- **FR-010**: System MUST implement a glowing numeric matrix for the lock screen with rippling light effects on tap.
- **FR-011**: System MUST provide subtle audio feedback (SFX) for key interactions, including a global mute setting.
- **FR-012**: System MUST respect OS-level accessibility settings (Reduce Motion, High Contrast) by simplifying animations and patterns when active.

### Key Entities *(include if feature involves data)*

- **Visual Theme**: The global configuration defining the "Gamified Pink" palette, glassmorphism tokens, and glow parameters.
- **Animated Emblem**: A reusable component for icons and buttons that supports textures, neon outlines, and micro-animations.
- **User Progress**: A data entity representing the user's XP and level-up milestones.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the primary screens (Dashboard, Archive, Academy, Chat, Lock) are visually updated to the "Gamified Pink" aesthetic.
- **SC-002**: All interactive components (buttons/cards) respond with a "bouncy" animation and ripple effect within 16ms of user input.
- **SC-003**: Text contrast for titles and metrics remains at a minimum ratio of 4.5:1 against the new gradient/patterned backgrounds.
- **SC-004**: The "Experience Points" bar accurately reflects progress based on user activity (e.g., studies completed, dates spun).

## Assumptions

- **Assumption 1**: Google Fonts or similar free high-quality font sources will be used for the semi-futuristic rounded typefaces.
- **Assumption 2**: The "experience points" logic already exists or will be stubbed as a visual progress bar based on existing activity flags.
- **Assumption 3**: The app is primarily viewed in a mobile-focused container (max width 500px) as established in previous design iterations.
- **Assumption 4**: The XP system will follow a simple linear progression (points per action) for this iteration.
