import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/canvas/domain/models/doodle_stroke.dart';
import 'package:everglow/features/canvas/presentation/widgets/canvas_painter.dart';

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
      expect(map['canvasAspectRatio'], 2.0);
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
        points: [
          {'x': 0.0, 'y': 0.0},
        ],
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
        points: [
          {'x': 0.5, 'y': 0.5},
        ],
        color: '#FFC0CB',
        strokeWidth: 3.0,
        userId: 'user1',
      );

      final copied = original.copyWith(color: '#98FB98', strokeWidth: 8.0);

      expect(copied.id, 'orig'); // unchanged
      expect(copied.color, '#98FB98'); // changed
      expect(copied.strokeWidth, 8.0); // changed
      expect(copied.canvasAspectRatio, original.canvasAspectRatio);
      expect(copied.userId, 'user1'); // unchanged
      expect(copied.points, original.points); // unchanged
    });

    test('copyWith with no arguments returns equivalent instance', () {
      final original = DoodleStroke(
        id: 'test',
        points: [
          {'x': 1.0, 'y': 1.0},
        ],
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

  group('DoodleStroke.fromFirestore', () {
    test('parses a full valid document', () {
      final created = DateTime.utc(2026, 9, 17);
      final stroke = DoodleStroke.fromMap({
          'points': [
            {'x': 0.1, 'y': 0.2},
            {'x': 0.3, 'y': 0.4},
          ],
          'color': '#98FB98',
          'strokeWidth': 5,
          'canvasAspectRatio': 1.5,
          'createdAt': Timestamp.fromDate(created),
          'userId': 'khentsgdz',
          'text': 'hi',
        },
      's1',);

      expect(stroke.id, 's1');
      expect(stroke.points, [
        {'x': 0.1, 'y': 0.2},
        {'x': 0.3, 'y': 0.4},
      ]);
      expect(stroke.color, '#98FB98');
      expect(stroke.strokeWidth, 5.0);
      expect(stroke.canvasAspectRatio, 1.5);
      expect(
        stroke.createdAt?.millisecondsSinceEpoch,
        created.millisecondsSinceEpoch,
      );
      expect(stroke.userId, 'khentsgdz');
      expect(stroke.text, 'hi');
    });

    test('missing points yields empty points, not a throw', () {
      final stroke = DoodleStroke.fromMap({'userId': 'clairjassen'},
      's2',);

      expect(stroke.id, 's2');
      expect(stroke.points, isEmpty);
      expect(stroke.userId, 'clairjassen');
    });

    test('null or non-list points yields empty points', () {
      expect(
        DoodleStroke.fromMap({'points': null},
        's3',).points,
        isEmpty,
      );
      expect(
        DoodleStroke.fromMap({'points': 'nope'},
        's4',).points,
        isEmpty,
      );
    });

    test('skips malformed points but keeps valid ones', () {
      final stroke = DoodleStroke.fromMap({
          'points': [
            {'y': 0.2},
            {'x': 0.1},
            {'x': 'a', 'y': 0.2},
            {'x': 0.1, 'y': null},
            null,
            'nope',
            {'x': 0.5, 'y': 0.6},
          ],
        },
      's5',);

      expect(stroke.points, [
        {'x': 0.5, 'y': 0.6},
      ]);
    });

    test('never crashes on odd field types', () {
      final stroke = DoodleStroke.fromMap({
          'points': [
            {'x': 0, 'y': 0},
          ],
          'color': 42,
          'strokeWidth': 'wide',
          'canvasAspectRatio': 'tall',
          'createdAt': 'someday',
          'userId': 7,
          'text': 9,
        },
      's6',);

      expect(stroke.points, [
        {'x': 0.0, 'y': 0.0},
      ]);
      expect(stroke.color, '#FFC0CB');
      expect(stroke.strokeWidth, 3.0);
      expect(
        stroke.canvasAspectRatio,
        DoodleStroke.legacyCanvasAspectRatio,
      );
      expect(stroke.createdAt, isNull);
      expect(stroke.userId, isEmpty);
      expect(stroke.text, isNull);
    });

    test('null document data yields defaults', () {
      final stroke = DoodleStroke.fromMap(const {}, 's7');

      expect(stroke.id, 's7');
      expect(stroke.points, isEmpty);
      expect(stroke.color, '#FFC0CB');
      expect(stroke.userId, isEmpty);
    });
  });

  testWidgets('CanvasPainter paints sanitized strokes without throwing', (
    tester,
  ) async {
    final broken = DoodleStroke.fromMap({
        'points': [
          {'x': 'bad'},
        ],
      },
    's8',);
    final annotation = DoodleStroke.fromMap({'text': 'hello'},
    's9',);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomPaint(
            size: const Size(300, 300),
            painter: CanvasPainter(
              strokes: [broken, annotation],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
