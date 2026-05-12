# Data Model: Creator Mode

**Feature**: Creator Mode Admin Panel | **Date**: 2026-05-11

## Entities

### Milestone
Represents a memory in the relationship timeline.

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| title | String | Name of the memory | Required, non-empty |
| description | String | Detailed story of the memory | Required, multi-line |
| imageUrl | String | Download URL from Firebase Storage | Optional |
| date | DateTime | When the memory occurred | Required |

### HiddenNote
Represents a time-locked letter in the letterbox.

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| title | String | Title of the letter | Required, non-empty |
| content | String | Secret content of the letter | Required, multi-line |
| unlockDate | DateTime | When the letter can be opened | Required, must be >= today |
| isRead | Boolean | Whether the letter has been viewed | Default: false |
| isOpened | Boolean | Whether the envelope has been opened | Default: false |

## Relationships
- **Milestones** are stored as a flat collection in Firestore (`milestones`).
- **HiddenNotes** are stored as a flat collection in Firestore (`notes`).

## Validation Rules
- **Memories**: Must have a title and description. Date defaults to today if not selected.
- **Letters**: Must have a title and content. Unlock date defaults to "Tomorrow" (current date + 1 day).
- **Images**: Only `.jpg`, `.png`, and `.gif` are supported (handled by `image_picker` filtering).
