import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/animex_home_cache.dart';

MediaItem _sampleItem() {
  return MediaItem(
    id: '',
    tmdbId: 1535,
    title: 'Death Note',
    mediaType: 'tv',
    posterPath: 'https://cdn.example/poster.jpg',
    backdropPath: 'https://cdn.example/banner.jpg',
    year: '2006',
    status: '',
    isAnime: true,
    addedAt: DateTime(2026, 8, 16),
    source: 'jikan',
    anilistId: 12345,
    synopsis: 'A death note changes everything.',
    episodeCount: 37,
    airingStatus: 'Finished Airing',
    format: 'TV',
    studio: 'Madhouse',
    genres: const ['Mystery', 'Supernatural', 'Psychological', 'Thriller'],
    score: 8.6,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaItem home-row JSON', () {
    test('round-trips every field the anime home cards need', () {
      final original = _sampleItem();
      final restored = MediaItem.fromJson(original.toJson());

      expect(restored.tmdbId, original.tmdbId);
      expect(restored.title, original.title);
      expect(restored.mediaType, original.mediaType);
      expect(restored.posterPath, original.posterPath);
      expect(restored.backdropPath, original.backdropPath);
      expect(restored.year, original.year);
      expect(restored.isAnime, isTrue);
      expect(restored.anilistId, original.anilistId);
      expect(restored.synopsis, original.synopsis);
      expect(restored.episodeCount, original.episodeCount);
      expect(restored.airingStatus, original.airingStatus);
      expect(restored.format, original.format);
      expect(restored.studio, original.studio);
      expect(restored.genres, original.genres);
      expect(restored.score, original.score);
    });
  });

  group('AnimexHomeCache', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists a row and restores it on the next load', () async {
      final cache = AnimexHomeCache.instance;
      final initial = await cache.load();
      expect(initial, isEmpty);

      await cache.saveRow('trending', [_sampleItem()]);

      final after = await cache.load();
      expect(after['trending'], hasLength(1));
      expect(after['trending']!.first.title, 'Death Note');
      expect(after['trending']!.first.score, 8.6);
    });
  });
}
