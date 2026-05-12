# Research: Cute Main Structure

## Time Calculation Precision

**Decision**: Use the `age_calculator` package (or equivalent like `jiffy` if preferred, but `age_calculator` specifically targets exact year/month/day calculation).
**Rationale**: The specification requires precise relationship duration tracking down to the second, accounting for leap years and exact month lengths. Standard Dart `DateTime` difference only provides total days or hours, leaving months and years to approximation. A dedicated package handles edge cases reliably.
**Alternatives considered**: 
- Standard Dart `DateTime.difference()`: Rejected due to inability to extract exact months and years accurately (requires approximation like 30 days/month).
- `jiffy` package: Valid alternative, but might be heavier than needed just for age duration calculation.

## Animation & Transitions

**Decision**: Use `PageRouteBuilder` with `ScaleTransition` and `FadeTransition` for the "blooming" effect, and `AnimatedSwitcher` for the real-time counter ticking.
**Rationale**: These are standard, high-performance Flutter animation primitives that easily achieve the "bouncy" and "popping" requirements without needing heavyweight animation libraries like Rive or Lottie.
**Alternatives considered**:
- Third-party animation libraries: Rejected as overkill for simple scale/fade and switcher animations.
