# Research: Everglow Academy

## Decision 1: Firestore Matchmaking Pattern
- **Decision**: Use a "Host-Join" pattern with `runTransaction`.
- **Rationale**: When a user joins a 'waiting' match, we must atomically update the status to 'active' and add the second player's ID to prevent multiple people from joining the same slot (though here it's just two users, it's good practice).
- **Alternatives considered**: Simple `update()` calls, but transactions provide the safety needed for simultaneous joining.

## Decision 2: 1v1 Game State Synchronization
- **Decision**: Centralize state in a single `GameMatch` document.
- **Rationale**: Listening to a single document via `StreamBuilder` minimizes reads and ensures both players see the exact same state (question ID, scores, status).
- **Alternatives considered**: Separate documents for each player's state, but this complicates synchronization.

## Decision 3: "Fastest Finger" Point Logic
- **Decision**: Use Firestore transactions for answer submission.
- **Rationale**: When a player taps the correct answer, the transaction checks if the `currentQuestionId` in Firestore still matches the local one and if a point has already been awarded for this question. If not, it awards the point and increments `currentQuestionId`.
- **Alternatives considered**: Local-first logic, but it's prone to desync and double-scoring.

## Decision 4: Confetti & Animations
- **Decision**: Use the `confetti` Flutter package with a `ConfettiController`.
- **Rationale**: It's lightweight, customizable, and works well on Web. The bouncy "Enter Academy" button will use standard `AnimatedContainer` or `GestureDetector` with `ScaleTransition`.
- **Alternatives considered**: Lottie animations, but simple confetti is more flexible for a "Podium" effect.

## Decision 5: Match Cleanup (Stale Matches)
- **Decision**: Implement a cleanup check during the "Waiting" phase.
- **Rationale**: When a user creates a 'waiting' match, they will first query for any 'waiting' or 'active' matches older than 30 minutes and delete them before creating a new one.
- **Alternatives considered**: Cloud Functions (too much overhead for this project), manual cleanup.
