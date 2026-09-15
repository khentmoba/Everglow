import 'package:everglow/features/manga/presentation/katana/katana_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Skeletons paint on every manga tab switch while lists load, so they
  // must lay out cleanly (widget tests fail on overflow errors) on
  // both phone and desktop sizes.
  testWidgets('KatanaListSkeleton lays out on a phone screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390x844 logical.
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: KatanaListSkeleton(rows: 8))),
    );
    // Advance the shimmer pulse through a full cycle.
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(KatanaListSkeleton), findsOneWidget);
  });

  testWidgets('KatanaGenreGridSkeleton lays out on desktop', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: KatanaGenreGridSkeleton())),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(KatanaGenreGridSkeleton), findsOneWidget);
  });
}
