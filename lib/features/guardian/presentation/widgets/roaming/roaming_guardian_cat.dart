import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'roaming_guardian_controller.dart';

/// Snapshot of the cat's animation state handed to the visual builder.
///
/// Kept free of any web-only types so the interaction layer can be widget
/// tested on the VM.
class RoamingCatFrame {
  const RoamingCatFrame({
    required this.catSize,
    required this.held,
    required this.hovered,
    required this.turning,
    required this.moving,
    required this.bob,
    required this.breath,
    required this.scale,
    required this.facing,
    required this.activity,
    required this.elapsed,
  });

  final double catSize;
  final bool held;
  final bool hovered;
  final bool turning;
  final bool moving;
  final double bob;
  final double breath;
  final double scale;
  final double facing;
  final RoamingActivity activity;
  final double elapsed;
}

/// Builds the visible cat body. The web build injects the 3D
/// `<model-viewer>` visual via [RoamingGuardianVisualBuilder]; tests inject a
/// plain widget so the gesture/positioning layer runs on the VM.
typedef RoamingGuardianVisualBuilder =
    Widget Function(BuildContext context, RoamingCatFrame frame);

/// The roaming cat's interaction layer: a draggable hit area positioned at
/// [RoamingGuardianController.position], with walk bobbing and directional
/// mirroring applied by the injected visual.
class RoamingGuardianCat extends StatelessWidget {
  const RoamingGuardianCat({
    super.key,
    required this.controller,
    required this.visualBuilder,
  });

  final RoamingGuardianController controller;
  final RoamingGuardianVisualBuilder visualBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final catSize = controller.catSize;
        final position = controller.position;
        final held = controller.isDragging;
        final hovered = controller.isHovered;
        final turning = controller.activity == RoamingActivity.turning;
        final moving = controller.isMoving;

        // Walk hop; bigger, faster hops during zoomies.
        final bob = moving
            ? math.sin(
                    controller.elapsed *
                        (controller.activity == RoamingActivity.zoomies
                            ? 13
                            : 9),
                  ) *
                  (controller.activity == RoamingActivity.zoomies ? 7 : 4)
            : 0.0;

        // Idle breathing + hover/drag lift.
        final breath = moving
            ? 1.0
            : 1 + math.sin(controller.elapsed * 2.4) * 0.015;
        final scale = held ? 1.12 : (hovered ? 1.06 : 1.0);

        final frame = RoamingCatFrame(
          catSize: catSize,
          held: held,
          hovered: hovered,
          turning: turning,
          moving: moving,
          bob: bob,
          breath: breath,
          scale: scale,
          facing: controller.facing,
          activity: controller.activity,
          elapsed: controller.elapsed,
        );

        // Full-viewport Stack so the Positioned below has a valid parent.
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: position.dx - catSize / 2,
              top: position.dy - catSize / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => controller.beginDrag(),
                onPanUpdate: (details) => controller.dragBy(details.delta),
                onPanEnd: (_) => controller.endDrag(),
                onPanCancel: controller.endDrag,
                onDoubleTap: () => controller.burst(),
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  onEnter: (_) => controller.setHovered(true),
                  onExit: (_) => controller.setHovered(false),
                  child: SizedBox(
                    width: catSize,
                    height: catSize,
                    child: visualBuilder(context, frame),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
