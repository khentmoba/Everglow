import 'package:flutter/material.dart';
import '../../data/models/plant_type.dart';
import 'lily_painter.dart';
import 'rose_painter.dart';
import 'sunflower_painter.dart';
import 'tulip_painter.dart';
import 'sakura_painter.dart';

/// A garden plant view that renders the correct painter for a given plant type.
class GardenPlantView extends StatefulWidget {
  final PlantType plantType;
  final int stage;

  const GardenPlantView({
    super.key,
    required this.plantType,
    required this.stage,
  });

  @override
  State<GardenPlantView> createState() => _GardenPlantViewState();
}

class _GardenPlantViewState extends State<GardenPlantView>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  CustomPainter _getPainter() {
    switch (widget.plantType.id) {
      case 'rose':
        return RosePainter(
          stage: widget.stage,
          animationValue: _breathingController.value,
        );
      case 'sunflower':
        return SunflowerPainter(
          stage: widget.stage,
          animationValue: _breathingController.value,
        );
      case 'tulip':
        return TulipPainter(
          stage: widget.stage,
          animationValue: _breathingController.value,
        );
      case 'sakura':
        return SakuraPainter(
          stage: widget.stage,
          animationValue: _breathingController.value,
        );
      case 'lily':
      default:
        return LilyPainter(
          stage: widget.stage,
          animationValue: _breathingController.value,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _breathingController,
        builder: (context, _) {
          return AnimatedSwitcher(
            duration: const Duration(seconds: 1),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: CustomPaint(
              key: ValueKey('${widget.plantType.id}-${widget.stage}'),
              size: Size.infinite,
              painter: _getPainter(),
            ),
          );
        },
      ),
    );
  }
}
