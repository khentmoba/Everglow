# Feature Specification: Everglow Academy

**Feature Branch**: `015-everglow-academy`  
**Created**: 2026-05-11  
**Status**: Draft  
**Input**: User description: "Build the Everglow Academy feature for my Flutter web app, Everglow. This feature must be integrated directly into the main dashboard's scrollable layout as a massive 'Portal' card, and include a fully functional real-time 1v1 game mode using Firebase Firestore. Directives for Implementation: [Details omitted for brevity]"

## Clarifications

### Session 2026-05-11

- Q: How should Study Points be awarded (real-time vs end of match)? → A: Awarded once at the end based on total score.
- Q: How should abandoned or stale matches be handled? → A: Auto-cleanup after 30 minutes.
- Q: How long should the matchmaking timeout be? → A: 60 seconds with "Play Solo" prompt.
- Q: How many bonus Study Points does the winner get? → A: Fixed bonus (50 points).
- Q: How should ties be handled in 1v1? → A: Draw screen (both get 25 bonus pts).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Entering the Academy (Priority: P1)

As a user (Khent or Clair), I want to see a prominent entrance to the Academy on my dashboard and transition into it smoothly so that I feel immersed in the learning experience.

**Why this priority**: Essential for feature discovery and maintaining the "Digital Sanctuary" aesthetic.

**Independent Test**: Can be fully tested by scrolling the dashboard, locating the Academy Portal card, and tapping "Enter Academy" to reach the Academy Hub.

**Acceptance Scenarios**:

1. **Given** I am on the main dashboard, **When** I scroll down, **Then** I see a large card with a pink diagonal split design (Engineering icons on left, Tourism on right).
2. **Given** the Academy Portal card is visible, **When** I tap the "Enter Academy" button, **Then** it performs a bouncy animation and transitions to the Academy Hub with a smooth fade/slide effect.

---

### User Story 2 - Solo Study Mode (Priority: P2)

As a student of the Academy, I want to practice my knowledge individually so that I can earn Study Points and improve my skills at my own pace.

**Why this priority**: Provides core value even when the partner is unavailable.

**Independent Test**: Can be tested by starting Solo Mode, answering 10 questions, and verifying that Study Points are updated in the profile.

**Acceptance Scenarios**:

1. **Given** I am in the Academy Hub, **When** I select "Solo Study", **Then** I am prompted to choose a category (Engineering or Tourism).
2. **Given** a category is selected, **When** the game starts, **Then** the system fetches 10 random questions from that category in the academy collection.
3. **Given** I complete all 10 questions, **When** the session ends, **Then** my "Study Points" in Firestore are incremented by the points earned.

---

### User Story 3 - 1v1 Challenge (Priority: P1)

As a competitive partner, I want to challenge my partner to a real-time 1v1 match so that we can have fun competing and see who knows more.

**Why this priority**: The central "Multiplayer Engine" feature that drives engagement.

**Independent Test**: Requires two active sessions. Can be tested by having both Khent and Clair join the challenge and completing a match.

**Acceptance Scenarios**:

1. **Given** I select "1v1 Challenge" and no match is available, **When** I tap it, **Then** I see a "Waiting for Partner..." screen while a match document is created with status 'waiting'.
2. **Given** I am on the "Waiting for Partner..." screen, **When** 60 seconds pass without a partner joining, **Then** I am prompted with a "Play Solo instead?" option.
3. **Given** a match document exists in 'waiting' status, **When** my partner taps "1v1 Challenge", **Then** both of us are transitioned to the game board simultaneously and the status becomes 'active'.
3. **Given** a question is displayed on the game board, **When** I tap the correct answer before my partner, **Then** I get a point, and the question advances for both of us instantly.
4. **Given** I tap a wrong answer, **When** I do so, **Then** my input is locked for 2 seconds while my partner can still answer.

---

### User Story 4 - Victory Celebration (Priority: P3)

As the winner of a 1v1 match, I want to be celebrated on a podium with my partner so that our competitive efforts feel rewarded.

**Why this priority**: Enhances emotional resonance and closure for the multiplayer experience.

**Independent Test**: Can be tested by finishing a 1v1 match and verifying the Podium screen appears.

**Acceptance Scenarios**:

1. **Given** the final question of a 1v1 match is answered and one player has more points, **When** the game concludes, **Then** a Podium screen appears declaring that player the winner.
2. **Given** the final question is answered and scores are equal, **When** the game concludes, **Then** a "Draw" screen appears celebrating both players.
3. **Given** the Podium or Draw screen is active, **When** it loads, **Then** pink confetti animations play and bonus Study Points are awarded (50 for winner, 25 each for draw).

### Edge Cases

- **What happens if a match is abandoned before completion?**
  - Stale matches (no activity for 30 minutes) are automatically cleaned up from the `active_matches` collection to maintain system health.
- **What happens when the partner disconnects during a 1v1 match?**
  - The match should detect the lack of updates or a heartbeat and allow the remaining player to either finish solo or return to the hub with a "Partner disconnected" notification.
- **How does the system handle simultaneous taps on the correct answer?**
  - Firestore transactions or server-side logic (if available) should ensure only one player is awarded the point for that specific question ID.
- **What happens if no questions are available in the collection?**
  - The system should display a friendly "Academy is under construction" message or use a fallback set of static questions.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a large `AcademyPortalCard` in the dashboard with a diagonal split aesthetic and theme-consistent icons.
- **FR-002**: System MUST transition from the dashboard to `AcademyHub` using a custom `PageRouteBuilder` with fade/slide animations.
- **FR-003**: System MUST support a "Solo Study" loop that retrieves 10 random questions and updates user "Study Points" in Firestore.
- **FR-004**: System MUST implement a real-time matchmaking system using an `active_matches` Firestore collection with 'waiting', 'active', and 'finished' states.
- **FR-005**: System MUST synchronize the game state (current question, scores) across both players' screens using a Firestore `StreamBuilder`.
- **FR-006**: System MUST enforce a "First-to-Answer" point system for 1v1 matches, where the first correct tap advances the question for both.
- **FR-007**: System MUST implement a 2-second input lockout for players who select an incorrect answer in 1v1 mode.
- **FR-008**: System MUST display a "Podium" screen with winner declaration and confetti animations upon 1v1 match completion.
- **FR-009**: System MUST ensure all UI elements (cards, buttons, trackers) follow the "pinkish and very cute" Everglow theme with high border radiuses and soft shadows.
- **FR-010**: System MUST handle 1v1 match length of 10 questions.
- **FR-011**: System MUST allow users to select a question category (Engineering or Tourism) before starting Solo or 1v1 modes.

### Key Entities *(include if feature involves data)*

- **GameMatch**: Represents a multiplayer session.
  - Attributes: `matchId`, `khentScore`, `clairScore`, `status` (waiting/active/finished), `currentQuestionId`.
- **AcademyQuestion**: Represents a study item.
  - Attributes: `id`, `questionText`, `options` (List), `correctOptionIndex`, `category` (Engineering/Tourism).
- **StudyPoints**: A user-specific metric persisted in their profile.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can transition from the dashboard to the Academy Hub in under 500ms (animation duration notwithstanding).
- **SC-002**: 1v1 Matchmaking connects two waiting players and starts the game within 2 seconds of the second player joining.
- **SC-003**: Question sync latency between players in a 1v1 match is under 300ms on a stable connection.
- **SC-004**: 100% of completed matches correctly award Study Points to the participating users' profiles.

## Assumptions

- Users (Khent and Clair) have stable internet connectivity for real-time Firestore sync.
- The `academy_questions` collection will be pre-populated with enough variety for both Engineering and Tourism categories.
- The app's existing authentication context provides the necessary user IDs (Khent/Clair) for matchmaking and score tracking.
- Mobile responsiveness is required for the dashboard card and all Academy screens, keeping within the 500px max-width established for the project.
