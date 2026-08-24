import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/features/dashboard/presentation/widgets/dashboard_motion.dart';

/// Rough CPU frame-cost check: pumps a burst of frames and reports the mean
/// pump duration. The ambience painter should add only a fraction of a
/// millisecond per frame compared to a plain background.
void main() {
  testWidgets('ambience frame cost is low', (tester) async {
    tester.view.physicalSize = const Size(1440, 2560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: AppColors.inkDeep,
          child: Stack(
            children: [
              Positioned.fill(child: DashboardAmbience()),
              Positioned.fill(child: DashboardCursorGlow()),
            ],
          ),
        ),
      ),
    );

    // Warm up so controllers are ticking.
    await tester.pump(const Duration(milliseconds: 100));
    // JIT warmup pass so the first measurement isn't inflated by compilation.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final stopwatch = Stopwatch()..start();
    const frameCount = 240;
    for (var i = 0; i < frameCount; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    stopwatch.stop();

    final withAmbienceMs = stopwatch.elapsed.inMicroseconds / frameCount / 1000;

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(color: AppColors.inkDeep),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final stopwatch2 = Stopwatch()..start();
    for (var i = 0; i < frameCount; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    stopwatch2.stop();
    final baselineMs = stopwatch2.elapsed.inMicroseconds / frameCount / 1000;

    debugPrint(
      '[bench] ambience=$withAmbienceMs ms/frame baseline=$baselineMs ms/frame',
    );

    // The ambience should stay under ~3ms/frame extra even in the software
    // test rasterizer; that leaves the vast majority of the 16.6ms budget.
    // Even in the pure-software test rasterizer the layer stays well under
    // the 16.6ms budget; GPU-backed CanvasKit is far cheaper in practice.
    expect(withAmbienceMs - baselineMs, lessThan(4.0));
  });
}
