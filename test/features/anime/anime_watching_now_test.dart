import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';

void main() {
  group('Anime Watching Now tests', () {
    test('Anime series marked watching-self has isCurrentlyWatching and isAnime true', () {
      final anime = MediaItem(
        id: 'a1',
        tmdbId: 52991,
        title: 'Sousou no Frieren',
        mediaType: 'tv',
        posterPath: 'https://cdn.myanimelist.net/images/anime/1015/138006.jpg',
        status: 'watching-self',
        isAnime: true,
        userName: 'khentsgdz',
        addedAt: DateTime(2026, 9, 10),
        currentSeason: 1,
        currentEpisode: 4,
      );

      expect(anime.isAnime, isTrue);
      expect(anime.isCurrentlyWatching, isTrue);
      expect(anime.isWatched, isFalse);
      expect(anime.isToWatch, isFalse);
      expect(anime.isCinemaItem, isFalse); // Anime series live in Anime rail
      expect(anime.isAnimeSeries, isTrue);
    });

    test('Anime movie marked watching-khent has isCurrentlyWatching true and belongs to both shelves', () {
      final animeMovie = MediaItem(
        id: 'a2',
        tmdbId: 372058,
        title: 'Kimi no Na wa.',
        mediaType: 'movie',
        posterPath: 'https://cdn.myanimelist.net/images/anime/1915/115598.jpg',
        status: 'watching-khent',
        isAnime: true,
        userName: 'khentsgdz',
        addedAt: DateTime(2026, 9, 10),
      );

      expect(animeMovie.isAnime, isTrue);
      expect(animeMovie.isCurrentlyWatching, isTrue);
      expect(animeMovie.isMovie, isTrue);
      expect(animeMovie.isCinemaItem, isTrue); // Anime films belong to cinema too
      expect(animeMovie.isAnimeSeries, isFalse);
    });

    test('Watched anime series does not appear in currently watching', () {
      final watchedAnime = MediaItem(
        id: 'a3',
        tmdbId: 5114,
        title: 'Fullmetal Alchemist: Brotherhood',
        mediaType: 'tv',
        posterPath: 'https://cdn.myanimelist.net/images/anime/1208/94745.jpg',
        status: 'watched-self',
        isAnime: true,
        userName: 'khentsgdz',
        addedAt: DateTime(2026, 9, 1),
        currentSeason: 1,
        currentEpisode: 64,
      );

      expect(watchedAnime.isAnime, isTrue);
      expect(watchedAnime.isCurrentlyWatching, isFalse);
      expect(watchedAnime.isWatched, isTrue);
    });

    test('toFirestore preserves isAnime, status, currentEpisode and posterPath', () {
      final anime = MediaItem(
        id: 'a4',
        tmdbId: 38000,
        title: 'Kimetsu no Yaiba',
        mediaType: 'tv',
        posterPath: 'https://cdn.myanimelist.net/images/anime/1286/99889.jpg',
        status: 'watching-self',
        isAnime: true,
        userName: 'clairjassen',
        addedAt: DateTime(2026, 9, 10),
        currentSeason: 1,
        currentEpisode: 12,
        currentTimestamp: 540,
        durationSeconds: 1440,
      );

      final map = anime.toFirestore();
      expect(map['isAnime'], isTrue);
      expect(map['status'], 'watching-self');
      expect(map['currentEpisode'], 12);
      expect(map['currentTimestamp'], 540);
      expect(map['durationSeconds'], 1440);
      expect(map['posterPath'], 'https://cdn.myanimelist.net/images/anime/1286/99889.jpg');
      expect(map['userName'], 'clairjassen');
    });
  });
}
