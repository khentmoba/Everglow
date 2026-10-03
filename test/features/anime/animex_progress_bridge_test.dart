import 'dart:convert';

import 'package:everglow/features/anime/presentation/widgets/animex/animex_videasy_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const url = '$animeXProxyOrigin/proxyAnime?source=megavid&ep=3';
  Map<String, Object?> tick({
    Object? position = 25,
    Object? duration = 100,
    Object? episode = 3,
  }) => {
    'type': 'animex-progress',
    'position': position,
    'duration': duration,
    'episode': episode,
  };

  test(
    'owned object and native JSON ticks become existing VideasyProgress',
    () {
      for (final data in [
        tick(position: 25.5),
        jsonEncode(tick(position: 25.5)),
      ]) {
        final progress = parseAnimeXProgress(animeXProxyOrigin, url, data);
        expect(progress?.positionSeconds, 25.5);
        expect(progress?.durationSeconds, 100);
        expect(progress?.episode, 3);
      }
      expect(
        parseAnimeXProgress(animeXProxyOrigin, url, tick(position: 0)),
        isNotNull,
      );
      expect(
        parseAnimeXProgress(animeXProxyOrigin, url, tick(position: 100)),
        isNotNull,
      );
    },
  );

  test('owned progress requires exact origin, URL, source and episode', () {
    for (final origin in [
      'null',
      '$animeXProxyOrigin.evil.com',
      'https://evil.com',
      'https://everglow-1c6db.web.app',
    ]) {
      expect(parseAnimeXProgress(origin, url, tick()), isNull);
    }
    for (final otherUrl in [
      'https:foo',
      'not a url',
      '$animeXProxyOrigin/proxyAnime?source=%FF&ep=3',
      '$animeXProxyOrigin/proxyCatalog?source=megavid&ep=3',
      '$animeXProxyOrigin/proxyAnime/extra?source=megavid&ep=3',
      '$animeXProxyOrigin/proxyAnime?source=cinesrc&ep=3',
      '$animeXProxyOrigin/proxyAnime?source=megavid',
      '$animeXProxyOrigin/proxyAnime?source=megavid&ep=4',
      'https://evil.com/proxyAnime?source=megavid&ep=3',
      'https://user@us-central1-everglow-1c6db.cloudfunctions.net/proxyAnime?source=megavid&ep=3',
    ]) {
      expect(
        parseAnimeXProgress(animeXProxyOrigin, otherUrl, tick()),
        isNull,
        reason: otherUrl,
      );
    }
  });

  test('no NaN, infinity, numeric strings, negatives or impossible values', () {
    for (final position in [
      double.nan,
      double.infinity,
      -1,
      101,
      '25',
      null,
      true,
    ]) {
      expect(
        parseAnimeXProgress(animeXProxyOrigin, url, tick(position: position)),
        isNull,
      );
    }
    for (final duration in [
      double.nan,
      double.infinity,
      -1,
      0,
      10,
      '100',
      null,
    ]) {
      expect(
        parseAnimeXProgress(animeXProxyOrigin, url, tick(duration: duration)),
        isNull,
      );
    }
    for (final episode in [
      double.nan,
      double.infinity,
      -1,
      0,
      3.5,
      '3',
      null,
    ]) {
      expect(
        parseAnimeXProgress(animeXProxyOrigin, url, tick(episode: episode)),
        isNull,
      );
    }
    for (final data in [
      'not json',
      '[]',
      '{}',
      null,
      {'type': 'cinesrc-progress'},
      '{"type":"animex-progress","position":1e999,"duration":100,"episode":3}',
    ]) {
      expect(parseAnimeXProgress(animeXProxyOrigin, url, data), isNull);
    }
  });

  test(
    'provider origin must match this frame, with only Videasy redirect exception',
    () {
      expect(animeXPlayerMessageOriginAllowed(url, animeXProxyOrigin), isTrue);
      expect(
        animeXPlayerMessageOriginAllowed(url, 'https://cinesrc.st'),
        isFalse,
      );
      expect(
        animeXPlayerMessageOriginAllowed(
          'https://player.videasy.net/anime/1',
          'https://player.videasy.to',
        ),
        isTrue,
      );
      expect(
        animeXPlayerMessageOriginAllowed(url, 'https://player.videasy.to'),
        isFalse,
      );
      for (final other in [
        'not a url',
        'about:blank',
        'javascript:alert(1)',
        'https://user@everglow-1c6db.web.app/embed.html',
      ]) {
        expect(
          animeXPlayerMessageOriginAllowed(
            other,
            'https://everglow-1c6db.web.app',
          ),
          isFalse,
        );
      }
    },
  );

  test('Videasy also rejects overflow and out-of-duration seconds', () {
    for (final data in [
      '{"timestamp":1e999,"duration":100}',
      '{"timestamp":1,"duration":1e999}',
      '{"timestamp":101,"duration":100}',
    ]) {
      expect(parseVideasyProgress('https://player.videasy.to', data), isNull);
    }
  });
}
