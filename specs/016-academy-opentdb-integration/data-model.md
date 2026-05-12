# Data Model: Everglow Academy OpenTDB Integration

## Firestore Entities

### Collection: `academy_questions`

Represents the pool of trivia questions fetched from OpenTDB.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | **Primary Key**. SHA-256 hash of the decoded `questionText`. |
| `questionText` | `String` | The trivia question (HTML unescaped). |
| `options` | `List<String>` | Shuffled list of correct and incorrect answers (HTML unescaped). |
| `correctOptionIndex` | `int` | The index of the correct answer within the `options` list. |
| `category` | `String` | Internal category: `engineering` or `tourism`. |
| `difficulty` | `String` | OpenTDB difficulty: `easy`, `medium`, or `hard`. |
| `source` | `String` | Origin of the data (default: `opentdb`). |
| `createdAt` | `Timestamp` | Server timestamp when the question was added. |

## Relationships

- **GameMatch** (Existing): References questions from the `academy_questions` collection by ID.

## State Transitions

### Question Replenishment Flow
1. **Trigger**: Unanswered questions for a category < 10.
2. **Fetch**: `TriviaApiService` requests 50 questions from OpenTDB.
3. **Map**: Results are decoded, categories mapped, and options shuffled.
4. **Persist**: Documents are set in Firestore using `id` (hash) as Doc ID. `set(data, merge: true)` ensures idempotency.
