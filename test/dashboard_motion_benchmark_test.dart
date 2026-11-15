import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/features/dashboard/presentation/widgets/dashboard_motion.dart';

void main() {
  const frameCount = 240;

  Future<double> measure(WidgetTester tester, Widget scene) async {
    await tester.pumpWidget(scene);
    await tester.pump(const Duration(milliseconds: 100));
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

    expect(cursorGlowOnly - baseline, lessThan(0.5));

    expect(ambienceOnly - baseline, lessThan(4.0));
    expect(both - ambienceOnly, lessThan(0.5));
  });
}
