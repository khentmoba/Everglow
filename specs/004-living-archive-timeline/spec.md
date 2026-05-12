# Feature Specification: Living Archive Timeline

**Feature Branch**: `004-living-archive-timeline`  
**Created**: 2026-05-08  
**Status**: Draft  
**Input**: User description: "Build the Living Archive feature for this project using Flutter and Firebase. This feature must be a vertical, scrolling timeline that maps out relationship milestones."

## Clarifications

### Session 2026-05-08

- Q: What is the Firestore collection path for milestones? → A: Top-level `milestones/{id}` collection — the app is private to a single couple, so no nesting or per-user scoping is needed.
- Q: What happens when a user taps a milestone card? → A: No tap action — cards are purely display-only. No detail view or in-card expansion is required.
- Q: How should the milestone date be displayed on the card? → A: Human-friendly long format — e.g. `14 February 2024`. Clear, warm, and regionally unambiguous.
- Q: How should milestones be loaded — all at once or paginated? → A: All at once via a single real-time listener. A couple’s archive will realistically remain small; no pagination is needed.
- Q: How should offline behaviour be handled? → A: Passive reliance on Firestore’s default local cache — not a formal tested requirement. If cached data surfaces when offline, that is a bonus, not a commitment.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Chronological Milestone History (Priority: P1)

As a couple using the app, we want to scroll through our shared relationship history presented as a beautiful vertical timeline, so that we can relive and celebrate every meaningful moment we have shared together.

**Why this priority**: This is the core purpose of the Living Archive — without the ability to browse existing milestones in a visually engaging way, the feature has no value. Everything else builds on top of this view.

**Independent Test**: Can be fully tested with seeded Firestore data by navigating to the dashboard and verifying that milestones appear in chronological order in a styled vertical timeline below the letterbox section.

**Acceptance Scenarios**:

1. **Given** there are milestones stored in the shared archive, **When** the user opens the dashboard, **Then** a vertical timeline is rendered below the letterbox, displaying all milestones in oldest-to-newest order.
2. **Given** a milestone has an associated photo, **When** the timeline card is rendered, **Then** the photo is displayed with rounded corners at the top of the card.
3. **Given** a milestone has no associated photo, **When** the timeline card is rendered, **Then** the card displays only the title, date, and description text gracefully without any broken image placeholder.
4. **Given** the timeline is loaded, **When** the user scrolls down, **Then** milestone cards alternate between left and right sides of the central timeline line.

---

### User Story 2 - Real-Time Archive Updates (Priority: P2)

As a couple using the app, we want the timeline to automatically reflect new milestones added by either partner, so that the archive always feels alive and current without needing to manually refresh.

**Why this priority**: The app is designed as a living, shared space. Real-time sync ensures both partners always see the same, up-to-date history, which is a key differentiator from a static photo album.

**Independent Test**: Can be tested by adding a new milestone document to Firestore from outside the app and observing that it appears in the timeline within a few seconds without any user interaction.

**Acceptance Scenarios**:

1. **Given** the dashboard is open and displaying the timeline, **When** a new milestone is added to the shared archive, **Then** it appears in its correct chronological position in the timeline without requiring a page reload.
2. **Given** the timeline is displaying milestones, **When** an existing milestone's details are updated, **Then** the corresponding card reflects the updated information automatically.

---

### User Story 3 - Empty State Experience (Priority: P3)

As a new couple setting up the app, we want to see a welcoming, non-empty-looking screen even when no milestones have been recorded yet, so that the dashboard feels warm and inviting rather than broken.

**Why this priority**: First-run experience significantly impacts user retention. A graceful empty state prevents the app from feeling incomplete during the initial setup phase.

**Independent Test**: Can be tested on a fresh Firestore collection with zero documents in the milestones subcollection by verifying that the timeline area displays a gentle, on-brand empty state prompt.

**Acceptance Scenarios**:

1. **Given** the milestones archive is empty, **When** the timeline section renders, **Then** a soft, on-brand empty state is displayed inviting the couple to add their first milestone.
2. **Given** an error occurs fetching milestone data, **When** the timeline section renders, **Then** a friendly error message is shown without crashing the dashboard.

---

### Edge Cases

- What happens when a milestone has a very long description? The card must expand gracefully without overflowing the timeline layout.
- What happens when an image URL is invalid or the image fails to load? The card must fall back to displaying text-only gracefully, as if no image was provided.
- What happens when the archive contains a very large number of milestones (50+)? The list must scroll fluidly without performance degradation.
- What happens when the internet connection is lost mid-session? Firestore’s default local cache may surface the last known milestone list automatically. This is a passive benefit — it is not a formally tested requirement and explicit offline persistence configuration is out of scope.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST display all relationship milestones from the shared archive in a vertically scrolling timeline, ordered from the oldest date to the newest.
- **FR-002**: The system MUST listen to the entire milestones collection in real time via a single persistent listener, automatically reflecting any additions or modifications without requiring a manual page refresh. No pagination or lazy loading is required.
- **FR-003**: Each milestone entry MUST display a title, date, and description at minimum. The date MUST be rendered in human-friendly long format (e.g. `14 February 2024`).
- **FR-004**: If a milestone has an associated image, the system MUST render that image with rounded corners at the top of its card.
- **FR-005**: If a milestone has no associated image, the system MUST render the card in a gracefully adjusted, text-only layout without any broken image indicators.
- **FR-006**: Milestone cards MUST alternate between the left and right sides of the central timeline axis.
- **FR-007**: The central timeline axis MUST be visually styled with a soft pink gradient and heart-shaped node markers at each milestone point.
- **FR-008**: The timeline section MUST be positioned within the main dashboard's scrollable area, directly below the Letterbox section.
- **FR-009**: The system MUST display a welcoming empty state when the milestones archive contains zero entries.
- **FR-010**: The system MUST display a non-crashing, user-friendly error state if the archive data cannot be retrieved.
- **FR-011**: All milestone cards MUST use a soft pink background, high border radius, and subtle drop shadows consistent with the established design system.
- **FR-012**: Milestone cards MUST be non-interactive — no tap, press, or expand gesture is registered. The timeline is a display-only view.

### Key Entities

- **Milestone**: Represents a single relationship memory or life event. Key attributes: a unique identifier, a title, a description, a date (stored as a Firestore Timestamp, displayed as `DD Month YYYY` e.g. `14 February 2024`), and an optional image reference. Milestones are stored in the top-level Firestore collection `milestones` (path: `milestones/{id}`) and retrieved in chronological order by date. No per-user or per-couple scoping is applied — all documents in the collection belong to the single couple using the app.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All milestones appear in the correct chronological order (oldest first) on every load, with zero ordering errors across 100 test cases.
- **SC-002**: The timeline reflects a newly added milestone within 5 seconds of it being saved to the archive, with no manual refresh required.
- **SC-003**: Cards with images and cards without images both render correctly in 100% of test cases — no broken layouts or image placeholder artifacts.
- **SC-004**: The timeline scrolls at 60 frames per second with no dropped frames when the full collection is loaded at once (expected: up to ~100 milestones) on a mid-range device. No pagination or "load more" interaction is required.
- **SC-005**: The dashboard remains stable (zero crashes) when the milestones archive is empty or when a data-fetch error occurs.
- **SC-006**: The feature integrates into the dashboard without breaking any existing component (letterbox, anniversary counter, gateway transition).

## Assumptions

- Milestones are stored in a top-level Firestore collection (`milestones/{id}`). No per-user or per-couple document scoping is applied. The app is exclusively private to a single couple — there is no multi-tenant requirement and no risk of data bleed between relationships.
- The existing global design system (soft pink color palette, typography, border-radius tokens) is already established and accessible to new components.
- The Letterbox section is already rendered in the dashboard scroll area and serves as the visual anchor point above the timeline.
- Image hosting is handled externally (e.g., Firebase Storage) and the milestone record only stores a URL; image upload functionality is out of scope for this feature.
- The milestone editing and creation UI (adding new milestones) is out of scope for this feature; the timeline is read-only for now.
- The app targets a single couple (two users) and does not need multi-tenant or access-control logic for the milestones collection.
