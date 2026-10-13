import 'dart:io';
import 'dart:ui' as ui;

import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/ai/presentation/widgets/motchi_voice_waveform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  testWidgets('waveform fits phones and tablets and respects reduced motion', (
    tester,
  ) async {
    final levels = ValueNotifier<List<double>>(List.filled(25, 0));
    addTearDown(levels.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 430.0, 810.0]) {
      tester.view.physicalSize = Size(width, 900);
      for (final reduced in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.gamifiedTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                disableAnimations: reduced,
              ),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    child: MotchiVoiceWaveform(levels: levels),
                  ),
                ),
              ),
            ),
          ),
        );
        levels.value = List.generate(25, (i) => i / 24);
        await tester.pump();
        expect(find.text('Listening · English'), findsOneWidget);
        expect(find.text('Tap Stop to review'), findsOneWidget);
        expect(tester.getSize(find.byType(MotchiVoiceWaveform)).width, width);
        expect(tester.takeException(), isNull);
        levels.value = List.filled(25, 0);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('captures the actual listening indicator with synthetic levels', (
    tester,
  ) async {
    const path = String.fromEnvironment('PR_PROOF_PATH');
    if (path.isEmpty) return;
    final levels = ValueNotifier<List<double>>([
      0,
      .02,
      .08,
      .25,
      .5,
      .8,
      .55,
      .2,
      .04,
      .1,
      .3,
      .7,
      1,
      .8,
      .5,
      .2,
      .1,
      .3,
      .6,
      .9,
      .4,
      .2,
      .08,
      .02,
      0,
    ]);
    addTearDown(levels.dispose);
    final font = FontLoader('Outfit');
    font.addFont(rootBundle.load('assets/google_fonts/Outfit-Medium.ttf'));
    await tester.runAsync(font.load);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.gamifiedTheme,
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('voice-proof'),
              child: ColoredBox(
                color: AppColors.silk,
                child: SizedBox(
                  width: 430,
                  height: 96,
                  child: Center(child: MotchiVoiceWaveform(levels: levels)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('voice-proof')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final png = img.encodePng(
        img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: pixels!.buffer,
          bytesOffset: pixels.offsetInBytes,
          numChannels: 4,
        ),
      );
      image.dispose();
      await File(path).writeAsBytes(png);
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
