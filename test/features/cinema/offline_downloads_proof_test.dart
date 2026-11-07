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
import 'package:everglow/core/services/offline_media/offline_media_item.dart';
import 'package:everglow/core/services/offline_media/offline_media_service.dart';
import 'package:everglow/core/services/offline_media/offline_media_storage.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_downloads_tab.dart';

void main() {
  testWidgets('captures offline downloads section for PR proof', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    AgentMode.isActive.value = false;
    AgentMode.useDemoData.value = false;

    final storage = OfflineMediaStorage.instance;
    final service = OfflineMediaService(storage: storage);

    await tester.runAsync(() async {
      await storage.clearAll();
      await service.clearAll();
      await service.startDownloadMedia(
        id: 'cinema_movie_157336',
        type: OfflineMediaType.movie,
        mediaId: '157336',
        title: 'Interstellar',
        subtitle: 'Movie • 2014',
        durationSeconds: 10140,
        directBytes: Uint8List.fromList([1, 2]),
      );
      await service.startDownloadMedia(
        id: 'cinema_tv_66732_s1_e1',
        type: OfflineMediaType.tv,
        mediaId: '66732',
        title: 'Stranger Things',
        subtitle: 'S1 E1 • Chapter One: The Vanishing of Will Byers',
        season: 1,
        episode: 1,
        durationSeconds: 2940,
        directBytes: Uint8List.fromList([3, 4]),
      );
      await service.startDownloadMedia(
        id: 'cinema_tv_66732_s1_e2',
        type: OfflineMediaType.tv,
        mediaId: '66732',
        title: 'Stranger Things',
        subtitle: 'S1 E2 • Chapter Two: The Weirdo on Maple Street',
        season: 1,
        episode: 2,
        durationSeconds: 3300,
        directBytes: Uint8List.fromList([5, 6]),
      );
      await service.startDownloadMedia(
        id: 'cinema_tv_66732_s2_e1',
        type: OfflineMediaType.tv,
        mediaId: '66732',
        title: 'Stranger Things',
        subtitle: 'S2 E1 • Chapter One: MADMAX',
        season: 2,
        episode: 1,
        durationSeconds: 2880,
        directBytes: Uint8List.fromList([7, 8]),
      );
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

      if (Platform.environment['GENERATE_PR_PROOF'] == 'true') {
        final proofFile = File('docs/pr-proof/pr-579/shot.png');
        if (!await proofFile.parent.exists()) {
          await proofFile.parent.create(recursive: true);
        }
        await proofFile.writeAsBytes(output);
      }
      return output;
    });

    expect(png, isNotNull);
  });
}
