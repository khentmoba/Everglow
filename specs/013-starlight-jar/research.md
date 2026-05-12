# Research: Starlight Jar

**Status**: Complete  
**Date**: 2026-05-11

## Decisions

### 1. Glassmorphism Implementation
- **Decision**: Use `BackdropFilter` with `ImageFilter.blur` inside a `Container` with a semi-transparent border and background.
- **Rationale**: This is the standard Flutter approach for high-fidelity "frosted glass" effects, aligned with Principle II of the Constitution.
- **Alternatives considered**: Using a static image of a jar. Rejected because it lacks the "dynamic/alive" feel requested.

### 2. Physics & Piling Simulation
- **Decision**: Use a `Stack` with `Positioned` widgets. For the "piling" effect, we will use a deterministic random distribution within the bottom 20% of the jar's coordinate space, applying slight random rotations.
- **Rationale**: A full physics engine (like `forge2d`) is overkill for 100 static stars. A coordinate-based "pile" is performant and visually sufficient.
- **Alternatives considered**: `flutter_forge2d`. Rejected as too heavy for this feature's scope.

### 3. Animations
- **Decision**: 
  - **Drop**: `TweenAnimationBuilder` or `AnimationController` for Y-axis translation from screen height to calculated pile position.
  - **Shake**: `AnimationController` driving a `Transform.rotate` with a sine wave curve for 1 second.
  - **Float Out**: A curved path animation (Bezier) from the jar to the center of the screen.
- **Rationale**: Standard Flutter animation controllers provide the required precision and "bouncy" feel.
- **Alternatives considered**: `Lottie` animations. Rejected because the stars need to represent real data (StarNotes).

## Findings

- **Firestore Stream**: Listening to a limited stream (`limit(100)`) ordered by `timestamp` descending will ensure we only render the required stars.
- **Author Attribution**: Accessing `currentUser` state to determine if 'khent' or 'clair' is dropping the star.
