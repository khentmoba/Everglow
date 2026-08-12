import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/features/dashboard/presentation/widgets/dashboard_motion.dart';

void main() {
  testWidgets('ambience layer renders and animates', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: AppColors.inkDeep,
          child: Stack(
            children: const [
              Positioned.fill(child: DashboardAmbience()),
              Positioned.fill(child: DashboardCursorGlow()),
            ],
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byType(DashboardAmbience),
      matchesGoldenFile('goldens/ambience_a.png'),
    );

    await tester.pump(const Duration(milliseconds: 700));
    await expectLater(
      find.byType(DashboardAmbience),
      matchesGoldenFile('goldens/ambience_b.png'),
    );
  });

  testWidgets('header motion widgets render and animate', (tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: AppColors.inkDeep,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BreathingEmblem(
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.velvet,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ShimmerTitle(
                  child: Text(
                    'Forever In Bloom',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: AppColors.petalWhite,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const PulseHeart(
                  child: Icon(
                    Icons.favorite_rounded,
                    color: AppColors.auroraRose,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(Column),
      matchesGoldenFile('goldens/header_a.png'),
    );

    await tester.pump(const Duration(milliseconds: 900));
    await expectLater(
      find.byType(Column),
      matchesGoldenFile('goldens/header_b.png'),
    );
  });

  testWidgets('cursor glow paints under hover', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: AppColors.inkDeep,
          child: Stack(
            children: [
              Positioned.fill(child: DashboardCursorGlow()),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await gesture.addPointer(location: const Offset(120, 200));
    addTearDown(gesture.removePointer);
    await gesture.moveTo(const Offset(320, 260));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(const Offset(420, 330));
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
  });
}
