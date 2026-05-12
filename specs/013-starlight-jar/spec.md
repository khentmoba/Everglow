# Feature Specification: Starlight Jar

**Feature Branch**: `013-starlight-jar`  
**Created**: 2026-05-11  
**Status**: Draft  
**Input**: User description: "Build a new feature called the Starlight Jar for my Flutter web app, Everglow. This feature is a digital 'gratitude vault' where we can write short notes of appreciation that visually drop into a glass jar as glowing stars."

## Clarifications

### Session 2026-05-11
- Q: How should the system handle empty or whitespace-only submissions? → A: Disable the "Drop" button until text is entered
- Q: How should the "random note" dialog be dismissed? → A: Explicit "Close" button in the dialog
- Q: If the database has many notes, how many stars should we render? → A: Render only the 100 most recent stars
- Q: Where exactly should the star fall from during the drop animation? → A: Top of the screen
- Q: What happens to the star that floats out after the note is read? → A: Star returns to the jar after reading

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Dropping a Star (Priority: P1)

As a user, I want to write a short note of appreciation and see it visually drop into a glass jar as a glowing star so that I can feel a sense of contribution to our shared gratitude vault.

**Why this priority**: This is the core interaction of the feature. Without the ability to "drop" stars, the "vault" concept doesn't exist.

**Independent Test**: Can be fully tested by clicking the "Drop a Star" button, entering text, and verifying that a star icon animates into the jar and the note is saved to the database.

**Acceptance Scenarios**:

1. **Given** I am on the dashboard, **When** I click "Drop a Star", **Then** I should see a cute, rounded text input dialog.
2. **Given** I have typed a note, **When** I click submit, **Then** a glowing star should animate from the top of the screen into the jar.

---

### User Story 2 - Reading a Random Note (Priority: P2)

As a user, I want to tap the jar to see a random note from our vault so that I can be reminded of past moments of appreciation.

**Why this priority**: This provides the "reward" for using the feature—the ability to reflect on stored gratitude.

**Independent Test**: Can be tested by tapping the jar and verifying that it shakes, a star floats out, and a random note is displayed in a pink dialog.

**Acceptance Scenarios**:

1. **Given** there are stars in the jar, **When** I tap the jar, **Then** it should shake for 1 second.
2. **Given** the jar has finished shaking, **When** a star floats out, **Then** I should see a beautiful, glowing pink dialog box with a random gratitude note.

---

### User Story 3 - Visual Piling & Persistence (Priority: P3)

As a user, I want to see all our previously dropped stars piled up at the bottom of the jar so that I can visually see how much gratitude we've shared over time.

**Why this priority**: This adds long-term value and visual satisfaction, though the feature functions without it.

**Independent Test**: Can be tested by adding multiple stars and verifying they remain visible in a "pile" at the bottom of the jar across sessions.

**Acceptance Scenarios**:

1. **Given** multiple notes exist in the database, **When** I view the jar, **Then** I should see a corresponding number of stars randomly piled at the bottom.

---

### Edge Cases

- **Empty Note**: The "Drop" button MUST be disabled until the user has entered non-whitespace text.
- **Concurrent Users**: If both "khent" and "clair" drop stars at the same time, both should appear in the real-time stream.
- **Star Limit**: If the jar becomes "too full" (e.g., hundreds of stars), the piling logic should ensure they don't overflow the jar bounds.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a visually appealing "glass jar" container using semi-transparent glassmorphism effects (frosty white/pink).
- **FR-002**: System MUST allow users to enter short text notes via a themed dialog, with submission disabled for empty input.
- **FR-003**: System MUST identify the author of the note based on the `currentUser` state ('khent' or 'clair').
- **FR-004**: System MUST persist notes to a Firestore collection named `starlight_jar`.
- **FR-005**: System MUST render a glowing star icon (star or favorite) for the 100 most recent notes in the database to maintain performance.
- **FR-006**: System MUST animate new stars falling from the top of the screen to the bottom of the jar.
- **FR-007**: System MUST implement a "piling" simulation where stars settle at random bottom positions with varied rotations.
- **FR-008**: System MUST trigger a 1-second shake animation on the jar when tapped.
- **FR-009**: System MUST display a random note in a glowing pink dialog after the shake interaction, with an explicit "Close" button for dismissal.

### Key Entities *(include if feature involves data)*

- **StarNote**: Represents a gratitude note.
    - `id`: String (UUID or Firestore Doc ID).
    - `content`: String (The gratitude message).
    - `author`: String ("khent" or "clair").
    - `timestamp`: DateTime (Creation time).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can complete the "Drop a Star" flow (click button -> type -> submit) in under 15 seconds.
- **SC-002**: The "Drop" animation completes within 2 seconds of submission.
- **SC-003**: The jar shake animation lasts exactly 1 second as specified.
- **SC-004**: The UI remains responsive (60 FPS) while rendering the 100 most recent stars in the jar.

## Assumptions

- **A-001**: The `currentUser` state is already managed globally and accessible as either 'khent' or 'clair'.
- **A-002**: Firebase Firestore is already set up and configured for the project.
- **A-003**: The feature will be placed as a decorative centerpiece on the main dashboard, adjacent to the Daily Bloom widget.
- **A-004**: Visual assets like star icons are available via Flutter's `Icons` or custom svg.
