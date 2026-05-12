# Data Model: Gamified Pink UI Modernization

## Entities

### UserProgress
Represents the gamification state for a user (Clair or Khent).

| Field | Type | Description |
|-------|------|-------------|
| `uid` | String | Unique identifier for the user. |
| `xpTotal` | int | Cumulative experience points earned. |
| `level` | int | Current calculated level (e.g., Level = xpTotal / 1000). |
| `lastActivity` | Timestamp | Last time XP was earned. |
| `streak` | int | Number of consecutive days with activity. |

**Validation Rules**:
- `xpTotal` must be non-negative.
- `level` is derived but may be cached for UI performance.

## Collections

### `users/{uid}/progress` (Firestore)
- **Security**: Read/Write only by the authenticated owner.
- **Indexing**: No custom indexes required for basic retrieval.

## UI Tokens (Theme Contract)

These are internal styling tokens used by the `AppTheme` engine.

| Token | Type | Value/Range |
|-------|------|-------------|
| `glassBlur` | double | 10.0 (Standard), 0.0 (Fallback) |
| `glassOpacity` | double | 0.1 to 0.3 |
| `gradientStart` | Color | Shifting Pink (`#FFD1DC`) |
| `gradientEnd` | Color | Peachy Magenta (`#FF00FF`) |
| `glowTeal` | Color | Iridescent Teal (`#00FFFF`) |
| `glowGold` | Color | Champagne Gold (`#F7E7CE`) |
