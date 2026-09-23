import 'package:everglow/features/dashboard/presentation/widgets/dashboard_load_veil.dart';
import 'package:everglow/features/entry/presentation/pages/gateway_page.dart';
import 'package:everglow/features/entry/presentation/state/gateway_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gateway exposes the passphrase field immediately', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GatewayPage()));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('couple passphrase requires a server verifier', (tester) async {
    final notifier = GatewayNotifier()
      ..updateInput('this long phrase is unverified')
      ..submit();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(notifier.currentState, GatewayState.awaitingInput);
  });

  testWidgets('server-verified passphrase unlocks', (tester) async {
    final notifier = GatewayNotifier();
    notifier.verifyCouplePasscode = (_) async => 'khentsgdz';
    notifier.updateInput('a valid server passphrase');
    notifier.submit();
    await tester.pump(const Duration(milliseconds: 700));

    expect(notifier.currentState, GatewayState.unlocking);
  });

  testWidgets('dashboard loader is not requested before unlock', (
    tester,
  ) async {
    DashboardLoadVeil.resetPasscodeLoaderRequest();
    expect(DashboardLoadVeil.hasPendingPasscodeLoaderRequest, isFalse);
    expect(DashboardLoadVeil.consumePasscodeLoaderRequest(), isFalse);
  });
}
