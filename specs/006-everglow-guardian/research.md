# Research: Everglow Guardian

## Decisions

### 1. Pure Widget Character Design
- **Decision**: Use a `CustomPaint` or a nested `Stack` of `Container` and `CircleAvatar` widgets.
- **Rationale**: The user explicitly requested "pure Flutter widgets." A nested stack of shaped containers is easier to animate individually (e.g., ears twitching, tail wagging) than a single CustomPaint.
- **Alternatives considered**: SVG (rejected per prompt), Lottie (rejected per prompt).

### 2. Particle System Implementation
- **Decision**: Use the `confetti` package or a custom lightweight `AnimationController` with `Stack` + `Positioned` widgets.
- **Rationale**: For "tiny pink heart particles," a custom lightweight solution using `Overlay` or a local `Stack` provides more control over the "pink heart" look and feel without external overhead.
- **Alternatives considered**: `particle_flutter` (too heavy), `confetti` (good, but might be too "celebratory" rather than "cute burst").

### 3. Animation State Machine
- **Decision**: Use a single `AnimationController` with multiple `CurvedAnimation` segments or a simple `ValueNotifier<GuardianState>` to switch between different animation controllers.
- **Rationale**: An `Immediate Reset` is best handled by `controller.forward(from: 0)`. A dedicated controller for the "Idle" (repeat) and another for "Reaction" (one-shot) ensures smooth transitions.
- **Alternatives considered**: Rive state machine (rejected per prompt).

### 4. Firestore Seeding Logic
- **Decision**: Mirror the `DateIdeaService` pattern.
- **Rationale**: Consistency across the codebase. Use a JSON asset `assets/data/guardian_messages_seed.json` and a `seedMessages()` method in `GuardianService`.
- **Alternatives considered**: Manual entry in Firebase Console (less reliable for reproduction).

## Best Practices
- **Layout Integration**: Use a `Stack` in `DashboardScreen` and place `EverglowGuardian` at the end. Wrap it in an `IgnorePointer` for the non-visual areas to ensure background widgets remain interactable.
- **Theme Consistency**: Use `Theme.of(context).colorScheme.primary` (soft pink) and high `borderRadius` values defined in `theme.dart`.
