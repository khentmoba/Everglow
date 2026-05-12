import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/jukebox/data/models/music_status.dart';

void main() {
  group('MusicStatus Model Tests', () {
    test('MusicStatus.fromJson parses Last.fm response correctly', () {
      final mockJson = {
        'recenttracks': {
          'track': [
            {
              'artist': {'#text': 'Ethel Cain'},
              'name': 'American Teenager',
              'album': {'#text': 'Preacher\'s Daughter'},
              'image': [
                {'#text': 'url_small', 'size': 'small'},
                {'#text': 'url_xl', 'size': 'extralarge'}
              ],
              '@attr': {'nowplaying': 'true'}
            }
          ]
        }
      };

      final status = MusicStatus.fromJson(mockJson, 'khent');

      expect(status.username, 'khent');
      expect(status.artistName, 'Ethel Cain');
      expect(status.trackName, 'American Teenager');
      expect(status.isPlaying, true);
      expect(status.imageUrl, 'url_xl');
      expect(status.spotifyUrl, contains('Ethel%20Cain'));
      expect(status.spotifyUrl, contains('American%20Teenager'));
    });

    test('MusicStatus.empty creates a fallback status', () {
      final status = MusicStatus.empty('clair');
      expect(status.username, 'clair');
      expect(status.isPlaying, false);
      expect(status.trackName, 'Silent Night');
    });
  });
}
