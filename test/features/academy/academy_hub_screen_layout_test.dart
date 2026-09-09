import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/academy/screens/academy_hub_screen.dart';

Widget _card() {
  return AcademyModeCard(
    title: 'A Very Long Academy Mode Title That Must Ellipsize Instead Of Overflowing',
    subtitle:
        'An extra long subtitle line that exercises wrapping on narrow phone screens for Clair',
    badge: 'LIVE \u00b7 TOGETHER',
    icon: Icons.bolt_rounded,
    accent: Colors.pink,
    onTap: () {},
  );
}

Future<void> _pump(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [_card(), _card()],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('AcademyModeCard has no overflow on a 360px phone', (
    tester,
  ) async {
    await _pump(tester, const Size(360, 800));
    final first = tester.getRect(find.byType(AcademyModeCard).first);
    expect(first.right, lessThanOrEqualTo(360.1));
  });

  testWidgets('AcademyModeCard has no overflow on an 810px tablet', (
    tester,
  ) async {
    await _pump(tester, const Size(810, 1080));
    final first = tester.getRect(find.byType(AcademyModeCard).first);
    expect(first.right, lessThanOrEqualTo(810.1));
  });
}
