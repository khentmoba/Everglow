import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/video_source_config.dart';
import 'package:everglow/features/cinema/data/services/video_source_service.dart';

/// A stale remote config: the four servers retired on 2026-10-04 are still
/// listed, and VidBolt/VidLink still carry `sandboxSafe: true` — which is
/// exactly what made them answer "Playback Disabled" / "Please Disable
/// Sandbox" instead of streaming.
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
    id: 'vidlink',
    name: 'VidLink',
    shortName: 'VidLink',
    movieUrl: 'https://vidlink.pro/movie/',
    tvUrl: 'https://vidlink.pro/tv/',
    sandboxSafe: true,
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
    id: 'vidcore',
    name: 'VidCore',
    shortName: 'VidCore',
    movieUrl: 'https://vidcore.org/embed/movie/',
    tvUrl: 'https://vidcore.org/embed/tv/',
    isRecommended: true,
    sandboxSafe: true,
  ),
  VideoSourceConfig(
    id: 'vidsrc',
    name: 'VidSrc',
    shortName: 'VidSrc',
    movieUrl: 'https://vidsrc.to/embed/movie/',
    tvUrl: 'https://vidsrc.to/embed/tv/',
  ),
  VideoSourceConfig(
    id: 'multiembed',
    name: 'MultiEmbed',
    shortName: 'MultiEmbed',
    movieUrl: 'https://multiembed.mov/?video_id=',
    tvUrl: 'https://multiembed.mov/?video_id=',
  ),
];

void main() {
  group('VideoSourceService.currentList', () {
    test('drops servers that died upstream, even from a stale remote list', () {
      final ids = VideoSourceService.currentList(staleRemote)
          .map((p) => p.id)
          .toList();

      expect(ids, isNot(contains('videasy')));
      expect(ids, isNot(contains('movish')));
      expect(ids, isNot(contains('111movies')));
      expect(ids, isNot(contains('multiembed')));
      expect(
        ids,
        // No-ads group first (input order kept), ad-heavy mirrors last.
        ['everglow-embed', 'vidbolt', 'vidlink', 'vidcore', 'vidsrc'],
      );
    });

    test('clears sandboxSafe on the servers that refuse a sandbox', () {
      final byId = {
        for (final p in VideoSourceService.currentList(staleRemote)) p.id: p,
      };

      expect(byId['vidbolt']!.sandboxSafe, isFalse);
      expect(byId['vidlink']!.sandboxSafe, isFalse);
      // Untouched: VidCore and Everglow both stream fine inside a sandbox.
      expect(byId['vidcore']!.sandboxSafe, isTrue);
      expect(byId['everglow-embed']!.sandboxSafe, isTrue);
    });

    test('keeps everything else about a provider intact', () {
      final byId = {
        for (final p in VideoSourceService.currentList(staleRemote)) p.id: p,
      };
      final vidbolt = byId['vidbolt']!;

      expect(vidbolt.name, 'VidBolt');
      expect(vidbolt.movieUrl, 'https://vidbolt.xyz/movie/');
      expect(vidbolt.tvUrl, 'https://vidbolt.xyz/tv/');
      expect(vidbolt.isRecommended, isTrue);
    });

    test('still groups no-ads providers above ad-heavy mirrors', () {
      final ids = VideoSourceService.currentList(staleRemote)
          .map((p) => p.id)
          .toList();

      // vidsrc is ad-heavy, so it sorts last even though the remote list
      // placed it earlier.
      expect(ids.last, 'vidsrc');
      expect(ids.indexOf('vidbolt'), lessThan(ids.indexOf('vidsrc')));
    });
  });

  group('VideoSourceService.providers', () {
    test('offers no retired server from the hardcoded fallback', () {
      final ids = VideoSourceService().providers.map((p) => p.id).toList();

      expect(ids, isNot(contains('videasy')));
      expect(ids, isNot(contains('movish')));
      expect(ids, isNot(contains('111movies')));
      expect(ids, isNot(contains('multiembed')));
    });

    test('leaves VidBolt and VidLink unsandboxed', () {
      final byId = {
        for (final p in VideoSourceService().providers) p.id: p,
      };

      expect(byId['vidbolt']!.sandboxSafe, isFalse);
      expect(byId['vidlink']!.sandboxSafe, isFalse);
    });
  });
}