import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/manga/data/services/katana_service.dart';
import 'package:everglow/features/manga/presentation/katana/katana_theme.dart';
import 'package:everglow/shared/widgets/app_network_image.dart';

void main() {
  group('KatanaService.proxyImageUrl', () {
    test('proxies raw mangakatana image url', () {
      const raw = 'https://mangakatana.com/imgs/cover/09c/21/7d9f2.webp';
      final proxied = KatanaService.proxyImageUrl(raw);
      expect(
        proxied,
        equals(
          'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaKatana?url=https%3A%2F%2Fmangakatana.com%2Fimgs%2Fcover%2F09c%2F21%2F7d9f2.webp',
        ),
      );
    });

    test('leaves already-proxied url untouched without double proxying', () {
      const proxied =
          'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaKatana?url=https%3A%2F%2Fmangakatana.com%2Fimgs%2Fcover%2F09c%2F21%2F7d9f2.webp';
      expect(KatanaService.proxyImageUrl(proxied), equals(proxied));
    });

    test('handles empty url gracefully', () {
      expect(KatanaService.proxyImageUrl(''), isEmpty);
    });

    test('ignores non-manga urls', () {
      const other = 'https://firebasestorage.googleapis.com/v0/b/img.jpg';
      expect(KatanaService.proxyImageUrl(other), equals(other));
    });
  });

  group('KatanaNetworkImage widget', () {
    testWidgets(
      'resolves raw mangakatana url to proxied url for AppNetworkImage',
      (tester) async {
        const raw = 'https://mangakatana.com/imgs/cover/09c/21/7d9f2.webp';
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: KatanaNetworkImage(raw),
            ),
          ),
        );

        final appNetworkImage = tester.widget<AppNetworkImage>(
          find.byType(AppNetworkImage),
        );
        expect(
          appNetworkImage.imageUrl,
          equals(
            'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaKatana?url=https%3A%2F%2Fmangakatana.com%2Fimgs%2Fcover%2F09c%2F21%2F7d9f2.webp',
          ),
        );
      },
    );
  });
}
