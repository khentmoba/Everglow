import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/money/presentation/widgets/add_money_dialog.dart';
import 'package:everglow/shared/widgets/everglow/everglow_button.dart';

void main() {
  testWidgets('failed spending save retains the draft and lets Clair retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showAddMoneyDialog(
                  context,
                  onSave: (_) async {
                    attempts++;
                    if (attempts == 1) throw StateError('offline');
                  },
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '250');
    await tester.enterText(find.byType(TextField).last, 'Demo coffee');
    await tester.tap(find.widgetWithText(EverglowButton, 'Log spending'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your entry is still here'), findsOneWidget);
    expect(find.text('250'), findsOneWidget);
    expect(find.text('Demo coffee'), findsOneWidget);
    await tester.tap(find.widgetWithText(EverglowButton, 'Log spending'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Add money'), findsNothing);
  });

  testWidgets('failed budget save retains its amount and can be retried', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showSetBudgetDialog(
                  context,
                  'Food',
                  onSave: (_) async {
                    attempts++;
                    if (attempts == 1) throw StateError('offline');
                  },
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1000');
    await tester.tap(find.widgetWithText(EverglowButton, 'Save budget'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save this budget'), findsOneWidget);
    expect(find.text('1000'), findsOneWidget);
    await tester.tap(find.widgetWithText(EverglowButton, 'Save budget'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(Dialog), findsNothing);
  });
}
