import 'dart:ui' as ui;

import 'package:everglow/features/anime/presentation/widgets/animex/animex_spotlight.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  for (final viewport in [
    const Size(1920, 1080),
    const Size(820, 1180),
    const Size(390, 844),
  ]) {
    testWidgets('spotlight artwork fills $viewport through slide changes', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(viewport);
      AppNetworkImage.debugUseWebImplementation = true;
      addTearDown(() {
        AppNetworkImage.debugUseWebImplementation = null;
        tester.binding.setSurfaceSize(null);
        PaintingBinding.instance.imageCache.clear();
      });

      final items = <MediaItem>[];
      for (final shape in [const Size(800, 170), const Size(232, 330)]) {
        final url = 'https://demo.everglow.test/${shape.width}.png';
        final image = await tester.runAsync(() async {
          final bytes = img.encodePng(
            img.Image(width: shape.width.toInt(), height: shape.height.toInt()),
          );
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          codec.dispose();
          return frame.image;
        });
        PaintingBinding.instance.imageCache.putIfAbsent(
          NetworkImage(url),
          () => OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: image!)),
          ),
        );
        items.add(
          MediaItem(
            id: url,
            tmdbId: items.length + 1,
            title: 'Demo anime ${items.length + 1}',
            mediaType: 'tv',
            posterPath: url,
            backdropPath: items.isEmpty ? url : '',
            year: '2026',
            status: 'to-watch',
            addedAt: DateTime(2026),
          ),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AnimeXSpotlight(items: items)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      void expectFullArtwork() {
        final hero = tester.getRect(find.byType(AnimeXSpotlight));
        final images = find.descendant(
          of: find.byType(AnimeXSpotlight),
          matching: find.byType(RawImage),
        );
        expect(images, findsWidgets);
        for (final element in images.evaluate()) {
          final raw = element.widget as RawImage;
          expect(raw.image, isNotNull);
          final rect = tester.getRect(find.byWidget(raw));
          expect(rect.left, lessThanOrEqualTo(hero.left + 0.1));
          expect(rect.top, lessThanOrEqualTo(hero.top + 0.1));
          expect(rect.right, greaterThanOrEqualTo(hero.right - 0.1));
          expect(rect.bottom, greaterThanOrEqualTo(hero.bottom - 0.1));
        }
        expect(tester.takeException(), isNull);
      }

      expectFullArtwork();
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Demo anime 2'), findsOneWidget);
      expect(find.byType(RawImage), findsNWidgets(2));
      expectFullArtwork();
      await tester.pump(const Duration(seconds: 1));
      expectFullArtwork();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
