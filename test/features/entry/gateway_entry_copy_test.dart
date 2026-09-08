import 'package:everglow/features/entry/presentation/state/gateway_state.dart';
import 'package:everglow/features/entry/presentation/widgets/passcode_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(PasscodeInput input) {
  return MaterialApp(home: Scaffold(body: Center(child: input)));
}

void main() {
  group('GatewayNotifier failure reasons', () {
    testWidgets('wrong code keeps invalidCode reason after auto-reset',
        (tester) async {
      final notifier = GatewayNotifier()
        ..verifyCouplePasscode = (_) async => null;
      for (final d in ['1', '2', '3', '4']) {
        notifier.appendDigit(d);
      }
      await tester.pump(const Duration(milliseconds: 1200));
      expect(notifier.currentState, GatewayState.awaitingInput);
      expect(notifier.currentInput, '');
      expect(notifier.lastFailureReason, GatewayFailureReason.invalidCode);
    });

    testWidgets('throwing verifier keeps connection reason after auto-reset',
        (tester) async {
      final notifier = GatewayNotifier()
        ..verifyCouplePasscode = (_) async {
          throw Exception('offline');
        };
      for (final d in ['1', '2', '3', '4']) {
        notifier.appendDigit(d);
      }
      await tester.pump(const Duration(milliseconds: 1200));
      expect(notifier.currentState, GatewayState.awaitingInput);
      expect(notifier.lastFailureReason, GatewayFailureReason.connection);
    });

    testWidgets('new digit clears the failure reason', (tester) async {
      final notifier = GatewayNotifier()
        ..verifyCouplePasscode = (_) async => null;
      for (final d in ['1', '2', '3', '4']) {
        notifier.appendDigit(d);
      }
      await tester.pump(const Duration(milliseconds: 1200));
      expect(notifier.lastFailureReason, isNotNull);
      notifier.appendDigit('5');
      expect(notifier.lastFailureReason, isNull);
      expect(notifier.currentInput, '5');
    });
  });

  group('PasscodeInput entry copy + states', () {
    testWidgets('shows private-place header and progress count',
        (tester) async {
      await tester.pumpWidget(_wrap(PasscodeInput(
        input: '12',
        onDigitPressed: (_) {},
        onBackspace: () {},
      )));
      await tester.pump();
      expect(
        find.text('Your private place for Khent & Clair'),
        findsOneWidget,
      );
      expect(find.text('Enter your 4-digit passcode'), findsOneWidget);
      expect(find.text('2 of 4'), findsOneWidget);
    });

    testWidgets('shows verifying state and disables visual emphasis',
        (tester) async {
      await tester.pumpWidget(_wrap(PasscodeInput(
        input: '1234',
        isVerifying: true,
        onDigitPressed: (_) {},
        onBackspace: () {},
      )));
      await tester.pump();
      expect(find.text('Opening your space…'), findsOneWidget);
      // Progress count is replaced while verifying.
      expect(find.text('4 of 4'), findsNothing);
    });

    testWidgets('shows wrong-code message', (tester) async {
      await tester.pumpWidget(_wrap(PasscodeInput(
        input: '',
        isError: true,
        failureReason: GatewayFailureReason.invalidCode,
        onDigitPressed: (_) {},
        onBackspace: () {},
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('That code didn’t open Everglow. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('shows connection message', (tester) async {
      await tester.pumpWidget(_wrap(PasscodeInput(
        input: '',
        isError: true,
        failureReason: GatewayFailureReason.connection,
        onDigitPressed: (_) {},
        onBackspace: () {},
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text(
          'Everglow couldn’t connect. Check your connection and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('key buttons expose keyboard focus nodes', (tester) async {
      await tester.pumpWidget(_wrap(PasscodeInput(
        input: '',
        onDigitPressed: (_) {},
        onBackspace: () {},
      )));
      await tester.pump();
      // Every key is wrapped in a Focus so Tab + Enter/Space works.
      // 10 digits + backspace = 11 focusable keys.
      final focusWidgets = tester.widgetList<Focus>(find.byType(Focus));
      // Includes the outer pad Focus plus 11 key Focus nodes.
      expect(focusWidgets.length, greaterThanOrEqualTo(12));
    });
  });
}
