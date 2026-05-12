# Data Model: cute-entry-gateway

Since this feature is explicitly a visual-only frontend overlay with a hardcoded passcode, there are no backend entities or persistent database tables to define. 

Instead, this document defines the localized UI State models to manage the entry gateway.

## UI State Enum: `GatewayState`

Manages the current animation and interaction phase of the gateway.

| State | Description | Transitions To |
|-------|-------------|----------------|
| `initialLoad` | The lock/door is animating into view. | `awaitingInput` |
| `awaitingInput` | The system is waiting for the user to enter the passcode. | `evaluating`, `error` |
| `evaluating` | Temporary state while validating passcode. | `unlocking`, `error` |
| `error` | The input was incorrect. Triggers the shake animation and clears input. | `awaitingInput` |
| `unlocking` | The passcode was correct ('1111'). Triggers the pop/swing unlock animation. | `revealingSite` |
| `revealingSite` | The lock/door disappears and the petal shower/blooming animation reveals the main dashboard. | `complete` |
| `complete` | The gateway is fully bypassed. The main dashboard is fully interactive. | None (End of gateway flow) |

## Internal Constants

- **Hardcoded Passcode**: `'1111'`
- **Max Passcode Length**: `4`

## State Management Approach
A local state controller (e.g., `StatefulWidget` or a dedicated Riverpod/Provider notifier if the project uses them) will hold:
1. `GatewayState currentState`
2. `String currentInput` (up to 4 characters)
