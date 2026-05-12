# Research Report: Everglow Academy OpenTDB Integration

## Open Trivia Database (OpenTDB) API Analysis

### Response Codes & Handling
- **Code 0 (Success)**: Process results normally.
- **Code 1 (No Results)**: Log warning; if occurring during initial fetch, might indicate API downtime or invalid parameters.
- **Code 2 (Invalid Parameter)**: Validation error in request (should not occur with correct implementation).
- **Code 3 (Token Not Found)**: Session token expired (should fresh request).
- **Code 4 (Token Empty)**: User has answered all questions in the category/query. **Action**: Call `command=reset` and retry.
- **Code 5 (Rate Limit)**: Requests faster than 1 per 5 seconds. **Action**: Implement exponential backoff (e.g., 5s, 10s, 20s).

### Session Tokens
- Tokens are unique strings that prevent receiving the same question twice for 6 hours.
- **Storage**: `SharedPreferences` is sufficient for persistence across app restarts.

## Text Decoding (html_unescape)

- **Library**: `package:html_unescape/html_unescape.dart` (Full version to support HTML5 entities).
- **Strategy**: Instantiate a single `HtmlUnescape` object in the `TriviaApiService`. Perform decoding immediately upon receiving JSON, before mapping to the domain model.

## Duplicate Prevention (Hashing)

- **Algorithm**: SHA-256 (via `package:crypto`).
- **Rationale**: SHA-256 provides high collision resistance compared to MD5.
- **Implementation**: Hash the `question` text (post-decoding) to generate a unique string. Use this string as the Firestore Document ID in the `AcademyQuestion` collection.

## Decisions
- **Decision**: Use SHA-256 for Firestore Document IDs.
- **Rationale**: Guarantees uniqueness across multiple user fetches and sessions without extra database lookups.
- **Decision**: Implement Exponential Backoff for Rate Limiting.
- **Rationale**: Ensures compliance with OpenTDB's 5s IP-based rate limit without crashing or showing errors to the user.
- **Decision**: Store Session Token in `SharedPreferences`.
- **Rationale**: Persists user progress (non-duplication) across app restarts for up to 6 hours.
