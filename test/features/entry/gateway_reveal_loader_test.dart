import 'package:everglow/features/entry/presentation/widgets/reveal_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GatewayRevealLoader', () {
    Future<void> pumpLoader(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: GatewayRevealLoader())),
        ),
      );
    }

    testWidgets('streams 0% to 100% with a determinate bar', (tester) async {
      await pumpLoader(tester);

      expect(find.text('0%'), findsOneWidget);
      expect(find.text('EVERGLOW'), findsOneWidget);
      expect(find.text('loading your story…'), findsOneWidget);

      // Mid-stream the bar is determinate and climbing, never spinning.
      await tester.pump(const Duration(milliseconds: 500));
      final midBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(midBar.value, isNotNull);
      expect(midBar.value!, greaterThan(0.0));
      expect(midBar.value!, lessThan(1.0));

      // The door reveal lasts ~1100ms; the count lands on 100% just as
      // the dashboard veil takes over.
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('100%'), findsOneWidget);
      final endBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(endBar.value, 1.0);
    });
  });
}
