# Data Model: Daily Bloom

This document defines the data structures for the Daily Bloom gamified garden feature.

## GardenStats

Represents the user's progress and engagement metrics for their digital garden.

| Field | Type | Description |
|-------|------|-------------|
| `currentStage` | `int` | The current growth stage (0-5). |
| `lastVisit` | `DateTime` | Timestamp of the last recorded interaction (visit or note read). |
| `streakCount` | `int` | Number of consecutive days the user has interacted. |
| `totalInteractions` | `int` | Cumulative count of all interactions. |

### Growth Thresholds (Total Interactions)

- **Stage 0**: 0 (Seedling/Empty)
- **Stage 1**: 1 (Sprout)
- **Stage 2**: 5 (Early Bud)
- **Stage 3**: 10 (Closed Bud)
- **Stage 4**: 20 (Partially Open)
- **Stage 5**: 30 (Full Bloom)

### Persistence

- **Collection**: `users/{uid}/garden_stats`
- **Document**: `stats` (Single document per user)

## Enums / Constants

### GrowthStage (Internal)

```dart
enum GrowthStage {
  sprout(0),
  earlyBud(1),
  closedBud(2),
  partiallyOpen(3),
  fullBloom(4),
  radiantBloom(5);

  final int value;
  const GrowthStage(this.value);
}
```
