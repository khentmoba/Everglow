import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/jukebox/data/models/music_status.dart';
import 'package:everglow/features/jukebox/data/models/top_music_track.dart';
import 'package:everglow/features/jukebox/data/models/lastfm_image_utils.dart';

void main() {
  group('Last.fm image utils', () {
    test('cleanLastfmImageUrl strips known placeholder hashes', () {
      expect(
        cleanLastfmImageUrl(
          'https://lastfm-img.freetls.fastly.net/i/u/300x300/'
          '2a96cbd8b46e442fc41c2b86b821562f.png',
        ),
        isNull,
      );
      expect(
        cleanLastfmImageUrl(
          'https://lastfm.freetls.fastly.net/i/u/174s/'
          'c6f59c1e5e7240a4c0d427abd71f3dbb.png',
        ),
        isNull,
      );
    });

    test('cleanLastfmImageUrl keeps real artwork and empty values', () {
      const real =
          'https://lastfm-img.freetls.fastly.net/i/u/300x300/'
          'fd378412e92480577c0f2a4463c8998a.png';
      expect(cleanLastfmImageUrl(real), real);
      expect(cleanLastfmImageUrl(null), isNull);
      expect(cleanLastfmImageUrl(''), isNull);
    });

    test('pickLastfmImageUrl prefers extralarge over smaller sizes', () {
      expect(
        pickLastfmImageUrl([
          {'#text': 'url_small', 'size': 'small'},
          {'#text': 'url_xl', 'size': 'extralarge'},
        ]),
        'url_xl',
      );
    });

    test('pickLastfmImageUrl falls back when extralarge is empty', () {
      expect(
        pickLastfmImageUrl([
          {'#text': '', 'size': 'small'},
          {'#text': '', 'size': 'extralarge'},
          {'#text': 'url_mega', 'size': 'mega'},
        ]),
        'url_mega',
      );
    });

    test('pickLastfmImageUrl skips placeholders and returns null when dry', () {
      expect(
        pickLastfmImageUrl([
          {
            '#text':
                'https://lastfm-img.freetls.fastly.net/i/u/300x300/'
                '2a96cbd8b46e442fc41c2b86b821562f.png',
            'size': 'extralarge',
          },
          {'#text': 'url_large', 'size': 'large'},
        ]),
        'url_large',
      );
      expect(
        pickLastfmImageUrl([
          {'#text': '', 'size': 'extralarge'},
        ]),
        isNull,
      );
      expect(pickLastfmImageUrl(null), isNull);
      expect(pickLastfmImageUrl([]), isNull);
    });
  });

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
        'mbid': '4459f042-afff-4fa3-b5e5-e10d9782992d',
      });

      expect(track.rank, 3);
      expect(track.trackName, 'American Teenager');
      expect(track.artistName, 'Ethel Cain');
      expect(track.playCount, 1284);
      expect(track.imageUrl, 'url_xl');
      expect(track.mbid, '4459f042-afff-4fa3-b5e5-e10d9782992d');
      expect(track.spotifyUrl, contains('Ethel%20Cain'));
      expect(track.spotifyUrl, contains('American%20Teenager'));
    });

    test('fromJson discards Last.fm placeholder artwork', () {
      final track = TopMusicTrack.fromJson({
        'name': 'Style',
        'playcount': '117',
        'artist': {'name': 'Taylor Swift'},
        'image': [
          {
            '#text':
                'https://lastfm-img.freetls.fastly.net/i/u/300x300/'
                '2a96cbd8b46e442fc41c2b86b821562f.png',
            'size': 'extralarge',
          },
        ],
      });

      expect(track.imageUrl, isNull);
    });

    test('fromJson uses a smaller cover when extralarge is blank', () {
      final track = TopMusicTrack.fromJson({
        'name': 'Fine Line',
        'playcount': '85',
        'artist': {'name': 'Harry Styles'},
        'image': [
          {'#text': '', 'size': 'small'},
          {'#text': '', 'size': 'extralarge'},
          {'#text': 'url_mega', 'size': 'mega'},
        ],
        '@attr': {'rank': '5'},
      });

      expect(track.imageUrl, 'url_mega');
    });

    test('fromJson falls back gracefully when fields are missing', () {
      final track = TopMusicTrack.fromJson({'name': 'Mystery'});

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

    test('fromTrackJson discards placeholder artwork', () {
      final status = MusicStatus.fromTrackJson({
        'artist': {'#text': 'Mat\u00e9o'},
        'name': 'Pinipili',
        'album': {'#text': 'Pinipili'},
        'image': [
          {
            '#text':
                'https://lastfm-img.freetls.fastly.net/i/u/300x300/'
                '2a96cbd8b46e442fc41c2b86b821562f.png',
            'size': 'extralarge',
          },
        ],
        'date': {'uts': '1786489832'},
      }, 'khentsgdz');

      expect(status.imageUrl, isNull);
    });
  });
}
