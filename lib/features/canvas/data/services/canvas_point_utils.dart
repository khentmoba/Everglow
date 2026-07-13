/// Ramer-Douglas-Peucker point simplification for normalized canvas points.
///
/// Used by [CanvasService] to reduce stroke point count while preserving
/// visual fidelity. Extracted here so it can be unit-tested without Firebase.

/// Simplifies a list of normalized canvas points (each `x`/`y` in [0,1])
/// using the Ramer-Douglas-Peucker algorithm.
///
/// [epsilon] is the maximum allowed perpendicular distance, in normalized
/// canvas units (NOT squared). Points whose distance from the segment is
/// less than [epsilon] are collapsed.
List<Map<String, double>> simplifyCanvasPoints(
  List<Map<String, double>> points, {
  double epsilon = 0.001,
}) {
  if (points.length <= 2) return points;

  int index = -1;
  double maxDist = 0;
  final epsilonSq = epsilon * epsilon;

  for (int i = 1; i < points.length - 1; i++) {
    double distSq = perpendicularDistanceSquared(points[i], points.first, points.last);
    if (distSq > maxDist) {
      index = i;
      maxDist = distSq;
    }
  }

  if (maxDist > epsilonSq) {
    var left = simplifyCanvasPoints(points.sublist(0, index + 1), epsilon: epsilon);
    var right = simplifyCanvasPoints(points.sublist(index), epsilon: epsilon);
    return [...left.sublist(0, left.length - 1), ...right];
  } else {
    return [points.first, points.last];
  }
}

/// Returns the squared perpendicular distance from point [p] to the segment
/// [a]-[b], in normalized canvas units squared. Compare with `epsilon * epsilon`,
/// NOT with a raw distance threshold.
double perpendicularDistanceSquared(
  Map<String, double> p,
  Map<String, double> a,
  Map<String, double> b,
) {
  double x = p['x']!, y = p['y']!;
  double x1 = a['x']!, y1 = a['y']!;
  double x2 = b['x']!, y2 = b['y']!;

  double dx = x2 - x1;
  double dy = y2 - y1;

  if (dx == 0 && dy == 0) {
    return (x - x1) * (x - x1) + (y - y1) * (y - y1);
  }

  double t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);
  t = t.clamp(0.0, 1.0);

  double nearestX = x1 + t * dx;
  double nearestY = y1 + t * dy;

  return (x - nearestX) * (x - nearestX) + (y - nearestY) * (y - nearestY);
}
