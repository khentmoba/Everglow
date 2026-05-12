# Data Model: SanctuaryChat

## Entity: ChatMessage
Represents a single message in the sanctuary chat.

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | String | Unique Firestore document ID. |
| `sender` | String | Identifier of the sender ('clair' or 'khent'). |
| `text` | String | The message content. |
| `timestamp` | DateTime | When the message was sent (for ordering). |

### Firestore Mapping
- **Collection**: `messages`
- **Ordering**: `timestamp` ascending.

### Logic
- **toFirestore()**: Converts model to a map for upload.
- **fromFirestore()**: Factory for creating model from Firestore snapshot.
