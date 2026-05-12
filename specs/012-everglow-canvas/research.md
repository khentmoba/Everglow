# Research: Everglow Canvas

## Decision: Drawing Performance Optimization
- **Finding**: For an interactive drawing app, `RepaintBoundary` is useful only if the rest of the UI is complex and doesn't change. The `CustomPainter` itself should be optimized.
- **Decision**: 
  - Use `canvas.drawPoints(PointMode.polygon, ...)` for better performance than `drawPath`.
  - Minimize object allocation inside `paint()`.
  - Cache screen-space points and update only when the canvas size changes or new data arrives.
- **Rationale**: Reduces GPU overhead and prevents frame drops during active drawing.
- **Alternatives Considered**: `picture.toImage()` raster caching was considered but rejected for MVP as it adds complexity and "hundreds of strokes" is within the limit of `CustomPaint` on modern web browsers.

## Decision: Path Simplification
- **Finding**: High-frequency sampling during `onPanUpdate` generates redundant points.
- **Decision**: 
  - Implement a distance-based filter: discard any point that is less than 2.0 normalized units away from the previous point.
  - Apply a simplified Ramer-Douglas-Peucker (RDP) algorithm before saving to Firestore to further reduce document size.
- **Rationale**: Keeps Firestore document sizes small and ensures smooth rendering.

## Decision: Real-Time Synchronization
- **Finding**: Firestore Streams are efficient for low-frequency updates (entire strokes) but too slow for point-by-point updates.
- **Decision**: 
  - Render the "active" stroke locally using immediate state.
  - Persist the entire stroke to Firestore only on `onPanEnd`.
  - Listen to a `Stream<QuerySnapshot>` from `canvas_strokes` for other users' strokes.
- **Rationale**: Balances real-time feel with Firebase quota management.

## Decision: Coordinate Normalization
- **Finding**: Users have different screen sizes/ratios.
- **Decision**: 
  - Store all points as `Offset(x, y)` where `x, y` are in range `[0.0, 1.0]`.
  - Convert to local pixels in the `CustomPainter` using `size.width` and `size.height`.
- **Rationale**: Ensures drawings look consistent across web and mobile.

## Decision: Eraser Implementation
- **Finding**: User requested "Permanent Removal".
- **Decision**: 
  - Implement a "hit detection" logic that checks if the eraser stroke intersects with any existing `DoodleStroke`.
  - Delete matching strokes from Firestore.
- **Rationale**: Direct response to user clarification.

## Decision: 'Clear Canvas' Confirmation
- **Finding**: Accidental clearing should be prevented.
- **Decision**: 
  - Use a standard Flutter `AlertDialog` with a "Clear" action button in a bright pink/red accent.
- **Rationale**: User safety and theme consistency.
