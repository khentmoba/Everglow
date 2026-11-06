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

  group('WatchPartyRoom.livePositionAt', () {
    WatchPartyRoom room({
      required String state,
      required double currentTime,
      DateTime? positionAt,
      DateTime? updatedAt,
    }) {
      final anchor = updatedAt ?? DateTime.utc(2026, 1, 1, 12);
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
        state: state,
        currentTime: currentTime,
        positionAt: positionAt,
        updatedAt: anchor,
        updatedBy: 'a',
        createdAt: anchor,
        active: true,
      );
    }

    test('adds elapsed server time while playing', () {
      final anchor = DateTime.utc(2026, 1, 1, 12);
      final r = room(
        state: 'playing',
        currentTime: 10,
        positionAt: anchor,
      );
      expect(
        r.livePositionAt(anchor.add(const Duration(seconds: 5))),
        closeTo(15, 0.001),
      );
    });

    test('stays at the anchor while paused', () {
      final anchor = DateTime.utc(2026, 1, 1, 12);
      final r = room(
        state: 'paused',
        currentTime: 10,
        positionAt: anchor,
      );
      expect(
        r.livePositionAt(anchor.add(const Duration(minutes: 5))),
        10,
      );
    });

    test('falls back to updatedAt for rooms written before positionAt', () {
      final anchor = DateTime.utc(2026, 1, 1, 12);
      final r = room(state: 'playing', currentTime: 10, updatedAt: anchor);
      expect(
        r.livePositionAt(anchor.add(const Duration(seconds: 3))),
        closeTo(13, 0.001),
      );
    });

    test('never runs backwards when the server clock is behind', () {
      final anchor = DateTime.utc(2026, 1, 1, 12);
      final r = room(
        state: 'playing',
        currentTime: 10,
        positionAt: anchor,
      );
      expect(
        r.livePositionAt(anchor.subtract(const Duration(seconds: 5))),
        10,
      );
    });

    test('a stale anchor does not skip the idle time', () {
      final anchor = DateTime.utc(2026, 1, 1, 12);
      final r = room(
        state: 'playing',
        currentTime: 10,
        positionAt: anchor,
      );
      expect(
        r.livePositionAt(anchor.add(const Duration(minutes: 5))),
        10,
      );
    });
  });

  group('WatchPartyRoom media and captions', () {
    test('copyWithMedia clears a stale anime id and episode', () {
      final r = _room(active: true, updatedAt: DateTime.now()).copyWith(
        malId: 21,
        isAnime: true,
        season: 2,
        episode: 5,
      );
      final movie = r.copyWithMedia(
        mediaType: 'movie',
        tmdbId: 550,
        isAnime: false,
        title: 'Fight Club',
        posterPath: '',
        state: 'paused',
        currentTime: 0,
      );
      expect(movie.malId, isNull);
      expect(movie.isAnime, isFalse);
      expect(movie.season, isNull);
      expect(movie.episode, isNull);
      expect(movie.tmdbId, 550);
    });

    test('captions default on and survive a server copy', () {
      final r = _room(active: true, updatedAt: DateTime.now());
      expect(r.captionsOn, isTrue);
      final withTrack = r.copyWithServer(
        serverType: 'everglow',
        subtitleUrl: 'https://example/en.vtt',
      );
      expect(withTrack.captionsOn, isTrue);
      expect(withTrack.subtitleUrl, 'https://example/en.vtt');
    });

    test('copyWithCaptions keeps the active server intact', () {
      final r = _room(active: true, updatedAt: DateTime.now())
          .copyWithServer(
            serverType: 'everglow',
            serverName: 'Everglow',
            serverHost: 'everglow',
            streamUrl: 'https://example/master.m3u8',
          );
      final captioned = r.copyWithCaptions(
        subtitleUrl: 'https://example/en.vtt',
        captionsOn: true,
      );
      expect(captioned.serverType, 'everglow');
      expect(captioned.serverName, 'Everglow');
      expect(captioned.streamUrl, 'https://example/master.m3u8');
      expect(captioned.subtitleUrl, 'https://example/en.vtt');
      expect(captioned.captionsOn, isTrue);
    });

    test('hasMedia is false for a freshly created room', () {
      final empty = _room(
        active: true,
        updatedAt: DateTime.now(),
      ).copyWithMedia(
        mediaType: 'movie',
        tmdbId: 0,
        isAnime: false,
        title: '',
        posterPath: '',
      );
      expect(empty.hasMedia, isFalse);
    });
  });
}
