import 'package:everglow/features/entry/presentation/pages/gateway_page.dart';
import 'package:everglow/features/entry/presentation/state/gateway_state.dart';
import 'package:everglow/features/entry/presentation/widgets/passcode_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('passcode keypad is visible and tappable immediately', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GatewayPage()));

    // The keypad must be clickable from the first frame, even before the
    // door entrance animation finishes.
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.text('1'));
    await tester.pump(const Duration(milliseconds: 100));

    final input = tester.widget<PasscodeInput>(find.byType(PasscodeInput));
    expect(input.input, '1');
  });

  testWidgets('keypad remains after the entrance animation completes', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GatewayPage()));

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('documented passcode 0938 unlocks the gateway notifier', (
    tester,
  ) async {
    final notifier = GatewayNotifier();
    for (final digit in ['0', '9', '3', '8']) {
      notifier.appendDigit(digit);
    }
    await tester.pump(const Duration(milliseconds: 700));
    expect(notifier.currentState, GatewayState.unlocking);
  });
}
