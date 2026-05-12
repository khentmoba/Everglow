# Data Model: Everglow Academy

## Entities

### AcademyQuestion (Collection: `academy_questions`)
Represents a single quiz item.

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique identifier |
| `questionText` | String | The text of the question |
| `options` | List<String> | 4 possible answers |
| `correctOptionIndex` | int | Index of the correct answer (0-3) |
| `category` | String | 'engineering' or 'tourism' |

### GameMatch (Collection: `active_matches`)
Represents a real-time multiplayer session.

| Field | Type | Description |
|-------|------|-------------|
| `matchId` | String | Firestore document ID |
| `hostId` | String | User ID of the creator |
| `participantId` | String | User ID of the joiner (null if waiting) |
| `khentScore` | int | Current score for Khent |
| `clairScore` | int | Current score for Clair |
| `status` | String | 'waiting', 'active', 'finished' |
| `currentQuestionId` | String | ID of the current question being shown |
| `questionIndex` | int | Sequence number (0-9) |
| `category` | String | The selected category for the match |
| `createdAt` | Timestamp | For stale match cleanup |
| `winnerId` | String | Set upon transition to 'finished' |

### UserProfile (Collection: `users` - Update)
Update existing user profile to track points.

| Field | Type | Description |
|-------|------|-------------|
| `studyPoints` | int | Cumulative points earned in Academy |

## State Transitions (1v1)

1. **Waiting**: Match created by Player A. `status: 'waiting'`, `hostId: 'A'`.
2. **Joining**: Player B joins. `runTransaction` updates `participantId: 'B'`, `status: 'active'`.
3. **Active**: Players answer questions. Transactional updates increment scores and `questionIndex`.
4. **Finished**: `questionIndex` reaches 10. `status: 'finished'`, `winnerId` calculated.
