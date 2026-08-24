import 'package:everglow/features/entry/presentation/state/gateway_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GatewayNotifier', () {
    test('starts in awaitingInput', () {
      final notifier = GatewayNotifier();
      expect(notifier.currentState, GatewayState.awaitingInput);
    });

    test('digits accumulate up to four', () {
      final notifier = GatewayNotifier();
      for (final d in ['1', '2', '3', '4', '5']) {
        notifier.appendDigit(d);
      }
      expect(notifier.currentInput, '1234');
    });

    test('digits ignored after fourth until cleared', () {
      final notifier = GatewayNotifier();
      for (final d in ['0', '9', '3', '8']) {
        notifier.appendDigit(d);
      }
      expect(notifier.currentInput, '0938');
      notifier.appendDigit('7');
      expect(notifier.currentInput, '0938');
    });

    test('backspace removes last digit', () {
      final notifier = GatewayNotifier();
      notifier.appendDigit('0');
      notifier.appendDigit('9');
      notifier.backspace();
      expect(notifier.currentInput, '0');
    });

    test('backspace does not go below zero digits', () {
      final notifier = GatewayNotifier();
      notifier.backspace();
      expect(notifier.currentInput, '');
    });

    test('clearInput resets the field', () {
      final notifier = GatewayNotifier();
      notifier.appendDigit('1');
      notifier.clearInput();
      expect(notifier.currentInput, '');
    });

    testWidgets('client cinema code unlocks without a server verifier wired', (
      tester,
    ) async {
      final notifier = GatewayNotifier();
      for (final d in ['8', '0', '8', '0']) {
        notifier.appendDigit(d);
      }
      await tester.pump(const Duration(milliseconds: 600));
      expect(notifier.currentState, GatewayState.unlocking);
    });

    testWidgets('unknown code errors and resets to awaitingInput', (
      tester,
    ) async {
      final verifierCalled = <String>[];
      final notifier = GatewayNotifier()
        ..verifyCouplePasscode = (passcode) async {
          verifierCalled.add(passcode);
          return null;
        };
      for (final d in ['9', '9', '9', '9']) {
        notifier.appendDigit(d);
      }
      await tester.pump(const Duration(milliseconds: 1200));
      expect(verifierCalled, contains('9999'));
      expect(notifier.currentState, GatewayState.awaitingInput);
      expect(notifier.currentInput, '');
    });

    testWidgets('server-verified couple passcode unlocks', (tester) async {
      final notifier = GatewayNotifier()
        ..verifyCouplePasscode = (passcode) async =>
            passcode == '0221' ? 'khentsgdz' : null;
      for (final d in ['0', '2', '2', '1']) {
        notifier.appendDigit(d);
      }
      await tester.pump(const Duration(milliseconds: 700));
      expect(notifier.currentState, GatewayState.unlocking);
      expect(notifier.lastEnteredPasscode, '0221');
    });
  });
}
