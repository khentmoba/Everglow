import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:everglow/features/watch_party/data/models/watch_party_room.dart';
import 'package:everglow/features/watch_party/data/services/watch_party_stream_resolver.dart';

WatchPartyRoom _room({
  String mediaType = 'movie',
  int tmdbId = 550,
  int? malId,
  bool isAnime = false,
  int? season,
  int? episode,
  String title = 'Fight Club',
}) {
  return WatchPartyRoom(
    id: 'demo',
    hostUid: 'a',
    hostName: 'Khent',
    partnerUid: 'b',
    partnerName: 'Clair',
    mediaType: mediaType,
    tmdbId: tmdbId,
    malId: malId,
    isAnime: isAnime,
    season: season,
    episode: episode,
    title: title,
    posterPath: '',
    state: 'paused',
    currentTime: 0,
    updatedAt: DateTime.utc(2026, 1, 1),
    updatedBy: 'a',
    createdAt: DateTime.utc(2026, 1, 1),
    active: true,
  );
}

void main() {
  group('WatchPartyStreamResolver.uriFor', () {
    test('builds a cinema movie request against our Worker', () {
      final uri = WatchPartyStreamResolver().uriFor(_room());
      expect(uri.origin, 'https://everglow-stream.khentplaysmoba.workers.dev');
      expect(uri.path, '/proxyAnime');
      expect(uri.queryParameters['source'], 'cinema');
      expect(uri.queryParameters['type'], 'movie');
      expect(uri.queryParameters['tmdbId'], '550');
      expect(uri.queryParameters['s'], '1');
      expect(uri.queryParameters['e'], '1');
      expect(uri.queryParameters['format'], 'json');
      expect(uri.queryParameters['title'], 'Fight Club');
    });

    test('carries the season and episode for a cinema series', () {
      final uri = WatchPartyStreamResolver().uriFor(
        _room(mediaType: 'tv', tmdbId: 1399, season: 2, episode: 5),
      );
      expect(uri.queryParameters['type'], 'tv');
      expect(uri.queryParameters['s'], '2');
      expect(uri.queryParameters['e'], '5');
    });

    test('builds an anime request from the MAL id', () {
      final uri = WatchPartyStreamResolver().uriFor(
        _room(
          mediaType: 'tv',
          tmdbId: 21,
          malId: 21,
          isAnime: true,
          season: 1,
          episode: 3,
          title: 'One Piece',
        ),
      );
      expect(uri.queryParameters['source'], 'megaplay');
      expect(uri.queryParameters['malId'], '21');
      expect(uri.queryParameters['ep'], '3');
      expect(uri.queryParameters['audio'], 'sub');
      expect(uri.queryParameters['format'], 'json');
    });

    test('an anime film always asks for episode 1', () {
      final uri = WatchPartyStreamResolver().uriFor(
        _room(
          mediaType: 'movie',
          tmdbId: 16498,
          malId: 16498,
          isAnime: true,
          episode: 7,
        ),
      );
      expect(uri.queryParameters['ep'], '1');
    });

    test('refuses a room without a title id', () {
      expect(
        () => WatchPartyStreamResolver().uriFor(_room(tmdbId: 0)),
        throwsStateError,
      );
      expect(
        () => WatchPartyStreamResolver().uriFor(
          _room(tmdbId: 0, malId: 0, isAnime: true),
        ),
        throwsStateError,
      );
    });
  });

  group('WatchPartyStreamResolver.parse', () {
    test('reads the manifest and subtitle tracks', () {
      final stream = WatchPartyStreamResolver.parse({
        'src': 'https://worker.example/proxyMegavidHls?u=abc',
        'tracks': [
          {'file': 'https://worker.example/sub.vtt', 'label': 'English'},
          {'file': 'https://worker.example/sub2.vtt', 'label': 'Spanish'},
          {'file': 'javascript:alert(1)', 'label': 'Bad'},
          {'label': 'No URL'},
        ],
        'title': 'Demo Film',
      });
      expect(stream.src, 'https://worker.example/proxyMegavidHls?u=abc');
      expect(stream.title, 'Demo Film');
      expect(stream.subtitles, hasLength(2));
      expect(stream.subtitles.first.label, 'English');
      expect(stream.subtitles.last.url, 'https://worker.example/sub2.vtt');
    });

    test('rejects a body without a playable URL', () {
      expect(
        () => WatchPartyStreamResolver.parse({'src': 'http://insecure'}),
        throwsStateError,
      );
      expect(
        () => WatchPartyStreamResolver.parse({'tracks': []}),
        throwsStateError,
      );
    });
  });

  group('WatchPartyStreamResolver.resolve', () {
    test('calls the Worker and parses the JSON response', () async {
      Uri? requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode({
            'src': 'https://worker.example/proxyMegavidHls?u=abc',
            'tracks': [
              {'file': 'https://worker.example/en.vtt', 'label': 'English'},
            ],
            'title': 'Fight Club',
          }),
          200,
        );
      });
      final resolver = WatchPartyStreamResolver(client: client);
      final stream = await resolver.resolve(_room());
      expect(requested?.queryParameters['format'], 'json');
      expect(stream.src, 'https://worker.example/proxyMegavidHls?u=abc');
      expect(stream.subtitles.single.label, 'English');
    });

    test('reports a non-200 answer instead of playing nothing', () async {
      final client = MockClient((_) async => http.Response('nope', 502));
      final resolver = WatchPartyStreamResolver(client: client);
      expect(() => resolver.resolve(_room()), throwsStateError);
    });
  });
}
