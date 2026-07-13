import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/canvas/data/services/canvas_point_utils.dart';

void main() {
  group('simplifyCanvasPoints', () {
    test('returns same list when 2 or fewer points', () {
      final points = [
        {'x': 0.0, 'y': 0.0},
        {'x': 1.0, 'y': 1.0},
      ];

      final result = simplifyCanvasPoints(points);

      expect(result, points);
    });

    test('returns same single point list', () {
      final points = [
        {'x': 0.5, 'y': 0.5},
      ];

      final result = simplifyCanvasPoints(points);

      expect(result, points);
    });

    test('collinear points reduce to endpoints', () {
      // Points along a straight line
      final points = [
        {'x': 0.0, 'y': 0.0},
        {'x': 0.25, 'y': 0.25},
        {'x': 0.5, 'y': 0.5},
        {'x': 0.75, 'y': 0.75},
        {'x': 1.0, 'y': 1.0},
      ];

      final result = simplifyCanvasPoints(points);

      // Collinear points should be reduced to just start and end
      expect(result.length, 2);
      expect(result.first, points.first);
      expect(result.last, points.last);
    });

    test('preserves points that deviate significantly from line', () {
      // A sharp corner — the middle point must be kept
      final points = [
        {'x': 0.0, 'y': 0.0},
        {'x': 0.5, 'y': 0.0},
        {'x': 0.5, 'y': 1.0},
        {'x': 1.0, 'y': 1.0},
      ];

      final result = simplifyCanvasPoints(points);

      // The corner point (0.5, 0.0) and (0.5, 1.0) should be preserved
      expect(result.length, greaterThanOrEqualTo(3));
    });

    test('respects epsilon parameter', () {
      // Slightly wobbly line
      final points = [
        {'x': 0.0, 'y': 0.0},
        {'x': 0.25, 'y': 0.26}, // slight deviation
        {'x': 0.5, 'y': 0.5},
        {'x': 0.75, 'y': 0.74}, // slight deviation
        {'x': 1.0, 'y': 1.0},
      ];

      // With large epsilon, all interior points collapse
      final aggressive = simplifyCanvasPoints(points, epsilon: 0.1);
      expect(aggressive.length, 2);

      // With tiny epsilon, more points are preserved
      final conservative = simplifyCanvasPoints(points, epsilon: 0.0001);
      expect(conservative.length, greaterThan(2));
    });

    test('empty points returns empty', () {
      final result = simplifyCanvasPoints([]);

      expect(result, isEmpty);
    });
  });
}
