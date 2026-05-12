# Research: Gamified Pink UI Modernization

## Decision: Glassmorphism Implementation
- **Decision**: Custom `GlassContainer` widget using `ClipRRect`, `BackdropFilter` (sigma 10.0), and `RepaintBoundary`.
- **Rationale**: Research indicates `BackdropFilter` is computationally expensive on Flutter Web. Using `RepaintBoundary` ensures the blur is only re-calculated when the contents change, and `ClipRRect` bounds the GPU sampling area.
- **Alternatives considered**: 
    - `glass_kit`: Avoided to keep the dependency tree lean.
    - Faux Glass: Using only semi-transparent gradients without blur; rejected for the primary "High-Fidelity" goal but kept as a fallback.

## Decision: Performance Fallback
- **Decision**: Conditional rendering of `BackdropFilter` based on a performance monitor or system accessibility settings.
- **Rationale**: Aligns with the clarified requirement to provide an automatic fallback to solid colors if low performance is detected.
- **Alternatives considered**: Manual toggle only (rejected in favor of automatic detection).

## Decision: Audio Feedback (SFX)
- **Decision**: `just_audio` with a singleton `AudioService` that pre-loads essential assets (pop, sparkle, click).
- **Rationale**: `just_audio` provides the most stable cross-platform experience for Flutter Web. Pre-loading assets is critical for "instant" UI feedback.
- **Alternatives considered**: 
    - `flame_audio`: Better for complex games, but overkill for simple UI sounds.
    - `soundpool`: Unmaintained and unreliable on modern Flutter Web.

## Decision: Gamified Pink Palette & Patterns
- **Decision**: Shifting Gradient Background using an `AnimatedBuilder` with `LinearGradient` offsets and a custom `CircuitryPainter` for the background pattern.
- **Visual Mapping**:
    - **Primary**: Shifting Pink (`#FFD1DC`) to Peachy-Magenta (`#FF00FF`).
    - **Highlights**: Iridescent Teal (`#00FFFF`) and Electric Blue (`#0000FF`) for glows.
    - **Accents**: Champagne Gold (`#F7E7CE`) for outlines.
- **Rationale**: Creates the "layered, multi-dimensional" feel requested.

## Decision: XP Persistence
- **Decision**: Firestore document `users/{uid}/progress` with real-time updates.
- **Rationale**: Provides the requested "Local Persistence" that stays in sync across devices for the shared experience.
- **Alternatives considered**: `shared_preferences` (rejected as it wouldn't sync between Khent and Clair).
