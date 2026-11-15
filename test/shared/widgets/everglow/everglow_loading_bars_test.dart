import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/shared/widgets/everglow/everglow_skeleton.dart';

void main() {
  tearDown(EverglowShimmerScope.resetForTesting);

  testWidgets('EverglowLoadingBars renders 3 animated skeletons', (tester) async {
    EverglowShimmerScope.resetForTesting();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EverglowLoadingBars())),
    );
    await tester.pump();

    expect(find.byType(EverglowLoadingBars), findsOneWidget);
    expect(find.byType(EverglowSkeleton), findsNWidgets(3));
    expect(EverglowShimmerScope.activeCount, 3);
    expect(EverglowShimmerScope.controller, isNotNull);
  });

  testWidgets('EverglowLoadingChips renders 3 pill skeletons', (tester) async {
    EverglowShimmerScope.resetForTesting();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EverglowLoadingChips())),
    );
    await tester.pump();

    expect(find.byType(EverglowLoadingChips), findsOneWidget);
    expect(find.byType(EverglowSkeleton), findsNWidgets(3));
    expect(EverglowShimmerScope.activeCount, 3);
  });

  testWidgets('EverglowLoadingBars respects custom widths', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EverglowLoadingBars(widthFactors: [1.0, 0.5]),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(EverglowSkeleton), findsNWidgets(2));
  });
}
