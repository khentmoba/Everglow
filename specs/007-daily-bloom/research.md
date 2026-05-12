# Research: Daily Bloom

This document outlines the technical decisions and best practices for implementing the Daily Bloom feature in the Everglow Flutter web application.

## 1. Breathing Animation Implementation

**Decision**: Use `TweenAnimationBuilder` with `Curves.easeInOutSine` to animate the scale and vertical offset of the lily container.

**Rationale**:
- `TweenAnimationBuilder` is lightweight and handles its own lifecycle (no need for a manual `AnimationController` in a `StatefulWidget`).
- `Curves.easeInOutSine` provides a smooth, natural "inhale/exhale" feeling.
- Animating `Transform.scale` and `Transform.translate` is performance-optimized in Flutter (compositor layer).

**Alternatives Considered**:
- `CustomPainter`: Overkill for a simple container animation; better for complex vector shapes.
- `flutter_animate`: Great for one-off effects, but `TweenAnimationBuilder` is more robust for persistent, looping "breathing" logic.

## 2. Asset Strategy: Lily Visuals

**Decision**: Implement the Lily using **Layered PNG Assets** with `ColorFiltered` overlays for the soft pink glow.

**Rationale**:
- High-quality PNGs ensure the "cute" aesthetic without the complexity of pixel-perfect `CustomPaint` logic.
- Layering allows independent animation (e.g., the bud "opens" by fading in a partially-open PNG over the closed-bud PNG).
- Using `AnimatedSwitcher` between growth stages provides a smooth cross-fade.

**Alternatives Considered**:
- `CustomPaint`: Provides maximum flexibility but is time-consuming to create complex organic shapes like a lily.
- `Rive/Lottie`: Excellent for complex animations, but adds dependency weight and requires external tooling.

## 3. Global Interaction Hook

**Decision**: Create a `GardenService` and use a `Provider` to expose it. Call `incrementInteractions()` from:
1.  `DashboardScreen.initState()` (for dashboard visits).
2.  `LetterboxService.markAsRead()` (for note reads).

**Rationale**:
- Centralizes interaction logic.
- Decouples UI from the database increment logic.
- Allows for future interaction types (e.g., clicking a pet, shared photo view).

**Alternatives Considered**:
- Event Bus: Too complex for this simple use case.
- Directly calling Firestore in widgets: Violates clean architecture patterns established in the project.

## 4. Streak Calculation Logic

**Decision**: Use `DateTime.now().toLocal()` and compare calendar days.

**Rationale**:
- Calendar-day comparison (Year/Month/Day) is standard for engagement streaks.
- `toLocal()` ensures the user's perception of "today" vs "yesterday" is accurate to their timezone.
- A "consecutive visit" is defined as `lastVisit.day == today.day - 1`.

**Edge Cases**:
- Crossing midnight: Handled correctly by calendar-day check.
- Timezone changes (travel): Handled by comparing absolute dates in the current locale.
