import 'lastfm_image_utils.dart';

/// A single entry from Last.fm's `user.gettoptracks` response.
///
/// Unlike [MusicStatus], top tracks carry a play count and rank instead of
/// a timestamp. Last.fm's `user.gettoptracks` response does not include the
/// album for top tracks, so it can be enriched from `track.getinfo`, iTunes,
/// or Spotify.
class TopMusicTrack {
  final int rank;
  final String trackName;
  final String artistName;
  final int playCount;
  final String? imageUrl;
  final String spotifyUrl;
  final String? mbid;
  final String? albumName;

  const TopMusicTrack({
    required this.rank,
    required this.trackName,
    required this.artistName,
    required this.playCount,
    this.imageUrl,
    required this.spotifyUrl,
    this.mbid,
    this.albumName,
  });

  factory TopMusicTrack.fromJson(Map<String, dynamic> json) {
    final dynamic artistJson = json['artist'];
    final artistName = artistJson is Map
        ? (artistJson['name'] as String? ?? 'Unknown Artist')
        : 'Unknown Artist';
    final trackName = json['name'] as String? ?? 'Unknown Track';

    final imgUrl = pickLastfmImageUrl(json['image'] as List<dynamic>?);

    final dynamic attr = json['@attr'];
    final rank =
        int.tryParse(attr is Map ? (attr['rank']?.toString() ?? '') : '') ?? 0;
    final playCount = int.tryParse(json['playcount']?.toString() ?? '') ?? 0;
    final mbidValue = json['mbid'] as String?;

    final dynamic albumJson = json['album'];
    String? albumName;
    if (albumJson is Map) {
      albumName =
          (albumJson['#text'] ?? albumJson['name'] ?? albumJson['title'])
              as String?;
    } else if (albumJson is String) {
      albumName = albumJson;
    } else if (json['albumName'] is String) {
      albumName = json['albumName'] as String;
    }

    return TopMusicTrack(
      rank: rank,
      trackName: trackName,
      artistName: artistName,
      playCount: playCount,
      imageUrl: imgUrl,
      spotifyUrl:
          'https://open.spotify.com/search/${Uri.encodeComponent('$artistName $trackName')}',
      mbid: mbidValue?.isNotEmpty == true ? mbidValue : null,
      albumName:
          albumName?.trim().isNotEmpty == true ? albumName!.trim() : null,
    );
  }

  TopMusicTrack copyWith({
    int? rank,
    String? trackName,
    String? artistName,
    int? playCount,
    String? imageUrl,
    String? spotifyUrl,
    String? mbid,
    String? albumName,
  }) {
    return TopMusicTrack(
      rank: rank ?? this.rank,
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      playCount: playCount ?? this.playCount,
      imageUrl: imageUrl ?? this.imageUrl,
      spotifyUrl: spotifyUrl ?? this.spotifyUrl,
      mbid: mbid ?? this.mbid,
      albumName: albumName ?? this.albumName,
    );
  }
}
