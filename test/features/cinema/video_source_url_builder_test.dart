import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/video_source_config.dart';
import 'package:everglow/features/cinema/data/services/cinema_video_sources.dart';
import 'package:everglow/features/cinema/data/services/video_source_url_builder.dart';

void main() {
  const videasy = VideoSourceConfig(
    id: 'videasy',
    name: 'Videasy',
    shortName: 'Videasy',
    movieUrl: 'https://player.videasy.net/movie/',
    tvUrl: 'https://player.videasy.net/tv/',
    isRecommended: true,
  );
  const vidsrc = VideoSourceConfig(
    id: 'vidsrc',
    name: 'VidSrc',
    shortName: 'VidSrc',
    movieUrl: 'https://vidsrc.to/embed/movie/',
    tvUrl: 'https://vidsrc.to/embed/tv/',
  );
  const multiembed = VideoSourceConfig(
    id: 'multiembed',
    name: 'MultiEmbed',
    shortName: 'MultiEmbed',
    movieUrl: 'https://multiembed.mov/?video_id=',
    tvUrl: 'https://multiembed.mov/?video_id=',
  );

  group('buildVideoSourceUrl', () {
    test('builds Videasy movie URLs with autoplay', () {
      expect(
        buildVideoSourceUrl(
          videasy,
          mediaType: 'movie',
          id: '603',
          season: 1,
          episode: 1,
        ),
        'https://player.videasy.net/movie/603?autoplay=true',
      );
    });

    test('builds Videasy TV URLs with episode selector params', () {
      expect(
        buildVideoSourceUrl(
          videasy,
          mediaType: 'tv',
          id: '1399',
          season: 2,
          episode: 3,
        ),
        'https://player.videasy.net/tv/1399/2/3?autoplay=true&nextButton=true&episodeSelector=true',
      );
    });

    test('builds VidSrc TV URLs with season and episode query', () {
      expect(
        buildVideoSourceUrl(
          vidsrc,
          mediaType: 'tv',
          id: '1399',
          season: 2,
          episode: 3,
        ),
        'https://vidsrc.to/embed/tv/1399?season=2&episode=3',
      );
    });

    test('builds MultiEmbed movie URLs with tmdb flag', () {
      expect(
        buildVideoSourceUrl(
          multiembed,
          mediaType: 'movie',
          id: '603',
          season: 1,
          episode: 1,
        ),
        'https://multiembed.mov/?video_id=603&tmdb=1',
      );
    });

    test('builds Everglow embed movie URLs with start passthrough', () {
      expect(
        buildVideoSourceUrl(
          CinemaVideoSources.everglowEmbed,
          mediaType: 'movie',
          id: '603',
          season: 1,
          episode: 1,
          startSeconds: 90,
        ),
        'https://everglow-1c6db.web.app/embed.html?tmdbId=603&type=movie&start=90',
      );
    });

    test('builds Everglow embed TV URLs with season and episode', () {
      expect(
        buildVideoSourceUrl(
          CinemaVideoSources.everglowEmbed,
          mediaType: 'tv',
          id: '1399',
          season: 2,
          episode: 3,
        ),
        'https://everglow-1c6db.web.app/embed.html?tmdbId=1399&type=tv&s=2&e=3',
      );
    });
  });
}
