import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/dashboard/presentation/widgets/dashboard_zone_header.dart';

Future<void> _pumpPair(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DashboardPair(
          left: Container(
            key: const Key('left'),
            height: 100,
            color: Colors.red,
          ),
          right: Container(
            key: const Key('right'),
            height: 100,
            color: Colors.blue,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('DashboardPair stacks vertically on a 360px phone', (
    tester,
  ) async {
    await _pumpPair(tester, const Size(360, 800));
    expect(find.byType(Row), findsNothing);
    final leftTop = tester.getTopLeft(find.byKey(const Key('left'))).dy;
    final rightTop = tester.getTopLeft(find.byKey(const Key('right'))).dy;
    expect(rightTop, greaterThan(leftTop));
  });

  testWidgets('DashboardPair sits side by side on a 700px tablet', (
    tester,
  ) async {
    await _pumpPair(tester, const Size(700, 900));
    expect(find.byType(Row), findsOneWidget);
    final left = tester.getRect(find.byKey(const Key('left')));
    final right = tester.getRect(find.byKey(const Key('right')));
    expect(right.left, greaterThan(left.left));
    expect(left.top, equals(right.top));
  });

  testWidgets('DashboardPair sits side by side on an 810px tablet', (
    tester,
  ) async {
    await _pumpPair(tester, const Size(810, 1080));
    expect(find.byType(Row), findsOneWidget);
    final left = tester.getRect(find.byKey(const Key('left')));
    final right = tester.getRect(find.byKey(const Key('right')));
    expect(right.left, greaterThan(left.left));
  });
}
