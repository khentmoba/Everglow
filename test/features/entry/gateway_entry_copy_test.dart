import 'package:everglow/features/entry/presentation/state/gateway_state.dart';
import 'package:everglow/features/entry/presentation/widgets/passcode_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(PasscodeInput input) {
  return MaterialApp(
    home: Scaffold(body: Center(child: input)),
  );
}

void main() {
  group('GatewayNotifier failure reasons', () {
    testWidgets('wrong passphrase keeps invalid reason after reset', (
      tester,
    ) async {
      final notifier = GatewayNotifier();
      notifier.verifyCouplePasscode = (_) async => null;
      notifier.updateInput('this passphrase is wrong');
      notifier.submit();

      await tester.pump(const Duration(milliseconds: 1200));
      expect(notifier.currentState, GatewayState.awaitingInput);
      expect(notifier.currentInput, isEmpty);
      expect(notifier.lastFailureReason, GatewayFailureReason.invalidCode);
    });

    testWidgets('throwing verifier keeps connection reason', (tester) async {
      final notifier = GatewayNotifier();
      notifier.verifyCouplePasscode = (_) async {
        throw Exception('offline');
      };
      notifier.tryOfflineUnlock = (_) => null;
      notifier.updateInput('a valid length offline phrase');
      notifier.submit();

      await tester.pump(const Duration(milliseconds: 1200));
      expect(notifier.lastFailureReason, GatewayFailureReason.connection);
    });

    testWidgets('new input clears the previous failure', (tester) async {
      final notifier = GatewayNotifier();
      notifier.verifyCouplePasscode = (_) async => null;
      notifier.updateInput('this passphrase is wrong');
      notifier.submit();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(notifier.lastFailureReason, GatewayFailureReason.invalidCode);

      notifier.updateInput('another');
      expect(notifier.lastFailureReason, isNull);
    });
  });

  group('PassphraseInput', () {
    testWidgets('shows progress and exposes accessible entry', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PasscodeInput(
            input: 'twelve chars',
            onChanged: (_) {},
            onSubmit: () {},
            canSubmit: false,
          ),
        ),
      );

      expect(find.text('12 / 16+ characters'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Passphrase entry for Khent and Clair',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows verifying state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PasscodeInput(
            input: 'a valid passphrase',
            onChanged: (_) {},
            onSubmit: () {},
            canSubmit: true,
            isVerifying: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Opening your space...'), findsOneWidget);
    });

    testWidgets('shows wrong-passphrase error', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PasscodeInput(
            input: '',
            onChanged: (_) {},
            onSubmit: () {},
            canSubmit: false,
            isError: true,
            failureReason: GatewayFailureReason.invalidCode,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('That passphrase did not open Everglow. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('can reveal the private passphrase', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PasscodeInput(
            input: 'private phrase',
            onChanged: (_) {},
            onSubmit: () {},
            canSubmit: false,
          ),
        ),
      );

      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      await tester.tap(find.byTooltip('Show passphrase'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
    });
  });
}
