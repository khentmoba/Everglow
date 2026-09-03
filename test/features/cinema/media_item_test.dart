import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';

MediaItem _item({
  required String mediaType,
  int? currentEpisode,
  String status = 'watching',
  bool isAnime = false,
}) {
  return MediaItem(
    id: 'm1',
    tmdbId: 1,
    title: 'Test',
    mediaType: mediaType,
    posterPath: '',
    status: status,
    isAnime: isAnime,
    addedAt: DateTime(2026, 1, 1),
    currentSeason: 1,
    currentEpisode: currentEpisode,
  );
}

void main() {
  group('MediaItem.isMovie', () {
    test('movie items with episode progress are still movies', () {
      final movie = _item(mediaType: 'movie', currentEpisode: 1);
      expect(movie.isMovie, isTrue);
    });

    test('tv series are never movies', () {
      final tv = _item(mediaType: 'tv', currentEpisode: 4);
      expect(tv.isMovie, isFalse);
    });

    test('anime movies are movies', () {
      final animeMovie = _item(mediaType: 'movie', currentEpisode: 1);
      expect(animeMovie.isMovie, isTrue);
    });

    test('fromFirestore defaults to movie when mediaType is missing', () {
      final parsed = MediaItem.fromFirestore({
        'title': 'X',
        'tmdbId': 1,
        'status': 'watching',
      }, 'doc');
      expect(parsed.isMovie, isTrue);
    });
  });

  group('MediaItem shelf visibility (cinema owns every movie)', () {
    test('anime movies belong in cinema shelves', () {
      final animeMovie = _item(
        mediaType: 'movie',
        status: 'watching-self',
        isAnime: true,
      );
      expect(animeMovie.isCinemaItem, isTrue);
      expect(animeMovie.isCurrentlyWatching, isTrue);
    });

    test('watched anime movies belong in cinema Watched', () {
      final animeMovie = _item(
        mediaType: 'movie',
        status: 'watched-self',
        isAnime: true,
      );
      expect(animeMovie.isCinemaItem, isTrue);
      expect(animeMovie.isWatched, isTrue);
    });

    test('anime series stay out of cinema shelves', () {
      final animeTv = _item(
        mediaType: 'tv',
        status: 'watching-self',
        isAnime: true,
      );
      expect(animeTv.isCinemaItem, isFalse);
      expect(animeTv.isAnimeSeries, isTrue);
    });

    test('live-action movies and tv stay in cinema shelves', () {
      final movie = _item(mediaType: 'movie', status: 'watched-self');
      final tv = _item(mediaType: 'tv', status: 'watching-self');
      expect(movie.isCinemaItem, isTrue);
      expect(tv.isCinemaItem, isTrue);
    });

    test('status matching tolerates whitespace and casing', () {
      final watched = _item(mediaType: 'movie', status: ' Watched-Self ');
      final watching = _item(mediaType: 'tv', status: 'WATCHING-BOTH');
      expect(watched.isWatched, isTrue);
      expect(watching.isCurrentlyWatching, isTrue);
    });

    test('cinema filter keeps movies, drops only anime series', () {
      final items = [
        _item(mediaType: 'movie', status: 'watching-self'),
        _item(mediaType: 'movie', status: 'watching-self', isAnime: true),
        _item(mediaType: 'tv', status: 'watching-self'),
        _item(mediaType: 'tv', status: 'watching-self', isAnime: true),
      ];
      final visible =
          items.where((i) => i.isCurrentlyWatching && i.isCinemaItem).toList();
      expect(visible.length, 3);
      expect(visible.any((i) => i.isAnimeSeries), isFalse);
    });
  });
}
