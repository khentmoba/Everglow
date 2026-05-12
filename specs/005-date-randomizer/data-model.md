# Data Model: Date Randomizer

## Entities

### DateIdea
Represents a single suggestion for a date activity.

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique identifier (Firestore Document ID). |
| `title` | String | The text of the date idea. |

**Firestore Collection**: `date_ideas`

## Validation Rules
- `title` MUST NOT be empty.
- `title` SHOULD be concise (under 100 characters for optimal UI display).

## Relationships
- None. This is a flat collection for high-speed random access.

## Volume Assumptions
- Minimum: 1000 items (initial seed).
- Maximum: Scaling up to 5000+ items.
- Selection Logic: Fetch all `id`s/`title`s into a local list once per session to ensure $O(1)$ random selection after the initial fetch.
