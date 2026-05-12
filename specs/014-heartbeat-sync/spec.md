# Feature Specification: Heartbeat Sync

**Feature Branch**: `014-heartbeat-sync`  
**Created**: 2026-05-11  
**Status**: Draft  
**Input**: User description: "Build the Heartbeat Sync feature for my Flutter web app, Everglow. This feature allows Khent and Clair Jassen to share their daily emotional status through a cute, interactive mood check-in."

## Clarifications

### Session 2026-05-11
- Q: How to access check-in if skipped? → A: A small heart icon or "Check-in" button on the dashboard.
- Q: Guardian mention frequency? → A: Occasionally (every 5-10 messages).
- Q: Mood privacy? → A: No, all mood check-ins are shared automatically (Sync).
- Q: Offline handling? → A: Cache the entry locally and sync to Firestore when a connection is restored.
- Q: Mood history visibility? → A: No, only show the most recent "Current Status".


## User Scenarios & Testing *(mandatory)*

### User Story 1 - Daily Mood Check-In (Priority: P1)

When the user (Khent or Clair) enters the app for the first time each day, they are greeted by the Everglow Guardian who asks how they are feeling. The user can quickly select a heart emoji that matches their current mood.

**Why this priority**: Core functionality of the feature. Without the check-in, there is no data to sync.

**Independent Test**: Can be fully tested by logging in as '1111' or '2222', ensuring the Guardian prompts for mood if not already submitted today, and verifying the selection is saved.

**Acceptance Scenarios**:

1. **Given** a user has not submitted a mood today, **When** they log in, **Then** the Guardian appears with a thought bubble asking "How is your heart today, [Name]?"
2. **Given** the mood prompt is visible, **When** the user selects a heart emoji, **Then** a sweet confirmation message "Sending your love to [Partner Name]..." is displayed and the prompt disappears.
3. **Given** a user has already submitted a mood today, **When** they log in, **Then** the Guardian does not prompt for a mood check-in.

---

### User Story 2 - Partner Mood Visibility (Priority: P1)

The user can see their partner's current emotional status at a glance on the main dashboard, allowing them to feel connected and responsive to their partner's needs.

**Why this priority**: This is the "Sync" part of Heartbeat Sync, providing the emotional connection value.

**Independent Test**: Can be tested by having one user submit a mood and verifying that the other user sees the correct status indicator on their dashboard.

**Acceptance Scenarios**:

1. **Given** Clair has submitted a "Amazing" mood (Score 5), **When** Khent views the dashboard, **Then** he sees a vibrant, sparkling pink heart indicator near Clair's name.
2. **Given** Clair has submitted a "Stressed" mood (Score 1 or 2), **When** Khent views the dashboard, **Then** he sees a tiny, pulsing soft blue heart indicator.

---

### User Story 3 - Guardian Mood Awareness (Priority: P2)

The Everglow Guardian acts as a gentle messenger, occasionally mentioning the partner's mood to the user through its thought bubbles.

**Why this priority**: Enhances the "cute" and "interactive" nature of the feature, making the Guardian feel more alive and helpful.

**Independent Test**: Can be tested by submitting a mood for a partner and observing the Guardian's thought bubbles over a period of time.

**Acceptance Scenarios**:

1. **Given** a partner has a mood submitted, **When** the Guardian displays a random message, **Then** it occasionally includes a message like "[Partner Name] is feeling super happy today! 🌸".

---

### Edge Cases

- **No Partner Mood**: If the partner hasn't submitted a mood yet today, the status indicator should be subtle or empty (e.g., a hollow heart) rather than showing a default "neutral" mood.
- **Multiple Entries**: If a user somehow submits multiple moods in a day, the system must only display the most recent one.
- **Timezone Differences**: If the partners are in different timezones, "today" should be relative to the viewing user's perspective or the submitting user's calendar day? (Assumption: Submitting user's calendar day).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST identify if the current user has submitted a mood for the current calendar day upon login.
- **FR-002**: System MUST trigger the Everglow Guardian to prompt for a mood check-in if one is missing for the day.
- **FR-003**: System MUST provide a manual "Check-in" heart icon or button on the dashboard to access the mood picker if the initial prompt is dismissed.
- **FR-004**: System MUST provide a "MoodPicker" widget with 5 heart emoji options representing scores 1 (Raincloud/Blue) to 5 (Sparkling Pink).
- **FR-005**: MoodPicker MUST feature bouncy animations and visual feedback (growth/glow) when a mood is selected.
- **FR-006**: System MUST persist the mood entry (userId, score, emoji, timestamp) to the "moods" collection. All entries are automatically shared with the partner to facilitate the sync.
- **FR-007**: System MUST support offline mood submission by caching entries locally and syncing them once a network connection is available.
- **FR-008**: Dashboard MUST display a partner status indicator near the partner's name or chat icon, showing only the most recent entry.
- **FR-009**: Status indicator MUST change visual style (color/pulsing) based on the most recent mood score.
- **FR-010**: Everglow Guardian MUST include partner mood status in its pool of random thought bubble messages, appearing approximately every 5-10 messages.

### Key Entities *(include if feature involves data)*

- **UserMood**: Represents a single mood check-in.
  - `userId`: String (ID of the user who submitted)
  - `moodScore`: Integer (1-5)
  - `moodEmoji`: String (The emoji character or asset reference)
  - `timestamp`: DateTime (When the mood was submitted)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can complete the mood check-in flow (prompt to selection) in under 10 seconds.
- **SC-002**: Partner mood indicators reflect updates within 5 seconds of a remote submission (real-time sync).
- **SC-003**: 100% of mood submissions are correctly attributed to the logged-in user and current date.

## Assumptions

- "Today" is defined as the current calendar day (midnight to midnight) in the user's local timezone.
- The Everglow Guardian has an existing thought bubble system that can be easily hooked into.
- The app uses Firestore as the primary real-time database.
- Users are authenticated via simple passcodes (1111 for Khent, 2222 for Clair).
