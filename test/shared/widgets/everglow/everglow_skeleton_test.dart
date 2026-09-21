import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/shared/widgets/everglow/everglow_skeleton.dart';

void main() {
  setUp(() {
    EverglowShimmerScope.resetForTesting();
  });

  tearDown(() {
    EverglowShimmerScope.resetForTesting();
  });

  testWidgets('EverglowShimmerScope shares a single controller across multiple skeletons',
      (tester) async {
    expect(EverglowShimmerScope.activeCount, 0);
    expect(EverglowShimmerScope.controller, isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              EverglowSkeleton(width: 100, height: 20),
              EverglowSkeleton(width: 150, height: 20),
              EverglowSkeleton(width: 200, height: 20),
            ],
          ),
        ),
      ),
    );

    // 3 skeletons mounted -> exactly 1 shared controller, activeCount is 3
    expect(EverglowShimmerScope.activeCount, 3);
    expect(EverglowShimmerScope.controller, isNotNull);
    final sharedController = EverglowShimmerScope.controller;

    // Pump frames to advance shimmer
    await tester.pump(const Duration(milliseconds: 100));
    expect(EverglowShimmerScope.controller, same(sharedController));

    // Unmount all skeletons
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));

    // Controller disposed, activeCount back to 0
    expect(EverglowShimmerScope.activeCount, 0);
    expect(EverglowShimmerScope.controller, isNull);
  });

  testWidgets('EverglowSkeleton respects reduceMotion by skipping shimmer',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EverglowSkeleton(width: 100, height: 20),
        ),
      ),
    );

    expect(EverglowShimmerScope.activeCount, 0);
    expect(EverglowShimmerScope.controller, isNull);
  });

  testWidgets('EverglowSkeletonRow and Grid mount properly with shared shimmer',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                EverglowSkeletonRow(count: 4),
                EverglowSkeletonGrid(count: 6),
              ],
            ),
          ),
        ),
      ),
    );

    expect(EverglowShimmerScope.activeCount, 10);
    expect(EverglowShimmerScope.controller, isNotNull);

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    expect(EverglowShimmerScope.activeCount, 0);
  });
}
