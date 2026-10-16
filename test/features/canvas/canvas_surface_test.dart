import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/canvas/presentation/widgets/canvas_painter.dart';
import 'package:everglow/features/canvas/domain/models/doodle_stroke.dart';

void main() {
  testWidgets('pen movement repaints without rebuilding or replacing history', (
    tester,
  ) async {
    final active = ValueNotifier<DoodleStroke?>(null);
    final strokes = <DoodleStroke>[];
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (_) {
              builds++;
              return CanvasSurface(strokes: strokes, active: active);
            },
          ),
        ),
      ),
    );
    final paints = find.descendant(
      of: find.byType(CanvasSurface),
      matching: find.byType(CustomPaint),
    );
    final before = tester
        .widgetList<CustomPaint>(paints)
        .map((w) => w.painter)
        .toList();
    for (var i = 1; i <= 30; i++) {
      active.value = DoodleStroke(
        id: '',
        userId: 'demo',
        color: '#FFC0CB',
        strokeWidth: 3,
        points: [
          {'x': 0.1, 'y': 0.1},
          {'x': i / 30, 'y': 0.8},
        ],
      );
      await tester.pump();
    }
    expect(builds, 1);
    final after = tester
        .widgetList<CustomPaint>(paints)
        .map((w) => w.painter)
        .toList();
    expect(identical(before.first, after.first), isTrue);
    expect(identical(before.last, after.last), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    active.dispose();
    expect(tester.takeException(), isNull);
  });
}
