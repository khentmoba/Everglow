import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/features/dashboard/presentation/widgets/dashboard_motion.dart';

/// Rough per-frame cost check for the dashboard's ambient layers.
///
/// Pumps a burst of frames and reports the mean pump duration for each layer on
/// its own, so the report says *which* layer costs what. This runs against the
/// software test rasterizer, so the absolute numbers are not phone numbers —
/// but they are a fair relative measure of recording + draw work, and they are
/// the same measurement across runs, which is what makes them a regression
/// guard.
///
/// Two things this pins down:
/// * `DashboardCursorGlow` must be free while no pointer is hovering. It used
///   to start its ticker at init, which scheduled a frame 60x/sec forever on a
///   phone where hover never happens.
/// * `DashboardAmbience` must stay a small fraction of the 16.6ms budget, and
///   must not allocate its aurora paints/shaders on every frame.
void main() {
  const frameCount = 240;

  Future<double> measure(WidgetTester tester, Widget scene) async {
    await tester.pumpWidget(scene);
    // Warm up so controllers are ticking.
    await tester.pump(const Duration(milliseconds: 100));
    // JIT warmup pass so the first measurement isn't inflated by compilation.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < frameCount; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    stopwatch.stop();

    return stopwatch.elapsed.inMicroseconds / frameCount / 1000;
  }

  Widget scene(List<Widget> layers) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ColoredBox(
      color: AppColors.inkDeep,
      child: Stack(
        children: [
          for (final layer in layers) Positioned.fill(child: layer),
        ],
      ),
    ),
  );

  testWidgets('ambient layers stay cheap per frame', (tester) async {
    tester.view.physicalSize = const Size(1440, 2560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final baseline = await measure(tester, scene(const []));
    final ambienceOnly = await measure(
      tester,
      scene(const [DashboardAmbience()]),
    );
    final cursorGlowOnly = await measure(
      tester,
      scene(const [DashboardCursorGlow()]),
    );
    final both = await measure(
      tester,
      scene(const [DashboardAmbience(), DashboardCursorGlow()]),
    );

    debugPrint(
      '[bench] baseline=${baseline.toStringAsFixed(3)} '
      'ambience=${ambienceOnly.toStringAsFixed(3)} '
      'cursorGlow=${cursorGlowOnly.toStringAsFixed(3)} '
      'both=${both.toStringAsFixed(3)} ms/frame',
    );

    // Nothing to draw without a pointer: the glow must not schedule frames.
    // A little slack covers test-harness noise, not a ticking layer.
    expect(cursorGlowOnly - baseline, lessThan(0.5));

    // The ambience stays a small slice of the frame budget, and adding the
    // (idle) glow layer on top must not meaningfully raise it.
    expect(ambienceOnly - baseline, lessThan(4.0));
    expect(both - ambienceOnly, lessThan(0.5));
  });
}
