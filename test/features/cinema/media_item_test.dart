import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';

MediaItem _item({required String mediaType, int? currentEpisode}) {
  return MediaItem(
    id: 'm1',
    tmdbId: 1,
    title: 'Test',
    mediaType: mediaType,
    posterPath: '',
    status: 'watching',
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
}
