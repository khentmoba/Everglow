# Data Model: Cute Main Structure

## Entities

### `AnniversaryCounter` (Value Object / Presentation Model)
Represents the calculated duration between the hardcoded start date and the current time.

**Fields**:
- `years`: `int` - Number of full years elapsed.
- `months`: `int` - Number of full months elapsed (0-11).
- `days`: `int` - Number of full days elapsed (0-30).
- `hours`: `int` - Number of full hours elapsed (0-23).
- `minutes`: `int` - Number of full minutes elapsed (0-59).
- `seconds`: `int` - Number of full seconds elapsed (0-59).

**Validation Rules**:
- Time units must be positive integers or zero.
- Maximum values adhere to standard calendar boundaries.

**State Transitions**:
- Updated every 1 second by a background `Timer` or `Stream`.
- If the start date is in the future, all fields should default to `0`.
