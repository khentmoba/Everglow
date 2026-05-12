# Feature Specification: Everglow Canvas

**Feature Branch**: `012-everglow-canvas`  
**Created**: 2026-05-11  
**Status**: Draft  
**Input**: User description: "Build the Everglow Canvas feature for my Flutter web app, Everglow. This feature is a shared, real-time digital whiteboard where we can leave cute doodles and handwritten notes for each other using Firebase Cloud Firestore."

## Clarifications

### Session 2026-05-11
- Q: Is the canvas restricted to specific users? → A: Private: Restricted to 'clair' and 'khent' only.
- Q: How should strokes be ordered when rendered? → A: Temporal: Newest strokes on top.
- Q: Should the drawing paths be simplified? → A: Optimized: Apply basic path simplification.
- Q: Is undo/redo functionality required? → A: Local: Undo/Redo for the current user's own strokes.
- Q: How should coordinates be stored? → A: Normalized: Store points as ratios (0.0 to 1.0).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Real-Time Collaborative Drawing (Priority: P1)

As a user, I want to draw freehand on a shared canvas and see my partner's doodles appearing in real-time, so that we can communicate creatively and leave sweet notes for each other.

**Why this priority**: This is the core functionality of the feature. Without real-time sync, it's just a local drawing app, not a "shared digital whiteboard."

**Independent Test**: Can be tested by opening the app in two separate browser windows, drawing in one, and verifying the stroke appears in the other automatically.

**Acceptance Scenarios**:

1. **Given** the Canvas screen is open, **When** I drag my mouse/finger across the screen, **Then** a continuous line should be rendered following my path.
2. **Given** I have finished a stroke, **When** I release the mouse/finger, **Then** the stroke should be persisted and become visible to other users.
3. **Given** another user is drawing, **When** they finish a stroke, **Then** it should appear on my canvas without me needing to refresh.

---

### User Story 2 - Cute Creative Toolbar (Priority: P2)

As a user, I want to choose between different pastel colors and switch between a pen and an eraser, so that I can make my doodles look cute and fix any mistakes.

**Why this priority**: Enhances the "cute" aesthetic and provides essential editing capabilities.

**Independent Test**: Can be tested by selecting different colors and the eraser from the toolbar and verifying the drawing behavior changes accordingly.

**Acceptance Scenarios**:

1. **Given** the toolbar is visible, **When** I select a color from the palette, **Then** subsequent strokes should be drawn in that color.
2. **Given** I have selected the Eraser tool, **When** I draw, **Then** it should remove or mask existing strokes (or draw in the background color).
3. **Given** the toolbar is pill-shaped at the bottom, **When** I interact with it, **Then** it should provide visual feedback (e.g., highlighting the active tool).

---

### User Story 3 - Canvas Reset (Priority: P3)

As a user, I want to be able to clear the entire canvas when it gets too crowded, so that we can start fresh with new doodles.

**Why this priority**: Necessary for long-term usability to prevent the canvas from becoming a cluttered mess.

**Independent Test**: Can be tested by clicking the "Clear Canvas" button and confirming the deletion.

**Acceptance Scenarios**:

1. **Given** the canvas has drawings on it, **When** I click the "Clear Canvas" button, **Then** a confirmation dialog should appear.
2. **Given** the confirmation dialog is open, **When** I confirm the action, **Then** all strokes should be deleted from the canvas and Firestore for all users.
3. **Given** the confirmation dialog is open, **When** I cancel the action, **Then** no drawings should be deleted.

### Edge Cases

- **Connectivity Loss**: How does the system handle strokes drawn while offline? (Assumption: Local drawing works, but sync fails until reconnected).
- **Stroke Complexity**: What happens if a user tries to draw an extremely long stroke with thousands of points? (Assumption: We might need to simplify points or limit stroke length to prevent Firestore document size limits).
- **Concurrent Deletion**: What happens if two users try to clear the canvas at the exact same time?

## Requirements *(mandatory)*

### Functional Requirements

- FR-001: System MUST provide a full-screen shared drawing area with a soft, light pink background.
- FR-002: System MUST persist each continuous drawing stroke as a standalone unit of data to ensure real-time synchronization.
- FR-003: System MUST listen to real-time updates to render strokes from other users as they are completed.
- FR-004: System MUST track all stroke metadata including a unique identifier, the coordinate path, color selection, and line thickness.
- FR-005: System MUST provide a floating, pill-shaped toolbar at the bottom with glassmorphism effects (high border radius: 32.0).
- FR-006: System MUST include a Pen vs. Eraser toggle in the toolbar. The Eraser MUST permanently remove existing strokes from the shared canvas when they are touched or intersected.
- FR-007: System MUST include a palette of at least 4-5 pastel colors (e.g., pink, blue, yellow, green).
- FR-008: System MUST include a 'Clear Canvas' button with a confirmation dialog that clears the canvas for all users.
- FR-009: System MUST add a navigation button (brush/palette icon) to the Main Dashboard with a smooth transition.
- FR-010: System MUST restrict canvas access and drawing capabilities to 'clair' and 'khent' personas.
- FR-011: System MUST render strokes in ascending order of their creation timestamp to ensure newest drawings appear on top.
- FR-012: System MUST apply path simplification to drawing strokes before persistence to optimize document size and rendering performance.
- FR-013: System SHOULD provide local Undo/Redo functionality for the current user's strokes within the active session.
- FR-014: System MUST use a normalized coordinate system (0.0 to 1.0) for stroke points to ensure consistent rendering across different screen sizes and ratios.

### Key Entities

- **Stroke**: Represents a single continuous line. 
  - `id`: Unique identifier.
  - `points`: The sequence of normalized coordinate points (0.0 to 1.0) defining the path.
  - `color`: The visual color of the stroke.
  - `strokeWidth`: The thickness of the line.
  - `createdAt`: Timestamp of when the stroke was completed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- SC-001: Drawing strokes appear on other users' screens within 500ms of the sender completing the stroke.
- SC-002: The Canvas screen becomes interactive and starts receiving shared data in under 800ms.
- SC-003: The UI maintains a smooth rendering experience (no visible lag) while drawing, even with 50+ strokes on screen.
- SC-004: Users report the interface feels "extremely cute" and consistent with the Everglow theme.

## Assumptions

- **Connectivity**: Users are connected to the internet; offline support is limited to local drawing buffer.
- **Identity**: The system can differentiate between users to facilitate shared drawing.
- **Scale**: The canvas is designed for personal use between a small group of users, not massive public collaboration.
- **Stroke Storage**: Each stroke is saved as a single entity to optimize data usage and synchronization frequency.
