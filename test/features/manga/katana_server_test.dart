import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/manga/data/services/katana_service.dart';

/// MangaKatana's server switch is a cookie (`s_r`), not just the `?sv=`
/// query — without it, Server 2/3 requests silently return Server 1's
/// page URLs, so switching servers in the reader did nothing.
void main() {
  test('maps each reader server to the cookie the site uses', () {
    expect(KatanaService.cookieForServer(''), '');
    expect(KatanaService.cookieForServer('?sv=mk'), 's_r=sv2');
    expect(KatanaService.cookieForServer('?sv=3'), 's_r=sv3');
    expect(KatanaService.cookieForServer('?sv=evil'), '');
  });

  group('CDN host fallback', () {
    const page =
        'https://i1.mangakatana.com/token/abc123/0.jpg';

    test('step 0 keeps the URL, steps cycle the other hosts', () {
      expect(KatanaService.cdnFallbackUrl(page, 0), page);
      final seen = <String>{};
      for (var step = 1; step <= 4; step++) {
        final next = KatanaService.cdnFallbackUrl(page, step);
        expect(next, contains('/token/abc123/0.jpg'));
        expect(next, isNot(page));
        seen.add(Uri.parse(next).host);
      }
      expect(seen, hasLength(4));
      expect(seen, isNot(contains('i1.mangakatana.com')));
    });

    test('past the last host the URL is unchanged', () {
      expect(KatanaService.cdnFallbackUrl(page, 5), page);
      expect(KatanaService.cdnFallbackUrl(page, 99), page);
    });

    test('non-iN hosts have no fallbacks', () {
      const cover = 'https://mangakatana.com/imgs/cover/a.jpg';
      expect(KatanaService.cdnFallbackUrl(cover, 1), cover);
      expect(KatanaService.cdnFallbackCount(cover), 0);
      expect(KatanaService.cdnFallbackCount('not a url %'), 0);
    });

    test('fallback count matches the available hosts', () {
      expect(KatanaService.cdnFallbackCount(page), 4);
    });
  });
}
