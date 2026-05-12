# Quickstart: SanctuaryChat

## Setup
1. Ensure Firebase is configured (already done for the project).
2. The `messages` collection will be created automatically on the first message.

## Usage
1. **Entry**: Enter '1111' at the gateway for Clair, or '2222' for Khent.
2. **Navigation**: Tap the heart/chat bubble icon on the dashboard to open the chat.
3. **Messaging**: Type a message and tap the paper plane icon.

## Development
- **Models**: `lib/features/chat/domain/models/chat_message.dart`
- **Service**: `lib/features/chat/data/services/chat_service.dart`
- **UI**: `lib/features/chat/presentation/screens/sanctuary_chat_screen.dart`
- **Gateway Update**: `lib/features/entry/presentation/state/gateway_state.dart`
