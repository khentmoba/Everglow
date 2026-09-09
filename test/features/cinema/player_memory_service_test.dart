import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/features/cinema/data/services/player_memory_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlayerMemoryService keys', () {
    test('keys anime by MAL id and the rest by TMDB id', () {
      expect(
        PlayerMemoryService.cinemaKey(
          id: 21,
          mediaType: 'tv',
          isAnime: true,
        ),
        'player_memory_v1/mal/21/tv',
      );
      expect(
        PlayerMemoryService.cinemaKey(
          id: 1399,
          mediaType: 'tv',
          isAnime: false,
        ),
        'player_memory_v1/tmdb/1399/tv',
      );
    });

    test('prefers AniList id for animex keys', () {
      expect(
        PlayerMemoryService.animexKey(anilistId: 1535, malId: 21),
        'player_memory_v1/animex/1535',
      );
      expect(
        PlayerMemoryService.animexKey(malId: 21),
        'player_memory_v1/animex/21',
      );
    });

    test('scopes watch-party volume per room', () {
      expect(
        PlayerMemoryService.watchPartyKey('room-1'),
        'player_memory_v1/party/room-1',
      );
    });
  });

  group('PlayerMemoryService save/load', () {
    test('loads empty memory for titles never opened', () async {
      final memory = await PlayerMemoryService().load(
        PlayerMemoryService.cinemaKey(
          id: 1,
          mediaType: 'movie',
          isAnime: false,
        ),
      );
      expect(memory.providerId, isNull);
      expect(memory.episode, isNull);
    });

    test('remembers provider and episode per title', () async {
      final service = PlayerMemoryService();
      final key = PlayerMemoryService.cinemaKey(
        id: 1399,
        mediaType: 'tv',
        isAnime: false,
      );
      await service.save(
        key,
        providerId: 'cinesrc',
        season: 2,
        episode: 3,
        positionSeconds: 420,
      );

      final memory = await service.load(key);
      expect(memory.providerId, 'cinesrc');
      expect(memory.season, 2);
      expect(memory.episode, 3);
      expect(memory.positionSeconds, 420);
    });

    test('merges saves so later picks keep earlier ones', () async {
      final service = PlayerMemoryService();
      final key = PlayerMemoryService.cinemaKey(
        id: 1399,
        mediaType: 'tv',
        isAnime: false,
      );
      await service.save(key, providerId: 'cinesrc', episode: 3);
      await service.save(key, episode: 4);

      final memory = await service.load(key);
      expect(memory.providerId, 'cinesrc');
      expect(memory.episode, 4);
    });

    test('clears the resume point on episode change', () async {
      final service = PlayerMemoryService();
      final key = PlayerMemoryService.cinemaKey(
        id: 1399,
        mediaType: 'tv',
        isAnime: false,
      );
      await service.save(key, episode: 3, positionSeconds: 420);
      await service.save(key, episode: 4, clearPosition: true);

      final memory = await service.load(key);
      expect(memory.episode, 4);
      expect(memory.positionSeconds, isNull);
    });

    test('keeps titles independent of each other', () async {
      final service = PlayerMemoryService();
      final show = PlayerMemoryService.cinemaKey(
        id: 1399,
        mediaType: 'tv',
        isAnime: false,
      );
      final movie = PlayerMemoryService.cinemaKey(
        id: 603,
        mediaType: 'movie',
        isAnime: false,
      );
      await service.save(show, providerId: 'cinesrc', episode: 3);
      await service.save(movie, providerId: 'videasy');

      expect((await service.load(show)).providerId, 'cinesrc');
      expect((await service.load(movie)).providerId, 'videasy');
      expect((await service.load(movie)).episode, isNull);
    });

    test('remembers animex server and sub/dub per anime', () async {
      final service = PlayerMemoryService();
      final key = PlayerMemoryService.animexKey(anilistId: 1535, malId: 21);
      await service.save(key, server: 'Server 3', audio: 'dub', episode: 12);

      final memory = await service.load(key);
      expect(memory.server, 'Server 3');
      expect(memory.audio, 'dub');
      expect(memory.episode, 12);
    });

    test('falls back to the global volume for titles without one', () async {
      final service = PlayerMemoryService();
      await service.save(
        PlayerMemoryService.watchPartyKey('room-1'),
        volume: 0.4,
      );

      final other = await service.load(
        PlayerMemoryService.watchPartyKey('room-2'),
      );
      expect(other.volume, 0.4);
    });

    test('prefers the per-title volume over the global one', () async {
      final service = PlayerMemoryService();
      await service.save(
        PlayerMemoryService.watchPartyKey('room-1'),
        volume: 0.4,
      );
      await service.save(
        PlayerMemoryService.watchPartyKey('room-2'),
        volume: 0.8,
      );

      expect(
        (await service.load(PlayerMemoryService.watchPartyKey('room-1')))
            .volume,
        0.4,
      );
      expect(
        (await service.load(PlayerMemoryService.watchPartyKey('room-2')))
            .volume,
        0.8,
      );
    });
  });

  group('PlayerMemory JSON', () {
    test('round-trips every field', () {
      const original = PlayerMemory(
        providerId: 'cinesrc',
        season: 2,
        episode: 3,
        positionSeconds: 420,
        server: 'Server 3',
        audio: 'dub',
        volume: 0.4,
      );
      final restored = PlayerMemory.fromJson(original.toJson());

      expect(restored.providerId, 'cinesrc');
      expect(restored.season, 2);
      expect(restored.episode, 3);
      expect(restored.positionSeconds, 420);
      expect(restored.server, 'Server 3');
      expect(restored.audio, 'dub');
      expect(restored.volume, 0.4);
    });
  });
}
