import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/shared/utils/tmdb_images.dart';

void main() {
  group('TmdbImages.isUsablePath', () {
    test('rejects null, blank, and stringified nulls', () {
      expect(TmdbImages.isUsablePath(null), isFalse);
      expect(TmdbImages.isUsablePath(''), isFalse);
      expect(TmdbImages.isUsablePath('   '), isFalse);
      for (final bad in ['null', 'NULL', ' undefined ', 'false', 'none', 'NaN']) {
        expect(TmdbImages.isUsablePath(bad), isFalse, reason: bad);
      }
    });

    test('rejects values with whitespace (titles, not paths)', () {
      // Regression: a title like "Yellow Jacket" stored in the poster field
      // built a bogus .../w500Yellow Jacket URL that 404d forever.
      expect(TmdbImages.isUsablePath('Yellow Jacket'), isFalse);
      expect(TmdbImages.isUsablePath('/ab c.jpg'), isFalse);
      expect(TmdbImages.isUsablePath('https://x.com/a b.jpg'), isFalse);
    });

    test('accepts relative paths and full URLs', () {
      expect(TmdbImages.isUsablePath('/abc.jpg'), isTrue);
      expect(TmdbImages.isUsablePath('abc.jpg'), isTrue);
      expect(
        TmdbImages.isUsablePath('https://image.tmdb.org/t/p/w500/abc.jpg'),
        isTrue,
      );
      expect(
        TmdbImages.isUsablePath('https://s4.anilist.co/image/large.jpg'),
        isTrue,
      );
    });
  });

  group('TmdbImages.posterFor', () {
    test('returns empty for unusable paths', () {
      expect(TmdbImages.posterFor(null), isEmpty);
      expect(TmdbImages.posterFor(''), isEmpty);
      expect(TmdbImages.posterFor('null'), isEmpty);
      expect(TmdbImages.posterFor('Yellow Jacket'), isEmpty);
    });

    test('returns full URLs as-is, trimmed', () {
      const url = 'https://image.tmdb.org/t/p/w500/abc.jpg';
      expect(TmdbImages.posterFor(url), url);
      expect(TmdbImages.posterFor('  $url  '), url);
    });

    test('prepends the w500 base to relative paths', () {
      expect(
        TmdbImages.posterFor('/abc.jpg'),
        'https://image.tmdb.org/t/p/w500/abc.jpg',
      );
    });

    test('restores a stripped leading slash', () {
      expect(
        TmdbImages.posterFor('abc.jpg'),
        'https://image.tmdb.org/t/p/w500/abc.jpg',
      );
    });
  });

  group('TmdbImages.backdropFor / stillFor', () {
    test('backdrop uses w780 by default, w1280 when large', () {
      expect(
        TmdbImages.backdropFor('/b.jpg'),
        'https://image.tmdb.org/t/p/w780/b.jpg',
      );
      expect(
        TmdbImages.backdropFor('/b.jpg', large: true),
        'https://image.tmdb.org/t/p/w1280/b.jpg',
      );
      expect(TmdbImages.backdropFor('null'), isEmpty);
    });

    test('still uses w300 by default, w400 when large', () {
      expect(
        TmdbImages.stillFor('/s.jpg'),
        'https://image.tmdb.org/t/p/w300/s.jpg',
      );
      expect(
        TmdbImages.stillFor('/s.jpg', large: true),
        'https://image.tmdb.org/t/p/w400/s.jpg',
      );
      expect(TmdbImages.stillFor('  '), isEmpty);
    });
  });
}
