# Feature Specification: Everglow Academy OpenTDB Integration

**Feature Branch**: `016-academy-opentdb-integration`  
**Created**: 2026-05-11  
**Status**: Draft  
**Input**: User description: "Upgrade the Everglow Academy feature in my Flutter/Firestore web app to automatically fetch infinite questions using the free Open Trivia Database (OpenTDB) API. The implementation must include strict Session Token management to prevent duplicate questions and proper text decoding. ..."

## Clarifications

### Session 2026-05-11

- Q: How should we ensure uniqueness for questions stored in the Firestore `AcademyQuestion` collection? → A: Use a hash of the question text as the Firestore Document ID to naturally prevent duplicates.
- Q: How should the `TriviaApiService` handle the OpenTDB rate limit (1 request per 5 seconds)? → A: Implement an automatic retry with exponential backoff if the API returns a rate-limit error.
- Q: Where should the session token be stored, and should it persist across app restarts? → A: Store in `SharedPreferences` to persist across app restarts (up to the 6-hour expiration).
- Q: How should the system coordinate the background fetch during a 1v1 match to prevent redundant API calls? → A: ONLY the host can trigger the auto-fill background fetch; the guest simply waits for the database to update.
- Q: How should we handle question difficulty during the auto-fill fetch? → A: Fetch all difficulties (mix) to provide a balanced challenge.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Seamless Question Replenishment (Priority: P1)

As a student in Everglow Academy, I want the system to automatically fetch new trivia questions when the database is low, so that I can study indefinitely without interruption.

**Why this priority**: Core value proposition of the upgrade - infinite, automated learning content.

**Independent Test**: Manually delete questions from Firestore until < 10 remain for a category, then click 'Solo Study' and verify the background fetch triggers and populates 50 new questions.

**Acceptance Scenarios**:

1. **Given** a category has 8 unanswered questions in Firestore, **When** I click 'Solo Study', **Then** I see a cute loading animation saying 'Downloading new study materials... 📚' while 50 new questions are fetched and saved.
2. **Given** 50 questions are being fetched, **When** the process completes, **Then** the loading animation disappears and I can start my study session.

---

### User Story 2 - High-Fidelity Trivia Experience (Priority: P2)

As a user, I want the trivia questions to be perfectly formatted (no HTML entities) and categorized correctly according to the Everglow theme, so that the experience feels premium and "cute".

**Why this priority**: Essential for maintaining the "Digital Sanctuary" aesthetic and readability.

**Independent Test**: Inspect Firestore documents for 'Engineering' and 'Tourism' categories to ensure text is decoded (e.g., " instead of &quot;) and options are shuffled.

**Acceptance Scenarios**:

1. **Given** the API returns a question with "&quot;", **When** it is saved to Firestore, **Then** it is stored as "\"".
2. **Given** an OpenTDB question is from category 18 (Computers), **When** it is mapped, **Then** it appears under the 'Engineering' category in Everglow.

---

### User Story 3 - Synchronized 1v1 Challenges (Priority: P3)

As a challenger, I want my 1v1 match to be perfectly synced with my partner, including any newly fetched questions, so that we both compete on the exact same content.

**Why this priority**: Critical for fair and functional multiplayer gameplay.

**Independent Test**: Start a 1v1 match where the database is low, verify the host triggers the fetch, and both players receive the same first question from the newly fetched batch.

**Acceptance Scenarios**:

1. **Given** a 1v1 match starts and questions are low, **When** the host triggers the API call, **Then** both players wait for the sync before the match begins.

### Edge Cases

- **Token Exhaustion**: System handles "Token Empty" (Response Code 4) by automatically resetting the token and retrying the fetch.
- **Rate Limiting**: System handles API Rate Limit errors (Response Code 5) by automatically retrying with exponential backoff.
- **Network Failure**: System provides a user-friendly error dialog in the Everglow theme if the API is unreachable.
- **No Questions Available**: System gracefully handles scenarios where a category might truly have no more questions even after a reset (highly unlikely with OpenTDB).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST implement a `TriviaApiService` with session token management (request, store in `SharedPreferences`, reset).
- **FR-002**: System MUST use the `html_unescape` package to decode all question and answer strings before Firestore ingestion.
- **FR-003**: System MUST map OpenTDB categories 18 (Computers) and 19 (Math) to the internal 'Engineering' category.
- **FR-004**: System MUST map OpenTDB categories 22 (Geography) and 23 (History) to the internal 'Tourism' category.
- **FR-005**: System MUST combine the correct answer and incorrect answers into a shuffled `options` list for the `GameQuestion` model.
- **FR-006**: System MUST trigger a background fetch of 50 questions when Firestore contains fewer than 10 unanswered questions for a selected category.
- **FR-007**: System MUST use a hash of the question text as the Firestore Document ID to prevent duplicate question entries.
- **FR-008**: System MUST display a cute loading animation ("spinning gear" or "bouncing globe") with the text "Downloading new study materials... 📚" during replenishment.
- **FR-009**: System MUST ensure ONLY the host in 1v1 mode triggers the auto-fill fetch; the guest MUST wait for the synced Firestore update.

### Key Entities *(include if feature involves data)*

- **TriviaApiService**: Handles communication with OpenTDB, session lifecycle, and error handling.
- **GameQuestion**: Existing data model to be populated with decoded and mapped OpenTDB data.
- **AcademyQuestion Collection**: Firestore collection storing the pool of questions for different categories.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of fetched questions have HTML entities successfully decoded before display.
- **SC-002**: Question pool replenishment occurs silently and automatically with zero user intervention required beyond the initial loading state.
- **SC-003**: 100% of 1v1 matches use synchronized question sets, even when the pool is replenished at the start of the match.
- **SC-004**: API Token exhaustion is handled automatically in under 5 seconds (reset + retry).

## Assumptions

- **OpenTDB Availability**: The free Open Trivia Database API remains accessible and follows its documented response codes.
- **html_unescape**: The package is compatible with the current Flutter version.
- **Category IDs**: OpenTDB category IDs (18, 19, 22, 23) remain stable.
- **Difficulty**: All difficulty levels (easy, medium, hard) will be fetched and mixed to provide a balanced experience.
- **Existing Model**: The existing `GameQuestion` model is flexible enough to accommodate the OpenTDB fields.
