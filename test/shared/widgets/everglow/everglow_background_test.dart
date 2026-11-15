import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/shared/widgets/everglow/everglow_background.dart';

class _FullScreenGlows extends StatelessWidget {
  const _FullScreenGlows({required this.glows, required this.baseColor});

  final List<RadialGlow> glows;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: baseColor,
        child: Stack(
          children: [
            for (final g in glows)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: g.alignment,
                      radius: g.size,
                      colors: [
                        g.color.withValues(alpha: g.opacity),
                        g.color.withValues(alpha: 0),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<Uint8List> capture(WidgetTester tester, Widget widget, Size size) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(key: key, child: widget),
    ),
  );
  await tester.pump();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

void main() {
  const glows = <RadialGlow>[
    RadialGlow(
      color: AppColors.deepRose,
      alignment: Alignment(-0.7, -0.85),
      size: 0.9,
      opacity: 0.14,
    ),
    RadialGlow(
      color: AppColors.softLavender,
      alignment: Alignment(0.85, 0.95),
      size: 0.8,
      opacity: 0.10,
    ),
    RadialGlow(
      color: AppColors.auroraGold,
      alignment: Alignment(0.1, 0.45),
      size: 0.6,
      opacity: 0.05,
    ),
  ];

  testWidgets('bounded glows draw the same pixels as full-screen glows', (
    tester,
  ) async {
    const size = Size(390, 844);
    final optimized = await capture(
      tester,
      const EverglowBackground(baseColor: AppColors.inkDeep, glows: glows),
      size,
    );
    final reference = await capture(
      tester,
      const _FullScreenGlows(baseColor: AppColors.inkDeep, glows: glows),
      size,
    );

    expect(optimized.length, reference.length);

    var maxDelta = 0;
    var differing = 0;
    for (var i = 0; i < optimized.length; i += 4) {
      var differs = false;
      for (var channel = 0; channel < 3; channel++) {
        final delta = (optimized[i + channel] - reference[i + channel]).abs();
        if (delta > maxDelta) maxDelta = delta;
        if (delta > 1) differs = true;
      }
      if (differs) differing++;
    }

    final total = optimized.length ~/ 4;
    debugPrint(
      '[pixel] glows maxChannelDelta=$maxDelta '
      'differing=$differing/$total',
    );

    expect(maxDelta, 0);
    expect(differing, 0);
  });

  testWidgets('a glow paints only its own circle, not the whole screen', (
    tester,
  ) async {
    const size = Size(390, 844);
    final glow = glows[2];
    final rect = EverglowBackground.glowRect(glow, size);
    final visible = rect.intersect(Offset.zero & size);

    expect(rect.center, glow.alignment.withinRect(Offset.zero & size));
    expect(rect.width / 2, glow.size * 390);
    expect(
      visible.width * visible.height,
      lessThan(size.width * size.height * 0.6),
    );
  });

  testWidgets('the dashboard background shades far fewer pixels per frame', (
    tester,
  ) async {
    const size = Size(390, 844);
    final screen = size.width * size.height;
    var shaded = 0.0;
    for (final glow in glows) {
      final visible = EverglowBackground.glowRect(
        glow,
        size,
      ).intersect(Offset.zero & size);
      shaded += visible.width * visible.height;
    }

    debugPrint(
      '[pixel] glows shade ${(shaded / (screen * glows.length) * 100).round()}% '
      'of what the full-screen layers did',
    );
    expect(shaded, lessThan(screen * glows.length * 0.6));
  });
}
