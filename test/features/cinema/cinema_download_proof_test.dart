library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/services/torrent_index_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/torrent_download_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

class _DemoIndex extends TorrentIndexService {
  @override
  Future<TorrentSearch> search({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) async => const TorrentSearch(copies: TorrentIndexService.demoCopies);
}

void main() {
  testWidgets('captures cinema download sheet for PR proof', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);

    for (final font in ['Outfit', 'CormorantGaramond']) {
      final loader = FontLoader(font == 'Outfit' ? font : 'Cormorant Garamond');
      loader.addFont(rootBundle.load('assets/google_fonts/$font-SemiBold.ttf'));
      await tester.runAsync(loader.load);
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.gamifiedTheme,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: RepaintBoundary(
            key: const ValueKey('proof_sheet'),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TorrentDownloadSheet(
                tmdbId: 900001,
                mediaType: 'tv',
                title: 'Moonlit Cinema',
                season: 1,
                episode: 3,
                service: _DemoIndex(),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Download · S1 E3'), findsOneWidget);
    expect(find.text('Moonlit Cinema'), findsOneWidget);

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('proof_sheet')),
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
      const path = String.fromEnvironment('PR_PROOF_PATH');
      if (path.isNotEmpty) {
        final file = File(path);
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsBytes(output);
      }
      return output;
    });

    expect(png, isNotNull);
    expect(img.decodePng(png!)!.width, 430);
  });
}
