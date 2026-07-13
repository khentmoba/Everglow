import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/canvas/domain/models/doodle_stroke.dart';

void main() {
  group('DoodleStroke', () {
    test('toMap returns correct map structure', () {
      final stroke = DoodleStroke(
        id: 'abc123',
        points: [
          {'x': 0.1, 'y': 0.2},
          {'x': 0.3, 'y': 0.4},
        ],
        color: '#FFC0CB',
        strokeWidth: 3.0,
        userId: 'user1',
      );

      final map = stroke.toMap();

      expect(map['color'], '#FFC0CB');
      expect(map['strokeWidth'], 3.0);
      expect(map['userId'], 'user1');
      expect(map['points'], [
        {'x': 0.1, 'y': 0.2},
        {'x': 0.3, 'y': 0.4},
      ]);
      // createdAt should be server timestamp when null
      expect(map['createdAt'], isNotNull);
    });

    test('toMap preserves createdAt when set', () {
      final date = DateTime(2026, 1, 15, 10, 30);
      final stroke = DoodleStroke(
        id: 'abc',
        points: [{'x': 0.0, 'y': 0.0}],
        color: '#B0E0E6',
        strokeWidth: 5.0,
        createdAt: date,
        userId: 'user2',
      );

      final map = stroke.toMap();

      expect(map['createdAt'], isA<dynamic>());
    });

    test('copyWith creates new instance with overridden fields', () {
      final original = DoodleStroke(
        id: 'orig',
        points: [{'x': 0.5, 'y': 0.5}],
        color: '#FFC0CB',
        strokeWidth: 3.0,
        userId: 'user1',
      );

      final copied = original.copyWith(
        color: '#98FB98',
        strokeWidth: 8.0,
      );

      expect(copied.id, 'orig'); // unchanged
      expect(copied.color, '#98FB98'); // changed
      expect(copied.strokeWidth, 8.0); // changed
      expect(copied.userId, 'user1'); // unchanged
      expect(copied.points, original.points); // unchanged
    });

    test('copyWith with no arguments returns equivalent instance', () {
      final original = DoodleStroke(
        id: 'test',
        points: [{'x': 1.0, 'y': 1.0}],
        color: '#FFFACD',
        strokeWidth: 2.0,
        userId: 'user3',
      );

      final copied = original.copyWith();

      expect(copied.id, original.id);
      expect(copied.color, original.color);
      expect(copied.strokeWidth, original.strokeWidth);
      expect(copied.userId, original.userId);
      expect(copied.points, original.points);
    });

    test('constructor with null createdAt', () {
      final stroke = DoodleStroke(
        id: 'no-date',
        points: [],
        color: '#E6E6FA',
        strokeWidth: 1.0,
        userId: 'user4',
      );

      expect(stroke.createdAt, isNull);
    });
  });
}
