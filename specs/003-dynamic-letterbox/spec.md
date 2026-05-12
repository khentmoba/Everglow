# Feature Specification: Dynamic Letterbox

**Feature Branch**: `[003-dynamic-letterbox]`  
**Created**: 2026-05-08  
**Status**: Draft  
**Input**: User description: "I need you to build a new feature: The Dynamic Letterbox, a system for digital 'envelopes' or notes, some of which are time-locked. Please generate the code for this feature and integrate it directly into my existing dashboard file, placing the new LetterboxView widget exactly below my existing MetricCard (the time counter) inside the layout..."

## Clarifications

### Session 2026-05-08

- Q: Which layout style should the `LetterboxView` use to display the notes? → A: Horizontal scrolling list (carousel style)
- Q: Should the system track and display whether an unlocked note has already been read? → A: Yes, track read state and change visual appearance once read.
- Q: How should the note content dialog handle text that exceeds the screen height? → A: Dialog expands vertically up to a max height, then scrolls.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Viewing the Letterbox List (Priority: P1)

Users view a horizontal scrolling list (carousel style) of digital envelopes below the anniversary metric section on their main dashboard.

**Why this priority**: It establishes the visual presence of the feature, acting as the foundation for both locked and unlocked interactions.

**Independent Test**: Can be tested by rendering the component with dummy data and verifying its placement and visual styling within the global cute theme.

**Acceptance Scenarios**:

1. **Given** the user is on the main dashboard, **When** they look below the metric section, **Then** they see a horizontal list of envelope cards with high border radiuses and soft shadows.
2. **Given** the user views the horizontal list, **When** they see a locked note, **Then** it appears as a sealed envelope with a soft pink container, a lock icon, and a countdown text.
3. **Given** the user views the horizontal list, **When** they see an unread unlocked note, **Then** it looks inviting with a glowing border, lighter pink hue, and a mail or heart icon.
4. **Given** the user views the horizontal list, **When** they see a read unlocked note, **Then** it appears distinct (e.g., dimmed glow, open envelope icon) to indicate it has already been opened.

---

### User Story 2 - Interacting with Unlocked Notes (Priority: P2)

Users can open an unlocked note to read the hidden message inside it, which appears as a cute 'letter' UI.

**Why this priority**: It provides the core value of the feature—actually reading the letters once they are unlocked.

**Independent Test**: Can be tested by tapping an unlocked note and ensuring the dialog with the scale-in animation and handwritten font appears correctly.

**Acceptance Scenarios**:

1. **Given** an unlocked note is displayed, **When** the user taps it, **Then** a smooth scale-in animation triggers, showing a dialog with the note's content.
2. **Given** the note content is shown, **When** the dialog appears, **Then** the content is styled with a handwritten-style font inside a soft-cornered layout.
3. **Given** the note content is longer than the screen height, **When** the dialog opens, **Then** it expands to a maximum height and allows the user to scroll through the text.

---

### User Story 3 - Attempting to Open Locked Notes (Priority: P3)

Users attempting to peek at a locked note are greeted with a playful rejection message rather than the content.

**Why this priority**: Enforces the time-lock constraint playfully without breaking the user experience.

**Independent Test**: Can be tested by tapping a locked note and verifying the correct playful rejection message is displayed without revealing the content.

**Acceptance Scenarios**:

1. **Given** a locked note is displayed, **When** the user taps it, **Then** the note does not open.
2. **Given** a locked note is tapped, **When** the action is rejected, **Then** a playful alert says, 'No peeking! This unlocks on [Date].'

### Edge Cases

- What happens when a user attempts to tap a note exactly at the moment it unlocks?
- How does the horizontal list layout respond to smaller mobile screens or varying text sizes?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a data model for hidden notes containing an identifier, title, hidden content, unlock date and time, and an unlock status.
- **FR-002**: System MUST display a collection of these notes directly below the existing anniversary metric section on the main dashboard layout.
- **FR-003**: System MUST display notes in multiple distinct states: locked (styled as a sealed envelope with countdown), unread unlocked (glowing, inviting), and read unlocked (visually indicating it was opened).
- **FR-004**: System MUST strictly prevent access to note content if the current date and time is before the unlock date.
- **FR-005**: System MUST trigger a playful rejection alert when a user attempts to open a locked note.
- **FR-006**: System MUST reveal note content using a smooth presentation and handwritten-style typography when an unlocked note is opened, allowing vertical scrolling if the content exceeds maximum dialog height.
- **FR-007**: System MUST adhere to the application's global cute design system (rounded corners, soft shadows, pastel color palette).
- **FR-008**: System MUST supply a set of 3-4 placeholder notes (including both locked and unlocked states) for initial demonstration.

### Key Entities

- **HiddenNote**: Represents a digital letter. Contains an identifier, title, content, unlock timestamp, a read status tracking if it was opened, and a derived property indicating whether it is currently unlocked.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The note collection accurately displays all placeholder instances without causing layout errors on standard screen sizes.
- **SC-002**: Opening an unlocked note displays the hidden content instantly with a smooth transition.
- **SC-003**: Attempting to open a locked note displays the rejection message 100% of the time and never reveals the hidden content.
- **SC-004**: The existing dashboard layout remains visually stable and fully functional after the addition of the new note collection.

## Assumptions

- The existing dashboard layout accommodates adding a new section below the metric section without major structural refactoring.
- The global cute theme colors and constants are already accessible within the application context.
- The handwritten font is either already available or can be added without significant performance overhead.
