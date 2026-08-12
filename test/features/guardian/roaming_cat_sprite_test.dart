import 'package:everglow/features/guardian/presentation/widgets/roaming/roaming_cat_sprite.dart';
import 'package:everglow/features/guardian/presentation/widgets/roaming/roaming_guardian_cat.dart';
import 'package:everglow/features/guardian/presentation/widgets/roaming/roaming_guardian_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RoamingCatFrame frame({
    double elapsed = 0,
    double facing = 1,
    RoamingActivity activity = RoamingActivity.wandering,
    bool moving = true,
  }) {
    return RoamingCatFrame(
      catSize: 96,
      held: false,
      hovered: false,
      turning: false,
      moving: moving,
      bob: 3,
      breath: 1,
      scale: 1,
      facing: facing,
      activity: activity,
      elapsed: elapsed,
    );
  }

  testWidgets('sprite paints without errors in all facing directions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => SizedBox(
                width: 96,
                height: 96,
                child: buildRoamingCatSprite(context, frame()),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('sprite handles held, idle and flipped states', (tester) async {
    final states = <RoamingCatFrame>[
      frame(
        facing: -1,
        activity: RoamingActivity.idle,
        moving: false,
      ),
      RoamingCatFrame(
        catSize: 96,
        held: true,
        hovered: false,
        turning: true,
        moving: false,
        bob: 0,
        breath: 1,
        scale: 1.1,
        facing: -1,
        activity: RoamingActivity.turning,
        elapsed: 1.2,
      ),
    ];

    for (final state in states) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => SizedBox(
                  width: 96,
                  height: 96,
                  child: buildRoamingCatSprite(context, state),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
