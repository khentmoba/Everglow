import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/video_source_config.dart';
import 'package:everglow/features/cinema/data/services/video_source_service.dart';

/// A stale remote config: every retired server is still listed, and VidLink
/// still carries `sandboxSafe: true` — which is exactly what made it answer
/// "Please Disable Sandbox" instead of streaming.
///
/// `admirror` stands in for any ad-heavy provider so the ordering rule stays
/// under test without depending on a real server that happens to be alive.
const staleRemote = <VideoSourceConfig>[
  VideoSourceConfig(
    id: 'everglow-embed',
    name: 'Everglow',
    shortName: 'Everglow',
    movieUrl: 'https://everglow-1c6db.web.app/embed.html',
    tvUrl: 'https://everglow-1c6db.web.app/embed.html',
    isRecommended: true,
    sandboxSafe: true,
  ),
  VideoSourceConfig(
    id: 'videasy',
    name: 'Videasy',
    shortName: 'Videasy',
    movieUrl: 'https://player.videasy.net/movie/',
    tvUrl: 'https://player.videasy.net/tv/',
    isRecommended: true,
  ),
  VideoSourceConfig(
    id: 'movish',
    name: 'Movish',
    shortName: 'Movish',
    movieUrl: 'https://movish.to/moviebox-embed/move/',
    tvUrl: 'https://movish.to/moviebox-embed/tv/',
    isRecommended: true,
    sandboxSafe: true,
  ),
  VideoSourceConfig(
    id: 'vidbolt',
    name: 'VidBolt',
    shortName: 'VidBolt',
    movieUrl: 'https://vidbolt.xyz/movie/',
    tvUrl: 'https://vidbolt.xyz/tv/',
    isRecommended: true,
    sandboxSafe: true,
  ),
  VideoSourceConfig(
    id: 'vsembed',
    name: 'VsEmbed',
    shortName: 'VsEmbed',
    movieUrl: 'https://vsembed.ru/embed/movie/',
    tvUrl: 'https://vsembed.ru/embed/',
  ),
  VideoSourceConfig(
    id: 'vidrock',
    name: 'VidRock',
    shortName: 'VidRock',
    movieUrl: 'https://vidrock.ru/movie/',
    tvUrl: 'https://vidrock.ru/tv/',
  ),
  VideoSourceConfig(
    id: 'vidsrc',
    name: 'VidSrc',
    shortName: 'VidSrc',
    movieUrl: 'https://vidsrc.to/embed/movie/',
    tvUrl: 'https://vidsrc.to/embed/tv/',
  ),
  VideoSourceConfig(
    id: '111movies',
    name: '111Movies',
    shortName: '111Movies',
    movieUrl: 'https://111movies.com/movie/',
    tvUrl: 'https://111movies.com/tv/',
    sandboxSafe: true,
  ),
  VideoSourceConfig(
    id: 'multiembed',
    name: 'MultiEmbed',
    shortName: 'MultiEmbed',
    movieUrl: 'https://multiembed.mov/?video_id=',
    tvUrl: 'https://multiembed.mov/?video_id=',
  ),
  VideoSourceConfig(
    id: 'vidlink',
    name: 'VidLink',
    shortName: 'VidLink',
    movieUrl: 'https://vidlink.pro/movie/',
    tvUrl: 'https://vidlink.pro/tv/',
    sandboxSafe: true,
  ),
  VideoSourceConfig(
    id: 'vidcore',
    name: 'VidCore',
    shortName: 'VidCore',
    movieUrl: 'https://vidcore.org/embed/movie/',
    tvUrl: 'https://vidcore.org/embed/tv/',
    isRecommended: true,
    sandboxSafe: true,
  ),
  VideoSourceConfig(
    id: 'admirror',
    name: 'AdMirror',
    shortName: 'AdMirror',
    movieUrl: 'https://admirror.example/movie/',
    tvUrl: 'https://admirror.example/tv/',
  ),
];

void main() {
  group('VideoSourceService.currentList', () {
    test('drops servers that died upstream, even from a stale remote list', () {
      final ids = VideoSourceService.currentList(staleRemote)
          .map((p) => p.id)
          .toList();

      for (final dead in [
        'videasy',
        'movish',
        '111movies',
        'multiembed',
        'vidbolt',
        'vidrock',
        'vsembed',
        'vidsrc',
      ]) {
        expect(ids, isNot(contains(dead)), reason: '$dead is retired');
      }
      expect(
        ids,
        // No-ads group first (input order kept), ad-heavy mirrors last.
        ['everglow-embed', 'vidlink', 'vidcore', 'admirror'],
      );
    });

    test('clears sandboxSafe on the server that refuses a sandbox', () {
      final byId = {
        for (final p in VideoSourceService.currentList(staleRemote)) p.id: p,
      };

      expect(byId['vidlink']!.sandboxSafe, isFalse);
      // Untouched: VidCore and Everglow both stream fine inside a sandbox.
      expect(byId['vidcore']!.sandboxSafe, isTrue);
      expect(byId['everglow-embed']!.sandboxSafe, isTrue);
    });

    test('keeps everything else about a provider intact', () {
      final byId = {
        for (final p in VideoSourceService.currentList(staleRemote)) p.id: p,
      };
      final vidcore = byId['vidcore']!;

      expect(vidcore.name, 'VidCore');
      expect(vidcore.movieUrl, 'https://vidcore.org/embed/movie/');
      expect(vidcore.tvUrl, 'https://vidcore.org/embed/tv/');
      expect(vidcore.isRecommended, isTrue);
    });

    test('still groups no-ads providers above ad-heavy mirrors', () {
      final ids = VideoSourceService.currentList(staleRemote)
          .map((p) => p.id)
          .toList();

      // admirror is ad-heavy, so it sorts last even though the remote list
      // placed it earlier.
      expect(ids.last, 'admirror');
      expect(ids.indexOf('vidcore'), lessThan(ids.indexOf('admirror')));
    });
  });

  group('VideoSourceService.providers', () {
    test('offers no retired server from the hardcoded fallback', () {
      final ids = VideoSourceService().providers.map((p) => p.id).toList();

      for (final dead in [
        'videasy',
        'movish',
        '111movies',
        'multiembed',
        'vidbolt',
        'vidrock',
        'vsembed',
        'vidsrc',
      ]) {
        expect(ids, isNot(contains(dead)), reason: '$dead is retired');
      }
      expect(ids, ['everglow-embed', 'vidcore', 'vidlink']);
    });

    test('leaves VidLink unsandboxed', () {
      final byId = {
        for (final p in VideoSourceService().providers) p.id: p,
      };

      expect(byId['vidlink']!.sandboxSafe, isFalse);
    });
  });
}
