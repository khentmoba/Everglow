import 'package:everglow/features/entry/presentation/state/gateway_state.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const khentPassphrase = 'khent correct horse battery';
  const clairPassphrase = 'clair correct horse battery';

  group('GatewayNotifier with configured passphrases', () {
    setUp(() {
      dotenv.loadFromString(
        envString:
            '''
OCTAGRAM_PASSCODE=8080
BREYAN_PASSCODE=9132
CLAIR_PASSCODE=$clairPassphrase
KHENT_PASSCODE=$khentPassphrase
''',
      );
    });

    tearDown(dotenv.clean);

    test('accepts text and enforces the maximum input length', () {
      final notifier = GatewayNotifier()
        ..updateInput('a' * 300)
        ..updateInput('private phrase');

      expect(notifier.currentInput, 'private phrase');
      expect(notifier.canSubmit, isFalse);
    });

    test('requires 16 characters for a couple passphrase', () {
      final notifier = GatewayNotifier()..updateInput('a' * 15);
      expect(notifier.canSubmit, isFalse);

      notifier.updateInput('a' * 16);
      expect(notifier.canSubmit, isTrue);
    });

    test('client cinema code unlocks without a server verifier', () async {
      final notifier = GatewayNotifier()
        ..updateInput('8080')
        ..submit();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(notifier.currentState, GatewayState.unlocking);
    });

    testWidgets('unknown passphrase errors and resets', (tester) async {
      final verifierCalled = <String>[];
      final notifier = GatewayNotifier()
        ..verifyCouplePasscode = (passphrase) async {
          verifierCalled.add(passphrase);
          return null;
        }
        ..updateInput('this passphrase is definitely wrong')
        ..submit();

      await tester.pump(const Duration(milliseconds: 1200));
      expect(verifierCalled, ['this passphrase is definitely wrong']);
      expect(notifier.currentState, GatewayState.awaitingInput);
      expect(notifier.currentInput, isEmpty);
      expect(notifier.lastFailureReason, GatewayFailureReason.invalidCode);
    });

    testWidgets('server-verified couple passphrase unlocks', (tester) async {
      final notifier = GatewayNotifier();
      notifier.verifyCouplePasscode = (passphrase) async {
        return passphrase == clairPassphrase ? 'clairjassen' : null;
      };
      notifier.updateInput(clairPassphrase);
      notifier.submit();

      await tester.pump(const Duration(milliseconds: 700));
      expect(notifier.currentState, GatewayState.unlocking);
      expect(notifier.lastEnteredPasscode, clairPassphrase);
    });

    testWidgets('offline remembered passphrase opens the saved copy', (
      tester,
    ) async {
      final notifier = GatewayNotifier();
      notifier.verifyCouplePasscode = (_) async {
        throw Exception('offline');
      };
      notifier.tryOfflineUnlock = (passphrase) {
        return passphrase == khentPassphrase ? 'khentsgdz' : null;
      };
      notifier.updateInput(khentPassphrase);
      notifier.submit();

      await tester.pump(const Duration(milliseconds: 700));
      expect(notifier.currentState, GatewayState.unlocking);
      expect(notifier.lastFailureReason, isNull);
    });

    testWidgets('offline wrong passphrase reports invalid, not connection', (
      tester,
    ) async {
      final notifier = GatewayNotifier();
      notifier.verifyCouplePasscode = (_) async {
        throw Exception('offline');
      };
      notifier.tryOfflineUnlock = (_) => null;
      notifier.updateInput('another sufficiently long phrase');
      notifier.submit();

      await tester.pump(const Duration(milliseconds: 1200));
      expect(notifier.lastFailureReason, GatewayFailureReason.invalidCode);
    });
  });

  group('GatewayNotifier without configured environment', () {
    setUp(dotenv.clean);
    tearDown(dotenv.clean);

    testWidgets('missing server verifier never unlocks a couple', (
      tester,
    ) async {
      final notifier = GatewayNotifier()
        ..updateInput('this is long enough but unverified')
        ..submit();

      await tester.pump(const Duration(milliseconds: 1200));
      expect(notifier.currentState, GatewayState.awaitingInput);
    });
  });
}
