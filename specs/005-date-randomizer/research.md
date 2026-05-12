# Research: Date Randomizer Implementation

## Decision 1: Fast-spinning Suspense Animation
- **Decision**: Implement a custom `AnimationController` that drives a `RotationTransition`. The controller will be configured to repeat multiple times within the 1.5s window to create a "blur" or "high speed" effect.
- **Rationale**: Standard Flutter `AnimationController` provides precise control over the 1.5s duration and can be easily looped using `controller.repeat()` and then stopped.
- **Alternatives Considered**: 
    - `animate_do` Spin: Too simplistic; harder to synchronize with the exact 1.5s revealed logic.
    - `Rive`: High fidelity but overkill for a simple rotation.

## Decision 2: Bouncy Dialog Reveal
- **Decision**: Use `showGeneralDialog` with a custom `pageBuilder` and `transitionBuilder`. The `transitionBuilder` will apply a `ScaleTransition` with an `ElasticOut` curve for the "bouncy" entry.
- **Rationale**: `showGeneralDialog` is the canonical way to implement custom entrance animations for dialogs in Flutter. `ElasticOut` is the industry standard for a "cute/bouncy" feel.
- **Alternatives Considered**: 
    - `showDialog`: Limited animation control.
    - `Overlay`: More complex to manage state and dismissal.

## Decision 3: Celebration UI (Sparkles/Confetti)
- **Decision**: Use a `Stack` within the dialog containing several `AnimateDo` (`BounceInDown`, `ZoomIn`) widgets wrapping `Icons.star` and `Icons.circle` with randomized offsets and soft pink/gold colors.
- **Rationale**: This achieves the "festive" requirement without adding a new heavy dependency like `lottie` or `confetti`.
- **Alternatives Considered**: 
    - `confetti` package: Great but adds another dependency. If the current approach feels lacking, we can easily swap to this.

## Decision 4: Data Seeding Strategy
- **Decision**: Create a `SeedService` that reads a JSON file from `assets/data/date_ideas_seed.json`. It will use `WriteBatch` to push data to Firestore in chunks of 500. This will be triggered once if the collection is empty.
- **Rationale**: `WriteBatch` is the most efficient way to seed large amounts of data in Firestore. A JSON asset ensures the 1000+ ideas are always available for the initial setup.
- **Alternatives Considered**: 
    - Cloud Functions: Requires more setup and cost.
    - Manual Import: Error-prone for 1000+ entries.
