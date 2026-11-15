import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/dashboard/presentation/widgets/metric_card.dart';

Widget _card(Size screen, int value) => MediaQuery(
  data: MediaQueryData(size: screen),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: MetricCard(label: 'SECONDS', value: value, isLive: true),
  ),
);

void main() {
  testWidgets('a ticking number does not animate on phones', (tester) async {
    const phone = Size(430, 932);
    await tester.pumpWidget(_card(phone, 1));
    await tester.pumpWidget(_card(phone, 2));
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('01'), findsNothing);
  });

  testWidgets('a ticking number still animates on tablets', (tester) async {
    const tablet = Size(1024, 1366);
    await tester.pumpWidget(_card(tablet, 1));
    await tester.pumpWidget(_card(tablet, 2));
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('01'), findsNothing);
  });
}
