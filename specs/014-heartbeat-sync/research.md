# Research: Heartbeat Sync

## Decision: Bouncy Animations & Glowing Effects
- **Choice**: Native `AnimationController` with `CurvedAnimation(curve: Curves.elasticOut)` and `BoxShadow` for glow.
- **Rationale**: Flutter's native animation system is highly performant and easily customizable for "bouncy" effects. `BoxShadow` with a high blur radius can simulate a "glow" efficiently.
- **Alternatives Considered**: 
  - `simple_animations` package: Good for complex timelines, but native Flutter is sufficient for simple heart bounces and avoids extra dependencies.
  - Rive/Lottie: Overkill for simple heart interactions.

## Decision: Guardian Integration
- **Choice**: Extend `GuardianController` with a `triggerMoodCheckIn()` method and add a `mood` category to `GuardianService`.
- **Rationale**: Reuses the existing persistent character system. The Guardian is already managed via a global controller, making it the perfect entry point for the daily check-in prompt.
- **Alternatives Considered**:
  - Independent Modal: Less "cute" and doesn't leverage the established character personality.

## Decision: Firestore Offline Persistence
- **Choice**: Enable `persistenceEnabled: true` in Firestore settings (if not already enabled) and use `Snapshots` for real-time updates.
- **Rationale**: Provides automatic local caching and synchronization. This is the industry-standard way to handle "sync when online" requirements in Flutter/Firebase.
- **Alternatives Considered**:
  - Manual `sqflite` caching: Too complex for this use case; Firestore handles this out-of-the-box.

## Decision: Daily Mood Tracking
- **Choice**: Query the `moods` collection for entries where `userId == currentUserId` and `timestamp` falls within the current calendar day.
- **Rationale**: Simple and direct. By indexing on `userId` and `timestamp`, we can efficiently check if a check-in is needed for today.
