import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/shared/widgets/everglow/everglow_button.dart';
import 'package:everglow/shared/widgets/everglow/everglow_card.dart';

void main() {
  testWidgets('EverglowButton responds to pointer and keyboard activation', (
    tester,
  ) async {
    var activations = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: EverglowButton(
              label: 'Activate',
              onPressed: () => activations++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Activate'));
    expect(activations, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(activations, 2);
  });

  testWidgets('EverglowCard responds to pointer and keyboard activation', (
    tester,
  ) async {
    var activations = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: EverglowCard(
              semanticLabel: 'Open item',
              onTap: () => activations++,
              child: const SizedBox(width: 120, height: 80),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(EverglowCard));
    expect(activations, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(activations, 2);
  });
}
