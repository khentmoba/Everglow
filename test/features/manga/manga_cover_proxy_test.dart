import 'package:everglow/features/manga/data/services/manga_cover_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('proxyMangaCoverUrl', () {
    test('routes MangaDex covers through proxyMangaImage', () {
      const raw =
          'https://uploads.mangadex.org/covers/abc/cover.256.jpg';
      final proxied = proxyMangaCoverUrl(raw);
      expect(proxied, contains('proxyMangaImage'));
      expect(proxied, contains(Uri.encodeComponent(raw)));
    });

    test('routes direct Katana covers through proxyMangaKatana', () {
      const raw = 'https://mangakatana.com/imgs/cover/09c/01/cc06d.webp';
      final proxied = proxyMangaCoverUrl(raw);
      expect(proxied, contains('proxyMangaKatana'));
      expect(proxied, contains(Uri.encodeComponent(raw)));
    });

    test('leaves already-proxied urls untouched', () {
      const proxied =
          'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaKatana?url=https%3A%2F%2Fmangakatana.com%2Fimgs%2Fcover%2F09c%2F01%2Fcc06d.webp';
      expect(proxyMangaCoverUrl(proxied), equals(proxied));
      const dexProxied =
          'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaImage?url=https%3A%2F%2Fuploads.mangadex.org%2Fcovers%2Fabc%2Fcover.256.jpg';
      expect(proxyMangaCoverUrl(dexProxied), equals(dexProxied));
    });

    test('rewrites already-proxied Katana AVIF cover to webp twin', () {
      // Dashboard entries stored while the parser picked AVIF heal on
      // render without needing a Firestore rewrite.
      const proxied =
          'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaKatana?url=https%3A%2F%2Fmangakatana.com%2Fimgs%2Fcover%2F09c%2F22%2F724fa.avif';
      expect(
        proxyMangaCoverUrl(proxied),
        equals(
          'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaKatana?url=https%3A%2F%2Fmangakatana.com%2Fimgs%2Fcover%2F09c%2F22%2F724fa.webp',
        ),
      );
    });

    test('routes direct Katana AVIF cover through proxy as webp twin', () {
      const raw = 'https://mangakatana.com/imgs/cover/09c/22/724fa.avif';
      final proxied = proxyMangaCoverUrl(raw);
      expect(proxied, contains('proxyMangaKatana'));
      expect(
        proxied,
        contains(
          Uri.encodeComponent(
            'https://mangakatana.com/imgs/cover/09c/22/724fa.webp',
          ),
        ),
      );
    });

    test('leaves Comick covers direct (CORS-enabled CDN)', () {
      const raw = 'https://meo.comick.pictures/d0Xmgj.jpg';
      expect(proxyMangaCoverUrl(raw), equals(raw));
    });

    test('handles empty url gracefully', () {
      expect(proxyMangaCoverUrl(''), isEmpty);
    });
  });
}
