# Data Model: Everglow Canvas

## Entities

### DoodleStroke
Represents a single continuous line drawn on the shared canvas.

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique identifier (Firestore document ID). |
| `points` | List<Map<String, double>> | Normalized coordinates `{"x": 0.0, "y": 0.0}` in range [0.0, 1.0]. |
| `color` | String | Hexadecimal color code (e.g., `#FFC0CB`). |
| `strokeWidth` | double | Thickness of the line. |
| `createdAt` | Timestamp | Server-side timestamp for temporal layering. |
| `userId` | String | ID of the user who created the stroke ('clair' or 'khent'). |

## Relationships
- **Firestore Collection**: `canvas_strokes`
- **Ordering**: Ascending by `createdAt` (oldest at bottom, newest on top).

## Validation Rules
- `points` must contain at least 2 points to be a valid line.
- `color` must be a valid hex string.
- `strokeWidth` must be > 0.
