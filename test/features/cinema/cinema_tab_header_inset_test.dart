import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_nav_bar.dart';

Future<double> _insetFor(
  WidgetTester tester,
  Size size,
  EdgeInsets padding,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  late double inset;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, padding: padding),
        child: Builder(
          builder: (context) {
            inset = cinemaTopContentInset(context);
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return inset;
}

void main() {
  testWidgets('desktop content clears the floating navbar', (
    WidgetTester tester,
  ) async {
    const desktop = Size(1280, 800);

    expect(await _insetFor(tester, desktop, EdgeInsets.zero), 76);

    expect(
      await _insetFor(tester, desktop, const EdgeInsets.only(top: 24)),
      24 + kToolbarHeight + 20,
    );
  });

  testWidgets('mobile content only adds the status inset', (
    WidgetTester tester,
  ) async {
    const mobile = Size(390, 844);

    expect(await _insetFor(tester, mobile, EdgeInsets.zero), 12);

    expect(await _insetFor(tester, mobile, const EdgeInsets.only(top: 24)), 36);
  });
}
