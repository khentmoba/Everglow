# Research & Decisions: cute-entry-gateway

## Tech Stack Confirmation
- **Decision**: Flutter Web
- **Rationale**: The project constitution specifies Flutter for Web. The terminal indicates a Flutter app is actively running. Flutter's animation engine is excellent for building the high-fidelity, playful transitions required (bouncing, popping, blooming).
- **Alternatives considered**: HTML/Vanilla JS (discarded due to project constitution).

## Entrance & Unlock Animations
- **Decision**: Use `AnimatedContainer`, `TweenAnimationBuilder`, and flutter's `AnimatedSwitcher` for entry and unlock effects. For the petal shower/blooming effect, use a custom `CustomPainter` or a lightweight particle package (like `flutter_particles` or just custom `AnimationController`s managing simple petal widgets).
- **Rationale**: Keeps the bundle size small without needing heavy external animation assets (like Lottie), while still providing 60fps high-fidelity transitions.
- **Alternatives considered**: Lottie animations (could be too complex to find the exact "cute pink lock" or "petal shower" without a dedicated designer). Custom code gives more control over the exact '1111' unlock logic.

## Passcode Input
- **Decision**: A simple custom row of 4 text fields or circles that fill in as the user types, controlled by a hidden `TextField` or RawKeyboardListener.
- **Rationale**: Avoids the "corporate" look of standard input forms. We want it to look like a playful lock or door code.
- **Alternatives considered**: Standard `TextField` with `obscureText` (rejected for being too standard/corporate).

## "Cute Pinkish" Aesthetic
- **Decision**: Define a custom `ThemeData` override or local styling heavily utilizing pink hues (e.g., `Colors.pink[50]` to `Colors.pink[300]`), rounded corners (`BorderRadius.circular(30)`), and soft drop shadows (`BoxShadow` with high blur radius and soft pink shadow color).
- **Rationale**: Direct alignment with the 'overwhelmingly cute' and 'pinkish' requirement.
