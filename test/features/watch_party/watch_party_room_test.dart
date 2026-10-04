import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/watch_party/data/models/watch_party_room.dart';

WatchPartyRoom _room({required bool active, required DateTime updatedAt}) {
  return WatchPartyRoom(
    id: 'a_b',
    hostUid: 'a',
    hostName: 'khentsgdz',
    partnerUid: 'b',
    partnerName: 'clairjassen',
    mediaType: 'movie',
    tmdbId: 1,
    isAnime: false,
    title: 'Test night',
    posterPath: '',
    state: 'paused',
    currentTime: 0,
    updatedAt: updatedAt,
    updatedBy: 'a',
    createdAt: updatedAt,
    active: active,
  );
}

void main() {
  group('WatchPartyRoom.isLive', () {
    test('fresh active room is live', () {
      final room = _room(active: true, updatedAt: DateTime.now());
      expect(room.isLive(), isTrue);
    });

    test('active room with an old heartbeat is not live', () {
      final room = _room(
        active: true,
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(room.isLive(), isFalse);
    });

    test('ended room is not live even when fresh', () {
      final room = _room(active: false, updatedAt: DateTime.now());
      expect(room.isLive(), isFalse);
    });

    test('custom grace period applies', () {
      final room = _room(
        active: true,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      expect(room.isLive(staleAfter: const Duration(minutes: 5)), isFalse);
      expect(room.isLive(staleAfter: const Duration(minutes: 30)), isTrue);
    });
  });

  group('WatchPartyRoom.beatBy', () {
    test('defaults to null when omitted', () {
      final room = _room(active: true, updatedAt: DateTime.now());
      expect(room.beatBy, isNull);
    });

    test('preserves beatBy when provided', () {
      final room = WatchPartyRoom(
        id: 'a_b',
        hostUid: 'a',
        hostName: 'khentsgdz',
        partnerUid: 'b',
        partnerName: 'clairjassen',
        mediaType: 'movie',
        tmdbId: 1,
        isAnime: false,
        title: 'Test night',
        posterPath: '',
        state: 'paused',
        currentTime: 0,
        updatedAt: DateTime.now(),
        updatedBy: 'a',
        beatBy: 'a',
        createdAt: DateTime.now(),
        active: true,
      );
      expect(room.beatBy, 'a');
    });

    test('copyWith updates or preserves beatBy', () {
      final room = _room(active: true, updatedAt: DateTime.now());
      final updated = room.copyWith(beatBy: 'b');
      expect(updated.beatBy, 'b');

      final preserved = updated.copyWith(currentTime: 42.0);
      expect(preserved.beatBy, 'b');
      expect(preserved.currentTime, 42.0);
    });
  });
}
