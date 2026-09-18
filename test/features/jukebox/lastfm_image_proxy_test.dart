import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/jukebox/data/models/lastfm_image_utils.dart';

void main() {
  group('Last.fm image proxy', () {
    const realArt =
        'https://lastfm-img.freetls.fastly.net/i/u/300x300/'
        '312d04191a575f71f2c743fca3bb596f.png';

    test('isLastfmImageUrl matches both artwork CDN hosts', () {
      expect(isLastfmImageUrl(realArt), isTrue);
      expect(
        isLastfmImageUrl('https://lastfm.freetls.fastly.net/i/u/174s/x.png'),
        isTrue,
      );
    });

    test('isLastfmImageUrl rejects anything else', () {
      expect(isLastfmImageUrl(''), isFalse);
      expect(isLastfmImageUrl('not a url'), isFalse);
      expect(
        isLastfmImageUrl('http://lastfm-img.freetls.fastly.net/i/u/x.png'),
        isFalse,
      );
      expect(isLastfmImageUrl('https://evil.com/x.png'), isFalse);
      expect(
        isLastfmImageUrl(
          'https://lastfm-img.freetls.fastly.net.evil.com/x.png',
        ),
        isFalse,
      );
      // iTunes and Spotify art already send CORS headers: never proxied.
      expect(
        isLastfmImageUrl('https://is1-ssl.mzstatic.com/image/x.jpg'),
        isFalse,
      );
      expect(isLastfmImageUrl('https://i.scdn.co/image/x'), isFalse);
    });

    test('proxyLastfmImageUrl rewrites CDN art, passes the rest through', () {
      final proxied = proxyLastfmImageUrl(realArt);
      expect(
        proxied,
        startsWith(
          'https://us-central1-everglow-1c6db.cloudfunctions.net/'
          'proxyLastfmImage?url=',
        ),
      );
      expect(proxied, contains(Uri.encodeComponent(realArt)));
      // Idempotent: proxying twice yields the same URL.
      expect(proxyLastfmImageUrl(proxied), proxied);
      expect(
        proxyLastfmImageUrl('https://i.scdn.co/image/x'),
        'https://i.scdn.co/image/x',
      );
    });

    group('web rewrite', () {
      setUp(() => debugLastfmImageIsWeb = true);
      tearDown(() => debugLastfmImageIsWeb = null);

      test('cleanLastfmImageUrl proxies real art on web', () {
        final cleaned = cleanLastfmImageUrl(realArt)!;
        expect(cleaned, startsWith(proxyLastfmImageUrl(realArt)));
      });

      test('cleanLastfmImageUrl still drops placeholders on web', () {
        expect(
          cleanLastfmImageUrl(
            'https://lastfm-img.freetls.fastly.net/i/u/300x300/'
            '2a96cbd8b46e442fc41c2b86b821562f.png',
          ),
          isNull,
        );
      });

      test('pickLastfmImageUrl returns proxied art on web', () {
        expect(
          pickLastfmImageUrl([
            {'#text': realArt, 'size': 'extralarge'},
          ]),
          proxyLastfmImageUrl(realArt),
        );
      });
    });

    test('cleanLastfmImageUrl leaves real art untouched off web', () {
      debugLastfmImageIsWeb = false;
      addTearDown(() => debugLastfmImageIsWeb = null);
      expect(cleanLastfmImageUrl(realArt), realArt);
    });
  });
}
