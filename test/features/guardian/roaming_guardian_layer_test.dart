import 'dart:math' as math;
import 'package:everglow/features/guardian/presentation/widgets/roaming/roaming_guardian_cat.dart';
import 'package:everglow/features/guardian/presentation/widgets/roaming/roaming_guardian_controller.dart';
import 'package:everglow/features/guardian/presentation/widgets/roaming/roaming_guardian_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _catKey = Key('fake-cat');

Widget _harness(RoamingGuardianController controller) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 600,
        child: Stack(
          children: [
            Positioned.fill(
              child: RoamingGuardianLayer(
                controller: controller,
                depth: CatDepth.behind,
                visualBuilder: _fakeVisual,
              ),
            ),
            Positioned.fill(
              child: RoamingGuardianLayer(
                controller: controller,
                depth: CatDepth.front,
                visualBuilder: _fakeVisual,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _fakeVisual(BuildContext context, RoamingCatFrame frame) {
  return Container(
    key: _catKey,
    width: frame.catSize,
    height: frame.catSize,
    color: const Color(0xFFFFC0CB),
  );
}

void main() {
  testWidgets('dragging the cat moves it in real time and roaming resumes',
      (tester) async {
    final controller = RoamingGuardianController(random: math.Random(2));
    addTearDown(controller.dispose);

    await tester.pumpWidget(_harness(controller));
    await tester.pump();

    // Bring the cat to the front layer so it is interactive.
    if (controller.depth == CatDepth.behind) {
      controller.flipDepth();
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(controller.depth, CatDepth.front);

    final finder = find.byKey(_catKey);
    expect(finder, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump();

    // First move establishes the pan.
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    final afterFirstMove = controller.position;
    expect(controller.isDragging, isTrue);

    // Subsequent moves track the pointer in real time.
    await gesture.moveBy(const Offset(80, 50));
    await tester.pump();
    final afterSecondMove = controller.position;
    expect(afterSecondMove.dx, greaterThan(afterFirstMove.dx + 60));
    expect(afterSecondMove.dy, greaterThan(afterFirstMove.dy + 30));

    // The cat stays where it was dropped, then sets off roaming again.
    final dropPoint = controller.position;
    await gesture.up();
    await tester.pump();
    expect(controller.isDragging, isFalse);
    expect(controller.position, dropPoint);
    expect(controller.activity, RoamingActivity.wandering);

    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.position, isNot(equals(dropPoint)));
    controller.stop();
  });

  testWidgets('dragging clamps the cat inside the viewport', (tester) async {
    final controller = RoamingGuardianController(random: math.Random(4));
    addTearDown(controller.dispose);

    await tester.pumpWidget(_harness(controller));
    await tester.pump();
    if (controller.depth == CatDepth.behind) {
      controller.flipDepth();
      await tester.pump(const Duration(milliseconds: 400));
    }

    final finder = find.byKey(_catKey);
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump();
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-5000, -5000));
    await tester.pump();
    // While held, the cat is clamped to the viewport corner.
    expect(controller.position, const Offset(58, 58));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 60));

    expect(controller.isDragging, isFalse);
    controller.stop();
  });

  testWidgets('depth change cross-fades and removes the inactive cat',
      (tester) async {
    final controller = RoamingGuardianController(random: math.Random(6));
    addTearDown(controller.dispose);

    await tester.pumpWidget(_harness(controller));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(_catKey), findsOneWidget);

    controller.flipDepth();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Both layers host a cat during the cross-fade...
    expect(find.byKey(_catKey), findsNWidgets(2));

    // ...and the outgoing layer disposes its cat after the fade-out.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(_catKey), findsOneWidget);
    controller.stop();
  });
}
