import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/watch_party/data/models/media_ref.dart';
import 'package:everglow/features/watch_party/data/models/watch_party_room.dart';

void main() {
  group('MediaRef', () {
    test('movie reference initialization', () {
      const ref = MediaRef(
        tmdbId: 550,
        mediaType: 'movie',
        title: 'Fight Club',
        posterPath: '/path.jpg',
      );
      expect(ref.isMovie, isTrue);
      expect(ref.isAnime, isFalse);
      expect(ref.season, isNull);
      expect(ref.episode, isNull);
    });

    test('tv reference initialization', () {
      const ref = MediaRef(
        tmdbId: 1399,
        mediaType: 'tv',
        season: 2,
        episode: 5,
        title: 'Game of Thrones',
      );
      expect(ref.isMovie, isFalse);
      expect(ref.isAnime, isFalse);
      expect(ref.season, 2);
      expect(ref.episode, 5);
    });

    test('anime reference with malId', () {
      const ref = MediaRef(
        tmdbId: 21,
        malId: 21,
        mediaType: 'tv',
        isAnime: true,
        episode: 1000,
        title: 'One Piece',
      );
      expect(ref.isAnime, isTrue);
      expect(ref.malId, 21);
      expect(ref.episode, 1000);
    });
  });

  group('WatchPartyRoom.copyWith media fields', () {
    test('updates media fields cleanly', () {
      final now = DateTime.now();
      final room = WatchPartyRoom(
        id: 'khent_clair',
        hostUid: 'khent',
        hostName: 'khentsgdz',
        partnerUid: 'clair',
        partnerName: 'clairjassen',
        mediaType: 'movie',
        tmdbId: 100,
        isAnime: false,
        title: 'Old Movie',
        posterPath: '/old.jpg',
        state: 'playing',
        currentTime: 45.0,
        updatedAt: now,
        updatedBy: 'khent',
        createdAt: now,
        active: true,
      );

      final updated = room.copyWith(
        mediaType: 'tv',
        tmdbId: 200,
        malId: 50,
        isAnime: true,
        season: 1,
        episode: 3,
        title: 'New Anime',
        posterPath: '/new.jpg',
        state: 'paused',
        currentTime: 0.0,
      );

      expect(updated.title, 'New Anime');
      expect(updated.mediaType, 'tv');
      expect(updated.tmdbId, 200);
      expect(updated.malId, 50);
      expect(updated.isAnime, isTrue);
      expect(updated.season, 1);
      expect(updated.episode, 3);
      expect(updated.posterPath, '/new.jpg');
      expect(updated.state, 'paused');
      expect(updated.currentTime, 0.0);
    });
  });
}
