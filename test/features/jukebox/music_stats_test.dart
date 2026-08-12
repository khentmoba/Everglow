import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/jukebox/data/models/music_status.dart';
import 'package:everglow/features/jukebox/data/models/top_music_track.dart';

void main() {
  group('TopMusicTrack Model Tests', () {
    test('fromJson parses a Last.fm top-track entry', () {
      final track = TopMusicTrack.fromJson({
        'name': 'American Teenager',
        'playcount': '1284',
        'artist': {'name': 'Ethel Cain'},
        'image': [
          {'#text': 'url_small', 'size': 'small'},
          {'#text': 'url_xl', 'size': 'extralarge'},
        ],
        '@attr': {'rank': '3'},
      });

      expect(track.rank, 3);
      expect(track.trackName, 'American Teenager');
      expect(track.artistName, 'Ethel Cain');
      expect(track.playCount, 1284);
      expect(track.imageUrl, 'url_xl');
      expect(track.spotifyUrl, contains('Ethel%20Cain'));
      expect(track.spotifyUrl, contains('American%20Teenager'));
    });

    test('fromJson falls back gracefully when fields are missing', () {
      final track = TopMusicTrack.fromJson({
        'name': 'Mystery',
      });

      expect(track.rank, 0);
      expect(track.artistName, 'Unknown Artist');
      expect(track.playCount, 0);
      expect(track.imageUrl, isNull);
    });
  });

  group('Recent Track Parsing Tests', () {
    test('fromTrackJson parses a scrobbled track with a timestamp', () {
      final status = MusicStatus.fromTrackJson({
        'artist': {'#text': 'Ethel Cain'},
        'name': 'American Teenager',
        'album': {'#text': 'Preacher\'s Daughter'},
        'image': [
          {'#text': 'url_small', 'size': 'small'},
          {'#text': 'url_xl', 'size': 'extralarge'},
        ],
        'date': {'uts': '1700000000'},
      }, 'khentsgdz');

      expect(status.username, 'khentsgdz');
      expect(status.artistName, 'Ethel Cain');
      expect(status.trackName, 'American Teenager');
      expect(status.albumName, 'Preacher\'s Daughter');
      expect(status.isPlaying, false);
      expect(status.timestamp, isNotNull);
      expect(status.imageUrl, 'url_xl');
    });

    test('fromTrackJson marks a now-playing track without a timestamp', () {
      final status = MusicStatus.fromTrackJson({
        'artist': {'#text': 'Mitski'},
        'name': 'First Love / Late Spring',
        'album': {'#text': 'Bury Me at Makeout Creek'},
        '@attr': {'nowplaying': 'true'},
      }, 'khentsgdz');

      expect(status.isPlaying, true);
      expect(status.timestamp, isNull);
    });
  });
}
