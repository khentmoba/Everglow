# Data Model: Dynamic Letterbox

## `HiddenNote` Model

Represents a digital letter that is time-locked and tracks its read status.

### Fields
- `id` (String): Unique identifier for the note.
- `title` (String): Title or hint shown on the envelope.
- `content` (String): The hidden message inside the letter.
- `unlockDate` (DateTime): The exact date and time the note unlocks.
- `isRead` (bool): Tracks whether the note has been opened yet. Defaults to `false`.

### Derived Properties
- `isUnlocked` (bool): Getter that evaluates `DateTime.now().isAfter(unlockDate) || DateTime.now().isAtSameMomentAs(unlockDate)`.

### Initialization
A dummy list containing 3-4 instances must be provided:
1. Locked note (unlocking in the future, e.g., tomorrow).
2. Unread unlocked note (unlockDate in the past, `isRead` == false).
3. Read unlocked note (unlockDate in the past, `isRead` == true).
