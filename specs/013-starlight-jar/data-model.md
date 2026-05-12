# Data Model: Starlight Jar

## Entities

### StarNote
Represents a single gratitude note stored in the vault.

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique identifier (Firestore Document ID) |
| `content` | String | The text content of the gratitude note |
| `author` | String | Either "khent" or "clair" |
| `timestamp` | DateTime | When the note was created |

## Relationships
- One-to-many: The `starlight_jar` collection contains multiple `StarNote` documents.

## Validation Rules
- `content` MUST NOT be empty or whitespace-only.
- `author` MUST be one of ["khent", "clair"].
- `timestamp` should be server-side generated or local time if offline.
