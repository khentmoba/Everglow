# Quickstart: Heartbeat Sync

## Feature Activation
1. **Firestore Setup**: Ensure the `moods` collection exists in Firebase.
2. **Indexing**: Add a composite index for `userId` (ASC) and `timestamp` (DESC) to support "latest mood" queries.

## Development Setup
- Run `flutter pub get` to ensure `cloud_firestore` and `provider` are available.
- Ensure the `GuardianService` is initialized in `main.dart`.

## Verification Steps
1. **Mock Submission**: 
   ```dart
   MoodService().submitMood(userId: 'clair', score: 5, emoji: '💖');
   ```
2. **Dashboard Preview**: Open the dashboard as 'khent' and verify the sparkling pink heart appears near Clair's name.
3. **Guardian Trigger**: Clear today's mood for the current user and refresh the app to trigger the Guardian prompt.
