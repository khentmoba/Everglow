import 'dart:io';
import 'dart:ui' as ui;

import 'package:everglow/core/agent/agent_mode.dart';
import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_discovery_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

class _DemoAuth extends ChangeNotifier implements AuthService {
  @override
  bool get isCoupleUser => true;
  @override
  String get currentUser => 'khentsgdz';
  @override
  String get partnerUsername => 'clairjassen';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('agent drawer fits at phone width and captures without hanging', (
    tester,
  ) async {
    AgentMode.isActive.value = true;
    final auth = _DemoAuth();
    addTearDown(() {
      AgentMode.isActive.value = false;
      auth.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    // Use the app fonts so an exported proof depicts the production typography.
    for (final font in ['Outfit', 'CormorantGaramond']) {
      final loader = FontLoader(font == 'Outfit' ? font : 'Cormorant Garamond');
      loader.addFont(rootBundle.load('assets/google_fonts/$font-SemiBold.ttf'));
      await tester.runAsync(loader.load);
    }
    final items = await TMDBDiscoveryService().fetchPopularMovies();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('proof'),
              child: EpisodeDrawer(item: items.first, cinemaVariant: true),
            ),
          ),
        ),
      ),
    );
    // The drawer includes an animated recommendation loader; pump a bounded
    // interval rather than waiting for all animations to stop.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('Status'), findsOneWidget);
    for (final label in ['Want to Watch', 'Clair Watching', 'Both Watched']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(430));
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('proof')),
    );
    // Both image creation and byte readback must leave the fake async zone.
    // Encode raw pixels with the already-installed image package: no Skia PNG wait.
    final png = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final output = img.encodePng(
        img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: pixels!.buffer,
          bytesOffset: pixels.offsetInBytes,
          numChannels: 4,
        ),
      );
      image.dispose();
      const path = String.fromEnvironment('PR_PROOF_PATH');
      if (path.isNotEmpty) await File(path).writeAsBytes(output);
      return output;
    });
    expect(img.decodePng(png!)!.width, 430);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
