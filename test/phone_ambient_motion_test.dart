import 'package:everglow/features/anime/presentation/widgets/animex/animex_skeleton.dart';
import 'package:everglow/features/dashboard/presentation/widgets/dashboard_motion.dart';
import 'package:everglow/shared/widgets/everglow/everglow_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phone backdrop is still; tablet motion returns after resizing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(828, 1792);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(child: DashboardAmbience()),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BreathingEmblem(child: Text('Everglow')),
                  ShimmerTitle(child: Text('Forever In Bloom')),
                  PulseHeart(child: Text('Heart')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.descendant(
        of: find.byType(DashboardAmbience),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(tester.binding.hasScheduledFrame, isFalse);

    tester.view.physicalSize = const Size(1620, 2160);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.binding.hasScheduledFrame, isTrue);

    // Landscape phone remains light and stops the existing tablet ticker.
    tester.view.physicalSize = const Size(1792, 828);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('phone loading placeholders do not attach animation clocks', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(828, 1792);
    addTearDown(tester.view.reset);
    addTearDown(EverglowShimmerScope.resetForTesting);
    await tester.pumpWidget(
      const MaterialApp(
        home: SingleChildScrollView(
          child: Column(children: [EverglowSkeletonRow(), AnimeXSkeletonRow()]),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(EverglowShimmerScope.activeCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
