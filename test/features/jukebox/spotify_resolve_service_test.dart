import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:everglow/features/jukebox/data/models/music_status.dart';
import 'package:everglow/features/jukebox/data/services/spotify_resolve_service.dart';

void main() {
  group('SpotifyResolveService', () {
    test('populates albumName when status has No Album', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'trackId': 'spotify123',
            'trackName': 'Cruel Summer',
            'artistName': 'Taylor Swift',
            'albumName': 'Lover',
            'imageUrl': 'https://example.com/art.jpg',
            'embedUrl': 'https://open.spotify.com/embed/track/spotify123',
            'spotifyUrl': 'https://open.spotify.com/track/spotify123',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = SpotifyResolveService(
        client: client,
        idTokenProvider: () async => 'mock-token',
      );
      final initial = MusicStatus(
        username: 'khent',
        trackName: 'Cruel Summer',
        artistName: 'Taylor Swift',
        albumName: 'No Album',
        isPlaying: false,
        spotifyUrl: 'https://open.spotify.com/search/x',
      );

      final resolved = await service.resolve(initial);
      expect(resolved.hasSpotifyTrack, isTrue);
      expect(resolved.spotifyTrackId, 'spotify123');
      expect(resolved.albumName, 'Lover');
      expect(resolved.imageUrl, 'https://example.com/art.jpg');
    });

    test('preserves existing valid albumName', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'trackId': 'spotify456',
            'trackName': 'American Teenager',
            'artistName': 'Ethel Cain',
            'albumName': 'Different Album Name',
            'imageUrl': 'https://example.com/art.jpg',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = SpotifyResolveService(
        client: client,
        idTokenProvider: () async => 'mock-token',
      );
      final initial = MusicStatus(
        username: 'khent',
        trackName: 'American Teenager',
        artistName: 'Ethel Cain',
        albumName: 'Preacher\'s Daughter',
        isPlaying: false,
        spotifyUrl: 'https://open.spotify.com/search/x',
      );

      final resolved = await service.resolve(initial);
      expect(resolved.albumName, 'Preacher\'s Daughter');
    });

    test('clears No Album to empty string when Spotify has no album', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'trackId': 'spotify789',
            'trackName': 'Mystery Song',
            'artistName': 'Indie Band',
            'albumName': '',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = SpotifyResolveService(
        client: client,
        idTokenProvider: () async => 'mock-token',
      );
      final initial = MusicStatus(
        username: 'khent',
        trackName: 'Mystery Song',
        artistName: 'Indie Band',
        albumName: 'No Album',
        isPlaying: false,
        spotifyUrl: 'https://open.spotify.com/search/x',
      );

      final resolved = await service.resolve(initial);
      expect(resolved.albumName, isEmpty);
    });
  });
}
