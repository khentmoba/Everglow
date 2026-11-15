import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/canvas/data/services/canvas_point_utils.dart';

void main() {
  test('maps portrait views into the original canvas aspect ratio', () {
    expect(
      mapCanvasPointToViewport(
        x: 0,
        y: 0,
        viewportSize: const Size(200, 400),
        canvasAspectRatio: 2,
      ),
      const Offset(0, 150),
    );
    expect(
      mapCanvasPointToViewport(
        x: 1,
        y: 1,
        viewportSize: const Size(200, 400),
        canvasAspectRatio: 2,
      ),
      const Offset(200, 250),
    );
  });

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
      final points = [
        {'x': 0.0, 'y': 0.0},
        {'x': 0.25, 'y': 0.25},
        {'x': 0.5, 'y': 0.5},
        {'x': 0.75, 'y': 0.75},
        {'x': 1.0, 'y': 1.0},
      ];

      final result = simplifyCanvasPoints(points);

      expect(result.length, 2);
      expect(result.first, points.first);
      expect(result.last, points.last);
    });

    test('preserves points that deviate significantly from line', () {
      final points = [
        {'x': 0.0, 'y': 0.0},
        {'x': 0.5, 'y': 0.0},
        {'x': 0.5, 'y': 1.0},
        {'x': 1.0, 'y': 1.0},
      ];

      final result = simplifyCanvasPoints(points);

      expect(result.length, greaterThanOrEqualTo(3));
    });

    test('respects epsilon parameter', () {
      final points = [
        {'x': 0.0, 'y': 0.0},
        {'x': 0.25, 'y': 0.26},
        {'x': 0.5, 'y': 0.5},
        {'x': 0.75, 'y': 0.74},
        {'x': 1.0, 'y': 1.0},
      ];

      final aggressive = simplifyCanvasPoints(points, epsilon: 0.1);
      expect(aggressive.length, 2);

      final conservative = simplifyCanvasPoints(points, epsilon: 0.0001);
      expect(conservative.length, greaterThan(2));
    });

    test('empty points returns empty', () {
      final result = simplifyCanvasPoints([]);

      expect(result, isEmpty);
    });
  });
}
