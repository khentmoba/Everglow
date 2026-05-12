# Data Model: Everglow Guardian

## Entities

### GuardianMessage
Represents a sweet message the Guardian can say.

| Field | Type | Description |
|-------|------|-------------|
| id | String | Unique identifier (Firestore ID) |
| content | String | The actual text of the message |
| category | String | e.g., "greeting", "idle", "reaction" |
| createdAt | Timestamp | Server-side timestamp |

## State Machine: GuardianState

The character transitions between these visual states:

1. **Idle**: Floating up and down (Repeat).
2. **Greeting**: Scaling up with a bounce (One-shot, on dashboard load).
3. **Reacting**: Jump or spin animation (One-shot, triggered by tap).
4. **Speaking**: Thought bubble visible (5-second duration).

## Relationships

- **GuardianService** -> **Firestore**: Reads from `guardian_messages` collection.
- **EverglowGuardian Widget** -> **GuardianService**: Receives randomized messages.
