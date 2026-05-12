# Service Contract: TriviaApiService

## Overview
The `TriviaApiService` is responsible for all interactions with the Open Trivia Database (OpenTDB) API, including session management and data normalization.

## Interface

### `initSession()`
- **Purpose**: Requests a new session token from OpenTDB if one doesn't exist in `SharedPreferences`.
- **Side Effects**: Updates `SharedPreferences` with the new token.

### `fetchQuestions({required int categoryId, int amount = 50})`
- **Purpose**: Fetches a list of multiple-choice questions for the given category.
- **Parameters**:
  - `categoryId`: The OpenTDB category ID.
  - `amount`: Number of questions (max 50 per OpenTDB limit).
- **Return**: `Future<List<AcademyQuestion>>`
- **Behavior**:
  - Automatically handles Code 4 (Token Empty) by calling `resetSession()` and retrying.
  - Automatically handles Code 5 (Rate Limit) by retrying with exponential backoff.
  - Decodes HTML entities before returning the objects.

### `resetSession()`
- **Purpose**: Resets the current session token's question deck.
- **Side Effects**: Communicates with OpenTDB reset endpoint.

## External API Schema (OpenTDB)

### Endpoint: `https://opentdb.com/api.php`
- **Method**: GET
- **Response Format**: JSON
```json
{
  "response_code": 0,
  "results": [
    {
      "category": "Science: Computers",
      "type": "multiple",
      "difficulty": "easy",
      "question": "Which company created the &quot;Java&quot; programming language?",
      "correct_answer": "Sun Microsystems",
      "incorrect_answers": [
        "Apple",
        "Microsoft",
        "IBM"
      ]
    }
  ]
}
```
