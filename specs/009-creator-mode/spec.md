# Feature Specification: Creator Mode Admin Panel

**Feature Branch**: `009-creator-mode`  
**Created**: 2026-05-11  
**Status**: Draft  
**Input**: User description: "Build a hidden Creator Mode (Admin Panel) for my Flutter web app, Everglow. This feature allows me to add new timeline memories or secret letters directly from the app, but it must only be visible when I am logged in with my passcode."

## Clarifications

### Session 2026-05-11
- Q: Submission Feedback Strategy → A: Option B - Reliable (Show loading indicator on button, wait for Firestore success, then close and show SnackBar).
- Q: Image Input Method → A: Option B - Image Picker (Button to select a file from device and upload to Firebase Storage).
- Q: Form Scrolling & UX → A: Option A - Scrollable (Wrap forms in SingleChildScrollView for mobile accessibility).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Secure Access to Creator Mode (Priority: P1)

As Khent (Admin), I want a discrete way to access the Creator Panel so that I can manage app content without cluttering the UI for other users.

**Why this priority**: Core security and visibility requirement. The feature must be hidden from non-admin users.

**Independent Test**: Log in as 'clair' (passcode '1111') and verify the admin button is absent. Log in as 'khent' (passcode '2222') and verify the button is present.

**Acceptance Scenarios**:

1. **Given** I am logged in as 'clair', **When** I view the Main Dashboard, **Then** I should not see any admin icon or FloatingActionButton.
2. **Given** I am logged in as 'khent', **When** I view the Main Dashboard, **Then** I should see a discrete icon/button that opens the Creator Panel.

---

### User Story 2 - Adding a Relationship Memory (Priority: P2)

As Khent, I want to add new memories to the Living Archive timeline directly from the app so that I can easily record special moments.

**Why this priority**: Primary functional requirement for content management.

**Independent Test**: Open Creator Panel, select "Add Memory", fill all fields, and submit. Verify the memory appears in the Timeline.

**Acceptance Scenarios**:

1. **Given** the Creator Panel is open, **When** I select "Add Memory", **Then** I should see fields for title, description, image URL, and a date picker.
2. **Given** the "Add Memory" form is filled, **When** I tap submit, **Then** the data should be saved to Firestore, a success SnackBar should appear, and the modal should close.

---

### User Story 3 - Dropping a Secret Letter (Priority: P2)

As Khent, I want to drop secret letters into the Letterbox with a future unlock date so that I can surprise Clair with timed notes.

**Why this priority**: Secondary functional requirement for content management.

**Independent Test**: Open Creator Panel, select "Drop a Letter", fill all fields, and submit. Verify the letter appears in the Letterbox.

**Acceptance Scenarios**:

1. **Given** the Creator Panel is open, **When** I select "Drop a Letter", **Then** I should see fields for title, content, and an unlock date picker (defaulted to tomorrow).
2. **Given** the "Drop a Letter" form is filled, **When** I tap submit, **Then** the data should be saved to Firestore and the form should clear.

---

### Edge Cases

- **Empty Submission**: What happens when Khent taps submit with empty fields? (System MUST prevent submission and show validation error).
- **Invalid Image URL**: How does the system handle a malformed URL for memory images? (System should handle it gracefully, possibly with a placeholder or just saving the string as-is for Firestore).
- **Offline Mode**: What happens if the network is down during submission? (Firestore handles offline persistence, but UI should ideally indicate pending status if possible, though not strictly requested).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST render a discrete FloatingActionButton or Icon Button on the Main Dashboard ONLY if `currentUser == 'khent'`.
- **FR-002**: System MUST use `showModalBottomSheet` with rounded top corners (32.0) and a soft pink background for the Creator Panel.
- **FR-003**: Creator Panel MUST include a segmented control or TabBar to switch between "Add Memory" and "Drop a Letter" forms.
- **FR-004**: "Add Memory" form MUST include inputs for title (String), description (Multi-line String), and a button to pick/upload an image (Optional).
- **FR-012**: System MUST upload picked images to Firebase Storage and retrieve a download URL to store in the `Milestone` object before saving to Firestore.
- **FR-005**: "Drop a Letter" form MUST include inputs for title (String), content (Multi-line String), and a DatePicker for unlockDate.
- **FR-006**: System MUST persist new memories as `Milestone` objects in the `milestones` Firestore collection.
- **FR-007**: System MUST persist new letters as `HiddenNote` objects in the `notes` Firestore collection.
- **FR-008**: System MUST show a success SnackBar (e.g., 'Memory saved to Everglow! ✨') upon successful Firestore push.
- **FR-009**: System MUST clear form fields and close the bottom sheet automatically after a successful submission.
- **FR-010**: System MUST validate that mandatory fields (title, description/content) are not empty before allowing submission.
- **FR-011**: System MUST show a loading indicator (e.g., CircularProgressIndicator) on the submit button while the Firestore write is in progress and disable the button to prevent duplicate submissions.
- **FR-013**: System MUST wrap form content in a `SingleChildScrollView` within the modal to ensure all inputs remain accessible when the keyboard is visible.

### Key Entities *(include if feature involves data)*

- **Milestone**: Represents a timeline memory. Attributes: `title`, `description`, `imageUrl`, `date`.
- **HiddenNote**: Represents a time-locked letter. Attributes: `title`, `content`, `unlockDate`, `isRead` (default false), `isOpened` (default false).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Admin access button is 100% invisible to users logged in as 'clair'.
- **SC-002**: New memories/letters are successfully persisted to Firestore and reflected in the UI via existing streams.
- **SC-003**: Form submission to modal closure takes less than 2 seconds (assuming standard network conditions).
- **SC-004**: Visual design matches the 'pinkish and very cute' Everglow theme (verified by UI review).

## Assumptions

- **Existing State**: Assumes `authService.currentUser` correctly identifies 'khent' vs 'clair' based on existing passcode logic.
- **Existing Models**: Assumes `Milestone` and `HiddenNote` models/services are available for extension or direct use.
- **Firebase Auth**: Assumes the app is already connected to Firebase and has appropriate write permissions for the 'khent' user profile (or general write access for now).
- **Modularity**: Assumes `CreatorModal` will be implemented as a separate widget file to maintain dashboard cleanliness.
