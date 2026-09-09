import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/dashboard/presentation/widgets/anniversary_metrics.dart';
import 'package:everglow/features/dashboard/presentation/widgets/metric_card.dart';

void main() {
  testWidgets('AnniversaryMetrics renders all elements and keepsakes clock cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              AnniversaryMetrics(animate: false),
            ],
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify eyebrow pills
    expect(find.text('TIME TOGETHER'), findsOneWidget);

    // Verify hero section
    expect(find.text('YEARS TOGETHER'), findsOneWidget);
    expect(find.text('since Feb 14, 2026'), findsOneWidget);

    // Verify counter labels
    expect(find.text('MONTHS'), findsOneWidget);
    expect(find.text('DAYS'), findsOneWidget);
    expect(find.text('HOURS'), findsOneWidget);
    expect(find.text('MINUTES'), findsOneWidget);
    expect(find.text('SECONDS'), findsOneWidget);

    // Verify bottom seal ribbon
    expect(find.textContaining('days of us'), findsOneWidget);
  });

  testWidgets('MetricCard flat and standalone renders without layout error', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MetricCard(label: 'Months', value: 6, flat: true),
              MetricCard(label: 'Seconds', value: 42, isLive: true, flat: false),
            ],
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('06'), findsOneWidget);
    expect(find.text('MONTHS'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('SECONDS'), findsOneWidget);
  });
}
