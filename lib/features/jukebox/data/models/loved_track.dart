import 'lastfm_image_utils.dart';

/// Entry from `user.getLovedTracks`.
class LovedTrack {
  final String trackName;
  final String artistName;
  final String? imageUrl;
  final String url;
  final String? mbid;
  final DateTime? lovedAt;

  const LovedTrack({
    required this.trackName,
    required this.artistName,
    this.imageUrl,
    required this.url,
    this.mbid,
    this.lovedAt,
  });

  factory LovedTrack.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Unknown Track';
    final artistJson = json['artist'];
    final artistName = artistJson is Map
        ? (artistJson['name'] as String? ?? 'Unknown Artist')
        : 'Unknown Artist';
    final images = json['image'] as List<dynamic>?;
    String? imgUrl;
    if (images != null && images.isNotEmpty) {
      dynamic sel = images.last;
      for (final img in images) {
        if (img is Map && img['size'] == 'extralarge') {
          sel = img;
          break;
        }
      }
      if (sel is Map) imgUrl = sel['#text'] as String?;
    }
    final url = json['url'] as String? ?? '';
    final mbid = json['mbid'] as String?;
    DateTime? lovedAt;
    final date = json['date'];
    if (date is Map) {
      final uts = int.tryParse(date['uts']?.toString() ?? '');
      if (uts != null) {
        lovedAt = DateTime.fromMillisecondsSinceEpoch(uts * 1000);
      }
    }
    return LovedTrack(
      trackName: name,
      artistName: artistName,
      imageUrl: cleanLastfmImageUrl(imgUrl),
      url: url,
      mbid: mbid?.isNotEmpty == true ? mbid : null,
      lovedAt: lovedAt,
    );
  }

  String get spotifySearchUrl =>
      'https://open.spotify.com/search/${Uri.encodeComponent('$artistName $trackName')}';
}
