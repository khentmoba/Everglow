library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/core/agent/agent_mode.dart';
import 'package:everglow/core/services/offline_media/offline_media_service.dart';
import 'package:everglow/core/services/offline_media/offline_media_storage.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_downloads_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures offline downloads section for PR proof', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    AgentMode.isActive.value = false;
    AgentMode.useDemoData.value = false;

    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);

    for (final font in ['Outfit', 'CormorantGaramond']) {
      final loader = FontLoader(font == 'Outfit' ? font : 'Cormorant Garamond');
      loader.addFont(rootBundle.load('assets/google_fonts/$font-SemiBold.ttf'));
      await tester.runAsync(loader.load);
    }

    final storage = OfflineMediaStorage.instance;
    final service = OfflineMediaService(storage: storage);

    await tester.runAsync(() async {
      await storage.clearAll();
      await service.clearAll();
      service.seedDemoData();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<OfflineMediaService>.value(
        value: service,
        child: MaterialApp(
          theme: AppTheme.gamifiedTheme,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: RepaintBoundary(
              key: const ValueKey('downloads_screen'),
              child: CinemaDownloadsTab(
                onPlayMedia: (_) {},
                onBrowseCinema: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Offline Ready'), findsOneWidget);
    expect(find.text('TV Shows & Series'), findsOneWidget);
    expect(find.text('Stranger Things'), findsOneWidget);
    expect(find.text('Interstellar'), findsOneWidget);

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('downloads_screen')),
    );

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

      final proofFile = File('docs/pr-proof/pr-579/shot.png');
      if (!await proofFile.parent.exists()) {
        await proofFile.parent.create(recursive: true);
      }
      await proofFile.writeAsBytes(output);
      return output;
    });

    expect(png, isNotNull);
    expect(File('docs/pr-proof/pr-579/shot.png').existsSync(), isTrue);
  });
}
