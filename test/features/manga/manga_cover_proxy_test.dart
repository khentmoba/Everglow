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

    test('leaves Comick covers direct (CORS-enabled CDN)', () {
      const raw = 'https://meo.comick.pictures/d0Xmgj.jpg';
      expect(proxyMangaCoverUrl(raw), equals(raw));
    });

    test('handles empty url gracefully', () {
      expect(proxyMangaCoverUrl(''), isEmpty);
    });
  });
}
