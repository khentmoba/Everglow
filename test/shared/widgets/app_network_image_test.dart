import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/shared/widgets/app_network_image.dart';

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
