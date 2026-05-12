# Research: Dynamic Letterbox

## 1. UI Implementation Strategy for LetterboxView
- **Decision**: Use `ListView.builder` with `scrollDirection: Axis.horizontal` inside a constrained height container (e.g., `SizedBox(height: 160)`).
- **Rationale**: The spec requires a horizontal scrolling list that sits below the `MetricCard`. A `ListView` is the standard, performant way to handle scrolling lists in Flutter.
- **Alternatives considered**: `SingleChildScrollView` with a `Row` (less performant for many items, though fine for 3-4, `ListView.builder` is more robust for future growth). `CarouselSlider` package (adds an external dependency for simple scrolling, unnecessary).

## 2. Dialog Implementation for Long Text
- **Decision**: Use a custom `Dialog` widget wrapping a `Container` with a maximum height (e.g., `ConstrainedBox`), containing a `SingleChildScrollView` for the text. Use `showGeneralDialog` with a custom `transitionBuilder` for the smooth scale-in animation.
- **Rationale**: Meets the spec's requirement for a cute letter UI with smooth animations, while gracefully handling long text by expanding to a max height and then scrolling.
- **Alternatives considered**: Standard `showDialog` with `AlertDialog` (less customizable animation, harder to style as a soft-cornered letter without visual artifacts).

## 3. Font and Styling
- **Decision**: Use the `google_fonts` package (if available) or existing theme text styles to apply a handwritten look. Ensure `BorderRadius.circular(32.0)` and `BoxShadow` are used for the glowing/soft shadow effects.
- **Rationale**: Aligns with the "High-Fidelity & Modern Aesthetics" constitution principle.
