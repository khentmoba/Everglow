import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/cinema/data/models/video_source_config.dart';
import 'package:everglow/features/cinema/data/services/cinema_video_sources.dart';

void main() {
  const sharedSources = [
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
    ),
  ];

  group('CinemaVideoSources.selectable', () {
    test('promotes verified cinema servers and keeps shared sources', () {
      final providers = CinemaVideoSources.selectable(
        sharedSources,
        isAnime: false,
      );

      expect(providers.map((p) => p.id).toList(), [
        'everglow-embed',
        'flux-cinesrc',
        'videasy',
        'movish',
      ]);
      expect(providers.first.isRecommended, isTrue);
    });

    test('does not add cinema-only servers to anime playback', () {
      final providers = CinemaVideoSources.selectable(
        sharedSources,
        isAnime: true,
      );

      expect(providers.map((p) => p.id).toList(), ['videasy', 'movish']);
      expect(providers.any((p) => p.id.startsWith('flux-')), isFalse);
    });

    test(
      'deduplicates a cinema-only id already present in the shared list',
      () {
        const remoteCineSrc = VideoSourceConfig(
          id: 'flux-cinesrc',
          name: 'Remote CineSrc',
          shortName: 'Remote',
          movieUrl: 'https://example.com/movie/',
          tvUrl: 'https://example.com/tv/',
        );

        final providers = CinemaVideoSources.selectable([
          remoteCineSrc,
          ...sharedSources,
        ], isAnime: false);

        expect(providers.where((p) => p.id == 'flux-cinesrc').length, 1);
        expect(
          providers.firstWhere((p) => p.id == 'flux-cinesrc').name,
          'Remote CineSrc',
        );
        expect(providers.first.id, 'everglow-embed');
      },
    );
  });

  group('CinemaVideoSources.buildUrl', () {
    test('builds CineSrc movie URLs with the path style', () {
      expect(
        CinemaVideoSources.buildUrl(
          CinemaVideoSources.cineSrc,
          mediaType: 'movie',
          id: '603',
          season: 1,
          episode: 1,
        ),
        'https://cinesrc.st/embed/movie/603',
      );
    });

    test('builds CineSrc TV URLs with query season and episode', () {
      expect(
        CinemaVideoSources.buildUrl(
          CinemaVideoSources.cineSrc,
          mediaType: 'tv',
          id: '1399',
          season: 2,
          episode: 3,
        ),
        'https://cinesrc.st/embed/tv/1399?s=2&e=3',
      );
    });

    test('builds Everglow embed movie URLs with tmdbId query', () {
      expect(
        CinemaVideoSources.buildUrl(
          CinemaVideoSources.everglowEmbed,
          mediaType: 'movie',
          id: '603',
          season: 1,
          episode: 1,
        ),
        'https://everglow-1c6db.web.app/embed.html?tmdbId=603&type=movie',
      );
    });

    test('builds Everglow embed TV URLs with season and episode', () {
      expect(
        CinemaVideoSources.buildUrl(
          CinemaVideoSources.everglowEmbed,
          mediaType: 'tv',
          id: '1399',
          season: 2,
          episode: 3,
        ),
        'https://everglow-1c6db.web.app/embed.html?tmdbId=1399&type=tv&s=2&e=3',
      );
    });

    test('returns null for providers outside the cinema-only registry', () {
      expect(
        CinemaVideoSources.buildUrl(
          sharedSources.first,
          mediaType: 'movie',
          id: '603',
          season: 1,
          episode: 1,
        ),
        isNull,
      );
    });
  });
}
