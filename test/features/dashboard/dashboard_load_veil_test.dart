import 'package:everglow/features/dashboard/presentation/widgets/dashboard_load_veil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  setUp(() {
    DashboardLoadVeil.resetPasscodeLoaderRequest();
  });

  tearDown(() {
    DashboardLoadVeil.resetPasscodeLoaderRequest();
  });

  group('DashboardLoadVeil request state', () {
    test(
      'consumePasscodeLoaderRequest returns true only once after request',
      () {
        expect(DashboardLoadVeil.hasPendingPasscodeLoaderRequest, isFalse);
        expect(DashboardLoadVeil.consumePasscodeLoaderRequest(), isFalse);

        DashboardLoadVeil.requestPasscodeLoader();
        expect(DashboardLoadVeil.hasPendingPasscodeLoaderRequest, isTrue);

        expect(DashboardLoadVeil.consumePasscodeLoaderRequest(), isTrue);
        expect(DashboardLoadVeil.hasPendingPasscodeLoaderRequest, isFalse);
        expect(DashboardLoadVeil.consumePasscodeLoaderRequest(), isFalse);
      },
    );

    test('labelForPercent maps percentages to warm progression labels', () {
      expect(DashboardLoadVeil.labelForPercent(1), 'opening the door…');
      expect(DashboardLoadVeil.labelForPercent(10), 'opening the door…');
      expect(DashboardLoadVeil.labelForPercent(25), 'gathering memories…');
      expect(DashboardLoadVeil.labelForPercent(45), 'checking your dates…');
      expect(DashboardLoadVeil.labelForPercent(67), 'unsealing letters…');
      expect(DashboardLoadVeil.labelForPercent(80), 'waking the garden…');
      expect(DashboardLoadVeil.labelForPercent(95), 'counting your stars…');
      expect(DashboardLoadVeil.labelForPercent(100), 'opening your story…');
    });
  });

  group('DashboardLoadVeil widget', () {
    testWidgets('renders initial 1% progress and climbs smoothly', (
      tester,
    ) async {
      var completed = false;
      await tester.pumpWidget(
        _wrap(
          DashboardLoadVeil(
            visible: true,
            duration: const Duration(milliseconds: 1000),
            onComplete: () => completed = true,
          ),
        ),
      );

      // Initial frame: 1%, opening door label, heart icon, and EVERGLOW title
      expect(find.text('EVERGLOW'), findsOneWidget);
      expect(find.text('1%'), findsOneWidget);
      expect(find.text('opening the door…'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final initialIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(initialIndicator.value, closeTo(0.01, 0.005));

      // Pump halfway (500ms into 1000ms): percent should be climbing
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('1%'), findsNothing);

      final midIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(midIndicator.value, greaterThan(0.2));
      expect(midIndicator.value, lessThan(0.9));

      // Pump to completion (another 500ms for animation + 250ms for hold)
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('opening your story…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      expect(completed, isTrue);
    });

    testWidgets('Skip button immediately triggers onSkip', (tester) async {
      var skipped = false;
      await tester.pumpWidget(
        _wrap(
          DashboardLoadVeil(
            visible: true,
            duration: const Duration(seconds: 5),
            onSkip: () => skipped = true,
          ),
        ),
      );

      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pump();

      expect(skipped, isTrue);
    });

    testWidgets('when visible is false, veil is hidden and ignores pointer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(DashboardLoadVeil(visible: false, onSkip: () {})),
      );

      final ignorePointer = tester.widget<IgnorePointer>(
        find
            .descendant(
              of: find.byType(DashboardLoadVeil),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(ignorePointer.ignoring, isTrue);

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(animatedOpacity.opacity, 0.0);
    });
  });
}
