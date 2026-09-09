import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/shared/widgets/app_network_image.dart';

/// Cache backend that fails every load at once, so the retry path runs
/// without real network or disk I/O (the default manager needs
/// path_provider, which has no test implementation).
class _FailingCacheManager extends CacheManager {
  _FailingCacheManager() : super(Config('app-network-image-test'));

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    return Stream<FileResponse>.error(Exception('network down'));
  }
}

void main() {
  group('AppNetworkImage.isValidUrl', () {
    test('accepts valid HTTP/HTTPS URLs', () {
      expect(AppNetworkImage.isValidUrl('https://example.com/pic.jpg'), isTrue);
      expect(AppNetworkImage.isValidUrl('http://example.com/pic.png'), isTrue);
      expect(AppNetworkImage.isValidUrl('blob:https://example.com/uuid'), isTrue);
      expect(AppNetworkImage.isValidUrl('data:image/png;base64,abc'), isTrue);
    });

    test('rejects empty, null, or bogus strings', () {
      expect(AppNetworkImage.isValidUrl(null), isFalse);
      expect(AppNetworkImage.isValidUrl(''), isFalse);
      expect(AppNetworkImage.isValidUrl('   '), isFalse);
      expect(AppNetworkImage.isValidUrl('null'), isFalse);
      expect(AppNetworkImage.isValidUrl('undefined'), isFalse);
      expect(AppNetworkImage.isValidUrl('false'), isFalse);
      expect(AppNetworkImage.isValidUrl('not-a-url'), isFalse);
      expect(AppNetworkImage.isValidUrl('ftp://example.com/pic.jpg'), isFalse);
    });
  });

  group('AppNetworkImage widget', () {
    testWidgets('renders fallback widget for invalid URL', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkImage(
              imageUrl: '',
              width: 100,
              height: 150,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });

    testWidgets('renders custom errorWidget for invalid URL', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkImage(
              imageUrl: 'null',
              width: 100,
              height: 150,
              errorWidget: Text('Custom Error'),
            ),
          ),
        ),
      );

      expect(find.text('Custom Error'), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });

    testWidgets('renders CachedNetworkImage for valid URL', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkImage(
              imageUrl: 'https://example.com/poster.jpg',
              width: 120,
              height: 180,
              cacheWidth: 400,
            ),
          ),
        ),
      );

      final cachedImageFinder = find.byType(CachedNetworkImage);
      expect(cachedImageFinder, findsOneWidget);

      final widget = tester.widget<CachedNetworkImage>(cachedImageFinder);
      expect(widget.imageUrl, 'https://example.com/poster.jpg');
      expect(widget.useOldImageOnUrlChange, isTrue);

      if (kIsWeb) {
        // On web, memCacheWidth must be null to avoid ResizeImage WebGL crash.
        expect(widget.memCacheWidth, isNull);
        expect(widget.memCacheHeight, isNull);
      } else {
        expect(widget.memCacheWidth, 400);
      }
    });

    testWidgets('retries a failed load with a fresh key after backoff', (
      tester,
    ) async {
      const url = 'https://example.com/does-not-exist.jpg';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppNetworkImage(
              imageUrl: url,
              width: 120,
              height: 180,
              cacheManager: _FailingCacheManager(),
            ),
          ),
        ),
      );

      // Let the failed fetch surface and the fallback render.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      final first =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));

      // First backoff is 2s: advancing past it rebuilds the inner image
      // with a new key so it re-resolves instead of staying stuck.
      await tester.pump(const Duration(seconds: 3));
      final second =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(second.key, isNot(equals(first.key)));
    });

    testWidgets('web implementation renders Image.network without RepaintBoundary', (
      tester,
    ) async {
      AppNetworkImage.debugUseWebImplementation = true;
      addTearDown(() => AppNetworkImage.debugUseWebImplementation = null);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkImage(
              imageUrl: 'https://example.com/poster.jpg',
              width: 120,
              height: 180,
              cacheWidth: 400,
            ),
          ),
        ),
      );

      // On web, Image.network is rendered instead of CachedNetworkImage to avoid
      // WebGL texImage2D crash after alt-tabbing.
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byType(Image), findsOneWidget);

      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.gaplessPlayback, isTrue);
      expect(imageWidget.excludeFromSemantics, isTrue);

      // On web, RepaintBoundary is avoided on each thumbnail (flutter/flutter#192347).
      expect(
        find.descendant(
          of: find.byType(AppNetworkImage),
          matching: find.byType(RepaintBoundary),
        ),
        findsNothing,
      );
    });

    testWidgets('onAppResumed immediately retries failed images without waiting for backoff', (
      tester,
    ) async {
      const url = 'https://example.com/failed-then-wake.jpg';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppNetworkImage(
              imageUrl: url,
              width: 120,
              height: 180,
              cacheManager: _FailingCacheManager(),
            ),
          ),
        ),
      );

      // Let the failure occur.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      final first =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));

      // Without waiting for the 2s/8s timer, simulate returning from alt-tab
      AppNetworkImage.onAppResumed();
      await tester.pump();

      final second =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(second.key, isNot(equals(first.key)));
    });

    testWidgets('AppPosterImage creates 2:3 aspect ratio AppNetworkImage', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppPosterImage(
              imageUrl: 'https://example.com/poster.jpg',
              width: 150,
            ),
          ),
        ),
      );

      final appImageFinder = find.byType(AppNetworkImage);
      expect(appImageFinder, findsOneWidget);

      final widget = tester.widget<AppNetworkImage>(appImageFinder);
      expect(widget.width, 150);
      expect(widget.aspectRatio, 2 / 3);
    });
  });
}
