import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:everglow/features/guardian/presentation/widgets/roaming/roaming_guardian_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tick = Duration(milliseconds: 33);
  const bounds = Size(800, 600);

  RoamingGuardianController makeController({int seed = 7}) {
    return RoamingGuardianController(
      random: math.Random(seed),
      tickInterval: tick,
    );
  }

  void pump(RoamingGuardianController controller, int ticks) {
    for (var i = 0; i < ticks; i++) {
      controller.tick(tick);
    }
  }

  group('RoamingGuardianController', () {
    test('attach initializes position inside bounds and starts roaming', () {
      final controller = makeController();
      controller.attach(bounds);

      expect(controller.bounds, bounds);
      expect(controller.position.dx, inInclusiveRange(58, 742));
      expect(controller.position.dy, inInclusiveRange(58, 542));
      expect(controller.activity, RoamingActivity.idle);
      expect(controller.depth, anyOf(CatDepth.front, CatDepth.behind));

      final start = controller.position;
      pump(controller, 200);
      expect(controller.position, isNot(equals(start)));
      controller.dispose();
    });

    test('attach with empty bounds is a safe no-op', () {
      final controller = makeController();
      controller.attach(Size.zero);
      controller.tick(tick);
      expect(controller.bounds, Size.zero);
      controller.dispose();
    });

    test('walking always stays within the viewport bounds', () {
      final controller = makeController(seed: 3);
      controller.attach(bounds);
      pump(controller, 1500);

      final p = controller.position;
      expect(p.dx, inInclusiveRange(58 - 0.001, 742 + 0.001));
      expect(p.dy, inInclusiveRange(58 - 0.001, 542 + 0.001));
      controller.dispose();
    });

    test('drag moves the cat in real time and clamps to bounds', () {
      final controller = makeController(seed: 9);
      controller.attach(bounds);
      controller.beginDrag();

      final before = controller.position;
      controller.dragBy(const Offset(140, -60));
      expect(controller.position, before + const Offset(140, -60));

      controller.dragBy(const Offset(-100000, -100000));
      expect(controller.position, const Offset(58, 58));

      controller.dragBy(const Offset(100000, 100000));
      expect(controller.position, const Offset(742, 542));
      controller.endDrag();
      controller.dispose();
    });

    test(
      'beginDrag freezes roaming and endDrag resumes from the drop point',
      () {
        final controller = makeController(seed: 11);
        controller.attach(bounds);
        pump(controller, 60);
        final before = controller.position;

        controller.beginDrag();
        controller.dragBy(const Offset(120, -80));
        final dropped = controller.position;
        expect(dropped, isNot(equals(before)));

        pump(controller, 30);
        expect(controller.position, dropped);
        expect(controller.isDragging, isTrue);

        controller.endDrag();
        expect(controller.isDragging, isFalse);
        expect(controller.activity, RoamingActivity.wandering);
        expect(controller.position, dropped);

        pump(controller, 5);
        expect(controller.position, isNot(equals(dropped)));
        controller.dispose();
      },
    );

    test('burst triggers a zoomie dash', () {
      final controller = makeController(seed: 13);
      controller.attach(bounds);
      pump(controller, 10);

      controller.burst();
      expect(controller.activity, RoamingActivity.zoomies);
      expect(controller.isMoving, isTrue);
      controller.dispose();
    });

    test('flipDepth toggles the paint layer', () {
      final controller = makeController(seed: 15);
      controller.attach(bounds);
      final initial = controller.depth;

      controller.flipDepth();
      expect(controller.depth, isNot(initial));
      controller.flipDepth();
      expect(controller.depth, initial);
      controller.dispose();
    });

    test('depth mixes between front and behind across many strolls', () {
      final controller = makeController(seed: 5);
      controller.attach(bounds);
      final depths = <CatDepth>{};

      for (var i = 0; i < 3000; i++) {
        controller.tick(tick);
        depths.add(controller.depth);
      }

      expect(depths, containsAll(<CatDepth>[CatDepth.front, CatDepth.behind]));
      controller.dispose();
    });

    test('attach on resize clamps an out-of-range position', () {
      final controller = makeController(seed: 17);
      controller.attach(bounds);
      controller.beginDrag();
      controller.dragBy(const Offset(-10000, -10000));
      expect(controller.position, const Offset(58, 58));

      controller.attach(const Size(400, 500));
      expect(controller.position.dx, inInclusiveRange(52, 348));
      expect(controller.position.dy, inInclusiveRange(52, 448));
      controller.endDrag();
      controller.dispose();
    });

    test('stop and dispose are safe', () {
      final controller = makeController();
      controller.attach(bounds);
      controller.start();
      controller.stop();
      controller.stop();
      controller.dispose();
    });
  });
}
