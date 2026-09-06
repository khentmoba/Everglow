import 'package:everglow/features/watch_party/data/models/watch_party_room.dart';
import 'package:everglow/features/watch_party/data/models/watch_party_server.dart';
import 'package:everglow/features/watch_party/data/services/watch_party_server_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WatchPartyServer', () {
    test('round-trips through JSON', () {
      const server = WatchPartyServer(
        id: 'home-server',
        name: 'Home server',
        shortName: 'Home',
        host: 'home-server',
        type: 'hls',
        streamUrl: 'https://media.example.com/stream/master.m3u8',
        subtitleUrl: 'https://media.example.com/stream/en.vtt',
        proxyEnabled: true,
        isRecommended: true,
      );

      final restored = WatchPartyServer.fromJson(server.toJson());

      expect(restored.id, 'home-server');
      expect(restored.name, 'Home server');
      expect(restored.host, 'home-server');
      expect(restored.isHls, isTrue);
      expect(restored.streamUrl, server.streamUrl);
      expect(restored.subtitleUrl, server.subtitleUrl);
      expect(restored.proxyEnabled, isTrue);
      expect(restored.isRecommended, isTrue);
    });

    test('fromRoom maps the fields stored on a room', () {
      final server = WatchPartyServer.fromRoom(
        serverType: 'hls',
        serverName: 'Plex',
        serverHost: 'plex',
        streamUrl: 'https://plex.example.com/master.m3u8',
        subtitleUrl: 'https://plex.example.com/en.vtt',
        proxyEnabled: true,
      );

      expect(server.type, 'hls');
      expect(server.name, 'Plex');
      expect(server.host, 'plex');
      expect(server.streamUrl, 'https://plex.example.com/master.m3u8');
      expect(server.subtitleUrl, 'https://plex.example.com/en.vtt');
      expect(server.proxyEnabled, isTrue);
    });

    test('proxyUrlFor wraps the upstream URL like AniChan proxy routes', () {
      final proxied = WatchPartyServerService.proxyUrlFor(
        'https://media.example.com/master.m3u8',
      );

      expect(
        proxied,
        startsWith(
          'https://us-central1-everglow-1c6db.cloudfunctions.net/'
          'proxyWatchStream?url=',
        ),
      );
      expect(proxied, contains('https%3A%2F%2Fmedia.example.com'));
    });
  });

  group('WatchPartyRoom server fields', () {
    WatchPartyRoom baseRoom({
      String? serverType,
      String? serverName,
      String? serverHost,
      String? streamUrl,
      String? subtitleUrl,
      bool proxyEnabled = false,
    }) {
      return WatchPartyRoom(
        id: 'a_b',
        hostUid: 'a',
        hostName: 'A',
        partnerUid: 'b',
        partnerName: 'B',
        mediaType: 'tv',
        tmdbId: 1,
        isAnime: false,
        season: 1,
        episode: 2,
        title: 'Test Show',
        posterPath: '',
        serverType: serverType,
        serverName: serverName,
        serverHost: serverHost,
        streamUrl: streamUrl,
        subtitleUrl: subtitleUrl,
        proxyEnabled: proxyEnabled,
        state: 'playing',
        currentTime: 12.0,
        updatedAt: DateTime(2026, 8, 13),
        updatedBy: 'a',
        createdAt: DateTime(2026, 8, 13),
        active: true,
      );
    }

    test('toFirestore persists server identity fields', () {
      final room = baseRoom(
        serverType: 'hls',
        serverName: 'Home server',
        serverHost: 'home-server',
        streamUrl: 'https://media.example.com/master.m3u8',
        subtitleUrl: 'https://media.example.com/en.vtt',
        proxyEnabled: true,
      );

      final data = room.toFirestore();
      expect(data['serverType'], 'hls');
      expect(data['serverName'], 'Home server');
      expect(data['serverHost'], 'home-server');
      expect(data['streamUrl'], 'https://media.example.com/master.m3u8');
      expect(data['subtitleUrl'], 'https://media.example.com/en.vtt');
      expect(data['proxyEnabled'], isTrue);
    });

    test('toFirestore omits server fields when using default providers', () {
      final data = baseRoom().toFirestore();
      expect(data.containsKey('serverType'), isFalse);
      expect(data.containsKey('streamUrl'), isFalse);
    });

    test('copyWithServer switches and clears the active server', () {
      final switched = baseRoom().copyWithServer(
        serverType: 'hls',
        serverName: 'Plex',
        serverHost: 'plex',
        streamUrl: 'https://plex.example.com/master.m3u8',
        proxyEnabled: true,
      );
      expect(switched.streamUrl, 'https://plex.example.com/master.m3u8');
      expect(switched.serverHost, 'plex');
      expect(switched.proxyEnabled, isTrue);

      final cleared = switched.copyWithServer();
      expect(cleared.streamUrl, isNull);
      expect(cleared.serverType, isNull);
      expect(cleared.proxyEnabled, isFalse);
    });
  });
}
