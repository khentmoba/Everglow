import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/dashboard/presentation/widgets/creator_modal.dart';

void main() {
  testWidgets('every creator tab has a matching panel', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SafeArea(child: CreatorModal())),
      ),
    );

    expect(find.text('System Tools'), findsNothing);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();

    expect(find.text('System Tools'), findsOneWidget);
  });
}
