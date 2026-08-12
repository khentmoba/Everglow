/// A single entry from Last.fm's `user.gettoptracks` response.
///
/// Unlike [MusicStatus], top tracks carry a play count and rank instead of
/// a timestamp, and Last.fm does not include the album for top tracks.
class TopMusicTrack {
  final int rank;
  final String trackName;
  final String artistName;
  final int playCount;
  final String? imageUrl;
  final String spotifyUrl;

  const TopMusicTrack({
    required this.rank,
    required this.trackName,
    required this.artistName,
    required this.playCount,
    this.imageUrl,
    required this.spotifyUrl,
  });

  factory TopMusicTrack.fromJson(Map<String, dynamic> json) {
    final dynamic artistJson = json['artist'];
    final artistName = artistJson is Map
        ? (artistJson['name'] as String? ?? 'Unknown Artist')
        : 'Unknown Artist';
    final trackName = json['name'] as String? ?? 'Unknown Track';

    final images = json['image'] as List<dynamic>?;
    String? imgUrl;
    if (images != null && images.isNotEmpty) {
      dynamic selectedImage = images.last;
      for (final img in images) {
        if (img is Map && img['size'] == 'extralarge') {
          selectedImage = img;
          break;
        }
      }
      if (selectedImage is Map) {
        imgUrl = selectedImage['#text'] as String?;
      }
    }

    final dynamic attr = json['@attr'];
    final rank = int.tryParse(
      attr is Map ? (attr['rank']?.toString() ?? '') : '',
    ) ?? 0;
    final playCount = int.tryParse(json['playcount']?.toString() ?? '') ?? 0;

    return TopMusicTrack(
      rank: rank,
      trackName: trackName,
      artistName: artistName,
      playCount: playCount,
      imageUrl: imgUrl,
      spotifyUrl:
          'https://open.spotify.com/search/${Uri.encodeComponent('$artistName $trackName')}',
    );
  }
}
